#!/bin/sh
# 크론이 massa_push.sh 를 실제로 돌리고 있는지 확인한다
echo '=== 1. cron 데몬 ==='
(systemctl is-active cron 2>/dev/null || systemctl is-active crond 2>/dev/null || echo '확인불가') | sed 's/^/  /'

echo '=== 2. 등록된 항목 ==='
crontab -l | grep -n massa_push | sed 's/^/  /'

echo '=== 3. 파일 상태 ==='
ls -l /root/massa_push.sh | sed 's/^/  /'
head -1 /root/massa_push.sh | cat -A | sed 's/^/  shebang: /'

echo '=== 4. 최근 cron 실행 기록 (massa_push) ==='
grep -h massa_push /var/log/syslog /var/log/cron /var/log/cron.log 2>/dev/null | tail -5 | sed 's/^/  /' || echo '  로그 없음'

echo '=== 5. 로그 파일 쓰기 권한 ==='
ls -l /var/log/massa_push.log 2>/dev/null | sed 's/^/  /' || echo '  로그 파일 없음'

echo '=== 6. 크론과 같은 방식으로 직접 실행 ==='
/bin/bash /root/massa_push.sh
echo '  실행 완료 (종료코드 '$?')'
tail -2 /var/log/massa_push.log | sed 's/^/  /'
echo '=== CHECK DONE ==='
