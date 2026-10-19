#!/bin/sh
# ASCII only. Something in the admin console says 22. Find what has 22 rows.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== row counts for every public table (looking for 22) ==='
$PSQL -At -c "select tablename from pg_tables where schemaname='public' order by 1;" 2>&1 \
| while read t; do
    [ -z "$t" ] && continue
    n=$($PSQL -At -c "select count(*) from public.\"$t\";" 2>/dev/null)
    case "$n" in
      22) echo "  *** $t = $n  <= MATCH" ;;
      21|23) echo "  ~   $t = $n" ;;
      *) ;;
    esac
  done

echo '=== provider-ish tables, full counts ==='
$PSQL -c "select 'providers' t, count(*) from providers
          union all select 'provider_kyc', count(*) from provider_kyc
          union all select 'profiles', count(*) from profiles
          union all select 'auth.users', count(*) from auth.users;" 2>&1

echo '=== is anything soft-deleted or hidden from my earlier query? ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='providers'
            and column_name in ('deleted_at','archived_at','hidden','visible','status');" 2>&1
echo '=== DONE ==='
