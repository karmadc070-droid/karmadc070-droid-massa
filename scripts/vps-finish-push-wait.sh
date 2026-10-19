#!/bin/sh
# 6단계(기기가 생기면 집히는가) 마무리 + 정리
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== push_tokens 구조 ==='
$PSQL -c "select column_name, is_nullable, column_default from information_schema.columns
          where table_name='push_tokens' order by ordinal_position;"

echo '=== 토큰 삽입 시도 (오류가 나면 그대로 보여준다) ==='
$PSQL -c "
insert into push_tokens (user_id, token, platform, lang)
select id, 'WAITTEST-FAKE-TOKEN', 'web', 'vi' from auth.users where email='trinh1111ttt@gmail.com';"

echo '=== 기기가 생긴 뒤 집히는가 (1 이어야 정상) ==='
$PSQL -c "update notifications set next_push_at = now() - interval '1 minute' where title like 'WAITTEST%';"
$PSQL -t -A -c "select count(*) from claim_unpushed_notifications() where title like 'WAITTEST%';" \
  | sed 's/^/  집힌 건수: /'

echo '=== 정리 ==='
$PSQL -c "delete from push_tokens where token='WAITTEST-FAKE-TOKEN';"
$PSQL -c "delete from notifications where title like 'WAITTEST%';"

echo '=== 남은 테스트 흔적 확인 (0 이어야 한다) ==='
$PSQL -t -A -c "select count(*) from notifications where title like 'WAITTEST%' or title like 'TEST%';" | sed 's/^/  /'
$PSQL -t -A -c "select count(*) from push_tokens where token like 'WAITTEST%';" | sed 's/^/  /'
echo '=== DONE ==='
