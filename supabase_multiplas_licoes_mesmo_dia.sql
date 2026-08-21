-- Permite duas ou mais lições no mesmo dia para o mesmo aluno.
-- Mantém proteção contra duplicação exata da mesma lição/data e adiciona exclusão administrativa.

drop index if exists public.class_lesson_records_class_user_date_unique_idx;
drop index if exists public.class_lesson_records_class_invite_date_unique_idx;

create unique index if not exists class_lesson_records_class_user_date_lesson_unique_idx
  on public.class_lesson_records(class_number, user_id, class_date, lesson_code)
  where user_id is not null;

create unique index if not exists class_lesson_records_class_invite_date_lesson_unique_idx
  on public.class_lesson_records(class_number, invite_id, class_date, lesson_code)
  where invite_id is not null;

create or replace function public.save_teacher_class_lesson_record_by_ref(
  target_class_number integer,
  target_student_ref_id text,
  target_student_ref_type text,
  target_class_date date,
  target_lesson_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  target_user_id uuid;
  target_invite_id uuid;
  saved_id uuid;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  perform public.assert_teacher_class_exists(target_class_number);

  if nullif(trim(target_student_ref_id), '') is null then
    raise exception 'Aluno inválido: referência vazia.';
  end if;

  if not (
    target_lesson_code ~ '^L([1-9]|[1-6][0-9]|7[0-4])$'
    or target_lesson_code in ('Feriado','Teacher Cancelou','Não compareceu','Conversation','Outras atividades','Problemas técnicos')
  ) then
    raise exception 'Registro inválido. Use L1 a L74 ou uma das opções especiais.';
  end if;

  if target_student_ref_type = 'user' then
    target_user_id := target_student_ref_id::uuid;
    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number and cs.user_id = target_user_id
    ) then
      raise exception 'Este aluno não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records(class_number,user_id,invite_id,class_date,lesson_code)
    values (target_class_number,target_user_id,null,target_class_date,target_lesson_code)
    on conflict (class_number,user_id,class_date,lesson_code) where user_id is not null
    do update set updated_at = now()
    returning id into saved_id;

  elsif target_student_ref_type = 'invite' then
    target_invite_id := target_student_ref_id::uuid;
    if not exists (
      select 1 from public.class_students cs
      where cs.class_number = target_class_number and cs.invite_id = target_invite_id
    ) then
      raise exception 'Esta pré-matrícula não pertence a esta turma.';
    end if;

    insert into public.class_lesson_records(class_number,user_id,invite_id,class_date,lesson_code)
    values (target_class_number,null,target_invite_id,target_class_date,target_lesson_code)
    on conflict (class_number,invite_id,class_date,lesson_code) where invite_id is not null
    do update set updated_at = now()
    returning id into saved_id;
  else
    raise exception 'Tipo de aluno inválido.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', saved_id,
    'class_number', target_class_number,
    'student_ref_id', coalesce(target_user_id::text, target_invite_id::text),
    'student_ref_type', target_student_ref_type,
    'class_date', target_class_date,
    'lesson_code', target_lesson_code
  );
end;
$$;

revoke all on function public.save_teacher_class_lesson_record_by_ref(integer,text,text,date,text) from public, anon;
grant execute on function public.save_teacher_class_lesson_record_by_ref(integer,text,text,date,text) to authenticated, service_role;

create or replace function public.delete_teacher_class_lesson_record(target_record_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  deleted_row public.class_lesson_records%rowtype;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuário não cadastrado como professor.';
  end if;

  delete from public.class_lesson_records
  where id = target_record_id
  returning * into deleted_row;

  if deleted_row.id is null then
    raise exception 'Registro de lição não encontrado.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', deleted_row.id,
    'class_number', deleted_row.class_number,
    'class_date', deleted_row.class_date,
    'lesson_code', deleted_row.lesson_code
  );
end;
$$;

revoke all on function public.delete_teacher_class_lesson_record(uuid) from public, anon;
grant execute on function public.delete_teacher_class_lesson_record(uuid) to authenticated, service_role;
