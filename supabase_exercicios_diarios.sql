-- Tabela para registrar os exercícios diários concluídos pelos alunos
-- Execute no Supabase em SQL Editor > Run.
-- Este arquivo também cria as funções usadas pela área do professor para
-- visualizar exercícios feitos e acompanhar a obrigação semanal de cada aluno.

create table if not exists public.daily_exercise_completion (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null,
  exercise_title text not null,
  exercise_url text,
  completed boolean not null default false,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, exercise_id)
);

create index if not exists daily_exercise_completion_user_id_idx
  on public.daily_exercise_completion(user_id);

create index if not exists daily_exercise_completion_exercise_id_idx
  on public.daily_exercise_completion(exercise_id);

create index if not exists daily_exercise_completion_weekly_status_idx
  on public.daily_exercise_completion(user_id, completed_at)
  where completed = true;

alter table public.daily_exercise_completion enable row level security;

drop policy if exists "Alunos podem ver seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem ver seus exercícios diários"
  on public.daily_exercise_completion
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Alunos podem inserir seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem inserir seus exercícios diários"
  on public.daily_exercise_completion
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Alunos podem atualizar seus exercícios diários" on public.daily_exercise_completion;
create policy "Alunos podem atualizar seus exercícios diários"
  on public.daily_exercise_completion
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.set_daily_exercise_completion_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_daily_exercise_completion_updated_at on public.daily_exercise_completion;
create trigger set_daily_exercise_completion_updated_at
before update on public.daily_exercise_completion
for each row
execute function public.set_daily_exercise_completion_updated_at();

create or replace function public.is_teacher_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.teacher_admins ta
    where lower(ta.email) = lower(auth.jwt() ->> 'email')
  );
$$;

create or replace function public.get_teacher_daily_exercise_completion()
returns table (
  id text,
  user_id text,
  student_name text,
  student_email text,
  exercise_id text,
  exercise_title text,
  exercise_url text,
  completed boolean,
  completed_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  select
    dec.id::text,
    dec.user_id::text,
    coalesce(p.name, u.raw_user_meta_data ->> 'name', u.email, 'Aluno sem nome')::text as student_name,
    coalesce(p.email, u.email, '')::text as student_email,
    dec.exercise_id,
    dec.exercise_title,
    coalesce(dec.exercise_url, '')::text as exercise_url,
    dec.completed,
    dec.completed_at,
    dec.updated_at
  from public.daily_exercise_completion dec
  left join public.profiles p on p.id = dec.user_id
  left join auth.users u on u.id = dec.user_id
  where dec.completed = true
    and not exists (
      select 1 from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
    )
    and (
      coalesce(p.enrolled, false) = true
      or coalesce(p.enrollment_code, '') <> ''
      or coalesce((u.raw_user_meta_data ->> 'enrolled')::boolean, false) = true
      or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
    )
  order by student_name asc, dec.completed_at desc nulls last, dec.updated_at desc;
end;
$$;

revoke execute on function public.get_teacher_daily_exercise_completion() from public;
revoke execute on function public.get_teacher_daily_exercise_completion() from anon;
grant execute on function public.get_teacher_daily_exercise_completion() to authenticated;

-- Cada aluno possui ciclos individuais de sete dias contados desde a matrícula.
-- Apenas uma conclusão por ciclo dá crédito à semana. O ciclo atual só se torna
-- atrasado depois que seu prazo de sete dias termina.
drop function if exists public.get_teacher_weekly_exercise_status();

create function public.get_teacher_weekly_exercise_status()
returns table (
  user_id text,
  student_name text,
  student_email text,
  enrollment_started_at timestamptz,
  completed_exercises integer,
  credited_weeks integer,
  elapsed_weeks integer,
  overdue_weeks integer,
  current_week_number integer,
  current_week_start timestamptz,
  current_week_due_at timestamptz,
  current_week_completed boolean,
  last_completed_at timestamptz,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.teacher_admins ta
    where lower(ta.email) = lower(auth.jwt() ->> 'email')
  ) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  return query
  with enrolled_students as (
    select
      u.id as student_user_id,
      coalesce(
        nullif(trim(p.name), ''),
        nullif(trim(u.raw_user_meta_data ->> 'name'), ''),
        u.email,
        'Aluno sem nome'
      )::text as resolved_name,
      coalesce(nullif(trim(p.email), ''), u.email, '')::text as resolved_email,
      coalesce(
        (
          select min(sei.completed_at)
          from public.student_enrollment_invites sei
          where sei.user_id = u.id
            and sei.status = 'completed'
            and sei.completed_at is not null
        ),
        p.created_at,
        u.created_at
      ) as enrollment_date
    from auth.users u
    left join public.profiles p on p.id = u.id
    where not exists (
      select 1
      from public.teacher_admins ta
      where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
    )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce(lower(u.raw_user_meta_data ->> 'enrolled') in ('true', 't', '1', 'yes'), false)
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ),
  students_with_weeks as (
    select
      es.*,
      greatest(
        0,
        floor(extract(epoch from (now() - es.enrollment_date)) / 604800)
      )::integer as finished_week_count
    from enrolled_students es
    where es.enrollment_date is not null
  ),
  completion_buckets as (
    select
      sw.student_user_id,
      floor(
        extract(epoch from (dec.completed_at - sw.enrollment_date)) / 604800
      )::integer as week_index,
      dec.completed_at
    from students_with_weeks sw
    join public.daily_exercise_completion dec
      on dec.user_id = sw.student_user_id
     and dec.completed = true
     and dec.completed_at is not null
     and dec.completed_at >= sw.enrollment_date
  ),
  completion_stats as (
    select
      sw.student_user_id,
      count(cb.completed_at)::integer as exercise_count,
      count(distinct cb.week_index) filter (
        where cb.week_index >= 0
          and cb.week_index < sw.finished_week_count
      )::integer as finished_weeks_with_credit,
      coalesce(bool_or(cb.week_index = sw.finished_week_count), false) as active_week_completed,
      max(cb.completed_at) as most_recent_completion
    from students_with_weeks sw
    left join completion_buckets cb on cb.student_user_id = sw.student_user_id
    group by sw.student_user_id
  ),
  calculated as (
    select
      sw.student_user_id,
      sw.resolved_name,
      sw.resolved_email,
      sw.enrollment_date,
      coalesce(cs.exercise_count, 0) as exercise_count,
      coalesce(cs.finished_weeks_with_credit, 0) as finished_weeks_with_credit,
      sw.finished_week_count,
      greatest(sw.finished_week_count - coalesce(cs.finished_weeks_with_credit, 0), 0)::integer as missing_week_count,
      coalesce(cs.active_week_completed, false) as active_week_completed,
      cs.most_recent_completion
    from students_with_weeks sw
    left join completion_stats cs on cs.student_user_id = sw.student_user_id
  )
  select
    c.student_user_id::text as user_id,
    c.resolved_name::text as student_name,
    c.resolved_email::text as student_email,
    c.enrollment_date as enrollment_started_at,
    c.exercise_count::integer as completed_exercises,
    c.finished_weeks_with_credit::integer as credited_weeks,
    c.finished_week_count::integer as elapsed_weeks,
    c.missing_week_count::integer as overdue_weeks,
    (c.finished_week_count + 1)::integer as current_week_number,
    c.enrollment_date + (c.finished_week_count * interval '7 days') as current_week_start,
    c.enrollment_date + ((c.finished_week_count + 1) * interval '7 days') as current_week_due_at,
    c.active_week_completed::boolean as current_week_completed,
    c.most_recent_completion as last_completed_at,
    case
      when c.missing_week_count > 0 then 'late'
      when c.active_week_completed then 'up_to_date'
      else 'current_week_pending'
    end::text as status
  from calculated c
  order by
    case when c.missing_week_count > 0 then 0 when not c.active_week_completed then 1 else 2 end,
    c.missing_week_count desc,
    c.resolved_name asc,
    c.resolved_email asc;
end;
$$;

comment on function public.get_teacher_weekly_exercise_status() is
  'Retorna o acompanhamento semanal dos exercícios de todos os alunos matriculados, em ciclos de sete dias contados desde a matrícula.';

revoke execute on function public.get_teacher_weekly_exercise_status() from public;
revoke execute on function public.get_teacher_weekly_exercise_status() from anon;
grant execute on function public.get_teacher_weekly_exercise_status() to authenticated;
