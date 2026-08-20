-- Application-specific default privileges for objects created by postgres in public.
-- Supabase-managed default ACLs in auth/storage/extensions/etc. are intentionally not duplicated here.

alter default privileges for role postgres in schema public
  grant all on tables to anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  grant all on sequences to anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

alter default privileges for role postgres in schema public
  grant execute on functions to service_role;
