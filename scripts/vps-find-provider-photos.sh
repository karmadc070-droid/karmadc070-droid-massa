#!/bin/sh
# ASCII only. Where do a therapist's photos actually live, and how many are there?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== providers columns that look like images ==='
$PSQL -c "select column_name, data_type, udt_name
          from information_schema.columns
          where table_name='providers'
            and (column_name ilike '%photo%' or column_name ilike '%image%'
                 or column_name ilike '%img%' or column_name ilike '%url%')
          order by ordinal_position;" 2>&1

echo '=== any separate photo table? ==='
$PSQL -c "select tablename from pg_tables where schemaname='public'
          and (tablename ilike '%photo%' or tablename ilike '%image%' or tablename ilike '%media%');" 2>&1

echo '=== provider_kyc columns ==='
$PSQL -c "select column_name, data_type from information_schema.columns
          where table_name='provider_kyc' order by ordinal_position;" 2>&1

echo '=== how many photos does each approved therapist have? ==='
$PSQL -c "select display_name,
                 case when photos is null then -1 else array_length(photos,1) end as n_photos
          from providers where application_status='approved' order by 2 desc nulls last;" 2>&1

echo '=== what admin_provider_list hands the page for photos ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='admin_provider_list';" 2>&1 \
  | grep -n -i 'photo' | head
echo '=== DONE ==='
