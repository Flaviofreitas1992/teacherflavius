import { createClient } from "npm:@supabase/supabase-js@2";

const SECRET_SHA256 = "f093cfbed40de5128fa41e842a9431d385a27db653ff2e79eab7576ad8086f9e";

const EMAIL_ALIASES: Record<string, string> = {
  "carvalhodamiana306@gmail.com": "damiana_002@hotmail.com",
  "tesolinjulia@gmail.com": "tessarijulia2411@gmail.com",
};

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

    if (req.method === "GET") {
      return json({ ok: true, service: "google-forms-exercise-sync", checked_at: new Date().toISOString() });
    }

    if (req.method !== "POST") {
      return json({ ok: false, status: "method_not_allowed" }, 405);
    }

    const payload = await req.json();
    const exerciseId = String(payload.exercise_id ?? "").trim();
    const originalEmail = String(payload.email ?? "").trim().toLowerCase();
    const normalizedEmail = EMAIL_ALIASES[originalEmail] ?? originalEmail;
    const completedAt = new Date(String(payload.completed_at ?? ""));

    if (!exerciseId || !originalEmail || Number.isNaN(completedAt.getTime())) {
      return json({ ok: false, status: "invalid_payload" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ ok: false, status: "server_not_configured" }, 500);
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: profiles, error: profileError } = await admin
      .from("profiles")
      .select("id,name,email,enrolled,enrollment_code")
      .ilike("email", normalizedEmail)
      .limit(2);

    if (profileError) throw profileError;
    if (!profiles?.length) {
      return json({ ok: false, status: "unmatched_student", email: originalEmail });
    }
    if (profiles.length > 1) {
      return json({ ok: false, status: "ambiguous_email", email: originalEmail });
    }

    const student = profiles[0];
    const enrolled = Boolean(student.enrolled) || Boolean(String(student.enrollment_code ?? "").trim());
    if (!enrolled) {
      return json({ ok: false, status: "not_enrolled", student_name: student.name, email: originalEmail });
    }

    const { data: exercise, error: exerciseError } = await admin
      .from("teacher_exercises")
      .select("exercise_id,exercise_title,exercise_url")
      .eq("exercise_id", exerciseId)
      .maybeSingle();

    if (exerciseError) throw exerciseError;
    if (!exercise) {
      return json({ ok: false, status: "exercise_not_found", exercise_id: exerciseId }, 404);
    }

    const { data: existing, error: existingError } = await admin
      .from("daily_exercise_completion")
      .select("completed_at")
      .eq("user_id", student.id)
      .eq("exercise_id", exerciseId)
      .maybeSingle();

    if (existingError) throw existingError;

    let finalCompletedAt = completedAt;
    if (existing?.completed_at) {
      const existingDate = new Date(existing.completed_at);
      if (!Number.isNaN(existingDate.getTime()) && existingDate < finalCompletedAt) {
        finalCompletedAt = existingDate;
      }
    }

    const { error: upsertError } = await admin
      .from("daily_exercise_completion")
      .upsert({
        user_id: student.id,
        exercise_id: exercise.exercise_id,
        exercise_title: exercise.exercise_title,
        exercise_url: exercise.exercise_url,
        completed: true,
        completed_at: finalCompletedAt.toISOString(),
        completion_source: "monitor",
        completed_by: null,
        completed_by_email: null,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,exercise_id" });

    if (upsertError) throw upsertError;

    return json({
      ok: true,
      status: "processed",
      student_name: student.name,
      exercise_id: exercise.exercise_id,
      exercise_title: exercise.exercise_title,
      completed_at: finalCompletedAt.toISOString(),
      completion_source: "monitor",
      source_email: originalEmail,
    });
  } catch (error) {
    console.error(error);
    return json({
      ok: false,
      status: "error",
      message: error instanceof Error ? error.message : "Erro interno",
    }, 500);
  }
});