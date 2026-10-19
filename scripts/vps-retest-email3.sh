#!/bin/sh
# 메일 대체 재시험 (3판)
# ★ psql -t -A 로 RETURNING 을 받으면 뒤에 'INSERT 0 1' 명령 태그까지 붙어 나온다.
#   그대로 uuid 에 넣어 전부 깨졌다. head -1 로 첫 줄만 쓴다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+pushtest@gmail.com'
cd /root/massa

echo '=== 0. 남은 시험 계정 치우기 ==='
$PSQL -c "delete from notifications where user_id in (select id from auth.users where email='$TESTMAIL');" 2>&1
$PSQL -c "delete from auth.users where email='$TESTMAIL';" 2>&1

echo '=== 1. 임시 계정 ==='
U_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;" 2>&1 | head -1)
echo "  uid=[$U_]"

echo '=== 2. 알림 넣기 ==='
$PSQL -c "insert into notifications (user_id, title, body, kind)
          values ('$U_','Co lich dat moi','TEST - khong phai don that','booking_new');" 2>&1

echo '=== 3. 호출 ==='
S=$(grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2-)
URL=$($PSQL -t -A -c "select value->>'url' from app_settings where key='push';" 2>&1 | head -1)
curl -s -X POST "$URL" -H "x-notify-secret: $S" -H 'Content-Type: application/json' -d '{}'
echo ''
sleep 3

echo '=== 4. 결과 (no_device+emailed 여야 한다) ==='
$PSQL -c "select push_tries, push_result from notifications where user_id='$U_';" 2>&1

echo '=== 5. 실패 이유 ==='
docker compose logs --tail=80 functions 2>&1 | grep -i '메일실패' || echo '  (실패 로그 없음)'

echo '=== 6. 치우기 ==='
$PSQL -c "delete from notifications where user_id='$U_';" 2>&1
$PSQL -c "delete from auth.users where id='$U_';" 2>&1
$PSQL -t -A -c "select count(*) from auth.users where email='$TESTMAIL';" 2>&1 | head -1 | sed 's/^/  남은 시험계정: /'
echo '=== DONE ==='
