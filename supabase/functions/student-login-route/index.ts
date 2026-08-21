import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const allowedOrigin = "https://teacherflavius.com";

function corsHeaders(origin: string | null) {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (!origin || origin === allowedOrigin) headers["Access-Control-Allow-Origin"] = allowedOrigin;
  return headers;
}

function json(body: unknown, status = 200, origin: string | null = null) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (origin && origin !== allowedOrigin) return json({ error: "Origem não permitida." }, 403, origin);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(origin) });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405, origin);

  // Política atual: o portal não oferece mais autenticação por senha para nenhuma conta.
  await new Promise((resolve) => setTimeout(resolve, 150));
  return json({ route: "google_only" }, 200, origin);
});
