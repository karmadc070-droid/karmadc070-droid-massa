#!/bin/sh
# 테스트 예약 2건을 지우고, Jin 의 출퇴근을 켠다 (2026-10-19).
# 지우는 것은 내가 오늘 만든 가짜 2건뿐이다. 아침의 진짜 예약(3906)은 건드리지 않는다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 지우기 전 ==='
$PSQL -c "select booking_no, status from bookings order by created_at;" 2>&1

echo '=== 2. 딸린 알림부터 (외래키가 SET NULL 이라 남는다) ==='
$PSQL -c "
delete from notifications
where booking_id in (select id from bookings
                     where booking_no in ('MS-261019-6714','MS-261019-0826'));" 2>&1

echo '=== 3. 테스트 예약 2건 삭제 ==='
$PSQL -c "
delete from bookings
where booking_no in ('MS-261019-6714','MS-261019-0826')
returning booking_no;" 2>&1

echo '=== 4. 테스트 채팅도 지운다 ==='
$PSQL -c "
delete from messages
where provider_id = '47482472-7f32-4d7e-af2b-e97bd5dd83f5'
returning sender_role;" 2>&1

echo '=== 5. Jin 출퇴근 켜기 ==='
$PSQL -c "
update providers set is_active = true, on_duty_since = now()
where display_name = 'Jin' and application_status = 'approved'
returning display_name, is_active;" 2>&1

echo '=== 6. 확인 — 예약 ==='
$PSQL -c "select booking_no, status from bookings order by created_at;" 2>&1

echo '=== 7. 확인 — 고객 목록에 뜨는 사람 ==='
$PSQL -c "
select count(*) filter (where is_active) as 노출중,
       count(*) filter (where not is_active) as 꺼짐
from providers where application_status='approved';" 2>&1
echo '=== DONE ==='
