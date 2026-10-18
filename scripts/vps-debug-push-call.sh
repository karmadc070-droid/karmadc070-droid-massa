#!/bin/sh
# send-push 가 실제로 무엇을 돌려주는지 눈으로 본다 (반복 발송이 안 잡히는 원인 추적용)
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
echo "=== 1회차 호출 ==="
curl -s -m 25 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}'
echo ''
echo "=== 30초 대기 ==="
sleep 30
echo "=== 2회차 호출 ==="
curl -s -m 25 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}'
echo ''
echo "=== DB 상태 ==="
docker exec -i massa-db psql -U postgres -d postgres -c \
  "select push_tries, push_result, pushed_at::time(0), next_push_at::time(0), now()::time(0) as now from notifications where title like 'TEST5%';"
