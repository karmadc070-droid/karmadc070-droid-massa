#!/bin/sh
# 메일 대체가 실제로 나가는지 끝까지 확인한다 (2026-10-19)
#
# ★ 실제 마사지사에게 시험 메일을 보내지 않는다. 사장님 받은편지함으로 가는
#   임시 계정(karmadc070+pushtest@gmail.com)을 만들어 쓰고, 끝나면 지운다.
# ★ 시크릿은 서버 안에서만 읽고 화면에 찍지 않는다.
set -e
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+pushtest@gmail.com'

echo '=== 1. 임시 계정 만들기 (기기 0개) ==='
UID_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;")
echo "  uid: $UID_"

echo '=== 2. 예약 알림 한 건 넣기 ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
values ('$UID_', 'Có lịch đặt mới',
        'TEST — 09:20 19/10, Aroma Land, 600.000d. Day la thu nghiem, khong phai don that.',
        'booking_new');"

echo '=== 3. 발송기 직접 호출 ==='
cd /root/massa
S=$(grep -E '^NOTIFY_SECRET=' .env | cut -d= -f2-)
U=$(grep -E '^PUSH_FN_URL=' .env | cut -d= -f2-)
[ -n "$U" ] || U=$($PSQL -t -A -c "select value->>'url' from app_settings where key='push';")
curl -s -X POST "$U" -H "x-notify-secret: $S" -H 'Content-Type: application/json' -d '{}'
echo ''

echo '=== 4. 결과 — push_result 가 no_device+emailed 여야 한다 ==='
$PSQL -c "select kind, push_tries, push_result from notifications where user_id='$UID_';"

echo '=== 5. 치우기 (알림·계정 삭제) ==='
$PSQL -c "delete from notifications where user_id='$UID_';"
$PSQL -c "delete from auth.users where id='$UID_';"
$PSQL -c "select count(*) as 남은_시험계정 from auth.users where email='$TESTMAIL';"
echo '=== DONE ==='
