-- Painel de acessos dos alunos
-- Execute este arquivo no Supabase em SQL Editor > Run depois de publicar o código do site.
--
-- Privacidade:
--   * registra apenas alunos autenticados;
--   * não armazena endereço IP nem parâmetros da URL;
--   * localização é opcional, depende de consentimento e é arredondada;
--   * somente professores cadastrados em teacher_admins consultam os registros;
--   * os registros são mantidos por no máximo 90 dias.

create extension if not exists pgcrypto;

create table if not exists public.student_access_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  consent_decided boolean not null default false,
  location_consent boolean not null default false,
  consented_at timestamptz,
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.student_access_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  accessed_at timestamptz not null default now(),
  page_path text not null,
  page_title text,
  timezone text,
  latitude numeric(5,2),
  longitude numeric(6,2),
  location_accuracy_meters integer,
  location_status text not null default 'not_shared',
  constraint student_access_logs_latitude_check
    check (latitude is null or latitude between -90 and 90),
  constraint student_access_logs_longitude_check
    check (longitude is null or longitude between -180 and 180),
  constraint student_access_logs_accuracy_check
    check (location_accuracy_meters is null or location_accuracy_meters between 0 and 100000),
  constraint student_access_logs_status_check
    check (location_status in ('granted', 'not_shared', 'denied', 'unavailable', 'error'))
);

create index if not exists student_access_logs_user_accessed_idx
  on public.student_access_logs (user_id, accessed_at desc);

create index if not exists student_access_logs_accessed_idx
  on public.student_access_logs (accessed_at desc);

create index if not exists student_access_logs_page_idx
  on public.student_access_logs (page_path);

alter table public.student_access_preferences enable row level security;
alter table public.student_access_logs enable row level security;

-- O acesso às tabelas é feito exclusivamente pelas funções abaixo.
revoke all on table public.student_access_preferences from anon, authenticated;
revoke all on table public.student_access_logs from anon, authenticated;

create or replace function public.get_my_student_access_preference()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  requester_id uuid;
  preference_row public.student_access_preferences%rowtype;
begin
  requester_id := auth.uid();

  if requester_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select *
  into preference_row
  from public.student_access_preferences sap
  where sap.user_id = requester_id;

  if not found then
    return jsonb_build_object(
      'consent_decided', false,
      'location_consent', false,
      'consented_at', null,
      'revoked_at', null
    );
  end if;

  return jsonb_build_object(
    'consent_decided', preference_row.consent_decided,
    'location_consent', preference_row.location_consent,
    'consented_at', preference_row.consented_at,
    'revoked_at', preference_row.revoked_at
  );
end;
$function$;

create or replace function public.save_my_student_location_preference(
  target_consent boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  requester_id uuid;
  consent_value boolean;
  saved_row public.student_access_preferences%rowtype;
begin
  requester_id := auth.uid();
  consent_value := coalesce(target_consent, false);

  if requester_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  insert into public.student_access_preferences as sap (
    user_id,
    consent_decided,
    location_consent,
    consented_at,
    revoked_at,
    updated_at
  )
  values (
    requester_id,
    true,
    consent_value,
    case when consent_value then now() else null end,
    case when consent_value then null else now() end,
    now()
  )
  on conflict (user_id) do update
  set
    consent_decided = true,
    location_consent = consent_value,
    consented_at = case
      when consent_value then now()
      else sap.consented_at
    end,
    revoked_at = case
      when consent_value then null
      else now()
    end,
    updated_at = now()
  returning * into saved_row;

  if not consent_value then
    update public.student_access_logs sal
    set
      latitude = null,
      longitude = null,
      location_accuracy_meters = null,
      location_status = 'not_shared'
    where sal.user_id = requester_id;
  end if;

  return jsonb_build_object(
    'consent_decided', saved_row.consent_decided,
    'location_consent', saved_row.location_consent,
    'consented_at', saved_row.consented_at,
    'revoked_at', saved_row.revoked_at
  );
end;
$function$;

create or replace function public.log_student_page_access(
  target_page_path text,
  target_page_title text default null,
  target_timezone text default null,
  target_latitude double precision default null,
  target_longitude double precision default null,
  target_accuracy double precision default null,
  target_location_status text default 'not_shared'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  requester_id uuid;
  requester_email text;
  safe_page_path text;
  safe_status text;
  has_location_consent boolean;
  safe_latitude numeric(5,2);
  safe_longitude numeric(6,2);
  safe_accuracy integer;
  inserted_id uuid;
begin
  requester_id := auth.uid();
  requester_email := auth.jwt() ->> 'email';

  if requester_id is null then
    return jsonb_build_object('logged', false, 'reason', 'not_authenticated');
  end if;

  if exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(coalesce(requester_email, ''))
       or ta.user_id = requester_id
  ) then
    return jsonb_build_object('logged', false, 'reason', 'teacher');
  end if;

  safe_page_path := split_part(
    split_part(coalesce(nullif(trim(target_page_path), ''), '/'), '?', 1),
    '#',
    1
  );
  safe_page_path := left(safe_page_path, 300);

  if left(safe_page_path, 1) <> '/' then
    safe_page_path := '/' || safe_page_path;
  end if;

  safe_status := case
    when target_location_status in ('granted', 'not_shared', 'denied', 'unavailable', 'error')
      then target_location_status
    else 'error'
  end;

  select coalesce(sap.location_consent, false)
  into has_location_consent
  from public.student_access_preferences sap
  where sap.user_id = requester_id;

  has_location_consent := coalesce(has_location_consent, false);

  if has_location_consent
     and target_latitude between -90 and 90
     and target_longitude between -180 and 180 then
    safe_latitude := round(target_latitude::numeric, 2);
    safe_longitude := round(target_longitude::numeric, 2);
    safe_accuracy := least(100000, greatest(0, round(coalesce(target_accuracy, 0))::integer));
    safe_status := 'granted';
  else
    safe_latitude := null;
    safe_longitude := null;
    safe_accuracy := null;
    if safe_status = 'granted' then
      safe_status := 'not_shared';
    end if;
  end if;

  -- Limpeza automática da retenção de 90 dias.
  delete from public.student_access_logs sal
  where sal.accessed_at < now() - interval '90 days';

  insert into public.student_access_logs (
    user_id,
    page_path,
    page_title,
    timezone,
    latitude,
    longitude,
    location_accuracy_meters,
    location_status
  )
  values (
    requester_id,
    safe_page_path,
    left(nullif(trim(target_page_title), ''), 200),
    left(nullif(trim(target_timezone), ''), 100),
    safe_latitude,
    safe_longitude,
    safe_accuracy,
    safe_status
  )
  returning id into inserted_id;

  return jsonb_build_object(
    'logged', true,
    'access_id', inserted_id,
    'location_status', safe_status
  );
end;
$function$;

create or replace function public.update_my_student_access_location(
  target_access_id uuid,
  target_latitude double precision default null,
  target_longitude double precision default null,
  target_accuracy double precision default null,
  target_location_status text default 'not_shared'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  requester_id uuid;
  safe_status text;
  has_location_consent boolean;
  updated_count integer;
begin
  requester_id := auth.uid();

  if requester_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  select coalesce(sap.location_consent, false)
  into has_location_consent
  from public.student_access_preferences sap
  where sap.user_id = requester_id;

  has_location_consent := coalesce(has_location_consent, false);
  safe_status := case
    when target_location_status in ('granted', 'not_shared', 'denied', 'unavailable', 'error')
      then target_location_status
    else 'error'
  end;

  if has_location_consent
     and target_latitude between -90 and 90
     and target_longitude between -180 and 180 then
    safe_status := 'granted';
    update public.student_access_logs sal
    set
      latitude = round(target_latitude::numeric, 2),
      longitude = round(target_longitude::numeric, 2),
      location_accuracy_meters = least(
        100000,
        greatest(0, round(coalesce(target_accuracy, 0))::integer)
      ),
      location_status = 'granted'
    where sal.id = target_access_id
      and sal.user_id = requester_id;
  else
    if safe_status = 'granted' then
      safe_status := 'not_shared';
    end if;

    update public.student_access_logs sal
    set
      latitude = null,
      longitude = null,
      location_accuracy_meters = null,
      location_status = safe_status
    where sal.id = target_access_id
      and sal.user_id = requester_id;
  end if;

  get diagnostics updated_count = row_count;

  return jsonb_build_object(
    'updated', updated_count = 1,
    'location_status', safe_status
  );
end;
$function$;

drop function if exists public.get_teacher_student_accesses(integer, uuid);

create function public.get_teacher_student_accesses(
  target_days integer default 30,
  target_user_id uuid default null
)
returns table (
  log_id uuid,
  user_id uuid,
  student_name text,
  student_email text,
  accessed_at timestamptz,
  page_path text,
  page_title text,
  timezone text,
  latitude numeric,
  longitude numeric,
  location_accuracy_meters integer,
  location_status text
)
language plpgsql
security definer
set search_path = public, auth
as $function$
declare
  requester_email text;
  safe_days integer;
  period_start timestamptz;
begin
  requester_email := auth.jwt() ->> 'email';

  if requester_email is null or not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(requester_email)
       or ta.user_id = auth.uid()
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  safe_days := greatest(1, least(coalesce(target_days, 30), 90));
  period_start := now() - (safe_days::text || ' days')::interval;

  return query
  select
    sal.id as log_id,
    sal.user_id,
    coalesce(
      nullif(trim(p.name), ''),
      nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
      split_part(coalesce(u.email, 'Aluno'), '@', 1)
    )::text as student_name,
    coalesce(nullif(trim(p.email), ''), u.email, '')::text as student_email,
    sal.accessed_at,
    sal.page_path,
    sal.page_title,
    sal.timezone,
    sal.latitude,
    sal.longitude,
    sal.location_accuracy_meters,
    sal.location_status
  from public.student_access_logs sal
  join auth.users u on u.id = sal.user_id
  left join public.profiles p on p.id = sal.user_id
  where sal.accessed_at >= period_start
    and (target_user_id is null or sal.user_id = target_user_id)
    and not exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(u.email, ''))
         or ta.user_id = u.id
    )
  order by sal.accessed_at desc
  limit 2000;
end;
$function$;

revoke all on function public.get_my_student_access_preference() from public, anon;
revoke all on function public.save_my_student_location_preference(boolean) from public, anon;
revoke all on function public.log_student_page_access(text, text, text, double precision, double precision, double precision, text) from public, anon;
revoke all on function public.update_my_student_access_location(uuid, double precision, double precision, double precision, text) from public, anon;
revoke all on function public.get_teacher_student_accesses(integer, uuid) from public, anon;

grant execute on function public.get_my_student_access_preference() to authenticated;
grant execute on function public.save_my_student_location_preference(boolean) to authenticated;
grant execute on function public.log_student_page_access(text, text, text, double precision, double precision, double precision, text) to authenticated;
grant execute on function public.update_my_student_access_location(uuid, double precision, double precision, double precision, text) to authenticated;
grant execute on function public.get_teacher_student_accesses(integer, uuid) to authenticated;
