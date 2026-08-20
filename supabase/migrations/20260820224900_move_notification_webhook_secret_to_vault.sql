-- Keep the enrollment notification webhook secret out of trigger definitions.
-- The secret itself is intentionally not committed. Provision or restore it in
-- Supabase Vault under the name below before relying on notifications.

create or replace function public.dispatch_enrollment_notification_webhook()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  webhook_secret text;
begin
  select ds.decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets as ds
  where ds.name = 'teacherflavius_notification_webhook_secret'
  limit 1;

  if nullif(webhook_secret, '') is null then
    raise warning 'Enrollment notification webhook secret is unavailable';
    return new;
  end if;

  perform net.http_post(
    url := 'https://wnigzpvgsbpjdxvjzugt.supabase.co/functions/v1/notify-new-enrollment',
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    ),
    params := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', webhook_secret
    ),
    timeout_milliseconds := 5000
  );

  return new;
end;
$$;

revoke all on function public.dispatch_enrollment_notification_webhook() from public;
revoke all on function public.dispatch_enrollment_notification_webhook() from anon;
revoke all on function public.dispatch_enrollment_notification_webhook() from authenticated;

drop trigger if exists "notify-new-enrollment" on public.enrollment_email_notifications;

create trigger "notify-new-enrollment"
after insert on public.enrollment_email_notifications
for each row
execute function public.dispatch_enrollment_notification_webhook();
