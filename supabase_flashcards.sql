-- Flashcards do Teacher Flávio
-- Cria conjuntos pessoais para alunos e permite administração individual pelo professor.
-- Execute no projeto Supabase do Teacher Flávio em SQL Editor > Run.

begin;

create table if not exists public.flashcard_decks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text check (description is null or char_length(description) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.flashcards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.flashcard_decks(id) on delete cascade,
  english_word text not null check (char_length(btrim(english_word)) between 1 and 180),
  translation text not null check (char_length(btrim(translation)) between 1 and 300),
  position integer not null default 0 check (position >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (deck_id, position)
);

create index if not exists flashcard_decks_owner_id_idx
  on public.flashcard_decks(owner_id);
create index if not exists flashcards_deck_id_position_idx
  on public.flashcards(deck_id, position);

-- Desativa a função da primeira versão, que possuía compartilhamento geral.
-- A coluna antiga, quando existir, fica sem efeito para preservar compatibilidade.
do $disable_old_flashcard_function$
begin
  if to_regprocedure('public.save_flashcard_deck(uuid,text,text,boolean,jsonb)') is not null then
    execute 'revoke all on function public.save_flashcard_deck(uuid, text, text, boolean, jsonb) from public, anon, authenticated';
  end if;
end;
$disable_old_flashcard_function$;
drop index if exists public.flashcard_decks_shared_updated_idx;

alter table public.flashcard_decks enable row level security;
alter table public.flashcards enable row level security;

drop policy if exists "Usuários podem visualizar conjuntos permitidos" on public.flashcard_decks;
create policy "Usuários podem visualizar conjuntos permitidos"
  on public.flashcard_decks
  for select
  to authenticated
  using (
    owner_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Usuários podem criar seus conjuntos" on public.flashcard_decks;
create policy "Usuários podem criar seus conjuntos"
  on public.flashcard_decks
  for insert
  to authenticated
  with check (
    owner_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Usuários podem atualizar seus conjuntos" on public.flashcard_decks;
create policy "Usuários podem atualizar seus conjuntos"
  on public.flashcard_decks
  for update
  to authenticated
  using (
    owner_id = (select auth.uid())
    or (select public.is_teacher_admin())
  )
  with check (
    owner_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Usuários podem excluir seus conjuntos" on public.flashcard_decks;
create policy "Usuários podem excluir seus conjuntos"
  on public.flashcard_decks
  for delete
  to authenticated
  using (
    owner_id = (select auth.uid())
    or (select public.is_teacher_admin())
  );

drop policy if exists "Usuários podem visualizar cartões permitidos" on public.flashcards;
create policy "Usuários podem visualizar cartões permitidos"
  on public.flashcards
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.flashcard_decks deck
      where deck.id = flashcards.deck_id
        and (
          deck.owner_id = (select auth.uid())
          or (select public.is_teacher_admin())
        )
    )
  );

drop policy if exists "Usuários podem criar cartões nos próprios conjuntos" on public.flashcards;
create policy "Usuários podem criar cartões nos próprios conjuntos"
  on public.flashcards
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.flashcard_decks deck
      where deck.id = flashcards.deck_id
        and (
          deck.owner_id = (select auth.uid())
          or (select public.is_teacher_admin())
        )
    )
  );

drop policy if exists "Usuários podem atualizar cartões dos próprios conjuntos" on public.flashcards;
create policy "Usuários podem atualizar cartões dos próprios conjuntos"
  on public.flashcards
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.flashcard_decks deck
      where deck.id = flashcards.deck_id
        and (
          deck.owner_id = (select auth.uid())
          or (select public.is_teacher_admin())
        )
    )
  )
  with check (
    exists (
      select 1
      from public.flashcard_decks deck
      where deck.id = flashcards.deck_id
        and (
          deck.owner_id = (select auth.uid())
          or (select public.is_teacher_admin())
        )
    )
  );

drop policy if exists "Usuários podem excluir cartões dos próprios conjuntos" on public.flashcards;
create policy "Usuários podem excluir cartões dos próprios conjuntos"
  on public.flashcards
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.flashcard_decks deck
      where deck.id = flashcards.deck_id
        and (
          deck.owner_id = (select auth.uid())
          or (select public.is_teacher_admin())
        )
    )
  );

revoke all on table public.flashcard_decks from anon;
revoke all on table public.flashcards from anon;
grant select, insert, update, delete on table public.flashcard_decks to authenticated;
grant select, insert, update, delete on table public.flashcards to authenticated;

create or replace function public.set_flashcards_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_flashcard_decks_updated_at on public.flashcard_decks;
create trigger set_flashcard_decks_updated_at
before update on public.flashcard_decks
for each row execute function public.set_flashcards_updated_at();

drop trigger if exists set_flashcards_updated_at on public.flashcards;
create trigger set_flashcards_updated_at
before update on public.flashcards
for each row execute function public.set_flashcards_updated_at();

revoke all on function public.set_flashcards_updated_at() from public, anon;

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

    delete from public.flashcards where deck_id = v_deck_id;
  end if;

  insert into public.flashcards (deck_id, english_word, translation, position)
  select
    v_deck_id,
    btrim(card.value ->> 'english_word'),
    btrim(card.value ->> 'translation'),
    (card.ordinality - 1)::integer
  from jsonb_array_elements(p_cards) with ordinality as card(value, ordinality);

  return v_deck_id;
end;
$$;

revoke all on function public.save_flashcard_deck(uuid, uuid, text, text, jsonb) from public, anon;
grant execute on function public.save_flashcard_deck(uuid, uuid, text, text, jsonb) to authenticated;

commit;

-- Verificação rápida: duas tabelas, RLS ativo e políticas apenas para authenticated.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  count(p.policyname) as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policies p on p.schemaname = n.nspname and p.tablename = c.relname
where n.nspname = 'public'
  and c.relname in ('flashcard_decks', 'flashcards')
group by c.relname, c.relrowsecurity
order by c.relname;
