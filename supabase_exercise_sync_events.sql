-- Histórico de eventos da sincronização atual dos exercícios.
-- Cada POST processado por google-forms-exercise-sync gera um evento.

create table if not exists public.exercise_sync_events (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),
  status text not null check (
    status in (
      'processed',
      'unmatched_student',
      'ambiguous_email',
      'not_enrolled',
      'exercise_not_found',
      'invalid_payload',
      'error'
    )
  ),
  exercise_id text,
  exercise_title text,
  source_email text,
  normalized_email text,
  user_id uuid references auth.users(id) on delete set null,
  student_name text,
  submitted_completed_at timestamptz,
  stored_completed_at timestamptz,
  record_action text check (
    record_action is null
    or record_action in (
      'inserted',
      'confirmed_existing',
      'updated_earlier_completion'
    )
  ),
  error_message text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists exercise_sync_events_received_at_idx
  on public.exercise_sync_events(received_at desc);

create index if not exists exercise_sync_events_user_id_idx
  on public.exercise_sync_events(user_id, received_at desc);

create index if not exists exercise_sync_events_exercise_id_idx
  on public.exercise_sync_events(exercise_id, received_at desc);

create index if not exists exercise_sync_events_status_idx
  on public.exercise_sync_events(status, received_at desc);

alter table public.exercise_sync_events enable row level security;

drop policy if exists "Professor pode visualizar eventos de sincronizacao"
  on public.exercise_sync_events;

create policy "Professor pode visualizar eventos de sincronizacao"
  on public.exercise_sync_events
  for select
  to authenticated
  using ((select public.is_teacher_admin()));

revoke all on public.exercise_sync_events from anon;
revoke insert, update, delete on public.exercise_sync_events from authenticated;
grant select on public.exercise_sync_events to authenticated;
grant all on public.exercise_sync_events to service_role;
