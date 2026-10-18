#!/bin/sh
# massa_push.sh 가 멀쩡한지 + 반복 발송이 도는지 한 번에 확인한다 (2026-10-18)
#
# 왜 이렇게 꼼꼼히 — 오늘 두 번 당했다.
#  1) PowerShell heredoc 으로 보냈더니 $ 가 전개돼 스크립트가 깨지고 시크릿이 박혔다.
#  2) 'tr -d "\r"' 로 CR 을 지우려다 PowerShell 이 \r 을 r 로 넘겨 알파벳 r 을 전부 지웠다.
#     (grep->gep, curl->cul, /root->/oot). 'NOTIFY_SECRET' 과 'sleep 30' 에는 r 이 없어서
#     그걸로 한 검증이 통과해 버렸다. r 이 들어간 단어로 검증해야 한다.
set -e
F=/root/massa_push.sh

echo '=== 1. r 이 지워지지 않았는가 (전부 1 이상이어야 한다) ==='
for w in curl grep '/root/massa/.env' '/var/log' 'x-notify-secret'; do
  printf '  %-20s ' "$w"; grep -c -- "$w" "$F" || true
done

echo '=== 2. CR 포함 여부 (0 이어야 한다) ==='
printf '  CR 줄 수: '; grep -c "$(printf '\r')" "$F" 2>/dev/null || echo 0

echo '=== 3. 문법 ==='
bash -n "$F" && echo '  OK'

echo '=== 4. 권한 ==='
ls -l "$F" | sed 's/^/  /'

echo '=== 5. 실행 (60초: 호출 → 30초 → 호출) ==='
/bin/bash "$F"
echo "  종료코드 $?"

echo '=== 6. 로그 꼬리 ==='
tail -3 /var/log/massa_push.log | sed 's/^/  /'

echo '=== 7. 테스트 알림 상태 ==='
docker exec -i massa-db psql -U postgres -d postgres -c \
 "select push_tries, push_result, pushed_at::time(0) as last, next_push_at::time(0) as next, now()::time(0) as now from notifications where title like 'TEST5%';"

echo '=== VERIFY DONE ==='
