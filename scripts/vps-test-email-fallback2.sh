#!/bin/sh
# 메일 대체 확인 — 2단계(알림 넣기)까지는 이미 손으로 끝냈다. 호출·확인·치우기만 한다.
# ★ set -e 를 빼고 오류를 눈에 보이게 둔다 (앞 판에서 stderr 가 삼켜져 뭐가 깨졌는지 못 봤다).
PSQL="docker exec -i massa-db psql -U postgres -d postgres"
U_=9be8f740-9884-4257-ba0b-eece0a73d8d6
cd /root/massa

echo '=== 호출 전 상태 ==='
$PSQL -c "select kind, push_tries, pushed_at, push_result from notifications where user_id='$U_';"

echo '=== 발송기 직접 호출 ==='
S=$(grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2-)
URL=$($PSQL -t -A -c "select value->>'url' from app_settings where key='push';")
echo "  url: $URL"
curl -s -X POST "$URL" -H "x-notify-secret: $S" -H 'Content-Type: application/json' -d '{}'
echo ''

echo '=== 결과 — no_device+emailed 여야 한다 ==='
$PSQL -c "select kind, push_tries, push_result from notifications where user_id='$U_';"

echo '=== 치우기 ==='
$PSQL -c "delete from notifications where user_id='$U_';"
$PSQL -c "delete from auth.users where id='$U_';"
$PSQL -c "select count(*) as 남은_시험계정 from auth.users where email like 'karmadc070+pushtest%';"
echo '=== DONE ==='
