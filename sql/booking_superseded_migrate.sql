-- 1회 이전: 이미 '다른 테라피스트가 먼저 수락했습니다'로 system 취소된 사본을 booking_superseded 로 옮긴다 (먼저 sql/booking_superseded.sql 적용)

-- 백업 — 옮길 행과 그 행을 가리키는 알림
create table if not exists public.bookings_backup_20261027_superseded as
select b.* from bookings b
 where b.cancel_reason = '다른 테라피스트가 먼저 수락했습니다' and b.cancelled_by = 'system';
create table if not exists public.notifications_backup_20261027_superseded as
select n.* from notifications n
 where n.booking_id in (select id from public.bookings_backup_20261027_superseded);
revoke all on public.bookings_backup_20261027_superseded, public.notifications_backup_20261027_superseded from anon, authenticated;

do $$
declare r record; n int; total int := 0;
begin
  for r in
    select w.id as winner, array_agg(l.id order by l.id) as ids
      from bookings l
      join bookings w on w.group_id = l.group_id and w.id <> l.id
                     and w.status in ('confirmed', 'on_the_way', 'in_progress', 'completed')
     where l.group_id is not null
       and l.status = 'cancelled'
       and l.cancelled_by = 'system'
       and l.cancel_reason = '다른 테라피스트가 먼저 수락했습니다'
     group by w.id
  loop
    perform id from bookings where group_id = (select group_id from bookings where id = r.winner) order by id for update;
    n := public.supersede_bookings(r.ids, r.winner);
    total := total + n;
    raise notice '묶음 수락 % → 옮긴 사본 %건', r.winner, n;
  end loop;
  raise notice '옮긴 사본 합계 %건', total;
end $$;