# Cloudflare security edge — teacherflavius.com

This configuration keeps GitHub Pages as the origin and places Cloudflare in front of it only for TLS/edge security controls and response headers.

## API token

Create a Cloudflare API token restricted to the `teacherflavius.com` zone. Do not use the Global API Key.

Required zone permissions:

- Zone Read
- DNS Write
- Zone Settings Edit
- Transform Rules Edit
- SSL and Certificates Read

Store the token only as the GitHub Actions repository secret `CLOUDFLARE_API_TOKEN`.

## Deployment workflow

Run the GitHub Actions workflow `Configure Cloudflare security edge`.

1. First run with `enable_proxy=false`. This stages SSL/TLS settings and the response-header Transform Rule without changing DNS proxy state.
2. Review the workflow output. The zone must be active and the web DNS records must be detected.
3. Run again with `enable_proxy=true`. The automation requires an active Cloudflare edge certificate covering `teacherflavius.com` before enabling proxying.
4. After proxying, the automation verifies Cloudflare is serving the request and that the security headers are present. If verification fails, it rolls the modified DNS proxy states back.

## Headers

The edge rule sets:

- `Strict-Transport-Security: max-age=31536000`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: SAMEORIGIN`
- a conservative `Permissions-Policy` that keeps same-origin microphone access for pronunciation exercises
- `Content-Security-Policy-Report-Only`

HSTS intentionally starts without `includeSubDomains` and without preload. CSP intentionally starts in Report-Only mode to avoid disrupting authentication, payments, video embeds, analytics, or pronunciation features.

## CSP telemetry

CSP reports are sent to the Supabase Edge Function `csp-report`. The function:

- accepts CSP reporting payloads without user JWTs because browsers send these reports automatically;
- rate-limits reports by a SHA-256 hash of the network source rather than storing the raw address;
- strips URL query strings and fragments before storage;
- writes into `public.csp_violation_reports`, which has RLS enabled and no direct `anon` or `authenticated` access.

After enough representative traffic has been observed, review the CSP reports and tighten the policy before changing it from Report-Only to enforcement.
