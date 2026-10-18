#!/bin/sh
# massa 정산 요약 메일 (VPS /root/massa_digest.sh, 크론 0 0 * * *). 시크릿은 실행할 때 /root/massa/.env 에서 읽는다.
# 파일에 시크릿을 박지 않으므로 vps-rotate-notify-secret.sh 로 교체해도 이 파일은 고칠 필요가 없다.
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
curl -s -X POST http://localhost:8002/functions/v1/notify-admin \
  -H "Content-Type: application/json" -H "x-notify-secret: $S" \
  -d '{"action":"daily_digest"}' >> /var/log/massa_digest.log 2>&1
echo " <- $(date -Is)" >> /var/log/massa_digest.log
