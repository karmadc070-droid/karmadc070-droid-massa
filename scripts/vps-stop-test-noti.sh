#!/bin/sh
# ASCII only. Kill the repeating test notifications (2026-10-20).
# booking_new repeats every 30s until accepted. A test row has no booking, so it
# never stops. Delete them.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== what is still repeating ==='
$PSQL -c "select id, kind, body, push_tries,
                 to_char(created_at at time zone 'Asia/Seoul','HH24:MI:SS') as made
          from notifications
          where body = 'sound test' or (kind='booking_new' and booking_id is null)
          order by created_at;" 2>&1

echo '=== delete them ==='
$PSQL -c "delete from notifications
          where body = 'sound test' or (kind='booking_new' and booking_id is null);" 2>&1

echo '=== anything left that would re-ring? ==='
$PSQL -c "select id, kind, booking_id, push_tries,
                 to_char(created_at at time zone 'Asia/Seoul','HH24:MI:SS') as made
          from notifications
          where kind='booking_new' and created_at > now() - interval '1 day';" 2>&1

echo '=== sender should now claim nothing ==='
bash /root/massa_push.sh 2>&1 | tail -2
echo '=== DONE ==='
