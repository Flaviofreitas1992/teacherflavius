create or replace function public.perform_data_retention_maintenance(p_trigger_source text default 'cron')
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_run_id uuid;
  policy_row public.data_retention_policies%rowtype;
  v_deleted_count integer;
  v_deleted_counts jsonb := '{}'::jsonb;
  normalized_source text := lower(btrim(coalesce(p_trigger_source, 'cron')));
  v_error_text text;
begin
  if normalized_source not in ('cron','manual') then
    raise exception 'Origem de execução inválida.' using errcode = '22023';
  end if;

  insert into public.data_retention_runs (trigger_source, status)
  values (normalized_source, 'running')
  returning id into v_run_id;

  if not pg_try_advisory_xact_lock(731955421) then
    update public.data_retention_runs r
       set status = 'skipped', completed_at = now(), error_message = 'Outra execução de retenção já estava em andamento.'
     where r.id = v_run_id;
    return jsonb_build_object('ok', true, 'status', 'skipped', 'run_id', v_run_id);
  end if;

  begin
    for policy_row in
      select * from public.data_retention_policies
       where enabled = true
         and automatic_purge = true
         and retention_days is not null
         and source_table is not null
         and timestamp_column is not null
       order by dataset
    loop
      if to_regclass(format('public.%I', policy_row.source_table)) is null then
        raise exception 'Tabela configurada para retenção não encontrada: %', policy_row.source_table;
      end if;

      execute format(
        'delete from public.%I where %I < now() - make_interval(days => $1)',
        policy_row.source_table,
        policy_row.timestamp_column
      ) using policy_row.retention_days;
      get diagnostics v_deleted_count = row_count;
      v_deleted_counts := v_deleted_counts || jsonb_build_object(policy_row.dataset, v_deleted_count);
    end loop;

    delete from public.data_retention_runs r
     where r.id <> v_run_id
       and r.started_at < now() - interval '365 days';

    update public.data_retention_runs r
       set status = 'completed',
           completed_at = now(),
           deleted_counts = v_deleted_counts,
           error_message = null
     where r.id = v_run_id;

    return jsonb_build_object('ok', true, 'status', 'completed', 'run_id', v_run_id, 'deleted_counts', v_deleted_counts);
  exception when others then
    v_error_text := left(sqlerrm, 4000);
    update public.data_retention_runs r
       set status = 'failed',
           completed_at = now(),
           deleted_counts = v_deleted_counts,
           error_message = v_error_text
     where r.id = v_run_id;

    if to_regclass('public.app_error_events') is not null then
      begin
        insert into public.app_error_events (
          event_type, severity, message, source, path, fingerprint, metadata, occurred_at
        ) values (
          'data_retention_failure', 'error', v_error_text, 'database', 'cron:data-retention',
          md5('data_retention_failure:' || v_error_text),
          jsonb_build_object('run_id', v_run_id, 'trigger_source', normalized_source), now()
        );
      exception when others then
        null;
      end;
    end if;

    return jsonb_build_object('ok', false, 'status', 'failed', 'run_id', v_run_id, 'deleted_counts', v_deleted_counts, 'error', v_error_text);
  end;
end;
$$;

revoke all on function public.perform_data_retention_maintenance(text) from public;
revoke all on function public.perform_data_retention_maintenance(text) from anon;
revoke all on function public.perform_data_retention_maintenance(text) from authenticated;