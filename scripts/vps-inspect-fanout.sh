#!/bin/sh
# 지금 있는 '다른 사람에게 더 보내기' 구조를 확인한다 (2026-10-19)
PSQL="docker exec -i massa-db psql -U postgres -d postgres"

echo '=== 1. 어제 그 예약에 group_id 가 있었나 ==='
$PSQL -c "select booking_no, status, group_id, provider_id from bookings order by created_at desc limit 3;"

echo '=== 2. 형제 예약 자동 취소 장치가 있는가 ==='
$PSQL -t -A -c "
select proname from pg_proc
where prosrc ilike '%group_id%' and pronamespace = 'public'::regnamespace
order by proname;" | sed 's/^/  /'

echo '=== 3. bookings 트리거 목록 ==='
$PSQL -c "
select tgname as 트리거, p.proname as 함수
from pg_trigger t join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'public.bookings'::regclass and not t.tgisinternal
order by tgname;"

echo '=== 4. 하노이 황리엣(그 손님 지역) 주변에 누가 있나 ==='
$PSQL -c "
select p.display_name as 마사지사, p.kind as 종류, p.base_district as 권역,
       p.city_code, p.is_active as 영업중,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as 기기수
from providers p
where p.application_status='approved' and p.kind='masseur'
order by 기기수 desc, p.display_name;"
echo '=== DONE ==='
