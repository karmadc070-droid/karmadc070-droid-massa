#!/bin/sh
# 환영 푸시 3줄을 두 계정에 보내고 경로별 결과를 본다 (2026-10-18)
#   karmadc070@gmail.com : 웹푸시  -> 본문이 안 실린다(sw.js 고정 문구). 소리/도착만 확인.
#   demo@massa.app       : FCM     -> 본문이 실린다. 토큰이 살아있는지도 같이 확인.
set -e
Q() { docker exec -i massa-db psql -U postgres -d postgres -t -A -c "$1"; }

TITLE='Chúc mừng bạn đã tham gia massa!'
BODY='Vui lòng bổ sung thông tin còn thiếu trong hồ sơ.
Sắp tới sẽ có tiền thưởng cho những kỹ thuật viên được yêu thích nhất.'

echo '=== 1. 알림 넣기 (kind=notice — 반복 안 함) ==='
docker exec -i massa-db psql -U postgres -d postgres -c "
insert into notifications (user_id, title, body, kind)
select id, \$\$$TITLE\$\$, \$\$$BODY\$\$, 'notice'
from auth.users where email in ('karmadc070@gmail.com','demo@massa.app');"

echo '=== 2. 발송 ==='
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
curl -s -m 30 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}'
echo ''

echo '=== 3. 경로별 결과 ==='
docker exec -i massa-db psql -U postgres -d postgres -c "
select u.email, n.push_result, n.pushed_at::time(0) as sent_at
from notifications n join auth.users u on u.id=n.user_id
where n.kind='notice' and n.title like 'Chúc mừng%'
order by u.email;"

echo '=== 4. 토큰 플랫폼 ==='
docker exec -i massa-db psql -U postgres -d postgres -c "
select u.email, t.platform, count(*) from push_tokens t
join auth.users u on u.id=t.user_id group by 1,2 order by 1;"

echo '=== DONE ==='
