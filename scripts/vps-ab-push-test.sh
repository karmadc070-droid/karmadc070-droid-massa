#!/bin/sh
# notice 와 booking_new 를 연달아 보내 어느 쪽이 폰에 도착하는지 가린다.
# 앞서 booking_new 는 도착했는데 notice 는 안 왔다고 해서, kind 가 변수인지 확인한다.
PSQL="docker exec -i massa-db psql -U postgres -d postgres"
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
U="karmadc070@gmail.com"

send() {
  $PSQL -c "insert into notifications (user_id, title, body, kind)
            select id, '$1', '$1 본문', '$2' from auth.users where email='$U';" >/dev/null
  R=$(curl -s -m 30 -X POST http://localhost:8002/functions/v1/send-push \
      -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}')
  echo "  [$2] $1 -> $R"
}

echo '=== A. notice 먼저 ==='
send 'ABTEST-NOTICE' notice
echo '   (5초 대기)'; sleep 5

echo '=== B. booking_new ==='
send 'ABTEST-BOOKING' booking_new

echo ''
echo '=== 기록 ==='
$PSQL -c "select title, kind, push_result, pushed_at::time(0)
          from notifications where title like 'ABTEST%' order by title;"

echo ''
echo '=== 이 계정의 구독 상태 (endpoint 앞부분만) ==='
$PSQL -t -A -c "select platform || ' | ' || left(token, 60) || '...'
                from push_tokens t join auth.users u on u.id=t.user_id where u.email='$U';" \
  | sed 's/^/  /'
echo '=== 보냄. 폰에서 어느 쪽이 떴는지 확인할 것 ==='
