#!/bin/sh
# ASCII only. Which account owns which android token right now?
PSQL="docker exec massa-db psql -U postgres -d postgres"
echo '=== android tokens, newest first ==='
$PSQL -c "
select u.email, left(t.token,14) as head, t.lang,
       to_char(t.updated_at at time zone 'Asia/Seoul','HH24:MI:SS') as updated
from push_tokens t join auth.users u on u.id=t.user_id
where t.platform='android'
order by t.updated_at desc limit 8;" 2>&1

echo '=== karmadc070 all platforms ==='
$PSQL -c "
select t.platform, count(*),
       to_char(max(t.updated_at) at time zone 'Asia/Seoul','HH24:MI:SS') as newest
from push_tokens t join auth.users u on u.id=t.user_id
where u.email='karmadc070@gmail.com' group by 1;" 2>&1

echo '=== today app opens by platform (who, when) ==='
$PSQL -c "
select a.platform, a.role, coalesce(u.email,'(logged out)') as who,
       to_char(a.created_at at time zone 'Asia/Seoul','HH24:MI') as first_seen
from app_visit a left join auth.users u on u.id=a.user_id
where a.visit_date = current_date and a.platform='android'
order by a.created_at desc limit 5;" 2>&1
echo '=== DONE ==='
