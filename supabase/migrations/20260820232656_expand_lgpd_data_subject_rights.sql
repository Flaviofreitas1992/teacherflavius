alter table public.data_subject_requests
  add column if not exists request_details text;

alter table public.data_subject_requests
  drop constraint if exists data_subject_requests_request_type_check;

alter table public.data_subject_requests
  add constraint data_subject_requests_request_type_check
  check (request_type in (
    'account_deletion',
    'data_access',
    'correction',
    'anonymization_blocking',
    'sharing_information'
  ));

alter table public.data_subject_requests
  add constraint data_subject_requests_request_details_length_check
  check (request_details is null or length(request_details) <= 4000) not valid;

alter table public.data_subject_requests
  validate constraint data_subject_requests_request_details_length_check;

alter table public.data_subject_requests
  add constraint data_subject_requests_resolution_note_length_check
  check (resolution_note is null or length(resolution_note) <= 8000) not valid;

alter table public.data_subject_requests
  validate constraint data_subject_requests_resolution_note_length_check;

drop index if exists public.data_subject_requests_one_active_deletion_per_user;
create unique index if not exists data_subject_requests_one_active_type_per_user
  on public.data_subject_requests (subject_user_id, request_type)
  where status in ('open','in_review');

create index if not exists data_subject_requests_type_status_requested_at_idx
  on public.data_subject_requests (request_type, status, requested_at desc);

create or replace function public.create_data_subject_request(
  p_request_type text,
  p_request_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  requester_id uuid := auth.uid();
  requester_name text;
  requester_email text;
  normalized_type text := lower(btrim(coalesce(p_request_type, '')));
  normalized_details text := nullif(btrim(coalesce(p_request_details, '')), '');
  existing_request public.data_subject_requests%rowtype;
  created_request public.data_subject_requests%rowtype;
begin
  if requester_id is null then
    raise exception 'Usuário não autenticado.' using errcode = '42501';
  end if;

  if coalesce(public.is_teacher_admin(), false) then
    raise exception 'Contas administrativas não utilizam este fluxo.' using errcode = '42501';
  end if;

  if normalized_type not in ('data_access','correction','anonymization_blocking','sharing_information') then
    raise exception 'Tipo de solicitação inválido.' using errcode = '22023';
  end if;

  if normalized_details is not null and length(normalized_details) > 4000 then
    raise exception 'A descrição do pedido deve ter no máximo 4000 caracteres.' using errcode = '22023';
  end if;

  if normalized_type in ('correction','anonymization_blocking') and normalized_details is null then
    raise exception 'Descreva quais dados precisam ser corrigidos, anonimizados ou bloqueados.' using errcode = '22023';
  end if;

  select * into existing_request
  from public.data_subject_requests
  where subject_user_id = requester_id
    and request_type = normalized_type
    and status in ('open','in_review')
  order by requested_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'ok', true,
      'request_id', existing_request.id,
      'request_type', existing_request.request_type,
      'status', existing_request.status,
      'requested_at', existing_request.requested_at,
      'already_existed', true
    );
  end if;

  select p.name, coalesce(p.email, u.email)
    into requester_name, requester_email
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = requester_id;

  insert into public.data_subject_requests (
    subject_user_id,
    subject_name,
    subject_email,
    request_type,
    request_details,
    status
  ) values (
    requester_id,
    nullif(btrim(requester_name), ''),
    nullif(btrim(requester_email), ''),
    normalized_type,
    normalized_details,
    'open'
  )
  returning * into created_request;

  return jsonb_build_object(
    'ok', true,
    'request_id', created_request.id,
    'request_type', created_request.request_type,
    'status', created_request.status,
    'requested_at', created_request.requested_at,
    'already_existed', false
  );
end;
$$;

revoke all on function public.create_data_subject_request(text,text) from public;
revoke all on function public.create_data_subject_request(text,text) from anon;
grant execute on function public.create_data_subject_request(text,text) to authenticated;

create or replace function public.cancel_my_data_subject_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requester_id uuid := auth.uid();
  changed_count integer := 0;
begin
  if requester_id is null then
    raise exception 'Usuário não autenticado.' using errcode = '42501';
  end if;

  update public.data_subject_requests
  set status = 'cancelled',
      updated_at = now(),
      resolution_note = 'Pedido cancelado pelo titular.'
  where id = p_request_id
    and subject_user_id = requester_id
    and request_type <> 'account_deletion'
    and status = 'open';

  get diagnostics changed_count = row_count;
  if changed_count = 0 then
    raise exception 'Pedido não encontrado ou já está em análise.';
  end if;

  return jsonb_build_object('ok', true, 'request_id', p_request_id, 'status', 'cancelled');
end;
$$;

revoke all on function public.cancel_my_data_subject_request(uuid) from public;
revoke all on function public.cancel_my_data_subject_request(uuid) from anon;
grant execute on function public.cancel_my_data_subject_request(uuid) to authenticated;

create or replace function public.mark_data_subject_request_in_review(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed_count integer := 0;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  update public.data_subject_requests
  set status = 'in_review',
      reviewed_at = coalesce(reviewed_at, now()),
      reviewed_by = auth.uid(),
      updated_at = now()
  where id = p_request_id
    and request_type <> 'account_deletion'
    and status = 'open';

  get diagnostics changed_count = row_count;
  if changed_count = 0 then
    raise exception 'Pedido não encontrado ou não está mais aberto.';
  end if;

  return jsonb_build_object('ok', true, 'request_id', p_request_id, 'status', 'in_review');
end;
$$;

revoke all on function public.mark_data_subject_request_in_review(uuid) from public;
revoke all on function public.mark_data_subject_request_in_review(uuid) from anon;
grant execute on function public.mark_data_subject_request_in_review(uuid) to authenticated;

create or replace function public.complete_data_subject_request(
  p_request_id uuid,
  p_resolution_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_resolution text := nullif(btrim(coalesce(p_resolution_note, '')), '');
  request_row public.data_subject_requests%rowtype;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  if normalized_resolution is null then
    raise exception 'Registre a resposta dada ao titular antes de concluir o pedido.' using errcode = '22023';
  end if;

  if length(normalized_resolution) > 8000 then
    raise exception 'A resposta deve ter no máximo 8000 caracteres.' using errcode = '22023';
  end if;

  select * into request_row
  from public.data_subject_requests
  where id = p_request_id
    and request_type <> 'account_deletion'
  for update;

  if not found then
    raise exception 'Pedido não encontrado.';
  end if;

  if request_row.status not in ('open','in_review') then
    raise exception 'Este pedido não pode mais ser concluído.';
  end if;

  update public.data_subject_requests
  set status = 'completed',
      reviewed_at = coalesce(reviewed_at, now()),
      completed_at = now(),
      reviewed_by = auth.uid(),
      updated_at = now(),
      subject_name = null,
      subject_email = null,
      resolution_note = normalized_resolution,
      retention_summary = jsonb_build_object(
        'response_channel', 'portal',
        'personal_data_copy_stored', false
      )
  where id = p_request_id;

  return jsonb_build_object(
    'ok', true,
    'request_id', p_request_id,
    'request_type', request_row.request_type,
    'status', 'completed',
    'completed_at', now()
  );
end;
$$;

revoke all on function public.complete_data_subject_request(uuid,text) from public;
revoke all on function public.complete_data_subject_request(uuid,text) from anon;
grant execute on function public.complete_data_subject_request(uuid,text) to authenticated;

create or replace function public.get_my_data_export()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, storage, pg_temp
as $$
declare
  requester_id uuid := auth.uid();
  result jsonb;
begin
  if requester_id is null then
    raise exception 'Usuário não autenticado.' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'format_version', '1.0',
    'exported_at', now(),
    'scope_note', 'Cópia automática dos principais dados diretamente associados à conta. Payloads técnicos extensos, segredos operacionais e conteúdo de terceiros não são incluídos automaticamente e podem ser objeto de solicitação formal de acesso.',
    'account', (
      select jsonb_build_object(
        'id', u.id,
        'email', u.email,
        'phone', u.phone,
        'created_at', u.created_at,
        'updated_at', u.updated_at,
        'last_sign_in_at', u.last_sign_in_at,
        'email_confirmed_at', u.email_confirmed_at,
        'user_metadata', coalesce(u.raw_user_meta_data, '{}'::jsonb)
      )
      from auth.users u where u.id = requester_id
    ),
    'identities', coalesce((
      select jsonb_agg(jsonb_build_object(
        'provider', i.provider,
        'provider_id', i.provider_id,
        'email', i.email,
        'created_at', i.created_at,
        'updated_at', i.updated_at,
        'last_sign_in_at', i.last_sign_in_at
      ) order by i.created_at)
      from auth.identities i where i.user_id = requester_id
    ), '[]'::jsonb),
    'profile', (
      select jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'email', p.email,
        'created_at', p.created_at,
        'cpf', p.cpf,
        'whatsapp', p.whatsapp,
        'enrollment_code', p.enrollment_code,
        'enrolled', p.enrolled,
        'pix_key', p.pix_key,
        'availability', p.availability,
        'exercise_schedule_start_date', p.exercise_schedule_start_date,
        'archived', p.archived,
        'archived_at', p.archived_at,
        'class_type', p.class_type,
        'profile_completed', p.profile_completed,
        'first_portal_access_at', p.first_portal_access_at,
        'last_portal_access_at', p.last_portal_access_at,
        'date_of_birth', p.date_of_birth
      ) from public.profiles p where p.id = requester_id
    ),
    'private_data', (
      select to_jsonb(spd) from public.student_private_data spd where spd.user_id = requester_id
    ),
    'enrollment_records', coalesce((select jsonb_agg(to_jsonb(se) order by se.created_at) from public.student_enrollments se where se.user_id = requester_id), '[]'::jsonb),
    'class_memberships', coalesce((select jsonb_agg(to_jsonb(cs) order by cs.created_at) from public.class_students cs where cs.user_id = requester_id), '[]'::jsonb),
    'attendance', coalesce((select jsonb_agg(to_jsonb(sf) order by sf.class_date) from public.student_frequency sf where sf.user_id = requester_id), '[]'::jsonb),
    'activity_results', coalesce((select jsonb_agg(to_jsonb(ar) order by ar.completed_at) from public.activity_results ar where ar.user_id = requester_id), '[]'::jsonb),
    'daily_exercise_completion', coalesce((select jsonb_agg(to_jsonb(dec) - 'completed_by' - 'completed_by_email' order by dec.created_at) from public.daily_exercise_completion dec where dec.user_id = requester_id), '[]'::jsonb),
    'grammar_lesson_completion', coalesce((select jsonb_agg(to_jsonb(glc) order by glc.updated_at) from public.grammar_lesson_completion glc where glc.user_id = requester_id), '[]'::jsonb),
    'study_roadmap_completion', coalesce((select jsonb_agg(to_jsonb(src) order by src.updated_at) from public.study_roadmap_completion src where src.user_id = requester_id), '[]'::jsonb),
    'weekly_tasks', coalesce((select jsonb_agg(to_jsonb(wst) - 'created_by' order by wst.created_at) from public.weekly_student_tasks wst where wst.user_id = requester_id), '[]'::jsonb),
    'weekly_plan_snapshots', coalesce((select jsonb_agg(to_jsonb(wps) order by wps.created_at) from public.weekly_plan_snapshots wps where wps.user_id = requester_id), '[]'::jsonb),
    'flashcard_decks', coalesce((select jsonb_agg(to_jsonb(fd) order by fd.created_at) from public.flashcard_decks fd where fd.owner_id = requester_id), '[]'::jsonb),
    'flashcards', coalesce((select jsonb_agg(to_jsonb(fc) order by fc.deck_id, fc.position) from public.flashcards fc join public.flashcard_decks fd on fd.id = fc.deck_id where fd.owner_id = requester_id), '[]'::jsonb),
    'flashcard_practice_days', coalesce((select jsonb_agg(to_jsonb(fpd) order by fpd.practice_date) from public.flashcard_practice_days fpd where fpd.user_id = requester_id), '[]'::jsonb),
    'flashcard_review_history', coalesce((select jsonb_agg(to_jsonb(frh) order by frh.reviewed_at) from public.flashcard_review_history frh where frh.user_id = requester_id), '[]'::jsonb),
    'flashcard_srs', coalesce((select jsonb_agg(to_jsonb(fs) order by fs.updated_at) from public.flashcard_srs fs where fs.user_id = requester_id), '[]'::jsonb),
    'makeup_class_bookings', coalesce((select jsonb_agg(to_jsonb(mcb) order by mcb.booked_at) from public.makeup_class_bookings mcb where mcb.student_id = requester_id), '[]'::jsonb),
    'pronunciation_attempts', coalesce((select jsonb_agg(to_jsonb(pa) - 'azure_result' order by pa.created_at) from public.pronunciation_attempts pa where pa.user_id = requester_id), '[]'::jsonb),
    'access_logs', coalesce((select jsonb_agg(to_jsonb(sal) order by sal.accessed_at) from public.student_access_logs sal where sal.user_id = requester_id), '[]'::jsonb),
    'tags', coalesce((select jsonb_agg(to_jsonb(st) - 'created_by' order by st.created_at) from public.student_tags st where st.user_id = requester_id), '[]'::jsonb),
    'exercise_sync_events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', ese.id,
        'received_at', ese.received_at,
        'status', ese.status,
        'exercise_id', ese.exercise_id,
        'exercise_title', ese.exercise_title,
        'source_email', ese.source_email,
        'student_name', ese.student_name,
        'submitted_completed_at', ese.submitted_completed_at,
        'stored_completed_at', ese.stored_completed_at,
        'record_action', ese.record_action,
        'error_message', ese.error_message
      ) order by ese.received_at)
      from public.exercise_sync_events ese where ese.user_id = requester_id
    ), '[]'::jsonb),
    'billing_settings', (select to_jsonb(sbs) - 'updated_by' from public.student_billing_settings sbs where sbs.student_id = requester_id),
    'monthly_tuition', coalesce((select jsonb_agg(to_jsonb(mt) - 'created_by' - 'updated_by' order by mt.reference_month) from public.monthly_tuition mt where mt.student_id = requester_id), '[]'::jsonb),
    'payment_attempts', coalesce((select jsonb_agg(to_jsonb(tpa) - 'idempotency_key' order by tpa.created_at) from public.tuition_payment_attempts tpa where tpa.student_id = requester_id), '[]'::jsonb),
    'storage_files', coalesce((
      select jsonb_agg(jsonb_build_object(
        'bucket_id', so.bucket_id,
        'name', so.name,
        'created_at', so.created_at,
        'updated_at', so.updated_at,
        'metadata', so.metadata
      ) order by so.created_at)
      from storage.objects so where so.owner = requester_id
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.get_my_data_export() from public;
revoke all on function public.get_my_data_export() from anon;
grant execute on function public.get_my_data_export() to authenticated;
