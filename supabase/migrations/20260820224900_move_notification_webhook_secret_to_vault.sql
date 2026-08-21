do $$
declare
  existing_secret text;
  trigger_definition text;
begin
  if not exists (
    select 1
    from vault.decrypted_secrets
    where name = 'teacherflavius_notification_webhook_secret'
  ) then
    select pg_get_triggerdef(t.oid, true)
      into trigger_definition
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'enrollment_email_notifications'
      and t.tgname = 'notify-new-enrollment';

    existing_secret := (regexp_match(
      coalesce(trigger_definition, ''),
      '"x-webhook-secret":"([^"]+)"'
    ))[1];

    if nullif(existing_secret, '') is null then
      raise exception 'Unable to recover existing notification webhook secret';
    end if;

    perform vault.create_secret(
      existing_secret,
      'teacherflavius_notification_webhook_secret',
      'Shared secret used by database notification webhooks'
    );
  end if;
end;
$$;

drop trigger if exists "notify-new-enrollment" on public.enrollment_email_notifications;
drop trigger if exists "notify-makeup-booking" on public.makeup_class_email_notifications;

create or replace function public.dispatch_enrollment_notification_webhook()
returns trigger
language plpgsql
security definer
set search_path = 'pg_catalog', 'public', 'pg_temp'
as $$
declare
  webhook_secret text;
begin
  select ds.decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets ds
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

create or replace function public.dispatch_makeup_notification_webhook()
returns trigger
language plpgsql
security definer
set search_path = 'pg_catalog', 'public', 'pg_temp'
as $$
declare
  webhook_secret text;
begin
  select ds.decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets ds
  where ds.name = 'teacherflavius_notification_webhook_secret'
  limit 1;

  if nullif(webhook_secret, '') is null then
    raise warning 'Makeup notification webhook secret is unavailable';
    return new;
  end if;

  perform net.http_post(
    url := 'https://wnigzpvgsbpjdxvjzugt.supabase.co/functions/v1/notify-makeup-booking',
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
    timeout_milliseconds := 10000
  );

  return new;
end;
$$;

revoke all on function public.dispatch_enrollment_notification_webhook() from public, anon, authenticated, service_role;
revoke all on function public.dispatch_makeup_notification_webhook() from public, anon, authenticated, service_role;

create trigger "notify-new-enrollment"
after insert on public.enrollment_email_notifications
for each row execute function public.dispatch_enrollment_notification_webhook();

create trigger "notify-makeup-booking"
after insert on public.makeup_class_email_notifications
for each row execute function public.dispatch_makeup_notification_webhook();