-- Prevent first-login profile completion from failing when enrollment_code is blank.
-- Blank/whitespace-only values are semantically "no enrollment code" and must be NULL,
-- so the partial unique index on non-NULL enrollment codes does not reject new profiles.

create or replace function public.normalize_profile_enrollment_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.enrollment_code is not null then
    new.enrollment_code := nullif(btrim(new.enrollment_code), '');
  end if;
  return new;
end;
$$;

drop trigger if exists normalize_profile_enrollment_code_before_write on public.profiles;

create trigger normalize_profile_enrollment_code_before_write
before insert or update of enrollment_code on public.profiles
for each row
execute function public.normalize_profile_enrollment_code();

update public.profiles
set enrollment_code = null
where enrollment_code is not null
  and btrim(enrollment_code) = '';
