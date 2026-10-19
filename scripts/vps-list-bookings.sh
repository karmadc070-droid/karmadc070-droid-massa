#!/bin/sh
# 지금까지 들어온 예약을 전부 본다 (삭제 전 확인용, 2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 예약 전체 ==='
$PSQL -c "
select b.booking_no, b.status,
       coalesce(p.display_name,'(없음)') as masseur,
       b.amount_vnd,
       to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as created
from bookings b left join providers p on p.id = b.provider_id
order by b.created_at;" 2>&1

echo '=== 2. 예약에 딸린 것들 ==='
for t in chat_messages reviews notifications payments; do
  printf '%-18s ' "$t"
  $PSQL -t -A -c "select count(*) from $t;" 2>&1 | head -1
done

echo '=== 3. 예약을 가리키는 외래키 ==='
$PSQL -c "
select tc.table_name, kcu.column_name, rc.delete_rule
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu on kcu.constraint_name = tc.constraint_name
join information_schema.referential_constraints rc on rc.constraint_name = tc.constraint_name
join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name
where tc.constraint_type = 'FOREIGN KEY' and ccu.table_name = 'bookings';" 2>&1
echo '=== DONE ==='
