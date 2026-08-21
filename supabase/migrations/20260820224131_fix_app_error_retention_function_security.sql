create or replace function public.prune_app_error_events(target_days integer default 90)
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  deleted_count integer;
begin
  if target_days < 7 or target_days > 365 then
    raise exception 'Período de retenção inválido.';
  end if;
  delete from public.app_error_events
  where created_at < now() - make_interval(days => target_days);
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.prune_app_error_events(integer) from public, anon, authenticated;
grant execute on function public.prune_app_error_events(integer) to service_role;
