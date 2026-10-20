#!/bin/sh
# ASCII only. Are the two rollbacks from last night still in place?
ENV=/root/massa/.env
F=/root/massa/volumes/functions/send-push/index.ts

echo '=== 1. massa:// in the allow list? (rolled back = absent) ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV" | tr ',' '\n' | grep 'massa://' || echo '  absent (still rolled back)'

echo '=== 2. which android channel does the server send? (rolled back = massa_booking) ==='
grep -n 'channel_id\|default_sound\|sound:' "$F"

echo '=== 3. compose service names (so restarts target the right thing) ==='
cd /root/massa && docker compose ps --services 2>&1 | tr '\n' ' '; echo

echo '=== 4. devices that could be affected if we flip now ==='
docker exec massa-db psql -U postgres -d postgres -c "
select u.email, t.platform, count(*) as devices,
       to_char(max(t.updated_at) at time zone 'Asia/Seoul','MM-DD HH24:MI') as last_seen
from push_tokens t join auth.users u on u.id=t.user_id
group by 1,2 order by 4 desc;" 2>&1
echo '=== DONE ==='
