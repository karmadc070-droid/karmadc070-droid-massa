-- 친구 초대: 초대 코드·초대 관계·보상(손님은 쿠폰, 마사지사는 지급 대기 적립금)과 그 함수·트리거 (2026-10-29)
-- 손님   — 초대받은 친구가 첫 예약을 '완료'하면 초대한 사람 쿠폰함에 100,000₫ 쿠폰(개인 쿠폰, 목록에 안 뜸)
-- 마사지사 — 초대받은 마사지사가 승인되고 첫 서비스를 '완료'하면 초대한 마사지사에게 100,000₫ 적립(pending_payout),
--           한 사람당 10명·1,000,000₫ 까지. 그 뒤 초대도 연결은 되지만 적립은 없다.
-- 막는 것 — 자기 초대, 서로 초대, 한 사람에게 초대자 둘(invitee_id 기본키), 보상 두 번(rewarded_at), 기존 계정(가입 24시간 지남·예약 있음)

-- 개인 쿠폰: 특정 사람에게만 넣어 주는 쿠폰. is_active=false 로 두어 '받을 수 있는 쿠폰' 목록과
-- 직접 받기(guard_user_coupon_write)에서 빠지고, 예약에 적용할 때만 personal 로 통과시킨다.
alter table public.coupons add column if not exists personal boolean not null default false;

create table if not exists public.referral_codes (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  code       text not null unique,
  created_at timestamptz not null default now()
);
alter table public.referral_codes enable row level security;   -- 정책 없음: 함수로만 읽고 쓴다

create table if not exists public.referrals (
  invitee_id          uuid primary key references public.profiles(id) on delete cascade,  -- 한 사람에게 초대자는 하나
  inviter_id          uuid not null references public.profiles(id) on delete cascade,
  kind                text not null check (kind in ('customer', 'provider')),
  inviter_provider_id uuid references public.providers(id) on delete set null,
  code                text not null,
  created_at          timestamptz not null default now(),
  rewarded_at         timestamptz,                                  -- 보상 처리한 시각(상한에 걸려 0원이어도 찍는다)
  reward_booking_id   uuid references public.bookings(id) on delete set null,
  reward_coupon_id    uuid references public.coupons(id) on delete set null,
  check (invitee_id <> inviter_id)
);
create index if not exists referrals_inviter_idx on public.referrals (inviter_id);
alter table public.referrals enable row level security;
drop policy if exists referrals_admin_read on public.referrals;
create policy referrals_admin_read on public.referrals for select to authenticated using (public.is_admin());

-- 마사지사 초대 적립금. 정산 때 관리자가 지급하고 paid 로 바꾼다.
create table if not exists public.referral_rewards (
  id          uuid primary key default gen_random_uuid(),
  invitee_id  uuid not null unique references public.referrals(invitee_id) on delete cascade,
  inviter_id  uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid references public.providers(id) on delete set null,   -- 받는 쪽(초대한 마사지사)
  booking_id  uuid references public.bookings(id) on delete set null,
  amount_vnd  integer not null check (amount_vnd > 0),
  status      text not null default 'pending_payout' check (status in ('pending_payout', 'paid')),
  created_at  timestamptz not null default now(),
  paid_at     timestamptz
);
create index if not exists referral_rewards_inviter_idx on public.referral_rewards (inviter_id);
alter table public.referral_rewards enable row level security;
drop policy if exists referral_rewards_admin_read on public.referral_rewards;
create policy referral_rewards_admin_read on public.referral_rewards for select to authenticated using (public.is_admin());

-- 내 초대 코드(없으면 만든다)와 숫자. kind 는 '지금 승인된 마사지사인가'.
create or replace function public.my_referral() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_code text; v_kind text; v_can boolean;
  i int;
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '42501'; end if;
  select code into v_code from referral_codes where user_id = uid;
  while v_code is null loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + floor(random() * 31)::int, 1);
    end loop;
    begin
      insert into referral_codes (user_id, code) values (uid, v_code);
    exception when unique_violation then
      v_code := null;   -- 코드가 겹쳤거나 동시에 만들었다 — 있는 것을 다시 읽고, 없으면 새로 뽑는다
      select code into v_code from referral_codes where user_id = uid;
    end;
  end loop;

  v_kind := case when exists (select 1 from providers
                               where (profile_id = uid or owner_id = uid) and application_status = 'approved')
                 then 'provider' else 'customer' end;
  v_can := not exists (select 1 from referrals where invitee_id = uid)
           and (select created_at from auth.users where id = uid) > now() - interval '24 hours'
           and not exists (select 1 from bookings where customer_id = uid);

  return jsonb_build_object(
    'code', v_code,
    'kind', v_kind,
    'invited', (select count(*) from referrals where inviter_id = uid),
    'rewarded', (select count(*) from referrals where inviter_id = uid and kind = 'customer' and reward_coupon_id is not null)
              + (select count(*) from referral_rewards where inviter_id = uid),
    'earned_vnd', coalesce((select sum(c.discount_value) from referrals r join coupons c on c.id = r.reward_coupon_id
                             where r.inviter_id = uid), 0)
                + coalesce((select sum(amount_vnd) from referral_rewards where inviter_id = uid), 0),
    'pending_vnd', coalesce((select sum(amount_vnd) from referral_rewards
                              where inviter_id = uid and status = 'pending_payout'), 0),
    'cap_count', 10,
    'can_enter', v_can);
end $$;

-- 초대 코드 등록. 링크로 들어와 가입한 뒤 앱이 한 번 부르거나, 사용자가 코드를 직접 넣는다.
create or replace function public.claim_referral(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_code, '')));
  v_inviter uuid; v_prov uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '42501'; end if;
  select user_id into v_inviter from referral_codes where code = v_code;
  if v_inviter is null then
    raise exception '초대 코드를 찾을 수 없습니다.' using errcode = 'P0001', hint = 'ref_not_found';
  end if;
  if v_inviter = uid or exists (select 1 from referrals where invitee_id = v_inviter and inviter_id = uid) then
    raise exception '본인이나 내가 초대한 사람의 코드는 쓸 수 없습니다.' using errcode = 'P0001', hint = 'ref_self';
  end if;
  if exists (select 1 from referrals where invitee_id = uid) then
    raise exception '이미 초대 코드를 등록했습니다.' using errcode = 'P0001', hint = 'ref_already';
  end if;
  if (select created_at from auth.users where id = uid) <= now() - interval '24 hours'
     or exists (select 1 from bookings where customer_id = uid) then
    raise exception '새로 가입한 계정만 초대 코드를 등록할 수 있습니다.' using errcode = 'P0001', hint = 'ref_not_new';
  end if;

  select id into v_prov from providers
   where (profile_id = v_inviter or owner_id = v_inviter) and application_status = 'approved'
   order by created_at limit 1;
  insert into referrals (invitee_id, inviter_id, kind, inviter_provider_id, code)
  values (uid, v_inviter, case when v_prov is null then 'customer' else 'provider' end, v_prov, v_code);
  return jsonb_build_object('ok', true, 'kind', case when v_prov is null then 'customer' else 'provider' end);
end $$;

-- 예약이 완료될 때 보상한다. 손님 쪽과 마사지사 쪽을 따로 본다(한 예약이 둘 다 해당될 수 있다).
create or replace function public.referral_reward_on_complete() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  r referrals%rowtype;
  pv record;
  v_cp uuid; v_sum bigint; v_amt int;
begin
  -- 손님: 이 손님의 첫 완료 예약이면 초대한 사람에게 쿠폰
  if not exists (select 1 from bookings b where b.customer_id = new.customer_id and b.status = 'completed' and b.id <> new.id) then
    select * into r from referrals
     where invitee_id = new.customer_id and kind = 'customer' and rewarded_at is null for update;
    if found then
      insert into coupons (code, title, discount_type, discount_value, min_amount_vnd, valid_until, is_active, personal)
      values ('REF-' || upper(replace(r.invitee_id::text, '-', '')), '친구 초대 보상 100,000₫', 'amount', 100000, 0, null, false, true)
      returning id into v_cp;
      insert into user_coupons (customer_id, coupon_id) values (r.inviter_id, v_cp);
      update referrals set rewarded_at = now(), reward_booking_id = new.id, reward_coupon_id = v_cp
       where invitee_id = r.invitee_id;
      insert into notifications (user_id, title, body, kind)
      values (r.inviter_id, '친구 초대 보상 100,000동 쿠폰이 도착했어요', '100,000₫', 'referral_reward');
    end if;
  end if;

  -- 마사지사: 승인된 마사지사의 첫 완료 서비스면 초대한 마사지사에게 적립 (10명·1,000,000₫ 까지)
  select id, profile_id, owner_id, application_status into pv from providers where id = new.provider_id;
  if pv.id is not null and pv.application_status = 'approved'
     and not exists (select 1 from bookings b where b.provider_id = new.provider_id and b.status = 'completed' and b.id <> new.id) then
    select * into r from referrals
     where invitee_id in (pv.profile_id, pv.owner_id) and kind = 'provider' and rewarded_at is null
     limit 1 for update;
    if found then
      perform pg_advisory_xact_lock(hashtext('referral_cap:' || r.inviter_id::text));   -- 상한 계산이 겹치지 않게
      select coalesce(sum(amount_vnd), 0) into v_sum from referral_rewards where inviter_id = r.inviter_id;
      v_amt := least(100000, greatest(0, 1000000 - v_sum));
      update referrals set rewarded_at = now(), reward_booking_id = new.id where invitee_id = r.invitee_id;
      if v_amt > 0 then
        insert into referral_rewards (invitee_id, inviter_id, provider_id, booking_id, amount_vnd)
        values (r.invitee_id, r.inviter_id, r.inviter_provider_id, new.id, v_amt);
        insert into notifications (user_id, title, body, kind)
        values (r.inviter_id, '친구 초대 보상 100,000동이 적립됐어요', '100,000₫', 'referral_bonus');
      end if;
    end if;
  end if;
  return null;
end $$;

drop trigger if exists trg_referral_reward on public.bookings;
create trigger trg_referral_reward after update of status on public.bookings
  for each row when (new.status = 'completed' and old.status is distinct from 'completed')
  execute function public.referral_reward_on_complete();

-- 관리자: 그 마사지사의 지급 대기 적립금을 정산 때 지급했다고 표시한다
create or replace function public.admin_referral_paid(p_provider uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.is_admin() then raise exception '관리자만 처리할 수 있습니다.' using errcode = '42501'; end if;
  update referral_rewards set status = 'paid', paid_at = now()
   where provider_id = p_provider and status = 'pending_payout';
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.my_referral(), public.claim_referral(text), public.admin_referral_paid(uuid),
  public.referral_reward_on_complete() from public, anon;
grant execute on function public.my_referral(), public.claim_referral(text), public.admin_referral_paid(uuid) to authenticated;

-- 예약에 쿠폰을 붙일 때 개인 쿠폰(is_active=false, personal=true)도 받아 준다. 함수 본문의 한 줄만 바꾼다.
do $$
declare d text := pg_get_functiondef('public.guard_booking_write'::regproc);
begin
  if position('(c.is_active or c.personal)' in d) = 0 then
    if position('where c.id = new.coupon_id and c.is_active' in d) = 0 then
      raise exception 'guard_booking_write 의 쿠폰 조건을 찾지 못했다 — 손으로 확인할 것';
    end if;
    execute replace(d, 'where c.id = new.coupon_id and c.is_active', 'where c.id = new.coupon_id and (c.is_active or c.personal)');
  end if;
end $$;
