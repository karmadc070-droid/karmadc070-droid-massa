// massa 객실 QR 카드(admin/partner-card.html)를 샘플 코드로 A6 PDF·PNG 로 저장한다 — 호텔 제휴 키트용
const { chromium } = require('C:/Users/user/Claude/Projects/채널/node_modules/playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const ROOT = 'C:/Users/user/Claude/Projects/massa', OUT = ROOT + '/partners/hotel-qr/';
const code = process.argv[2] || 'SAMPLE', name = process.argv[3] || '';
const srv = http.createServer((q, s) => {
  const f = path.join(ROOT, decodeURIComponent(new URL(q.url, 'http://x').pathname));
  fs.readFile(f, (e, b) => { if (e) { s.writeHead(404); s.end(); return; } s.writeHead(200, { 'content-type': f.endsWith('.html') ? 'text/html; charset=utf-8' : 'application/octet-stream' }); s.end(b); });
}).listen(8767);
(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const p = await (await browser.newContext({ deviceScaleFactor: 3 })).newPage();
  await p.goto('http://localhost:8767/site-src/admin/partner-card.html?code=' + code + '&name=' + encodeURIComponent(name), { waitUntil: 'networkidle' });
  await p.evaluate(() => document.fonts.ready);
  const base = OUT + 'massa-room-card-' + code + '-A6';
  await p.locator('.sheet').screenshot({ path: base + '.png' });
  await p.pdf({ path: base + '.pdf', width: '105mm', height: '148mm', printBackground: true, pageRanges: '1' });
  console.log('qr url:', await p.evaluate(() => 'https://app.massaviet.com/?p=' + new URLSearchParams(location.search).get('code')));
  console.log('saved', base + '.png', base + '.pdf');
  await browser.close(); srv.close();
})().catch(e => { console.error(e); process.exit(1); });
