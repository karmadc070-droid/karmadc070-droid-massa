#!/bin/sh
# 테스트용 마사지사를 고객 목록에서 내린다 (행은 남긴다 — 소리 테스트에 계속 쓴다).
# 2026-10-19. 테스트가 끝나면 vps-remove-test-provider.sh 로 통째로 지운다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. TEST provider off duty ==='
$PSQL -c "update providers set is_active = false
          where display_name like '[TEST]%'
          returning display_name, is_active;" 2>&1

echo '=== 2. who customers can see now ==='
$PSQL -c "select display_name, is_active, city_code
          from providers where application_status = 'approved'
          order by is_active desc, display_name;" 2>&1

echo '=== 3. counts ==='
$PSQL -c "select count(*) filter (where is_active) as visible,
                 count(*) filter (where not is_active) as off_duty
          from providers where application_status = 'approved';" 2>&1

echo '=== 4. bookings left ==='
$PSQL -c "select booking_no, status from bookings;" 2>&1
echo '=== DONE ==='
