#!/bin/sh
# ASCII only. Back up, then clear the stranded bookings (2026-10-20 05:40).
#
# What goes: every 'cancelled' row, plus MS-261019-7795 which got marked
# 'completed' by a mis-click. Nobody performed that service -- leaving it would
# put a fake job into revenue and commission. All of them belong to the same
# stranded fanout or to earlier tests.
#
# Everything is copied to bookings_backup_20261020 first. Restore with:
#   insert into bookings select * from bookings_backup_20261020;
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== before ==='
$PSQL -c "select status, count(*) from bookings group by 1 order by 1;" 2>&1

echo '=== back up the rows we are about to remove ==='
$PSQL -c "
drop table if exists bookings_backup_20261020;
create table bookings_backup_20261020 as
select * from bookings
 where status = 'cancelled'
    or booking_no = 'MS-261019-7795';
select count(*) as backed_up from bookings_backup_20261020;" 2>&1

echo '=== delete ==='
$PSQL -c "
delete from bookings
 where status = 'cancelled'
    or booking_no = 'MS-261019-7795'
returning booking_no, status;" 2>&1

echo '=== after ==='
$PSQL -c "select status, count(*) from bookings group by 1 order by 1;" 2>&1
$PSQL -At -c "select count(*) as rows_left from bookings;" 2>&1

echo '=== notifications that pointed at them (FK is SET NULL, so they survive) ==='
$PSQL -At -c "select count(*) from notifications where kind like 'booking%' and booking_id is null;" 2>&1

echo '=== backup table is there ==='
$PSQL -At -c "select count(*) from bookings_backup_20261020;" 2>&1
echo '=== DONE ==='
