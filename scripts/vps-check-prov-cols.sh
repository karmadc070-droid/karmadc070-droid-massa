#!/bin/sh
# ASCII only. Did adding fee_rate/deposit_code to the app's select break it?
PSQL="docker exec massa-db psql -U postgres -d postgres"
AID=$($PSQL -At -c "select id from profiles where role='admin' limit 1;")

echo '=== do these columns exist on providers? ==='
$PSQL -c "select column_name, data_type from information_schema.columns
          where table_name='providers'
            and column_name in ('fee_rate','deposit_code','business_hours','is_active','display_name');" 2>&1

echo '=== the exact select the app now makes, as that admin user ==='
$PSQL -c "
begin;
set local role authenticated;
set local request.jwt.claims = '{\"sub\":\"$AID\",\"role\":\"authenticated\"}';
select id, display_name, is_active, business_hours, fee_rate, deposit_code
from providers
where (profile_id = '$AID' or owner_id = '$AID')
  and application_status = 'approved';
rollback;" 2>&1

echo '=== who owns [TEST] massa owner ? ==='
$PSQL -c "select display_name, application_status, is_active,
                 profile_id = '$AID' as profile_is_admin,
                 owner_id   = '$AID' as owner_is_admin
          from providers where display_name like '%TEST%';" 2>&1

echo '=== column level grants on providers (does authenticated see every column?) ==='
$PSQL -c "select grantee, privilege_type, count(*) as cols
          from information_schema.column_privileges
          where table_name='providers' and grantee in ('authenticated','anon')
          group by 1,2 order by 1,2;" 2>&1
echo '=== DONE ==='
