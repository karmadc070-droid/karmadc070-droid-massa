#!/bin/sh
# 알림음 테스트 — 지금 앱이 로그인돼 있는 계정으로 booking_new 알림을 쏜다 (2026-10-19).
# 예약을 만들지 않는다. 실제 마사지사에게 테스트가 흘러가는 일을 막기 위함이다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
TARGET='demo@massa.app'

echo '=== 1. 이 계정의 기기 ==='
$PSQL -c "select t.platform, count(*)
          from push_tokens t join auth.users u on u.id = t.user_id
          where u.email = '$TARGET' group by 1;" 2>&1

echo '=== 2. 알림 넣기 ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'massa', 'sound test', 'booking_new'
from auth.users where email = '$TARGET'
returning id;" 2>&1

echo '=== 3. 발송기 돌리기 ==='
bash /root/massa_push.sh 2>&1 | tail -3
sleep 4
tail -2 /var/log/massa_push.log 2>&1

echo '=== 4. 결과 ==='
$PSQL -c "select kind, push_tries, push_result
          from notifications
          where created_at > now() - interval '2 minutes';" 2>&1
echo '=== DONE ==='
