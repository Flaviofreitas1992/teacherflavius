import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const SECRET_SHA256 = "f093cfbed40de5128fa41e842a9431d385a27db653ff2e79eab7576ad8086f9e";
const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };

function getDefaultKey(envName: string, legacyName: string): string {
  const raw = Deno.env.get(envName);
  if (raw) {
    try {
      const parsed = JSON.parse(raw) as Record<string, unknown>;
      const key = parsed?.default;
      if (typeof key === "string" && key) return key;
    } catch (_) {}
  }
  return Deno.env.get(legacyName) ?? "";
}

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

async function writeSyncEvent(admin: ReturnType<typeof createClient>, event: Record<string, unknown>) {
  try {
    const { error } = await admin.from("exercise_sync_events").insert(event);
    if (error) console.error("Falha ao registrar exercise_sync_events:", error);
  } catch (error) {
    console.error("Falha inesperada ao registrar exercise_sync_events:", error);
  }
}

async function resolveEnrollmentEmail(admin: ReturnType<typeof createClient>, sourceEmail: string) {
  if (!sourceEmail) return sourceEmail;
  const { data, error } = await admin
    .from("student_google_email_aliases")
    .select("enrollment_email")
    .eq("active", true)
    .ilike("google_email", sourceEmail)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) throw error;
  return String(data?.enrollment_email ?? sourceEmail).trim().toLowerCase();
}

Deno.serve(async (req: Request) => {
  let admin: ReturnType<typeof createClient> | null = null;
  let eventContext: Record<string, unknown> = {};

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

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const secretKey = getDefaultKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !secretKey) {
      return json({ ok: false, status: "server_not_configured" }, 500);
    }

    admin = createClient(supabaseUrl, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    let payload: Record<string, unknown>;
    try {
      payload = await req.json();
    } catch {
      await writeSyncEvent(admin, { status: "invalid_payload", error_message: "JSON inválido ou ausente." });
      return json({ ok: false, status: "invalid_payload" }, 400);
    }

    const exerciseId = String(payload.exercise_id ?? "").trim();
    const originalEmail = String(payload.email ?? "").trim().toLowerCase();
    const normalizedEmail = await resolveEnrollmentEmail(admin, originalEmail);
    const completedAt = new Date(String(payload.completed_at ?? ""));
    const aliasApplied = Boolean(originalEmail && normalizedEmail !== originalEmail);

    eventContext = {
      exercise_id: exerciseId || null,
      source_email: originalEmail || null,
      normalized_email: normalizedEmail || null,
      submitted_completed_at: Number.isNaN(completedAt.getTime()) ? null : completedAt.toISOString(),
      metadata: { alias_applied: aliasApplied },
    };

    if (!exerciseId || !originalEmail || Number.isNaN(completedAt.getTime())) {
      await writeSyncEvent(admin, {
        ...eventContext,
        status: "invalid_payload",
        error_message: "exercise_id, email ou completed_at inválido.",
      });
      return json({ ok: false, status: "invalid_payload" }, 400);
    }

    const { data: profiles, error: profileError } = await admin
      .from("profiles")
      .select("id,name,email,enrolled,enrollment_code")
      .ilike("email", normalizedEmail)
      .limit(2);

    if (profileError) throw profileError;
    if (!profiles?.length) {
      await writeSyncEvent(admin, { ...eventContext, status: "unmatched_student" });
      return json({ ok: false, status: "unmatched_student", email: originalEmail });
    }
    if (profiles.length > 1) {
      await writeSyncEvent(admin, {
        ...eventContext,
        status: "ambiguous_email",
        metadata: { alias_applied: aliasApplied, matching_profiles: profiles.length },
      });
      return json({ ok: false, status: "ambiguous_email", email: originalEmail });
    }

    const student = profiles[0];
    eventContext = { ...eventContext, user_id: student.id, student_name: student.name };

    const enrolled = Boolean(student.enrolled) || Boolean(String(student.enrollment_code ?? "").trim());
    if (!enrolled) {
      await writeSyncEvent(admin, { ...eventContext, status: "not_enrolled" });
      return json({ ok: false, status: "not_enrolled", student_name: student.name, email: originalEmail });
    }

    const { data: exercise, error: exerciseError } = await admin
      .from("teacher_exercises")
      .select("exercise_id,exercise_title,exercise_url")
      .eq("exercise_id", exerciseId)
      .maybeSingle();

    if (exerciseError) throw exerciseError;
    if (!exercise) {
      await writeSyncEvent(admin, { ...eventContext, status: "exercise_not_found" });
      return json({ ok: false, status: "exercise_not_found", exercise_id: exerciseId }, 404);
    }

    eventContext = { ...eventContext, exercise_title: exercise.exercise_title };

    const { data: existing, error: existingError } = await admin
      .from("daily_exercise_completion")
      .select("completed_at")
      .eq("user_id", student.id)
      .eq("exercise_id", exerciseId)
      .maybeSingle();

    if (existingError) throw existingError;

    let finalCompletedAt = completedAt;
    let recordAction = "inserted";
    if (existing?.completed_at) {
      recordAction = "confirmed_existing";
      const existingDate = new Date(existing.completed_at);
      if (!Number.isNaN(existingDate.getTime())) {
        if (completedAt < existingDate) {
          recordAction = "updated_earlier_completion";
          finalCompletedAt = completedAt;
        } else {
          finalCompletedAt = existingDate;
        }
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

    await writeSyncEvent(admin, {
      ...eventContext,
      status: "processed",
      stored_completed_at: finalCompletedAt.toISOString(),
      record_action: recordAction,
    });

    return json({
      ok: true,
      status: "processed",
      student_name: student.name,
      exercise_id: exercise.exercise_id,
      exercise_title: exercise.exercise_title,
      completed_at: finalCompletedAt.toISOString(),
      completion_source: "monitor",
      record_action: recordAction,
      source_email: originalEmail,
    });
  } catch (error) {
    console.error(error);
    if (admin) {
      await writeSyncEvent(admin, {
        ...eventContext,
        status: "error",
        error_message: error instanceof Error ? error.message : "Erro interno",
      });
    }
    return json({
      ok: false,
      status: "error",
      message: error instanceof Error ? error.message : "Erro interno",
    }, 500);
  }
});
