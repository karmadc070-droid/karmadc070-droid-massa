#!/bin/sh
# ASCII only. One notice push to the owner's own account, every device it has.
# kind='notice' on purpose: booking_new repeats every 30s until accepted.
PSQL="docker exec massa-db psql -U postgres -d postgres"
ME='karmadc070@gmail.com'

echo '=== devices on that account ==='
$PSQL -c "select t.platform, t.lang, left(t.token,14) as head,
                 to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as registered
          from push_tokens t join auth.users u on u.id=t.user_id
          where u.email='$ME' order by t.updated_at desc;" 2>&1

echo '=== channel the server will use ==='
grep -n 'channel_id' /root/massa/volumes/functions/send-push/index.ts | head -2

echo '=== queue one notice ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'massa', 'sound check', 'notice'
from auth.users where email='$ME'
returning id;" 2>&1

echo '=== send ==='
bash /root/massa_push.sh 2>&1 | tail -2
sleep 5
tail -3 /var/log/massa_push.log 2>&1

echo '=== result ==='
$PSQL -c "select kind, push_tries, next_push_at,
                 left(coalesce(push_result,''),90) as result
          from notifications where created_at > now() - interval '2 minutes';" 2>&1

echo '=== nothing left queued? ==='
$PSQL -At -c "select count(*) from notifications where pushed_at is null;" 2>&1
echo '=== DONE ==='
