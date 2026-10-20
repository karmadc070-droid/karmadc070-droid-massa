#!/bin/sh
# ASCII only. One-shot sound test on the new v2 channel (2026-10-20).
# kind='notice' on purpose: booking_new repeats every 30s until accepted and a
# test has no booking to accept, so last night it rang for hours. Do not use it.
PSQL="docker exec massa-db psql -U postgres -d postgres"
TARGET='tallvietnam@gmail.com'

echo "=== devices for $TARGET ==="
$PSQL -c "select t.platform, t.lang,
                 to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as registered
          from push_tokens t join auth.users u on u.id=t.user_id
          where u.email='$TARGET';" 2>&1

echo '=== queue one notice ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'massa', 'v2 channel sound test', 'notice'
from auth.users where email='$TARGET'
returning id;" 2>&1

echo '=== send ==='
bash /root/massa_push.sh 2>&1 | tail -2
sleep 4
tail -2 /var/log/massa_push.log 2>&1

echo '=== result ==='
$PSQL -c "select kind, push_tries, left(coalesce(push_result,''),60) as result
          from notifications where created_at > now() - interval '2 minutes';" 2>&1

echo '=== nothing should be left repeating ==='
$PSQL -At -c "select count(*) from notifications where pushed_at is null;" 2>&1
echo '=== DONE ==='
