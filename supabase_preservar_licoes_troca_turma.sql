-- Preserva e exibe o histórico de lições quando um aluno muda de turma.
-- Execute no Supabase em SQL Editor > Run.
-- Execute depois de supabase_licoes_pre_matriculas_fix.sql.
--
-- Os registros continuam guardando a turma em que cada aula ocorreu,
-- mas a página da turma passa a consultar o histórico completo dos alunos
-- que atualmente pertencem à turma selecionada.

create or replace function public.get_teacher_class_lesson_records(target_class_number integer)
returns table (
  id text,
  class_number integer,
  user_id text,
  invite_id text,
  student_ref_id text,
  student_ref_type text,
  class_date date,
  lesson_code text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $preserve_lesson_history$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  return query
  select
    clr.id::text,
    clr.class_number,
    clr.user_id::text,
    clr.invite_id::text,
    coalesce(clr.user_id::text, clr.invite_id::text) as student_ref_id,
    case when clr.user_id is not null then 'user' else 'invite' end::text as student_ref_type,
    clr.class_date,
    clr.lesson_code,
    clr.created_at,
    clr.updated_at
  from public.class_lesson_records clr
  where exists (
    select 1
    from public.class_students cs
    where cs.class_number = target_class_number
      and (
        (clr.user_id is not null and cs.user_id = clr.user_id)
        or
        (clr.invite_id is not null and cs.invite_id = clr.invite_id)
      )
  )
  order by clr.class_date desc, clr.created_at desc;
end;
$preserve_lesson_history$;

grant execute on function public.get_teacher_class_lesson_records(integer) to authenticated;
