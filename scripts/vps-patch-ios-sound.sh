#!/bin/sh
# ⚠ 1.0.18 이 TestFlight·앱스토어에 올라간 뒤에 돌린다.
#
# APNs 는 aps.sound 로 적은 파일을 앱 번들에서 찾는다. 번들에 massa.caf 가 없는
# 버전을 쓰는 사람에게 이 값을 보내면 소리가 안 나거나 기본음으로 떨어진다.
# 그래서 번들에 들어간 빌드가 사용자 손에 가기 전에는 'default' 로 둔다.
F=/root/massa/volumes/functions/send-push/index.ts

echo '=== 1. 지금 값 ==='
grep -n 'sound: "default"' "$F"

cp "$F" "$F.bak.$(date +%s)"
sed -i 's/sound: "default"/sound: "massa.caf"/' "$F"

echo '=== 2. 바꾼 뒤 ==='
grep -n 'aps:' "$F"

echo '=== 3. 함수 다시 올리기 ==='
cd /root/massa && docker compose restart functions 2>&1 | tail -2
sleep 5
docker compose ps functions 2>&1 | tail -1
echo '=== DONE ==='
