#!/bin/sh
# 1단계 — 사장님 계정을 테스트 마사지사로 세운다 (2026-10-19).
# 끝나면 vps-test-cleanup.sh 로 지운다. 고객 목록에 TEST 가 오래 보이면 안 된다.
# ★ 한글을 SQL 안에 쓰지 않는다. 파이프로 흘려 넣으면 깨진다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
UID_ME='0bf03ce4-ed36-463c-88ae-6c068d16bb2b'

echo '=== 1. 이미 있으면 그걸 쓴다 ==='
$PSQL -c "
insert into providers (profile_id, kind, display_name, specialties, languages,
                       city_code, lat, lng, base_district, service_area,
                       is_active, application_status, rating, review_count,
                       bio, sort_priority)
select '$UID_ME', 'masseur', '[TEST] massa owner', array['aroma'], array['ko','vi'],
       'hanoi', 21.0278, 105.8342, 'Ba Dinh', 'Ba Dinh',
       true, 'approved', 0, 0,
       'Internal test account. Do not book.', -99
where not exists (select 1 from providers where profile_id = '$UID_ME')
returning id, display_name, city_code, is_active;" 2>&1

echo '=== 2. 결과 ==='
$PSQL -c "select id, display_name, kind, application_status, is_active, city_code, lat, lng
          from providers where profile_id = '$UID_ME';" 2>&1

echo '=== 3. 내 기기(푸시) 몇 대인가 ==='
$PSQL -c "select count(*) as devices from push_tokens where user_id = '$UID_ME';" 2>&1

echo '=== 4. 손님으로 쓸 demo 계정 id ==='
$PSQL -c "select id, email from auth.users where email = 'demo@massa.app';" 2>&1

echo '=== 5. payment_method 가 어떤 값을 받는가 ==='
$PSQL -c "select column_name, data_type, udt_name from information_schema.columns
          where table_name='bookings' and column_name in ('payment_method','status','location_type');" 2>&1
$PSQL -c "select t.typname, e.enumlabel from pg_type t join pg_enum e on e.enumtypid=t.oid
          where t.typname in ('payment_method','booking_status','location_type') order by 1,e.enumsortorder;" 2>&1
echo '=== DONE ==='
