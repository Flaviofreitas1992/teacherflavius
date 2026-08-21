-- Treat a completed first-login Google onboarding as a real student enrollment.
-- Google creates a provisional profile with enrolled=false; after the student completes
-- all enrollment fields, the profile must become enrolled and receive an enrollment code.

create or replace function public.activate_completed_google_student_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  provider_name text;
  candidate_code text;
begin
  select u.raw_app_meta_data ->> 'provider'
    into provider_name
  from auth.users u
  where u.id = new.id;

  if coalesce(new.profile_completed, false) = true
     and coalesce(new.enrolled, false) = false
     and provider_name = 'google'
     and not exists (
       select 1
       from public.teacher_admins ta
       where ta.user_id = new.id
          or lower(ta.email) = lower(coalesce(new.email, ''))
     ) then
    new.enrolled := true;

    if nullif(btrim(new.enrollment_code), '') is null then
      loop
        candidate_code := upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 5));
        exit when not exists (
          select 1
          from public.profiles p
          where p.enrollment_code = candidate_code
            and p.id <> new.id
        );
      end loop;
      new.enrollment_code := candidate_code;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists activate_completed_google_student_profile_before_write on public.profiles;

create trigger activate_completed_google_student_profile_before_write
before insert or update of profile_completed, enrolled, enrollment_code, email on public.profiles
for each row
execute function public.activate_completed_google_student_profile();

-- Repair already-completed Google student profiles created before this fix.
-- Rewriting profile_completed invokes the trigger without hardcoding user IDs.
update public.profiles p
set profile_completed = p.profile_completed
where coalesce(p.profile_completed, false) = true
  and coalesce(p.enrolled, false) = false
  and exists (
    select 1
    from auth.users u
    where u.id = p.id
      and u.raw_app_meta_data ->> 'provider' = 'google'
  )
  and not exists (
    select 1
    from public.teacher_admins ta
    where ta.user_id = p.id
       or lower(ta.email) = lower(coalesce(p.email, ''))
  );
