-- Sistema de questionarios internos.
-- Execute no Supabase SQL Editor depois de SUPABASE_SETUP.md e supabase_professor_admin.sql.
-- O gabarito fica protegido no banco e a pontuacao e calculada por funcoes security definer.

create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  definition jsonb not null default '[]'::jsonb,
  is_published boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quizzes_title_length_check check (char_length(title) between 1 and 200),
  constraint quizzes_definition_array_check check (jsonb_typeof(definition) = 'array')
);

create table if not exists public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete restrict,
  student_id uuid not null references auth.users(id) on delete cascade,
  student_name text not null,
  student_email text not null,
  answers jsonb not null default '[]'::jsonb,
  score integer not null check (score >= 0),
  max_score integer not null check (max_score > 0),
  percentage numeric(5,2) not null check (percentage between 0 and 100),
  submitted_at timestamptz not null default now()
);

create index if not exists quizzes_publication_idx
  on public.quizzes (is_active, is_published, published_at desc);

create index if not exists quiz_attempts_quiz_idx
  on public.quiz_attempts (quiz_id, submitted_at desc);

create index if not exists quiz_attempts_student_idx
  on public.quiz_attempts (student_id, submitted_at desc);

alter table public.quizzes enable row level security;
alter table public.quiz_attempts enable row level security;

revoke all on public.quizzes from anon, authenticated;
revoke all on public.quiz_attempts from anon, authenticated;

grant select, insert, update, delete on public.quizzes to service_role;
grant select, insert, update, delete on public.quiz_attempts to service_role;

create or replace function public.set_quizzes_updated_at()
returns trigger
language plpgsql
set search_path = public
as $quiz_updated_at$
begin
  new.updated_at = now();
  return new;
end;
$quiz_updated_at$;

drop trigger if exists set_quizzes_updated_at on public.quizzes;
create trigger set_quizzes_updated_at
before update on public.quizzes
for each row
execute function public.set_quizzes_updated_at();

create or replace function public.is_enrolled_quiz_student()
returns boolean
language sql
security definer
set search_path = public
as $quiz_enrolled$
  select auth.uid() is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and (
          coalesce(p.enrolled, false) = true
          or coalesce(trim(p.enrollment_code), '') <> ''
        )
    );
$quiz_enrolled$;

revoke all on function public.is_enrolled_quiz_student() from public;
grant execute on function public.is_enrolled_quiz_student() to authenticated;

create or replace function public.validate_quiz_definition(target_definition jsonb)
returns boolean
language plpgsql
security definer
set search_path = public
as $quiz_validate$
declare
  item jsonb;
  option_item jsonb;
  item_type text;
  item_id text;
  option_id text;
  seen_item_ids text[] := array[]::text[];
  seen_option_ids text[];
  question_count integer := 0;
  correct_count integer;
  question_points integer;
begin
  if target_definition is null
    or jsonb_typeof(target_definition) <> 'array'
    or jsonb_array_length(target_definition) = 0
  then
    raise exception 'Adicione pelo menos um bloco ao questionario.';
  end if;

  if jsonb_array_length(target_definition) > 100 then
    raise exception 'O questionario pode ter no maximo 100 blocos.';
  end if;

  for item in
    select value from jsonb_array_elements(target_definition)
  loop
    item_type := coalesce(item ->> 'type', '');
    item_id := coalesce(item ->> 'id', '');

    if item_id = '' or char_length(item_id) > 100 then
      raise exception 'Todos os blocos precisam de um identificador valido.';
    end if;

    if item_id = any(seen_item_ids) then
      raise exception 'Existem blocos duplicados no questionario.';
    end if;
    seen_item_ids := array_append(seen_item_ids, item_id);

    if item_type = 'text' then
      if coalesce(trim(item ->> 'content'), '') = '' then
        raise exception 'Preencha o texto de todos os blocos de conteudo.';
      end if;

    elsif item_type = 'video' then
      if coalesce(trim(item ->> 'url'), '') !~* '^https?://' then
        raise exception 'Informe uma URL valida para cada video.';
      end if;

    elsif item_type = 'multiple_choice' then
      question_count := question_count + 1;

      if coalesce(trim(item ->> 'prompt'), '') = '' then
        raise exception 'Preencha o enunciado de todas as perguntas.';
      end if;

      question_points := coalesce(nullif(item ->> 'points', '')::integer, 1);
      if question_points < 1 or question_points > 100 then
        raise exception 'Cada pergunta deve valer entre 1 e 100 pontos.';
      end if;

      if jsonb_typeof(item -> 'options') <> 'array'
        or jsonb_array_length(item -> 'options') < 2
      then
        raise exception 'Cada pergunta precisa de pelo menos duas alternativas.';
      end if;

      seen_option_ids := array[]::text[];
      correct_count := 0;

      for option_item in
        select value from jsonb_array_elements(item -> 'options')
      loop
        option_id := coalesce(option_item ->> 'id', '');

        if option_id = '' or option_id = any(seen_option_ids) then
          raise exception 'As alternativas precisam de identificadores unicos.';
        end if;
        seen_option_ids := array_append(seen_option_ids, option_id);

        if coalesce(trim(option_item ->> 'text'), '') = '' then
          raise exception 'Preencha o texto de todas as alternativas.';
        end if;

        if coalesce((option_item ->> 'correct')::boolean, false) then
          correct_count := correct_count + 1;
        end if;
      end loop;

      if correct_count <> 1 then
        raise exception 'Cada pergunta deve ter exatamente uma resposta correta.';
      end if;

    else
      raise exception 'Tipo de bloco nao reconhecido: %.', item_type;
    end if;
  end loop;

  if question_count = 0 then
    raise exception 'Adicione pelo menos uma pergunta de multipla escolha.';
  end if;

  return true;
end;
$quiz_validate$;

revoke all on function public.validate_quiz_definition(jsonb) from public;

create or replace function public.save_quiz(
  target_quiz_id uuid,
  target_title text,
  target_description text,
  target_definition jsonb,
  target_publish boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $quiz_save$
declare
  saved_id uuid;
  published_time timestamptz;
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  if coalesce(trim(target_title), '') = '' then
    raise exception 'Informe o titulo do questionario.';
  end if;

  if char_length(trim(target_title)) > 200 then
    raise exception 'O titulo pode ter no maximo 200 caracteres.';
  end if;

  perform public.validate_quiz_definition(target_definition);

  if coalesce(target_publish, false) then
    published_time := now();
  else
    published_time := null;
  end if;

  if target_quiz_id is null then
    insert into public.quizzes (
      title,
      description,
      definition,
      is_published,
      is_active,
      created_by,
      published_at
    )
    values (
      trim(target_title),
      nullif(trim(target_description), ''),
      target_definition,
      coalesce(target_publish, false),
      true,
      auth.uid(),
      published_time
    )
    returning id into saved_id;
  else
    update public.quizzes
    set
      title = trim(target_title),
      description = nullif(trim(target_description), ''),
      definition = target_definition,
      is_published = coalesce(target_publish, false),
      published_at = case
        when coalesce(target_publish, false)
          then coalesce(published_at, now())
        else null
      end
    where id = target_quiz_id
      and is_active = true
    returning id into saved_id;

    if saved_id is null then
      raise exception 'Questionario nao encontrado ou arquivado.';
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'quiz_id', saved_id,
    'published', coalesce(target_publish, false)
  );
end;
$quiz_save$;

revoke all on function public.save_quiz(uuid, text, text, jsonb, boolean) from public;
grant execute on function public.save_quiz(uuid, text, text, jsonb, boolean) to authenticated;

create or replace function public.set_quiz_published(
  target_quiz_id uuid,
  target_published boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $quiz_publish$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  update public.quizzes
  set
    is_published = coalesce(target_published, false),
    published_at = case
      when coalesce(target_published, false)
        then coalesce(published_at, now())
      else null
    end
  where id = target_quiz_id
    and is_active = true;

  if not found then
    raise exception 'Questionario nao encontrado ou arquivado.';
  end if;

  return jsonb_build_object(
    'ok', true,
    'quiz_id', target_quiz_id,
    'published', coalesce(target_published, false)
  );
end;
$quiz_publish$;

revoke all on function public.set_quiz_published(uuid, boolean) from public;
grant execute on function public.set_quiz_published(uuid, boolean) to authenticated;

create or replace function public.archive_quiz(target_quiz_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $quiz_archive$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  update public.quizzes
  set is_active = false, is_published = false, published_at = null
  where id = target_quiz_id
    and is_active = true;

  if not found then
    raise exception 'Questionario nao encontrado.';
  end if;

  return jsonb_build_object('ok', true, 'quiz_id', target_quiz_id);
end;
$quiz_archive$;

revoke all on function public.archive_quiz(uuid) from public;
grant execute on function public.archive_quiz(uuid) to authenticated;

drop function if exists public.get_teacher_quizzes();

create function public.get_teacher_quizzes()
returns table (
  quiz_id text,
  quiz_title text,
  quiz_description text,
  quiz_definition jsonb,
  is_published boolean,
  published_at timestamptz,
  question_count integer,
  total_points integer,
  attempt_count integer,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $quiz_teacher_list$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    q.id::text,
    q.title,
    coalesce(q.description, '')::text,
    q.definition,
    q.is_published,
    q.published_at,
    coalesce((
      select count(*)::integer
      from jsonb_array_elements(q.definition) item
      where item ->> 'type' = 'multiple_choice'
    ), 0)::integer,
    coalesce((
      select sum(coalesce(nullif(item ->> 'points', '')::integer, 1))::integer
      from jsonb_array_elements(q.definition) item
      where item ->> 'type' = 'multiple_choice'
    ), 0)::integer,
    (
      select count(*)::integer
      from public.quiz_attempts qa
      where qa.quiz_id = q.id
    ),
    q.created_at,
    q.updated_at
  from public.quizzes q
  where q.is_active = true
  order by q.created_at desc;
end;
$quiz_teacher_list$;

revoke all on function public.get_teacher_quizzes() from public;
grant execute on function public.get_teacher_quizzes() to authenticated;

drop function if exists public.get_published_quizzes();

create function public.get_published_quizzes()
returns table (
  quiz_id text,
  quiz_title text,
  quiz_description text,
  question_count integer,
  total_points integer,
  attempt_count integer,
  best_percentage numeric,
  published_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $quiz_public_list$
begin
  if not public.is_enrolled_quiz_student() then
    raise exception 'Acesso restrito a alunos matriculados.';
  end if;

  return query
  select
    q.id::text,
    q.title,
    coalesce(q.description, '')::text,
    coalesce((
      select count(*)::integer
      from jsonb_array_elements(q.definition) item
      where item ->> 'type' = 'multiple_choice'
    ), 0)::integer,
    coalesce((
      select sum(coalesce(nullif(item ->> 'points', '')::integer, 1))::integer
      from jsonb_array_elements(q.definition) item
      where item ->> 'type' = 'multiple_choice'
    ), 0)::integer,
    (
      select count(*)::integer
      from public.quiz_attempts qa
      where qa.quiz_id = q.id
        and qa.student_id = auth.uid()
    ),
    coalesce((
      select max(qa.percentage)
      from public.quiz_attempts qa
      where qa.quiz_id = q.id
        and qa.student_id = auth.uid()
    ), 0)::numeric,
    q.published_at
  from public.quizzes q
  where q.is_active = true
    and q.is_published = true
  order by q.published_at desc nulls last, q.created_at desc;
end;
$quiz_public_list$;

revoke all on function public.get_published_quizzes() from public;
grant execute on function public.get_published_quizzes() to authenticated;

create or replace function public.get_quiz_for_student(target_quiz_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $quiz_student_view$
declare
  target_quiz public.quizzes%rowtype;
  public_definition jsonb;
begin
  if not public.is_enrolled_quiz_student() then
    raise exception 'Acesso restrito a alunos matriculados.';
  end if;

  select *
  into target_quiz
  from public.quizzes q
  where q.id = target_quiz_id
    and q.is_active = true
    and q.is_published = true;

  if target_quiz.id is null then
    raise exception 'Questionario nao encontrado ou ainda nao publicado.';
  end if;

  select coalesce(
    jsonb_agg(
      case
        when item.value ->> 'type' = 'multiple_choice' then
          (item.value - 'options') ||
          jsonb_build_object(
            'options',
            (
              select coalesce(
                jsonb_agg(option_item.value - 'correct' order by option_item.position),
                '[]'::jsonb
              )
              from jsonb_array_elements(item.value -> 'options')
                with ordinality as option_item(value, position)
            )
          )
        else item.value
      end
      order by item.position
    ),
    '[]'::jsonb
  )
  into public_definition
  from jsonb_array_elements(target_quiz.definition)
    with ordinality as item(value, position);

  return jsonb_build_object(
    'quiz_id', target_quiz.id,
    'title', target_quiz.title,
    'description', coalesce(target_quiz.description, ''),
    'items', public_definition
  );
end;
$quiz_student_view$;

revoke all on function public.get_quiz_for_student(uuid) from public;
grant execute on function public.get_quiz_for_student(uuid) to authenticated;

create or replace function public.submit_quiz_attempt(
  target_quiz_id uuid,
  target_answers jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $quiz_submit$
declare
  target_quiz public.quizzes%rowtype;
  item jsonb;
  selected_option jsonb;
  answer_details jsonb := '[]'::jsonb;
  question_id text;
  selected_option_id text;
  question_prompt text;
  question_required boolean;
  question_points integer;
  earned_score integer := 0;
  maximum_score integer := 0;
  result_percentage numeric(5,2);
  attempt_id uuid;
  target_student_name text;
  target_student_email text;
begin
  if not public.is_enrolled_quiz_student() then
    raise exception 'Acesso restrito a alunos matriculados.';
  end if;

  if target_answers is null or jsonb_typeof(target_answers) <> 'object' then
    raise exception 'As respostas enviadas sao invalidas.';
  end if;

  select *
  into target_quiz
  from public.quizzes q
  where q.id = target_quiz_id
    and q.is_active = true
    and q.is_published = true;

  if target_quiz.id is null then
    raise exception 'Questionario nao encontrado ou ainda nao publicado.';
  end if;

  perform public.validate_quiz_definition(target_quiz.definition);

  for item in
    select value
    from jsonb_array_elements(target_quiz.definition)
    where value ->> 'type' = 'multiple_choice'
  loop
    question_id := item ->> 'id';
    question_prompt := item ->> 'prompt';
    question_points := coalesce(nullif(item ->> 'points', '')::integer, 1);
    question_required := coalesce((item ->> 'required')::boolean, true);
    maximum_score := maximum_score + question_points;
    selected_option_id := target_answers ->> question_id;

    if coalesce(selected_option_id, '') = '' then
      if question_required then
        raise exception 'Responda a pergunta obrigatoria: %', question_prompt;
      end if;
      continue;
    end if;

    selected_option := null;
    select value
    into selected_option
    from jsonb_array_elements(item -> 'options')
    where value ->> 'id' = selected_option_id
    limit 1;

    if selected_option is null then
      raise exception 'Uma das alternativas selecionadas nao pertence ao questionario.';
    end if;

    if coalesce((selected_option ->> 'correct')::boolean, false) then
      earned_score := earned_score + question_points;
    end if;

    answer_details := answer_details || jsonb_build_array(
      jsonb_build_object(
        'question_id', question_id,
        'selected_option_id', selected_option_id,
        'correct', coalesce((selected_option ->> 'correct')::boolean, false),
        'points_awarded', case
          when coalesce((selected_option ->> 'correct')::boolean, false)
            then question_points
          else 0
        end,
        'points_possible', question_points
      )
    );
  end loop;

  if maximum_score <= 0 then
    raise exception 'O questionario nao possui perguntas pontuadas.';
  end if;

  result_percentage := round((earned_score::numeric / maximum_score::numeric) * 100, 2);

  select
    coalesce(nullif(trim(p.name), ''), auth.jwt() ->> 'email', 'Aluno'),
    coalesce(nullif(trim(p.email), ''), auth.jwt() ->> 'email', '')
  into
    target_student_name,
    target_student_email
  from public.profiles p
  where p.id = auth.uid();

  if target_student_name is null then
    target_student_name := coalesce(auth.jwt() ->> 'email', 'Aluno');
  end if;

  if target_student_email is null then
    target_student_email := coalesce(auth.jwt() ->> 'email', '');
  end if;

  insert into public.quiz_attempts (
    quiz_id,
    student_id,
    student_name,
    student_email,
    answers,
    score,
    max_score,
    percentage
  )
  values (
    target_quiz.id,
    auth.uid(),
    target_student_name,
    target_student_email,
    answer_details,
    earned_score,
    maximum_score,
    result_percentage
  )
  returning id into attempt_id;

  return jsonb_build_object(
    'ok', true,
    'attempt_id', attempt_id,
    'score', earned_score,
    'max_score', maximum_score,
    'percentage', result_percentage
  );
end;
$quiz_submit$;

revoke all on function public.submit_quiz_attempt(uuid, jsonb) from public;
grant execute on function public.submit_quiz_attempt(uuid, jsonb) to authenticated;

drop function if exists public.get_my_quiz_attempts(uuid);

create function public.get_my_quiz_attempts(target_quiz_id uuid default null)
returns table (
  attempt_id text,
  quiz_id text,
  quiz_title text,
  score integer,
  max_score integer,
  percentage numeric,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $quiz_my_results$
begin
  if auth.uid() is null then
    raise exception 'Faca login para visualizar seus resultados.';
  end if;

  return query
  select
    qa.id::text,
    qa.quiz_id::text,
    q.title,
    qa.score,
    qa.max_score,
    qa.percentage,
    qa.submitted_at
  from public.quiz_attempts qa
  join public.quizzes q on q.id = qa.quiz_id
  where qa.student_id = auth.uid()
    and (target_quiz_id is null or qa.quiz_id = target_quiz_id)
  order by qa.submitted_at desc;
end;
$quiz_my_results$;

revoke all on function public.get_my_quiz_attempts(uuid) from public;
grant execute on function public.get_my_quiz_attempts(uuid) to authenticated;

drop function if exists public.get_teacher_quiz_results();

create function public.get_teacher_quiz_results()
returns table (
  attempt_id text,
  quiz_id text,
  quiz_title text,
  student_id text,
  student_name text,
  student_email text,
  score integer,
  max_score integer,
  percentage numeric,
  submitted_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $quiz_teacher_results$
begin
  if not public.is_teacher_admin() then
    raise exception 'Acesso negado: usuario nao cadastrado como professor.';
  end if;

  return query
  select
    qa.id::text,
    qa.quiz_id::text,
    q.title,
    qa.student_id::text,
    qa.student_name,
    qa.student_email,
    qa.score,
    qa.max_score,
    qa.percentage,
    qa.submitted_at
  from public.quiz_attempts qa
  join public.quizzes q on q.id = qa.quiz_id
  order by qa.submitted_at desc;
end;
$quiz_teacher_results$;

revoke all on function public.get_teacher_quiz_results() from public;
grant execute on function public.get_teacher_quiz_results() to authenticated;
