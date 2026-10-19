#!/bin/sh
# 재촉 메일 스크립트를 실제로 돌려 본다 (2026-10-19)
#
# ★ 12명은 오늘 이미 같은 내용을 두 번 받았다. 그걸 1회차로 쳐서 기록해 두면
#   자동 발송은 3시간 뒤부터 시작된다. 그래야 지금 시험한다고 또 날아가지 않는다.
# ★ 시험은 사장님 받은편지함으로 가는 임시 마사지사 한 명으로만 한다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+nudge@gmail.com'
cd /root/massa

echo '=== 1. 오늘 보낸 메일을 1회차로 기록 (3시간 유예) ==='
$PSQL -c "
insert into push_nudges (user_id, sent_count, last_sent_at)
select user_id, 1, now() from push_nudge_targets(3, 21)
on conflict (user_id) do nothing;" 2>&1
$PSQL -c "select count(*) as 지금_대상자_0이어야함 from push_nudge_targets(3, 21);" 2>&1

echo '=== 2. 시험용 임시 마사지사 ==='
$PSQL -c "delete from providers where display_name='ZZ 시험계정';" 2>&1
$PSQL -c "delete from auth.users where email='$TESTMAIL';" 2>&1
U_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;" 2>&1 | head -1)
echo "  uid=[$U_]"
$PSQL -c "
insert into providers (profile_id, kind, display_name, application_status, is_active,
                       specialties, languages, rating, review_count, base_district)
values ('$U_','masseur','ZZ 시험계정','approved',false,
        '{aroma}','{vi}',0,0,'바딘');" 2>&1

echo '=== 3. 대상에 잡히는가 (1명이어야 한다) ==='
$PSQL -c "select display_name, email from push_nudge_targets(3, 21);" 2>&1

echo '=== 4. 스크립트 실행 ==='
bash /tmp/massa_nudge.sh
echo '--- 로그 ---'
tail -5 /var/log/massa_nudge.log

echo '=== 5. 기록됐는가 ==='
$PSQL -c "select n.sent_count, n.last_sent_at from push_nudges n where n.user_id='$U_';" 2>&1

echo '=== 6. 치우기 ==='
$PSQL -c "delete from providers where display_name='ZZ 시험계정';" 2>&1
$PSQL -c "delete from push_nudges where user_id='$U_';" 2>&1
$PSQL -c "delete from auth.users where id='$U_';" 2>&1
$PSQL -c "select count(*) as 남은_시험계정 from auth.users where email='$TESTMAIL';" 2>&1
echo '=== DONE ==='
