#!/bin/sh
# ASCII only. The sender stopped logging at 01:23. Why? (2026-10-20 05:32)
echo '=== cron entries ==='
crontab -l 2>&1 | grep -i 'massa\|push' || echo "  (no matching crontab line)"

echo '=== is cron even running? ==='
service cron status 2>&1 | head -3 || systemctl is-active cron 2>&1

echo '=== cron log for massa_push ==='
grep -i 'massa_push' /var/log/syslog 2>/dev/null | tail -5 || echo "  (no syslog entries)"

echo '=== log file state ==='
ls -l /var/log/massa_push.log
echo '--- last 3 lines ---'
tail -3 /var/log/massa_push.log

echo '=== run it by hand and see what happens ==='
bash /root/massa_push.sh 2>&1 | tail -3
echo '--- log after the manual run ---'
tail -3 /var/log/massa_push.log
echo '=== DONE ==='
