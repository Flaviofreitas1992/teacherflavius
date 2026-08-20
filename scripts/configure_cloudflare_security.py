#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

API_ROOT = "https://api.cloudflare.com/client/v4"
ZONE_NAME = "teacherflavius.com"
RULE_REF = "teacherflavius_security_headers_v1"
RULE_DESCRIPTION = "TeacherFlavius security headers v1"
CSP_REPORT_URL = "https://wnigzpvgsbpjdxvjzugt.supabase.co/functions/v1/csp-report"

CSP_REPORT_ONLY = (
    "default-src 'self'; "
    "base-uri 'self'; object-src 'none'; frame-ancestors 'self'; "
    "form-action 'self' https://accounts.google.com https://*.mercadopago.com; "
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' "
    "https://cdn.jsdelivr.net https://sdk.mercadopago.com "
    "https://www.googletagmanager.com https://www.google-analytics.com; "
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
    "font-src 'self' data: https://fonts.gstatic.com; "
    "img-src 'self' data: blob: https://*.googleusercontent.com "
    "https://i.ytimg.com https://*.ytimg.com https://www.google-analytics.com; "
    "connect-src 'self' https://*.supabase.co wss://*.supabase.co "
    "https://*.mercadopago.com https://*.google-analytics.com; "
    "frame-src 'self' https://www.youtube.com https://www.youtube-nocookie.com "
    "https://*.mercadopago.com https://accounts.google.com; "
    "media-src 'self' data: blob: https:; worker-src 'self' blob:; "
    "manifest-src 'self'; upgrade-insecure-requests; "
    f"report-uri {CSP_REPORT_URL}"
)

SECURITY_HEADERS = {
    "Strict-Transport-Security": {
        "operation": "set",
        "value": "max-age=31536000",
    },
    "X-Content-Type-Options": {
        "operation": "set",
        "value": "nosniff",
    },
    "Referrer-Policy": {
        "operation": "set",
        "value": "strict-origin-when-cross-origin",
    },
    "X-Frame-Options": {
        "operation": "set",
        "value": "SAMEORIGIN",
    },
    "Permissions-Policy": {
        "operation": "set",
        "value": (
            "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
            "magnetometer=(), microphone=(self), usb=()"
        ),
    },
    "Content-Security-Policy-Report-Only": {
        "operation": "set",
        "value": CSP_REPORT_ONLY,
    },
}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def cloudflare_request(
    method: str,
    path: str,
    token: str,
    payload: dict[str, Any] | None = None,
) -> Any:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        f"{API_ROOT}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "User-Agent": "teacherflavius-security-edge/1.0",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        fail(f"Cloudflare API {method} {path} returned HTTP {exc.code}: {body[:1200]}")
    except urllib.error.URLError as exc:
        fail(f"Cloudflare API request failed: {exc.reason}")

    if not body:
        return None

    envelope = json.loads(body)
    if not envelope.get("success", False):
        fail(f"Cloudflare API error for {method} {path}: {envelope.get('errors')}")
    return envelope.get("result")


def find_zone(token: str) -> dict[str, Any]:
    query = urllib.parse.urlencode({"name": ZONE_NAME, "per_page": 50})
    zones = cloudflare_request("GET", f"/zones?{query}", token)
    exact = [z for z in zones if str(z.get("name", "")).lower() == ZONE_NAME]
    if len(exact) != 1:
        fail(f"Expected exactly one Cloudflare zone named {ZONE_NAME}; found {len(exact)}")
    zone = exact[0]
    if zone.get("status") != "active":
        fail(f"Cloudflare zone is not active (status={zone.get('status')!r})")
    return zone


def patch_zone_setting(token: str, zone_id: str, setting: str, value: str) -> None:
    cloudflare_request(
        "PATCH",
        f"/zones/{zone_id}/settings/{setting}",
        token,
        {"value": value},
    )
    print(f"Configured Cloudflare setting: {setting}={value}")


def security_rule() -> dict[str, Any]:
    return {
        "ref": RULE_REF,
        "enabled": True,
        "description": RULE_DESCRIPTION,
        "expression": (
            '(http.host eq "teacherflavius.com") or '
            '(http.host eq "www.teacherflavius.com")'
        ),
        "action": "rewrite",
        "action_parameters": {"headers": SECURITY_HEADERS},
    }


def configure_transform_rule(token: str, zone_id: str) -> None:
    rulesets = cloudflare_request("GET", f"/zones/{zone_id}/rulesets", token)
    matching = [
        item
        for item in rulesets
        if item.get("phase") == "http_response_headers_transform"
        and item.get("kind") == "zone"
    ]

    desired_rule = security_rule()

    if not matching:
        cloudflare_request(
            "POST",
            f"/zones/{zone_id}/rulesets",
            token,
            {
                "name": "Zone-level Response Headers Transform Ruleset",
                "description": "TeacherFlavius response security headers",
                "kind": "zone",
                "phase": "http_response_headers_transform",
                "rules": [desired_rule],
            },
        )
        print("Created Cloudflare response-header transform ruleset.")
        return

    ruleset_id = matching[0]["id"]
    full_ruleset = cloudflare_request("GET", f"/zones/{zone_id}/rulesets/{ruleset_id}", token)
    existing = next(
        (
            rule
            for rule in full_ruleset.get("rules", [])
            if rule.get("ref") == RULE_REF or rule.get("description") == RULE_DESCRIPTION
        ),
        None,
    )

    if existing:
        cloudflare_request(
            "PATCH",
            f"/zones/{zone_id}/rulesets/{ruleset_id}/rules/{existing['id']}",
            token,
            desired_rule,
        )
        print("Updated Cloudflare security response-header rule.")
    else:
        cloudflare_request(
            "POST",
            f"/zones/{zone_id}/rulesets/{ruleset_id}/rules",
            token,
            desired_rule,
        )
        print("Added Cloudflare security response-header rule.")


def active_certificate_covers_apex(token: str, zone_id: str) -> bool:
    query = urllib.parse.urlencode({"status": "active", "per_page": 50})
    packs = cloudflare_request(
        "GET",
        f"/zones/{zone_id}/ssl/certificate_packs?{query}",
        token,
    )
    hosts: set[str] = set()
    for pack in packs:
        for host in pack.get("hosts", []) or []:
            hosts.add(str(host).lower())
        for certificate in pack.get("certificates", []) or []:
            for host in certificate.get("hosts", []) or []:
                hosts.add(str(host).lower())
    return ZONE_NAME in hosts


def web_dns_records(token: str, zone_id: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for name in (ZONE_NAME, f"www.{ZONE_NAME}"):
        query = urllib.parse.urlencode({"name": name, "per_page": 100})
        result = cloudflare_request("GET", f"/zones/{zone_id}/dns_records?{query}", token)
        records.extend(
            record
            for record in result
            if record.get("type") in {"A", "AAAA", "CNAME"}
            and str(record.get("name", "")).lower() == name
        )
    return records


def set_proxy_state(
    token: str,
    zone_id: str,
    records: list[dict[str, Any]],
    proxied: bool,
) -> None:
    for record in records:
        if not record.get("proxiable", True):
            continue
        if bool(record.get("proxied")) == proxied:
            continue
        cloudflare_request(
            "PATCH",
            f"/zones/{zone_id}/dns_records/{record['id']}",
            token,
            {"proxied": proxied},
        )
        print(f"Set proxy={proxied} for {record.get('type')} {record.get('name')}")


def fetch_live_headers() -> dict[str, str]:
    request = urllib.request.Request(
        f"https://{ZONE_NAME}/",
        method="HEAD",
        headers={"User-Agent": "teacherflavius-security-edge-verify/1.0"},
    )
    context = ssl.create_default_context()
    with urllib.request.urlopen(request, timeout=20, context=context) as response:
        return {key.lower(): value for key, value in response.headers.items()}


def verify_cloudflare_headers() -> tuple[bool, str]:
    required = {
        "strict-transport-security",
        "x-content-type-options",
        "referrer-policy",
        "x-frame-options",
        "permissions-policy",
        "content-security-policy-report-only",
    }
    try:
        headers = fetch_live_headers()
    except Exception as exc:  # noqa: BLE001
        return False, f"HTTPS verification failed: {exc}"

    cloudflare_seen = "cf-ray" in headers or headers.get("server", "").lower() == "cloudflare"
    missing = sorted(required.difference(headers))
    if not cloudflare_seen:
        return False, "Cloudflare proxy is not visible yet (no cf-ray/server: cloudflare)."
    if missing:
        return False, f"Missing expected security headers: {', '.join(missing)}"
    return True, "Cloudflare proxy and response security headers verified."


def main() -> None:
    token = os.getenv("CLOUDFLARE_API_TOKEN", "").strip()
    if not token:
        fail("CLOUDFLARE_API_TOKEN is not configured.")

    enable_proxy = os.getenv("CLOUDFLARE_ENABLE_PROXY", "false").strip().lower() == "true"

    zone = find_zone(token)
    zone_id = zone["id"]
    print(f"Found active Cloudflare zone: {ZONE_NAME}")

    patch_zone_setting(token, zone_id, "ssl", "strict")
    patch_zone_setting(token, zone_id, "always_use_https", "on")
    patch_zone_setting(token, zone_id, "automatic_https_rewrites", "on")
    configure_transform_rule(token, zone_id)

    records = web_dns_records(token, zone_id)
    if not records:
        fail("No A/AAAA/CNAME records found for the apex or www host.")

    print("Web DNS records:")
    for record in records:
        print(
            f"- {record.get('type')} {record.get('name')} -> {record.get('content')} "
            f"proxied={bool(record.get('proxied'))}"
        )

    if not enable_proxy:
        print("Proxy enablement was not requested. Cloudflare rules are staged only.")
        return

    if not active_certificate_covers_apex(token, zone_id):
        fail(
            "No active Cloudflare edge certificate currently covers teacherflavius.com. "
            "Proxy enablement was aborted before changing DNS."
        )

    original_states = {record["id"]: bool(record.get("proxied")) for record in records}
    set_proxy_state(token, zone_id, records, True)

    last_message = ""
    for _ in range(24):
        ok, message = verify_cloudflare_headers()
        last_message = message
        if ok:
            print(message)
            return
        print(f"Verification pending: {message}")
        time.sleep(5)

    print(f"Verification did not succeed: {last_message}", file=sys.stderr)
    print("Rolling back DNS proxy states to avoid an unverified edge change.", file=sys.stderr)
    refreshed = web_dns_records(token, zone_id)
    for record in refreshed:
        previous = original_states.get(record["id"])
        if previous is None or bool(record.get("proxied")) == previous:
            continue
        cloudflare_request(
            "PATCH",
            f"/zones/{zone_id}/dns_records/{record['id']}",
            token,
            {"proxied": previous},
        )
    fail("Cloudflare edge verification failed and DNS proxy changes were rolled back.")


if __name__ == "__main__":
    main()
