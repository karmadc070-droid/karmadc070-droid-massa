#!/bin/sh
# ASCII only. Reproduce the "완료 처리" failure as the admin, then roll back.
PSQL="docker exec massa-db psql -U postgres -d postgres"
AID=$($PSQL -At -c "select id from profiles where role='admin' limit 1;")
BID=$($PSQL -At -c "select id from bookings where status='cancelled' order by created_at desc limit 1;")
echo "admin=$AID"
echo "booking=$BID"

echo '=== reproduce: set a cancelled booking to completed, as the admin ==='
$PSQL -c "
begin;
set local role authenticated;
set local request.jwt.claims = '{\"sub\":\"$AID\",\"role\":\"authenticated\"}';
update bookings set status='completed', completed_at=now() where id='$BID';
rollback;" 2>&1

echo '=== is_admin() seen from that JWT? ==='
$PSQL -At -c "
begin;
set local role authenticated;
set local request.jwt.claims = '{\"sub\":\"$AID\",\"role\":\"authenticated\"}';
select public.is_admin();
rollback;" 2>&1

echo '=== status column type / allowed values ==='
$PSQL -c "select t.typname, e.enumlabel
          from pg_type t join pg_enum e on e.enumtypid=t.oid
          where t.typname = (select udt_name from information_schema.columns
                             where table_name='bookings' and column_name='status')
          order by e.enumsortorder;" 2>&1

echo '=== what references bookings ==='
$PSQL -c "select conrelid::regclass as child, pg_get_constraintdef(oid)
          from pg_constraint where confrelid='public.bookings'::regclass;" 2>&1
echo '=== DONE ==='
