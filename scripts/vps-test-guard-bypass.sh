#!/bin/sh
# 관리자 예외가 먹는지 + 마사지사 본인은 여전히 막히는지 — 롤백으로 안전하게 확인
# ★ 앞선 시도에서 '아무 권한 없는 사람'으로 테스트했더니 RLS 가 먼저 막아 UPDATE 0 이 나왔다.
#   그러면 트리거까지 가지도 않아 아무것도 증명하지 못한다. 본인 계정으로 해야 한다.
P=660cd0da-8007-4833-848f-1b54cecad1fc
ADMIN=$(docker exec massa-db psql -U postgres -d postgres -t -A \
  -c "select id from auth.users where email='karmadc070@gmail.com';")
OWNER=$(docker exec massa-db psql -U postgres -d postgres -t -A \
  -c "select coalesce(profile_id, owner_id) from providers where id='$P';")
echo "관리자 uid : $ADMIN"
echo "본인   uid : $OWNER"

echo '=== 1. 관리자로 승인 (통과해야 한다) ==='
docker exec -i massa-db psql -U postgres -d postgres <<SQL
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$ADMIN","role":"authenticated"}';
update providers set application_status='approved', is_active=true where id='$P';
rollback;
SQL

echo '=== 2. 마사지사 본인이 영업 켜기 — 기기가 없으므로 막혀야 한다 ==='
docker exec -i massa-db psql -U postgres -d postgres <<SQL
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"$OWNER","role":"authenticated"}';
update providers set is_active=true where id='$P';
rollback;
SQL
echo '--- 위에 ERROR: 알림을 켜야 ... 가 떴으면 규칙이 살아 있는 것이다 ---'
echo '=== DONE (전부 롤백, DB 는 그대로) ==='
