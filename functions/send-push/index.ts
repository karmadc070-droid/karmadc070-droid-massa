// 아직 안 보낸 알림(notifications.pushed_at 이 빈 행)을 그 사용자의 아이폰에 APNs 푸시로 보낸다. DB 트리거(pg_net)와 1분 크론이 부른다.
// APNs 코드는 VIBI challenge-push 와 같다(같은 Apple 팀의 APNs 키를 쓴다). 공개 엔드포인트라 notify-admin 과 같은 공유 시크릿으로 막는다.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TOPIC = "app.massa.hanoi";
const NOTIFY_SECRET = Deno.env.get("NOTIFY_SECRET") ?? "";
const json = (o: unknown, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { "Content-Type": "application/json" } });

function b64url(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
// .env 에는 키가 한 줄로 들어 있고 줄바꿈이 글자 그대로의 \n 으로 적혀 있어서 그것도 지운다.
function pemToDer(pem: string): Uint8Array {
  const body = pem.replace(/\\n/g, "").replace(/-----BEGIN [^-]+-----/g, "").replace(/-----END [^-]+-----/g, "").replace(/\s+/g, "");
  const bin = atob(body);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return der;
}

// APNs 토큰은 1시간 유효하고 20분보다 잦게 만들면 안 된다 → 인스턴스가 살아 있는 동안 30분 캐시
let apnsJwt: { token: string; at: number } | null = null;
async function getApnsJwt(): Promise<string | null> {
  const teamId = Deno.env.get("APPLE_TEAM_ID");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const p8 = Deno.env.get("APNS_PRIVATE_KEY");
  if (!teamId || !keyId || !p8) return null;
  if (apnsJwt && Date.now() - apnsJwt.at < 30 * 60 * 1000) return apnsJwt.token;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const payload = b64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: now })));
  const input = `${header}.${payload}`;
  const key = await crypto.subtle.importKey("pkcs8", pemToDer(p8), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  apnsJwt = { token: `${input}.${b64url(new Uint8Array(sig))}`, at: Date.now() };
  return apnsJwt.token;
}

// App Store·TestFlight 빌드는 production, Xcode 직접 설치는 sandbox. production 먼저 보내고 BadDeviceToken 이면 sandbox 로 다시 보낸다.
const APNS_HOSTS = ["https://api.push.apple.com", "https://api.sandbox.push.apple.com"];

// kind·booking_id 는 알림 data 로 앱에 전달된다 → 누르면 index.html 이 해당 화면을 연다.
async function sendApns(jwt: string, token: string, title: string, body: string, kind: string, bookingId: string | null) {
  const payload = JSON.stringify({ aps: { alert: { title, body }, sound: "default" }, kind, booking_id: bookingId });
  let lastError = "";
  for (const host of APNS_HOSTS) {
    const res = await fetch(`${host}/3/device/${token}`, {
      method: "POST",
      headers: { authorization: `bearer ${jwt}`, "apns-topic": TOPIC, "apns-push-type": "alert", "apns-priority": "10", "content-type": "application/json" },
      body: payload,
    });
    if (res.ok) return { ok: true, gone: false, error: "" };
    const txt = await res.text();
    // 앱을 지운 기기는 410 Unregistered → 토큰을 지운다
    if (res.status === 410 || txt.includes("Unregistered")) return { ok: false, gone: true, error: `${res.status} ${txt}` };
    // 토큰 환경이 반대이거나, 키가 한쪽 환경 전용이면 다른 호스트로 다시 보낸다.
    if (txt.includes("BadDeviceToken") || txt.includes("BadEnvironmentKeyInToken")) {
      lastError += `${host} ${res.status} ${txt} `;
      continue;
    }
    return { ok: false, gone: false, error: `${res.status} ${txt}` };
  }
  // 두 호스트 모두 BadDeviceToken 이면 죽은 토큰, 키 환경 문제면 토큰은 남기고 오류를 알린다.
  if (lastError.includes("BadEnvironmentKeyInToken")) return { ok: false, gone: false, error: lastError };
  return { ok: false, gone: true, error: lastError };
}

// ── 웹푸시 (안드로이드 TWA·브라우저) ──────────────────────────
// 안드로이드는 TWA 라 APNs 도 네이티브 FCM 도 못 쓴다. 표준 Web Push + VAPID 로 보낸다.
// Firebase 프로젝트는 필요 없다. 브라우저가 준 endpoint 로 그냥 POST 한다.
//
// ★ 본문을 싣지 않는다(payload 없음). 본문을 실으려면 aes128gcm 암호화가 필요한데,
//   서비스워커가 고정 문구로 알림을 띄우는 것으로 충분하다. 내용은 앱을 열면 보인다.
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC_KEY") ?? "";
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:support@massaviet.com";

// VAPID JWT 는 수신 서버(origin)마다 다르고 최대 24시간이다. origin 별로 12시간 캐시한다.
const vapidJwts = new Map<string, { token: string; at: number }>();
async function getVapidJwt(origin: string): Promise<string | null> {
  if (!VAPID_PRIVATE) return null;
  const hit = vapidJwts.get(origin);
  if (hit && Date.now() - hit.at < 12 * 60 * 60 * 1000) return hit.token;
  const header = b64url(new TextEncoder().encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const payload = b64url(new TextEncoder().encode(JSON.stringify({
    aud: origin, exp: Math.floor(Date.now() / 1000) + 23 * 60 * 60, sub: VAPID_SUBJECT,
  })));
  const input = `${header}.${payload}`;
  // VAPID 개인키는 raw d 값(base64url 32바이트)이라 JWK 로 넣는다.
  const key = await crypto.subtle.importKey(
    "jwk",
    { kty: "EC", crv: "P-256", d: VAPID_PRIVATE, x: b64url(b64urlToBytes(VAPID_PUBLIC).slice(1, 33)), y: b64url(b64urlToBytes(VAPID_PUBLIC).slice(33, 65)), ext: true },
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  const token = `${input}.${b64url(new Uint8Array(sig))}`;
  vapidJwts.set(origin, { token, at: Date.now() });
  return token;
}
function b64urlToBytes(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4);
  const bin = atob((s + pad).replace(/-/g, "+").replace(/_/g, "/"));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function sendWebPush(subJson: string) {
  let endpoint = "";
  try { endpoint = JSON.parse(subJson).endpoint ?? ""; } catch { /* 깨진 구독 */ }
  if (!endpoint) return { ok: false, gone: true, error: "구독 정보를 읽을 수 없습니다" };
  const origin = new URL(endpoint).origin;
  const jwt = await getVapidJwt(origin);
  if (!jwt) return { ok: false, gone: false, error: "VAPID_PRIVATE_KEY 가 없습니다" };
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      authorization: `vapid t=${jwt}, k=${VAPID_PUBLIC}`,
      ttl: "3600",
      urgency: "high",
      "content-length": "0",
    },
  });
  if (res.ok) return { ok: true, gone: false, error: "" };
  const txt = await res.text();
  // 404·410 은 구독이 사라진 것 — 토큰을 지운다.
  if (res.status === 404 || res.status === 410) return { ok: false, gone: true, error: `${res.status} ${txt}` };
  return { ok: false, gone: false, error: `${res.status} ${txt.slice(0, 200)}` };
}

// ── 안드로이드 네이티브 (FCM HTTP v1) ────────────────────────
// 웹푸시로는 소리·헤드업 배너를 못 낸다. 네이티브 앱은 '알림 채널'을 직접 만들 수 있고
// (native.js 에서 massa_booking, importance 5), 서버가 channel_id 를 실어 보내야 그 채널이 쓰인다.
//
// FCM HTTP v1 은 서비스 계정으로 OAuth2 토큰을 받아야 한다. 레거시 서버키는 폐지됐다.
const FCM_SA = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";   // 서비스 계정 JSON 통째로

let fcmTok: { token: string; at: number } | null = null;
async function getFcmAccessToken(): Promise<{ token: string; projectId: string } | null> {
  if (!FCM_SA) return null;
  let sa: { client_email: string; private_key: string; project_id: string };
  try { sa = JSON.parse(FCM_SA); } catch { return null; }
  // 액세스 토큰은 1시간짜리다. 50분 캐시한다.
  if (!fcmTok || Date.now() - fcmTok.at > 50 * 60 * 1000) {
    const now = Math.floor(Date.now() / 1000);
    const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
    const claim = b64url(new TextEncoder().encode(JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now, exp: now + 3600,
    })));
    const input = `${header}.${claim}`;
    const key = await crypto.subtle.importKey(
      "pkcs8", pemToDer(sa.private_key),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
    );
    const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(input));
    const assertion = `${input}.${b64url(new Uint8Array(sig))}`;
    const res = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion,
      }),
    });
    if (!res.ok) { console.error("FCM 토큰 발급 실패", await res.text()); return null; }
    fcmTok = { token: (await res.json()).access_token, at: Date.now() };
  }
  return { token: fcmTok.token, projectId: sa.project_id };
}

async function sendFcm(deviceToken: string, title: string, body: string, kind: string, bookingId: string | null) {
  const auth = await getFcmAccessToken();
  if (!auth) return { ok: false, gone: false, error: "FCM_SERVICE_ACCOUNT 가 없습니다" };
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${auth.projectId}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${auth.token}`, "content-type": "application/json" },
    body: JSON.stringify({
      message: {
        token: deviceToken,
        notification: { title, body },
        data: { kind, booking_id: bookingId ?? "" },
        android: {
          priority: "HIGH",
          notification: {
            // ★ 이 채널이 소리·헤드업 배너를 정한다. 앱이 같은 id 로 채널을 만들어 두어야 한다.
            channel_id: "massa_booking",
            default_sound: true,
            notification_priority: "PRIORITY_MAX",
          },
        },
      },
    }),
  });
  if (res.ok) return { ok: true, gone: false, error: "" };
  const txt = await res.text();
  // 앱을 지웠거나 토큰이 죽은 경우 — 지운다
  if (res.status === 404 || txt.includes("UNREGISTERED") || txt.includes("INVALID_ARGUMENT")) {
    return { ok: false, gone: true, error: `${res.status} ${txt.slice(0, 200)}` };
  }
  return { ok: false, gone: false, error: `${res.status} ${txt.slice(0, 200)}` };
}

// 예약 알림 제목은 기기 언어로 쓴다. 중국어·일본어 화면은 영어로 보낸다. 공지는 관리자가 쓴 문장 그대로.
const TITLE: Record<string, Record<string, string>> = {
  booking_new: { vi: "Có lịch đặt mới", ko: "새 예약이 들어왔습니다", en: "New booking received" },
  booking_confirmed: { vi: "Đã xác nhận đặt lịch", ko: "예약이 확정되었습니다", en: "Your booking is confirmed" },
  booking_on_the_way: { vi: "Kỹ thuật viên đang trên đường đến", ko: "테라피스트가 출발했습니다", en: "Your therapist is on the way" },
  booking_completed: { vi: "Dịch vụ đã hoàn tất. Hãy để lại đánh giá nhé.", ko: "서비스가 완료되었습니다. 평가를 남겨주세요", en: "Your service is complete. Please leave a review." },
  booking_cancelled: { vi: "Đã hủy đặt lịch.", ko: "예약이 취소되었습니다.", en: "Your booking has been cancelled." },
  booking_cancelled_by_customer: { vi: "Khách đã hủy đặt lịch", ko: "손님이 예약을 취소했습니다", en: "The customer cancelled the booking" },
};

type Noti = { id: string; user_id: string; title: string | null; body: string | null; kind: string; booking_id: string | null };
type Tok = { token: string; user_id: string; lang: string; platform: string | null };

Deno.serve(async (req) => {
  if (!NOTIFY_SECRET || req.headers.get("x-notify-secret") !== NOTIFY_SECRET) return json({ error: "unauthorized" }, 401);
  // 보낼 수단이 하나도 없으면 claim 하기 전에 멈춘다(알림이 조용히 사라지지 않게).
  const jwt = await getApnsJwt();          // 없으면 아이폰만 못 보낸다 — 웹푸시는 계속 간다
  if (!jwt && !VAPID_PRIVATE && !FCM_SA) {
    return json({ error: "APNs·VAPID·FCM 키가 모두 없습니다 — 보낼 수단이 없습니다" }, 500);
  }

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: notis, error } = await db.rpc("claim_unpushed_notifications").returns<Noti[]>();
  if (error) return json({ error: error.message }, 500);
  if (!notis.length) return json({ ok: true, claimed: 0 });

  const users = [...new Set(notis.map((n) => n.user_id))];
  const { data: toks, error: e2 } = await db.from("push_tokens").select("token, user_id, lang, platform").in("user_id", users).returns<Tok[]>();
  if (e2) return json({ error: e2.message }, 500);

  let sent = 0, removed = 0, noDevice = 0;
  const errors: string[] = [];
  for (const n of notis) {
    const mine = toks.filter((x) => x.user_id === n.user_id);
    // ★ 받을 기기가 없으면 '보냄'으로 두지 않는다. 예전에는 그대로 두어서
    //   아무에게도 안 갔는데 전부 발송된 것처럼 보였다 (2026-10-18 수정).
    if (!mine.length) {
      noDevice++;
      await db.from("notifications").update({ push_result: "no_device" }).eq("id", n.id);
      continue;
    }
    let okAny = false;
    const errs: string[] = [];
    for (const t of mine) {
      const lang = ["vi", "ko"].includes(t.lang) ? t.lang : "en";
      const title = TITLE[n.kind]?.[lang] ?? n.title ?? "massa";
      const r = t.platform === "web"
        ? await sendWebPush(t.token)
        : t.platform === "android"
        ? await sendFcm(t.token, title, n.body ?? "", n.kind, n.booking_id)
        : jwt
        ? await sendApns(jwt, t.token, title, n.body ?? "", n.kind, n.booking_id)
        : { ok: false, gone: false, error: "APNs 키 없음" };
      if (r.ok) { sent++; okAny = true; }
      else if (r.gone) { removed++; await db.from("push_tokens").delete().eq("token", t.token); }
      if (r.error) { errs.push(r.error.slice(0, 300)); errors.push(r.error.slice(0, 300)); }
    }
    await db.from("notifications")
      .update({ push_result: okAny ? "sent" : `failed: ${errs.join(" | ").slice(0, 300)}` })
      .eq("id", n.id);
  }
  return json({ ok: true, claimed: notis.length, sent, removed, noDevice, errors: errors.slice(0, 3) });
});
