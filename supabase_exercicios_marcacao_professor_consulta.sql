-- Lista os exercícios publicados e o estado de conclusão de um aluno.

create or replace function public.get_teacher_student_exercise_completion(
  target_user_id uuid
)
returns table (
  exercise_id text,
  exercise_title text,
  exercise_url text,
  completed boolean,
  completed_at timestamptz,
  completion_source text,
  completed_by_email text,
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

  if not exists (
    select 1
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = target_user_id
      and not exists (
        select 1 from public.teacher_admins ta
        where lower(ta.email) = lower(coalesce(p.email, u.email, ''))
      )
      and (
        coalesce(p.enrolled, false) = true
        or coalesce(p.enrollment_code, '') <> ''
        or coalesce(lower(u.raw_user_meta_data ->> 'enrolled') in ('true', 't', '1', 'yes'), false)
        or coalesce(u.raw_user_meta_data ->> 'enrollment_code', '') <> ''
      )
  ) then
    raise exception 'Aluno matriculado não encontrado.';
  end if;

  return query
  select
    te.exercise_id,
    te.exercise_title,
    te.exercise_url,
    coalesce(dec.completed, false),
    dec.completed_at,
    coalesce(dec.completion_source, 'student')::text,
    coalesce(dec.completed_by_email, '')::text,
    dec.updated_at
  from public.teacher_exercises te
  left join public.daily_exercise_completion dec
    on dec.user_id = target_user_id
   and dec.exercise_id = te.exercise_id
  where te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now())
  order by coalesce(te.scheduled_publish_at, te.created_at) asc, te.created_at asc;
end;
$$;

revoke execute on function public.get_teacher_student_exercise_completion(uuid) from public;
revoke execute on function public.get_teacher_student_exercise_completion(uuid) from anon;
grant execute on function public.get_teacher_student_exercise_completion(uuid) to authenticated;
