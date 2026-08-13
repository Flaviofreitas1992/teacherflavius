-- Permite excepcionalmente cinco alunos na Turma 36 - THU 21H.
-- Todas as demais turmas continuam com o limite já vigente de quatro alunos.
--
-- Turma identificada de forma estável pelo class_number 73. O bloco inicial
-- confirma o horário atual antes de aplicar a exceção, evitando alterar a
-- turma errada em outra instalação.

do $$
begin
  if not exists (
    select 1
    from public.teacher_classes tc
    where tc.class_number = 73
      and tc.is_active = true
      and tc.class_type = 'quartet'
      and tc.class_weekday = 4
      and tc.class_start_time = time '21:00'
  ) then
    raise exception 'A turma 73 não corresponde ao QUARTETO de quinta-feira às 21h.';
  end if;
end;
$$;

-- Proteção central: cobre inclusão administrativa, pré-matrícula, migração de
-- convite e troca feita pelo aluno. O advisory lock impede que duas inclusões
-- simultâneas ultrapassem o limite.
create or replace function public.enforce_class_students_capacity()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  occupied_count integer;
  capacity_limit integer;
  new_occupies_spot boolean := false;
begin
  if new.class_number is null then
    return new;
  end if;

  capacity_limit := case when new.class_number = 73 then 5 else 4 end;

  perform pg_advisory_xact_lock(73008, new.class_number);

  if new.invite_id is not null then
    new_occupies_spot := true;
  elsif new.user_id is not null then
    select exists (
      select 1
      from public.profiles p
      where p.id = new.user_id
        and coalesce(p.enrolled, false) = true
        and coalesce(p.archived, false) = false
    ) into new_occupies_spot;
  end if;

  if not new_occupies_spot then
    return new;
  end if;

  select count(*)::integer
    into occupied_count
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  where cs.class_number = new.class_number
    and (tg_op <> 'UPDATE' or cs.id <> new.id)
    and (new.user_id is null or cs.user_id is distinct from new.user_id)
    and (new.invite_id is null or cs.invite_id is distinct from new.invite_id)
    and (
      cs.invite_id is not null
      or (
        cs.user_id is not null
        and coalesce(p.enrolled, false) = true
        and coalesce(p.archived, false) = false
      )
    );

  if occupied_count >= capacity_limit then
    raise exception 'Esta turma já atingiu o limite máximo de % alunos.', capacity_limit;
  end if;

  return new;
end;
$$;

revoke execute on function public.enforce_class_students_capacity()
  from public, anon, authenticated;

-- Relatório administrativo de vagas.
create or replace function public.get_group_classes_with_available_spots()
returns table (
  class_number integer,
  class_name text,
  class_weekday smallint,
  class_start_time time without time zone,
  occupied_spots integer,
  available_spots integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  return query
  with class_counts as (
    select
      tc.class_number,
      tc.class_name,
      tc.class_weekday,
      tc.class_start_time,
      case when tc.class_number = 73 then 5 else 4 end::integer as capacity_limit,
      count(cs.id) filter (
        where cs.invite_id is not null
           or (
             cs.user_id is not null
             and coalesce(p.enrolled, false) = true
             and coalesce(p.archived, false) = false
           )
      )::integer as occupied_spots
    from public.teacher_classes tc
    left join public.class_students cs on cs.class_number = tc.class_number
    left join public.profiles p on p.id = cs.user_id
    where tc.is_active = true
      and tc.class_type = 'quartet'
    group by tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time
  )
  select
    cc.class_number,
    cc.class_name,
    cc.class_weekday,
    cc.class_start_time,
    cc.occupied_spots,
    greatest(0, cc.capacity_limit - cc.occupied_spots)::integer
  from class_counts cc
  where cc.occupied_spots < cc.capacity_limit
  order by (cc.capacity_limit - cc.occupied_spots) desc, cc.class_name asc, cc.class_number asc;
end;
$$;

revoke execute on function public.get_group_classes_with_available_spots()
  from public, anon;
grant execute on function public.get_group_classes_with_available_spots()
  to authenticated;

-- Lista de horários oferecida aos alunos.
create or replace function public.get_available_group_classes_for_students()
returns table (
  class_number integer,
  class_name text,
  class_weekday smallint,
  class_start_time time without time zone,
  occupied_spots integer,
  available_spots integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  caller_id uuid := auth.uid();
  caller_class_type text;
  target_db_type text;
  base_capacity integer;
begin
  if caller_id is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;

  select p.class_type into caller_class_type
  from public.profiles p
  where p.id = caller_id
    and coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false;

  if caller_class_type is null then
    raise exception 'Seu tipo de turma ainda não foi definido pelo professor.' using errcode = '42501';
  end if;

  target_db_type := case caller_class_type
    when 'INDIVIDUAL' then 'individual'
    when 'QUARTETO' then 'quartet'
    when '8 ALUNOS' then 'eight_students'
    else null
  end;

  base_capacity := case caller_class_type
    when 'INDIVIDUAL' then 1
    when 'QUARTETO' then 4
    when '8 ALUNOS' then 8
    else null
  end;

  if target_db_type is null or base_capacity is null then
    raise exception 'Tipo de turma inválido no perfil do aluno.';
  end if;

  return query
  with class_counts as (
    select
      tc.class_number,
      tc.class_name,
      tc.class_weekday,
      tc.class_start_time,
      case when tc.class_number = 73 then 5 else base_capacity end::integer as capacity_limit,
      count(cs.id) filter (
        where cs.invite_id is not null
           or (
             cs.user_id is not null
             and coalesce(p.enrolled, false) = true
             and coalesce(p.archived, false) = false
           )
      )::integer as occupied_spots
    from public.teacher_classes tc
    left join public.class_students cs on cs.class_number = tc.class_number
    left join public.profiles p on p.id = cs.user_id
    where tc.is_active = true
      and tc.class_type = target_db_type
      and not exists (
        select 1
        from public.class_students mine
        where mine.user_id = caller_id
          and mine.class_number = tc.class_number
      )
    group by tc.class_number, tc.class_name, tc.class_weekday, tc.class_start_time
  )
  select
    cc.class_number,
    cc.class_name,
    cc.class_weekday,
    cc.class_start_time,
    cc.occupied_spots,
    greatest(0, cc.capacity_limit - cc.occupied_spots)::integer
  from class_counts cc
  where cc.occupied_spots < cc.capacity_limit
  order by (cc.capacity_limit - cc.occupied_spots) desc, cc.class_name asc, cc.class_number asc;
end;
$$;

revoke execute on function public.get_available_group_classes_for_students()
  from public, anon;
grant execute on function public.get_available_group_classes_for_students()
  to authenticated;

-- Troca de turma iniciada pelo aluno.
create or replace function public.switch_my_group_class(target_class_number integer)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  caller_id uuid := auth.uid();
  old_class_number integer;
  occupied_count integer;
  caller_class_type text;
  target_db_type text;
  capacity integer;
begin
  if caller_id is null then
    raise exception 'Autenticação necessária.' using errcode = '42501';
  end if;

  select p.class_type into caller_class_type
  from public.profiles p
  where p.id = caller_id
    and coalesce(p.enrolled, false) = true
    and coalesce(p.archived, false) = false;

  if caller_class_type is null then
    raise exception 'Seu tipo de turma ainda não foi definido pelo professor.' using errcode = '42501';
  end if;

  target_db_type := case caller_class_type
    when 'INDIVIDUAL' then 'individual'
    when 'QUARTETO' then 'quartet'
    when '8 ALUNOS' then 'eight_students'
    else null
  end;

  capacity := case caller_class_type
    when 'INDIVIDUAL' then 1
    when 'QUARTETO' then 4
    when '8 ALUNOS' then 8
    else null
  end;

  if target_db_type is null or capacity is null then
    raise exception 'Tipo de turma inválido no perfil do aluno.';
  end if;

  select cs.class_number into old_class_number
  from public.class_students cs
  where cs.user_id = caller_id
  limit 1;

  if old_class_number = target_class_number then
    return jsonb_build_object(
      'ok', true,
      'changed', false,
      'old_class_number', old_class_number,
      'new_class_number', target_class_number
    );
  end if;

  perform 1
  from public.teacher_classes tc
  where tc.class_number = target_class_number
    and tc.is_active = true
    and tc.class_type = target_db_type
  for update;

  if not found then
    raise exception 'Esta turma não é compatível com o seu tipo de turma.';
  end if;

  if target_class_number = 73 then
    capacity := 5;
  end if;

  perform pg_advisory_xact_lock(73007, target_class_number);

  select count(*)::integer into occupied_count
  from public.class_students cs
  left join public.profiles p on p.id = cs.user_id
  where cs.class_number = target_class_number
    and (
      cs.invite_id is not null
      or (
        cs.user_id is not null
        and coalesce(p.enrolled, false) = true
        and coalesce(p.archived, false) = false
      )
    );

  if occupied_count >= capacity then
    raise exception 'Esta turma não possui mais vagas.';
  end if;

  delete from public.class_students where user_id = caller_id;

  insert into public.class_students (class_number, user_id, invite_id)
  values (target_class_number, caller_id, null);

  return jsonb_build_object(
    'ok', true,
    'changed', true,
    'old_class_number', old_class_number,
    'new_class_number', target_class_number,
    'available_spots_after_change', capacity - occupied_count - 1
  );
end;
$$;

revoke execute on function public.switch_my_group_class(integer)
  from public, anon;
grant execute on function public.switch_my_group_class(integer)
  to authenticated;

