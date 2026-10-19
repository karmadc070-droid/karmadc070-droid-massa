#!/bin/sh
# ASCII only. No time filters. Just show everything that exists right now.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== clock check ==='
$PSQL -At -c "select now(), now() at time zone 'Asia/Seoul' as kst;" 2>&1
date -Is

echo '=== ALL bookings ==='
$PSQL -c "
select b.booking_no, b.status,
       coalesce(p.display_name,'(none)') as masseur,
       to_char(b.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as made_kst,
       to_char(b.scheduled_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as when_kst,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as devices
from bookings b left join providers p on p.id = b.provider_id
order by b.created_at;" 2>&1

echo '=== ALL notifications ==='
$PSQL -c "
select n.kind, n.push_tries, left(coalesce(n.push_result,''),40) as result,
       coalesce(u.email,'?') as who,
       to_char(n.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as made,
       n.pushed_at is null as unpushed
from notifications n left join auth.users u on u.id = n.user_id
order by n.created_at;" 2>&1

echo '=== what claim_unpushed_notifications would pick ==='
$PSQL -At -c "select count(*) from notifications where pushed_at is null;" 2>&1
echo '=== DONE ==='
