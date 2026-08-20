create table if not exists public.data_subject_requests (
  id uuid primary key default gen_random_uuid(),
  subject_user_id uuid not null,
  subject_name text,
  subject_email text,
  request_type text not null default 'account_deletion' check (request_type in ('account_deletion')),
  status text not null default 'open' check (status in ('open','in_review','completed','cancelled','rejected')),
  requested_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_at timestamptz,
  completed_at timestamptz,
  reviewed_by uuid,
  resolution_note text,
  retention_summary jsonb not null default '{}'::jsonb
);

create unique index if not exists data_subject_requests_one_active_deletion_per_user
  on public.data_subject_requests (subject_user_id)
  where request_type = 'account_deletion' and status in ('open','in_review');

create index if not exists data_subject_requests_status_requested_at_idx
  on public.data_subject_requests (status, requested_at desc);

alter table public.data_subject_requests enable row level security;
revoke all on table public.data_subject_requests from public;
revoke all on table public.data_subject_requests from anon;
revoke all on table public.data_subject_requests from authenticated;
grant select on table public.data_subject_requests to authenticated;

drop policy if exists "subjects_read_own_privacy_requests" on public.data_subject_requests;
create policy "subjects_read_own_privacy_requests" on public.data_subject_requests
  for select to authenticated using ((select auth.uid()) = subject_user_id);

drop policy if exists "teacher_reads_privacy_requests" on public.data_subject_requests;
create policy "teacher_reads_privacy_requests" on public.data_subject_requests
  for select to authenticated using (coalesce(public.is_teacher_admin(), false));

create or replace function public.request_account_deletion()
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
  requester_id uuid := auth.uid();
  requester_name text;
  requester_email text;
  existing_request public.data_subject_requests%rowtype;
  created_request public.data_subject_requests%rowtype;
begin
  if requester_id is null then raise exception 'Usuário não autenticado.' using errcode = '42501'; end if;
  if coalesce(public.is_teacher_admin(), false) then
    raise exception 'Contas administrativas não podem ser encerradas por este fluxo.' using errcode = '42501';
  end if;

  select * into existing_request from public.data_subject_requests
   where subject_user_id = requester_id and request_type = 'account_deletion' and status in ('open','in_review')
   order by requested_at desc limit 1;
  if found then
    return jsonb_build_object('ok',true,'request_id',existing_request.id,'status',existing_request.status,'requested_at',existing_request.requested_at,'already_existed',true);
  end if;

  select p.name, coalesce(p.email,u.email) into requester_name, requester_email
    from auth.users u left join public.profiles p on p.id=u.id where u.id=requester_id;

  insert into public.data_subject_requests(subject_user_id,subject_name,subject_email,request_type,status)
  values(requester_id,nullif(btrim(requester_name),''),nullif(btrim(requester_email),''),'account_deletion','open')
  returning * into created_request;

  return jsonb_build_object('ok',true,'request_id',created_request.id,'status',created_request.status,'requested_at',created_request.requested_at,'already_existed',false);
end; $$;
revoke all on function public.request_account_deletion() from public;
revoke all on function public.request_account_deletion() from anon;
grant execute on function public.request_account_deletion() to authenticated;

create or replace function public.cancel_my_account_deletion_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare requester_id uuid := auth.uid(); changed_count integer := 0;
begin
  if requester_id is null then raise exception 'Usuário não autenticado.' using errcode='42501'; end if;
  update public.data_subject_requests set status='cancelled',updated_at=now(),resolution_note='Pedido cancelado pelo titular.'
   where id=p_request_id and subject_user_id=requester_id and request_type='account_deletion' and status='open';
  get diagnostics changed_count=row_count;
  if changed_count=0 then raise exception 'Pedido não encontrado ou já está em análise.'; end if;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'status','cancelled');
end; $$;
revoke all on function public.cancel_my_account_deletion_request(uuid) from public;
revoke all on function public.cancel_my_account_deletion_request(uuid) from anon;
grant execute on function public.cancel_my_account_deletion_request(uuid) to authenticated;

create or replace function public.mark_account_deletion_in_review(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare changed_count integer := 0;
begin
  if not coalesce(public.is_teacher_admin(),false) then raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode='42501'; end if;
  update public.data_subject_requests set status='in_review',reviewed_at=coalesce(reviewed_at,now()),reviewed_by=auth.uid(),updated_at=now()
   where id=p_request_id and request_type='account_deletion' and status='open';
  get diagnostics changed_count=row_count;
  if changed_count=0 then raise exception 'Pedido não encontrado ou não está mais aberto.'; end if;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'status','in_review');
end; $$;
revoke all on function public.mark_account_deletion_in_review(uuid) from public;
revoke all on function public.mark_account_deletion_in_review(uuid) from anon;
grant execute on function public.mark_account_deletion_in_review(uuid) to authenticated;

create or replace function public.close_student_account_for_privacy(target_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public, auth, storage, pg_temp as $$
declare
  subject_ids uuid[];
  subject_id uuid;
  availability_column text;
  has_financial_records boolean;
  preserved_financial_profiles integer := 0;
  fully_deleted_profiles integer := 0;
  deleted_auth_accounts integer := 0;
begin
  if not coalesce(public.is_teacher_admin(),false) then raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode='42501'; end if;

  select array_agg(distinct candidate_id) into subject_ids from (
    select target_user_id candidate_id
    union all select l.google_user_id from public.student_google_account_links l where l.google_user_id=target_user_id or l.legacy_user_id=target_user_id
    union all select l.legacy_user_id from public.student_google_account_links l where l.google_user_id=target_user_id or l.legacy_user_id=target_user_id
  ) linked where candidate_id is not null;
  if subject_ids is null or cardinality(subject_ids)=0 then subject_ids:=array[target_user_id]; end if;

  if exists(select 1 from public.teacher_admins ta where ta.user_id=any(subject_ids)) then raise exception 'Não é permitido encerrar uma conta de professor.'; end if;
  if not exists(select 1 from auth.users u where u.id=any(subject_ids)) and not exists(select 1 from public.profiles p where p.id=any(subject_ids)) then raise exception 'Aluno não encontrado.'; end if;
  if exists(select 1 from storage.objects o where o.owner=any(subject_ids)) then raise exception 'A conta possui arquivos no Storage. Remova ou transfira os arquivos antes de concluir o encerramento.'; end if;

  foreach subject_id in array subject_ids loop
    delete from public.activity_results where user_id=subject_id;
    delete from public.class_lesson_records where user_id=subject_id;
    delete from public.class_students where user_id=subject_id;
    delete from public.daily_exercise_completion where user_id=subject_id;
    delete from public.enrollment_email_notifications where student_id=subject_id;
    delete from public.exercise_sync_events where user_id=subject_id;
    delete from public.flashcard_review_history where user_id=subject_id;
    delete from public.flashcard_srs where user_id=subject_id;
    delete from public.flashcard_practice_days where user_id=subject_id;
    delete from public.flashcard_decks where owner_id=subject_id;
    delete from public.grammar_lesson_completion where user_id=subject_id;
    delete from public.makeup_class_bookings where student_id=subject_id;
    delete from public.pronunciation_attempts where user_id=subject_id;
    delete from public.student_access_logs where user_id=subject_id;
    delete from public.student_billing_settings where student_id=subject_id;
    delete from public.student_enrollment_invites where user_id=subject_id;
    delete from public.student_enrollments where user_id=subject_id;
    delete from public.student_frequency where user_id=subject_id;
    delete from public.student_private_data where user_id=subject_id;
    delete from public.student_tags where user_id=subject_id;
    delete from public.study_roadmap_completion where user_id=subject_id;
    delete from public.weekly_plan_snapshots where user_id=subject_id;
    delete from public.weekly_student_tasks where user_id=subject_id;
    if to_regclass('public.backup_student_private_data_20260501') is not null then execute 'delete from public.backup_student_private_data_20260501 where user_id=$1' using subject_id; end if;

    update public.monthly_tuition set payment_notes=null,updated_at=now() where student_id=subject_id;
    has_financial_records := exists(select 1 from public.monthly_tuition mt where mt.student_id=subject_id)
      or exists(select 1 from public.tuition_payment_attempts pa where pa.student_id=subject_id);

    if has_financial_records then
      update public.profiles set name='Conta encerrada',email=null,cpf=null,whatsapp=null,enrollment_code=null,enrolled=false,pix_key=null,availability='{}'::jsonb,exercise_schedule_start_date=null,archived=true,archived_at=now(),class_type=null,profile_completed=false,first_portal_access_at=null,last_portal_access_at=null,date_of_birth=null where id=subject_id;
      for availability_column in select c.column_name from information_schema.columns c where c.table_schema='public' and c.table_name='profiles' and c.column_name like 'availability\_%' escape '\' and c.data_type='boolean' loop
        execute format('update public.profiles set %I=false where id=$1',availability_column) using subject_id;
      end loop;
      preserved_financial_profiles:=preserved_financial_profiles+1;
    else
      delete from public.profiles where id=subject_id;
      fully_deleted_profiles:=fully_deleted_profiles+1;
    end if;

    delete from auth.users where id=subject_id;
    if found then deleted_auth_accounts:=deleted_auth_accounts+1; end if;
  end loop;

  delete from public.student_google_account_links where google_user_id=any(subject_ids) or legacy_user_id=any(subject_ids);
  return jsonb_build_object('ok',true,'subject_ids_processed',subject_ids,'auth_accounts_deleted',deleted_auth_accounts,'profiles_fully_deleted',fully_deleted_profiles,'financial_profiles_anonymized',preserved_financial_profiles,'financial_records_preserved',preserved_financial_profiles>0);
end; $$;
revoke all on function public.close_student_account_for_privacy(uuid) from public;
revoke all on function public.close_student_account_for_privacy(uuid) from anon;
revoke all on function public.close_student_account_for_privacy(uuid) from authenticated;

create or replace function public.complete_account_deletion_request(p_request_id uuid,p_resolution_note text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare request_row public.data_subject_requests%rowtype; closure_result jsonb; retention jsonb;
begin
  if not coalesce(public.is_teacher_admin(),false) then raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode='42501'; end if;
  select * into request_row from public.data_subject_requests where id=p_request_id and request_type='account_deletion' for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  if request_row.status not in ('open','in_review') then raise exception 'Este pedido não pode mais ser concluído.'; end if;
  closure_result:=public.close_student_account_for_privacy(request_row.subject_user_id);
  retention:=jsonb_build_object('financial_records_preserved',coalesce((closure_result->>'financial_records_preserved')::boolean,false),'basis','Conservação seletiva de registros financeiros para cumprimento de obrigações legais/regulatórias e exercício regular de direitos; dados operacionais e identificadores desnecessários removidos ou anonimizados.');
  update public.data_subject_requests set status='completed',reviewed_at=coalesce(reviewed_at,now()),completed_at=now(),reviewed_by=auth.uid(),updated_at=now(),subject_name=null,subject_email=null,resolution_note=coalesce(nullif(btrim(p_resolution_note),''),'Conta encerrada e dados tratados conforme a política de retenção.'),retention_summary=retention where id=p_request_id;
  return jsonb_build_object('ok',true,'request_id',p_request_id,'status','completed','closure',closure_result,'retention',retention);
end; $$;
revoke all on function public.complete_account_deletion_request(uuid,text) from public;
revoke all on function public.complete_account_deletion_request(uuid,text) from anon;
grant execute on function public.complete_account_deletion_request(uuid,text) to authenticated;

create or replace function public.delete_teacher_student(target_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
  if not coalesce(public.is_teacher_admin(),false) then raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode='42501'; end if;
  return public.close_student_account_for_privacy(target_user_id);
end; $$;
revoke all on function public.delete_teacher_student(uuid) from public;
revoke all on function public.delete_teacher_student(uuid) from anon;
grant execute on function public.delete_teacher_student(uuid) to authenticated;

create or replace function public.protect_profile_security_fields()
returns trigger language plpgsql set search_path=public,pg_temp as $$
declare requester_email text:=nullif(auth.jwt()->>'email','');
begin
  if current_user='authenticated' and auth.uid() is not null and not coalesce(public.is_teacher_admin(),false) then
    if tg_op='INSERT' then
      new.email:=requester_email; new.created_at:=now(); new.enrollment_code:=null; new.enrolled:=false; new.exercise_schedule_start_date:=null; new.archived:=false; new.archived_at:=null; new.class_type:=null; new.first_portal_access_at:=null; new.last_portal_access_at:=null;
    elsif tg_op='UPDATE' then
      if coalesce(old.archived,false)=true then raise exception 'Esta conta foi encerrada e não pode ser reativada pelo portal.' using errcode='42501'; end if;
      if new.email is distinct from old.email or new.created_at is distinct from old.created_at or coalesce(new.enrollment_code,'') is distinct from coalesce(old.enrollment_code,'') or new.enrolled is distinct from old.enrolled or new.exercise_schedule_start_date is distinct from old.exercise_schedule_start_date or new.archived is distinct from old.archived or new.archived_at is distinct from old.archived_at or new.class_type is distinct from old.class_type or new.first_portal_access_at is distinct from old.first_portal_access_at or new.last_portal_access_at is distinct from old.last_portal_access_at then
        raise exception 'Campos administrativos do perfil não podem ser alterados diretamente.' using errcode='42501';
      end if;
    end if;
  end if;
  return new;
end; $$;