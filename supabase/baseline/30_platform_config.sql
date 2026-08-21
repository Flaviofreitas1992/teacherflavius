-- Database-backed Supabase platform configuration not represented by the public schema dump.
-- Safe to run after 10_public_schema.sql.

-- Required extensions used by application-owned automation.
create extension if not exists pg_cron with schema pg_catalog;

-- Recreate the one application-owned Cron job if it does not already exist.
do $$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'sync-auto-makeup-slots-30-days'
  ) then
    perform cron.schedule(
      'sync-auto-makeup-slots-30-days',
      '15 6 * * *',
      'select public.sync_auto_makeup_slots_30_days();'
    );
  end if;
end;
$$;

-- Vault values are intentionally NOT versioned.
-- A restored environment must create a secret named:
--   teacherflavius_notification_webhook_secret
-- with the same value configured in the notification Edge Functions.

-- Current production inventory at baseline time:
-- Storage buckets: none.
-- Custom storage RLS policies: none.
