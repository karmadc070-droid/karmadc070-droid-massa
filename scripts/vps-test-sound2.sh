#!/bin/sh
# ASCII only. Ring the phone that just logged in with email+password (2026-10-20).
PSQL="docker exec massa-db psql -U postgres -d postgres"
TARGET='tallvietnam@gmail.com'

echo "=== devices for $TARGET ==="
$PSQL -c "select t.platform, t.lang,
                 to_char(t.updated_at at time zone 'Asia/Seoul','HH24:MI:SS') as reg
          from push_tokens t join auth.users u on u.id=t.user_id
          where u.email='$TARGET';" 2>&1

echo '=== queue one booking_new ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'massa', 'sound test', 'booking_new'
from auth.users where email='$TARGET'
returning id;" 2>&1

echo '=== run the sender ==='
bash /root/massa_push.sh 2>&1 | tail -3
sleep 4
tail -2 /var/log/massa_push.log 2>&1

echo '=== result ==='
$PSQL -c "select kind, push_tries, left(push_result,120) as result
          from notifications where created_at > now() - interval '2 minutes';" 2>&1
echo '=== DONE ==='
