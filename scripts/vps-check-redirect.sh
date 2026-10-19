#!/bin/sh
# ASCII only. Where does GoTrue send a Google login back to, and is massa:// allowed?
ENV=/root/massa/.env
echo '=== allow list ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV" | cut -d= -f2- | tr ',' '\n' | sed 's/^/  /'
echo '=== SITE_URL ==='
grep -E '^(GOTRUE_)?SITE_URL=' "$ENV"
echo '=== what the server answers for redirect_to=massa://auth ==='
curl -s -o /dev/null -D - "https://api.massaviet.com/auth/v1/authorize?provider=google&redirect_to=massa%3A%2F%2Fauth" | head -5
echo '=== DONE ==='
