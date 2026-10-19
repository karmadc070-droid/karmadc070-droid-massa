#!/bin/sh
# ASCII only. Close the 5 requests nobody ever accepted (2026-10-20 05:30 KST).
#
# Hung Tran booked at 01:06 for 01:50. It fanned out to 5 therapists at 01:17.
# Three of them have no device at all; the two who were reached never answered.
# The appointment time passed hours ago. Leaving these open risks someone
# accepting at dawn and turning up at a customer who gave up long ago.
#
# We only touch rows that are still 'requested' and whose scheduled_at is past.
# Anything else is left alone.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== before ==='
$PSQL -c "
select booking_no, status,
       to_char(scheduled_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as when_kst
from bookings
where status = 'requested' and scheduled_at < now()
order by booking_no;" 2>&1

echo '=== cancel (only past, still-requested rows) ==='
$PSQL -c "
update bookings
   set status        = 'cancelled',
       cancelled_at  = now(),
       cancelled_by  = 'system',
       cancel_reason = '수락한 마사지사가 없어 예약 시각이 지났습니다.'
 where status = 'requested'
   and scheduled_at < now()
returning booking_no;" 2>&1

echo '=== after — nothing stale should remain ==='
$PSQL -c "
select booking_no, status, cancelled_by, left(cancel_reason,40) as reason
from bookings where created_at > now() - interval '12 hours'
order by booking_no;" 2>&1

echo '=== any still-open request left? (expect 0) ==='
$PSQL -At -c "select count(*) from bookings where status='requested';" 2>&1
echo '=== DONE ==='
