-- Security hardening synchronized from production on 2026-08-20.
-- This migration intentionally keeps application-facing RPCs available only
-- where their function bodies enforce teacher/self authorization.

begin;

-- ---------------------------------------------------------------------------
-- Student frequency: students can read their own records but may not forge
-- attendance records directly. Teacher writes are performed by privileged RPCs.
-- ---------------------------------------------------------------------------
drop policy if exists "Usuários podem inserir sua própria frequência" on public.student_frequency;
drop policy if exists "Usuários podem atualizar sua própria frequência" on public.student_frequency;
drop policy if exists "Usuários podem apagar sua própria frequência" on public.student_frequency;
drop policy if exists "Alunos podem inserir sua própria frequência" on public.student_frequency;
drop policy if exists "Alunos podem atualizar sua própria frequência" on public.student_frequency;
drop policy if exists "Alunos podem excluir sua própria frequência" on public.student_frequency;

-- ---------------------------------------------------------------------------
-- Private server-side rate-limit storage. No browser/API role may read or write
-- this table or invoke its counter directly.
-- ---------------------------------------------------------------------------
create table if not exists public.api_rate_limit_buckets (
  bucket_key text not null,
  window_start timestamptz not null,
  request_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (bucket_key, window_start)
);

alter table public.api_rate_limit_buckets enable row level security;
revoke all privileges on table public.api_rate_limit_buckets from anon, authenticated;

create or replace function public.consume_api_rate_limit(
  target_bucket_key text,
  target_window_seconds integer,
  target_max_requests integer
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_window timestamptz;
  new_count integer;
begin
  if target_bucket_key is null or length(target_bucket_key) < 1 or length(target_bucket_key) > 200 then
    raise exception 'invalid rate limit bucket key';
  end if;
  if target_window_seconds < 1 or target_window_seconds > 86400 then
    raise exception 'invalid rate limit window';
  end if;
  if target_max_requests < 1 or target_max_requests > 10000 then
    raise exception 'invalid rate limit maximum';
  end if;

  current_window := to_timestamp(
    floor(extract(epoch from clock_timestamp()) / target_window_seconds) * target_window_seconds
  );

  insert into public.api_rate_limit_buckets(bucket_key, window_start, request_count, updated_at)
  values (target_bucket_key, current_window, 1, now())
  on conflict (bucket_key, window_start)
  do update set
    request_count = public.api_rate_limit_buckets.request_count + 1,
    updated_at = now()
  returning request_count into new_count;

  return new_count <= target_max_requests;
end;
$$;

revoke all on function public.consume_api_rate_limit(text, integer, integer) from public, anon, authenticated;
grant execute on function public.consume_api_rate_limit(text, integer, integer) to service_role;

-- ---------------------------------------------------------------------------
-- Historical backup tables are not application data. RLS remains enabled and
-- API roles also lose table privileges as defense in depth.
-- ---------------------------------------------------------------------------
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'backup_auth_users_metadata_20260501',
    'backup_profiles_20260501',
    'backup_student_private_data_20260501'
  ]
  loop
    if to_regclass('public.' || table_name) is not null then
      execute format('revoke all privileges on table public.%I from anon, authenticated', table_name);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Google Forms administration RPCs must never be callable anonymously.
-- Their bodies retain the teacher-admin checks used by the authenticated UI.
-- ---------------------------------------------------------------------------
revoke execute on function public.disconnect_google_form_integration(uuid) from anon;
revoke execute on function public.get_google_form_integrations() from anon;
revoke execute on function public.retry_google_form_integration(uuid) from anon;
revoke execute on function public.upsert_google_form_integration(text, text, boolean) from anon;

-- ---------------------------------------------------------------------------
-- Enrollment authority: raw_user_meta_data is user-editable and must never be
-- sufficient evidence that a user is enrolled. Only authoritative DB state or
-- a completed enrollment invitation can activate enrollment.
-- ---------------------------------------------------------------------------
create or replace function public.sync_enrolled_auth_profile(
  target_user_id uuid,
  target_email text,
  target_metadata jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  normalized_metadata jsonb := coalesce(target_metadata, '{}'::jsonb);
  normalized_availability jsonb := '{}'::jsonb;
  authoritative_enrollment_code text;
  has_authoritative_enrollment boolean := false;
begin
  if target_user_id is null then
    return false;
  end if;

  if exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = target_user_id
       or lower(ta.email) = lower(coalesce(target_email, ''))
  ) then
    return false;
  end if;

  select nullif(trim(p.enrollment_code), '')
    into authoritative_enrollment_code
  from public.profiles p
  where p.id = target_user_id
    and coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false
  limit 1;

  if found then
    has_authoritative_enrollment := true;
  end if;

  if not has_authoritative_enrollment then
    select nullif(trim(sei.invite_code), '')
      into authoritative_enrollment_code
    from public.student_enrollment_invites sei
    where sei.status = 'completed'
      and (
        sei.user_id = target_user_id
        or (
          sei.user_id is null
          and coalesce(target_email, '') <> ''
          and lower(coalesce(sei.email, '')) = lower(target_email)
        )
      )
    order by sei.completed_at desc nulls last, sei.created_at desc
    limit 1;

    if found then
      has_authoritative_enrollment := true;
    end if;
  end if;

  if not has_authoritative_enrollment then
    return false;
  end if;

  if jsonb_typeof(normalized_metadata -> 'availability') = 'object' then
    normalized_availability := normalized_metadata -> 'availability';
  end if;

  insert into public.profiles (
    id, name, email, cpf, whatsapp, pix_key, availability,
    enrollment_code, enrolled
  ) values (
    target_user_id,
    nullif(trim(coalesce(normalized_metadata ->> 'name', '')), ''),
    nullif(trim(coalesce(target_email, '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'cpf', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'whatsapp', '')), ''),
    nullif(trim(coalesce(normalized_metadata ->> 'pix_key', '')), ''),
    normalized_availability,
    authoritative_enrollment_code,
    true
  )
  on conflict (id) do update
  set
    name = coalesce(nullif(public.profiles.name, ''), excluded.name),
    email = coalesce(nullif(public.profiles.email, ''), excluded.email),
    cpf = coalesce(nullif(public.profiles.cpf, ''), excluded.cpf),
    whatsapp = coalesce(nullif(public.profiles.whatsapp, ''), excluded.whatsapp),
    pix_key = coalesce(nullif(public.profiles.pix_key, ''), excluded.pix_key),
    availability = case
      when public.profiles.availability is null
        or public.profiles.availability = '{}'::jsonb
      then excluded.availability
      else public.profiles.availability
    end,
    enrollment_code = coalesce(
      nullif(public.profiles.enrollment_code, ''),
      excluded.enrollment_code
    ),
    enrolled = true;

  return true;
end;
$$;

create or replace function public.handle_enrolled_auth_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_enrolled_auth_profile(
    new.id,
    new.email,
    new.raw_user_meta_data
  );
  return new;
end;
$$;

create or replace function public.protect_profile_security_fields()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  requester_email text := nullif(auth.jwt() ->> 'email', '');
begin
  if current_user = 'authenticated'
     and auth.uid() is not null
     and not coalesce(public.is_teacher_admin(), false)
  then
    if tg_op = 'INSERT' then
      new.email := requester_email;
      new.created_at := now();
      new.enrollment_code := null;
      new.enrolled := false;
      new.exercise_schedule_start_date := null;
      new.archived := false;
      new.archived_at := null;
      new.class_type := null;
      new.first_portal_access_at := null;
      new.last_portal_access_at := null;
    elsif tg_op = 'UPDATE' then
      if new.email is distinct from old.email
         or new.created_at is distinct from old.created_at
         or coalesce(new.enrollment_code, '') is distinct from coalesce(old.enrollment_code, '')
         or new.enrolled is distinct from old.enrolled
         or new.exercise_schedule_start_date is distinct from old.exercise_schedule_start_date
         or new.archived is distinct from old.archived
         or new.archived_at is distinct from old.archived_at
         or new.class_type is distinct from old.class_type
         or new.first_portal_access_at is distinct from old.first_portal_access_at
         or new.last_portal_access_at is distinct from old.last_portal_access_at
      then
        raise exception 'Campos administrativos do perfil não podem ser alterados diretamente.'
          using errcode = '42501';
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_security_fields_trigger on public.profiles;
create trigger protect_profile_security_fields_trigger
before insert or update on public.profiles
for each row
execute function public.protect_profile_security_fields();

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles
for insert
to authenticated
with check (
  auth.uid() = id
  and enrolled = false
  and coalesce(enrollment_code, '') = ''
  and coalesce(archived, false) = false
  and archived_at is null
  and class_type is null
  and exercise_schedule_start_date is null
  and first_portal_access_at is null
  and last_portal_access_at is null
);

commit;
