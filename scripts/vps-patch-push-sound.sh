#!/bin/sh
# 서버가 새 알림음 채널로 보내도록 고친다 (2026-10-19).
# 안드로이드는 채널이 소리를 정한다. 채널 설정은 한 번 만들어지면 고정이라
# 앱에서 id 를 massa_booking_v2 로 올렸고, 서버도 같은 id 를 실어 보내야 한다.
# iOS 는 건드리지 않는다 — 번들에 massa.caf 가 들어간 빌드가 올라간 뒤에 바꾼다.
F=/root/massa/volumes/functions/send-push/index.ts

echo '=== 1. 바꾸기 전 ==='
grep -n 'channel_id\|default_sound' "$F"

cp "$F" "$F.bak.$(date +%s)"
sed -i 's/channel_id: "massa_booking"/channel_id: "massa_booking_v2"/' "$F"
sed -i 's/default_sound: true,/sound: "massa",   \/\/ Android 7.1 이하용. 8.0+ 는 채널이 정한다/' "$F"

echo '=== 2. 바꾼 뒤 ==='
grep -n 'channel_id\|sound:' "$F"

echo '=== 3. 함수 다시 올리기 ==='
cd /root/massa && docker compose restart functions 2>&1 | tail -3
sleep 5
docker compose ps functions 2>&1 | tail -2
echo '=== DONE ==='
