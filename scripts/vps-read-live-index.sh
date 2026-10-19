#!/bin/sh
# ASCII only. What exactly does bookings_one_live_per_group consider "live"?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== the index ==='
$PSQL -c "select indexdef from pg_indexes
          where tablename='bookings' and indexname='bookings_one_live_per_group';" 2>&1

echo '=== all indexes on bookings ==='
$PSQL -c "select indexname, indexdef from pg_indexes where tablename='bookings';" 2>&1

echo '=== the group in question, every row ==='
$PSQL -c "
select b.booking_no, b.status, p.display_name as masseur, b.group_id
from bookings b left join providers p on p.id=b.provider_id
where b.group_id = (select group_id from bookings where status='cancelled'
                    and group_id is not null order by created_at desc limit 1)
order by b.created_at;" 2>&1
echo '=== DONE ==='
