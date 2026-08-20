# Supabase production baseline

This directory is the canonical schema-only reconstruction baseline for the Teacherflavius production database.

Captured after production migration `20260820225434_harden_notification_webhook_vault_dispatcher`.

## Why this baseline exists

The production `supabase_migrations.schema_migrations` ledger contains 63 entries, while the repository historically contained only a small subset of migration files. In addition, the remote ledger begins after some core application tables already existed, so replaying the ledger alone cannot reconstruct an empty database.

A literal public copy of the historical ledger is also unsafe: migration `20260819081121_google_only_student_account_linking` contains real student email addresses. Those values must not become permanent history in this public repository.

For those reasons, the current production schema is the reconstruction source of truth. `migration-ledger.csv` records every remote version/name for audit without publishing historical personal data.

## Restore order

Use a fresh Supabase project with the same PostgreSQL major version and standard Supabase-managed `auth`/`storage` schemas.

1. Apply `10_public_schema.sql`.
2. Apply `20_default_privileges.sql`.
3. Apply `30_platform_config.sql`.
4. Provision the Vault secret named `teacherflavius_notification_webhook_secret` out-of-band. Never commit its value.
5. Deploy the Edge Functions and their environment secrets from the normal application deployment path.
6. Restore application data separately, if a data restore is required.
7. Compare the restored catalog against `schema-fingerprint.json` before directing traffic to it.
8. Only after the restored schema has been verified, reconcile migration-history status using the current Supabase CLI `migration repair` workflow and `migration-ledger.csv`. Do not replay the historical migrations on top of this baseline.

## Important boundaries

- This is schema only. It contains no student rows, payment rows, auth users, CPF values, email addresses, or Vault secret values.
- Storage currently has no buckets and no custom Storage RLS policies.
- The production database currently has one application Cron job, recreated by `30_platform_config.sql`.
- Supabase-managed internals in `auth`, `storage`, `realtime`, GraphQL, and extension schemas are not duplicated. The only application-owned auth trigger is captured by `10_public_schema.sql`.
- Application-owned objects in schema `private` are included in `10_public_schema.sql` before triggers that reference them.
- `supabase/migrations/` remains historical development material; it is not a complete fresh-database replay chain. For disaster recovery, use this baseline plus a verified data backup.

## Validation fingerprint

At capture time production had:

- 46 public tables
- 188 constraints
- 99 non-constraint indexes
- 116 application public functions
- 1 application private function
- 85 public RLS policies
- 28 public user triggers
- 1 application auth trigger
- 1 application event trigger
- 1 Cron job
- 0 Storage buckets
- 1 required Vault secret name

The machine-readable copy is in `schema-fingerprint.json`.
