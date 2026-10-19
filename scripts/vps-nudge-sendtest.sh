#!/bin/bash
# massa_nudge.sh 안의 '메일 보내는 부분' 만 떼어 시험한다 (2026-10-19)
#
# ★ 대상 산정·기록·유예는 이미 확인했다 (12명 잡힘 → 기록 후 0명).
#   남은 미검증 구간은 curl + jq + Resend 호출뿐이라 그것만 본다.
#   가짜 마사지사를 만들려다 KYC·심사 규칙에 두 번 막혔다 — 운영 규칙을 건드리지 않는다.
cd /root/massa || exit 1
RESEND=$(grep -E '^RESEND_KEY=' .env | cut -d= -f2-)
[ -n "$RESEND" ] || { echo "RESEND_KEY 없음"; exit 1; }

EMAIL='karmadc070+nudge@gmail.com'
NAME='ZZ 시험'
N=1
BODY="Chào ${NAME},

Tài khoản massa của bạn vẫn CHƯA bật thông báo.
(Đây là email thử nghiệm — không phải thông báo thật.)

massa"

RESP=$(curl -s -o /tmp/nudge_resp.json -w '%{http_code}' -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND" -H 'Content-Type: application/json' \
  --data-raw "$(jq -nc --arg to "$EMAIL" --arg b "$BODY" --arg s "massa — 시험 (nhắc lần $N)" \
      '{from:"massa <massa@moahagwon.com>", to:[$to], subject:$s, text:$b, reply_to:"massa@moahagwon.com"}')")
echo "HTTP=$RESP"
cat /tmp/nudge_resp.json; echo ''
rm -f /tmp/nudge_resp.json
