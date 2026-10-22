// 첫 화면(.hero)에 브랜드 색 셰이더 배경과 마우스 빛을 까는 로더 — WebGPU 없음·움직임 줄이기·데이터 절약이면 아무것도 하지 않는다
// 쓰는 법: <script src="/js/shaders-hero.js" data-target=".hero" data-a="#색1" data-b="#색2" data-c="#색3" data-trail="#빛색" data-opacity="0.8" defer></script>
// 라이브러리(npm shaders 4.0.5 번들, 약 700KB 압축)는 jsDelivr 에서, 페이지가 다 뜬 뒤 WebGPU 가 되는 기기에서만 받는다.
(function () {
  var me = document.currentScript;
  if (!me || !('gpu' in navigator)) return;
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  if (navigator.connection && navigator.connection.saveData) return;
  var d = me.dataset;
  var lib = 'https://cdn.jsdelivr.net/npm/shaders@4.0.5/dist/js/bundle.js';
  var TERMINAL = ['unsupported', 'no-adapter', 'no-device', 'init-failed', 'device-lost', 'out-of-memory',
    'gpu-error', 'render-failed', 'limit-exceeded', 'unrecoverable', 'rebuild_failed'];

  function start() {
    var el = document.querySelector(d.target || '.hero');
    if (!el) return;
    navigator.gpu.requestAdapter().then(function (ad) {
      if (!ad) return;
      return import(lib).then(function (m) {
        if (getComputedStyle(el).position === 'static') el.style.position = 'relative';
        el.style.isolation = 'isolate';   // 캔버스를 z-index:-1 로 두어도 히어로 배경 위·내용 아래에 오게
        var c = document.createElement('canvas');
        c.setAttribute('aria-hidden', 'true');
        c.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;z-index:-1;pointer-events:none;'
          + 'opacity:0;transition:opacity 1.2s ease;border-radius:inherit';
        el.prepend(c);
        var layers = [
          // stops 를 주지 않으면 라이브러리 기본 팔레트(주황·보라)가 나온다. 브랜드 색을 직접 넣는다
          { type: 'MeshGradient', props: { stops: [{ color: d.a, position: 0 }, { color: d.b, position: 0.5 }, { color: d.c || d.a, position: 1 }],
            colorSpace: 'oklab', speed: 0.5 }, children: [] },
          { type: 'SimplexNoise', props: { stops: null, colorA: '#000000', colorB: '#ffffff', scale: 3, speed: 0.4, opacity: 0.08, blendMode: 'softLight' }, children: [] }
        ];
        // 마우스 빛은 마우스가 있는 기기(PC)에서만
        if (matchMedia('(pointer: fine)').matches) layers.push({ type: 'CursorTrail',
          props: { stops: null, colorA: d.trail || '#ffffff', colorB: d.b, radius: 0.25, length: 0.35, opacity: 0.45, blendMode: 'screen' }, children: [] });
        return m.createShader(c, { components: layers }, {
          disableTelemetry: true,
          onReady: function () { c.style.opacity = d.opacity || '0.8'; },
          // 기기 분실은 라이브러리가 스스로 다시 세운다. 다시 못 쓰게 된 경우에만 캔버스를 걷어 원래 배경으로
          onError: function (r) { if (TERMINAL.indexOf(r) >= 0) { console.warn('[shaders-hero] 배경 셰이더를 끕니다:', r); c.remove(); } }
        });
      });
    }).catch(function () {});
  }
  function later() { if (window.requestIdleCallback) requestIdleCallback(start, { timeout: 2000 }); else setTimeout(start, 300); }
  if (document.readyState === 'complete') later(); else addEventListener('load', later);
})();
