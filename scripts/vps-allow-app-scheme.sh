#!/bin/sh
# 구글 로그인이 앱으로 돌아오게 한다 (2026-10-19).
#
# 증상: 앱에서 구글 로그인 → 외부 브라우저 → 로그인은 되는데 앱이 아니라 웹에 세션이 생긴다.
#       앱은 세션을 못 받으니 네이티브 푸시 토큰을 영영 등록하지 못한다. 알림음이 안 난 진짜 이유.
# 원인: 앱은 redirectTo=massa://auth 로 보내는데 GoTrue 허용 목록에 massa:// 가 없다.
#       허용되지 않은 주소면 GoTrue 는 SITE_URL(app.massaviet.com) 로 되돌린다.
# 조치: 허용 목록에 massa://** 를 더한다. 앱 전용 스킴이라 외부에서 가로챌 수 없다.
set -e
ENV=/root/massa/.env

echo '=== 1. 지금 값 ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV"

if grep -q 'massa://' "$ENV"; then
  echo '  이미 들어 있다 — 건드리지 않는다'
else
  cp "$ENV" "$ENV.bak.$(date +%s)"
  sed -i 's|^ADDITIONAL_REDIRECT_URLS=\(.*\)$|ADDITIONAL_REDIRECT_URLS=\1,massa://**,massa://auth|' "$ENV"
  echo '  massa://** 추가함'
fi

echo '=== 2. 바뀐 값 ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV"

echo '=== 3. auth 컨테이너 다시 올리기 ==='
cd /root/massa
docker compose up -d auth 2>&1 | tail -3
sleep 6
docker compose ps auth 2>&1 | tail -2

echo '=== 4. 컨테이너가 새 값을 들고 있나 ==='
docker compose exec -T auth sh -c 'echo "$GOTRUE_URI_ALLOW_LIST"' 2>&1 | tr ',' '\n' | grep -i massa:// || echo '  ★ 컨테이너에 반영 안 됨'

echo '=== 5. 인증 서비스가 살아 있나 ==='
curl -s -o /dev/null -w '  /auth/v1/settings -> %{http_code}\n' https://app.massaviet.com/auth/v1/settings
echo '=== DONE ==='
