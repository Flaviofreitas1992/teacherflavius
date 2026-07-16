-- Notificacoes por e-mail para novas matriculas.
-- Execute este arquivo no Supabase SQL Editor depois de supabase_mensalidades.sql.
--
-- O envio do e-mail e feito pela Edge Function notify-new-enrollment.
-- Este script somente cria uma fila confiavel e registra nela cada aluno
-- quando public.profiles.enrolled passa de false para true.

create table if not exists public.enrollment_email_notifications (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  last_error text,
  constraint enrollment_email_notifications_student_unique unique (student_id)
);

create index if not exists enrollment_email_notifications_status_idx
  on public.enrollment_email_notifications (status, created_at);

alter table public.enrollment_email_notifications enable row level security;

-- Somente o administrador pode consultar o historico pelo Supabase.
-- O navegador nao pode criar, alterar ou excluir notificacoes.
drop policy if exists "Administrador visualiza notificacoes de matricula"
  on public.enrollment_email_notifications;
create policy "Administrador visualiza notificacoes de matricula"
  on public.enrollment_email_notifications
  for select
  to authenticated
  using (public.is_teacher_admin());

revoke all on public.enrollment_email_notifications from anon, authenticated;
grant select on public.enrollment_email_notifications to authenticated;
grant select, insert, update, delete on public.enrollment_email_notifications to service_role;

create or replace function public.queue_enrollment_email_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  became_enrolled boolean := false;
begin
  if tg_op = 'INSERT' then
    became_enrolled := coalesce(new.enrolled, false);
  elsif tg_op = 'UPDATE' then
    became_enrolled :=
      coalesce(new.enrolled, false)
      and not coalesce(old.enrolled, false);
  end if;

  if became_enrolled and not exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = new.id
       or lower(ta.email) = lower(coalesce(new.email, ''))
  ) then
    insert into public.enrollment_email_notifications (student_id)
    values (new.id)
    on conflict (student_id) do nothing;
  end if;

  return new;
end;
$$;

revoke all on function public.queue_enrollment_email_notification() from public, anon, authenticated;

drop trigger if exists queue_enrollment_email_notification_trigger
  on public.profiles;
create trigger queue_enrollment_email_notification_trigger
  after insert or update of enrolled on public.profiles
  for each row
  execute function public.queue_enrollment_email_notification();

-- Nao ha backfill intencional: alunos que ja estavam matriculados antes da
-- instalacao nao geram e-mails antigos. Apenas matriculas futuras entram na fila.
