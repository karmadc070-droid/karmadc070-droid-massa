#!/bin/sh
# 지금 상태 한눈에 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. 알림 기기 보유 현황 ==='
$PSQL -c "
select p.display_name as 마사지사,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as 기기수,
       coalesce(n.sent_count,0) as 재촉메일,
       coalesce(to_char(u.last_sign_in_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI'),'없음') as 마지막로그인
from providers p
left join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
left join push_nudges n on n.user_id = u.id
where p.application_status='approved'
order by 기기수 desc, p.display_name;"

echo '=== 2. 예약 ==='
$PSQL -c "
select to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 신청,
       b.booking_no, b.status as 상태,
       coalesce(p.display_name,'-') as 마사지사,
       coalesce(to_char(b.accepted_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI'),'-') as 수락
from bookings b left join providers p on p.id=b.provider_id
order by b.created_at desc limit 5;"

echo '=== 3. 오늘 알림이 어떻게 처리됐나 ==='
$PSQL -c "
select n.kind as 종류, coalesce(n.push_result,'(대기)') as 결과, count(*) as 건수
from notifications n
where n.created_at > now() - interval '1 day'
group by 1,2 order by 3 desc;"

echo '=== 4. 재촉 메일 로그 ==='
tail -6 /var/log/massa_nudge.log 2>/dev/null || echo '  (아직 없음 — 첫 발송은 한국시간 17시)'

echo '=== 5. 푸시 발송기 ==='
tail -2 /var/log/massa_push.log 2>/dev/null
echo '=== 6. 크론 ==='
crontab -l | grep -E 'massa_push|massa_nudge'
echo '=== DONE ==='
