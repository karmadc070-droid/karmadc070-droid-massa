#!/bin/sh
# ASCII only. Did the 10-minute change land, and does a booking-less alert stop repeating?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== the numbers in the live function ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='claim_unpushed_notifications';" 2>&1 \
  | grep -nE "push_tries \+ 1 <|push_tries <|interval '1[01] minutes'|booking_id is not null"

echo '=== probe: a booking_new with NO booking must be sent once, then never again ==='
$PSQL -c "
begin;
insert into notifications (user_id, title, body, kind)
select id, 'probe', 'repeat probe', 'booking_new'
from auth.users where email='karmadc070@gmail.com';
-- 1회차
select count(*) as claimed_1st from claim_unpushed_notifications();
-- next_push_at 이 비어 있어야 한다 (재발송 예약 안 함)
select kind, push_tries, next_push_at is null as will_not_repeat
from notifications where body='repeat probe';
-- 2회차: 아무것도 안 잡혀야 한다
select count(*) as claimed_2nd from claim_unpushed_notifications();
rollback;" 2>&1

echo '=== probe cleaned up? ==='
$PSQL -At -c "select count(*) from notifications where body='repeat probe';" 2>&1
echo '=== DONE ==='
