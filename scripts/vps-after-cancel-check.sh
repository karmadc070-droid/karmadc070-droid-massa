#!/bin/sh
# ASCII only. The cancel fires notify_booking_event. What did it queue at 05:30?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== notifications created by the cancel ==='
$PSQL -c "
select n.kind, coalesce(u.email,'?') as who, n.pushed_at is null as unpushed,
       to_char(n.created_at at time zone 'Asia/Seoul','HH24:MI:SS') as made
from notifications n left join auth.users u on u.id = n.user_id
where n.created_at > now() - interval '5 minutes'
order by n.created_at;" 2>&1

echo '=== anything still waiting to be pushed? ==='
$PSQL -At -c "select count(*) from notifications where pushed_at is null;" 2>&1

echo '=== sender log, last lines ==='
tail -3 /var/log/massa_push.log 2>&1
echo '=== DONE ==='
