#!/bin/sh
# ASCII only. tallvietnam's android token vanished. Where did it go?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== every push token, no limit ==='
$PSQL -c "
select u.email, t.platform, left(t.token,14) as head,
       to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as updated
from push_tokens t join auth.users u on u.id=t.user_id
order by t.updated_at desc;" 2>&1

echo '=== counts ==='
$PSQL -c "select platform, count(*) from push_tokens group by 1;" 2>&1

echo '=== what register_push_token does (upsert key matters) ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='register_push_token';" 2>&1

echo '=== push_tokens shape ==='
$PSQL -c "select conname, pg_get_constraintdef(oid)
          from pg_constraint where conrelid='public.push_tokens'::regclass;" 2>&1
echo '=== DONE ==='
