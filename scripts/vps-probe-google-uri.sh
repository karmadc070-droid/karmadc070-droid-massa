#!/bin/sh
# ASCII only. Would Google accept api.massaviet.com as a callback? Follow the redirect.
CID=823881120105-lsi766j30jepa3ss5r59bvve5a7pm4nm.apps.googleusercontent.com

probe() {
  U="$1"
  E=$(printf '%s' "$U" | sed 's|:|%3A|g; s|/|%2F|g')
  B="https://accounts.google.com/o/oauth2/v2/auth?client_id=$CID&response_type=code&scope=email+profile&redirect_uri=$E"
  curl -sL -o /tmp/g.out -w "  $U -> http %{http_code} final=%{url_effective}\n" "$B" | cut -c1-160
  if grep -qi 'redirect_uri_mismatch' /tmp/g.out; then echo "     !! redirect_uri_mismatch"; fi
  if grep -qi 'Error 400' /tmp/g.out; then echo "     !! Error 400"; fi
  grep -oiE 'redirect_uri_mismatch|Access blocked|oauth 정책|does not comply' /tmp/g.out | head -2 | sed 's/^/     /'
}

echo '=== google redirect_uri check ==='
probe "https://api.moahagwon.com/auth/v1/callback"
probe "https://api.massaviet.com/auth/v1/callback"
echo '=== DONE ==='
