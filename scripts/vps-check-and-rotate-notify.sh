#!/bin/sh
# NOTIFY_SECRET 회전 + 발송기 정상 동작 확인 (2026-10-18)
#
# 왜 — 시크릿이 작업 화면에 노출됐다. 값이 보인 이상 바꾸는 게 맞다.
# PowerShell 로 셸 명령을 직접 보내면 $ 와 따옴표가 깨진다. 이 파일을 scp 로 보내 실행한다.
set -e

ENV=/root/massa/.env
echo '=== 1. 현재 상태 ==='
printf '  시크릿 길이: '; grep -E '^NOTIFY_SECRET=' "$ENV" | cut -d= -f2- | tr -d '\n' | wc -c

echo '=== 2. 새 시크릿 생성 ==='
NEW=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
[ ${#NEW} -eq 48 ] || { echo "★ 생성 실패 (길이 ${#NEW})"; exit 1; }

cp "$ENV" "$ENV.bak.$(date +%s)"
if grep -qE '^NOTIFY_SECRET=' "$ENV"; then
  sed -i "s|^NOTIFY_SECRET=.*|NOTIFY_SECRET=$NEW|" "$ENV"
else
  echo "NOTIFY_SECRET=$NEW" >> "$ENV"
fi
echo '  .env 교체 완료'

echo '=== 3. 함수 재기동 (새 시크릿 반영) ==='
cd /root/massa && docker compose restart functions >/dev/null 2>&1 || docker restart massa-functions >/dev/null 2>&1
sleep 8

echo '=== 4. 옛 시크릿은 거부되는가 (401 이어야 정상) ==='
printf '  '
curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H 'x-notify-secret: OLD-SECRET-SHOULD-FAIL' -d '{}'

echo '=== 5. 발송기가 새 시크릿으로 도는가 ==='
bash /root/massa_push.sh && echo '  massa_push.sh 실행 OK'

echo '=== 6. 크론 확인 ==='
crontab -l | grep massa_push.sh | sed 's/^/  /'

echo '=== ROTATE DONE ==='
