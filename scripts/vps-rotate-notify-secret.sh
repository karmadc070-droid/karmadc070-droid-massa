#!/bin/sh
# 알림 함수의 공유 시크릿을 새로 발급한다. 진단 중 옛 값이 작업 로그에 찍혀서 교체한다.
# 값은 어디에도 출력하지 않는다. 길이만 보여 준다.
set -e
ENV=/root/massa/.env
NEW=$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')
OLD=$(grep -E '^NOTIFY_SECRET=' "$ENV" | cut -d= -f2-)   # 5단계 401 확인용. 파일에 값을 적지 않는다.

echo "=== 1. .env 교체 ==="
sed -i '/^NOTIFY_SECRET=/d' "$ENV"
echo "NOTIFY_SECRET=$NEW" >> "$ENV"
chmod 600 "$ENV"
echo "  새 시크릿 기록 (${#NEW}자)"

echo "=== 2. DB 설정 교체 (트리거가 쓰는 값) ==="
docker exec massa-db psql -U postgres -d postgres -q -c \
  "update public.app_settings
      set value = jsonb_set(value, '{secret}', to_jsonb('$NEW'::text)), updated_at = now()
    where key='notify';" >/dev/null
echo "  app_settings.notify.secret 갱신"

echo "=== 3. 함수 컨테이너 재기동 ==="
cd /root/massa && docker compose up -d functions >/dev/null 2>&1
sleep 9

echo "=== 4. 새 시크릿으로 발송 (200 이어야 한다) ==="
curl -s -o /dev/null -w "  HTTP %{http_code}\n" -X POST \
  http://localhost:8002/functions/v1/notify-admin \
  -H "Content-Type: application/json" -H "x-notify-secret: $NEW" \
  -d '{"action":"test"}'

echo "=== 5. 옛 시크릿으로 발송 (401 이어야 한다) ==="
curl -s -o /dev/null -w "  HTTP %{http_code}\n" -X POST \
  http://localhost:8002/functions/v1/notify-admin \
  -H "Content-Type: application/json" \
  -H "x-notify-secret: $OLD" \
  -d '{"action":"test"}'

# 요약 스크립트(/root/massa_digest.sh)는 실행할 때 .env 에서 시크릿을 읽으므로 고칠 게 없다.
# 예전처럼 값이 박힌 스크립트가 남아 있으면 다음 날 401 로 조용히 실패하니 그것만 확인한다 (2026-10-19 에 실제로 겪었다).
echo "=== 6. 크론 스크립트 확인 ==="
if grep -q "grep -E '^NOTIFY_SECRET=' /root/massa/.env" /root/massa_digest.sh; then
  echo "  .env 에서 읽음 — 그대로 둔다"
else
  echo "  값이 박힌 옛 스크립트 — scripts/vps-notify-cron.sh 로 다시 만들 것"
fi

echo "=== ROTATE DONE ==="
