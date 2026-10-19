#!/bin/sh
# ASCII only. Is the 유입 tile counting visits or people? (2026-10-20)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== visits by role (rows = visits, people = distinct users) ==='
$PSQL -c "select coalesce(role::text,'(none)') as role, is_member,
                 count(*) as visits,
                 count(distinct user_id) as people
          from app_visit
          group by 1,2 order by 3 desc;" 2>&1

echo '=== does 73 + 22 + 264 = 359 hold for the whole table? ==='
$PSQL -c "select count(*) as total,
                 count(*) filter (where role='customer') as customer,
                 count(*) filter (where role='provider') as provider,
                 count(*) filter (where role is null)    as logged_out
          from app_visit;" 2>&1

echo '=== how admin_dashboard builds that breakdown ==='
$PSQL -c "select pg_get_functiondef(p.oid) from pg_proc p
          join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='admin_dashboard';" 2>&1 \
  | grep -n -i "app_visit\|provider'\|customer'\|anon\|new_device\|visits" | head -20
echo '=== DONE ==='
