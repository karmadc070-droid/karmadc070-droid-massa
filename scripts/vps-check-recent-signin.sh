#!/bin/sh
# ASCII only. Did the Google sign-in actually complete on the server side?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== sign-ins in the last 30 minutes ==='
$PSQL -c "
select email,
       raw_app_meta_data->>'provider' as provider,
       to_char(last_sign_in_at at time zone 'Asia/Seoul','HH24:MI:SS') as signed_in,
       to_char(updated_at at time zone 'Asia/Seoul','HH24:MI:SS') as updated
from auth.users
where last_sign_in_at > now() - interval '30 minutes'
   or updated_at > now() - interval '30 minutes'
order by coalesce(last_sign_in_at, updated_at) desc;" 2>&1

echo '=== sessions created recently ==='
$PSQL -c "
select u.email, s.created_at at time zone 'Asia/Seoul' as created
from auth.sessions s join auth.users u on u.id = s.user_id
where s.created_at > now() - interval '30 minutes'
order by s.created_at desc;" 2>&1

echo '=== any token registered since the test? ==='
$PSQL -c "
select u.email, t.platform,
       to_char(t.updated_at at time zone 'Asia/Seoul','HH24:MI:SS') as updated
from push_tokens t join auth.users u on u.id=t.user_id
where t.updated_at > now() - interval '30 minutes';" 2>&1
echo '=== DONE ==='
