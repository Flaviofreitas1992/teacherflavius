alter table public.monthly_tuition add column if not exists subject_ref uuid;
update public.monthly_tuition set subject_ref = student_id where subject_ref is null;
alter table public.monthly_tuition alter column subject_ref set not null;
alter table public.monthly_tuition alter column student_id drop not null;
alter table public.monthly_tuition drop constraint if exists monthly_tuition_student_id_fkey;
alter table public.monthly_tuition add constraint monthly_tuition_student_id_fkey foreign key (student_id) references public.profiles(id) on delete set null;

alter table public.tuition_payment_attempts add column if not exists subject_ref uuid;
update public.tuition_payment_attempts set subject_ref = student_id where subject_ref is null;
alter table public.tuition_payment_attempts alter column subject_ref set not null;
alter table public.tuition_payment_attempts alter column student_id drop not null;
alter table public.tuition_payment_attempts drop constraint if exists tuition_payment_attempts_student_id_fkey;
alter table public.tuition_payment_attempts add constraint tuition_payment_attempts_student_id_fkey foreign key (student_id) references public.profiles(id) on delete set null;

create or replace function public.preserve_financial_subject_ref()
returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
  if new.student_id is not null then new.subject_ref:=new.student_id;
  elsif new.subject_ref is null then raise exception 'subject_ref é obrigatório para registros financeiros.';
  end if;
  return new;
end; $$;

drop trigger if exists preserve_monthly_tuition_subject_ref on public.monthly_tuition;
create trigger preserve_monthly_tuition_subject_ref before insert or update of student_id,subject_ref on public.monthly_tuition for each row execute function public.preserve_financial_subject_ref();

drop trigger if exists preserve_tuition_payment_attempt_subject_ref on public.tuition_payment_attempts;
create trigger preserve_tuition_payment_attempt_subject_ref before insert or update of student_id,subject_ref on public.tuition_payment_attempts for each row execute function public.preserve_financial_subject_ref();

create index if not exists monthly_tuition_subject_ref_idx on public.monthly_tuition(subject_ref,reference_month desc);
create index if not exists tuition_payment_attempts_subject_ref_idx on public.tuition_payment_attempts(subject_ref,created_at desc);

create or replace function public.close_student_account_for_privacy(target_user_id uuid)
returns jsonb language plpgsql security definer set search_path=public,auth,storage,pg_temp as $$
declare
  subject_ids uuid[];
  subject_id uuid;
  subject_emails text[];
  has_financial_records boolean;
  preserved_financial_subjects integer:=0;
  fully_deleted_subjects integer:=0;
  deleted_auth_accounts integer:=0;
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

  select array_agg(distinct lower(email_value)) filter(where email_value is not null and btrim(email_value)<>'') into subject_emails from (
    select u.email::text email_value from auth.users u where u.id=any(subject_ids)
    union all select p.email from public.profiles p where p.id=any(subject_ids)
    union all select l.google_email from public.student_google_account_links l where l.google_user_id=any(subject_ids) or l.legacy_user_id=any(subject_ids)
    union all select l.enrollment_email from public.student_google_account_links l where l.google_user_id=any(subject_ids) or l.legacy_user_id=any(subject_ids)
  ) emails;

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

    has_financial_records:=exists(select 1 from public.monthly_tuition mt where mt.student_id=subject_id)
      or exists(select 1 from public.tuition_payment_attempts pa where pa.student_id=subject_id);

    update public.monthly_tuition set payment_notes=null,updated_at=now() where student_id=subject_id;
    update public.monthly_tuition_events e set details=coalesce(e.details,'{}'::jsonb)-'payment_notes'
      where e.tuition_id in (select mt.id from public.monthly_tuition mt where mt.subject_ref=subject_id);

    delete from auth.users where id=subject_id;
    if found then deleted_auth_accounts:=deleted_auth_accounts+1;
    else delete from public.profiles where id=subject_id;
    end if;

    if has_financial_records then preserved_financial_subjects:=preserved_financial_subjects+1;
    else fully_deleted_subjects:=fully_deleted_subjects+1;
    end if;
  end loop;

  delete from public.student_google_account_links where google_user_id=any(subject_ids) or legacy_user_id=any(subject_ids);
  if subject_emails is not null then
    delete from public.student_google_email_aliases where lower(google_email)=any(subject_emails) or lower(enrollment_email)=any(subject_emails);
  end if;

  return jsonb_build_object('ok',true,'subject_ids_processed',subject_ids,'auth_accounts_deleted',deleted_auth_accounts,'subjects_fully_deleted_without_financial_history',fully_deleted_subjects,'financial_subjects_detached_and_preserved',preserved_financial_subjects,'financial_records_preserved',preserved_financial_subjects>0);
end; $$;

revoke all on function public.close_student_account_for_privacy(uuid) from public;
revoke all on function public.close_student_account_for_privacy(uuid) from anon;
revoke all on function public.close_student_account_for_privacy(uuid) from authenticated;