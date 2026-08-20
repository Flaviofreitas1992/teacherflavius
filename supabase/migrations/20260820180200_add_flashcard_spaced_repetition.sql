-- Repetição espaçada para os flashcards do Teacher Flávio.
-- Preserva os IDs dos cartões ao editar conjuntos para não perder o progresso SRS.

begin;

create table if not exists public.flashcard_srs (
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null references public.flashcards(id) on delete cascade,
  ease_factor numeric(4,2) not null default 2.50 check (ease_factor between 1.30 and 3.50),
  interval_days integer not null default 0 check (interval_days >= 0),
  repetitions integer not null default 0 check (repetitions >= 0),
  lapses integer not null default 0 check (lapses >= 0),
  due_date date not null default ((now() at time zone 'America/Sao_Paulo')::date),
  last_grade text check (last_grade is null or last_grade in ('again', 'hard', 'good', 'easy')),
  last_reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, card_id)
);

create table if not exists public.flashcard_review_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_id uuid not null references public.flashcards(id) on delete cascade,
  grade text not null check (grade in ('again', 'hard', 'good', 'easy')),
  reviewed_at timestamptz not null default now(),
  interval_days_after integer not null check (interval_days_after >= 0),
  due_date_after date not null,
  ease_factor_after numeric(4,2) not null check (ease_factor_after between 1.30 and 3.50),
  repetitions_after integer not null check (repetitions_after >= 0)
);

create index if not exists flashcard_srs_user_due_idx
  on public.flashcard_srs(user_id, due_date);
create index if not exists flashcard_srs_card_idx
  on public.flashcard_srs(card_id);
create index if not exists flashcard_review_history_user_reviewed_idx
  on public.flashcard_review_history(user_id, reviewed_at desc);
create index if not exists flashcard_review_history_card_reviewed_idx
  on public.flashcard_review_history(card_id, reviewed_at desc);

alter table public.flashcard_srs enable row level security;
alter table public.flashcard_review_history enable row level security;

drop policy if exists "Alunos e professor podem visualizar progresso SRS" on public.flashcard_srs;
create policy "Alunos e professor podem visualizar progresso SRS"
  on public.flashcard_srs
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Alunos podem criar o próprio progresso SRS" on public.flashcard_srs;
create policy "Alunos podem criar o próprio progresso SRS"
  on public.flashcard_srs
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.flashcards card
      join public.flashcard_decks deck on deck.id = card.deck_id
      where card.id = flashcard_srs.card_id
        and deck.owner_id = (select auth.uid())
    )
  );

drop policy if exists "Alunos podem atualizar o próprio progresso SRS" on public.flashcard_srs;
create policy "Alunos podem atualizar o próprio progresso SRS"
  on public.flashcard_srs
  for update
  to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.flashcards card
      join public.flashcard_decks deck on deck.id = card.deck_id
      where card.id = flashcard_srs.card_id
        and deck.owner_id = (select auth.uid())
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.flashcards card
      join public.flashcard_decks deck on deck.id = card.deck_id
      where card.id = flashcard_srs.card_id
        and deck.owner_id = (select auth.uid())
    )
  );

drop policy if exists "Alunos e professor podem visualizar histórico SRS" on public.flashcard_review_history;
create policy "Alunos e professor podem visualizar histórico SRS"
  on public.flashcard_review_history
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Alunos podem registrar o próprio histórico SRS" on public.flashcard_review_history;
create policy "Alunos podem registrar o próprio histórico SRS"
  on public.flashcard_review_history
  for insert
  to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1
      from public.flashcards card
      join public.flashcard_decks deck on deck.id = card.deck_id
      where card.id = flashcard_review_history.card_id
        and deck.owner_id = (select auth.uid())
    )
  );

revoke all on table public.flashcard_srs from anon;
revoke all on table public.flashcard_review_history from anon;
revoke all on table public.flashcard_srs from authenticated;
revoke all on table public.flashcard_review_history from authenticated;
grant select, insert, update on table public.flashcard_srs to authenticated;
grant select, insert on table public.flashcard_review_history to authenticated;

drop trigger if exists set_flashcard_srs_updated_at on public.flashcard_srs;
create trigger set_flashcard_srs_updated_at
before update on public.flashcard_srs
for each row execute function public.set_flashcards_updated_at();

create or replace function public.save_flashcard_deck(
  p_deck_id uuid,
  p_owner_id uuid,
  p_title text,
  p_description text,
  p_cards jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_deck_id uuid;
  v_owner_id uuid;
  v_changed integer;
  v_is_teacher boolean;
  v_card record;
  v_card_id uuid;
  v_keep_ids uuid[] := array[]::uuid[];
begin
  if (select auth.uid()) is null then
    raise exception 'Usuário não autenticado.';
  end if;

  v_is_teacher := (select public.is_teacher_admin());

  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 120 then
    raise exception 'O nome do conjunto deve ter entre 1 e 120 caracteres.';
  end if;

  if char_length(coalesce(p_description, '')) > 500 then
    raise exception 'A descrição deve ter no máximo 500 caracteres.';
  end if;

  if p_cards is null or jsonb_typeof(p_cards) <> 'array'
     or jsonb_array_length(p_cards) not between 1 and 200 then
    raise exception 'O conjunto deve ter entre 1 e 200 cartões.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_cards) as card(value)
    where char_length(btrim(coalesce(card.value ->> 'english_word', ''))) not between 1 and 180
       or char_length(btrim(coalesce(card.value ->> 'translation', ''))) not between 1 and 300
  ) then
    raise exception 'Todos os cartões precisam de uma palavra em inglês e uma tradução válidas.';
  end if;

  if p_deck_id is not null and exists (
    select 1
    from jsonb_array_elements(p_cards) as card(value)
    where nullif(card.value ->> 'id', '') is not null
    group by card.value ->> 'id'
    having count(*) > 1
  ) then
    raise exception 'Um mesmo cartão não pode aparecer duas vezes no conjunto.';
  end if;

  if p_deck_id is null then
    v_owner_id := coalesce(p_owner_id, (select auth.uid()));

    if v_owner_id <> (select auth.uid()) and not v_is_teacher then
      raise exception 'Somente o professor pode criar um conjunto para outro aluno.';
    end if;

    insert into public.flashcard_decks (owner_id, title, description)
    values (
      v_owner_id,
      btrim(p_title),
      nullif(btrim(coalesce(p_description, '')), '')
    )
    returning id into v_deck_id;
  else
    update public.flashcard_decks
    set title = btrim(p_title),
        description = nullif(btrim(coalesce(p_description, '')), '')
    where id = p_deck_id
      and (
        owner_id = (select auth.uid())
        or v_is_teacher
      )
    returning id, owner_id into v_deck_id, v_owner_id;

    get diagnostics v_changed = row_count;
    if v_changed <> 1 then
      raise exception 'Conjunto não encontrado ou acesso negado.';
    end if;

    if p_owner_id is not null and p_owner_id <> v_owner_id then
      raise exception 'O proprietário de um conjunto existente não pode ser alterado.';
    end if;

    -- Libera as posições atuais antes da reordenação para preservar IDs sem violar a chave única.
    update public.flashcards
    set position = position + 1000
    where deck_id = v_deck_id;
  end if;

  for v_card in
    select card.value, card.ordinality
    from jsonb_array_elements(p_cards) with ordinality as card(value, ordinality)
    order by card.ordinality
  loop
    v_card_id := null;

    if p_deck_id is not null and nullif(v_card.value ->> 'id', '') is not null then
      begin
        v_card_id := (v_card.value ->> 'id')::uuid;
      exception when invalid_text_representation then
        raise exception 'Identificador de cartão inválido.';
      end;
    end if;

    if v_card_id is not null then
      update public.flashcards
      set english_word = btrim(v_card.value ->> 'english_word'),
          translation = btrim(v_card.value ->> 'translation'),
          position = (v_card.ordinality - 1)::integer
      where id = v_card_id
        and deck_id = v_deck_id;

      get diagnostics v_changed = row_count;
      if v_changed <> 1 then
        raise exception 'Cartão não encontrado neste conjunto.';
      end if;
    else
      insert into public.flashcards (deck_id, english_word, translation, position)
      values (
        v_deck_id,
        btrim(v_card.value ->> 'english_word'),
        btrim(v_card.value ->> 'translation'),
        (v_card.ordinality - 1)::integer
      )
      returning id into v_card_id;
    end if;

    v_keep_ids := array_append(v_keep_ids, v_card_id);
  end loop;

  if p_deck_id is not null then
    delete from public.flashcards
    where deck_id = v_deck_id
      and not (id = any(v_keep_ids));
  end if;

  return v_deck_id;
end;
$$;

revoke all on function public.save_flashcard_deck(uuid, uuid, text, text, jsonb) from public, anon;
grant execute on function public.save_flashcard_deck(uuid, uuid, text, text, jsonb) to authenticated;

create or replace function public.record_flashcard_review(
  p_card_id uuid,
  p_grade text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_user_id uuid := (select auth.uid());
  v_owner_id uuid;
  v_interval integer := 0;
  v_repetitions integer := 0;
  v_lapses integer := 0;
  v_ease numeric(4,2) := 2.50;
  v_due date;
  v_existing boolean := false;
begin
  if v_user_id is null then
    raise exception 'Usuário não autenticado.';
  end if;

  if p_grade not in ('again', 'hard', 'good', 'easy') then
    raise exception 'Avaliação SRS inválida.';
  end if;

  select deck.owner_id
  into v_owner_id
  from public.flashcards card
  join public.flashcard_decks deck on deck.id = card.deck_id
  where card.id = p_card_id;

  if v_owner_id is null then
    raise exception 'Cartão não encontrado.';
  end if;

  if v_owner_id <> v_user_id then
    raise exception 'Somente o aluno proprietário pode alterar a agenda deste cartão.';
  end if;

  select interval_days, repetitions, lapses, ease_factor
  into v_interval, v_repetitions, v_lapses, v_ease
  from public.flashcard_srs
  where user_id = v_user_id
    and card_id = p_card_id
  for update;

  v_existing := found;
  if not v_existing then
    v_interval := 0;
    v_repetitions := 0;
    v_lapses := 0;
    v_ease := 2.50;
  end if;

  case p_grade
    when 'again' then
      v_interval := 0;
      v_repetitions := 0;
      v_lapses := v_lapses + 1;
      v_ease := greatest(1.30, v_ease - 0.20);
      v_due := v_today;
    when 'hard' then
      if v_repetitions = 0 then
        v_interval := 1;
      else
        v_interval := greatest(1, ceil(v_interval * 1.20)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_ease := greatest(1.30, v_ease - 0.15);
      v_due := v_today + v_interval;
    when 'good' then
      if v_repetitions = 0 then
        v_interval := 1;
      elsif v_repetitions = 1 then
        v_interval := 3;
      else
        v_interval := greatest(1, round(v_interval * v_ease)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_due := v_today + v_interval;
    when 'easy' then
      if v_repetitions = 0 then
        v_interval := 4;
      elsif v_repetitions = 1 then
        v_interval := 7;
      else
        v_interval := greatest(1, round(v_interval * v_ease * 1.30)::integer);
      end if;
      v_repetitions := v_repetitions + 1;
      v_ease := least(3.50, v_ease + 0.15);
      v_due := v_today + v_interval;
  end case;

  insert into public.flashcard_srs (
    user_id, card_id, ease_factor, interval_days, repetitions, lapses,
    due_date, last_grade, last_reviewed_at
  )
  values (
    v_user_id, p_card_id, v_ease, v_interval, v_repetitions, v_lapses,
    v_due, p_grade, now()
  )
  on conflict (user_id, card_id) do update
  set ease_factor = excluded.ease_factor,
      interval_days = excluded.interval_days,
      repetitions = excluded.repetitions,
      lapses = excluded.lapses,
      due_date = excluded.due_date,
      last_grade = excluded.last_grade,
      last_reviewed_at = excluded.last_reviewed_at,
      updated_at = now();

  insert into public.flashcard_review_history (
    user_id, card_id, grade, interval_days_after, due_date_after,
    ease_factor_after, repetitions_after
  )
  values (
    v_user_id, p_card_id, p_grade, v_interval, v_due,
    v_ease, v_repetitions
  );

  return jsonb_build_object(
    'card_id', p_card_id,
    'user_id', v_user_id,
    'grade', p_grade,
    'due_date', v_due,
    'interval_days', v_interval,
    'repetitions', v_repetitions,
    'lapses', v_lapses,
    'ease_factor', v_ease,
    'last_reviewed_at', now()
  );
end;
$$;

revoke all on function public.record_flashcard_review(uuid, text) from public, anon;
grant execute on function public.record_flashcard_review(uuid, text) to authenticated;

-- Os cartões atuais começam devidos hoje; cartões novos sem linha SRS também são tratados como devidos pelo frontend.
insert into public.flashcard_srs (user_id, card_id, due_date)
select deck.owner_id, card.id, (now() at time zone 'America/Sao_Paulo')::date
from public.flashcards card
join public.flashcard_decks deck on deck.id = card.deck_id
on conflict (user_id, card_id) do nothing;

commit;
