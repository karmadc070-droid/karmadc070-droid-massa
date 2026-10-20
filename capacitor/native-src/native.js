// 네이티브(iOS) 전용 기능을 window.MassaNative 로 노출하는 번들 진입점 — esbuild로 묶여 앱 www에만 주입된다
import { Capacitor } from "@capacitor/core";
import { PushNotifications } from "@capacitor/push-notifications";
import { Geolocation } from "@capacitor/geolocation";
import { Browser } from "@capacitor/browser";
import { App } from "@capacitor/app";

// iOS WKWebView는 navigator.geolocation 을 기본 제공하지 않는다.
// index.html은 navigator.geolocation 만 쓰므로, 플러그인으로 같은 모양의 API를 덮어써서 코드 변경 없이 동작시킨다.
// 주의: navigator.geolocation 은 getter만 있는 접근자라 단순 대입은 조용히 무시된다. 반드시 defineProperty 를 써야 한다.
function shimGeolocation() {
  const watches = new Map();
  const impl = {
    getCurrentPosition(ok, err, opts) {
      Geolocation.getCurrentPosition(opts).then(ok).catch(err || (() => {}));
    },
    watchPosition(ok, err, opts) {
      const key = Date.now() + Math.random();
      Geolocation.watchPosition(opts || {}, (pos, e) => {
        if (e) { if (err) err(e); return; }
        ok(pos);
      }).then((id) => watches.set(key, id));
      return key;
    },
    clearWatch(key) {
      const id = watches.get(key);
      if (id) { Geolocation.clearWatch({ id }); watches.delete(key); }
    },
  };
  Object.defineProperty(navigator, "geolocation", { value: impl, configurable: true, writable: true });
  return navigator.geolocation === impl;
}

// 푸시 등록 (아이폰 APNs · 안드로이드 FCM). 권한 허용 시 onToken(디바이스 토큰) 을 호출한다.
async function registerPush(onToken, onNotification) {
  // ★ 두 번 불러도 안전하게 만든다 (2026-10-20).
  //   예전에는 리스너가 쌓여서 알림이 두 번 처리됐고, 그래서 앱 실행당 한 번만 불렀다.
  //   그 제약 때문에 로그아웃 후 다른 계정으로 로그인하면 토큰을 다시 받을 길이 없었다.
  //   아침에 울렸던 경로(앱 시작 → 로그인 → 등록)를 로그인할 때마다 그대로 다시 타게 한다.
  try { await PushNotifications.removeAllListeners(); } catch (e) {}
  const perm = await PushNotifications.requestPermissions();
  if (perm.receive !== "granted") return false;

  // ★ 안드로이드는 '알림 채널'이 소리·헤드업 배너를 정한다. 중요도 5(긴급)로 채널을 직접 만든다.
  //   웹푸시(TWA)로는 이걸 못 해서 알림이 조용히 떴다 — 네이티브로 옮긴 이유가 이것이다.
  //   서버는 FCM 에 channel_id 를 같이 실어 보내야 이 채널이 쓰인다.
  //   채널은 한 번 만들어지면 설정이 고정된다. 바꾸려면 id 를 올려야 한다(massa_booking_v2 …).
  if (Capacitor.getPlatform() === "android") {
    try {
      await PushNotifications.createChannel({
        // ★ v2 로 올렸다 (2026-10-19). 안드로이드는 채널이 한 번 만들어지면 소리·중요도가
        //    고정돼서, id 를 그대로 두면 이미 깔린 사람에게 새 알림음이 영영 안 먹는다.
        id: "massa_booking_v2",
        name: "새 신청",
        description: "손님이 신청하면 바로 알립니다",
        sound: "massa",       // android/app/src/main/res/raw/massa.wav (확장자 없이 적는다)
        importance: 5,        // IMPORTANCE_HIGH — 소리 + 화면 위 배너
        visibility: 1,        // 잠금화면에도 보임
        vibration: true,
      });
    } catch (e) { console.warn("알림 채널 생성 실패", e); }
  }

  PushNotifications.addListener("registration", (t) => onToken(t.value));
  if (onNotification) {
    PushNotifications.addListener("pushNotificationReceived", onNotification);
    PushNotifications.addListener("pushNotificationActionPerformed", onNotification);
  }
  await PushNotifications.register();
  return true;
}

// 소셜 로그인·결제창을 앱 안 브라우저(SFSafariViewController)로 연다.
// 사파리로 나가버리면 앱으로 돌아올 수 없고 App Store 가이드라인 4 소지도 생긴다.
async function openExternal(url) {
  await Browser.open({ url, presentationStyle: "popover" });
}

// massa:// 로 되돌아왔을 때를 처리한다.
// 로그인은 massa://auth, 결제는 massa://pay 로 온다.
// 둘 다 실패 시 code= 를 달고 오므로 파라미터가 아니라 호스트로 갈라야 한다.
// ★ 손잡이가 아직 없으면 버리지 말고 쌓아 둔다 (2026-10-19).
//   onNativeAuthReturn 은 index.html 의 module 스크립트 안에서 만들어지는데, 그 스크립트는
//   CDN 에서 supabase-js 를 받아온 뒤에야 끝난다. 앱이 완전히 꺼진 상태에서 massa:// 로 깨어나면
//   그 전에 appUrlOpen 이 먼저 올 수 있다. 전에는 그냥 버려서, 로그인은 성공했는데
//   앱은 로그아웃인 채로 떴다. 결제 복귀도 같은 구멍이었다.
const pending = [];
function deliver(name, arg) {
  const fn = window[name];
  if (typeof fn === "function") { fn(arg); return true; }
  pending.push([name, arg]);
  return false;
}
// 손잡이가 생겼는지 잠깐 지켜본다. 20초면 CDN 이 아무리 느려도 충분하다.
let waits = 0;
const timer = setInterval(() => {
  for (let i = pending.length - 1; i >= 0; i--) {
    const fn = window[pending[i][0]];
    if (typeof fn === "function") { fn(pending[i][1]); pending.splice(i, 1); }
  }
  if (!pending.length || ++waits > 80) clearInterval(timer);
}, 250);

function handleAppUrl(url) {
  try {
    Browser.close().catch(() => {});
    const u = new URL(url);
    const target = u.host || u.pathname.replace(/^\/+/, "");
    if (target === "pay") { deliver("onNativePayReturn", u.search); return; }
    // 로그인 — 토큰은 # 뒤에, PKCE 코드는 ? 뒤에 붙는다. 그대로 넘기면 supabase-js 가 세션을 세운다.
    // ★ 거절·오류도 # 뒤에 error= 로 온다. access_token 만 보면 그 이유를 통째로 버리게 된다.
    const useHash = !!u.hash && /access_token=|error=/.test(u.hash);
    deliver("onNativeAuthReturn", useHash ? u.hash : u.search);
  } catch (e) { console.error("appUrlOpen 처리 실패", e); }
}

let geoShimmed = false;
if (Capacitor.isNativePlatform()) {
  geoShimmed = shimGeolocation();
  if (!geoShimmed) console.error("navigator.geolocation 대체 실패 — 위치 기능이 동작하지 않을 수 있음");
  App.addListener("appUrlOpen", (e) => handleAppUrl(e.url));
}

// 네이티브 앱의 알림 권한을 묻는다. 웹의 Notification API 는 iOS WebView 에 아예 없어서,
// 그걸로 판단하면 "이 기기에서는 알림을 쓸 수 없습니다" 라는 거짓말을 하게 된다 (2026-10-19).
async function checkPush() {
  try {
    const p = await PushNotifications.checkPermissions();
    return p.receive;          // 'granted' | 'denied' | 'prompt' | 'prompt-with-rationale'
  } catch (e) { return 'unknown'; }
}

window.IS_NATIVE_APP = Capacitor.isNativePlatform();
window.openExternal = openExternal;
window.MassaNative = {
  platform: Capacitor.getPlatform(),
  isNative: Capacitor.isNativePlatform(),
  geoShimmed,
  registerPush,
  checkPush,
  openExternal,
};
