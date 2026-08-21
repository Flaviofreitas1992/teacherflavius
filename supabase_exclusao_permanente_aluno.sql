-- Exclusão permanente de aluno pela Área do Professor.
-- Mantém o arquivamento separado em archive_teacher_student(uuid).

create or replace function public.delete_teacher_student(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  target_email text;
  profile_count_before integer := 0;
  deleted_auth_count integer := 0;
  deleted_profile_count integer := 0;
  deleted_invite_count integer := 0;
  deleted_backup_count integer := 0;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  select u.email into target_email
  from auth.users u
  where u.id = target_user_id;

  if exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = target_user_id
       or (target_email is not null and lower(ta.email) = lower(target_email))
  ) then
    raise exception 'Não é permitido excluir uma conta de professor.';
  end if;

  select count(*) into profile_count_before
  from public.profiles p
  where p.id = target_user_id;

  if target_email is null and profile_count_before = 0 then
    raise exception 'Aluno não encontrado.';
  end if;

  if exists (
    select 1
    from storage.objects o
    where o.owner = target_user_id
  ) then
    raise exception 'Este aluno possui arquivos no Storage. Remova os arquivos antes de excluir a conta permanentemente.';
  end if;

  delete from public.student_enrollment_invites
  where user_id = target_user_id;
  get diagnostics deleted_invite_count = row_count;

  if to_regclass('public.backup_student_private_data_20260501') is not null then
    execute 'delete from public.backup_student_private_data_20260501 where user_id = $1'
      using target_user_id;
    get diagnostics deleted_backup_count = row_count;
  end if;

  delete from auth.users
  where id = target_user_id;
  get diagnostics deleted_auth_count = row_count;

  if deleted_auth_count = 0 then
    delete from public.profiles
    where id = target_user_id;
    get diagnostics deleted_profile_count = row_count;
  else
    deleted_profile_count := profile_count_before;
  end if;

  return jsonb_build_object(
    'ok', true,
    'target_user_id', target_user_id,
    'deleted_auth_count', deleted_auth_count,
    'deleted_profile_count', deleted_profile_count,
    'deleted_invite_count', deleted_invite_count,
    'deleted_backup_count', deleted_backup_count
  );
end;
$$;

revoke all on function public.delete_teacher_student(uuid) from public;
revoke all on function public.delete_teacher_student(uuid) from anon;
grant execute on function public.delete_teacher_student(uuid) to authenticated;
