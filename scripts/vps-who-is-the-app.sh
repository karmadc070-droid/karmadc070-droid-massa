#!/bin/sh
# ASCII only. Who is the android app actually logged in as right now?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== today visits, with the person attached (user_id added 2026-10-20) ==='
$PSQL -c "
select a.platform, a.role, coalesce(u.email,'(logged out)') as who,
       a.device_id,
       to_char(a.created_at at time zone 'Asia/Seoul','HH24:MI:SS') as first_seen
from app_visit a left join auth.users u on u.id = a.user_id
where a.visit_date >= current_date - 1
order by a.created_at desc limit 15;" 2>&1

echo '=== every push token, newest first ==='
$PSQL -c "
select u.email, t.platform, left(t.token,12) as head,
       to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as updated
from push_tokens t join auth.users u on u.id=t.user_id
order by t.updated_at desc limit 8;" 2>&1
echo '=== DONE ==='
