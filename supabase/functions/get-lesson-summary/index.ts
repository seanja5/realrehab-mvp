// get-lesson-summary: returns AI summary for a lesson (patient or PT). Checks cache first; on miss calls OpenAI and caches.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestPayload {
  audience: "patient" | "pt";
  lesson_id: string;
  patient_profile_id: string;
  score: number;
  reps_target: number;
  reps_completed: number;
  reps_attempted: number;
  total_duration_sec: number;
  event_counts: {
    drift_left?: number;
    drift_right?: number;
    too_fast?: number;
    too_slow?: number;
    max_not_reached?: number;
    shake?: number;
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: RequestPayload;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { audience, lesson_id, patient_profile_id, score, reps_target, reps_completed, reps_attempted, total_duration_sec, event_counts } = body;
  if (!audience || !lesson_id || !patient_profile_id || typeof score !== "number") {
    return new Response(JSON.stringify({ error: "Missing or invalid required fields" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (audience !== "patient" && audience !== "pt") {
    return new Response(JSON.stringify({ error: "audience must be 'patient' or 'pt'" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
  const useCache = Boolean(serviceRoleKey && serviceRoleKey.length > 0);
  const supabase = createClient(supabaseUrl, serviceRoleKey ?? "", {});

  // 1) Check cache (only if service role key is set)
  if (useCache) {
    const { data: cached, error: cacheError } = await supabase
    .schema("rehab")
    .from("lesson_ai_summaries")
    .select("patient_summary, next_time_cue, pt_summary")
    .eq("lesson_id", lesson_id)
    .eq("patient_profile_id", patient_profile_id)
    .eq("audience", audience)
    .maybeSingle();

    if (!cacheError && cached) {
      if (audience === "patient" && cached.patient_summary && cached.next_time_cue) {
        return new Response(
          JSON.stringify({ patientSummary: cached.patient_summary, nextTimeCue: cached.next_time_cue }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      if (audience === "pt" && cached.pt_summary) {
        return new Response(
          JSON.stringify({ ptSummary: cached.pt_summary }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }
  }

  // 2) Cache miss or no cache: call OpenAI
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey || openaiKey.length === 0) {
    return new Response(JSON.stringify({ error: "OpenAI API key not configured" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const counts = event_counts ?? {};
  const stats = `Score: ${score}/100. Reps: ${reps_completed}/${reps_attempted} completed (target ${reps_target}). Duration: ${total_duration_sec}s. Events: drift_left=${counts.drift_left ?? 0}, drift_right=${counts.drift_right ?? 0}, too_fast=${counts.too_fast ?? 0}, too_slow=${counts.too_slow ?? 0}, max_not_reached=${counts.max_not_reached ?? 0}, shake=${counts.shake ?? 0}.`;

  let systemPrompt: string;
  let userPrompt: string;
  let responseKey: "patientSummary" | "ptSummary";

  if (audience === "patient") {
    systemPrompt = "You are a supportive physical therapy assistant. Respond only with valid JSON. No markdown or extra text.";
    userPrompt = `Given this knee extension lesson data: ${stats}. Return a JSON object with exactly two keys: "patientSummary" (2-4 sentences for the patient: what their score means, what went well, what to focus on; encouraging and plain language) and "nextTimeCue" (one short line starting with "Next time try: " and one concrete cue based on the main issue, e.g. drift, pace, or steadiness).`;
    responseKey = "patientSummary";
  } else {
    systemPrompt = "You are a clinical physical therapy assistant. Respond only with valid JSON. No markdown or extra text.";
    userPrompt = `Given this knee extension lesson data: ${stats}. Return a JSON object with one key "ptSummary": 2-3 sentences for the PT (what went well, what to focus on, any cue suggestion). Clinical but concise.`;
    responseKey = "ptSummary";
  }

  let openaiRes: Response;
  try {
    openaiRes = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userPrompt },
        ],
        response_format: { type: "json_object" },
        max_tokens: 400,
      }),
    });
  } catch (e) {
    console.error("OpenAI request failed:", e);
    return new Response(JSON.stringify({ error: "AI service unavailable" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!openaiRes.ok) {
    const errText = await openaiRes.text();
    console.error("OpenAI error:", openaiRes.status, errText);
    return new Response(JSON.stringify({ error: "AI service error" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const openaiJson = await openaiRes.json();
  const content = openaiJson.choices?.[0]?.message?.content;
  if (!content || typeof content !== "string") {
    return new Response(JSON.stringify({ error: "Invalid AI response" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let parsed: Record<string, string>;
  try {
    parsed = JSON.parse(content);
  } catch {
    return new Response(JSON.stringify({ error: "Invalid AI JSON" }), {
      status: 503,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const now = new Date().toISOString();
  const row = {
    lesson_id,
    patient_profile_id,
    audience,
    updated_at: now,
  };

  if (audience === "patient") {
    const patientSummary = (parsed.patientSummary ?? "").trim();
    const nextTimeCue = (parsed.nextTimeCue ?? "").trim();
    if (!patientSummary || !nextTimeCue) {
      return new Response(JSON.stringify({ error: "Incomplete AI response" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (useCache) {
      await supabase.schema("rehab").from("lesson_ai_summaries").upsert(
        { ...row, patient_summary: patientSummary, next_time_cue: nextTimeCue },
        { onConflict: "lesson_id,patient_profile_id,audience" }
      );
    }
    return new Response(
      JSON.stringify({ patientSummary, nextTimeCue }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } else {
    const ptSummary = (parsed.ptSummary ?? "").trim();
    if (!ptSummary) {
      return new Response(JSON.stringify({ error: "Incomplete AI response" }), {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (useCache) {
      await supabase.schema("rehab").from("lesson_ai_summaries").upsert(
        { ...row, pt_summary: ptSummary },
        { onConflict: "lesson_id,patient_profile_id,audience" }
      );
    }
    return new Response(
      JSON.stringify({ ptSummary }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
