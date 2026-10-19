#!/bin/sh
# ASCII only. Verify the activity function AND that track_visit now records who.
PSQL="docker exec massa-db psql -U postgres -d postgres"
AID=$($PSQL -At -c "select id from profiles where role='admin' limit 1;")
JWT="{\"sub\":\"$AID\",\"role\":\"authenticated\"}"

echo '=== 1. does track_visit write user_id now? (write as a real user, then roll back) ==='
$PSQL -c "
begin;
set local request.jwt.claims = '$JWT';
select track_visit('verify-probe-device','android','ko');
select device_id, role, is_member, user_id is not null as has_user
from app_visit where device_id = 'verify-probe-device';
rollback;" 2>&1

echo '=== 2. the probe must be gone after rollback ==='
$PSQL -At -c "select count(*) from app_visit where device_id='verify-probe-device';" 2>&1

echo '=== 3. activity rows (expect 15, with the two new columns) ==='
$PSQL -c "
set local request.jwt.claims = '$JWT';
select r->>'name' as masseur,
       (r->>'devices')::int as dev,
       (r->>'got')::int as got,
       coalesce(r->>'accept_rate','-') as rate,
       (r->>'visit_days')::int as days,
       coalesce(r->>'last_visit','-') as last
from jsonb_array_elements(admin_provider_activity()->'rows') r
order by (r->>'got')::int desc, r->>'name';" 2>&1

echo '=== 4. a non-admin must still be refused ==='
$PSQL -At -c "
set local request.jwt.claims = '{\"sub\":\"00000000-0000-0000-0000-000000000000\",\"role\":\"authenticated\"}';
select admin_provider_activity();" 2>&1 | head -1
echo '=== DONE ==='
