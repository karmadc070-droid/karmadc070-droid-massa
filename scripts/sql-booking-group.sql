-- 한 손님의 같은 요청을 여러 마사지사에게 동시에 보내고, 먼저 수락한 쪽만 남긴다.
--
-- 왜 필요한가 — 지금까지 고객 앱이 예약을 바로 'confirmed' 로 만들어서 수락 단계가
-- 아예 쓰이지 않았다(2026-10-14 기준 13건 전부 confirmed, requested 0건).
-- 'requested' 로 바꾸면 마사지사가 안 누를 때 예약이 떠 있게 되므로,
-- 10분 뒤 가까운 다른 마사지사에게도 같은 요청을 보내는 길을 연다.
--
-- ★ 수락을 앱에서 update 로 하면 안 된다. 두 명이 같은 순간에 누르면 둘 다 확정된다.
--   그래서 수락은 이 파일의 accept_booking() 한 곳으로만 들어오게 한다.

begin;

-- ── 1. 같은 요청을 묶는 열 ────────────────────────────────────────
alter table bookings add column if not exists group_id uuid;
create index if not exists bookings_group_idx on bookings (group_id) where group_id is not null;

-- 한 묶음에서 살아남는 예약은 하나뿐. 트리거가 실패해도 DB 가 마지막으로 막는다.
create unique index if not exists bookings_one_live_per_group
  on bookings (group_id)
  where group_id is not null
    and status in ('confirmed', 'on_the_way', 'in_progress', 'completed');

-- ── 2. 수락 ──────────────────────────────────────────────────────
-- security definer 로 둔다. 묶음의 다른 예약은 '남의 예약'이라
-- guard_booking_write 가 authenticated 권한으로는 손대지 못하게 막기 때문이다.
create or replace function accept_booking(p_id uuid)
returns bookings
language plpgsql
security definer
set search_path = public
as $fn$
declare
  b bookings;
  g uuid;
begin
  select group_id into g from bookings where id = p_id;
  if not found then
    raise exception '예약을 찾을 수 없습니다.' using errcode = '42501';
  end if;

  -- ★ 잠그는 순서를 묶음 전체 · id 오름차순으로 고정한다.
  --   자기 행부터 잠그면 두 명이 서로를 기다리다 교착에 빠진다.
  if g is not null then
    perform id from bookings where group_id = g order by id for update;
  else
    perform id from bookings where id = p_id for update;
  end if;

  select * into b from bookings where id = p_id;

  if not public.is_admin() and not exists (
       select 1 from providers pr
        where pr.id = b.provider_id
          and (pr.profile_id = auth.uid() or pr.owner_id = auth.uid())) then
    raise exception '이 예약을 수락할 권한이 없습니다.' using errcode = '42501';
  end if;

  if b.status <> 'requested' then
    raise exception '대기 중인 예약만 수락할 수 있습니다 (현재 %).', b.status
      using errcode = '42501';
  end if;

  if g is not null and exists (
       select 1 from bookings
        where group_id = g and id <> p_id
          and status in ('confirmed', 'on_the_way', 'in_progress', 'completed')) then
    raise exception '다른 테라피스트가 먼저 수락했습니다.'
      using errcode = '42501', hint = 'already_taken';
  end if;

  update bookings set status = 'confirmed', accepted_at = now()
   where id = p_id returning * into b;

  -- 늦은 쪽은 '거절'이 아니라 '취소'다. reject_count 는 건드리지 않는다 —
  -- 늦었다고 페널티를 먹이면 마사지사가 앱을 떠난다.
  if g is not null then
    update bookings
       set status = 'cancelled', cancelled_at = now(),
           cancel_reason = '다른 테라피스트가 먼저 수락했습니다',
           cancelled_by  = 'system'
     where group_id = g and id <> p_id and status = 'requested';
  end if;

  return b;
end
$fn$;

revoke all on function accept_booking(uuid) from public;
grant execute on function accept_booking(uuid) to authenticated;

-- ── 3. 알림 ──────────────────────────────────────────────────────
-- 지금 함수는 cancelled_by 가 'customer' 가 아니면 **손님에게** 취소 알림을 보낸다.
-- 그대로 두면 대체 요청 4건이 한꺼번에 취소될 때 손님이 "예약이 취소되었습니다" 를
-- 네 번 받는다. system 취소는 손님이 아니라 늦은 마사지사에게 알린다.
create or replace function notify_booking_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_body text := new.booking_no || ' · ' || to_char(new.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'MM/DD HH24:MI');
  v_kind text;
  v_title text;
begin
  if tg_op = 'INSERT' then
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '새 예약이 들어왔습니다', v_body, 'booking_new', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id
          union select id from profiles where role = 'admin') r
    where u is not null;
    return new;
  end if;

  if new.status is not distinct from old.status then return new; end if;

  if new.status = 'confirmed' then
    v_kind := 'booking_confirmed';  v_title := '예약이 확정되었습니다';
  elsif new.status = 'on_the_way' then
    v_kind := 'booking_on_the_way'; v_title := '테라피스트가 출발했습니다';
  elsif new.status = 'completed' then
    v_kind := 'booking_completed';  v_title := '서비스가 완료되었습니다. 평가를 남겨주세요';
  elsif new.status = 'cancelled' and coalesce(new.cancelled_by, '') = 'system' then
    -- 묶음에서 밀린 건. 손님은 이미 '확정' 알림을 받았으므로 여기서 또 알리지 않는다.
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '다른 테라피스트가 먼저 수락했습니다', v_body, 'booking_taken', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id) r
    where u is not null;
    return new;
  elsif new.status = 'cancelled' and coalesce(new.cancelled_by, '') <> 'customer' then
    v_kind := 'booking_cancelled';  v_title := '예약이 취소되었습니다.';
  elsif new.status = 'cancelled' then
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '손님이 예약을 취소했습니다', v_body, 'booking_cancelled_by_customer', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id) r
    where u is not null;
    return new;
  else
    return new;
  end if;

  insert into notifications (user_id, title, body, kind, booking_id)
  values (new.customer_id, v_title, v_body, v_kind, new.id);
  return new;
end
$fn$;

commit;
