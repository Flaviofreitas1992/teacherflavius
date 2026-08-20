# Database backup and recovery

This document describes the off-Supabase logical backup layer for the Teacherflavius production database.

## Current protection model

The project is on the Supabase Free plan, so managed daily database backups and Point-in-Time Recovery are not available. The repository contains a validated schema reconstruction baseline under `supabase/baseline/`, while `.github/workflows/supabase-encrypted-backup.yml` provides the separate data-backup layer.

The two layers serve different purposes:

- `supabase/baseline/`: versioned schema reconstruction and platform configuration.
- encrypted GitHub Actions artifacts: production database roles, schema, data and Supabase migration-history records.

Neither layer should be treated as a backup of Supabase Storage object bytes. Storage objects require a separate backup mechanism if buckets are added in the future.

## Required GitHub repository secrets

The backup workflow deliberately refuses to run without both secrets below.

### `SUPABASE_DB_URL`

Use the production database connection string from the Supabase Dashboard **Connect** panel. Prefer the Session Pooler connection string for CI reliability. It must contain the database password.

Example shape only — never commit the real value:

```text
postgresql://postgres.<project-ref>:<database-password>@<pooler-host>:5432/postgres
```

### `BACKUP_ENCRYPTION_PASSPHRASE`

Use a unique random passphrase of at least 32 characters. Store the same value in a password manager or another protected location outside GitHub. If this value is lost, the encrypted backup artifacts cannot be recovered.

Never put either secret in source files, issues, pull-request comments, Actions logs or documentation.

## Schedule and retention

The workflow runs every day at `03:17 UTC`, currently `00:17` in `America/Sao_Paulo`.

- Normal daily backup: retained for 30 days.
- Backup created on the first day of each month: retained for 90 days.

The 90-day ceiling reflects the maximum artifact retention available for a public GitHub repository. A future durable archive with retention longer than 90 days should use a separate encrypted object-storage destination.

## Backup contents

Each run follows the current Supabase CLI backup/restore guidance and creates:

- `roles.sql`
- `schema.sql`
- `data.sql`
- `history_schema.sql`
- `history_data.sql`
- `manifest.sha256`
- `README.txt`

Before upload, the SQL files are packed into a tarball and symmetrically encrypted with GnuPG using AES-256. The plaintext files are removed from the runner before the artifact is uploaded.

The workflow then decrypts the encrypted archive once inside the same disposable runner and validates every SQL file against `manifest.sha256`. The run fails if dump creation, encryption, decryption or checksum validation fails.

Only the encrypted `.gpg` payload and its SHA-256 checksum are uploaded as GitHub Actions artifacts.

## Manual validation after activation

After the two repository secrets are configured:

1. Run **Actions → Encrypted Supabase logical backup → Run workflow**.
2. Confirm the workflow finishes successfully.
3. Confirm the run contains one artifact named `supabase-daily-<timestamp>` or `supabase-monthly-<timestamp>`.
4. Download the artifact.
5. Verify its external SHA-256 file before decryption.
6. Decrypt and inspect the archive locally using the recovery passphrase.

A backup should not be considered operational until this first manual run succeeds.

## Decrypting a backup

Assuming the downloaded encrypted file is named `teacherflavius-YYYYMMDDTHHMMSSZ.tar.gz.gpg`:

```bash
gpg --batch --yes --pinentry-mode loopback \
  --output teacherflavius-backup.tar.gz \
  --decrypt teacherflavius-YYYYMMDDTHHMMSSZ.tar.gz.gpg

mkdir teacherflavius-backup
tar -xzf teacherflavius-backup.tar.gz -C teacherflavius-backup
cd teacherflavius-backup
sha256sum --check manifest.sha256
```

GnuPG will request the backup encryption passphrase during local decryption unless it is supplied through a secure local secret mechanism.

## Restore order

For a disaster recovery into a newly created Supabase project:

1. Create the replacement Supabase project and enable required extensions/webhook capabilities.
2. Obtain the replacement database connection string.
3. Decrypt the selected backup artifact and verify `manifest.sha256`.
4. Follow the repository baseline recovery instructions in `supabase/baseline/README.md` when reconstructing the application-owned schema.
5. Restore production data with triggers disabled for the data import where required.
6. Restore migration-history records only after the application schema/data state has been verified.
7. Provision Vault secrets, Edge Function secrets, OAuth settings, SMTP settings and other environment-specific configuration out-of-band.
8. Deploy Edge Functions from the repository.
9. Validate row counts and critical application flows before switching production traffic.

Do not blindly replay the repository's incomplete historical migration chain on top of the validated baseline.

## Recovery verification checklist

Before considering a restored environment usable, verify at minimum:

- student profiles and enrollment records
- authentication/login and Google account linking
- monthly tuition and payment-attempt records
- makeup class slots/bookings
- flashcards and practice history
- exercise completion/history
- teacher/admin access
- Edge Function deployment and secrets
- Cron job configuration
- RLS/policies and critical database triggers

## Security notes

The GitHub repository is public. GitHub Actions artifacts must therefore be treated as potentially discoverable by repository readers. The database backup payload is encrypted before upload specifically so that artifact access does not expose student, payment or authentication data.

Do not replace the encrypted artifact strategy with plaintext commits, plaintext release assets or unencrypted workflow artifacts.
