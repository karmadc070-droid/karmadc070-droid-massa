// 운영 콘솔 전용 번역(베트남어↔한국어) — 관리자만 호출. 파파고 우선, 실패하면 구글 번역(emoi send-message 와 같은 순서)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });

async function papago(text: string, source: string, target: string): Promise<string | null> {
  const id = Deno.env.get("PAPAGO_CLIENT_ID");
  const secret = Deno.env.get("PAPAGO_CLIENT_SECRET");
  if (!id || !secret) return null;
  try {
    const r = await fetch("https://papago.apigw.ntruss.com/nmt/v1/translation", {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-ncp-apigw-api-key-id": id, "x-ncp-apigw-api-key": secret },
      body: JSON.stringify({ source, target, text }),
      signal: AbortSignal.timeout(5000),
    });
    if (!r.ok) return null;
    return (await r.json())?.message?.result?.translatedText ?? null;
  } catch { return null; }
}

async function google(text: string, source: string, target: string): Promise<string | null> {
  const key = Deno.env.get("GOOGLE_TRANSLATE_API_KEY");
  if (!key) return null;
  try {
    const r = await fetch(`https://translation.googleapis.com/language/translate/v2?key=${key}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ q: text, source, target, format: "text" }),
      signal: AbortSignal.timeout(5000),
    });
    if (!r.ok) return null;
    return (await r.json())?.data?.translations?.[0]?.translatedText ?? null;
  } catch { return null; }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || Deno.env.get("SUPABASE_SERVICE_KEY")!,
  );
  const { data: u } = await admin.auth.getUser(token);
  if (!u?.user) return json({ error: "unauthorized" }, 401);
  const { data: p } = await admin.from("profiles").select("role").eq("id", u.user.id).single();
  if (p?.role !== "admin") return json({ error: "forbidden" }, 403);

  let body: { texts?: unknown; target?: unknown } = {};
  try { body = await req.json(); } catch { return json({ error: "bad json" }, 400); }
  const target = body.target === "vi" ? "vi" : "ko";
  const source = target === "ko" ? "vi" : "ko";
  const texts = (Array.isArray(body.texts) ? body.texts : []).slice(0, 30).map((t) => String(t).slice(0, 1000));
  const translations = await Promise.all(
    texts.map(async (t) => (await papago(t, source, target)) ?? (await google(t, source, target))),
  );
  return json({ translations });
});
