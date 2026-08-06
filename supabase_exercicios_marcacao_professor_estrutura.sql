-- Auditoria da conclusão dos exercícios.

alter table public.daily_exercise_completion
  add column if not exists completion_source text not null default 'student',
  add column if not exists completed_by uuid references auth.users(id) on delete set null,
  add column if not exists completed_by_email text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'daily_exercise_completion_source_check'
      and conrelid = 'public.daily_exercise_completion'::regclass
  ) then
    alter table public.daily_exercise_completion
      add constraint daily_exercise_completion_source_check
      check (completion_source in ('student', 'teacher'));
  end if;
end;
$$;

update public.daily_exercise_completion
set completion_source = 'student',
    completed_by = coalesce(completed_by, user_id)
where completed_by is null;

create index if not exists daily_exercise_completion_source_idx
  on public.daily_exercise_completion(completion_source);

create or replace function public.set_daily_exercise_completion_actor()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is not null and auth.uid() = new.user_id then
    new.completion_source = 'student';
    new.completed_by = auth.uid();
    new.completed_by_email = nullif(trim(auth.jwt() ->> 'email'), '');
  end if;

  if new.completed = false then
    new.completed_at = null;
  end if;

  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_daily_exercise_completion_actor
  on public.daily_exercise_completion;
create trigger set_daily_exercise_completion_actor
before insert or update on public.daily_exercise_completion
for each row
execute function public.set_daily_exercise_completion_actor();
