#!/bin/bash
# massa 푸시 발송기 (VPS /root/massa_push.sh 로 배치, 크론 1분마다).
#
# 새 예약 알림은 수락할 때까지 30초마다 다시 울려야 한다. 크론 최소 주기가 1분이라
# 한 번 호출하고 30초 뒤 한 번 더 호출해서 30초 간격을 만든다.
# 무엇을 다시 보낼지는 DB 의 claim_unpushed_notifications() 가 정한다 — 여기서는 호출만 한다.
#
# ★ 이 파일을 PowerShell 파이프/heredoc 으로 서버에 보내지 말 것.
#   $(...) 와 $S 가 로컬에서 전개돼 스크립트가 깨지고 시크릿이 파일에 박힌다. 반드시 scp.
set -u

S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
[ -n "$S" ] || { echo "$(date -Is) NOTIFY_SECRET 없음" >> /var/log/massa_push.log; exit 1; }

call() {
  out=$(curl -s -m 25 -X POST http://localhost:8002/functions/v1/send-push \
        -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}')
  case "$out" in
    *'"claimed":0'*) ;;                                   # 보낼 게 없으면 로그를 남기지 않는다
    *) echo "$(date -Is) $out" >> /var/log/massa_push.log ;;
  esac
}

call
sleep 30
call
