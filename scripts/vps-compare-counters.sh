#!/bin/sh
# ASCII only. The admin page counts therapists in two places. Compare them.
#   dashboard tile : admin_dashboard() -> providers_total
#   roster note    : admin_provider_list() -> rows.length
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== how admin_dashboard counts providers_total ==='
$PSQL -c "select pg_get_functiondef(p.oid) from pg_proc p
          join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='admin_dashboard';" 2>&1 \
  | grep -n -i 'providers_total\|from providers' | head -10

echo '=== how admin_provider_list picks rows ==='
$PSQL -c "select pg_get_functiondef(p.oid) from pg_proc p
          join pg_namespace n on n.oid=p.pronamespace
          where n.nspname='public' and p.proname='admin_provider_list';" 2>&1 \
  | grep -n -i 'from providers\|where\|application_status\|is_active' | head -15

echo '=== the numbers each would produce ==='
$PSQL -c "select count(*) as all_rows,
                 count(*) filter (where application_status='approved') as approved,
                 count(*) filter (where application_status='approved' and is_active) as approved_on,
                 count(*) filter (where kind='masseur') as masseur_rows
          from providers;" 2>&1
echo '=== DONE ==='
