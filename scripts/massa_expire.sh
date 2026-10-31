#!/bin/sh
# 하노이 00시에 약속 시각이 지난 신청(requested) 예약을 자동 취소한다 (VPS /root/massa_expire.sh, 크론 0 2 * * * 서버 KST)
echo "$(date -Is) expired=$(docker exec massa-db psql -U postgres -d postgres -Atc 'select public.expire_stale_bookings()' 2>&1)" >> /var/log/massa_expire.log
