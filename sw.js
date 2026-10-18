// 앱 셸과 정적 이미지를 캐시해 오프라인·재방문 속도를 높이는 서비스 워커
const CACHE = 'massa-v2';   // 웹푸시 추가 (2026-10-18) — 이름을 바꿔야 옛 캐시가 정리된다
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
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// ── 웹푸시 (안드로이드) ──────────────────────────────────────
// 아이폰은 앱(Capacitor)이 APNs 로 받는다. 안드로이드는 TWA(웹 껍데기)라 그 길이 없어서
// 표준 Web Push 를 쓴다. Firebase 프로젝트는 필요 없다 — VAPID 키 한 쌍이면 된다.
//
// ★ 본문(payload)은 비워서 보낸다. 본문을 실으려면 aes128gcm 암호화를 서버에 구현해야 하는데,
//   마사지사에게 필요한 건 '뭔가 왔다'는 사실이지 본문이 아니다. 열면 앱에서 바로 보인다.
self.addEventListener('push', e => {
  e.waitUntil(self.registration.showNotification('massa', {
    body: 'Có yêu cầu mới — hãy mở ứng dụng để xem.',   // 새 신청이 들어왔습니다
    icon: './icon-192.png',
    badge: './icon-192.png',
    tag: 'massa-booking',     // 여러 건이 와도 알림이 쌓이지 않게 한 줄로 덮어쓴다
    renotify: true,
    requireInteraction: true  // 손으로 지울 때까지 남는다. 주문을 놓치면 안 된다
  }));
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
