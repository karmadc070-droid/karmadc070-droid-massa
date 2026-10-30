// 앱 셸과 정적 이미지를 캐시해 오프라인·재방문 속도를 높이는 서비스 워커
const CACHE = 'massa-v5';   // v5: 푸시 문구를 국적 언어로 (2026-10-30). 이름을 바꿔야 새 워커가 적용된다
const SHELL = [
  './',
  './manifest.webmanifest',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => Promise.allSettled(SHELL.map(u => c.add(u))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE && k !== PREF).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// ── 웹푸시 (안드로이드) ──────────────────────────────────────
// 아이폰은 앱(Capacitor)이 APNs 로 받는다. 안드로이드는 TWA(웹 껍데기)라 그 길이 없어서
// 표준 Web Push 를 쓴다. Firebase 프로젝트는 필요 없다 — VAPID 키 한 쌍이면 된다.
//
// ★ 본문(payload)은 비워서 보낸다. 본문을 실으려면 aes128gcm 암호화를 서버에 구현해야 하는데,
//   마사지사에게 필요한 건 '뭔가 왔다'는 사실이지 본문이 아니다. 열면 앱에서 바로 보인다.
// ★ 본문이 없으니 알림 종류도 알 수 없다. 그래서 문구는 '어떤 종류든 사실인 말'이어야 한다.
//   예전 문구는 '새 신청이 들어왔습니다' 였는데, 환영 공지를 보내도 그렇게 떠서
//   마사지사가 앱을 열면 예약이 없는 상황이 된다 — 거짓말이 된다 (2026-10-18 수정).
//   정확한 문구는 네이티브(FCM·APNs)에서 나온다. 거기서는 본문이 실려 온다.
// 본문이 없어서 수신자 언어를 서버에서 알 수 없다 — 앱이 국적으로 정해 massa-pref 캐시에 둔 언어를 읽는다.
// 국적이 없거나 아직 저장 전이면 베트남어다 (2026-10-30)
const PREF = 'massa-pref';
const PUSH_BODY = {
  vi: 'Bạn có thông báo mới — hãy mở ứng dụng để xem.',
  ko: '새 알림이 있습니다 — 앱에서 확인하세요.',
  en: 'You have a new notification — open the app to see it.',
  zh: '您有新通知，请打开应用查看。',
  ja: '新しいお知らせがあります。アプリを開いて確認してください。'
};
self.addEventListener('push', e => {
  e.waitUntil(caches.open(PREF)
    .then(c => c.match(new URL('push-lang', self.registration.scope)))
    .then(r => r ? r.text() : 'vi')
    .catch(() => 'vi')
    .then(lang => self.registration.showNotification('massa', {
    body: PUSH_BODY[lang] || PUSH_BODY.vi,
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: 'massa-booking',     // 여러 건이 와도 알림이 쌓이지 않게 한 줄로 덮어쓴다
    renotify: true,
    requireInteraction: true, // 손으로 지울 때까지 남는다. 주문을 놓치면 안 된다
    // ★ 소리와 헤드업 배너는 여기서 못 켠다. 안드로이드는 '알림 채널'이 정하고
    //   크롬은 사이트마다 채널을 하나 만드는데 웹페이지가 그 중요도를 바꿀 수 없다.
    //   웹에서 할 수 있는 건 진동뿐이다. 소리까지 내려면 네이티브 앱이어야 한다.
    vibrate: [300, 150, 300, 150, 300]
  })));
});

// 알림을 누르면 이미 열린 창으로 보내고, 없으면 새로 연다.
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(ws => {
    for (const w of ws) if ('focus' in w) return w.focus();
    return self.clients.openWindow('./');
  }));
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // 슈퍼베이스 등 외부 요청과 GET 이외는 손대지 않는다.
  if (e.request.method !== 'GET' || url.origin !== self.location.origin) return;

  // 문서 요청은 네트워크 우선 — 배포 직후에도 최신 화면이 뜨도록 한다.
  if (e.request.mode === 'navigate') {
    e.respondWith(
      fetch(e.request)
        .then(r => { const cl = r.clone(); caches.open(CACHE).then(c => c.put('./', cl)); return r; })
        .catch(() => caches.match('./').then(r => r || Response.error()))
    );
    return;
  }

  // 이미지·아이콘 등 정적 자원은 캐시 우선.
  e.respondWith(
    caches.match(e.request).then(hit => hit || fetch(e.request).then(r => {
      if (r && r.ok && r.type === 'basic') { const cl = r.clone(); caches.open(CACHE).then(c => c.put(e.request, cl)); }
      return r;
    }))
  );
});
