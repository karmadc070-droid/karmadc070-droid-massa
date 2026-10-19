#!/bin/sh
# 출퇴근(is_active) 이 지금 어떻게 되어 있는가 — 본인이 못 바꾸는 값이라 중요하다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 승인된 사람들의 출퇴근 상태 ==='
$PSQL -c "select is_active, count(*) from providers
          where application_status='approved' group by 1;" 2>&1

echo '=== 2. 누가 켜져 있나 (고객 목록에 노출되는 사람) ==='
$PSQL -c "select display_name, city_code, is_active,
                 to_char(created_at,'MM-DD') as joined
          from providers where application_status='approved'
          order by is_active desc, display_name;" 2>&1

echo '=== 3. 본인이 is_active 를 바꾼 적이 있나 (on_duty_since 가 그 흔적) ==='
$PSQL -c "select count(*) filter (where on_duty_since is not null) as ever_toggled,
                 count(*) as total
          from providers where application_status='approved';" 2>&1
echo '=== DONE ==='
