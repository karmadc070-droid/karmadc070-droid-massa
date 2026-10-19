#!/bin/sh
# 메일 대체 재시험 (4판) — 직접 호출 대신 크론을 기다린다
# ★ app_settings 의 URL(massa-edge-functions:9000)은 도커 네트워크 안에서만 풀린다.
#   호스트에서 curl 하면 아무 응답도 없이 끝나서 아무것도 확인되지 않았다.
#   크론(/root/massa_push.sh)이 매분 도니까 그걸 기다린다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+pushtest@gmail.com'
cd /root/massa

echo '=== 0. 남은 시험 계정 치우기 ==='
$PSQL -c "delete from notifications where user_id in (select id from auth.users where email='$TESTMAIL');" 2>&1
$PSQL -c "delete from auth.users where email='$TESTMAIL';" 2>&1

echo '=== 1. 임시 계정 + 알림 ==='
U_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;" 2>&1 | head -1)
echo "  uid=[$U_]"
$PSQL -c "insert into notifications (user_id, title, body, kind)
          values ('$U_','Co lich dat moi','TEST - khong phai don that','booking_new');" 2>&1

echo '=== 2. 크론 기다리기 (최대 100초) ==='
i=0
while [ $i -lt 20 ]; do
  sleep 5; i=$((i+1))
  R=$($PSQL -t -A -c "select coalesce(push_result,'') from notifications where user_id='$U_';" 2>&1 | head -1)
  [ -n "$R" ] && { echo "  ${i}0초쯤 결과: $R"; break; }
done

echo '=== 3. 결과 (no_device+emailed 여야 한다) ==='
$PSQL -c "select push_tries, push_result from notifications where user_id='$U_';" 2>&1

echo '=== 4. 실패 이유 ==='
docker compose logs --tail=120 functions 2>&1 | grep -i '메일실패' | tail -5 || echo '  (실패 로그 없음)'

echo '=== 5. 치우기 ==='
$PSQL -c "delete from notifications where user_id='$U_';" 2>&1
$PSQL -c "delete from auth.users where id='$U_';" 2>&1
$PSQL -t -A -c "select count(*) from auth.users where email='$TESTMAIL';" 2>&1 | head -1 | sed 's/^/  남은 시험계정: /'
echo '=== DONE ==='
