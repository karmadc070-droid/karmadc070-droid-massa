#!/bin/sh
# 테스트 계정이 남긴 안전 요청 3건을 닫는다 (2026-10-18)
#
# 왜 닫아도 되는가 — 3건 모두 demo@massa.app(Thanh hà, 테스트 계정)이 오늘 17:42 에 보냈고
# 예약·위치·메모가 전부 비어 있다. 실제 위급 상황이 아니라 기능 점검 흔적이다.
# ★ 실제 사용자의 sos 는 이렇게 일괄 처리하지 않는다. 반드시 건별로 확인한다.
set -e
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 닫기 전 — 대상 확인 (테스트 계정 것만) ==='
$PSQL -c "
select s.id, s.kind, s.status, u.email
from safety_alerts s join auth.users u on u.id=s.user_id
where s.status='open' and u.email='demo@massa.app';"

echo '=== 혹시 테스트 계정 외에 열린 건이 있는가 (있으면 건드리지 않는다) ==='
$PSQL -c "
select coalesce(u.email,'(계정없음)') as 계정, s.kind, count(*)
from safety_alerts s left join auth.users u on u.id=s.user_id
where s.status='open' and coalesce(u.email,'') <> 'demo@massa.app'
group by 1,2;"

echo '=== 닫기 (테스트 계정 것만) ==='
$PSQL -c "
update safety_alerts s set status='closed'
from auth.users u
where u.id = s.user_id and s.status='open' and u.email='demo@massa.app';"

echo '=== 닫은 뒤 ==='
$PSQL -c "select status, count(*) from safety_alerts group by 1 order by 1;"
echo '=== DONE ==='
