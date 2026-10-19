#!/bin/sh
# ASCII only - the Korean version got mangled through the pipe and sed did nothing.
# Adds massa:// to GoTrue's redirect allow list so Google sign-in returns to the app.
ENV=/root/massa/.env

echo "=== 1. before ==="
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV"

python3 - "$ENV" <<'PY'
import sys, re, time, shutil
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
if 'massa://' in s:
    print("  already present")
else:
    shutil.copy(p, p + '.bak.' + str(int(time.time())))
    s = re.sub(r'^(ADDITIONAL_REDIRECT_URLS=.*)$',
               r'\1,massa://**,massa://auth', s, count=1, flags=re.M)
    open(p, 'w', encoding='utf-8').write(s)
    print("  added massa://** and massa://auth")
PY

echo "=== 2. after ==="
grep '^ADDITIONAL_REDIRECT_URLS=' "$ENV"

echo "=== 3. recreate auth container ==="
cd /root/massa
docker compose up -d --force-recreate auth 2>&1 | tail -3
sleep 8
docker compose ps auth 2>&1 | tail -2

echo "=== 4. value inside the container ==="
docker compose exec -T auth sh -c 'echo "$GOTRUE_URI_ALLOW_LIST"' 2>&1 | tr ',' '\n' | grep massa:// || echo "  NOT APPLIED"

echo "=== 5. auth endpoint alive ==="
curl -s -o /dev/null -w '  settings -> %{http_code}\n' https://app.massaviet.com/auth/v1/settings
echo "=== DONE ==="
