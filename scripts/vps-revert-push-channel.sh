#!/bin/sh
# ASCII only. Put the android channel_id back to the one the LIVE app actually has.
# Why: the server was switched to massa_booking_v2 at 20:59, but that channel only
# exists in 1.1.105, which is still in review. Android silently drops a push whose
# channel does not exist, so every android therapist on 1.1.103 stopped being notified.
# Flip this back to _v2 only AFTER 1.1.105 is live on Play.
F=/root/massa/volumes/functions/send-push/index.ts

echo '=== before ==='
grep -n 'channel_id' "$F"

cp "$F" "$F.bak.channel.$(date +%Y%m%d%H%M%S)"
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.count('"massa_booking_v2"')
s = s.replace('"massa_booking_v2"', '"massa_booking"')
open(p, 'w', encoding='utf-8').write(s)
print("replaced", n)
PY

echo '=== after ==='
grep -n 'channel_id' "$F"

echo '=== restart functions ==='
docker restart massa-functions < /dev/null 2>&1 | tail -1
sleep 6
docker ps --format '{{.Names}} {{.Status}}' | grep massa-functions
echo '=== DONE ==='
