#!/bin/sh
# 방금 그 알림을 한 번 더 보낸다 (소리를 못 들었을 때, 2026-10-19).
# 새 알림을 만들지 않는다 — 같은 알림의 발송 기록만 되돌려 다시 집어가게 한다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
NOTI='53f9640b-a4d3-4fde-8331-2df828e0ccb7'

echo '=== 1. 발송 기록 되돌리기 ==='
$PSQL -c "update notifications
          set push_tries = 0, pushed_at = null, push_result = null,
              next_push_at = now(), is_read = false
          where id = '$NOTI'
          returning id, kind, push_tries, is_read;" 2>&1

echo '=== 2. 발송기 돌리기 ==='
bash /root/massa_push.sh 2>&1 | tail -5
sleep 3
tail -2 /var/log/massa_push.log 2>&1

echo '=== 3. 결과 ==='
$PSQL -c "select kind, push_tries, push_result, pushed_at
          from notifications where id = '$NOTI';" 2>&1
echo '=== DONE ==='
