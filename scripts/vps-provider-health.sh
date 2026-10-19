#!/bin/sh
# ASCII only. Who signed up recently and what is wrong with their record.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo "=== 1. counts by status ==="
$PSQL -c "select kind, application_status, is_active, count(*)
          from providers group by 1,2,3 order by 1,2,3;" 2>&1

echo "=== 2. recent signups (last 3 days) ==="
$PSQL -c "
select p.display_name, p.kind, p.application_status as status, p.is_active,
       p.city_code, (p.lat is null) as no_coords,
       (select count(*) from provider_kyc k where k.provider_id=p.id) as kyc,
       (select count(*) from push_tokens t
          where t.user_id = coalesce(p.profile_id,p.owner_id)) as devices,
       to_char(p.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as joined
from providers p
where p.created_at > now() - interval '3 days'
order by p.created_at;" 2>&1

echo "=== 3. approved but switched off (invisible to customers) ==="
$PSQL -c "
select p.display_name, p.city_code, u.email,
       to_char(p.reviewed_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as approved
from providers p left join auth.users u on u.id = coalesce(p.profile_id,p.owner_id)
where p.application_status='approved' and not p.is_active;" 2>&1

echo "=== 4. waiting for approval ==="
$PSQL -c "
select p.display_name, p.kind, p.city_code, u.email,
       (select count(*) from provider_kyc k where k.provider_id=p.id) as kyc,
       to_char(p.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as joined
from providers p left join auth.users u on u.id = coalesce(p.profile_id,p.owner_id)
where p.application_status in ('pending','rejected')
order by p.created_at;" 2>&1

echo "=== 5. approved providers with no device (cannot hear a booking) ==="
$PSQL -c "
select p.display_name, u.email,
       (select count(*) from push_tokens t where t.user_id = u.id) as devices
from providers p join auth.users u on u.id = coalesce(p.profile_id,p.owner_id)
where p.application_status='approved'
order by 3, 1;" 2>&1
echo "=== DONE ==="
