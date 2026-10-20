#!/bin/sh
# ASCII only. Who exactly are we about to message, and how will each one be reached?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== approved masseurs: email, signup method, devices ==='
$PSQL -c "
select p.display_name, u.email,
       coalesce(u.raw_app_meta_data->>'provider','?') as signup,
       (select count(*) from push_tokens t where t.user_id = u.id) as devices,
       p.is_active as on_duty
from providers p join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
where p.application_status = 'approved'
order by devices, p.display_name;" 2>&1

echo '=== how many would be emailed vs pushed ==='
$PSQL -c "
select case when d.n = 0 then 'email (no device)' else 'push' end as route, count(*)
from (
  select (select count(*) from push_tokens t where t.user_id = u.id) as n
  from providers p join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
  where p.application_status = 'approved'
) d group by 1;" 2>&1

echo '=== does the sender email a notice when there is no device? ==='
grep -n "emailFallback\|no_device+emailed\|MAIL_SUBJ" /root/massa/volumes/functions/send-push/index.ts | head -8
echo '=== DONE ==='
