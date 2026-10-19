#!/bin/sh
# ASCII only. Read the real track_visit before touching it.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== every overload of track_visit ==='
$PSQL -c "select p.oid::regprocedure as sig
          from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='track_visit';" 2>&1

echo '=== full definition ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='track_visit';" 2>&1

echo '=== constraints / indexes on app_visit ==='
$PSQL -c "select conname, pg_get_constraintdef(oid)
          from pg_constraint where conrelid='public.app_visit'::regclass;" 2>&1
$PSQL -c "select indexname, indexdef from pg_indexes where tablename='app_visit';" 2>&1

echo '=== who may execute it ==='
$PSQL -c "select p.oid::regprocedure, p.proacl
          from pg_proc p join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='track_visit';" 2>&1
echo '=== DONE ==='
