-- 넘겨준 사본 리셋: 다른 테라피스트가 수락한 묶음의 나머지 사본을 bookings 에서 booking_superseded 로 옮긴다 (2026-10-27)

-- 1) 보관 표 — bookings 와 같은 열 + 언제·어느 예약에 밀렸는지. 관리자만 읽는다
create table if not exists public.booking_superseded (like public.bookings);
alter table public.booking_superseded
  add column if not exists superseded_at timestamptz not null default now(),
  add column if not exists accepted_booking_id uuid;
do $$ begin
  alter table public.booking_superseded add primary key (id);
exception when invalid_table_definition then null;
end $$;
create index if not exists booking_superseded_group_idx on public.booking_superseded (group_id);
alter table public.booking_superseded enable row level security;
revoke all on public.booking_superseded from anon, authenticated;
grant select on public.booking_superseded to authenticated;
drop policy if exists booking_superseded_admin_read on public.booking_superseded;
create policy booking_superseded_admin_read on public.booking_superseded
  for select to authenticated using (public.is_admin());

-- 2) 옮기기 — accept_booking 과 1회 이전이 같이 쓴다. 호출자가 이미 묶음을 잠갔다고 본다
create or replace function public.supersede_bookings(p_ids uuid[], p_winner uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $function$
declare n int;
begin
  if p_ids is null or cardinality(p_ids) = 0 then return 0; end if;

  -- jsonb 로 옮겨서 bookings 에 열이 늘어도 수락이 깨지지 않는다. 그 열 값까지 남기려면 이 표에도 같은 열을 더한다
  insert into booking_superseded
  select (jsonb_populate_record(null::booking_superseded,
            to_jsonb(b) || jsonb_build_object('superseded_at', now(), 'accepted_booking_id', p_winner))).*
    from bookings b where b.id = any(p_ids);

  -- 알림: 손님 것(예: '다른 테라피스트에게도 요청했습니다')은 수락된 예약으로 옮기고,
  -- '먼저 수락했습니다'는 예약 링크만 비우고, 나머지(새 신청 알림 등)는 지운다
  update notifications n set booking_id = p_winner
    from bookings b
   where b.id = any(p_ids) and n.booking_id = b.id and n.user_id = b.customer_id;
  update notifications set booking_id = null
   where booking_id = any(p_ids) and kind = 'booking_taken';
  delete from notifications where booking_id = any(p_ids);

  -- booking_locations·reviews 는 CASCADE, payment_transactions·safety_alerts 는 SET NULL
  delete from bookings where id = any(p_ids);
  get diagnostics n = row_count;
  return n;
end
$function$;
revoke all on function public.supersede_bookings(uuid[], uuid) from public, anon, authenticated;

-- 3) 수락 — 늦은 사본은 '취소'로 남기지 않고 옮긴다
create or replace function public.accept_booking(p_id uuid)
returns bookings
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  b bookings;
  g uuid;
  v_ids uuid[];
begin
  select group_id into g from bookings where id = p_id;
  if not found then
    -- 이미 다른 사람이 수락해 옮겨진 사본이면 그렇게 알려 준다
    if exists (select 1 from booking_superseded s
                where s.id = p_id
                  and (public.is_admin() or exists (
                        select 1 from providers pr
                         where pr.id = s.provider_id
                           and (pr.profile_id = auth.uid() or pr.owner_id = auth.uid())))) then
      raise exception '다른 테라피스트가 먼저 수락했습니다.'
        using errcode = '42501', hint = 'already_taken';
    end if;
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
  if not found then
    -- 잠금을 기다리는 사이 먼저 수락한 쪽이 이 사본을 옮겼다
    raise exception '다른 테라피스트가 먼저 수락했습니다.'
      using errcode = '42501', hint = 'already_taken';
  end if;

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

  -- 늦은 쪽은 '취소'도 '거절'도 아니다 — 예약이 아니었던 것으로 되돌린다(booking_superseded 로 옮김).
  -- reject_count·취소 건수는 건드리지 않는다. 마사지사에게는 알림만 남긴다(예약 링크 없음).
  if g is not null then
    select array_agg(id order by id) into v_ids
      from bookings where group_id = g and id <> p_id and status = 'requested';
    if v_ids is not null then
      insert into notifications (user_id, title, body, kind, booking_id)
      select r.u, '다른 테라피스트가 먼저 수락했습니다',
             l.booking_no || ' · ' || to_char(l.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'MM/DD HH24:MI'),
             'booking_taken', null
        from bookings l
        cross join lateral (select owner_id as u from providers where id = l.provider_id
                            union select profile_id from providers where id = l.provider_id) r
       where l.id = any(v_ids) and r.u is not null;
      perform public.supersede_bookings(v_ids, p_id);
    end if;
  end if;

  return b;
end
$function$;