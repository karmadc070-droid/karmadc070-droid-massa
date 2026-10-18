#!/bin/sh
# send-push 재배포 확인 + collapse 설정이 실제 코드에 들어갔는지 본다 (2026-10-18)
set -e
F=/root/massa/functions/send-push/index.ts

echo '=== 1. 배포된 코드에 collapse 가 있는가 (전부 1 이상) ==='
for s in 'apns-collapse-id' 'const collapseId' 'tag: (bookingId'; do
  printf '  %-22s ' "$s"; grep -c -- "$s" "$F" || true
done

echo '=== 2. 함수가 살아 있는가 — 현재 시크릿으로 200 이어야 한다 ==='
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
CODE=$(curl -s -o /tmp/o.txt -w '%{http_code}' -m 25 -X POST \
  http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}')
echo "  HTTP $CODE"
echo "  응답: $(cat /tmp/o.txt)"
[ "$CODE" = "200" ] || { echo '★ 함수가 응답하지 않는다 — 중단'; exit 1; }

echo '=== 3. 반복 발송이 여전히 도는가 (크론 로그 꼬리) ==='
tail -2 /var/log/massa_push.log | sed 's/^/  /'

echo '=== VERIFY DONE ==='
