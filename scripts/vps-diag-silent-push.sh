#!/bin/sh
# 알림이 아예 안 떴다 — 어디서 끊겼는지 찾는다 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. push_tokens 칼럼 (언제 등록됐는지 알 수 있나) ==='
$PSQL -c "select column_name, data_type from information_schema.columns
          where table_name='push_tokens' order by ordinal_position;" 2>&1

echo '=== 2. 토큰 전체 ==='
$PSQL -c "select u.email, t.platform, left(t.token,16) as head, t.lang
          from push_tokens t join auth.users u on u.id = t.user_id
          order by u.email;" 2>&1

echo '=== 3. 최근 앱 접속 — 지금 어느 계정이 쓰고 있나 ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='app_visit' order by ordinal_position;" 2>&1

echo '=== 4. 알림 발송 기록 ==='
$PSQL -c "select id, user_id, kind, push_tries, push_result,
                 to_char(pushed_at at time zone 'Asia/Seoul','HH24:MI:SS') as pushed
          from notifications
          where created_at > now() - interval '30 minutes'
          order by created_at;" 2>&1
echo '=== DONE ==='
