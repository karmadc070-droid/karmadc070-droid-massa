#!/bin/sh
# ASCII only. Does app_visit.platform accept a new value like 'pwa'?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo "=== column type ==="
$PSQL -c "select column_name, data_type, udt_name, is_nullable
          from information_schema.columns
          where table_name='app_visit' and column_name='platform';" 2>&1

echo "=== any check constraint on app_visit ==="
$PSQL -c "select conname, pg_get_constraintdef(oid)
          from pg_constraint where conrelid='public.app_visit'::regclass;" 2>&1

echo "=== track_visit function signature ==="
$PSQL -c "select pg_get_functiondef(p.oid)
          from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='track_visit';" 2>&1 | head -40

echo "=== distinct platform values seen so far ==="
$PSQL -c "select platform, count(*) from app_visit group by 1 order by 2 desc;" 2>&1
echo "=== DONE ==="
