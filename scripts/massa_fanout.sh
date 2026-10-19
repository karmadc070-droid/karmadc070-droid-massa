#!/bin/bash
# 수락 없는 예약을 같은 지역 다른 마사지사에게 넘긴다 (2026-10-19)
# 크론: 매분. 10분 조건은 함수 안에 있으니 자주 돌아도 중복으로 안 보낸다(fanout_at 로 한 번만).
LOG=/var/log/massa_fanout.log
OUT=$(docker exec massa-db psql -U postgres -d postgres -t -A -F'|' \
        -c "select booking_no, sent_to from public.fanout_stale_bookings(10, 10);" 2>&1)
if [ -n "$OUT" ]; then
  echo "$(date -Is) $OUT" >> "$LOG"
fi
