import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

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
    headers: { ...corsHeaders(origin), "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function getKey(envName: string, legacyName: string) {
  const raw = Deno.env.get(envName);
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed?.default) return parsed.default;
      const first = Object.values(parsed || {})[0];
      if (typeof first === "string") return first;
    } catch (_) {}
  }
  return Deno.env.get(legacyName) || "";
}

async function consumeLimit(admin: ReturnType<typeof createClient>, key: string, windowSeconds: number, maxRequests: number) {
  const { data, error } = await admin.rpc("consume_api_rate_limit", {
    target_bucket_key: key,
    target_window_seconds: windowSeconds,
    target_max_requests: maxRequests,
  });
  if (error) throw error;
  return data === true;
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin");
  if (origin && origin !== allowedOrigin) return json({ error: "Origem não permitida." }, 403, origin);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders(origin) });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405, origin);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const publishableKey = getKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY");
    const secretKey = getKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
    const azureKey = Deno.env.get("AZURE_SPEECH_KEY") || "";
    const azureRegion = Deno.env.get("AZURE_SPEECH_REGION") || "";

    if (!azureKey || !azureRegion) return json({ error: "Azure Speech ainda não foi configurado no servidor." }, 503, origin);
    if (!supabaseUrl || !publishableKey || !secretKey) return json({ error: "Configuração interna do Supabase incompleta." }, 500, origin);

    const authorization = req.headers.get("Authorization") || "";
    if (!authorization.startsWith("Bearer ")) return json({ error: "Sessão inválida." }, 401, origin);

    const userClient = createClient(supabaseUrl, publishableKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json({ error: "Usuário não autenticado." }, 401, origin);
    const user = userData.user;

    const admin = createClient(supabaseUrl, secretKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const hourlyAllowed = await consumeLimit(admin, `pronunciation:hour:${user.id}`, 3600, 30);
    if (!hourlyAllowed) return json({ error: "Limite de avaliações de pronúncia atingido. Tente novamente mais tarde." }, 429, origin);
    const dailyAllowed = await consumeLimit(admin, `pronunciation:day:${user.id}`, 86400, 200);
    if (!dailyAllowed) return json({ error: "Limite diário de avaliações de pronúncia atingido." }, 429, origin);

    const contentLength = Number(req.headers.get("content-length") || "0");
    if (Number.isFinite(contentLength) && contentLength > 16 * 1024 * 1024) {
      return json({ error: "Requisição muito grande." }, 413, origin);
    }

    const form = await req.formData();
    const audio = form.get("audio");
    const assignmentId = String(form.get("assignment_id") || "").trim() || null;
    const referenceText = String(form.get("reference_text") || "").trim();
    const locale = String(form.get("locale") || "en-US").trim();
    const durationSeconds = Number(form.get("duration_seconds") || 0);

    if (!(audio instanceof File) || audio.size === 0) return json({ error: "Gravação não recebida." }, 400, origin);
    if (!referenceText) return json({ error: "Texto de referência ausente." }, 400, origin);
    if (referenceText.length > 5000) return json({ error: "Texto de referência muito longo." }, 400, origin);
    if (audio.size > 15 * 1024 * 1024) return json({ error: "Arquivo de áudio muito grande." }, 413, origin);

    const assessmentConfig = {
      ReferenceText: referenceText,
      GradingSystem: "HundredMark",
      Granularity: "Phoneme",
      Dimension: "Comprehensive",
      EnableProsodyAssessment: false,
    };
    const assessmentHeader = btoa(unescape(encodeURIComponent(JSON.stringify(assessmentConfig))));
    const azureUrl = `https://${azureRegion}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=${encodeURIComponent(locale)}&format=detailed`;
    const audioBytes = await audio.arrayBuffer();

    const azureResponse = await fetch(azureUrl, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": azureKey,
        "Pronunciation-Assessment": assessmentHeader,
        "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
        "Accept": "application/json",
      },
      body: audioBytes,
    });

    const azureText = await azureResponse.text();
    let azureResult: any = null;
    try { azureResult = JSON.parse(azureText); } catch (_) {}
    if (!azureResponse.ok || !azureResult) {
      return json({ error: "O Azure não conseguiu analisar a gravação.", detail: azureText.slice(0, 500) }, 502, origin);
    }

    const best = Array.isArray(azureResult.NBest) ? azureResult.NBest[0] : null;
    const pa = best?.PronunciationAssessment || {};
    const words = Array.isArray(best?.Words) ? best.Words.map((w: any) => ({
      word: w.Word,
      accuracy_score: w.PronunciationAssessment?.AccuracyScore ?? null,
      error_type: w.PronunciationAssessment?.ErrorType ?? "None",
      phonemes: Array.isArray(w.Phonemes) ? w.Phonemes.map((p: any) => ({
        phoneme: p.Phoneme,
        accuracy_score: p.PronunciationAssessment?.AccuracyScore ?? null,
      })) : [],
    })) : [];

    const bucket = "pronunciation-audio";
    const { data: buckets } = await admin.storage.listBuckets();
    if (!buckets?.some((b: any) => b.name === bucket)) {
      const { error: bucketError } = await admin.storage.createBucket(bucket, {
        public: false,
        fileSizeLimit: 15 * 1024 * 1024,
        allowedMimeTypes: ["audio/wav"],
      });
      if (bucketError && !String(bucketError.message).toLowerCase().includes("already")) throw bucketError;
    }

    const attemptId = crypto.randomUUID();
    const audioPath = `${user.id}/${attemptId}.wav`;
    const { error: uploadError } = await admin.storage.from(bucket).upload(audioPath, audioBytes, {
      contentType: "audio/wav",
      upsert: false,
    });
    if (uploadError) throw uploadError;

    const record = {
      id: attemptId,
      user_id: user.id,
      assignment_id: assignmentId,
      reference_text: referenceText,
      locale,
      audio_path: audioPath,
      duration_seconds: Number.isFinite(durationSeconds) ? durationSeconds : null,
      accuracy_score: pa.AccuracyScore ?? null,
      fluency_score: pa.FluencyScore ?? null,
      completeness_score: pa.CompletenessScore ?? null,
      pronunciation_score: pa.PronScore ?? null,
      prosody_score: pa.ProsodyScore ?? null,
      words,
      azure_result: azureResult,
      status: "processed",
    };

    const { error: insertError } = await admin.from("pronunciation_attempts").insert(record);
    if (insertError) {
      await admin.storage.from(bucket).remove([audioPath]);
      throw insertError;
    }

    return json({
      attempt_id: attemptId,
      pronunciation_score: record.pronunciation_score,
      accuracy_score: record.accuracy_score,
      fluency_score: record.fluency_score,
      completeness_score: record.completeness_score,
      prosody_score: record.prosody_score,
      words,
    }, 200, origin);
  } catch (error) {
    console.error(error);
    return json({ error: "Não foi possível processar a gravação." }, 500, origin);
  }
});
