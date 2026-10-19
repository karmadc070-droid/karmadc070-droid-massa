#!/bin/sh
# 예약 알림은 30초마다 10번 재시도한다. 그때마다 메일이 가면 한 건에 10통이다.
# 첫 시도에만 가는지 3분 지켜본다.
PSQL="docker exec -i massa-db psql -U postgres -d postgres"
TESTMAIL='karmadc070+pushonce@gmail.com'

$PSQL -c "delete from notifications where user_id in (select id from auth.users where email='$TESTMAIL');" 2>&1 >/dev/null
$PSQL -c "delete from auth.users where email='$TESTMAIL';" 2>&1 >/dev/null

U_=$($PSQL -t -A -c "
insert into auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(), 'authenticated','authenticated',
        '$TESTMAIL', '', now(), now(), now(), '{\"provider\":\"email\"}'::jsonb, '{}'::jsonb)
returning id;" 2>&1 | head -1)
echo "uid=$U_"
$PSQL -c "insert into notifications (user_id, title, body, kind)
          values ('$U_','Co lich dat moi','TEST once','booking_new');" 2>&1

echo '=== 3분 동안 30초마다 상태 ==='
i=0
while [ $i -lt 6 ]; do
  sleep 30; i=$((i+1))
  $PSQL -t -A -c "select '  ' || (${i}*30) || '초 — tries=' || push_tries || ' result=' || coalesce(push_result,'-')
                  from notifications where user_id='$U_';" 2>&1 | head -1
done

echo '=== 치우기 ==='
$PSQL -c "delete from notifications where user_id='$U_';" 2>&1
$PSQL -c "delete from auth.users where id='$U_';" 2>&1
echo '--- 메일은 1통만 왔어야 한다 (tries 는 올라가도 result 가 emailed 로 한 번만 바뀜) ---'
echo '=== DONE ==='
