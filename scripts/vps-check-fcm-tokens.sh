#!/bin/sh
# 네이티브(FCM) 토큰이 실제로 등록된 적이 있는가 — 소리 문제의 핵심 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 플랫폼별 토큰 수 ==='
$PSQL -c "select platform, count(*) from push_tokens group by 1 order by 2 desc;" 2>&1

echo '=== 2. 누가 어떤 플랫폼으로 등록했나 ==='
$PSQL -c "select u.email, t.platform, count(*)
          from push_tokens t join auth.users u on u.id = t.user_id
          group by 1,2 order by 1;" 2>&1

echo '=== 3. android 토큰 생김새 (FCM 토큰은 길고 콜론이 들어 있다) ==='
$PSQL -c "select platform, length(token) as len, left(token, 20) as head
          from push_tokens where platform <> 'web' limit 5;" 2>&1
echo '=== DONE ==='
