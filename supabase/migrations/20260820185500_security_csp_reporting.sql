create table if not exists public.csp_violation_reports (
  id uuid primary key default gen_random_uuid(),
  document_uri text,
  violated_directive text,
  effective_directive text,
  blocked_uri text,
  source_file text,
  line_number integer,
  column_number integer,
  status_code integer,
  disposition text,
  referrer text,
  created_at timestamptz not null default now()
);

create index if not exists csp_violation_reports_created_at_idx
  on public.csp_violation_reports (created_at desc);

alter table public.csp_violation_reports enable row level security;

revoke all on table public.csp_violation_reports from public, anon, authenticated;
grant select, insert, delete on table public.csp_violation_reports to service_role;

comment on table public.csp_violation_reports is
  'Server-only CSP violation telemetry. Browser roles have no direct access.';
