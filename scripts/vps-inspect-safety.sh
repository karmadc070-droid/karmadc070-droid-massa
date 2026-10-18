#!/bin/sh
# 미처리 안전 요청 3건이 무엇인지 확인한다. sos 가 섞여 있어 내용을 모르고 처리하면 안 된다.
PSQL="docker exec -i massa-db psql -U postgres -d postgres"

echo '=== 관련 테이블 ==='
$PSQL -c "select table_name from information_schema.tables
          where table_schema='public' and table_name ~ 'safety|sos|report' order by 1;"

echo '=== safety 요청 전체 (컬럼 그대로) ==='
$PSQL -c "select * from safety_requests order by created_at desc limit 10;" 2>/dev/null \
  || $PSQL -c "select table_name, column_name from information_schema.columns
               where table_name ~ 'safety' order by table_name, ordinal_position;"

echo '=== 누가 보냈나 (사용자 연결) ==='
$PSQL -c "
select s.id, s.kind, s.created_at at time zone 'Asia/Ho_Chi_Minh' as 하노이시각,
       s.handled_at, u.email, coalesce(p.display_name,'(고객)') as 이름
from safety_requests s
left join auth.users u on u.id = s.user_id
left join providers p on p.profile_id = s.user_id
order by s.created_at desc limit 10;" 2>/dev/null || echo '  (컬럼 구성이 달라 조회 실패 — 위 목록 참고)'

echo '=== DONE ==='
