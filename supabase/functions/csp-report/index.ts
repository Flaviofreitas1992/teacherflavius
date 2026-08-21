import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function noContent() {
  return new Response(null, { status: 204, headers: { "Cache-Control": "no-store" } });
}

function safeText(value: unknown, max = 1000): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (!text) return null;
  return text.slice(0, max);
}

function sanitizeUrl(value: unknown): string | null {
  const raw = safeText(value, 4000);
  if (!raw) return null;
  if (raw === "inline" || raw === "eval") return raw;
  if (raw.startsWith("data:")) return "data:";
  if (raw.startsWith("blob:")) return "blob:";

  try {
    const url = new URL(raw);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return `${url.protocol}`.slice(0, 1000);
    }
    return `${url.protocol}//${url.host}${url.pathname}`.slice(0, 1000);
  } catch {
    return raw.slice(0, 1000);
  }
}

async function sha256Hex(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function normalizeReport(raw: Record<string, unknown>) {
  const body = (raw["csp-report"] ?? raw.body ?? raw) as Record<string, unknown>;
  return {
    document_uri: sanitizeUrl(body["document-uri"] ?? body.documentURL ?? body.document_uri),
    violated_directive: safeText(body["violated-directive"] ?? body.violatedDirective ?? body.violated_directive, 250),
    effective_directive: safeText(body["effective-directive"] ?? body.effectiveDirective ?? body.effective_directive, 250),
    blocked_uri: sanitizeUrl(body["blocked-uri"] ?? body.blockedURL ?? body.blocked_uri),
    source_file: sanitizeUrl(body["source-file"] ?? body.sourceFile ?? body.source_file),
    line_number: Number.isFinite(Number(body["line-number"] ?? body.lineNumber))
      ? Math.max(0, Math.trunc(Number(body["line-number"] ?? body.lineNumber)))
      : null,
    column_number: Number.isFinite(Number(body["column-number"] ?? body.columnNumber))
      ? Math.max(0, Math.trunc(Number(body["column-number"] ?? body.columnNumber)))
      : null,
    status_code: Number.isFinite(Number(body["status-code"] ?? body.statusCode))
      ? Math.max(0, Math.trunc(Number(body["status-code"] ?? body.statusCode)))
      : null,
    disposition: safeText(body.disposition, 50),
    referrer: sanitizeUrl(body.referrer),
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return noContent();
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false }), { status: 405, headers: jsonHeaders });
  }

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 32768) return noContent();

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return noContent();

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const forwardedFor = req.headers.get("cf-connecting-ip")
      ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
      ?? "unknown";
    const clientHash = await sha256Hex(forwardedFor);

    const [{ data: hourlyAllowed }, { data: dailyAllowed }] = await Promise.all([
      admin.rpc("consume_api_rate_limit", {
        target_bucket_key: `csp-report:hour:${clientHash}`,
        target_window_seconds: 3600,
        target_max_requests: 120,
      }),
      admin.rpc("consume_api_rate_limit", {
        target_bucket_key: `csp-report:day:${clientHash}`,
        target_window_seconds: 86400,
        target_max_requests: 1000,
      }),
    ]);

    if (!hourlyAllowed || !dailyAllowed) return noContent();

    const payload = await req.json();
    const rawReports = Array.isArray(payload) ? payload.slice(0, 10) : [payload];
    const reports = rawReports
      .filter((item): item is Record<string, unknown> => Boolean(item) && typeof item === "object")
      .map(normalizeReport)
      .filter((report) => report.document_uri || report.violated_directive || report.effective_directive);

    if (reports.length) {
      await admin.from("csp_violation_reports").insert(reports);
    }
  } catch (error) {
    console.error("csp-report ingestion error", error instanceof Error ? error.message : "unknown");
  }

  return noContent();
});
