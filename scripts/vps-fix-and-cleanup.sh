#!/bin/sh
# 1) send-push 파일이 실제로 어디 있는지 찾아 collapse 적용 여부 확인
# 2) 정리 안 된 A/B 테스트 알림이 계속 반복 발송되고 있다 — 지운다
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. send-push 실제 경로 ==='
find /root/massa -name 'index.ts' -path '*send-push*' 2>/dev/null | sed 's/^/  /'
F=$(find /root/massa -name 'index.ts' -path '*send-push*' 2>/dev/null | head -1)

if [ -n "$F" ]; then
  echo "=== 2. collapse 적용 여부 ($F) ==="
  for s in 'apns-collapse-id' 'collapseId' 'tag:'; do
    printf '  %-20s %s\n' "$s" "$(grep -c -- "$s" "$F" 2>/dev/null || echo 0)"
  done
else
  echo '  ★ send-push/index.ts 를 찾지 못했다'
fi

echo '=== 3. 지금 반복 중인 알림 ==='
$PSQL -c "select left(title,24) as title, kind, push_tries, is_read,
                 next_push_at::time(0) as next
          from notifications
          where next_push_at is not null and next_push_at <= now() + interval '5 minutes'
          order by next_push_at;"

echo '=== 4. 테스트 찌꺼기 삭제 ==='
$PSQL -c "delete from notifications where title like 'ABTEST%' or title like 'TEST%'
          or title like 'WAIT%' or title like 'Chúc mừng%';" | sed 's/^/  /'

echo '=== 5. 삭제 후 남은 반복 대상 (0 이어야 조용해진다) ==='
$PSQL -t -A -c "select count(*) from notifications where next_push_at is not null and next_push_at <= now();" | sed 's/^/  /'

echo '=== 6. 실제 알림 현황 ==='
$PSQL -c "select kind, coalesce(push_result,'(미발송)') as push_result, count(*)
          from notifications group by 1,2 order by 3 desc;"
echo '=== DONE ==='
