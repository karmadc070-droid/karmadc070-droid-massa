#!/bin/bash
# 알림을 안 켠 마사지사에게 재촉 메일을 보낸다 (2026-10-19)
#
# 크론: 베트남 시간 09·15·21시 = 한국 시간 11·17·23시 → 0 11,17,23 * * *
# 자는 시간에는 안 보낸다. 하루 8통씩 보내면 Gmail 이 스팸으로 분류하고,
# 그러면 정작 예약 알림 메일까지 스팸함으로 들어간다.
#
# ★ 숫자를 바꾸려면 아래 두 줄만 고치면 된다.
GAP_HOURS=3     # 마지막 발송 후 몇 시간 지나야 다시 보내는가
MAX_SENDS=21    # 한 사람에게 최대 몇 통까지 (하루 3통 × 7일)

LOG=/var/log/massa_nudge.log
cd /root/massa || exit 1
PSQL="docker exec -i massa-db psql -U postgres -d postgres -t -A -F|"
RESEND=$(grep -E '^RESEND_KEY=' .env | cut -d= -f2-)
[ -n "$RESEND" ] || { echo "$(date -Is) RESEND_KEY 없음" >> "$LOG"; exit 1; }

SENT=0
$PSQL -c "select user_id, email, display_name, sent_count from push_nudge_targets($GAP_HOURS, $MAX_SENDS);" \
| while IFS='|' read -r UID_ EMAIL NAME CNT; do
  [ -n "$EMAIL" ] || continue
  N=$((CNT + 1))
  BODY="Chào ${NAME},

Tài khoản massa của bạn vẫn CHƯA bật thông báo.
Nếu có khách đặt lịch ngay bây giờ, bạn sẽ không hề biết, và đơn sẽ
chuyển cho kỹ thuật viên khác.

Làm 3 bước, khoảng 1 phút:

1) Cập nhật ứng dụng
   - Android: CH Play -> tìm \"massa\" -> Cập nhật
   - iPhone:  App Store -> tìm \"massa\" -> Cập nhật
   (Chưa cài? Vào https://app.massaviet.com)
2) Mở ứng dụng và đăng nhập
3) Khi hiện \"Bật thông báo\", chọn Cho phép

Bật xong, điện thoại sẽ tự đổ chuông mỗi khi có đơn — bạn không cần
mở ứng dụng thường xuyên nữa.

Email này sẽ tự động dừng ngay khi bạn bật thông báo.
Gặp khó khăn? Hãy trả lời email này.

massa"

  RESP=$(curl -s -o /dev/null -w '%{http_code}' -X POST https://api.resend.com/emails \
    -H "Authorization: Bearer $RESEND" -H 'Content-Type: application/json' \
    --data-raw "$(jq -nc --arg to "$EMAIL" --arg b "$BODY" --arg s "massa — Hãy bật thông báo (nhắc lần $N)" \
        '{from:"massa <massa@moahagwon.com>", to:[$to], subject:$s, text:$b, reply_to:"massa@moahagwon.com"}')")

  if [ "$RESP" = "200" ]; then
    docker exec -i massa-db psql -U postgres -d postgres -q -c "select push_nudge_mark('$UID_');" >/dev/null 2>&1
    echo "$(date -Is) 보냄 $EMAIL (${N}회차)" >> "$LOG"
  else
    echo "$(date -Is) 실패 $EMAIL HTTP=$RESP" >> "$LOG"
  fi
done

echo "$(date -Is) 완료" >> "$LOG"
