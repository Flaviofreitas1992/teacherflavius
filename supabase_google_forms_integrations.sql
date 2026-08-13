-- Integração Google Forms gerenciada pela Área do Professor.
-- Requer public.teacher_exercises e public.is_teacher_admin(), já existentes no projeto.

create table if not exists public.exercise_form_sources (
  id uuid primary key default gen_random_uuid(),
  exercise_id text not null references public.teacher_exercises(exercise_id) on delete cascade,
  spreadsheet_id text not null,
  spreadsheet_url text not null,
  import_existing boolean not null default true,
  status text not null default 'pending'
    check (status in ('pending','active','error','disconnect_requested','disconnected')),
  created_by uuid references auth.users(id) on delete set null,
  trigger_created_at timestamptz,
  historical_sync_at timestamptz,
  historical_processed integer not null default 0,
  historical_unmatched integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_form_sources_exercise_unique unique (exercise_id),
  constraint exercise_form_sources_spreadsheet_unique unique (spreadsheet_id)
);

alter table public.exercise_form_sources enable row level security;
revoke all on table public.exercise_form_sources from anon, authenticated;

create or replace function public.get_google_form_integrations()
returns table (
  id uuid,
  exercise_id text,
  exercise_title text,
  spreadsheet_id text,
  spreadsheet_url text,
  import_existing boolean,
  status text,
  trigger_created_at timestamptz,
  historical_sync_at timestamptz,
  historical_processed integer,
  historical_unmatched integer,
  last_error text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  return query
  select s.id, s.exercise_id, e.exercise_title, s.spreadsheet_id, s.spreadsheet_url,
    s.import_existing, s.status, s.trigger_created_at, s.historical_sync_at,
    s.historical_processed, s.historical_unmatched, s.last_error, s.created_at, s.updated_at
  from public.exercise_form_sources s
  join public.teacher_exercises e on e.exercise_id = s.exercise_id
  order by s.created_at desc;
end;
$$;

create or replace function public.upsert_google_form_integration(
  target_exercise_id text,
  target_spreadsheet_url text,
  target_import_existing boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  normalized_url text := trim(coalesce(target_spreadsheet_url, ''));
  parsed_spreadsheet_id text;
  result_id uuid;
  conflicting_exercise text;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso restrito ao professor';
  end if;

  if not exists (select 1 from public.teacher_exercises where exercise_id = trim(coalesce(target_exercise_id, ''))) then
    raise exception 'Exercício não encontrado';
  end if;

  parsed_spreadsheet_id := substring(normalized_url from 'docs\.google\.com/spreadsheets/d/([A-Za-z0-9_-]+)');
  if parsed_spreadsheet_id is null or parsed_spreadsheet_id = '' then
    raise exception 'URL de planilha do Google Sheets inválida';
  end if;

  select exercise_id into conflicting_exercise
  from public.exercise_form_sources
  where spreadsheet_id = parsed_spreadsheet_id and exercise_id <> trim(target_exercise_id)
  limit 1;

  if conflicting_exercise is not null then
    raise exception 'Esta planilha já está vinculada a outro exercício';
  end if;

  insert into public.exercise_form_sources (
    exercise_id, spreadsheet_id, spreadsheet_url, import_existing, status, created_by, last_error, updated_at
  ) values (
    trim(target_exercise_id), parsed_spreadsheet_id, normalized_url,
    coalesce(target_import_existing, true), 'pending', auth.uid(), null, now()
  )
  on conflict (exercise_id) do update set
    spreadsheet_id = excluded.spreadsheet_id,
    spreadsheet_url = excluded.spreadsheet_url,
    import_existing = excluded.import_existing,
    status = 'pending',
    created_by = auth.uid(),
    last_error = null,
    historical_processed = 0,
    historical_unmatched = 0,
    historical_sync_at = null,
    trigger_created_at = null,
    updated_at = now()
  returning id into result_id;

  return result_id;
end;
$$;

create or replace function public.retry_google_form_integration(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then raise exception 'Acesso restrito ao professor'; end if;
  update public.exercise_form_sources set status = 'pending', last_error = null, updated_at = now() where id = target_id;
  if not found then raise exception 'Integração não encontrada'; end if;
end;
$$;

create or replace function public.disconnect_google_form_integration(target_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then raise exception 'Acesso restrito ao professor'; end if;
  update public.exercise_form_sources set status = 'disconnect_requested', last_error = null, updated_at = now() where id = target_id;
  if not found then raise exception 'Integração não encontrada'; end if;
end;
$$;

grant execute on function public.get_google_form_integrations() to authenticated;
grant execute on function public.upsert_google_form_integration(text,text,boolean) to authenticated;
grant execute on function public.retry_google_form_integration(uuid) to authenticated;
grant execute on function public.disconnect_google_form_integration(uuid) to authenticated;

insert into public.exercise_form_sources (
  exercise_id, spreadsheet_id, spreadsheet_url, import_existing, status,
  trigger_created_at, historical_sync_at, historical_processed, historical_unmatched
) values
(
  'teacher-atividade-10-reading-1783695401330',
  '1yoUK91aWgj7dUY1wnXEeaGzS3C6eyVO-WtjBe_VkPqg',
  'https://docs.google.com/spreadsheets/d/1yoUK91aWgj7dUY1wnXEeaGzS3C6eyVO-WtjBe_VkPqg/edit',
  true, 'active', now(), now(), 12, 49
),
(
  'teacher-atividade-11-writing-1783695459094',
  '1MPV0A1WUrCt3WeBP_xeBN8yJpkBIj_itlwouIJstWCo',
  'https://docs.google.com/spreadsheets/d/1MPV0A1WUrCt3WeBP_xeBN8yJpkBIj_itlwouIJstWCo/edit',
  true, 'active', now(), now(), 7, 24
)
on conflict do nothing;
