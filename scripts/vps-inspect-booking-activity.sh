#!/bin/sh
# ASCII only. Can we measure "who actually works" from bookings today? (2026-10-20)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== bookings columns ==='
$PSQL -c "select column_name, data_type from information_schema.columns
          where table_name='bookings' order by ordinal_position;" 2>&1

echo '=== status values seen ==='
$PSQL -c "select status, count(*) from bookings group by 1 order by 2 desc;" 2>&1

echo '=== is there a per-offer table (fanout) rather than one row per booking? ==='
$PSQL -c "select tablename from pg_tables where schemaname='public'
          and (tablename like '%offer%' or tablename like '%candidate%'
               or tablename like '%booking%' or tablename like '%fanout%');" 2>&1

echo '=== how accept_booking records the acceptance ==='
$PSQL -c "select pg_get_functiondef(p.oid) from pg_proc p
          join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='accept_booking';" 2>&1 | head -40

echo '=== sample bookings ==='
$PSQL -c "select booking_no, status, provider_id is not null as has_prov, group_id is not null as fanned,
                 to_char(created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as made
          from bookings order by created_at desc limit 10;" 2>&1
echo '=== DONE ==='
