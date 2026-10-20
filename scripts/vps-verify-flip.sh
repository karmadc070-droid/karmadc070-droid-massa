#!/bin/sh
# ASCII only. Both flips applied. Is auth healthy, and does Google now return to the app?
echo '=== auth endpoint on each host ==='
curl -s -o /dev/null -w '  app.massaviet.com/auth/v1/settings -> %{http_code}\n' https://app.massaviet.com/auth/v1/settings
curl -s -o /dev/null -w '  api.massaviet.com/auth/v1/settings -> %{http_code}\n' https://api.massaviet.com/auth/v1/settings
curl -s -o /dev/null -w '  api.moahagwon.com/auth/v1/settings -> %{http_code}\n' https://api.moahagwon.com/auth/v1/settings

echo '=== providers the server reports ==='
curl -s https://api.massaviet.com/auth/v1/settings | head -c 300; echo

echo '=== does a google login now keep massa://auth as the return? ==='
curl -s -o /dev/null -D - "https://api.massaviet.com/auth/v1/authorize?provider=google&redirect_to=massa%3A%2F%2Fauth" \
  | grep -i '^location' | cut -c1-240

echo '=== channel the sender uses now ==='
grep -n 'channel_id\|sound:' /root/massa/volumes/functions/send-push/index.ts | head -4

echo '=== android sound file is in the live build? (repo side check) ==='
ls -l /root/massa 2>/dev/null | head -1
echo '=== DONE ==='
