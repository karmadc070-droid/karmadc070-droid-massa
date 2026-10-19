#!/bin/sh
# 대기 알림 적용 + 검증 (2026-10-18)
# 검증 시나리오 — 기기가 0대인 실제 마사지사에게 공지를 넣고,
#   1) 보내면 no_device 로 기록되지만 next_push_at 이 남아 '대기' 상태가 되는가
#   2) 기기가 없는 동안은 다시 집히지 않는가 (헛돌지 않는가)
#   3) 기기가 생기면 집히는가 (가짜 토큰을 잠깐 넣어 확인하고 지운다)
set -e
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 함수 교체 ==='
$PSQL -v ON_ERROR_STOP=1 < /tmp/wait.sql

echo '=== 2. 스키마 리로드 ==='
docker exec massa-db psql -U postgres -d postgres -c "notify pgrst, 'reload schema';" >/dev/null
sleep 2

echo '=== 3. 기기 0대인 마사지사에게 공지 넣기 ==='
$PSQL -c "
insert into notifications (user_id, title, body, kind)
select id, 'WAITTEST 환영', '기기 생기면 전달', 'notice'
from auth.users where email='trinh1111ttt@gmail.com';"

echo '=== 4. 발송 → no_device 이지만 next_push_at 이 남아야 한다 ==='
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
curl -s -m 30 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}'
echo ''
$PSQL -c "select push_tries, push_result, next_push_at is not null as 대기중
          from notifications where title='WAITTEST 환영';"

echo '=== 5. 기기가 없는 동안엔 다시 안 집혀야 한다 ==='
$PSQL -c "update notifications set next_push_at = now() - interval '1 minute' where title='WAITTEST 환영';"
$PSQL -t -A -c "select count(*) from claim_unpushed_notifications() where title='WAITTEST 환영';" \
  | sed 's/^/  집힌 건수(0 이어야 정상): /'

echo '=== 6. 기기가 생기면 집혀야 한다 (가짜 토큰 잠깐 등록) ==='
$PSQL -c "
insert into push_tokens (user_id, token, platform, lang)
select id, 'WAITTEST-FAKE-TOKEN', 'web', 'vi' from auth.users where email='trinh1111ttt@gmail.com';" >/dev/null
$PSQL -c "update notifications set next_push_at = now() - interval '1 minute' where title='WAITTEST 환영';"
$PSQL -t -A -c "select count(*) from claim_unpushed_notifications() where title='WAITTEST 환영';" \
  | sed 's/^/  집힌 건수(1 이어야 정상): /'

echo '=== 7. 정리 ==='
$PSQL -c "delete from push_tokens where token='WAITTEST-FAKE-TOKEN';" | sed 's/^/  /'
$PSQL -c "delete from notifications where title like 'WAITTEST%';" | sed 's/^/  /'

echo '=== APPLY DONE ==='
