create table if not exists public.data_retention_policies (
  dataset text primary key,
  category text not null,
  source_table text,
  timestamp_column text,
  retention_days integer,
  automatic_purge boolean not null default false,
  enabled boolean not null default true,
  rationale text not null,
  last_reviewed_at timestamptz not null default now(),
  next_review_at date,
  constraint data_retention_policies_days_check check (retention_days is null or retention_days between 1 and 3650),
  constraint data_retention_policies_auto_requires_source check (
    automatic_purge = false or (source_table is not null and timestamp_column is not null and retention_days is not null)
  )
);

alter table public.data_retention_policies enable row level security;
revoke all on table public.data_retention_policies from public;
revoke all on table public.data_retention_policies from anon;
revoke all on table public.data_retention_policies from authenticated;
grant select on table public.data_retention_policies to authenticated;

drop policy if exists "teacher_reads_data_retention_policies" on public.data_retention_policies;
create policy "teacher_reads_data_retention_policies"
  on public.data_retention_policies
  for select to authenticated
  using (coalesce(public.is_teacher_admin(), false));

insert into public.data_retention_policies (
  dataset, category, source_table, timestamp_column, retention_days, automatic_purge, enabled, rationale, next_review_at
) values
  ('student_access_logs', 'operational', 'student_access_logs', 'accessed_at', 90, true, true,
   'Registros de navegação autenticada são operacionais e já possuem limite publicado de 90 dias.', '2027-02-20'),
  ('app_error_events', 'security_operations', 'app_error_events', 'created_at', 90, true, true,
   'Eventos de erro são mantidos somente pelo período necessário para diagnóstico, segurança e correção.', '2027-02-20'),
  ('csp_violation_reports', 'security_operations', 'csp_violation_reports', 'created_at', 30, true, true,
   'Relatórios CSP têm finalidade técnica de curto prazo e podem conter URLs ou referências de navegação.', '2027-02-20'),
  ('exercise_sync_events', 'operational', 'exercise_sync_events', 'received_at', 90, true, true,
   'Eventos de sincronização servem para diagnóstico de integração e podem conter nome ou e-mail do aluno.', '2027-02-20'),
  ('data_subject_requests', 'privacy_accountability', 'data_subject_requests', 'requested_at', null, false, true,
   'Solicitações de titulares permanecem em registro mínimo pseudonimizado; o prazo de eliminação integral exige revisão jurídica e de prestação de contas.', '2027-02-20'),
  ('financial_records', 'legal_financial', null, null, null, false, true,
   'Mensalidades, tentativas e eventos financeiros não entram no expurgo automático; a conservação depende de obrigações legais, regulatórias, contábeis e exercício de direitos.', '2027-02-20'),
  ('core_student_records', 'service', null, null, null, false, true,
   'Dados acadêmicos e cadastrais são tratados pelo ciclo de vida da conta e pelo fluxo de encerramento, não por idade fixa.', '2027-02-20'),
  ('legacy_backup_snapshots', 'backup', null, null, null, false, true,
   'Snapshots legados exigem revisão de recuperação antes da eliminação integral; exclusões de conta passam a remover também as linhas correspondentes desses snapshots.', '2026-10-28')
on conflict (dataset) do update set
  category = excluded.category,
  source_table = excluded.source_table,
  timestamp_column = excluded.timestamp_column,
  retention_days = excluded.retention_days,
  automatic_purge = excluded.automatic_purge,
  enabled = excluded.enabled,
  rationale = excluded.rationale,
  last_reviewed_at = now(),
  next_review_at = excluded.next_review_at;

create table if not exists public.data_retention_runs (
  id uuid primary key default gen_random_uuid(),
  trigger_source text not null check (trigger_source in ('cron','manual')),
  status text not null check (status in ('running','completed','failed','skipped')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  deleted_counts jsonb not null default '{}'::jsonb,
  error_message text
);

create index if not exists data_retention_runs_started_at_idx
  on public.data_retention_runs (started_at desc);

alter table public.data_retention_runs enable row level security;
revoke all on table public.data_retention_runs from public;
revoke all on table public.data_retention_runs from anon;
revoke all on table public.data_retention_runs from authenticated;
grant select on table public.data_retention_runs to authenticated;

drop policy if exists "teacher_reads_data_retention_runs" on public.data_retention_runs;
create policy "teacher_reads_data_retention_runs"
  on public.data_retention_runs
  for select to authenticated
  using (coalesce(public.is_teacher_admin(), false));

create or replace function public.perform_data_retention_maintenance(p_trigger_source text default 'cron')
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  run_id uuid;
  policy_row public.data_retention_policies%rowtype;
  deleted_count integer;
  deleted_counts jsonb := '{}'::jsonb;
  normalized_source text := lower(btrim(coalesce(p_trigger_source, 'cron')));
  error_text text;
begin
  if normalized_source not in ('cron','manual') then
    raise exception 'Origem de execução inválida.' using errcode = '22023';
  end if;

  insert into public.data_retention_runs (trigger_source, status)
  values (normalized_source, 'running')
  returning id into run_id;

  if not pg_try_advisory_xact_lock(731955421) then
    update public.data_retention_runs
       set status = 'skipped', completed_at = now(), error_message = 'Outra execução de retenção já estava em andamento.'
     where id = run_id;
    return jsonb_build_object('ok', true, 'status', 'skipped', 'run_id', run_id);
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
      get diagnostics deleted_count = row_count;
      deleted_counts := deleted_counts || jsonb_build_object(policy_row.dataset, deleted_count);
    end loop;

    delete from public.data_retention_runs
     where id <> run_id
       and started_at < now() - interval '365 days';

    update public.data_retention_runs
       set status = 'completed',
           completed_at = now(),
           deleted_counts = deleted_counts,
           error_message = null
     where id = run_id;

    return jsonb_build_object('ok', true, 'status', 'completed', 'run_id', run_id, 'deleted_counts', deleted_counts);
  exception when others then
    error_text := left(sqlerrm, 4000);
    update public.data_retention_runs
       set status = 'failed',
           completed_at = now(),
           deleted_counts = deleted_counts,
           error_message = error_text
     where id = run_id;

    if to_regclass('public.app_error_events') is not null then
      begin
        insert into public.app_error_events (
          event_type, severity, message, source, path, fingerprint, metadata, occurred_at
        ) values (
          'data_retention_failure', 'error', error_text, 'database', 'cron:data-retention',
          md5('data_retention_failure:' || error_text),
          jsonb_build_object('run_id', run_id, 'trigger_source', normalized_source), now()
        );
      exception when others then
        null;
      end;
    end if;

    return jsonb_build_object('ok', false, 'status', 'failed', 'run_id', run_id, 'deleted_counts', deleted_counts, 'error', error_text);
  end;
end;
$$;

revoke all on function public.perform_data_retention_maintenance(text) from public;
revoke all on function public.perform_data_retention_maintenance(text) from anon;
revoke all on function public.perform_data_retention_maintenance(text) from authenticated;

create or replace function public.run_data_retention_maintenance_now()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;
  return public.perform_data_retention_maintenance('manual');
end;
$$;

revoke all on function public.run_data_retention_maintenance_now() from public;
revoke all on function public.run_data_retention_maintenance_now() from anon;
grant execute on function public.run_data_retention_maintenance_now() to authenticated;

create or replace function public.get_data_retention_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public, cron, pg_temp
as $$
declare
  policy_row public.data_retention_policies%rowtype;
  policies jsonb := '[]'::jsonb;
  total_count bigint;
  eligible_count bigint;
  oldest_at timestamptz;
  latest_run jsonb;
  cron_job jsonb;
begin
  if not coalesce(public.is_teacher_admin(), false) then
    raise exception 'Acesso negado: usuário não cadastrado como professor.' using errcode = '42501';
  end if;

  for policy_row in select * from public.data_retention_policies order by automatic_purge desc, category, dataset
  loop
    total_count := null;
    eligible_count := null;
    oldest_at := null;

    if policy_row.source_table is not null
       and policy_row.timestamp_column is not null
       and to_regclass(format('public.%I', policy_row.source_table)) is not null then
      if policy_row.retention_days is null then
        execute format(
          'select count(*), min(%I), null::bigint from public.%I',
          policy_row.timestamp_column,
          policy_row.source_table
        ) into total_count, oldest_at, eligible_count;
      else
        execute format(
          'select count(*), min(%I), count(*) filter (where %I < now() - make_interval(days => $1)) from public.%I',
          policy_row.timestamp_column,
          policy_row.timestamp_column,
          policy_row.source_table
        ) into total_count, oldest_at, eligible_count using policy_row.retention_days;
      end if;
    end if;

    policies := policies || jsonb_build_array(jsonb_build_object(
      'dataset', policy_row.dataset,
      'category', policy_row.category,
      'retention_days', policy_row.retention_days,
      'automatic_purge', policy_row.automatic_purge,
      'enabled', policy_row.enabled,
      'rationale', policy_row.rationale,
      'last_reviewed_at', policy_row.last_reviewed_at,
      'next_review_at', policy_row.next_review_at,
      'record_count', total_count,
      'eligible_now', eligible_count,
      'oldest_at', oldest_at
    ));
  end loop;

  select to_jsonb(r) into latest_run
  from (
    select id, trigger_source, status, started_at, completed_at, deleted_counts, error_message
    from public.data_retention_runs
    order by started_at desc
    limit 1
  ) r;

  select jsonb_build_object('jobid', j.jobid, 'jobname', j.jobname, 'schedule', j.schedule, 'active', j.active)
    into cron_job
  from cron.job j
  where j.jobname = 'daily-data-retention-maintenance'
  limit 1;

  return jsonb_build_object(
    'policies', policies,
    'latest_run', latest_run,
    'cron_job', cron_job,
    'generated_at', now()
  );
end;
$$;

revoke all on function public.get_data_retention_dashboard() from public;
revoke all on function public.get_data_retention_dashboard() from anon;
grant execute on function public.get_data_retention_dashboard() to authenticated;

create or replace function public.cleanup_legacy_backup_personal_data_on_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_id uuid;
begin
  target_id := old.id;

  if to_regclass('public.backup_profiles_20260501') is not null then
    execute 'delete from public.backup_profiles_20260501 where id = $1' using target_id;
  end if;
  if to_regclass('public.backup_auth_users_metadata_20260501') is not null then
    execute 'delete from public.backup_auth_users_metadata_20260501 where id = $1' using target_id;
  end if;
  if to_regclass('public.backup_student_private_data_20260501') is not null then
    execute 'delete from public.backup_student_private_data_20260501 where user_id = $1' using target_id;
  end if;

  return old;
end;
$$;

revoke all on function public.cleanup_legacy_backup_personal_data_on_delete() from public;
revoke all on function public.cleanup_legacy_backup_personal_data_on_delete() from anon;
revoke all on function public.cleanup_legacy_backup_personal_data_on_delete() from authenticated;

drop trigger if exists cleanup_legacy_backup_pii_before_profile_delete on public.profiles;
create trigger cleanup_legacy_backup_pii_before_profile_delete
before delete on public.profiles
for each row execute function public.cleanup_legacy_backup_personal_data_on_delete();

drop trigger if exists cleanup_legacy_backup_pii_before_auth_delete on auth.users;
create trigger cleanup_legacy_backup_pii_before_auth_delete
before delete on auth.users
for each row execute function public.cleanup_legacy_backup_personal_data_on_delete();

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id from cron.job where jobname = 'daily-data-retention-maintenance' limit 1;
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'daily-data-retention-maintenance',
    '35 5 * * *',
    'select public.perform_data_retention_maintenance(''cron'');'
  );
end;
$$;