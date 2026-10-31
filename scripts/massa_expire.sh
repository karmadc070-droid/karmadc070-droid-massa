#!/bin/sh
# 하노이 00시에 약속 시각이 지난 신청 예약은 자동 취소, 수락된 예약은 자동 완료한다 (VPS /root/massa_expire.sh, 크론 0 2 * * * 서버 KST)
q() { docker exec massa-db psql -U postgres -d postgres -Atc "$1" 2>&1; }
echo "$(date -Is) expired=$(q 'select public.expire_stale_bookings()') completed=$(q 'select public.complete_stale_bookings()')" >> /var/log/massa_expire.log
