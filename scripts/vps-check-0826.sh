#!/bin/sh
# MS-261019-0826 은 어디서 왔는가 — 자동 전달(fanout)인지 확인 + 승인 흐름이 is_active 를 켜는지
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 두 예약의 group_id 가 같은가 (같으면 자동 전달이다) ==='
$PSQL -c "
select booking_no, group_id, fanout_at,
       to_char(created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as created
from bookings order by created_at;" 2>&1

echo '=== 2. 자동 전달 로그 ==='
tail -5 /var/log/massa_fanout.log 2>&1 || echo '  (로그 없음)'

echo '=== 3. 승인 뒤 is_active 가 꺼진 채로 남는가 — 등록일과 비교 ==='
$PSQL -c "
select display_name, is_active,
       to_char(created_at,'MM-DD') as joined,
       to_char(reviewed_at,'MM-DD HH24:MI') as approved
from providers where application_status='approved'
order by created_at desc limit 6;" 2>&1

echo '=== 4. Jin 에게 좌표가 없다 — 같은 처지가 또 있는가 ==='
$PSQL -c "
select display_name, is_active, (lat is null) as no_coords, city_code
from providers where application_status='approved' and lat is null;" 2>&1
echo '=== DONE ==='
