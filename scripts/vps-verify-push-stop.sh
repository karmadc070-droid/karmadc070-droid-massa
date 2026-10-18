#!/bin/sh
# 읽음 처리하면 반복이 멈추는지 확인하고, 테스트 알림을 정리한다
set -e
Q() { docker exec -i massa-db psql -U postgres -d postgres -t -A -c "$1"; }

echo '=== 1. 읽음 처리 전 ==='
Q "select 'tries='||push_tries from notifications where title like 'TEST5%';" | sed 's/^/  /'

echo '=== 2. 읽음으로 표시 (마사지사가 앱을 연 상황) ==='
Q "update notifications set is_read = true where title like 'TEST5%';" | sed 's/^/  /'

echo '=== 3. 발송기 2회 실행 (60초) ==='
/bin/bash /root/massa_push.sh
echo '  완료'

echo '=== 4. 읽음 처리 후 — tries 가 그대로면 멈춘 것 ==='
Q "select 'tries='||push_tries||'  next='||coalesce(next_push_at::time(0)::text,'(없음)') from notifications where title like 'TEST5%';" | sed 's/^/  /'

echo '=== 5. 테스트 알림 삭제 ==='
Q "delete from notifications where title like 'TEST%';" | sed 's/^/  /'

echo '=== 6. 실제 booking_new 현황 (테스트 제외) ==='
docker exec -i massa-db psql -U postgres -d postgres -c \
 "select coalesce(push_result,'(미발송)') as push_result, count(*) from notifications where kind='booking_new' group by 1 order by 2 desc;"

echo '=== STOP TEST DONE ==='
