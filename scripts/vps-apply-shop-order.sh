#!/bin/sh
# ASCII only. Install shop_order table + guard + notify trigger, deploy the notify-admin
# function that has the shop_order branch, then prove anon insert works and read is blocked.
# Needs /root/massa/sql/shop_order.sql and /root/massa/notify-admin.index.ts copied first.
set -e
PSQL="docker exec -i massa-db psql -U postgres -d postgres"
FN=/root/massa/volumes/functions/notify-admin/index.ts

echo '=== apply sql ==='
$PSQL -v ON_ERROR_STOP=1 < /root/massa/sql/shop_order.sql 2>&1
$PSQL -c "select policyname, cmd, roles from pg_policies where tablename='shop_order';" 2>&1

echo '=== function ==='
cp "$FN" "$FN.bak.$(date +%Y%m%d%H%M)"
cp /root/massa/notify-admin.index.ts "$FN"
grep -c 'action === "shop_order"' "$FN"
docker restart massa-edge-functions >/dev/null
sleep 6
docker ps --filter name=massa-edge-functions --format '{{.Names}} {{.Status}}'

echo '=== anon can insert, cannot read (rolled back, no mail) ==='
$PSQL -v ON_ERROR_STOP=1 <<'SQL' 2>&1
begin;
alter table public.shop_order disable trigger trg_notify_shop_order;
set local role anon;
insert into public.shop_order (items, total_vnd, name, phone, address, lang)
  values ('[{"id":"t","name":"t","price":1,"qty":1}]', 1, 'test', '0', 'test', 'vi');
select count(*) as anon_can_see from public.shop_order;
reset role;
rollback;
SQL
echo '=== DONE ==='
