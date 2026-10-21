#!/bin/sh
# ASCII only. Install the contact_request table + guard + notify trigger, then
# reload the notify-admin function so its new contact_request branch is live.
set -e
PSQL="docker exec -i massa-db psql -U postgres -d postgres"

echo '=== apply sql ==='
# -f 는 컨테이너 안의 경로로 해석된다. 파일은 호스트에 있으므로 표준입력으로 넣는다.
$PSQL -v ON_ERROR_STOP=1 < /root/massa/sql/contact_request.sql 2>&1

echo '=== table + policies ==='
$PSQL -c "select policyname, cmd, roles from pg_policies
          where tablename='contact_request';" 2>&1
$PSQL -c "select tgname from pg_trigger
          where tgrelid='public.contact_request'::regclass and not tgisinternal;" 2>&1

echo '=== notify url is set? (secret not printed) ==='
$PSQL -At -c "select value->>'url', (coalesce(value->>'secret','') <> '') as has_secret
              from app_settings where key='notify';" 2>&1

echo '=== restart edge functions so notify-admin picks up the new branch ==='
docker restart massa-edge-functions >/dev/null
sleep 6
docker ps --filter name=massa-edge-functions --format '{{.Names}} {{.Status}}'

echo '=== DONE ==='
