import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const SECRET_SHA256 = "f093cfbed40de5128fa41e842a9431d385a27db653ff2e79eab7576ad8086f9e";
const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function sha256Hex(value: string) {
  const bytes = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req: Request) => {
  try {
    const suppliedSecret = req.headers.get("x-sync-secret") ?? "";
    if ((await sha256Hex(suppliedSecret)) !== SECRET_SHA256) {
      return json({ ok: false, status: "unauthorized" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ ok: false, status: "server_not_configured" }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (req.method === "GET") {
      const url = new URL(req.url);
      const action = url.searchParams.get("action") ?? "health";

      if (action === "health") {
        return json({ ok: true, service: "google-forms-integration-manager" });
      }

      if (action === "pending") {
        const { data, error } = await admin
          .from("exercise_form_sources")
          .select("id,exercise_id,spreadsheet_id,spreadsheet_url,import_existing,status")
          .in("status", ["pending", "disconnect_requested"])
          .order("updated_at", { ascending: true })
          .limit(25);

        if (error) throw error;
        return json({ ok: true, sources: data ?? [] });
      }

      return json({ ok: false, status: "unknown_action" }, 400);
    }

    if (req.method !== "POST") {
      return json({ ok: false, status: "method_not_allowed" }, 405);
    }

    const payload = await req.json();
    const action = String(payload.action ?? "");
    if (action !== "source_status") {
      return json({ ok: false, status: "unknown_action" }, 400);
    }

    const sourceId = String(payload.source_id ?? "").trim();
    const status = String(payload.status ?? "").trim();
    const allowedStatuses = new Set(["active", "error", "disconnected"]);
    if (!sourceId || !allowedStatuses.has(status)) {
      return json({ ok: false, status: "invalid_payload" }, 400);
    }

    const update: Record<string, unknown> = {
      status,
      updated_at: new Date().toISOString(),
      last_error: status === "error" ? String(payload.error ?? "Falha no Apps Script") : null,
    };

    if (status === "active") {
      update.trigger_created_at = new Date().toISOString();
      if (payload.historical_processed !== undefined || payload.historical_unmatched !== undefined) {
        update.historical_sync_at = new Date().toISOString();
        update.historical_processed = Number(payload.historical_processed ?? 0);
        update.historical_unmatched = Number(payload.historical_unmatched ?? 0);
      }
    }

    const { data, error } = await admin
      .from("exercise_form_sources")
      .update(update)
      .eq("id", sourceId)
      .select("id,status")
      .maybeSingle();

    if (error) throw error;
    if (!data) return json({ ok: false, status: "source_not_found" }, 404);

    return json({ ok: true, source: data });
  } catch (error) {
    console.error(error);
    return json({
      ok: false,
      status: "error",
      message: error instanceof Error ? error.message : "Erro interno",
    }, 500);
  }
});
