#!/bin/sh
# 로그를 켠 뒤 메일 대체를 다시 시험하고, 실패 이유를 컨테이너 로그에서 읽는다
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+pushtest@gmail.com'
cd /root/massa

echo '=== 임시 계정 ==='
U_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;")
echo "  uid: $U_"

$PSQL -c "insert into notifications (user_id, title, body, kind)
          values ('$U_','Co lich dat moi','TEST - khong phai don that','booking_new');"

echo '=== 호출 ==='
S=$(grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2-)
URL=$($PSQL -t -A -c "select value->>'url' from app_settings where key='push';")
curl -s -X POST "$URL" -H "x-notify-secret: $S" -H 'Content-Type: application/json' -d '{}'
echo ''
sleep 3

echo '=== 결과 ==='
$PSQL -c "select push_tries, push_result from notifications where user_id='$U_';"

echo '=== 실패 이유 (컨테이너 로그) ==='
docker compose logs --tail=40 functions 2>&1 | grep -i '메일실패' || echo '  (메일실패 로그 없음 — 성공했거나 아직 안 찍힘)'

echo '=== 치우기 ==='
$PSQL -c "delete from notifications where user_id='$U_';" >/dev/null
$PSQL -c "delete from auth.users where id='$U_';" >/dev/null
$PSQL -t -A -c "select count(*) from auth.users where email='$TESTMAIL';" | sed 's/^/  남은 시험계정: /'
echo '=== DONE ==='
