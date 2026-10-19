#!/bin/sh
# 자동 전환을 어제 그 예약으로 시험한다 — 전부 롤백한다
# ★ scheduled_at 이 이미 지나서 조건에 안 걸린다. 시험 동안만 미래로 당겨 두고 되돌린다.
docker exec -i massa-db psql -U postgres -d postgres 2>&1 <<'SQL'
begin;

select '--- 전 ---' as 단계;
select booking_no, status, provider_id, amount_vnd, fanout_at
  from bookings where group_id='208b6c8d-e99b-47b8-94a0-3bb874c5be70';

-- 시험용으로 약속 시각만 미래로
update bookings set scheduled_at = now() + interval '3 hours'
 where booking_no = 'MS-261019-3906';

select '--- 실행 ---' as 단계;
select * from fanout_stale_bookings(10, 10);

select '--- 후: 묶음에 생긴 예약 ---' as 단계;
select b.booking_no, b.status, p.display_name as 마사지사, b.amount_vnd as 금액,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as 기기수
from bookings b join providers p on p.id = b.provider_id
where b.group_id='208b6c8d-e99b-47b8-94a0-3bb874c5be70'
order by b.created_at;

select '--- 후: 손님·마사지사에게 만들어진 알림 ---' as 단계;
select n.kind, count(*) from notifications n
 where n.created_at > now() - interval '1 minute' group by 1;

select '--- 두 번 돌려도 또 보내지 않는가 ---' as 단계;
select * from fanout_stale_bookings(10, 10);

rollback;
SQL
echo '=== 롤백 완료 — DB 는 그대로 ==='
