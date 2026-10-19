#!/bin/sh
# 최근 예약 요청이 실제로 성사됐는지 + 그에 딸린 푸시가 나갔는지 한 번에 본다
PSQL="docker exec -i massa-db psql -U postgres -d postgres"

echo '=== 1. 최근 예약 10건 (무슨 일이 있었나) ==='
$PSQL -c "
select to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 하노이시각,
       b.status as 상태,
       coalesce(p.display_name,'-') as 마사지사,
       coalesce(u.email,'-') as 손님,
       coalesce(s.name_ko, s.name_vi, '-') as 코스,
       to_char(b.scheduled_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 희망시각,
       b.id
from bookings b
left join providers p on p.id = b.provider_id
left join auth.users u on u.id = b.customer_id
left join services s on s.id = b.service_id
order by b.created_at desc limit 10;"

echo ''
echo '=== 2. 그 예약에 딸린 알림과 푸시 상태 ==='
$PSQL -c "
select to_char(n.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 만든시각,
       n.kind as 종류,
       coalesce(u.email,'-') as 받는사람,
       n.is_read as 읽음,
       case when n.pushed_at is null then '★ 안 보냄'
            else to_char(n.pushed_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') end as 보낸시각,
       n.push_tries as 시도횟수,
       (select count(*) from push_tokens t where t.user_id = n.user_id) as 기기수
from notifications n
left join auth.users u on u.id = n.user_id
where n.created_at > now() - interval '3 days'
order by n.created_at desc limit 15;"

echo ''
echo '=== 3. 마사지사별 푸시 기기 보유 현황 (승인된 사람만) ==='
$PSQL -c "
select p.display_name as 마사지사,
       p.is_active as 영업중,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as 기기수
from providers p
where p.application_status = 'approved'
order by 기기수 desc, p.display_name limit 20;"

echo ''
echo '=== 4. 푸시 발송기가 돌고 있는가 (크론 + 최근 로그) ==='
crontab -l 2>/dev/null | grep -i push || echo '  ★ 크론에 푸시 항목이 없다'
echo '--- 최근 로그 10줄 ---'
tail -10 /var/log/massa_push.log 2>/dev/null || echo '  (로그 파일 없음)'
echo '=== DONE ==='
