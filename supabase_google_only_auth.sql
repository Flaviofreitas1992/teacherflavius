-- Google-only authentication support.
-- Applied to production on 2026-08-19.

create table if not exists public.student_google_email_aliases (
  google_email text primary key,
  enrollment_email text not null,
  active boolean not null default true,
  note text,
  created_at timestamptz not null default now(),
  constraint student_google_email_aliases_google_email_normalized check (google_email = lower(btrim(google_email))),
  constraint student_google_email_aliases_enrollment_email_normalized check (enrollment_email = lower(btrim(enrollment_email)))
);

alter table public.student_google_email_aliases enable row level security;
revoke all on table public.student_google_email_aliases from public, anon, authenticated;
grant select, insert, update, delete on table public.student_google_email_aliases to service_role;

create unique index if not exists student_google_email_aliases_enrollment_email_uidx
  on public.student_google_email_aliases (enrollment_email)
  where active = true;

create table if not exists public.student_google_account_links (
  google_user_id uuid primary key,
  legacy_user_id uuid not null unique,
  enrollment_email text not null,
  google_email text not null,
  link_mode text not null check (link_mode in ('automatic', 'alias')),
  confirmed_at timestamptz not null default now(),
  legacy_auth_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.student_google_account_links enable row level security;
revoke all on table public.student_google_account_links from public, anon, authenticated;
grant select, insert, update, delete on table public.student_google_account_links to service_role;

insert into public.student_google_email_aliases (google_email, enrollment_email, note)
values
  ('carvalhodamiana306@gmail.com', 'damiana_002@hotmail.com', 'Alias previamente validado na integração de exercícios'),
  ('tesolinjulia@gmail.com', 'tessarijulia2411@gmail.com', 'Alias previamente validado na integração de exercícios')
on conflict (google_email) do update
set enrollment_email = excluded.enrollment_email,
    active = true,
    note = excluded.note;

create or replace function public.get_student_google_link_candidate_internal(
  target_google_user_id uuid,
  target_google_email text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  normalized_google_email text := lower(btrim(coalesce(target_google_email, '')));
  matched_profile public.profiles%rowtype;
  matched_mode text;
begin
  if target_google_user_id is null or normalized_google_email = '' then
    return jsonb_build_object('show_prompt', false, 'reason', 'invalid_user');
  end if;

  if exists (select 1 from public.student_google_account_links l where l.google_user_id = target_google_user_id) then
    return jsonb_build_object('show_prompt', false, 'reason', 'already_confirmed');
  end if;

  select p.* into matched_profile
  from public.profiles p
  where p.id = target_google_user_id
    and p.enrolled = true
    and coalesce(p.archived, false) = false
    and not exists (select 1 from public.teacher_admins ta where ta.user_id = p.id)
  limit 1;

  if found then
    matched_mode := 'automatic';
  else
    select p.* into matched_profile
    from public.student_google_email_aliases a
    join public.profiles p on lower(btrim(coalesce(p.email, ''))) = a.enrollment_email
    where a.google_email = normalized_google_email
      and a.active = true
      and p.enrolled = true
      and coalesce(p.archived, false) = false
      and not exists (select 1 from public.teacher_admins ta where ta.user_id = p.id)
      and not exists (select 1 from public.student_google_account_links l where l.legacy_user_id = p.id)
    limit 1;
    if found then matched_mode := 'alias'; end if;
  end if;

  if matched_profile.id is null then
    return jsonb_build_object('show_prompt', false, 'reason', 'no_match');
  end if;

  return jsonb_build_object(
    'show_prompt', true,
    'mode', matched_mode,
    'legacy_user_id', matched_profile.id,
    'enrollment_email', lower(btrim(coalesce(matched_profile.email, ''))),
    'student_name', coalesce(matched_profile.name, '')
  );
end;
$$;

revoke all on function public.get_student_google_link_candidate_internal(uuid, text) from public, anon, authenticated;
grant execute on function public.get_student_google_link_candidate_internal(uuid, text) to service_role;

create or replace function public.confirm_or_migrate_student_google_link_internal(
  target_google_user_id uuid,
  target_legacy_user_id uuid,
  target_google_email text
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  normalized_google_email text := lower(btrim(coalesce(target_google_email, '')));
  source_profile public.profiles%rowtype;
  ref record;
  mode_value text;
begin
  if target_google_user_id is null or target_legacy_user_id is null or normalized_google_email = '' then
    raise exception 'Dados de vinculação inválidos.';
  end if;

  select p.* into source_profile
  from public.profiles p
  where p.id = target_legacy_user_id
    and p.enrolled = true
    and coalesce(p.archived, false) = false
  for update;

  if source_profile.id is null then raise exception 'Matrícula não encontrada ou inativa.'; end if;
  if exists (select 1 from public.teacher_admins ta where ta.user_id = target_legacy_user_id) then
    raise exception 'Conta administrativa não pode ser migrada por este fluxo.';
  end if;

  if target_google_user_id = target_legacy_user_id then
    mode_value := 'automatic';
    insert into public.student_google_account_links (
      google_user_id, legacy_user_id, enrollment_email, google_email, link_mode, confirmed_at, updated_at
    ) values (
      target_google_user_id, target_legacy_user_id,
      lower(btrim(coalesce(source_profile.email, ''))), normalized_google_email,
      mode_value, now(), now()
    )
    on conflict (google_user_id) do update
    set enrollment_email = excluded.enrollment_email,
        google_email = excluded.google_email,
        link_mode = excluded.link_mode,
        confirmed_at = now(),
        updated_at = now();
    return jsonb_build_object('linked', true, 'mode', mode_value, 'legacy_user_id', target_legacy_user_id);
  end if;

  if not exists (
    select 1 from public.student_google_email_aliases a
    where a.google_email = normalized_google_email
      and a.enrollment_email = lower(btrim(coalesce(source_profile.email, '')))
      and a.active = true
  ) then
    raise exception 'Este e-mail Google não possui alias autorizado para a matrícula encontrada.';
  end if;

  if exists (
    select 1 from public.student_google_account_links l
    where l.legacy_user_id = target_legacy_user_id or l.google_user_id = target_google_user_id
  ) then
    raise exception 'Esta matrícula ou conta Google já foi vinculada.';
  end if;

  if exists (select 1 from public.profiles p where p.id = target_google_user_id and p.enrolled = true) then
    raise exception 'A conta Google já possui outra matrícula ativa.';
  end if;

  delete from public.profiles where id = target_google_user_id and enrolled = false;

  insert into public.profiles
  select (jsonb_populate_record(null::public.profiles, to_jsonb(p) || jsonb_build_object('id', target_google_user_id))).*
  from public.profiles p where p.id = target_legacy_user_id;

  for ref in
    select ns.nspname as schema_name, cls.relname as table_name, att.attname as column_name
    from pg_constraint c
    join pg_class cls on cls.oid = c.conrelid
    join pg_namespace ns on ns.oid = cls.relnamespace
    join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
    join pg_attribute att on att.attrelid = c.conrelid and att.attnum = ck.attnum
    where c.contype = 'f'
      and c.confrelid = 'public.profiles'::regclass
      and ns.nspname = 'public'
      and cls.relname <> 'profiles'
  loop
    execute format('update %I.%I set %I = $1 where %I = $2', ref.schema_name, ref.table_name, ref.column_name, ref.column_name)
      using target_google_user_id, target_legacy_user_id;
  end loop;

  for ref in
    select ns.nspname as schema_name, cls.relname as table_name, att.attname as column_name
    from pg_constraint c
    join pg_class cls on cls.oid = c.conrelid
    join pg_namespace ns on ns.oid = cls.relnamespace
    join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
    join pg_attribute att on att.attrelid = c.conrelid and att.attnum = ck.attnum
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and ns.nspname = 'public'
      and cls.relname not in ('profiles', 'teacher_admins')
  loop
    execute format('update %I.%I set %I = $1 where %I = $2', ref.schema_name, ref.table_name, ref.column_name, ref.column_name)
      using target_google_user_id, target_legacy_user_id;
  end loop;

  delete from public.profiles where id = target_legacy_user_id;

  insert into public.student_google_account_links (
    google_user_id, legacy_user_id, enrollment_email, google_email, link_mode, confirmed_at, updated_at
  ) values (
    target_google_user_id, target_legacy_user_id,
    lower(btrim(coalesce(source_profile.email, ''))), normalized_google_email,
    'alias', now(), now()
  );

  return jsonb_build_object('linked', true, 'mode', 'alias', 'legacy_user_id', target_legacy_user_id);
end;
$$;

revoke all on function public.confirm_or_migrate_student_google_link_internal(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.confirm_or_migrate_student_google_link_internal(uuid, uuid, text) to service_role;

create or replace function public.preserve_linked_student_enrollment_email()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.enrolled = true
     and new.email is distinct from old.email
     and exists (select 1 from public.student_google_account_links l where l.google_user_id = old.id) then
    new.email := old.email;
  end if;
  return new;
end;
$$;

revoke all on function public.preserve_linked_student_enrollment_email() from public, anon, authenticated;

drop trigger if exists preserve_linked_student_enrollment_email_trigger on public.profiles;
create trigger preserve_linked_student_enrollment_email_trigger
before update of email on public.profiles
for each row execute function public.preserve_linked_student_enrollment_email();
