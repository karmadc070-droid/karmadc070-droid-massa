#!/bin/sh
# 재촉 메일 스크립트 실제 발송 시험 (2판)
# ★ providers 는 guard_provider_kyc_insert 때문에 pending 으로만 만들 수 있다.
#   만든 뒤 approved 로 바꾼다 (is_active 는 false 라 푸시 규칙엔 안 걸린다).
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+nudge@gmail.com'
cd /root/massa

echo '=== 치우기(이전 잔여) ==='
$PSQL -c "delete from providers where display_name='ZZ 시험계정';" 2>&1
$PSQL -c "delete from auth.users where email='$TESTMAIL';" 2>&1

echo '=== 임시 마사지사 ==='
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
values ('$U_','masseur','ZZ 시험계정','pending',false,
        '{aroma}','{vi}',0,0,'바딘');" 2>&1
$PSQL -c "update providers set application_status='approved' where display_name='ZZ 시험계정';" 2>&1

echo '=== 대상 확인 (ZZ 시험계정 1명이어야 한다) ==='
$PSQL -c "select display_name, email from push_nudge_targets(3, 21);" 2>&1

echo '=== 스크립트 실행 ==='
bash /tmp/massa_nudge.sh
echo '--- 로그 ---'
tail -4 /var/log/massa_nudge.log

echo '=== 기록 확인 (sent_count=1) ==='
$PSQL -c "select sent_count, last_sent_at from push_nudges where user_id='$U_';" 2>&1

echo '=== 곧바로 또 돌려도 안 보내는가 (3시간 유예) ==='
bash /tmp/massa_nudge.sh
$PSQL -c "select sent_count from push_nudges where user_id='$U_';" 2>&1

echo '=== 치우기 ==='
$PSQL -c "delete from providers where display_name='ZZ 시험계정';" 2>&1
$PSQL -c "delete from push_nudges where user_id='$U_';" 2>&1
$PSQL -c "delete from auth.users where id='$U_';" 2>&1
$PSQL -c "select count(*) as 남은_시험계정 from auth.users where email='$TESTMAIL';" 2>&1
echo '=== DONE ==='
