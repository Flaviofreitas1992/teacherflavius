-- Prevent new identity duplicates without mutating the existing CPF anomaly.

create unique index if not exists profiles_email_normalized_uidx
  on public.profiles (lower(btrim(email)))
  where nullif(btrim(email), '') is not null;

create or replace function public.prevent_new_duplicate_profile_cpf()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  new_cpf text := regexp_replace(coalesce(new.cpf, ''), '\D', '', 'g');
  old_cpf text;
begin
  if new_cpf = '' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    old_cpf := regexp_replace(coalesce(old.cpf, ''), '\D', '', 'g');
    if new_cpf = old_cpf then
      return new;
    end if;
  end if;

  if exists (
    select 1
    from public.profiles p
    where p.id <> new.id
      and regexp_replace(coalesce(p.cpf, ''), '\D', '', 'g') = new_cpf
  ) then
    raise exception 'Já existe outro perfil com este CPF.' using errcode = '23505';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_new_duplicate_profile_cpf() from public, anon, authenticated;

drop trigger if exists profiles_prevent_new_duplicate_cpf on public.profiles;
create trigger profiles_prevent_new_duplicate_cpf
before insert or update of cpf on public.profiles
for each row
execute function public.prevent_new_duplicate_profile_cpf();
