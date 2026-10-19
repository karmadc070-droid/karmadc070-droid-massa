#!/bin/sh
# 자동 전환을 만들기 전에, 이미 있는 장치들을 정확히 읽는다
PSQL="docker exec -i massa-db psql -U postgres -d postgres -t -A"
echo '########## accept_booking ##########'
$PSQL -c "select pg_get_functiondef(oid) from pg_proc where proname='accept_booking';"
echo '########## guard_booking_write ##########'
$PSQL -c "select pg_get_functiondef(oid) from pg_proc where proname='guard_booking_write';"
echo '########## guard_booking_distance ##########'
$PSQL -c "select pg_get_functiondef(oid) from pg_proc where proname='guard_booking_distance';"
echo '########## booking_no 는 어떻게 생기나 ##########'
$PSQL -c "select column_name, column_default, is_nullable from information_schema.columns where table_name='bookings' and column_name in ('id','booking_no','status','group_id','amount_vnd','fee_rate');"
