#!/bin/sh
# 수락되지 않은 예약 MS-261019-3906 을 취소 처리한다 (2026-10-19).
# 지우지 않는 이유: 실제 손님이 신청했다는 기록은 남겨 둔다. 자동 전달만 멈추면 된다.
# ★ -i 를 쓰지 않는다. 이 스크립트를 ssh 표준입력으로 흘려 넣으면
#   docker exec -i 가 남은 스크립트를 통째로 삼켜 버린다 (실제로 1번 항목만 돌고 끝났다).
PSQL="docker exec massa-db psql -U postgres -d postgres"
NO='MS-261019-3906'

echo '=== 1. 바꾸기 전 ==='
$PSQL -c "select booking_no, status, fanout_at from bookings where booking_no='$NO';" 2>&1

echo '=== 2. cancelled_at 칼럼이 있는가 ==='
HAS=$($PSQL -t -A -c "select count(*) from information_schema.columns
                      where table_name='bookings' and column_name='cancelled_at';" 2>&1 | head -1)
echo "  cancelled_at: $HAS"

echo '=== 3. 취소 처리 ==='
if [ "$HAS" = "1" ]; then
  $PSQL -c "update bookings set status='cancelled', cancelled_at=now()
            where booking_no='$NO' and status='requested';" 2>&1
else
  $PSQL -c "update bookings set status='cancelled'
            where booking_no='$NO' and status='requested';" 2>&1
fi

echo '=== 4. 바꾼 뒤 ==='
$PSQL -c "select booking_no, status from bookings where booking_no='$NO';" 2>&1

echo '=== 5. 자동 전달이 더 집어가지 않는가 (requested 가 0건이어야 한다) ==='
$PSQL -c "select status, count(*) from bookings group by 1 order by 2 desc;" 2>&1
echo '=== DONE ==='
