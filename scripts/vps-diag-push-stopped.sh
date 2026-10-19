#!/bin/sh
# 푸시 발송기가 11:21 이후 로그를 안 남긴다 — 왜인지 찾는다 (2026-10-19)
echo "지금: $(date -Is)"
echo '=== 1. 스크립트가 있는가 ==='
ls -l /root/massa_push.sh
echo '=== 2. 손으로 돌려 본다 (출력 그대로) ==='
bash -x /root/massa_push.sh 2>&1 | tail -25
echo '=== 3. 로그 마지막 ==='
tail -3 /var/log/massa_push.log
echo '=== 4. functions 컨테이너 상태 ==='
cd /root/massa && docker compose ps functions
echo '=== 5. 크론 데몬이 살아 있나 ==='
systemctl is-active cron 2>/dev/null || service cron status 2>&1 | head -3
echo '=== 6. 크론이 실행은 했는가 (syslog) ==='
grep massa_push /var/log/syslog 2>/dev/null | tail -3 || echo '  (syslog 없음)'
echo '=== DONE ==='
