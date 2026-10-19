#!/bin/sh
# ASCII only. Take massa:// back out of the GoTrue allow list (2026-10-20).
#
# Why: with massa:// allowed, GoTrue redirects a social login to massa://auth.
# Android 1.1.103 has no intent-filter for that scheme, so Chrome cannot open it
# and shows the raw 302 body -- the word "Found". Without it, GoTrue falls back to
# SITE_URL and the login at least completes on the web.
#
# PUT THIS BACK the moment Play 1.1.105 is live. That build has the intent-filter.
# Re-apply with scripts/vps-allow-app-scheme2.sh, and flip the push channel to
# massa_booking_v2 at the same time (scripts/vps-patch-push-sound.sh).
set -u
ENV=/root/massa/.env

echo '=== before ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV" | cut -d= -f2- | tr ',' '\n' | sed 's/^/  /'

cp "$ENV" "$ENV.bak.scheme.$(date +%Y%m%d%H%M%S)"
python3 - "$ENV" <<'PY'
import sys
p = sys.argv[1]
out, hit = [], 0
for line in open(p, encoding='utf-8'):
    if line.startswith('ADDITIONAL_REDIRECT_URLS='):
        key, _, val = line.rstrip('\n').partition('=')
        items = [x for x in val.split(',') if x.strip()]
        kept = [x for x in items if not x.strip().startswith('massa://')]
        hit = len(items) - len(kept)
        line = key + '=' + ','.join(kept) + '\n'
    out.append(line)
open(p, 'w', encoding='utf-8').write(''.join(out))
print("removed", hit, "massa:// entries")
PY

echo '=== after ==='
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV" | cut -d= -f2- | tr ',' '\n' | sed 's/^/  /'

echo '=== restart auth ==='
cd /root/massa && docker compose up -d auth < /dev/null 2>&1 | tail -3
sleep 8
docker ps --format '{{.Names}} {{.Status}}' | grep massa-auth

echo '=== what the container now allows ==='
docker exec massa-auth sh -c 'echo "$GOTRUE_URI_ALLOW_LIST"' < /dev/null 2>&1 | tr ',' '\n' | sed 's/^/  /'

echo '=== does a social login still head to massa:// ? ==='
curl -s -o /dev/null -D - "https://api.massaviet.com/auth/v1/authorize?provider=google&redirect_to=massa%3A%2F%2Fauth" | grep -i '^location' | cut -c1-200
echo '=== DONE ==='
