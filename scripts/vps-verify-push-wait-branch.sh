#!/bin/sh
# (c) 분기 — '기기가 생기면 집힌다' 를 기기 있는 계정으로 정확히 검증한다.
# 앞선 시도는 가짜 토큰이 CHECK 제약에 걸려 검증이 안 됐다.
PSQL="docker exec -i massa-db psql -U postgres -d postgres"

echo '=== 참고: 토큰 CHECK 제약 ==='
$PSQL -t -A -c "select pg_get_constraintdef(oid) from pg_constraint where conname='push_tokens_token_check';" | sed 's/^/  /'

echo ''
echo '=== A) 기기 있는 계정에 공지 → 한 번에 전달되고 대기하지 않아야 한다 ==='
$PSQL -c "insert into notifications (user_id, title, body, kind)
          select id,'WAITCHK 공지','본문','notice' from auth.users where email='karmadc070@gmail.com';"
S=$(grep -E '^NOTIFY_SECRET=' /root/massa/.env | cut -d= -f2-)
curl -s -m 30 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}' >/dev/null
$PSQL -c "select push_result, push_tries, (next_push_at is null) as 대기안함
          from notifications where title='WAITCHK 공지';"

echo '=== B) (c) 분기 — 대기 예약 시각이 지났고 기기가 있으면 집혀야 한다 (1) ==='
$PSQL -c "update notifications set next_push_at = now() - interval '1 minute', is_read=false
          where title='WAITCHK 공지';" >/dev/null
$PSQL -t -A -c "select count(*) from claim_unpushed_notifications() where title='WAITCHK 공지';" \
  | sed 's/^/  집힌 건수: /'

echo '=== C) booking_new 는 기기가 없어도 기다리지 않아야 한다 ==='
$PSQL -c "insert into notifications (user_id, title, body, kind)
          select id,'WAITCHK 예약','본문','booking_new' from auth.users where email='trinh1111ttt@gmail.com';" >/dev/null
curl -s -m 30 -X POST http://localhost:8002/functions/v1/send-push \
  -H 'Content-Type: application/json' -H "x-notify-secret: $S" -d '{}' >/dev/null
$PSQL -c "select push_result, (next_push_at is not null) as 대기함
          from notifications where title='WAITCHK 예약';"

echo '=== 정리 ==='
$PSQL -c "delete from notifications where title like 'WAITCHK%';" | sed 's/^/  /'
$PSQL -t -A -c "select count(*) from notifications where title like 'WAIT%' or title like 'TEST%';" | sed 's/^/  남은 테스트 행: /'
echo '=== DONE ==='
