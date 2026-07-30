-- Painel de acessos dos alunos
-- Execute este arquivo no Supabase em SQL Editor > Run.
--
-- Registra somente:
--   * aluno autenticado;
--   * data e hora;
--   * caminho e título da página;
--   * fuso horário do navegador.
--
-- Não registra localização, endereço IP nem parâmetros da URL.
-- Somente professores cadastrados em teacher_admins consultam os registros.
-- Os registros são mantidos por no máximo 90 dias.

create extension if not exists pgcrypto;

-- Remove a versão anterior do recurso de localização, caso ela tenha sido executada.
drop function if exists public.get_my_student_access_preference();
drop function if exists public.save_my_student_location_preference(boolean);
drop function if exists public.update_my_student_access_location(
  uuid,
  double precision,
  double precision,
  double precision,
  text
);
drop function if exists public.log_student_page_access(
  text,
  text,
  text,
  double precision,
  double precision,
  double precision,
  text
);
drop function if exists public.log_student_page_access(text, text, text);
drop function if exists public.get_teacher_student_accesses(integer, uuid);

drop table if exists public.student_access_preferences;

create table if not exists public.student_access_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  accessed_at timestamptz not null default now(),
  page_path text not null,
  page_title text,
  timezone text
);

-- Garante que nenhum dado de localização permaneça se uma versão anterior foi usada.
alter table public.student_access_logs
  drop column if exists latitude,
  drop column if exists longitude,
  drop column if exists location_accuracy_meters,
  drop column if exists location_status;

create index if not exists student_access_logs_user_accessed_idx
  on public.student_access_logs (user_id, accessed_at desc);

create index if not exists student_access_logs_accessed_idx
  on public.student_access_logs (accessed_at desc);

create index if not exists student_access_logs_page_idx
  on public.student_access_logs (page_path);

alter table public.student_access_logs enable row level security;

-- O acesso à tabela é feito exclusivamente pelas funções abaixo.
revoke all on table public.student_access_logs from anon, authenticated;

create function public.log_student_page_access(
  target_page_path text,
  target_page_title text default null,
  target_timezone text default null
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

  -- Limpeza automática da retenção de 90 dias.
  delete from public.student_access_logs sal
  where sal.accessed_at < now() - interval '90 days';

  insert into public.student_access_logs (
    user_id,
    page_path,
    page_title,
    timezone
  )
  values (
    requester_id,
    safe_page_path,
    left(nullif(trim(target_page_title), ''), 200),
    left(nullif(trim(target_timezone), ''), 100)
  )
  returning id into inserted_id;

  return jsonb_build_object(
    'logged', true,
    'access_id', inserted_id
  );
end;
$function$;

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
  timezone text
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
    sal.timezone
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

revoke all on function public.log_student_page_access(text, text, text) from public, anon;
revoke all on function public.get_teacher_student_accesses(integer, uuid) from public, anon;

grant execute on function public.log_student_page_access(text, text, text) to authenticated;
grant execute on function public.get_teacher_student_accesses(integer, uuid) to authenticated;
