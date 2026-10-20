#!/bin/sh
# ASCII only. Exactly how long does a new-booking alert keep ringing?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== claim_unpushed_notifications — what it re-sends and how often ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='claim_unpushed_notifications';" 2>&1

echo '=== fanout rule (10 minutes?) ==='
$PSQL -At -c "select pg_get_functiondef(p.oid)
              from pg_proc p join pg_namespace n on n.oid=p.pronamespace
              where n.nspname='public' and p.proname='fanout_stale_bookings';" 2>&1 | head -30

echo '=== cron cadence ==='
crontab -l 2>&1 | grep -i 'massa_push\|massa_fanout'
echo '=== DONE ==='
