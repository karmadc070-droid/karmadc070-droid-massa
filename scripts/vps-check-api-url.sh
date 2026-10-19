#!/bin/sh
# ASCII only. Why does GoTrue hand Google the moahagwon callback?
ENV=/root/massa/.env
echo '=== external url / site url in .env ==='
grep -nE '^(GOTRUE_)?(API_EXTERNAL_URL|SITE_URL|EXTERNAL_GOOGLE|EXTERNAL_KAKAO|EXTERNAL_APPLE)' "$ENV"
echo '=== what the running auth container thinks ==='
docker exec massa-auth sh -c 'echo "API_EXTERNAL_URL=$API_EXTERNAL_URL"; echo "GOTRUE_API_EXTERNAL_URL=$GOTRUE_API_EXTERNAL_URL"; echo "SITE_URL=$GOTRUE_SITE_URL"' < /dev/null 2>&1
echo '=== docker-compose auth env lines ==='
grep -n -A3 'API_EXTERNAL_URL' /root/massa/docker-compose.yml | head -20
echo '=== does the old host still answer, and whose auth is it? ==='
curl -s https://api.moahagwon.com/auth/v1/settings 2>&1 | head -c 200; echo
echo '=== DONE ==='
