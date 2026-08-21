create table if not exists public.app_error_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (event_type in ('javascript','unhandled_promise','resource','api','auth','payment','not_found','client_exception')),
  severity text not null default 'error' check (severity in ('warning','error','critical')),
  message text not null check (char_length(message) between 1 and 2000),
  source text,
  path text,
  stack text,
  error_code text,
  http_status integer check (http_status is null or http_status between 100 and 599),
  http_method text,
  fingerprint text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists app_error_events_created_at_idx on public.app_error_events (created_at desc);
create index if not exists app_error_events_type_created_idx on public.app_error_events (event_type, created_at desc);
create index if not exists app_error_events_unresolved_idx on public.app_error_events (created_at desc) where resolved_at is null;
create index if not exists app_error_events_fingerprint_idx on public.app_error_events (fingerprint, created_at desc) where fingerprint is not null;

alter table public.app_error_events enable row level security;
revoke all on table public.app_error_events from public, anon, authenticated;
grant select on table public.app_error_events to authenticated;
grant update (resolved_at) on table public.app_error_events to authenticated;
grant select, insert, update, delete on table public.app_error_events to service_role;

drop policy if exists "Professor pode consultar erros da aplicação" on public.app_error_events;
create policy "Professor pode consultar erros da aplicação"
  on public.app_error_events for select to authenticated
  using ((select public.is_teacher_admin()));

drop policy if exists "Professor pode resolver erros da aplicação" on public.app_error_events;
create policy "Professor pode resolver erros da aplicação"
  on public.app_error_events for update to authenticated
  using ((select public.is_teacher_admin()))
  with check ((select public.is_teacher_admin()));

comment on table public.app_error_events is
  'Telemetria sanitizada de erros da aplicação. Inserção somente server-side; leitura restrita ao professor via RLS.';

create or replace function public.prune_app_error_events(target_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  deleted_count integer;
begin
  if current_user <> 'service_role' then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;
  if target_days < 7 or target_days > 365 then
    raise exception 'Período de retenção inválido.';
  end if;
  delete from public.app_error_events
  where created_at < now() - make_interval(days => target_days);
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.prune_app_error_events(integer) from public, anon, authenticated;
grant execute on function public.prune_app_error_events(integer) to service_role;
