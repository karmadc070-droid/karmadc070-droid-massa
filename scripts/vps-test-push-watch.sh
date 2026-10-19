#!/bin/sh
# 3단계 — 푸시가 실제로 나갔는지 본다 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 0. notifications 칼럼 ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='notifications' order by ordinal_position;" 2>&1

echo '=== 1. 방금 알림의 상태 ==='
$PSQL -c "select * from notifications where created_at > now() - interval '10 minutes';" 2>&1

echo '=== 2. 푸시 발송기 로그 (마지막 10줄) ==='
tail -10 /var/log/massa_push.log 2>&1 || echo '  (로그 없음)'

echo '=== 3. 발송기를 지금 한 번 돌린다 ==='
bash /root/massa_push.sh 2>&1 | tail -20

echo '=== 4. 돌린 뒤 알림 상태 ==='
$PSQL -c "select id, kind, push_tries from notifications
          where created_at > now() - interval '10 minutes';" 2>&1
echo '=== DONE ==='
