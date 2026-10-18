#!/bin/sh
# 함수 컨테이너가 새 NOTIFY_SECRET 을 읽게 다시 만든다 + 제대로 검증한다 (2026-10-18)
#
# 앞선 실수 — restart 만 했더니 .env 가 다시 읽히지 않아 401 이 났다.
# 그리고 '가짜 시크릿으로 401' 을 성공 신호로 본 것은 잘못된 검증이다.
# 옛 시크릿이든 새 시크릿이든 틀리면 401 이라 아무것도 구분하지 못한다.
# 올바른 검증은 '.env 의 현재 시크릿으로 호출했을 때 401 이 아닐 것'이다.
set -e
cd /root/massa

echo '=== 1. functions 컨테이너 재생성 (.env 다시 읽기) ==='
docker compose up -d --force-recreate functions 2>&1 | tail -3
sleep 10

echo '=== 2. 컨테이너가 들고 있는 시크릿 길이 (값은 안 찍는다) ==='
printf '  컨테이너: '
docker compose exec -T functions printenv NOTIFY_SECRET 2>/dev/null | tr -d '\n' | wc -c
printf '  .env    : '
grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2- | tr -d '\n' | wc -c

echo '=== 3. ★ 진짜 검증 — 현재 시크릿으로 호출하면 401 이 아니어야 한다 ==='
S=$(grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2-)
CODE=$(curl -s -o /tmp/pushout.txt -w '%{http_code}' -m 25 -X POST \
  http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}')
echo "  HTTP $CODE"
echo "  응답: $(cat /tmp/pushout.txt)"
[ "$CODE" = "200" ] || { echo '★ 아직 인증 실패 — 중단'; exit 1; }

echo '=== 4. 틀린 시크릿은 거부되는가 (401 이어야 한다) ==='
printf '  '
curl -s -o /dev/null -w '%{http_code}\n' -m 10 -X POST \
  http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H 'x-notify-secret: WRONG' -d '{}'

echo '=== FIX DONE ==='
