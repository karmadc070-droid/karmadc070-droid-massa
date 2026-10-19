#!/bin/sh
# 어느 토큰이 방금 등록됐나 — 지금 그 폰이 어느 계정으로 붙어 있는지 가린다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 토큰을 최근 갱신 순으로 ==='
$PSQL -c "
select u.email, t.platform, left(t.token,14) as head, t.lang,
       to_char(t.updated_at at time zone 'Asia/Seoul','MM-DD HH24:MI:SS') as updated
from push_tokens t join auth.users u on u.id = t.user_id
order by t.updated_at desc nulls last;" 2>&1

echo '=== 최근 30분 안에 갱신된 것만 ==='
$PSQL -c "
select u.email, t.platform, left(t.token,14) as head
from push_tokens t join auth.users u on u.id = t.user_id
where t.updated_at > now() - interval '40 minutes';" 2>&1

echo '=== 오늘 앱 접속 기록 (platform 별) ==='
$PSQL -c "
select platform, role, is_member, count(*),
       to_char(max(created_at) at time zone 'Asia/Seoul','HH24:MI') as last
from app_visit where created_at > now() - interval '2 hours'
group by 1,2,3 order by 5 desc;" 2>&1
echo '=== DONE ==='
