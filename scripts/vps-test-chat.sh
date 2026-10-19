#!/bin/sh
# 채팅 양방향 확인 — 마사지사가 보낸 글이 들어왔는지 보고, 손님 이름으로 답장을 넣는다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
CUST='adec3c30-746b-47db-bd8d-53ae164a142c'   # demo@massa.app
PROV='47482472-7f32-4d7e-af2b-e97bd5dd83f5'   # [TEST] massa owner

echo '=== 1. 지금까지의 대화 ==='
$PSQL -c "select sender_role, body, created_at at time zone 'Asia/Seoul' as t
          from messages where customer_id='$CUST' and provider_id='$PROV'
          order by created_at;" 2>&1

echo '=== 2. 손님 이름으로 답장 ==='
$PSQL -c "insert into messages (customer_id, provider_id, sender_role, body)
          values ('$CUST', '$PROV', 'customer', 'Xin chao! Toi la khach. (demo customer reply)')
          returning id, sender_role, body;" 2>&1

echo '=== 3. 다시 읽기 ==='
$PSQL -c "select sender_role, body from messages
          where customer_id='$CUST' and provider_id='$PROV' order by created_at;" 2>&1
echo '=== DONE ==='
