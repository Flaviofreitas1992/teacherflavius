-- Conclusão automática dos exercícios
-- Aplicado em produção em 2026-08-19.
-- Objetivo: impedir marcação manual e tornar o monitoramento automático a única fonte de novas conclusões.

alter table public.daily_exercise_completion
  drop constraint if exists daily_exercise_completion_source_check;

alter table public.daily_exercise_completion
  add constraint daily_exercise_completion_source_check
  check (completion_source = any (array['student'::text, 'monitor'::text, 'legacy'::text, 'teacher'::text, 'unknown'::text]));

-- Preserva o histórico anterior sem tratá-lo como nova detecção automática.
update public.daily_exercise_completion
set completion_source = 'legacy'
where completion_source = 'student';

alter table public.daily_exercise_completion
  drop constraint daily_exercise_completion_source_check;

alter table public.daily_exercise_completion
  add constraint daily_exercise_completion_source_check
  check (completion_source = any (array['monitor'::text, 'legacy'::text, 'teacher'::text, 'unknown'::text]));

alter table public.daily_exercise_completion
  alter column completion_source set default 'unknown';

-- O aluno pode consultar seu histórico, mas não inserir nem alterar conclusões.
drop policy if exists "Alunos podem inserir seus exercícios diários" on public.daily_exercise_completion;
drop policy if exists "Alunos podem atualizar seus exercícios diários" on public.daily_exercise_completion;

-- A marcação administrativa manual deixa de estar disponível em sessões autenticadas do site.
revoke execute on function public.set_teacher_student_exercise_completion(uuid, text, boolean, timestamptz) from authenticated;
grant execute on function public.set_teacher_student_exercise_completion(uuid, text, boolean, timestamptz) to service_role;

-- Defesa adicional contra gravações feitas por uma sessão autenticada no navegador.
create or replace function public.set_daily_exercise_completion_actor()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if coalesce(auth.jwt() ->> 'role', '') = 'authenticated' then
    raise exception 'A conclusão de exercícios é registrada exclusivamente pelo monitoramento automático.';
  end if;

  if new.completed = false then
    new.completed_at = null;
  end if;

  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_daily_exercise_completion_actor() from public, anon, authenticated;

comment on column public.daily_exercise_completion.completion_source is
  'Origem do registro: monitor para detecção automática; legacy para registros anteriores à automação obrigatória; teacher/unknown apenas para histórico ou manutenção administrativa.';
