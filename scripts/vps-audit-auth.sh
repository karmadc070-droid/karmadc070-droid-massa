#!/bin/sh
# ASCII only. Auth / app-web wiring audit (2026-10-19).
ENV=/root/massa/.env

echo "=== 1. which social providers are enabled on the server ==="
curl -s https://app.massaviet.com/auth/v1/settings | tr ',' '\n' | grep -iE 'google|kakao|apple|email|phone' | sed 's/^/  /'

echo "=== 2. email confirmation required? ==="
grep -iE '^(GOTRUE_)?(MAILER_AUTOCONFIRM|DISABLE_SIGNUP|ENABLE_EMAIL_AUTOCONFIRM|ENABLE_CONFIRMATIONS)' "$ENV" || echo "  (not set in .env)"
docker compose -f /root/massa/docker-compose.yml exec -T auth sh -c 'echo "AUTOCONFIRM=$GOTRUE_MAILER_AUTOCONFIRM SIGNUP=$GOTRUE_DISABLE_SIGNUP"' < /dev/null 2>&1

echo "=== 3. redirect allow list (one per line) ==="
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV" | cut -d= -f2- | tr ',' '\n' | sed 's/^/  /'

echo "=== 4. is reset.html allowed? is api.moahagwon.com still alive? ==="
curl -s -o /dev/null -w '  app.massaviet.com/reset.html -> %{http_code}\n' https://app.massaviet.com/reset.html
curl -s -o /dev/null -w '  api.moahagwon.com/auth/v1/settings -> %{http_code}\n' https://api.moahagwon.com/auth/v1/settings
curl -s -o /dev/null -w '  api.massaviet.com/auth/v1/settings -> %{http_code}\n' https://api.massaviet.com/auth/v1/settings

echo "=== 5. external provider redirect URI that Google/Kakao must have registered ==="
echo "  https://api.massaviet.com/auth/v1/callback"
grep -iE '^(GOTRUE_)?EXTERNAL_(GOOGLE|KAKAO|APPLE)_(ENABLED|REDIRECT_URI)' "$ENV" || echo "  (external provider vars not in .env)"

echo "=== 6. how many users signed up with each provider ==="
docker exec massa-db psql -U postgres -d postgres -c "
select coalesce(raw_app_meta_data->>'provider','?') as provider,
       count(*) as users,
       count(*) filter (where email_confirmed_at is null) as unconfirmed
from auth.users group by 1 order by 2 desc;" 2>&1

echo "=== DONE ==="
