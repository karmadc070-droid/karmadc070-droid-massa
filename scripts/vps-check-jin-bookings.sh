#!/bin/sh
# Jin 이 고객 목록에 왜 안 보이는가 + 지금까지의 예약 전부 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. Jin 상태 ==='
$PSQL -c "
select p.id, p.display_name, p.kind, p.application_status as status,
       p.is_active, p.city_code, p.lat, p.lng,
       p.suspended_until, p.sort_priority,
       (select count(*) from provider_kyc k where k.provider_id = p.id) as kyc,
       u.email
from providers p
left join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
where p.display_name ilike '%jin%';" 2>&1

echo '=== 2. 고객 목록에 뜨는 조건은 is_active + approved 이다 ==='
$PSQL -c "
select display_name, kind, application_status, is_active
from providers
where application_status = 'approved'
order by is_active, display_name;" 2>&1

echo '=== 3. 예약 전부 ==='
$PSQL -c "
select b.booking_no, b.status,
       coalesce(p.display_name,'-') as masseur,
       coalesce(uc.email,'-') as customer,
       b.amount_vnd, b.hotel_name,
       to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as created
from bookings b
left join providers p on p.id = b.provider_id
left join auth.users uc on uc.id = b.customer_id
order by b.created_at;" 2>&1

echo '=== 4. 테스트로 만든 것 (내가 만든 provider / demo 손님) ==='
$PSQL -c "
select b.booking_no, b.status,
       case when p.display_name like '[TEST]%' or uc.email = 'demo@massa.app'
            then 'TEST' else 'REAL' end as kind
from bookings b
left join providers p on p.id = b.provider_id
left join auth.users uc on uc.id = b.customer_id
order by b.created_at;" 2>&1
echo '=== DONE ==='
