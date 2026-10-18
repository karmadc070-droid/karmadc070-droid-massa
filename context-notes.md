# massa 작업 컨텍스트 노트

작업 중 내린 결정과 그 근거를 기록한다. 다음 세션은 이 문서와 checklist.md부터 읽는다.

## 2026-08-29 · API 도메인을 moahagwon.com 서브도메인으로

**결정**: 새 도메인을 사지 않고 기존 `moahagwon.com`의 서브도메인(`api.moahagwon.com`)을 massa API에 쓴다.

**근거**
- 현재 API 주소 `massa.141-164-46-88.sslip.io`는 무료 와일드카드 DNS라 **AAAA 레코드가 없다**. Apple 심사는 IPv6 환경에서 이뤄지며, 2차 리젝의 2.1(a)(로그인 무한 대기)의 원인 후보로 남아 있었다.
- `moahagwon.com`은 이미 Cloudflare DNS를 쓰고 있어 서브도메인 추가에 비용도 대기 시간도 없다.
- 브랜드가 다르지만 API 주소는 실사용자에게 노출되지 않는다.

**Cloudflare 프록시는 끈다(DNS only)**
- Supabase Realtime은 WebSocket, Storage는 대용량 업로드를 쓴다. Cloudflare 프록시는 이 둘에 제약(타임아웃·업로드 상한)이 있어 오작동 위험이 있다.
- 프록시를 끄면 A·AAAA를 직접 등록하게 되고, TLS는 Caddy가 Let's Encrypt로 자동 발급한다. IPv6 목적은 그대로 달성된다.

## 2026-08-29 · 관리자·파트너 기능을 웹으로 분리

**결정**: 앱은 고객 전용으로 두고, 관리자 13개 + 파트너 10개 화면을 `admin.moahagwon.com`으로 옮긴다.

**근거**
- 앱에 운영 기능이 섞여 있으면 심사관이 볼 수 없는 화면이 생겨 Guideline 2.3.1(숨겨진 기능) 소지가 있다. 지금은 demo 계정에 파트너 권한을 줘서 피하고 있는데, 이 방식은 데모 계정이 노출되면 일반 사용자도 운영 화면에 접근하게 된다(실제로 1.0에서 로그인 창에 데모 계정이 노출돼 있었다).
- 앱 용량·복잡도가 줄고 고객 플로우 검증이 쉬워진다.
- 운영자는 PC에서 쓰는 편이 실제로 편하다.

**한 번에 옮기지 않는 이유**
- index.html 3,950줄에서 23개 화면을 들어내는 작업이라 한 번에 하면 회귀를 잡기 어렵다. 관리자 → 파트너 순서로 나누고 각 단계마다 문법 검사와 고객 플로우 확인을 넣는다.

## 2026-08-29 · 채팅을 예약 이후로 제한

**결정**: 제공자 프로필에서 바로 채팅하지 못하게 하고, 예약이 있는 상대와만 채팅한다.

**근거**: 예약 전에 채팅이 열리면 앱을 거치지 않는 직거래로 이어진다. 제공자 연락처를 관리자 전용으로 돌린 것과 같은 목적이다.

**구현**: 버튼을 숨기는 대신 `openChat` 진입부에서 bookings를 조회해 막는다(취소 건 제외). 진입 지점이 프로필·예약완료·예약내역 세 곳이라 한 곳에서 검사해야 우회가 없다. 예약 완료 화면과 예약 내역 카드에 채팅 버튼을 새로 넣었다.

## 2026-08-29 · A 단계 실행 결과

- `api.moahagwon.com` A(141.164.46.88) + AAAA(2401:c080:1c02:7e6:5400:6ff:fe98:627f), 둘 다 DNS only
- Caddy `/root/Caddyfile`에 블록 추가 후 `docker exec caddy caddy reload` — 무중단. 기존 sslip.io 블록은 그대로 두어 구버전 앱 호환
- 검증: IPv4/IPv6 모두 401(정상), 로그인 255ms(기존 737ms)
- DB URL 치환 50건. **어느 컬럼인지 모른 채 UPDATE를 쓰지 않고** information_schema로 text·ARRAY 컬럼을 훑었더니 `providers.photo_urls`(배열) 25건이 추가로 나왔다. 추측했으면 절반을 놓쳤을 것

## 2026-08-29 · B0 단계에서 겪은 함정 세 가지

1. **스크립트 스코프**: `guardConsole`을 1136줄의 일반 `<script>`에 넣었더니 `refreshSession is not defined`. 앱 로직은 전부 1357줄의 `<script type="module">` 안에 있다. 모듈은 별도 스코프이므로 **관련 코드는 반드시 모듈 안에** 넣어야 한다.
2. **raw.githubusercontent.com 캐시**: 푸시 직후 배포해도 최대 5분간 옛 파일이 내려온다. 배포 스크립트는 `codeload.github.com/.../tar.gz/refs/heads/main`으로 받는다(항상 최신).
3. **try 블록 안의 가드**: `load()` 내부 try에 권한 검사를 넣었더니 실행되지 않았다. 앞선 await에서 흐름이 갈리면 건너뛴다. `(async () => { if (await guardConsole()) load(); })()` 처럼 **호출 자체를 감싸는** 편이 확실하다.

또한 noVNC 콘솔은 Shift가 안 먹으므로 `&&`를 쓸 수 없다(`77`로 깨진다). 명령은 한 줄씩 따로 입력한다.

## 2026-08-29 · 비밀번호 재설정에 massa.moahagwon.com 을 새로 만든 이유

**결정**: 재설정 페이지를 `admin.moahagwon.com`에 얹지 않고 `massa.moahagwon.com`을 새로 만들었다.

**근거**
- 재설정 메일은 고객에게도 간다. 링크가 `admin.`으로 시작하면 피싱처럼 보인다.
- Vercel 임시 도메인(`massa-seven.vercel.app`)은 git 미연동이라 갱신이 안 되고 있었다. 같은 VPS에서 고객용 웹앱까지 서빙하면 C2 항목도 함께 해결된다.
- A 레코드 하나 + Caddy 블록 하나로 끝나 비용도 복잡도도 늘지 않는다.

**GoTrue 쪽 필수 설정**: `GOTRUE_SITE_URL`과 `GOTRUE_URI_ALLOW_LIST`에 이 주소가 없으면 `resetPasswordForEmail`의 `redirectTo`가 무시되고 SITE_URL로 돌아간다. 지금 SITE_URL은 옛 Vercel 주소라 반드시 함께 바꿔야 한다.

## 2026-08-29 · Resend DNS는 수동 입력하지 말 것

Resend 도메인 화면의 DKIM 값은 UI에서 `p=MIGfMA0GCSqG[…]SIb3...` 처럼 중간 생략 표시가 붙어 나온다. 실제로 생략된 문자가 없는데도 `[…]`가 보이므로, 눈으로 읽어 옮기면 틀릴 위험이 있다. Cloudflare를 쓰면 **Auto configure** 버튼이 DKIM·MX·SPF 3개를 직접 넣어주므로 그쪽을 쓴다. 버튼을 눌러도 화면이 바로 안 바뀌고 "Temporarily unavailable"이 뜰 수 있는데, Cloudflare DNS 목록을 열어보면 이미 들어가 있다.

## 2026-08-29 · VPS 접속은 noVNC 말고 SSH를 쓸 것

**결정**: 앞으로 VPS 작업은 Vultr noVNC 대신 SSH로 한다.

```
& "C:\Program Files\Git\usr\bin\ssh.exe" -i "$env:USERPROFILE/.ssh/erp_vultr" -o BatchMode=yes root@141.164.46.88 '명령'
```

**근거 — noVNC에서 실제로 겪은 사고**
- Shift 조합이 깨진다(`+`→`=`, `_`→`-`). `dig +short`가 `dig =short`가 되고 `resend._domainkey`가 `resend.-domainkey`가 됐다.
- 사이드바의 **Ctrl 토글은 눌린 채로 유지된다**. 이걸 모르고 이어서 타이핑했더니 `clear`가 Ctrl+C/L/E/A/R로 들어가 로그인 세션이 끊겼고, Ctrl+S가 걸려 화면 출력이 멈췄다(Ctrl+Q로 복구).
- 그 뒤 키 입력 채널 자체가 죽어 사용자가 직접 타이핑해도 반응하지 않았다. 탭을 새로 열어도 마찬가지였다.

**Windows의 `C:\WINDOWS\System32\OpenSSH\ssh.exe`는 이 PC에서 아무 출력 없이 exit 255로 끝난다.** `ssh -V`조차 안 된다. Git 번들 ssh(`C:\Program Files\Git\usr\bin\ssh.exe`)는 정상 동작한다. 키는 `~/.ssh/erp_vultr`.

## 2026-08-29 · GoTrue 설정은 .env 변수명을 compose에서 확인하고 쓸 것

`docker-compose.yml`이 `GOTRUE_SITE_URL: ${SITE_URL}` 처럼 **다른 이름으로 매핑**한다. `.env`에 `GOTRUE_SITE_URL=`을 써도 읽히지 않는다. 실제로 이 실수로 1차 적용 때 SMTP만 바뀌고 SITE_URL은 옛 Vercel 주소 그대로였다.

| .env 에 쓸 이름 | 컨테이너 안 이름 |
| --- | --- |
| `SITE_URL` | `GOTRUE_SITE_URL` |
| `ADDITIONAL_REDIRECT_URLS` | `GOTRUE_URI_ALLOW_LIST` |
| `ENABLE_EMAIL_AUTOCONFIRM` | `GOTRUE_MAILER_AUTOCONFIRM` |
| `SMTP_*` | `GOTRUE_SMTP_*` |

검증은 `.env`가 아니라 `docker exec massa-auth env | grep GOTRUE_` 로 해야 한다.

## 2026-08-29 · 다국어를 CSS 클래스 순회에서 텍스트 노드 순회로 바꾼 이유

**문제**: 옛 `applyLang` 은 `I18N_SEL` 에 적힌 클래스만 훑고, 그마저도 `if (el.querySelector('*')) return;` 로 **자식 태그가 있으면 통째로 건너뛰었다**. 게다가 호출 지점이 4곳뿐이라 innerHTML 로 나중에 그려지는 목록·오버레이는 아예 번역 대상이 아니었다. "되는 것과 안 되는 것이 섞여 있다"는 증상의 원인이 이것이다.

**해결**: `translateTree()` 가 텍스트 노드를 전부 훑고, 각 노드에 한국어 원문을 `n.__ko` 로 보관한다. 여기에 `MutationObserver`(60ms 디바운스)를 붙여 새로 그려진 DOM 도 따라간다. 클래스에 의존하지 않으므로 오버레이든 동적 목록이든 상관없다.

**주의 두 가지**
1. 배너 제목·탭바·언어 버튼처럼 **전용 사전으로 따로 채우는 요소는 반드시 제외**해야 한다. 안 그러면 `__ko` 에 저장된 옛 값으로 서로 덮어쓴다. 단 `.banner` 통째로 빼면 그 안의 pill 까지 번역이 안 되므로 `.banner .bt, .banner .bd` 처럼 좁혀야 한다.
2. `alert`/`confirm`/`prompt` 는 DOM 이 아니므로 옵저버가 못 잡는다. 함수 자체를 래핑해 `T()` 를 태웠다 — 호출부 61곳을 고치지 않아도 된다.

## 2026-08-29 · 조합형 문구는 T() 말고 span 으로 쪼갤 것

`'아로마·스웨디시 · 한국어 가능 · 미딩 권역'` 같은 문장은 통째로 사전에 넣을 수 없다. 처음엔 생성 시점에 `T()` 로 감쌌는데, **카드를 만든 시점의 언어로 굳어** 언어를 바꿔도 그대로였다(목록을 다시 그리지 않으므로).

각 조각을 `<span>` 으로 감싸면 텍스트 노드가 나뉘어 사전에 개별로 걸리고, `translateTree` 가 그 자리에서 바꿔 준다. 다시 그릴 필요가 없다.

```js
// 나쁨 — 만든 시점 언어로 고정된다
const spec = list.map(s => T(TYPE_KO[s])).join('·');
// 좋음 — 언어를 바꾸면 그 자리에서 함께 바뀐다
const spec = list.map(s => '<span>' + TYPE_KO[s] + '</span>').join('·');
```

`T()` 는 DOM 밖(alert 문구, prompt 질문)에만 쓴다.

## 2026-08-29 · 사전 점검은 항목 단위 정규식으로

DICT 는 한 줄에 여러 항목이 들어 있는 줄이 있다. 줄 단위 정규식(`^\s*'key':\s*\[(.*)\]$`)으로 검사하면 **첫 항목만 보고 나머지를 놓쳐서** "zh/ja 누락 0개"라는 잘못된 결과가 나온다. 실제로는 56개가 비어 있었다. 항목 단위 패턴으로 세야 한다.

```python
re.compile(r"'((?:[^'\\]|\\.)*)'\s*:\s*\[((?:\s*'(?:[^'\\]|\\.)*'\s*,?)*)\]")
```

번역을 추가할 때는 `scripts/i18n-add.py` 를 고쳐 다시 실행한다. 같은 키는 덮어쓰므로 몇 번을 돌려도 결과가 같다.

## 2026-08-29 · 번역한 텍스트에서 숫자를 긁어내지 말 것

날짜 칩 마크업이 `<div class="day"><span class="dow">수</span>10</div>` 인데, 날짜를 이렇게 읽고 있었다.

```js
el.textContent.replace(/\D/g, '')   // '수10' → '10'
```

요일을 번역하자 베트남어 수요일이 `T4` 가 되면서 `T410` → **`410`** 이 됐다. 확인 화면에 `06/410` 이 찍혔고, 더 나쁜 건 `submitBooking()` 도 같은 코드를 써서 **잘못된 날짜로 예약이 저장될 수 있었다**.

교훈: 화면에 보이는 문자열은 번역되면 내용이 바뀐다. 거기서 값을 파싱하면 안 된다. `selectedDayNum()` 처럼 라벨 요소를 빼고 읽거나, 애초에 `data-*` 속성에 값을 따로 두는 편이 안전하다. 다국어를 붙일 때는 **문자열을 파싱하는 코드부터 찾아볼 것**.

## 알려진 함정 (반복 확인됨)

- **GitHub 푸시**: 저장소 소유자는 `karmadc070-droid`, PC 자격증명은 `parkdongchun-77`. 협업자로 초대·수락해 해결함. push가 멈추면 대기 중인 git 프로세스를 죽이고 재시도.
- **Codemagic 빌드 번호**: `app-store-connect get-latest-*`가 항상 0을 반환해 중복 실패. `$PROJECT_BUILD_NUMBER` 사용 중.
- **마케팅 버전**: 출시된 버전 트레인은 닫힌다. `capacitor/package.json`의 version을 올려야 한다.
- **ASC 웹 UI**: `/apps/<id>/distribution/...`로 직접 열면 렌더링 안 됨. `/apps`부터 SPA 내부 링크를 클릭할 것.
- **CSS 우선순위**: `#id { display: ... }`가 `.screen { display:none }`을 덮어써 비활성 화면이 남는 사고가 있었다(#chat). 화면 전용 스타일은 반드시 `#id.on`으로 쓸 것.

## 2026-08-30 · 결제창을 여는 페이지를 웹에 따로 둔다

**결정**: 토스 결제창을 앱에서 직접 띄우지 않고, `pay-start.html` 이라는 웹 페이지가 띄우게 한다.
앱은 그 주소를 앱 내 브라우저(SFSafariViewController)로 연다.

**근거**
- 토스 SDK 의 `requestPayment` 는 현재 페이지를 토스 도메인으로 **이동**시킨다.
  Capacitor 웹뷰는 `capacitor://localhost` 라, 여기서 이동하면 앱 껍데기 자체를 벗어난다.
- 사파리로 나가버리면 돌아올 방법이 없고 App Store 가이드라인 4 소지도 생긴다.
- 웹과 앱이 같은 페이지를 쓰므로 결제 코드 경로가 하나로 유지된다. 모아학원처럼 iOS 결제를 꺼둘 필요가 없다.

**대안으로 검토한 것**: 앱 안에 토스 SDK 를 넣고 결제창만 새 창으로 — 웹뷰에서 팝업 차단·복귀 문제가 그대로 남아 버렸다.

## 2026-08-30 · 앱 복귀는 파라미터가 아니라 호스트로 가른다

**발견한 버그**: `native.js` 가 `searchParams.get("code")` 로 결제 복귀를 판별하고 있었다.
그런데 **OAuth PKCE 로그인도 `code=` 를 달고 돌아온다**(`massa://auth?code=...`).
구글 로그인 키가 들어오는 순간 로그인이 결제 처리로 새게 되어 있었다.

**수정**: `massa://auth` / `massa://pay` 의 **호스트**로 가른다. 5개 URL 케이스로 검증했다.

**교훈**: 딥링크는 목적지를 경로에 박아야 한다. 쿼리 파라미터는 서로 다른 흐름이 우연히 같은 이름을 쓴다.

## 2026-08-30 · 토스 결제 수단은 켜기 전까지 숨긴다

`TOSS_ENABLED = false` 상수 하나로 결제 시트에서 감춘다. 키가 없으면 결제창이 뜨지 않는데,
눌러도 안 되는 버튼은 App Store 4.0 리젝 사유다. 소셜 로그인에서 이미 한 번 겪었다.
토스 키를 VPS 에 넣는 날 이 상수를 `true` 로 바꾼다.

**남겨둔 것**: 결제 시트의 기존 `카드`·`QR`·`은행 이체` 는 PG 연결 없이 `is_paid=true` 로 찍는
자리표시자다. 이번 작업 범위 밖이라 건드리지 않았다. 토스가 살아나면 이것들의 처리를 따로 정해야 한다.

## 2026-08-30 · 애플 소셜 로그인 — 비밀 파일은 scp 로 넘긴다

**결정**: `.p8` 을 noVNC 로 타이핑하지 않고, 사장님이 다운로드한 파일을 **그대로 scp** 로 VPS 에 올렸다.

**근거**
- `.p8` 은 여러 줄 PEM 이라 noVNC 클립보드로 넣기 어렵다. 예전에 noVNC 에서 Ctrl 키가 눌린 채 고정돼 세션이 날아간 적이 있다.
- scp 는 파일 내용을 열지 않고 전달만 한다. 서버 안에서 `vps-apple-secret.sh` 가 JWT 를 만들고 `.p8` 을 shred 한다.
- 결과 검증: JWT 3파트 289자, `/auth/v1/settings` 에서 `apple: true`.

**Windows 에서 SSH·SCP 는 Git 번들을 쓴다.** `C:\WINDOWS\System32\OpenSSH\ssh.exe` 는 출력 없이 255 로 죽는다.
`C:\Program Files\Git\usr\bin\{ssh,scp}.exe` 를 쓸 것.

**PowerShell 로 원격 셸 스크립트를 넘기지 말 것.** 한글·괄호·따옴표에서 BOM 과 CRLF 가 섞여 깨진다.
설정 파일은 로컬에 만들어 **scp 로 올리는 편이 확실하다** (`apple.conf` 를 printf 로 만들려다 빈 파일이 됐다).

**긴 스크립트는 nohup 으로 띄우고 로그를 본다.** `pip install cryptography` 때문에 SSH 응답이 먼저 끊겨
"실패한 줄 알았는데 실제로는 성공"한 상황이 나왔다. 두 번째 실행이 "apple.p8 없음"으로 죽어서야 알았다.

**만료일 2027-03-01.** 애플 클라이언트 시크릿은 최대 6개월이다. 만료 전 재발급이 필요하다.
`.p8` 은 서버에서 지웠으므로, 갱신하려면 사장님 다운로드 폴더의 원본이나 애플에서 새 Key 가 필요하다.

## 2026-09-04 · 소셜 로그인 3종 완료 — 가려진 시크릿을 걸러낸 방법

**결과**: `/auth/v1/settings` 에서 `google: true` / `kakao: true` / `apple: true`.
앱에서 버튼 3개(`Google로 계속하기`·`카카오로 계속하기`·`Apple로 계속하기`)가 그려지는 것까지 확인했다.

**걸러낸 사고**: 구글 콘솔은 클라이언트 시크릿을 `****lLXk` 처럼 뒤 4자리만 남기고 가린다.
사장님이 그 표시값을 복사해 넣었고, 그대로 적용했으면 **구글 버튼은 뜨는데 로그인만 실패**했을 것이다.
예전에 4.0 리젝을 받은 바로 그 상태다.

적용 전 검사로 잡았다 — **길이와 `*` 포함 여부**.
정상값은 `GOCSPX-` 로 시작하는 35자, 문제값은 8자에 `*` 포함이었다.
구글만 빼고 카카오를 먼저 적용한 뒤, 새 시크릿을 받아 구글을 켰다.

**교훈**: 콘솔 화면에서 복사한 시크릿은 믿지 말고 **형식을 먼저 검증한다.**
`vps-apply-social-keys.sh` 는 값이 있으면 무조건 `ENABLED=true` 로 켜므로, 스크립트가 걸러주지 않는다.

**키 파일 처리**: VPS 는 스크립트가 shred, 로컬 `social.keys` 는 0으로 덮어쓴 뒤 삭제했다.

## 2026-09-04 · 시크릿이 진짜 맞는지 실계정 없이 확인하는 법

**문제**: 소셜 로그인 설정이 맞는지 확인하려면 실계정으로 로그인해야 한다고 생각했다.
동의 화면까지는 확인되지만 **토큰 교환**은 못 본다. 여기가 깨져 있으면 심사자가 로그인 실패를 만나 2.1 리젝이다.

**방법**: 각 provider 의 토큰 엔드포인트에 **일부러 틀린 code** 로 요청한다.

- 시크릿이 틀리면 → `invalid_client` (클라이언트 인증 자체가 실패)
- 시크릿이 맞으면 → `invalid_grant` (클라이언트는 통과, code 만 틀림)

구글·카카오·애플 셋 다 `invalid_grant` 가 나왔다. 특히 **애플 JWT 와 .p8/Key ID 짝**이 이걸로 확인됐다 —
서버에서 만든 값이라 가장 불확실했던 부분이다. 스크립트는 `scripts/vps-verify-social-secrets.sh`.
시크릿은 VPS 안에서 읽고 출력하지 않는다.

**교훈**: "실계정이 없으면 검증 불가"라고 단정하기 전에, 실패 응답이 원인별로 갈리는지 본다.
OAuth 는 클라이언트 인증 실패와 코드 오류를 다른 코드로 돌려준다.

## 2026-09-04 · 비로그인 접근은 막는 게 아니라 열어두는 게 맞다

"로그인 없이 다 클릭된다"는 지적을 받고 확인했다. **바꾸지 않기로 했다.**

- 애플은 로그인 없이 볼 수 있는 콘텐츠를 로그인 뒤에 숨기면 **5.1.1(v)** 로 리젝한다.
  둘러보기는 열고 **행동할 때 로그인을 요구**하는 지금 구조가 애플이 권하는 방향이다.
- 행동 지점 28곳에 가드가 있고, 세션 없는 브라우저로 실제 호출해 전부 로그인창이 뜨는 것을 확인했다.
- **UI 가드는 우회 가능하므로 DB 를 직접 확인했다.** anon 키로 REST 를 찔러 읽기는 전부 빈 결과,
  쓰기는 6개 테이블 전부 42501(RLS 위반). 전 테이블 RLS 켜짐.

**테스트하다 헛짚은 것**: 함수명을 `toggleFav` 로 호출해 "가드 없음"으로 오판했다.
실제 이름은 `toggleFavorite` 이고 가드가 있다. **존재하지 않는 함수 호출은 조용히 통과한 것처럼 보인다.**
호출 전에 `typeof` 로 존재를 확인할 것.

## 2026-09-05 · 화면이 꽉 차지 않던 원인 — 목업 프레임이 남아 있었다

**증상**: 앱을 켜면 화면에 꽉 차지 않고 좌우로 움직인다.

**원인**: `.phone` 은 데스크톱에서 볼 때 쓰는 폰 목업 프레임이다(테두리 10px, 둥근 모서리 36px, 가짜 상태바).
이걸 벗기는 규칙이 `@media (max-width: 767px)` 안에만 있어서 **세로 아이폰만** 적용됐다.
가로 모드 아이폰(844x390)과 아이패드(820x1180)는 기준을 넘어 목업 카드가 화면 가운데 떠 있었다.
가로 모드에서는 카드 높이(560px)가 화면 높이(390px)보다 커서 잘리기까지 했다.

**결정**: 미디어쿼리를 건드리지 않고 `body.nativeapp` 클래스를 추가했다.
`IS_NATIVE_APP` 이 true 일 때만 붙으므로 **웹은 그대로**다. 목업은 데스크톱 미리보기용이니 웹에서는 남겨야 한다.
폭 기준으로 판단하면 또 다른 기기에서 새는 반면, "앱인가"로 판단하면 크기·방향과 무관하게 항상 맞다.

**교훈**: 반응형은 한 크기가 아니라 **경계값을 넘겨가며** 봐야 한다.
767/768 경계 하나 때문에 가로 모드와 아이패드가 통째로 빠졌는데, 세로 아이폰만 테스트해서 세 번의 출시 동안 못 봤다.

**부수 확인**: VPS 논리 백업은 이미 돌고 있었다(`10 3 * * * /root/pg_backup.sh`, 4개 DB, 10일 보관).
체크리스트에 미완료로 남아 있어 정리했다. 다만 백업이 **같은 서버에만** 있어 서버가 죽으면 같이 죽는다.

---

## 사이트를 앱과 연결하며 (2026-09-05)

**Play 링크를 걸지 않기로 한 판단.** 사용자는 "안드로이드, iOS 둘 다 연결"을 요청했다.
개발자 계정으로 로그인된 크롬에서 Play 스토어 페이지를 열어보니 정상적으로 떴다 — 여기서 멈췄으면 링크를 걸었을 것이다.
Play Console 을 직접 확인하니 프로덕션 트랙은 **"아직 프로덕션에 액세스할 수 없습니다"** 상태였고,
대시보드에 **"현재 12일 동안 참여를 선택한 테스터 12명"** (14일 필요)이라고 적혀 있었다.
즉 스토어 페이지가 보인 건 내가 **테스터/개발자 세션**이기 때문이고, 일반 방문자에게는 404 다.

**교훈**: 로그인된 브라우저에서 "페이지가 뜬다"는 것은 공개 여부의 증거가 아니다.
공개 여부는 **콘솔의 트랙 상태**로 확인해야 한다. 이건 앞서 존재하지 않는 함수 `toggleFav` 를 호출해 놓고
"통과했다"고 보고한 것과 같은 종류의 착각이다 — 확인 대상이 아닌 것을 확인하고 결론을 내렸다.
그래서 안드로이드는 `.store.off` 로 "공개 준비 중"만 표시하고 링크를 넣지 않았다.

**콘솔 자동화에서 또 걸린 것들.**
- 구글 서치콘솔 사이트맵 입력이 안 먹던 진짜 원인은 필드가 아니라 **위에 떠 있던 홍보 툴팁**이었다.
  좌표 클릭이 툴팁에 먹히고 있었다. 툴팁을 닫으니 한 번에 됐다. 도메인 속성은 `sitemap.xml` 이 아니라 **전체 URL** 을 요구한다.
- 다음 검색등록의 `_jsSubmit` 은 URL 6가지 형식을 전부 반려했다. 원인을 못 찾았고,
  검증 함수 소스는 확장 프로그램 필터에 막혀 읽지 못했다. 추측으로 계속 시도하는 대신 사용자에게 넘긴다.
- 네이버 서치어드바이저는 브라우저 두 곳 모두 도메인 접속 자체가 차단된다. 자동화 경로가 없다.

**취소 규정 최종 확인.** `CANCEL_RULES = {warn:3, block:5, block_days:7, window:30}` 를 기준으로
앱·약관·guide·faq(FAQPage JSON-LD 포함) 네 곳이 모두 **3회 경고 / 5회 누적 7일 제한 / 30일 창** 으로 일치한다.

## 2026-09-06 · 관리자 대시보드에서 내린 결정

**정적 사이트에 관리자 화면을 두는 방법.** `massaviet.com` 은 생성기가 찍어 내는 정적 사이트라
서버 쪽 인증이 없다. 페이지를 숨기는 것으로는 아무것도 막지 못한다.
그래서 **접근 통제를 DB 로 내렸다.**
- `app_visit` 은 RLS 를 켜고 **정책을 하나도 만들지 않는다.** 정책 없는 RLS = PostgREST 로 접근 불가.
- 읽기는 `admin_dashboard()`, 쓰기는 `track_visit()` 만 한다. 둘 다 `security definer`.
- 화면은 `admin_dashboard('day', 1)` 을 한 번 불러 보고 통과할 때만 열린다.
  즉 화면이 판단하는 게 아니라 **DB 가 판단한 결과를 화면이 따를 뿐이다.**
- `robots.txt` 의 `Disallow` 와 `noindex` 는 색인을 막을 뿐 보안 장치가 아니다. 그렇게 주석에도 적었다.

`is_admin()` 헬퍼가 이미 있었지만 쓰지 않고 조건을 함수 안에 직접 적었다.
이 함수 하나만 읽어도 누가 볼 수 있는지 보이는 편이 낫다.

**유입량은 없던 데이터라 새로 만들었다.** 물어보지 않고 가입 수로 슬쩍 대체하지 않았다.
`app_visit(visit_date, device_id)` 를 기본키로 둬서 같은 기기가 하루에 몇 번 열어도 한 줄이다.
신규 기기는 컬럼으로 저장하지 않고 `min(visit_date)` 로 계산한다 — 컬럼을 두면 과거를 다시 계산할 수 없다.
개인정보처리방침(앱 + 사이트 3개 언어)에 "이용 통계" 항목을 함께 추가했다. 수집을 늘렸으면 방침도 같이 고쳐야 한다.

**열려 있는 위험 하나.** `track_visit` 은 비로그인도 부를 수 있어야 해서 anon 에 실행 권한을 줬다.
임의의 `device_id` 로 반복 호출하면 행을 부풀릴 수 있다. 지금은 막지 않았다 —
회원가입도 똑같이 열려 있고, 유입 수치가 틀어지는 것 외에 피해가 없다. 문제가 되면 그때 막는다.

**차트를 라이브러리 없이 그린 이유.** Chart.js 를 넣으면 CDN 의존이 하나 늘고, 필요한 건 막대 3종뿐이다.
대신 `height:auto` 인 SVG 는 **viewBox 의 가로세로비가 그대로 화면 높이가 된다.**
1000×210 을 좁은 화면에 그대로 쓰면 차트가 70px 로 납작해진다. 그래서 `innerWidth < 760` 이면 viewBox 를 460 으로 바꾸고,
창 크기가 바뀌면 마지막 응답으로 다시 그린다.

**축 눈금은 반올림해야 한다.** `max*i/3` 을 그대로 찍으면 최대값이 7일 때 "2.333" 이 축에 나온다.

### 이번에도 psql 에서 같은 함정
- **enum 컬럼은 `||` 로 못 붙인다.** `status` 와 `role` 둘 다 enum 이라 `::text` 가 필요하다. `role` 때 이미 겪었는데 또 걸렸다.
- **`group by 1` 에 집계 함수가 섞이면 조용히 실패한다.** `'x'||status||' : '||count(*)` 를 `group by 1` 하면
  "aggregate functions are not allowed in GROUP BY" 다. stderr 가 PowerShell 에서 안 보여서
  **빈 결과를 "데이터가 없다"로 오해할 뻔했다.** count(*) 는 7이라고 나오는데 group by 는 0행인 게 단서였다.
  → 진단 쿼리는 `-A -t` 로 짜내지 말고 그냥 표로 뽑고 `2>&1` 을 붙이는 게 낫다.
- **PowerShell 로 SSH 에 SQL 을 인라인으로 넘기지 말 것.** 괄호·`%`·중괄호가 계속 깨진다.
  스크립트 파일을 `scp` 로 올려서 실행하면 한 번에 된다. 이번 세션에서 세 번 헛돌았다.

### Vercel 은 사실 git 이 연결돼 있다 (메모 정정)
"git 미연결" 이라고 적어 뒀었는데 아니다. 마지막 배포에
`gitSource: {type:"github", repoId:1312255563, ref:"main", sha:...}` 가 붙어 있다.
**웹훅이 안 걸려 자동 배포만 안 될 뿐**이라, 로그인된 vercel.com 탭에서 이렇게 부르면 된다.

```js
await fetch('/api/v13/deployments?forceNew=1', { method:'POST', credentials:'include',
  headers:{'Content-Type':'application/json'},
  body: JSON.stringify({ name:'massa', project:'prj_rXbH3q19JIMQaMMyYsqVP4P4p7Gc',
    target:'production',
    gitSource:{ type:'github', repoId:1312255563, ref:'main', sha:'<origin/main 해시>' } }) });
```
`READY` 가 되면 `massa-seven.vercel.app` 별칭이 자동으로 옮겨 붙는다. `assetlinks.json` 도 함께 간다(확인함).

### 시크릿을 진단하다 흘렸다
`select key, value from app_settings` 로 전체를 뽑는 바람에 `notify.secret` 이 작업 로그에 찍혔다.
바로 회전했다(새 값 200 / 옛 값 401). **그 과정에서 `/root/massa_digest.sh` 에 시크릿이 박혀 있다는 걸 놓쳤다** —
회전만 하고 끝냈으면 다음 날 아침 다이제스트가 조용히 401 로 죽었을 것이다.
회전 스크립트가 다이제스트 스크립트를 다시 쓰도록 고쳤다.
교훈: **설정 테이블을 통째로 뽑지 말고 필요한 키만 뽑을 것.**

## 2026-09-06 · GoTrue 허용 목록 글롭과 PKCE

**`*` 는 `/` 를 넘지 못한다.** `https://massaviet.com/*` 로는 `/admin/` 에 못 간다.
하위 경로가 있으면 `**` 를 써야 한다. 걸러지면 GoTrue 는 조용히 **referer 로** 되돌려 보내는데,
오류가 안 나서 "왜 엉뚱한 데로 갔지"로만 보인다. `docker logs massa-auth` 의 `path:/callback` 줄에
`referer` 가 찍히는 게 유일한 단서였다.

**supabase-js 의 흐름 방식을 기본값에 맡기지 말 것.** 이번에 암시적 흐름으로 붙어서
`#access_token=eyJ...` 이 주소창에 그대로 남았고, 사장님이 그 주소를 복사해 보내면서
관리자 액세스 토큰이 대화 기록에 들어갔다. `flowType: 'pkce'` 를 명시하면 `?code=` 만 남고
그건 1회용에 code_verifier 없이는 못 쓴다.

**JWT 는 취소되지 않는다.** 세션·리프레시 토큰을 지워도 이미 발급된 액세스 토큰은
만료까지 유효하다. `JWT_SECRET` 을 갈면 무효화되지만 anon/service 키가 같은 비밀로 서명돼 있어
전부 재발급·재배포해야 한다. 만료가 1시간이라 이번엔 하지 않았다.
**앞으로 노출 사고가 나면 남은 만료 시간을 먼저 계산하고 판단할 것.**

## 2026-09-06 · 수수료를 등급으로 나눌 때 지킨 것

**요율은 예약에 굳힌다.** `bookings.fee_rate` 에 예약이 들어온 순간의 요율을 트리거로 박는다.
이렇게 하지 않으면 등급을 바꾸는 순간 **이미 마감한 지난달 정산서 금액까지 바뀐다.**
마사지사가 "지난달에는 이 금액이라고 했잖아요" 라고 할 때 대답할 말이 없어진다.

**요율이 섞이면 합계에 한 번 곱하면 안 된다.** 예약별로 반올림해서 더해야 한다.
실제로 20/15/10% 가 섞인 5건 표본에서 옛 방식은 **166,667₫ 를 더 걷는 것으로 계산**됐다.
`close_settlement_cycle`·대시보드·운영 콘솔 세 군데 모두 고쳤다.

**대체 요율은 가장 높은 값(20%)으로 뒀다.** 등급을 못 찾았을 때 낮은 값을 쓰면 조용히 덜 걷는다.
높은 값을 쓰면 눈에 띄어서 고치게 된다.

**10% 승급은 자동으로 하지 않는다.** 기준(최근 30일 완료 20건 + 평점 4.7)을 넘으면
정산 화면에 "우대 10% 후보입니다" 라고 뜨기만 하고, 올리는 것은 사람이 누른다.
자동이면 실적이 떨어진 달에 요율이 말없이 올라가고, 그건 통보 없는 인상이다.

**등급 버튼은 새 화면을 만들지 않고 정산 화면 안에 넣었다.** 돈 이야기를 하는 자리에서 바꾸는 게 맞고,
화면을 하나 더 만들면 사이드바·라우터까지 건드려야 한다.

### psql 시험 스크립트에서 또 당한 것
`bookings.scheduled_at` 이 NOT NULL 인데 빼먹어 insert 가 실패했고,
`\gset` 이 안 돌아 뒤따르는 `:'bk1'` 이 전부 구문 오류가 났다. **그런데 앞의 몇 항목은 "통과"처럼 보였다.**
`\set ON_ERROR_STOP off` 로 돌리면 실패해도 계속 가므로, 출력에 오류가 섞여 있는지 반드시 눈으로 볼 것.
다행히 실패한 insert 의 DETAIL 에 `0.2000` / `0.1000` 이 찍혀 트리거가 도는 건 우연히 보였다.

## 2026-09-08 · 마사지사 개인 가격에서 지킨 것

**가격 칸을 `provider_services` 에 붙이지 않았다.** 그 표에는
`FOR INSERT WITH CHECK (true)` 정책이 살아 있어서 인증만 되면 누구나 행을 넣을 수 있다.
거기 금액 칸을 두면 **남의 프로필 가격을 끼워 넣을 수 있다.**
새 표 `provider_price` 를 만들고 RLS 를 켠 뒤 **정책을 하나도 만들지 않았다.**
PostgREST 로는 아무도 못 읽고 못 쓴다. security definer 함수로만 오간다.
수수료 등급([[fee_tier]])에서 쓴 것과 같은 방식이다.

**손님 화면이 보낸 금액을 믿지 않는다.** `trg_freeze_booking_amount` 가 예약을 받을 때
`service_id` 로 서버에서 다시 계산해 `amount_vnd` 를 덮어쓴다.
시험에서 9,999,999₫ 를 보내도 500,000₫ 으로, 1₫ 를 보내도 600,000₫ 으로 들어갔다.
예전에 코스를 못 찾으면 850,000₫ 을 임의로 물리던 자리가 바로 여기다.
이제 화면이 무엇을 보내든 청구 금액은 서버가 정한다.

**상한은 승인할 때 한 번 더 본다.** 요청은 통과했는데 그 사이 기본가나 배수가 바뀌면
범위를 벗어난 값이 승인될 수 있다. `admin_review_price` 가 승인 직전에 다시 검사한다.
`effective_price` 도 읽을 때마다 `[기본가, 기본가×배수]` 로 자른다.
배수를 나중에 2배 → 1.5배로 낮춰도 이미 승인된 가격이 그대로 청구되지 않는다.

**가격을 비우는 것은 승인 없이 바로 반영한다.** 내려가는 쪽이라 손님에게 불리하지 않다.
올리는 것만 승인을 받는다.

### 파트너 판정이 반쪽이었다 (이번에 드러남)
`loadAccount()` 는 `profile_id` 만 보고 파트너 여부를 정했다. 그런데 실제 데이터는
**승인 마사지사 21명 중 `profile_id` 보유 0명, `owner_id` 보유 7명**이다.
`myProviders()` 는 `.or('profile_id.eq…,owner_id.eq…')` 로 둘 다 보는데 판정만 안 봤다.
그래서 예약 관리·내 입금 현황·매출·스케줄·채팅·GPS 등 **파트너 메뉴 전체가 숨겨져 있었다.**
새 화면을 만들다가 "왜 안 뜨지" 하고 뒤져서 찾았다.
**두 곳에서 같은 판정을 하면 반드시 같은 조건을 써야 한다.**

### psql `\gset` 은 또 첫 줄에서 조용히 무너진다
`where profile_id is not null` 로 대상을 뽑았는데 해당자가 0명이라
`no rows returned for \gset` 한 줄만 뜨고, 뒤따르는 12개 시험이 전부 구문 오류가 났다.
**그런데 `:'cus'` 처럼 앞에서 성공한 변수는 정상 치환돼서 일부 항목은 "통과"처럼 보였다.**
출력 맨 윗줄을 먼저 볼 것. 지난번과 똑같이 당했다.


---

## Vercel 탈출을 왜, 어떻게 하기로 했나 (2026-09-15)

### 계기
스토어의 마케팅 URL 이 `massa-seven.vercel.app` 인 것을 사장님이 짚었다.
"vercel 안 쓰려고 도메인 만든 건데" — 링크만 바꾸는 건 답이 아니었다.

### 그때까지 잘못 알고 있던 것
`massaviet.com` 이 있으니 앱도 거기 있는 줄 알기 쉽다. 아니다. 실제 구조는 이렇다.

| 주소 | 실체 | 내용 |
|---|---|---|
| massaviet.com | VPS 141.164.46.88, Caddy | 소개 사이트 11페이지 × 3언어 (`site/`) |
| massa-seven.vercel.app | Vercel | **앱 본체** — 저장소 루트의 index.html·admin.html 등 |
| app.massaviet.com | 없음 | 이번에 만들 주소 |

안드로이드 앱은 Vercel 주소를 감싼 TWA 라, **앱을 켜면 그 주소에 접속한다.**
그래서 마케팅 URL 만 바꾸면 눈에 보이는 곳만 가려지고 Vercel 은 계속 쓴다.

### 고른 길
세 가지를 놓고 사장님이 **"앱을 VPS 로 완전 이전"** 을 골랐다.
- 링크만 교체 → 싸지만 목표 미달
- Vercel 커스텀 도메인 → 주소만 내 것, 인프라는 여전히 Vercel
- **VPS 완전 이전 → Vercel 의존도 0** ← 선택

### 이 작업의 진짜 위험
코드 옮기는 건 쉽다. 위험한 건 **origin 이 바뀐다**는 사실 자체다.

1. **이미 설치된 안드로이드 앱은 옛 주소를 본다.** 업데이트를 받기 전까지.
   Vercel 을 먼저 끄면 그 사람들 앱이 빈 화면이 된다. **옛 주소를 한동안 같이 살려 둔다.**
2. **소셜 로그인 리디렉트는 origin 단위로 등록돼 있다.** 구글·카카오·애플 세 콘솔에
   새 주소를 추가하지 않으면 로그인만 조용히 깨진다. 카카오 콘솔은 자동화가 안 된다 —
   사장님이 직접 해야 한다 ([[kakao-console-automation]] 과 같은 이유).
3. **TWA 는 assetlinks.json 지문이 맞아야 주소창이 안 뜬다.** 새 주소에도 같은 지문
   2개(업로드 키 + Play 서명 키)가 그대로 나와야 한다. 틀리면 앱이 브라우저처럼 보인다.

### 순서를 이렇게 잡은 이유
새 주소를 먼저 띄우고 **두 주소를 동시에 살린 채** 전부 검증한 다음에 안드로이드를 갈아탄다.
반대로 하면(안드로이드부터) 문제가 생겼을 때 되돌릴 방법이 심사 한 번을 더 기다리는 것뿐이다.

검증(V3)에서 하나라도 막히면 V4(안드로이드 재빌드)로 넘어가지 않는다. 심사는 되돌리기가 비싸다.

### 아직 안 정한 것
- 앱 주소를 `app.massaviet.com` 으로 할지 `massaviet.com/app` 으로 할지 →
  서브도메인으로 잡았다. 경로 방식은 소개 사이트와 서비스워커 scope 가 겹친다.
- Vercel 프로젝트를 언제 끌지 → Play 통계에서 구버전 비중을 보고 정한다. 지금은 건드리지 않는다.


---

## GoTrue 허용목록의 `/*` 와 `/**` 는 다르다 (2026-09-15)

### 무슨 일이 있었나
SITE_URL 을 `massa.moahagwon.com` → `app.massaviet.com` 으로 옮겼더니,
**옛 주소의 재설정 링크가 튕기기 시작했다.** 허용목록에는 `https://massa.moahagwon.com/*` 이
분명히 들어 있는데도 그랬다.

### 원인
GoTrue 는 **SITE_URL 을 언제나 허용한다.** 허용목록과 별개다.
그래서 옛 주소는 그동안 허용목록 덕에 통과한 게 아니라 **SITE_URL 이라서** 통과하고 있었다.
SITE_URL 을 옮기는 순간 그 우산이 사라졌고, 남은 `/*` 만으로는 `/reset.html` 을 못 받았다.

잘 되던 항목들을 보니 답이 있었다. `massaviet.com` 과 `app.massaviet.com` 은
`/*` 와 `/**` 를 **둘 다** 갖고 있었다. 나머지는 `/*` 뿐이었다.

| 주소 | 전 | 후 |
|---|---|---|
| app.massaviet.com/reset.html | 통과 | 통과 |
| massa.moahagwon.com/reset.html | **튕김** | 통과 |
| admin.moahagwon.com/index.html | **튕김** (원래 깨져 있었다) | 통과 |
| evil.example.com | 튕김 | 튕김 |

### 덤으로 찾은 것
`admin.moahagwon.com` 도 `/*` 뿐이었다. 즉 **운영 콘솔의 비밀번호 재설정 링크는
이 작업 전부터 이미 깨져 있었다.** SITE_URL 우산을 받지 못하는 주소였기 때문이다.
아무도 눈치채지 못한 건 관리자가 재설정을 쓸 일이 없어서였을 것이다.

### 다음에 지킬 것
**호스트를 허용목록에 넣을 때는 `/*` 와 `/**` 를 같이 넣는다.** 하나만 넣으면
지금은 SITE_URL 이 가려 주더라도 SITE_URL 이 바뀌는 날 조용히 깨진다.
그리고 이 종류의 고장은 **에러가 안 난다.** 그냥 엉뚱한 곳으로 간다.
확인은 `scripts/vps-diag-allowlist.sh` 로 한다 — `/auth/v1/verify` 의 Location 헤더를 본다.

---

## Vercel 을 프록시로 바꿨다 (2026-09-30)

### 왜
플레이 프로덕션이 승인돼 게시 직전이었는데, 확인해 보니 **출시되는 안드로이드 TWA 가 여는 주소는
`massa-seven.vercel.app`** 이었다(APK 문자열에서 5회 확인). 그런데 그 Vercel 프로젝트는
**9월 10일 이후 배포가 멈춰 있었다.** GitHub 연동이 커밋을 물지 않는다 — 오늘 푸시한
`37f9159` 도 자동 배포가 안 떴다. 그대로 게시했으면 새 사용자는 3주 묵은 화면,
즉 허위 인증 마크 22개와 허위 별점 1,775건을 그대로 봤을 것이다.

### 무엇을 했나
Vercel 배포에 **파일 두 개만** 올렸다. 앱 파일은 하나도 올리지 않았다.

```
vercel.json                    라우팅 규칙
.well-known/assetlinks.json    TWA 검증 파일
```

```json
{ "routes": [
    { "handle": "filesystem" },
    { "src": "/(.*)", "dest": "https://app.massaviet.com/$1" } ] }
```

filesystem 단계에서 잡히는 건 assetlinks 뿐이고, 나머지 모든 경로는 VPS 로 넘어간다.

### 반드시 지킬 두 가지
1. **리다이렉트가 아니라 프록시(rewrite)여야 한다.** 주소가 `app.massaviet.com` 으로 바뀌면
   TWA 의 출처 검증과 GoTrue 허용목록이 한꺼번에 깨진다. 검증할 때 `num_redirects:0` 을 꼭 본다.
2. **assetlinks 는 프록시에 맡기지 않고 Vercel 에 직접 둔다.** TWA 가 앱을 여느냐 브라우저를
   여느냐가 여기에 달렸다. 프록시가 잠깐 죽어도 이건 살아 있어야 한다.

`.vercelignore` 로 앱 파일이 다시 올라가는 걸 막아 뒀다. 앱 파일이 같이 올라가면
filesystem 단계에서 그게 먼저 잡혀 프록시가 조용히 무력화된다.

### 결과
세 주소가 같은 내용을 준다. 앞으로 VPS 에 배포하면 Vercel 쪽도 자동으로 따라온다.
**Vercel 이 배포되든 말든 상관없어졌다.** 이게 #62 Vercel 탈출의 실질적 완료다.
남은 건 나중에 TWA 를 `app.massaviet.com` 으로 다시 빌드하는 것뿐인데,
그건 새 버전 심사라 게시가 끝난 뒤에 한다.

### 검증
`scripts/vps-test-vercel-proxy.sh <host>` — 200·리다이렉트 0·새 문구·assetlinks 지문·
하위 경로 7개·비밀 파일 404 를 한 번에 본다. 미리보기에서 먼저 돌리고 별칭을 붙였다.


## 아이폰 푸시를 어떻게 붙였나 (2026-10-08)

### 구조
예약 트리거 / 공지 RPC → `notifications` 행 → (문장 단위 트리거가 pg_net 으로) `send-push` 호출
→ `claim_unpushed_notifications()` 가 `pushed_at` 을 찍으며 한 번만 내줌 → 그 사람의 `push_tokens` 로 APNs.
pg_net 호출이 빠질 때를 대비해 VPS 크론이 1분마다 같은 함수를 부른다(`/root/massa_push.sh`, 로그는 보낼 게 있을 때만 `/var/log/massa_push.log`).
**알림함과 푸시가 같은 행을 쓴다** — 푸시만 따로 쌓는 테이블을 만들지 않았다. 앱 알림함·실시간 토스트가 그대로 같이 동작한다.

### 어떤 이벤트에 보내나 — 실제 코드 흐름을 보고 정했다
- 앱은 예약을 `status: 'confirmed'` 로 **바로 넣는다**(index.html submitBooking). 그래서 "새 예약" 알림은 상태와 무관하게 INSERT 에 건다.
- 손님에게: 확정(requested→confirmed, 파트너 수락), 출발(on_the_way — 지금 UI 엔 버튼이 없지만 요청 범위라 넣음),
  **완료**(평가 요청 — 지금 흐름에서 실제로 일어나는 몇 안 되는 변화라 넣음), 취소 중 `cancelled_by <> 'customer'`
  (파트너 거절은 cancelled_by 가 비어 있고, 노쇼는 'provider', 관리자 취소도 비어 있다).
- 손님 본인 취소는 손님에게 안 보낸다. 대신 (같은 날 추가 요청으로) 마사지사 계정 owner_id·profile_id 에
  `booking_cancelled_by_customer` "손님이 예약을 취소했습니다" 를 보낸다. 관리자에게는 보내지 않는다(요청 대상이 마사지사뿐).
  DB 트리거·send-push 제목 표만 바꾼 것이라 **앱 재빌드 없이 바로 동작한다**. 알림함 제목 번역(DICT)만 다음 빌드(1.0.11)에 실린다.
- 새 예약 수신자: `providers.owner_id` 와 `profile_id` 둘 다(RLS 가 둘 다 마사지사로 인정한다) + 관리자 전원. UNION 으로 중복 제거.

### 문구·언어
- DB 의 제목은 **index.html DICT 에 이미 있는 한국어 문장**을 그대로 쓴다 → 알림함에서 translateTree 가 그 사람 언어로 바꾼다.
  본문은 `예약번호 · MM/DD HH24:MI(하노이)` 라 언어와 무관하다.
- 푸시 제목은 토큰에 저장한 화면 언어(`push_tokens.lang`)로 send-push 가 고른다. vi·ko 외(en·zh·ja)는 영어.
  `profiles.preferred_language` 는 앱이 갱신하지 않아 쓸 수 없었다.
- 공지는 관리자가 쓴 문장 그대로 보낸다(번역 없음).

### 시크릿
send-push 는 notify-admin 과 같은 `NOTIFY_SECRET` 을 쓴다. 트리거는 `app_settings('push')` 에서 URL·시크릿을 읽고,
그 값은 스키마가 `app_settings('notify')` 에서 서버 안에서 복사한다 — 시크릿이 화면이나 저장소에 나오지 않는다.
APNs 키는 VIBI 와 같은 팀 키(HS4BHJFLR2, Sandbox & Production)라 `/root/vibi/.env` 의 세 줄을 그대로 복사했다.

### 시험 방법
- DB: `scripts/test_push.sql` — 전부 트랜잭션 안, 끝에 rollback. pg_net 대기열 행도 같이 사라진다.
- APNs: 실제 손님 토큰은 절대 쓰지 않는다. 관리자 계정에 **가짜 토큰**을 넣고 알림 한 건 → `BadDeviceToken` 이면
  키·팀 인증은 통과한 것(키가 틀리면 403 InvalidProviderToken 이 난다). 토픽까지의 최종 확인은 실기기 수신으로 한다.

### 주의
- 한 시간 넘게 묵은 알림은 푸시하지 않는다(서버가 오래 멈췄다 살아났을 때 철 지난 푸시 폭탄 방지). 알림함에는 남는다.
- 세션 만료로 로그아웃되면(사용자가 로그아웃을 누르지 않으면) 토큰이 옛 계정에 남는다. 다음 로그인 때 새 계정으로 옮겨진다.
- `scripts/test_fee_tier.sh` 처럼 실제 예약 행을 넣는 시험은 이제 관리자에게 "새 예약" 알림을 만든다.
- 별건 발견(손대지 않음): `submitBooking()` 이 날짜를 `2026-06-${day}` 로 만든다 — 달이 6월로 박혀 있다.
  조사 결과: 날짜 칩 자체가 마크업에 고정된 와이어프레임이다(index.html 741~747, `토 6`~`금 12` = 2026년 6월 6~12일, 기본 선택 7).
  JS 로 다시 그리는 코드가 없다. 그래서 오늘(10/08) 누가 예약해도 2026-06-06~12 중 하루로 저장된다
  (기본값이면 `2026-06-07T20:00+07:00` = `2026-06-07T13:00:00Z`, 이미 지난 날짜). admin.html 2011 에도 같은 코드가 있다.
  지금까지 예약이 0건이라 잘못 저장된 실데이터는 없다. → 같은 날 사장님 승인으로 수정(아래).

## 예약 날짜 칩을 하노이 기준으로 그리기 (2026-10-08)
- 날짜 계산은 `now + 7시간` 의 UTC 연월일을 쓴다. 하노이는 서머타임이 없어 이 방식이 늘 맞고, 기기 시간대(한국 폰 등)에 흔들리지 않는다.
- 저장값은 화면 글자에서 파싱하지 않는다. 칩의 `data-date` 를 쓴다 — "번역한 텍스트에서 숫자를 긁지 말 것"(08-29 교훈)과 같은 이유.
  화면의 '일' 숫자는 `selectedDayNum()` 이 그대로 읽어 예약 확인 화면에만 쓴다.
- 칩은 시간 화면에 들어갈 때(`go('time')`) 다시 그린다. 아이폰 앱은 백그라운드에서 며칠 살아 있을 수 있다.
- 지난 시각 차단: 처음엔 지시대로 넣지 않았다가 사장님 승인으로 추가했다. `isBookable(iso, now)` = 예약 시각 ≥ 지금 + 30분.
  30분은 마사지사 이동 여유. 비교는 절대 시각(ISO)끼리라 기기 시간대와 무관하다. 막히면 알림창을 띄우고 시간 화면으로 돌려보낸다
  (칩도 그때 다시 그려진다). 관리자 콘솔의 상태 변경(adminSetBooking 등)은 다른 경로라 영향 없다.
  화면에서 미리 막지 않고 저장 직전에만 막는다 — 시간 고르는 UI 를 바꾸지 않는 최소 수정.
- index.html 과 admin.html 의 `hanoiWeek` 는 글자까지 같아야 한다 — `scripts/test_hanoi_week.js` 가 둘을 비교한다.

## profiles 자기 권한 상승 차단 (2026-10-08)

### 구멍
`profiles_self_update` 정책에 컬럼 제한이 없고 anon·authenticated 에 테이블 단위 UPDATE/INSERT 가 있었다.
로그인만 하면 자기 `role` 을 `admin` 으로 바꿔 `is_admin()` 을 통과하고, `cancel_count`·`no_show_count`·
`booking_blocked_until` 을 지워 노쇼 제재를 풀 수 있었다. (적용 전 시험이 FAIL 로 재현)

### 고친 방법
- 테이블 단위 INSERT/UPDATE 회수 → `full_name, phone, gender, nationality, terms_agreed_at, privacy_agreed_at,
  marketing_agreed_at, terms_version` 만 UPDATE 재부여. INSERT 는 앱에 경로가 없어 다시 주지 않았다.
  (테이블 권한이 남아 있으면 컬럼 revoke 가 먹지 않는다 — KBizV 0022 와 같은 방식)
- 제재 값은 `refresh_customer_penalty(p_customer)` (security definer) 가 예약 기록으로 다시 세서 저장한다.
  규칙은 앱 CANCEL_RULES 그대로(30일·1시간·5회→7일). 부를 수 있는 사람: 본인, 그 손님 예약을 맡은 마사지사, 관리자.
  파트너의 `markNoShow` 는 원래 RLS 때문에 손님 행 수정이 조용히 실패하고 있었는데 이걸로 실제로 기록된다.
- 시험: `scripts/test_profiles_role_lock.sql` (롤백). REST 확인은 임시 계정으로 하고 바로 지웠다.

### 남은 것 (손대지 않음)
- **auth.users 에 가입 트리거가 없다.** `handle_new_user()` 함수는 있는데 걸린 트리거가 0개.
  VPS 이전 때 auth 스키마 트리거가 안 따라온 것으로 보인다. 8/27 이후 가입 9명이 profiles 행이 없어
  프로필 수정·약관 동의 저장·제재 기록이 전부 0행 처리된다. → 아래에서 트리거 복구 + 9명 백필 완료
- 아이폰 앱은 index.html 을 내장하므로 RPC 호출은 다음 빌드부터. 옛 빌드의 자기 취소 페널티 기록은 403 으로 조용히 실패한다.
- 예약 제한은 여전히 앱에서만 검사한다(`ensureNotBlocked`). bookings INSERT 정책은 제재를 보지 않는다.
- `bookings_customer_update` 가 손님에게 자기 예약의 모든 컬럼(no_show_at·cancelled_at·amount_vnd·is_paid 등) 수정을 허용한다.
- `providers_owner_update` 가 마사지사에게 자기 행의 모든 컬럼(is_verified·fee_tier·penalty_level·suspended_until·application_status 등) 수정을 허용한다.
- 관리자 `unblockCustomer` 는 profiles 에 관리자 UPDATE 정책이 없어 원래부터 동작하지 않는다. → 아래에서 해결

## 가입 트리거 복구 + 백필 + 관리자 예약 제한 해제 (2026-10-08)

- 원인: `handle_new_user()` 함수는 남아 있고 `auth.users` 트리거만 없었다(VPS 이전 때 auth 스키마 트리거 누락).
  `scripts/profiles_signup_trigger.sql` 이 함수를 다시 만들고 `on_auth_user_created` AFTER INSERT 트리거를 건 뒤,
  같은 매핑으로 빠진 회원을 백필한다(on conflict do nothing — 몇 번 돌려도 같다).
- 매핑: `full_name` = 메타데이터 full_name → name → '' , `phone` = auth.users.phone → ''. `preferred_language` 등은 기본값.
- **role 은 메타데이터에서 절대 읽지 않는다.** 항상 컬럼 기본값 customer. 앱 signUp 은 메타데이터를 보내지 않고,
  마사지사 여부는 `providers.profile_id/owner_id` 로 판단하며, admin·reviewer 는 서버에서만 바꾼다.
  화이트리스트로 provider 를 허용할 이유도 없어서 아예 매핑하지 않았다.
- profiles 에는 트리거가 하나도 없다 → 백필은 notifications 를 만들지 않는다. `push_outbox` 테이블은 이 DB 에 없다.
  운영 적용 결과: profiles 없는 회원 9 → 0, admin 1 → 1, notifications 3 → 3.
- 관리자 해제는 `admin_unblock_customer(p_customer)` (security definer, `is_admin()` 아니면 42501) 가
  `booking_blocked_until=null, cancel_count=0, no_show_count=0` 으로 지운다. 기존 unblockCustomer 와 같은 의미.
  주의: 이후 `refresh_customer_penalty` 가 돌면 30일 예약 기록으로 횟수를 다시 센다(5회 이상이면 다시 7일 제한).
- 시험: `scripts/test_profiles_signup_trigger.sql` — 마이그레이션의 begin/commit 줄을 sed 로 지운 본문을
  컨테이너 `/tmp/profiles_signup_body.sql` 로 넣고 돌린다(전체 롤백).

## 예약·제공자 행 권한 잠금 (2026-10-08)

- 컬럼 GRANT 가 아니라 BEFORE 트리거(`trg_booking_guard`, `trg_provider_guard`)로 막는다. 관리자도 같은 authenticated
  역할이라 GRANT 로는 손님·관리자를 못 가르고, '값이 실제로 바뀐 칸'(`changed_columns(old,new)`)만 보면
  구 앱이 같은 값을 다시 보내는 요청(현장 결제 확정의 `is_paid:false`·같은 금액)도 통과한다.
- 통과: `current_user` 가 authenticated/anon 이 아닌 경우(service_role 엣지 함수, postgres 소유 보안정의자 함수), `is_admin()`,
  providers 는 `is_reviewer()`(관리자·심사자). 트리거 함수는 보안정의자가 아니다 — current_user 로 판단하기 때문.
- bookings 손님: 취소(대기·확정 → cancelled, `cancelled_at=now()`·`cancelled_by='customer'` 서버가 덮어씀), `payment_method`, 쿠폰
  (보유·미사용·유효 쿠폰 한 번만, `discount_vnd` 는 서버 계산). is_paid·amount_vnd·노쇼·기타 칸은 42501.
- bookings 담당 마사지사: status·accepted/completed/rejected/cancelled_at·no_show_at·reject/cancel_reason·cancelled_by 만.
  기록 시각은 비어 있을 때 한 번만, 값은 `now()`. 끝난 예약(cancelled·completed·no_show)은 못 바꾼다.
- bookings INSERT(관리자 외): `booking_blocked_until > now()` 면 42501 + hint `booking_blocked` + 하노이 시각 안내.
  결제·기록 칸·쿠폰이 있거나 status 가 requested/confirmed 가 아니거나 service_id 가 없으면 거부. fee_rate 는 null 로 비워 `trg_freeze_fee_rate` 가 채운다.
- providers 본인: display_name·photo_url(s)·bio·service_area·phone·business_hours·is_active·위치(lat/lng/last_*)·반려 재제출(rejected→pending, reject_reason null)만.
  정지 중(`suspended_until > now()`)에는 is_active 를 켤 수 없다. INSERT 는 pending·표시 없음·fee_tier 기본값·본인 id 로만.
- 거절 누적은 `refresh_provider_penalty(p_provider)` — 30일 거절 수로 단계 계산, **단계는 올리기만**(신고 제재를 이 함수로 지우지 못하게).
  내리는 것은 관리자 clearPenalty. 앱 문구 '거절을 줄이면 회복됩니다' 는 이제 자동이 아니다.
- 결제창 QR·이체·카드는 가짜 결제다(돈이 오가지 않음). 이제 결제 수단만 저장하고 is_paid 는 서버(토스 승인)·관리자만 바꾼다.
- 알려진 미해결: createStaff(샵 직원 추가)는 중복 신청 가드 때문에 원래도 실패하던 경로이고, 이제 승인 상태 INSERT 도 막힌다.
  user_coupons 는 손님이 자기 행을 자유롭게 쓴다(is_used 되돌리기 가능).
- 시험: `scripts/test_bookings_providers_lock.sql`(롤백, 예약 INSERT 알림도 롤백으로 사라짐),
  REST: `scripts/vps-test-bookings-providers-lock.sh`(임시 계정, 시험 예약은 session_replication_role=replica 로 넣어 알림 없음).

## 거절 제재 자동 회복 + 쿠폰함 잠금 (2026-10-08, 사용자 결정)

- 위 절의 '단계는 올리기만' 은 바뀌었다. 이제 단계 = greatest(최근 30일 거절 수로 계산한 단계, `providers.penalty_floor`).
  오래된 거절이 30일을 넘기면 내려가고, 관리자·신고 제재로 준 단계 아래로는 내려가지 않는다.
- `penalty_floor` 는 따로 쓰지 않는다. 관리자·심사자가 앱에서 `penalty_level` 을 바꾸면 트리거(`keep_penalty_floor`)가
  같은 값으로 맞춘다(submitResolve 1~3, clearPenalty 0). 서버 함수(postgres)가 바꿀 때는 하한을 건드리지 않는다.
  적용 당시 penalty_level>0 인 제공자는 0명이라 백필 대상 없음.
- 3단계 정지(3일)는 '새로 3단계에 들어설 때' 또는 `p_after_reject=true`(파트너가 방금 거절)일 때만 건다.
  화면 열기·매일 재계산으로 정지가 늘어나지 않게 하려는 것. 정지가 끝나도 is_active 는 마사지사가 다시 켠다(기존과 같음).
- 회복은 마사지사가 아무것도 안 해도 된다: 매일 호스트 crontab(00:17 UTC) `refresh_all_provider_penalties()`,
  그리고 파트너 예약 화면을 열 때 재계산. 앱 문구 '거절을 줄이면 회복됩니다' 는 이제 사실이라 고치지 않았다(번역 사전에도 없는 문장).
- 쿠폰함: 받기 = 활성·기한 내 쿠폰을 미사용으로만(어떤 쿠폰이든 1인 1회 — 기존 규칙, 신규 가입 전용 제한 같은 건 원래 없다),
  수정 = is_used false→true 만(used_at 은 서버 시각), 삭제 금지. 관리자가 user_coupons 를 직접 발급하는 경로는 없다.
- 쿠폰 사용 처리는 예약에 coupon_id 가 붙는 순간 `trg_booking_coupon_used`(보안정의자)가 한다. 구 앱의 사용 처리 호출은 0행으로 오류 없이 지나간다.
  예약 취소 때 쿠폰 복원 규칙은 기존 코드에 없다 → 만들지 않았다(취소해도 쿠폰은 사용됨으로 남는다).
- 시험: `scripts/test_penalty_recovery_coupon_lock.sql`(롤백), REST: `scripts/vps-test-penalty-coupon-lock.sh`(임시 계정 3개, 관리자 포함).

## 2026-10-14 — 경쟁앱 Glow 대조 후 손본 것들

경쟁앱 Glow(com.glow.mobileApp, Orderdi JSC 하노이, 10만+ 설치)의 실제 화면을
사장님이 폰으로 찍어 보내주셨다. APK 는 뜯지 않았다 — 로그인 UX 질문에 답이 안 되고
현지 경쟁사 제품을 분해하는 법적 노출이 있어서다. 사용자로서 쓴 화면만 봤다.

### 확인한 차이

| 항목 | Glow | massa (고치기 전) |
|---|---|---|
| 로그인 | Google · 전화번호 버튼 2개, 약관 체크박스 | 이메일·비번 입력칸 먼저 + 소셜 3종 |
| 전화 OTP | 기본 수단 | 없음 (서버는 phone:true 로 켜져 있었음) |
| 국적·성별 | 로그인 직후 강제 단계 (건너뛰기 가능) | 계정 탭 안쪽 '추가 정보' |
| 채팅 | 홈 우상단 상시 | 예약 후에만 |
| 결제 | 현금 후불 + WELCOME 쿠폰 자동 | 같음 |
| 장바구니 | 서비스 여러 개 담기 | 한 번에 하나 |

### ★ 접속 제약 (사장님 전달)

사장님이 **지금 한국에 계셔서 Zalo 를 못 쓰신다.** Zalo 인증이 걸린 Glow 내부
화면(예약 완료 이후, 마사지사 메신저 등)은 **확인이 안 된 상태**다.
→ **베트남 가신 뒤 사장님이 직접 보고 추가 수정하기로 함.**
   그때까지 Glow 내부 동선에 대한 추측으로 코드를 고치지 않는다.

### 손본 것

1. 채팅 봇 자동응답 제거 — sendChat 이 1.1초 뒤 sender_role:'provider' 로 가짜 답장을
   DB 에 넣고 있었다. 마사지사가 파트너 채팅을 열면 자기가 한 적 없는 약속이
   자기 이름으로 찍혀 있었다. 데모 코드가 운영에 남아 있던 것.
2. 전화번호 + OTP 로그인 추가.
3. 국적·성별을 가입 직후 단계로 올림.

### 2026-10-14 — 예약이 'requested' 로 바뀌었다 (중요)

고객 앱이 `status:'confirmed'` 로 예약을 바로 만들고 있었다. 그래서 파트너 앱의
수락 버튼은 출시 이래 한 번도 눌린 적이 없다(13건 전부 confirmed, requested 0건).
대체 마사지사 유도를 만들려면 기다릴 상태가 있어야 해서 'requested' 로 바꿨다.

따라오는 결과 — **마사지사가 안 누르면 예약이 떠 있다.** 그게 10분 대체 제안의 이유다.
마사지사가 6명뿐이라 초기에는 사장님이 수락률을 지켜봐야 한다.

수락은 반드시 `accept_booking()` RPC 로만 한다. 앱에서 update 로 하면 두 명이
같은 순간에 누를 때 둘 다 확정된다. DB 에 부분 유니크 색인도 함께 걸어 뒀다.

늦게 누른 사람은 **거절이 아니라 취소**다. reject_count 를 올리면 안 된다.

### 2026-10-14 저녁 — 운영 콘솔 보고 판 것들

**범위 밖 예약이 1건이 아니라 7건이었다.** 14건 중 절반.
예약 place_id 는 14건 다 있었는데 city_code 는 1건뿐이라 탐지가 안 되고 있었다
(vps-booking-region.py 를 사람이 손으로만 돌렸다). 전부 채우고 10분 크론에 걸었다.

  MS-261014-5352  하노이 ← Mins(칸호아)      ★ 1000km 신고 건
  MS-261012-8910  하노이 ← Trang(자라이)
  MS-261012-7411  하이퐁 ← Kun(하노이)
  MS-261011-2230  하이퐁 ← Kun(하노이)
  MS-261011-4667  람동   ← Kun(하노이)
  MS-261011-7537  자라이 ← Thảo(하노이)
  MS-261011-0451  자라이 ← Hồng Trà(하노이)

**"Sao thấy ktv cách tận hơn 1000km" 신고는 계산이 맞았다.**
Mins 는 칸호아고 ward_codes 가 비어 성 중심점(12.24,109.20)을 쓴다.
하노이에서 1,080km. 거리는 재고 있었는데 **정렬에 안 쓰고 있었다.**
→ 가까운 순 정렬 + 50km 경고 · 150km 차단.

**'이름 없음·연락처 없음'은 화면 버그가 아니었다.** 손님 49명 중 48명 이름,
49명 전원 연락처가 있다. 비어 있는 그 한 명이 하필 예약 6건을 했다.
→ 예약 확정 전에 비어 있으면 받는다.

**이상 거래 '1시간 안에 3건 연속'은 정상 동작이다.** 고객별로 제대로 세고 있다.
8910·2392·7805 는 한 손님, 4591·6435·1500 은 tien pham. 둘 다 진짜 3건이다.

ward_codes 가 비어 성 중심점을 쓰는 마사지사 5명 —
Lê Thúy Hiền(다낭) · Mi · Mins · Miu miu(칸호아) · Nguyễn thị thiên trang(호치민).
프엉을 받아 채우면 거리가 정확해진다.

### 2026-10-14 — 시스템 과실 신고 3건·안전 요청 1건 삭제

사장님 판단: 마사지사가 시스템 문제로 요청을 못 받아 생긴 컴플레인이라
마사지사 기록에 남길 이유가 없다. 삭제.

지운 것 — reports 3건(Thế 의 'không đến'·'không thấy nhân viên đâu',
Bem Bem 의 'Sao thấy ktv cách tận hơn 1000km'), safety_alerts 1건(share_location).

되돌릴 수 있다. DB 에 백업 테이블로 떠 뒀다.
  reports_sysfault_backup_20261014
  safety_alerts_sysfault_backup_20261014
복구는 insert into reports select * from reports_sysfault_backup_20261014;

★ 원인은 이미 고쳤다 — 거리순 정렬 + 150km 차단 + 지역 자동 판정 크론.
  같은 일이 또 생기면 그건 새 문제지 이 기록의 연장이 아니다.

### 2026-10-15 — 예약 기록 전부 삭제 (영업 개시 전 상태로)

사장님 확인: **지금까지 실제로 서비스가 이뤄진 건은 한 건도 없다.**
마사봇이 마사지사 이름으로 가짜 답장을 넣는 바람에 손님과 마사지사가 앱 내
메신저를 쓰지 못했고, 마사지사들은 **자기한테 주문이 온 줄도 몰랐다.**
그래서 예약 14건은 전부 허수다. 매출·수수료로 세면 안 된다.

지운 것 — bookings 14건, booking_id 달린 notifications 30건,
sender_role='provider' 인 가짜 메시지 11건.
손님이 직접 쓴 메시지 14건은 남겼다 (사람이 쓴 말이다).

백업 테이블 (되돌릴 수 있다)
  bookings_backup_20261015
  messages_bot_backup_20261015
  reports_sysfault_backup_20261014
  safety_alerts_sysfault_backup_20261014

차단 거리를 150km → **30km** 로 (사장님 지시). 경고는 15km.
FAR_WARN_KM / FAR_BLOCK_KM 두 상수만 고치면 된다.
★ 프엉 중심점으로 재는 거리라, ward_codes 가 빈 마사지사 5명은
  성 중심점을 쓴다 — 30km 면 같은 성 안에서도 막힐 수 있다. 프엉을 받아야 한다.

### 2026-10-15 — 30km 밖은 아예 안 보여 준다

사장님 판단: 30km 를 넘으면 마사지사가 안 간다. 보여 주면 손님이 기다리다 펑크를 맞는다.
→ 위치를 켠 손님에게는 fillList 에서 30km 밖을 **숨긴다**. 숨긴 인원 수는 적어 준다.
   목록 숨김과 예약 차단이 같은 FAR_BLOCK_KM 을 쓴다 — 안 보이는 사람을 예약할 길이
   있으면 안 된다.
   위치를 안 켠 손님에게는 거를 수가 없으니 전부 보여 준다(종전대로 성 기준).
   거리를 모르는 마사지사도 거르지 않는다. '모른다'는 '멀다'가 아니다.

손님 메시지 14건도 삭제 (messages_backup_20261015). 이제 bookings·messages·
reports·safety_alerts 전부 0건. 진짜 0부터 시작한다.

### 2026-10-15 — 창립 멤버 혜택은 '말만' 있었다

사이트에 "첫 20건 수수료 없음"이라고 2주 넘게 적어 두었는데 그걸 세는 코드가
아무 데도 없었다. fee_rate_of 가 등급표만 보고 있었다. 지금 고쳤다.
★ 화면에 카운터만 붙이는 것으로는 부족하다. fee_rate_of 를 고쳐야 실제 청구가 0 이 된다.

세는 기준은 '확정 후 살아 있는 건'이다. 취소·노쇼는 20건에서 깎지 않는다.
BEFORE INSERT 시점이라 그 예약은 아직 없다 → '쌓인 게 20 미만이면 공짜' 로 정확히 20건.

### 마사지사 카드가 사진·이름만 눌렀을 때 열리던 문제

내가 증거 화면을 찍다가 직접 걸렸다. 카드 가운데를 눌러도 아무 일이 없었다.
.tcard 전체에 onclick 을 걸되 .card-fav 와 .bookbtn 은 비켜 가게 했다.

### 2026-10-15 — iOS 는 번들이다 (중요)

codemagic.yaml 이 저장소 루트의 index.html 을 capacitor/www 로 **복사해 앱에 넣는다.**
server.url 설정이 없다. 즉 **iOS 앱은 서버를 보지 않는다 — 재빌드해야 바뀐다.**
안드로이드 TWA 와 웹은 app.massaviet.com 을 실시간으로 본다.

→ 오늘 한 것 전부(봇 제거·수락제·30km·즉시 매칭·날짜 월 표시·국적 시트·카드 클릭)는
   웹·안드로이드에는 반영됐고 **iOS 에는 아직 없다.**

### '날짜에 월 표시' 는 빌드 문제가 아니었다

hanoiWeek() 가 { ymd, day, dow } 만 돌려주고 월을 아예 안 만들고 있었다.
화면도 dow + day 만 그렸다. 코드에 없던 것이지 빌드가 안 된 게 아니다. 오늘 넣었다.

### 지금 받기 (즉시 매칭)

'베타 오픈 후 순차 제공' 안내를 지우고 진짜로 만들었다. 가정 두 가지 —
  1) 시간은 '지금 + 60분' (INSTANT_LEAD_MIN). 이동 시간이 필요하다.
  2) 가까운 5명(INSTANT_FANOUT)에게 동시에 보낸다. 먼저 수락하는 사람이 간다.
10분 기다렸다 퍼뜨리던 것을 처음부터 퍼뜨리는 것뿐이라 뒤의 기계(accept_booking)는 그대로다.
숫자 두 개만 고치면 조절된다.

### 2026-10-15 — providers.phone 에는 번호를 넣지 않는다 (내 제안이 틀렸다)

내가 "신청서 번호를 providers.phone 에도 같이 넣자"고 제안했는데 틀렸다.
`strip_provider_phone` 트리거가 **일부러** 항상 null 로 지우고 있었다.
주석: "연락처의 정본은 provider_kyc.contact 다".

이유가 맞다 — providers 는 손님 앱이 읽는 테이블이고 provider_kyc 는 관리자만 읽는다.
번호를 providers 로 옮기면 개인정보가 샌다. 백필을 시도했지만 트리거가 다 막았다(다행).
guard_provider_kyc 에서 phone 채우는 부분도 뺐다.

→ 로스터는 admin_provider_list() 안에서 kyc.contact 를 읽는다. 그게 올바른 길이다.
→ index.html 1821줄의 `isAdminUser() && p.phone` 전화 표시는 영영 안 뜬다
   (providers.phone 이 항상 null). 별개 문제로 남겨 둔다.

### 서류 자물쇠 (sql-kyc-lock.sql)

필수 네 가지 — 연락처 · 신분증 앞면 · 신분증 뒷면 · 계좌번호.
승인으로 **바뀌는 순간**과 is_active 가 **켜지는 순간**에만 본다.
끄기·반려는 언제나 허용한다. 기존 행은 다른 칸을 고쳐도 안 걸린다.
Kun 은 사장님 결정으로 그대로 두되, 한 번 끄면 서류 없이는 다시 못 켠다.
화면(심사 카드)의 lack 목록도 같은 네 가지로 맞췄다 — 기준이 다르면
승인 버튼은 눌리는데 저장이 거부된다.

### 2026-10-15 — 채팅은 마사지사가 먼저 건다 (사장님 방침)

손님이 먼저 말을 걸게 두면 안 된다. 수락한 마사지사가 재확인 메시지를 보내는 것이 맞다.
Glow 도 그렇게 돈다. 내가 "손님이 먼저 걸 가능성이 높다"고 한 건 방침과 어긋났다.

세 겹으로 만들었다 —
  1. DB  guard_first_message : sender_role='customer' 인데 그 상대에게서 온 메시지가
     하나도 없으면 거부. 화면을 우회해도 안 들어간다.
  2. 파트너 : accept_booking 성공 직후 확인 메시지 창이 뜬다 (베트남어 초안 채워져 있음).
     '나중에'로 닫으면 예약 카드에 "⚠ 확인 메시지를 아직 안 보냈습니다 · 지금 보내기"가 붙는다.
  3. 고객 : chats_opened() 로 '말 걸어 온 마사지사' 목록을 받아, 그 사람에게만 💬 채팅 버튼.
     아니면 "테라피스트가 먼저 연락드립니다." 예약 완료 화면의 채팅 버튼은 아예 없앴다.

★ 왜 이게 중요한가 — 오늘 지운 신고 두 건이 바로 이 공백에서 나왔다.
  손님은 올지 안 올지 모른 채 기다리다 "안 왔다"고 신고했다. 한 줄이면 막을 수 있었다.

### 2026-10-15 저녁 — '신청'과 '예약'을 가른다 + 600km 사고의 진짜 원인

사장님 방침: 손님이 넣으면 **신청**, 마사지사가 수락해야 **예약**이다.

오늘 두 건이 들어왔는데 status='confirmed' 인데 accepted_at 이 비어 있었다.
아무도 수락하지 않았다 — 옛 iOS 앱(1.0.13)이 confirmed 로 바로 넣은 것이다.
group_id 없음 · 손님 이름/연락처 없음 → 오늘 넣은 새 코드를 하나도 안 탔다.

★ 교훈 두 번째 — 화면에만 둔 규칙은 규칙이 아니다.
  30km 검사를 index.html 에만 넣었더니, 옛 앱에서 하노이 손님이 다낭 마사지사를
  603km 밖에서 두 건 신청했고 그대로 들어왔다. 서버에 아무 방어가 없었다.

서버에 건 자물쇠 두 개 —
  1. guard_booking_write : 손님이 만드는 예약은 무조건 status='requested' 로 덮는다.
     ★ 막지 않고 조용히 되돌린다. 막으면 아이폰 손님은 아예 예약을 못 한다.
  2. guard_booking_distance : 좌표를 둘 다 알고 30km 초과면 거부,
     성(city_code)을 둘 다 알고 다르면 거부. 모르면 막지 않는다.
     거리 상한은 app_settings.booking.far_block_km 로 바꿀 수 있다(기본 30).

시험 — 603km 거부 / 하노이 마사지사 통과 / 손님이 confirmed 로 보내도 requested 로 저장.

문구도 갈랐다: STATUS_KO requested='신청 (수락 대기)', confirmed='예약 확정'.
화면 제목 '예약 완료'→'신청 완료', '예약이 확정되었습니다'→'신청을 보냈습니다',
'예약 확인'→'신청 확인', '내 예약'→'내 신청·예약'.

성사 안 된 2건은 삭제 (bookings_backup_20261015b 에 백업).

### 2026-10-16 — 전 구간 시험 통과 + 구멍 두 개 더 막음

실제 권한(authenticated)으로 손님·마사지사를 번갈아 흉내 내 끝까지 돌렸다. 7개 전부 통과 —
  1) 손님이 confirmed 로 보내도 requested 로 저장 (수수료율 0 = 창립 멤버)
  2) 손님 선톡 막힘
  3) Kun 수락 → confirmed + accepted_at 기록, 묶인 Thanh hà 건 자동 취소
  4) 늦은 수락 막힘
  5) 마사지사 선톡 후 손님 답장 통과
  6) 607km 신청 막힘

그 뒤 훑다가 구멍 두 개를 더 찾았다 —
  ★ 좌표 없이 주소를 직접 적으면 거리 검사를 **통째로 건너뛰었다.**
    다낭 마사지사가 하노이 신청을 받는 걸 확인했다. 좌표를 필수로 만들었다.
    (마사지사 길찾기에도 어차피 필요하다. 앱에서도 먼저 안내하게 했다.)
  ★ 알림이 아직 "새 예약이 들어왔습니다" 였다 → "새 신청이 들어왔습니다 — 수락해 주세요".
    취소 알림도 '신청' 으로 맞췄다.

남은 위험 — 프엉이 빈 마사지사 5명은 성 중심점으로 거리를 잰다. 호치민·칸호아는 성이 넓어
같은 성 안의 정상 신청도 30km 를 넘어 막힐 수 있다. 프엉을 받아야 한다 (안내는 보냈다).

## 2026-10-16 — 관리자 콘솔 전 표 쪽 나누기
가입자 명단에만 있던 쪽 나누기를 8개 표 전부에 넣었다.
베껴 쓰지 않고 공용 helper 로 뺐다 — 표마다 복사하면 한 곳 고칠 때 나머지를 빼먹는다.

- `pageOf(key, rows)` / `pageBar(key, p)` / `pageReset(key)` + `PAGE_DRAW` 등록표.
- 쪽 넘김·개수 바꾸기는 문서에 한 번 건 위임 리스너가 처리한다 (표가 다시 그려져도 살아 있다).
- 적용: members · roster · rep · bk · price · fraud · cp · traffic.
- 가입자 명단의 `MPAGE`/`#mper`/`#mpage` 전용 코드는 지우고 공용 helper 로 옮겼다.
  툴바의 '10명씩' 고르개도 뺐다 — 쪽 막대 안에 들어 있어 두 개가 되기 때문이다.
- 거르개·찾기·정렬을 바꾸면 1쪽으로 돌아간다 (`pageReset`). 3쪽에서 거르면 빈 화면이 뜬다.
- 줄이 10건 이하면 막대를 아예 안 그린다. 군더더기만 된다.

검증 (massaviet.com/admin, 2026-10-16)
- 막대 3개 떴다 — 유입 14건, 마사지사 12명, 가입자 59명. 나머지 표는 10건 이하라 안 뜬 게 맞다.
- 가입자 다음 ›  2/6 → 3/6, 50개씩 → 1/2쪽 1–50번째, 이름 찾기 거르니 1쪽으로 복귀.
- 마사지사 다음 ›  2/2쪽 11–12번째 — 표끼리 쪽이 섞이지 않는다.
- 콘솔 오류 0건.

## 2026-10-16 — iOS 1.0.15 심사 제출
- Codemagic 빌드 #33 은 '실패'로 보였지만 빌드·업로드·App Store Connect 처리는 전부 성공했다.
  실패한 건 마지막 'TestFlight 베타 심사 제출' 단계 하나뿐이고, 사유는 Complete test information is required
  — 외부 베타 테스트 정보가 비어 있어서다. 앱 심사와는 무관하다.
  ★ Codemagic 의 'post-processing failed' 를 빌드 실패로 읽지 말 것. 어느 단계가 실패했는지 봐야 한다.
- 1.0.15 버전 생성 → 빌드 33 첨부 → 한국어·베트남어 '업그레이드된 사항' 작성 → 심사에 추가 → 심사를 위해 제출.
- 출시 방식은 '자동으로 버전 출시' 로 되어 있다 (1.0.14 때 바꿔 둔 설정이 유지됨).
- 상태: 1.0.15 심사 대기 중. 최대 48시간.
- Apple Developer Program 사용권 계약 동의 완료 (2026-10-16, 사용자가 직접). 배너 사라졌고 무료 앱 계약도 갱신됐다.
  단, '유료 앱 계약' 은 새 버전이 따로 나와 있다 — 비즈니스 › 계약 › 약관 보기 및 동의하기.
  현재 계약이 2027-08-14 까지 활성 상태라 급하진 않지만, 수익 배분 계약이라 사용자가 직접 동의해야 한다.

## 2026-10-16 — #59 #60 #62 확인한 것

### Vercel (#62) — 메모 정정
- 이전 메모에 "Vercel 이 배포되든 말든 상관없어졌다"고 썼는데 정확하지 않다.
  massa-seven.vercel.app 은 **프록시 preview 배포**(dpl_B77SjUPU…, CLI 로 올림)에 붙어 있고,
  이게 app.massaviet.com 으로 넘겨주므로 **현재 앱이 정상 서빙된다** (지금 받기·신청 확인 문구로 확인).
- 다만 **git 자동배포는 죽어 있다.** 마지막 git 배포가 2026-09-21 이고, main 에 push 해도 새 배포가 안 뜬다.
  그래서 vercel.json 을 301 로 고쳐 push 해도 반영되지 않는다 — 배포를 따로 올려야 한다.
- ★ 내가 한때 "옛 앱(봇 포함)이 서빙되고 있다"고 잘못 판단했다. 'massa bot' 은 지금 앱에도 있는
  상담 탭 이름이고, 지워진 건 chatAutoReply 자동응답이다. 문자열만 보고 단정하지 말 것.
- 안드로이드 방문: 최근 30일 **0건** (ios 206 · web 88). Vercel 에 매달린 사용자는 없다.
- 사장님 결정: **301 리디렉트로 전환**. Vercel 로그인 필요.

### 네이버 서치어드바이저 (#59) — 자동화 불가 (재확인)
- searchadvisor.naver.com 은 브라우저 도구의 안전 제한으로 차단된다. 이전과 동일.

### 다음 검색등록 (#59) — 폼까지는 들어간다
- register.search.daum.net 접속 OK. https://massaviet.com 입력 → 신규등록 폼 통과.
- 막히는 지점: 다음/카카오 **로그인**과 [필수] 개인정보·서비스이용 **동의 체크** 두 개. 법적 동의라 사장님이 직접.

### 애드센스 (#60) — 보류 결정
- 사장님 결정: 보류. 이유 — 회사 소개형 10여 페이지라 저품질 반려 가능성이 크고,
  예약 0건인 지금 프리미엄 예약 서비스 사이트에 광고를 붙이면 신뢰도·전환에 역효과.

### Vercel git 연결이 안 되는 진짜 이유 (2026-10-16)
Vercel 계정 karmadc070-1667 의 '로그인 방법'에 붙은 **GitHub 신원은 박동춘-77 하나뿐**이다.
massa 저장소는 **karmadc070-droid** 소유라 Vercel 저장소 목록·검색에 아예 안 뜬다
("massa"를 검색한 결과, 박동춘-77 검색 결과가 없습니다).
GitHub 쪽은 문제없다 — Vercel 앱이 karmadc070-droid 에 '모든 저장소' 권한으로 설치돼 있다.
필요한 건 Vercel 에 karmadc070-droid 스코프를 **추가**하는 것뿐인데,
그 버튼을 누르면 뜨는 GitHub 인증 창을 다른 확장이 가로채서 브라우저 도구로는 못 끝낸다.

★ 판단: 여기에 더 매달릴 값어치가 없다. 301 전환의 유일한 이득은 Vercel 을 데이터 경로에서
빼는 것인데, 지금 프록시가 멀쩡히 돌고 안드로이드 사용자는 0명이다.
#62 를 **진짜로** 끝내려면 git 을 고칠 게 아니라 **Vercel 프로젝트를 삭제**하면 된다 (클릭 한 번, git 불필요).

### #62 종료 처리 (2026-10-16)
사장님 결정: '프록시로 충분' 으로 닫는다.
- vercel.json 을 301 로 고쳤던 것을 **프록시(dest)로 되돌렸다** — 어차피 배포가 안 되므로
  저장소 파일이 실제 배포본과 달라 다음 사람이 헷갈릴 이유를 없앴다.
- .vercelignore 머리말에 "이 파일을 고쳐도 배포되지 않는다"를 적어 뒀다.
- 남은 상태: 앱 = VPS, Vercel = 옛 주소용 프록시. 의존 사용자 0명.

## 2026-10-17 — #59 네이버·다음 검색 등록

### 네이버 서치어드바이저 — 완료
- 소유확인은 **사이트에 심어야** 통과한다. 두 방식 다 깔았다 (어느 쪽을 보든 통과하도록).
  · `site-src/build.py` 의 `verify` 에 `naver-site-verification` 메타 추가
    — **루트(ko/index)에만** 넣는다. 네이버는 거기만 본다. vi·en 에는 안 들어간다.
  · 확인 파일 `site/naver107fcbfe0e4530f07911cbc3e3f54337.html` 도 build.py 가 생성한다.
    내용은 **파일 이름(확장자 제외)** 이어야 한다.
- 사이트맵 제출칸은 도메인이 **안 붙어 있다**. 전체 URL 을 넣어야 한다
  (`sitemap.xml` 만 넣으면 "올바른 URL 형식으로 입력해주세요").
  ★ 내가 "도메인이 이미 붙어 있다"고 잘못 안내해서 사장님이 `http://sitemap.xml` 을
    사이트로 잘못 등록했다가 지웠다. 화면을 못 보는 안내는 단정하지 말 것.
- ★ searchadvisor.naver.com 은 브라우저 도구가 도메인째 차단한다. 로그인과 무관하다.
  앞으로도 네이버 콘솔 조작은 사장님 몫이다. 내가 할 수 있는 건 사이트에 파일·태그를 심는 것까지.

### 다음 검색등록 — 신청 제출
- 제목 massa 마싸 / URL https://massaviet.com / 지역 "베트남 전지역"
- 디렉토리: 생활,건강>패션,미용>피부관리 (목록에 '마사지'가 없다. 다음이 검토 때 바꿀 수 있다고 안내)
- 신청자: MOAPKJG · karmadc070@gmail.com
- 거절 사유에 "콘텐츠의 양이 충분치 못함" 이 명시돼 있다. 반려 가능성 있음 — 재신청 가능.
- 기술 메모 두 가지
  · 디렉토리 고르개는 `daum.popup()` 팝업이라 탭 그룹 밖으로 나간다. 같은 URL 을 새 탭으로 열어
    radio 값(`16455¶...`)을 보고 부모 폼의 `dir_seq`·`dir_path` 를 직접 채웠다.
  · 이 사이트는 CDP 클릭·JS 평가가 자주 timeout 난다. 입력은 JS 로, 최종 클릭은 사장님이 했다.
  · computer.type 이 한글을 깨뜨린다(홈뷰티→홈뻐티, 왁싱→왕싱). 한글은 네이티브 setter + input 이벤트로 넣을 것.

## 2026-10-18 — ★ 알림이 아무에게도 안 가고 있었다 (예약 0건의 직접 원인)

마사지사 알림 경로를 처음부터 끝까지 따라가 본 결과.

| 경로 | 상태 |
|---|---|
| 문자(SMS) | **아예 없다.** functions/·scripts/ 어디에도 SMS 발송 코드가 없다 |
| 아이폰 푸시 | 구현돼 있으나 **등록된 토큰 0건** |
| 안드로이드 푸시 | **구현 자체가 없다** |
| 앱 내 알림함 | 작동 (notifications 테이블) |

근거
- `push_tokens` 전체 **0행**. 마사지사 12명 중 누구도 기기 등록을 한 적이 없다.
- `notifications` 26행 전부 `pushed_at` 이 찍혀 있다. send-push 가 `claim_unpushed_notifications` 로
  **먼저 '보냄' 표시를 하고** 그 다음 토큰을 찾기 때문이다. 토큰이 없으면 조용히 아무 데도 안 가고
  기록만 '보냄'으로 남는다. → 대시보드·DB 만 보면 잘 나간 것처럼 보인다. 속으면 안 된다.
- index.html `setupPush()` 첫 줄: `if (!SESSION || !N || N.platform !== 'ios') return;`
  안드로이드는 `window.MassaNative` 자체가 없고(TWA), `sw.js` 에 `push` 이벤트 핸들러도 없다.

의미
- 손님이 신청해도 마사지사는 **앱을 직접 열어 보기 전까지 모른다.**
- 지난번 "마사지사들이 주문 온 줄 몰랐다"를 마사봇 탓으로만 정리했는데 그건 일부였다.
  근본 원인은 이것이다. 예약 0건과 직접 연결된다.

할 일 (우선순위 순)
1. 마사지사 알림은 **문자가 맞다.** 푸시는 앱 깔고 권한 준 사람에게만 가는데,
   현지 마사지사에게 그걸 기대할 수 없다. SMS 업체 계약이 전화 OTP(#84)와 같은 선행조건이다.
2. 안드로이드 푸시 — TWA 라 웹푸시(FCM + sw.js push 핸들러)를 붙여야 한다. 지금은 0.
3. send-push 가 '토큰 없음'을 성공으로 기록하지 않게 고칠 것. 안 보낸 건 안 보냈다고 남겨야 한다.

## 2026-10-18 — Glow 는 마사지사에게 '전화'를 건다 (문자도 푸시도 아니다)

Glow 공식 블로그에서 결정적인 문서를 찾았다.
「Hướng dẫn xác thực thuê bao di động (SIM chính chủ) dành cho kỹ thuật viên Glow」
(기술자용 SIM 본인명의 인증 안내 · v1 · 2026-08-05 시행 · Glow Vietnam 운영팀 발행)
https://glowvietnam.com/vi/blog/huong-dan-xac-thuc-thue-bao-di-dong-sim-chinh-chu-danh-cho-ky-thuat-vien-glow-64

원문 핵심:
  "기술자가 고객이 예약하거나 기술자를 선택했을 때 **알림 전화(cuộc gọi thông báo)** 를
   항상 받을 수 있도록, Glow 는 모든 기술자에게 본인명의 SIM 인증을 권장합니다."
목적으로 적힌 세 가지도 전부 통화 기준이다.
  · 주문 알림 **전화**를 정상적으로 받을 수 있게
  · 주문을 빨리 받을 가능성을 높이려고
  · 고객·Glow 시스템과 연락이 끊기지 않게
본인명의가 아닌 번호를 쓰는 기술자는 앱 지원센터로 연락해 번호를 바꾸라고 안내한다.

→ **Glow 의 1차 알림 수단은 전화다.** 문자가 아니다. 푸시도 아니다.
   전화는 앱을 안 깔아도, 화면이 꺼져 있어도, 권한을 안 줘도 닿는다. 놓치기가 어렵다.
   베트남은 미등록 SIM 규제·스팸 차단이 있어서 본인명의 인증까지 요구하는 것이다.

부수 확인
- Glow 는 고객용·기술자용이 **한 앱**이다 (Play 리뷰에 기술자가 직접 "both for technicians
  and customers" 라고 썼고 Glow 가 프로필·가용시간 안내로 답글을 달았다).
- 법인: Orderdi Joint Stock Company / Công ty Cổ Phần Công nghệ BK Việt Nam, 하노이 Trần Duy Hưng 170.
  Play 100K+ 다운로드, 4.7점 (리뷰 2.7K).
- Zalo OA 를 쓴다 (사이트에 zalo-platform-site-verification 메타 + Zalo·Messenger·WhatsApp 버튼).
  다만 **주문 알림에 Zalo ZNS 를 쓴다는 증거는 못 찾았다** — 추측하지 말 것.
- 이 문서가 2026-08 에 v1 로 나왔다는 건 Glow 도 알림 전달 문제를 겪고 손을 봤다는 뜻이다.

★ APK 디컴파일은 하지 않았다. 공개 자료(Play 등록정보·Data safety·공식 블로그)만 썼다.

massa 에 주는 결론
  알림 수단 우선순위를 **전화 > 문자 > 푸시** 로 본다. 지금 massa 는 푸시 하나뿐이고
  그나마 토큰 0건이라 사실상 아무것도 없다. 경쟁사가 전화까지 쓰는 이유가 분명하다.

## 2026-10-18 — 알림이 실제로 닿게 만들기 (계획)

### 왜 푸시인가
베트남 법인이 없다. 문자·음성은 브랜드네임 등록이 필요하고 승인에 2~6개월 걸리며
사업자등록증을 요구한다. **푸시(APNs·FCM)는 베트남 사업자가 필요 없고 무료다.**
법인이 없는 지금 massa 가 쓸 수 있는 유일한 자동 알림이다.

### 안드로이드를 어떻게 할 것인가 — Firebase 없이 간다
안드로이드 앱은 TWA(웹 껍데기)다. 네이티브 FCM SDK 를 넣을 수 없다.
대신 **표준 Web Push + VAPID** 를 쓴다. 브라우저가 주는 endpoint 로 그냥 POST 하면 되고
Firebase 콘솔도 프로젝트도 필요 없다. 키 한 쌍만 만들면 된다.

★ 페이로드는 **비워서** 보낸다. Web Push 본문 암호화(aes128gcm)를 구현하지 않기 위해서다.
  서비스워커가 빈 push 를 받으면 "새 신청이 들어왔습니다" 고정 문구로 알림을 띄우고,
  누르면 앱이 열린다. 마사지사에게 필요한 건 '뭔가 왔다'는 사실이지 본문이 아니다.
  암호화를 넣으려다 세 배 복잡해지는 것보다 이쪽이 낫다.

### 순서 (사장님 승인받은 순서)
1. 안드로이드 웹푸시 추가 (VAPID + sw.js) → 검증: 안드로이드 기기에 알림 도착
2. iOS 푸시 토큰 등록 점검           → 검증: 사장님 폰 토큰이 push_tokens 에 생김
3. '토큰 없음'을 성공으로 기록하는 버그 수정 → 검증: 토큰 없으면 미발송으로 남음
4. 채팅 연락처 차단 (서버에서 번호 패턴 거부) → 검증: 번호 넣은 메시지 거부
5. 주소는 수락 후에만 노출            → 검증: requested 상태에서 주소 안 보임

### 유출(이탈) 관련 현황 — 확인한 사실
- `profiles` RLS 는 self + admin 만 SELECT. **마사지사는 손님 이름·전화를 못 읽는다.**
- `bookings` 에 전화번호 칼럼 자체가 없다. 파트너 화면은 주소·호실·시간만 보여준다.
- 남은 누수는 두 개뿐: ① 채팅 본문에 번호를 적는 것 ② 현장 대면. ①만 막을 수 있다 (4번 항목).
- 앱 내 채팅은 **이미 있다** (마사지사 선발신 강제). 새로 만들 필요 없다.

### 진행 결과 (2026-10-18)
- N1 안드로이드 웹푸시: sw.js push/notificationclick 핸들러 + index.html setupWebPush() +
  send-push 에 sendWebPush() 추가. VAPID 키를 .env 와 docker-compose(functions) 에 넣고 재기동.
  배포본 확인: app.massaviet.com/sw.js 에 push 핸들러 있음, 컨테이너에 VAPID 3개 들어감.
- N3 '안 보냈는데 보냄' 버그: notifications.push_result 추가. 받을 기기가 없으면 'no_device' 로 남긴다.
  검증: 테스트 알림 1건 → push_result='no_device'. 예전처럼 조용히 '발송'으로 남지 않는다.
- N4 채팅 연락처 차단: guard_no_contact_in_message 트리거. 12가지 문장으로 검증 12/12 통과
  (번호·zalo·wa.me 는 차단, 가격 300.000 VND·시간 14:30·호실 1203 은 통과).
  ★ 숫자만 뽑아 붙이는 방식은 버렸다 — 무관한 숫자가 이어 붙어 멀쩡한 대화를 막는다.
- N5 주소 수락 후 노출: **화면만 고쳤다. 아직 진짜 막은 게 아니다.**
  `bookings_provider_read` RLS 가 행 전체를 허용해서 REST 로 주소를 그냥 읽을 수 있다.
  제대로 막으려면 마스킹하는 SECURITY DEFINER 읽기 경로로 바꾸고 직접 SELECT 를 걷어내야 한다.
  ★ 화면에만 둔 규칙은 규칙이 아니다 — 이번 세션에서 이미 두 번 겪었다. 미완으로 남긴다.

### 함정 두 개 (다음에 또 걸린다)
1. PowerShell 에서 SQL 을 base64 로 넘기면 `$fn$` 달러 인용이 깨진다. 함수 본문이 통째로
   SQL 로 파싱돼 "syntax error at or near if" 가 난다. **SQL 파일은 scp 로 올릴 것.**
2. PowerShell here-string `@"..."@` 는 `$` 를 확장한다. 정규식의 `$` 가 사라져 테스트가
   거짓 통과했다. 변수 확장이 필요 없으면 `@'...'@` 를 쓸 것.

## 2026-10-18 — 알림 소리·배너, 그리고 '알림 강제'

### 웹푸시 검증 완료 (폰에 실제로 떴다)
구독 → FCM → 전송 → push_result='sent' → 폰 알림 표시까지 전 구간 확인.
가는 길에 잡은 버그 두 개
  · `push_tokens` 의 `CHECK (platform = 'ios')` 가 web 토큰을 거부. ('ios','web') 으로 고침.
  · 앱이 그 오류를 `.then(ok, fail)` 로 삼켜서 화면에 아무 표시가 없었다.
    → '구독은 됐는데 토큰 0건'이면 앱이 아니라 저장 쪽을 먼저 본다.

### 소리·헤드업 배너는 웹푸시로 불가능 (확인함)
안드로이드는 **알림 채널**이 소리·중요도를 정하고, 크롬은 origin 마다 채널을 하나 만든다.
웹페이지는 그 채널의 중요도를 바꿀 수 없고, 채널은 한 번 생기면 중요도가 고정된다.
웹에서 되는 건 `vibrate` 뿐 — 넣었다.
→ 소리 + 헤드업을 코드로 지정하려면 **네이티브 앱**이어야 한다. 지금 안드로이드는 TWA 다.

### ★ '알림 허용 강제'는 OS 차원에서 불가능하다
안드로이드 13+ / iOS 모두 런타임 권한이고 사용자가 거부할 수 있다. 우회 수단은 없다.
대신 **제품 규칙으로 강제**한다 — 효과는 같다.
  · 알림이 꺼진 마사지사는 **영업 ON 으로 바꿀 수 없다**
  · 따라서 손님 목록에도 안 뜬다 → 주문을 받으려면 알림을 켤 수밖에 없다
  ★ 반드시 **서버에서** 막는다. KYC 잠금(guard_provider_kyc)과 같은 방식.

### N8·N9 완료 (2026-10-18)
- N8 서버 잠금: `guard_provider_push` — 등록된 기기가 없으면 is_active 를 켤 수 없다.
  끄는 것은 항상 허용한다(이미 켜진 사람을 가두면 빠져나올 길이 없다).
  시험: 끄기 통과 / 켜기 거부 확인.
  ★ 기존 12명은 전원 is_active=true 인데 토큰 0건이다. 소급 적용은 안 되지만
    **한 번 끄면 알림을 켜기 전까지 다시 못 켠다.** 그래서 12명에게 미리 안내를 보냈다(N11).
- N9 권한 요청을 버튼으로: 로드 중 `requestPermission()` 은 크롬이 막는다(사용자 조작 없음).
  실제로 그래서 권한 창이 안 떴고 토큰이 0건이었다.
  이제 · 이미 허용 → 조용히 구독 갱신 · 아직이면 → 하단 배너, 버튼 누를 때 요청.
  거부 상태면 자물쇠 아이콘으로 바꾸라고 안내한다.

## 2026-10-18 — 안드로이드 네이티브 전환 (N10) 작업분

TWA → Capacitor 네이티브. **이유는 하나뿐이다** — 웹푸시는 소리·헤드업 배너를 못 낸다.
안드로이드는 알림 채널이 그걸 정하는데 웹페이지가 채널 중요도를 건드릴 수 없다.

### 한 것
- `capacitor/package.json` 에 `@capacitor/android` 추가
- `native.js registerPush()` 에 **채널 생성** 추가 — id `massa_booking`, importance 5(긴급),
  visibility 1, vibration. 안드로이드일 때만 만든다.
  ★ 채널은 한 번 만들어지면 설정이 고정된다. 바꾸려면 id 를 올려야 한다 (massa_booking_v2 …).
- `index.html setupPush()` — 네이티브면 platform(ios/android)을 그대로 쓰고, 아니면 웹푸시.
- `push_tokens` 제약에 'android' 추가 (ios·web·android).
- `send-push` 에 **FCM HTTP v1** 발송 추가. 레거시 서버키는 폐지돼서 **서비스 계정으로
  OAuth2 토큰**을 받아야 한다 (RS256 JWT → oauth2.googleapis.com/token, 50분 캐시).
  메시지에 `android.notification.channel_id = massa_booking` 을 실어야 그 채널이 쓰인다.
- `codemagic.yaml` 에 `android-play` 워크플로 추가. versionCode 는 100+빌드번호
  (기존 TWA 가 3이라 충돌 없음).

### 함정 (또 걸린다)
★ codemagic.yaml 안에 파이썬을 인라인으로 넣지 말 것. 여러 줄 문자열의 들여쓰기가
  YAML 블록 스칼라를 끊어서 파일 전체가 깨진다. → `scripts/android-gradle-patch.py` 로 뺐다.

### 남은 것 (사장님 입력 필요)
1. **FCM 서비스 계정 키** — Firebase 콘솔 → 프로젝트 설정 → 서비스 계정 →
   '새 비공개 키 생성' → JSON. 이걸 VPS `.env` 의 `FCM_SERVICE_ACCOUNT` 에 한 줄로 넣어야
   안드로이드로 푸시가 나간다. (docker-compose·함수는 이미 준비됨)
2. **Codemagic 환경변수 그룹 `android_signing`** — KEYSTORE_PASSWORD · KEY_ALIAS · KEY_PASSWORD
   (값은 android-package/signing-key-info.txt 에 있다)

### 메모 정정
서명키가 공개 저장소에 올라가 있다고 경고했는데 **틀렸다**. `.gitignore` 에 이미
`android-package/` · `*.keystore` · `signing-key-info.txt` 가 있고 git 추적 대상이 아니다.
로컬 폴더에 파일이 보인다고 저장소에 있다고 단정했다. `git ls-files` 로 먼저 확인할 것.
Play 앱 서명은 켜져 있다(진짜 키는 구글 보관, 로컬은 업로드 키).

### FCM 서버 연동 완료 (2026-10-18)
- 서비스 계정 키를 VPS `.env` 의 `FCM_SERVICE_ACCOUNT` 에 **한 줄 JSON**으로 넣었다.
  저장소에는 없다 — `.gitignore` 에 `*firebase-adminsdk*.json` 추가함.
- ★ 함정: PowerShell `Set-Content -Encoding UTF8` 이 **BOM** 을 붙인다. .env 에 그대로 들어가
  JSON.parse 가 깨진다. 서버에서 `FCM_SERVICE_ACCOUNT='\xef\xbb\xbf` 를 잘라냈다.
  다음엔 `-Encoding utf8NoBOM` 을 쓰거나 서버에서 거를 것.
- 검증: 가짜 토큰으로 실제 FCM 엔드포인트 호출 →
  OAuth 토큰 발급 성공, FCM 이 400 INVALID_ARGUMENT("not a valid FCM registration token").
  **인증·권한·프로젝트 연결 정상.** 진짜 기기 토큰만 있으면 바로 간다.
- 참고: `push_tokens.token` 에 형식 검사(check)가 있어서 아무 문자열이나 못 넣는다.
  가짜 토큰으로 end-to-end 시험이 안 되니, FCM 경로는 위처럼 직접 호출로 확인할 것.

## 2026-10-18 안드로이드 서명 — 저장소에 없는 키스토어를 가리키고 있었다
- `codemagic.yaml` 의 android-play 가 `$CM_BUILD_DIR/android-package/signing.keystore` 를 참조했는데
  `android-package/` 는 `.gitignore:9` 로 통째로 제외돼 있다. CI 체크아웃에는 그 파일이 없다.
  빌드를 돌렸으면 gradle 서명 단계에서 죽었을 것이다. 돌리기 전에 발견했다.
- 고친 방법 — Codemagic 의 Code signing identities(Android keystores)에 키스토어를 올리고
  `environment.android_signing: [massa_upload_key]` 로 참조한다.
  Codemagic 이 CM_KEYSTORE_PATH · CM_KEYSTORE_PASSWORD · CM_KEY_ALIAS · CM_KEY_PASSWORD 를 넣어 준다.
  환경변수 그룹 `android_signing` 은 필요 없어졌다 (만들지 말 것).
- 교훈 — 빌드 스크립트가 참조하는 경로는 `git ls-files` / `git check-ignore` 로 실재를 확인한다.
  로컬에 파일이 있다는 것은 CI 에 있다는 뜻이 아니다. (저장소 공개/비공개 오판과 같은 뿌리의 실수다.)

## 2026-10-18 저장소 비공개 전환 → Codemagic 접근 끊김 → 공개로 복귀
- 비공개로 바꾼 순간 `git ls-remote` 가 "Invalid username or token" 으로 실패했다.
  연결 방식이 GitHub 연동이 아니라 **Other**(인증 없는 공개 URL)였기 때문이다.
- Codemagic 에 연결된 GitHub 계정은 parkdongchun-77, 저장소 주인은 karmadc070-droid 로 서로 달라
  저장소 목록이 비어 있었다. GitHub 연동으로 갈아타려면 계정 정리가 필요하다.
- 애초에 비공개로 바꾼 이유(내가 "서명 키가 공개 저장소에 있다"고 한 것)는 오판이었다.
  keystore · FCM 키 · .env 모두 추적된 적 없다. 사용자 판단으로 공개로 되돌렸다.

## 2026-10-18 안드로이드 빌드를 macOS 로 옮기면서 생긴 함정 세 가지
1. `linux_x2` 는 현재 Codemagic 요금제에서 막혀 있다 → `mac_mini_m2` 로 바꿨다 (iOS 가 이미 쓰고 있어 검증됨).
2. **`sed -i` 를 macOS 에서 쓰면 안 된다.** BSD sed 는 `-i` 뒤에 백업 확장자를 요구해서
   치환식이 확장자로, 파일명이 스크립트로 해석된다. 실제 오류는 `sed: ww/index.html: No such file or directory`
   (`www` 의 첫 `w` 가 sed 의 쓰기 명령으로 먹혔다). → `perl -pi -e` 로 교체. 리눅스·macOS 둘 다 돈다.
   세 군데였다 (index.html 주입 1, versionCode·versionName 2). 하나만 고쳤으면 다음 단계에서 또 죽었다.
3. artifact 경로는 **working_directory 기준**이다. `capacitor/android/...` 로 적었더니 하나도 안 잡혔다.
   → `android/app/build/outputs/**/*.aab|apk`.

그리고 AAB 는 폰에 직접 설치할 수 없다. 소리·배너를 실제로 확인하려면 APK 가 필요해서
`bundleRelease assembleRelease` 로 둘 다 만든다.

주의 — 이 APK 는 업로드 키로 서명돼 있고, Play 에서 받은 기존 앱은 구글 키로 서명돼 있다.
패키지(app.massa.hanoi)가 같아서 **기존 앱을 지우고 설치해야 한다** (서명 불일치로 덮어쓰기 거부).

## 2026-10-18 server.url 로 '웹 즉시 반영'을 유지하려던 안 — 폐기
한 번 권장했다가 확인 후 철회했다. 근거 두 가지.
- Capacitor 공식 설정 문서: `server.url` = "External URL for the Web View (**live-reload; not for production**)".
- `android` 플랫폼별 override 표에 `server` 키가 **없다**. 안드로이드만 따로 못 준다 →
  설정하면 이미 심사 통과한 iOS 에도 적용된다.
- 덧붙여 원격 URL 만 띄우는 껍데기는 Play '최소 기능/웹뷰 래퍼' 정책의 전형적 사례다.
  TWA 는 구글이 공식 허용하는 형식이라 괜찮았지만 Capacitor 껍데기는 그 보호를 못 받는다.
교훈 — 설정 옵션을 권장하기 전에 공식 레퍼런스에서 (1) 운영 지원 여부 (2) 적용 범위를 먼저 본다.

## 2026-10-18 안드로이드 1.1.101 프로덕션 제출
- 내장 www 방식으로 확정. 이제 **웹만 고쳐서는 안드로이드에 반영되지 않는다** — iOS 와 같은 리듬이 됐다.
  앞으로 index.html 등을 고치면 android-play 빌드·출시를 같이 돌려야 한다.
- Play 기존 최고 versionCode 는 3 이었다. 새 빌드는 101 (CM_BUILD_NUMBER 기반 100+1).
- 검토 경고 2개는 선택 사항(난독화 매핑 파일·디버그 심볼 없음). 오류 없음. 지원 기기 변동 없음.
- 기존 TWA 사용자는 Play 업데이트로 자동 교체된다 (Play 앱 서명 키가 같으므로 서명 문제 없음).
  단 **Codemagic 이 만든 APK 를 직접 설치할 때는** 업로드 키 서명이라 기존 앱을 지워야 한다.

## 2026-10-18 ★ 마사지사 12명 중 알림 켠 사람 0명 — 진짜 원인은 번역 누락이었다
증상 — 승인 마사지사 12명, push_tokens 보유 0명(사장님 테스트 계정 2개만), 예약 0건.
앱 내 안내 12건은 전부 `push_result=no_device`, `is_read=0`. "알림을 켜라"를 알림으로 보낸 순환 실패.

**직접 원인** — `showPushBanner()` 의 두 문구가 DICT 에 없었다.
  '알림을 켜야 새 신청을 받을 수 있습니다.' / '알림 켜기'
`trOne` 은 사전에 없으면 한국어를 그대로 돌려준다(`if (!e) return ko`).
→ 베트남 마사지사들은 화면 아래에 **읽을 수 없는 한국어 띠**를 봤다. 안 켠 게 아니라 뭔지 몰랐다.
교훈 — 동적으로 만드는 문자열은 DICT 등록을 같이 해야 한다. 파일 내 등장 횟수 1회 = 사전 미등록 신호.

**고친 것**
- DICT 에 알림 관련 6개 문구 추가 (vi·en·zh·ja). 실제로 trOne 돌려 6/6 번역 확인.
- 마사지사(`application_status='approved'`)에게는 얇은 띠 대신 **전체 화면**으로 막는다 (`showPushGate`).
  권한이 'denied' 면 앱 안에서 되돌릴 수 없으므로 안내 + 닫기만 준다 — 안 그러면 앱을 못 쓴다.
- 네이티브에서 거절한 경우에도 같은 화면의 denied 모드를 띄운다.
- 배포본(app.massaviet.com)에서 베트남어 문구·pushGate·isApprovedProvider 존재 확인.

**타이밍이 유리했다** — 안드로이드는 아직 TWA(웹 로드)라 스토어 출시 없이 즉시 반영됐다.
네이티브(1.1.101)가 배포되면 이 경로가 사라지므로, 앞으로 웹 수정은 android-play 빌드도 같이 돌려야 한다.

**부수 수정**
- auth.users / auth.identities 의 `@gmail.con` → `@gmail.com` (Mins). 메일 정상 도착으로 오타 확정.
- 이메일 11건 발송 (Resend, massa@moahagwon.com) → 10 delivered / 1 sent, 반송 0.

## 2026-10-18 배포 스크립트가 저장소 이름 변경으로 깨졌다
`vps-deploy-app.sh` 가 `$TMP/massa-main` 을 박아 두고 있었는데 저장소가 karmadc070-droid-massa 로
바뀌어 압축 안 폴더명도 바뀌었다. → `find -maxdepth 1 -type d | head -1` 로 찾아 쓰도록 수정.
그리고 **PowerShell 파이프로 셸 스크립트를 보내면 한글이 깨져** 문법 오류가 난다(따옴표가 깨진다).
반드시 scp 로 파일 그대로 보낸다 — .sql 때와 같은 함정이다.

## 2026-10-18 수락할 때까지 반복해서 울리기 (30초 간격 · 최대 10회)
사장님이 실제 테스트에서 "소리가 한 번만 난다 — 못 들으면 놓친다"를 짚어 주셔서 만든 것.

구조 — sw.js 가 이미 `tag:'massa-booking'` + `renotify:true` 라서
같은 알림을 다시 보내면 **쌓이지 않고 덮어쓰면서 소리를 다시 낸다.** 서버가 반복만 하면 된다.
- `notifications` 에 `push_tries`, `next_push_at` 추가.
- `claim_unpushed_notifications()` 가 (a) 미발송 + (b) 반복 차례가 된 booking_new 를 함께 집는다.
- 멈춤: is_read=true / 예약이 requested 를 벗어남 / 10회 / 생성 후 10분. booking_new 만 반복한다.
- 크론 최소 주기가 1분이라 massa_push.sh 가 `call; sleep 30; call` 로 30초 간격을 만든다.
검증 — tries 1→4 증가 확인, 읽음 처리 후 멈춤 확인. 둘 다 눈으로 봤다.

### ★ 오늘 같은 뿌리로 세 번 깨졌다 — PowerShell 로 셸 명령을 보내지 말 것
1. heredoc 으로 보냈더니 `$(...)`·`$S` 가 **로컬에서 전개**돼 스크립트가 깨지고
   NOTIFY_SECRET 이 파일에 박히고 작업 화면에 노출됐다 → 시크릿 회전함.
2. `tr -d "\r"` 로 CR 을 지우려 했는데 PowerShell 이 `\r` 을 **`r`** 로 넘겨
   알파벳 r 이 전부 지워졌다 (grep→gep, curl→cul, /root→/oot, /var→/va).
   크론은 돌지만 스크립트가 종료코드 1 로 죽어 푸시가 멈췄다.
3. 그 검증으로 `grep -c NOTIFY_SECRET` 과 `sleep 30` 을 썼는데 **둘 다 r 이 없어서** 통과해 버렸다.
   → 검증 문자열은 깨질 수 있는 문자를 포함해야 한다. scp 로 보내고 파일로 검증한다.

### 시크릿 회전에서 또 하나
`docker compose restart` 로는 .env 가 다시 읽히지 않는다. `up -d --force-recreate` 여야 한다.
그리고 "틀린 시크릿으로 401" 은 검증이 아니다 — 옛 값이든 새 값이든 틀리면 401 이라 구분이 안 된다.
**올바른 검증은 '.env 의 현재 값으로 호출했을 때 200'** 이다.

### PostgREST 스키마 캐시
테이블에 컬럼을 추가하면 rest 컨테이너가 모른다. `scripts/vps-reload-schema.sh` 를 돌려야
RPC 가 새 컬럼을 포함해 동작한다. 함수는 psql 로는 되는데 API 로는 안 되면 이걸 의심한다.

## 2026-10-18 기기가 생길 때까지 기다리는 알림
문제 — 마사지사 11명이 기기 0대라 지금 공지를 보내면 전부 `no_device` 로 영구 실패한다.
아침에 보낸 안내 12건이 실제로 그렇게 사라졌다.
해법 — `claim_unpushed_notifications()` 에 (c) 분기 추가.
  notice·info·approved 는 기기가 없으면 next_push_at 을 10분 뒤로 잡고, 기기가 생기면 그때 전달한다 (3일까지).
검증 (실제로 돌려 확인)
  A) 기기 있는 계정 → 한 번 전달, next_push_at null (대기 안 함) ✓
  B) (c) 분기 → 대기 시각 지나고 기기 있으면 집힘 ✓
  C) booking_new + 기기 없음 → **대기한다**. 처음엔 안 기다리게 하려 했는데 그대로 뒀다.
     예약 받은 직후 앱을 열어 알림을 켜면 5분 안에 그 예약이 도착하므로 오히려 낫다.
     주석을 실제 동작에 맞게 고쳤다 (코드와 설명이 어긋나면 다음 사람이 속는다).

함정 — `push_tokens.token` 에 `length >= 32` CHECK 가 있다. 가짜 토큰으로 테스트하려다 막혔다.
검증은 기기를 가진 실제 계정으로 해야 한다.

## 2026-10-18 어드민 글자 크기
본문 14.5→16px, 표 13→14.5px 등 읽는 면만 키웠다 (레이아웃 수치는 안 건드림).
좌측 '지표' 라벨은 일반 뱃지(.tag)의 테두리를 물려받는데 `padding:0 10px 22px` 가 겹쳐
속이 빈 큰 칸처럼 보였다. 15px + 글자에 맞는 여백으로 고쳤다.

## 2026-10-18 ★ 웹푸시가 모든 알림에 '새 신청이 들어왔습니다' 를 띄우고 있었다
사장님이 "환영 푸시가 안 왔다"고 해서 A/B 로 확인하다 두 가지가 같이 드러났다.

1) **tag 충돌** — 모든 알림이 `tag:'massa-booking'` 하나를 쓴다. 공지를 보내면 직전 예약 알림을
   덮어쓴다. A/B 에서 notice·booking_new 를 6초 간격으로 보냈더니 폰에 하나만 떴다.
2) **더 심각 — 문구가 거짓이었다.** 웹푸시는 본문을 안 싣기 때문에 sw.js 가 고정 문구를 띄우는데
   그게 'Có yêu cầu mới'(새 신청이 들어왔습니다) 였다. 환영 공지를 보내도 그렇게 떠서
   마사지사가 앱을 열면 예약이 없다. 11명에게 그대로 보냈으면 거짓 안내가 될 뻔했다.

조치 — 문구를 종류 중립으로 바꿨다: 'Bạn có thông báo mới — hãy mở ứng dụng để xem.'
(새 알림이 있습니다 — 앱에서 확인하세요). CACHE 를 massa-v3 로 올려야 새 워커가 적용된다.

하지 않기로 한 것 — 본문 암호화(RFC 8291). 구현하면 실제 문구와 종류별 tag 가 되지만,
1.1.101 네이티브가 며칠 뒤면 나오고 거기서는 본문이 그대로 실린다. 곧 안 쓸 경로에
동작 중인 발송기를 수정하는 건 수지가 안 맞는다고 판단했다. 네이티브 이후 재검토.

교훈 — 알림 문구는 '모든 종류에 대해 사실'이어야 한다. 한 종류를 기준으로 쓰면 나머지가 거짓말이 된다.

## 2026-10-18 iOS 점검 — 반복 발송이 아이폰에 알림을 쌓을 뻔했다
사장님이 "iOS 는 동일하게 적용됐나" 물어서 확인하다 발견.

반영됨 (서버라 플랫폼 무관) — 30초 반복 / 기기 대기 / 본문 전달(APNs 는 원래 본문을 싣는다)
반영 안 됨 (앱에 번들돼 있어 새 빌드 필요) — 베트남어 번역, 마사지사 전체 화면 잠금
  iOS 는 server.url 이 없어 index.html 을 빌드 시점에 앱 안에 넣는다. 웹 배포로는 안 바뀐다.

★ 놓쳤던 것 — `sendApns` 에 `apns-collapse-id` 가 없었다. 안드로이드 웹푸시는 `tag` 로
  한 줄을 덮어쓰는데 iOS 는 그 장치가 없어서, 30초×10회 반복이 **알림 10개로 쌓일** 상황이었다.
  FCM(안드로이드 네이티브)에도 `tag` 가 없어 같은 문제가 있었다. 둘 다 추가했다.
  collapse 키 — 예약은 `b-<booking_id>`, 그 외는 `k-<kind>` (APNs 는 64바이트 제한).
  교훈: 한 플랫폼에 기능을 넣으면 나머지 두 경로(APNs·FCM·WebPush)를 같이 본다.

### ★ Edge Function 의 실제 경로
`/root/massa/functions/` 가 아니라 **`/root/massa/volumes/functions/`** 다.
잘못된 경로에 scp 하고 "배포했다"고 넘어갈 뻔했다. 검증 스크립트가 파일을 못 찾아 드러났다.
배포 후에는 반드시 서버의 실제 파일에서 grep 으로 확인한다.

### 테스트 찌꺼기
ABTEST-BOOKING 을 안 지워서 크론이 매분 반복 발송하고 있었다(사장님 폰이 계속 울렸을 것).
테스트 알림은 만든 즉시 삭제까지 스크립트에 넣는다.

### 마사지 종류별 페이지 (2026-10-19)
모아학원처럼 검색에 걸릴 실제 공개 페이지를 늘리려고 종류별 소개 페이지를 만들었다. 문구는 site-src/massage_content.py, 어느 종류·몇 분 코스가 있는지는 **빌드할 때 DB(services, is_active, category=massage)에서** 읽는다.
그래서 build.py 는 이제 인터넷(api.massaviet.com)이 되는 곳에서 돌려야 하고, 못 읽으면 일부러 멈춘다(종류 페이지 없이 배포되는 것을 막으려고). 가격은 테라피스트마다 달라 페이지에 넣지 않았다 — 금액이 바뀌어도 페이지가 틀려지지 않는다.
VIBI·KBizV 처럼 VPS cron 으로 돌리지 않은 이유: 이 사이트는 GitHub → vps-deploy-massaviet.sh 가 docroot 를 통째로 갈아 끼우는 구조라, VPS 에서 따로 쓰는 파일은 다음 배포 때 지워진다. 종류·시간은 거의 안 바뀌므로 바뀌면 build.py 를 다시 돌리고 배포한다.
테라피스트 개인 페이지와 지역 페이지는 만들지 않았다(checklist 참고).
