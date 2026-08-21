-- Compatibilidade para o botão administrativo de encerramento de aluno.
-- A lógica destrutiva foi centralizada nas migrations de LGPD:
--   20260820231050_add_lgpd_data_subject_request_workflow.sql
--   20260820231557_preserve_financial_history_on_privacy_deletion.sql
--
-- Esta função não apaga diretamente tabelas financeiras. Ela chama a rotina
-- controlada que remove dados operacionais, elimina a autenticação e preserva
-- somente o histórico financeiro necessário, desacoplado do perfil por subject_ref.

create or replace function public.delete_teacher_student(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  return public.close_student_account_for_privacy(target_user_id);
end;
$$;

revoke all on function public.delete_teacher_student(uuid) from public;
revoke all on function public.delete_teacher_student(uuid) from anon;
grant execute on function public.delete_teacher_student(uuid) to authenticated;
