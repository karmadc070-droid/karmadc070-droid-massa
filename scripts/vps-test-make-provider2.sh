#!/bin/sh
# 1단계(재시도) — 테스트 마사지사 만들기.
# guard_provider_kyc_insert 가 "신청은 pending 으로만" 이라고 막는다. 맞는 규칙이다.
# 그래서 실제 가입과 똑같이 pending 으로 넣고, 관리자 승인과 똑같이 approved 로 올린다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
UID_ME='0bf03ce4-ed36-463c-88ae-6c068d16bb2b'

echo '=== 1. pending 으로 신청 ==='
$PSQL -c "
insert into providers (profile_id, kind, display_name, specialties, languages,
                       city_code, lat, lng, base_district, service_area,
                       is_active, application_status, rating, review_count,
                       bio, sort_priority)
select '$UID_ME', 'masseur', '[TEST] massa owner', array['aroma'], array['ko','vi'],
       'hanoi', 21.0278, 105.8342, 'Ba Dinh', 'Ba Dinh',
       false, 'pending', 0, 0,
       'Internal test account. Do not book.', -99
where not exists (select 1 from providers where profile_id = '$UID_ME')
returning id;" 2>&1

echo '=== 2. 승인 + 출근 ==='
$PSQL -c "update providers set application_status = 'approved', is_active = true,
                               reviewed_at = now()
          where profile_id = '$UID_ME' returning id, display_name, application_status, is_active;" 2>&1

echo '=== 3. 결과 ==='
$PSQL -c "select id, display_name, kind, application_status, is_active, city_code, lat, lng, sort_priority
          from providers where profile_id = '$UID_ME';" 2>&1
echo '=== DONE ==='
