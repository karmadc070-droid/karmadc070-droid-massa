#!/bin/sh
# ASCII only. One-shot sound test to whoever owns the most recently registered
# android token — that is the phone in hand. Guessing the account got it wrong before.
# kind='notice' on purpose: booking_new repeats every 30s until accepted.
PSQL="docker exec massa-db psql -U postgres -d postgres"

TARGET=$($PSQL -At -c "
select u.email
from push_tokens t join auth.users u on u.id = t.user_id
where t.platform = 'android'
order by t.updated_at desc limit 1;")
echo "target: $TARGET"

echo '=== that account devices ==='
$PSQL -c "select t.platform, t.lang,
                 to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as registered
          from push_tokens t join auth.users u on u.id=t.user_id
          where u.email='$TARGET' order by t.updated_at desc;" 2>&1

echo '=== channel the server will use ==='
grep -n 'channel_id' /root/massa/volumes/functions/send-push/index.ts | head -2

echo '=== queue one notice ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'massa', 'sound check', 'notice'
from auth.users where email='$TARGET'
returning id;" 2>&1

echo '=== send ==='
bash /root/massa_push.sh 2>&1 | tail -2
sleep 4
tail -2 /var/log/massa_push.log 2>&1

echo '=== result ==='
$PSQL -c "select kind, push_tries, left(coalesce(push_result,''),70) as result
          from notifications where created_at > now() - interval '2 minutes';" 2>&1

echo '=== queue must be empty (no repeats) ==='
$PSQL -At -c "select count(*) from notifications where pushed_at is null;" 2>&1
echo '=== DONE ==='
