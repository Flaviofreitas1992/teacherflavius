-- Marca ou desmarca um exercício de um aluno e registra a data da conclusão.

create or replace function public.set_teacher_student_exercise_completion(
  target_user_id uuid,
  target_exercise_id text,
  target_completed boolean,
  target_completed_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_title text;
  target_url text;
  actor_email text;
  effective_completed_at timestamptz;
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

  select te.exercise_title, te.exercise_url
  into target_title, target_url
  from public.teacher_exercises te
  where te.exercise_id = target_exercise_id
    and te.is_active = true
    and (te.scheduled_publish_at is null or te.scheduled_publish_at <= now());

  if target_title is null then
    raise exception 'Exercício publicado não encontrado.';
  end if;

  if target_completed then
    effective_completed_at := target_completed_at;
    if effective_completed_at is null then
      raise exception 'Informe a data em que o exercício foi feito.';
    end if;
    if effective_completed_at > now() + interval '5 minutes' then
      raise exception 'A data de conclusão não pode estar no futuro.';
    end if;
  else
    effective_completed_at := null;
  end if;

  actor_email := nullif(trim(auth.jwt() ->> 'email'), '');

  insert into public.daily_exercise_completion (
    user_id, exercise_id, exercise_title, exercise_url,
    completed, completed_at, completion_source,
    completed_by, completed_by_email, updated_at
  )
  values (
    target_user_id, target_exercise_id, target_title, target_url,
    target_completed, effective_completed_at, 'teacher',
    auth.uid(), actor_email, now()
  )
  on conflict (user_id, exercise_id)
  do update set
    exercise_title = excluded.exercise_title,
    exercise_url = excluded.exercise_url,
    completed = excluded.completed,
    completed_at = excluded.completed_at,
    completion_source = 'teacher',
    completed_by = auth.uid(),
    completed_by_email = actor_email,
    updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'user_id', target_user_id,
    'exercise_id', target_exercise_id,
    'completed', target_completed,
    'completed_at', effective_completed_at,
    'completion_source', 'teacher'
  );
end;
$$;

revoke execute on function public.set_teacher_student_exercise_completion(uuid, text, boolean, timestamptz) from public;
revoke execute on function public.set_teacher_student_exercise_completion(uuid, text, boolean, timestamptz) from anon;
grant execute on function public.set_teacher_student_exercise_completion(uuid, text, boolean, timestamptz) to authenticated;
