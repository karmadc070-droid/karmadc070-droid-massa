-- 호텔·서비스드 아파트 제휴(파트너 QR): 파트너·손님 연결·예약 귀속·수수료(지급 대기)와 그 함수·트리거 (2026-10-29)
-- 귀속 규칙 — 손님이 파트너 링크(app.massaviet.com/?p=코드)로 들어온 뒤 로그인하면 그 계정을 파트너에 잇는다(linked_at=서버 시각).
--   다른 파트너 링크로 다시 들어오면 마지막 것으로 바뀐다. 이어진 뒤 30일 안에 만든 예약을 그 파트너 예약으로 굳힌다(예약 시점에 고정).
--   그 예약이 '완료'되면 손님이 낸 금액(amount_vnd - discount_vnd)의 10% 를 지급 대기(pending_payout)로 쌓는다.
-- 친구 초대(?ref=, referral_*)와는 표·함수·저장 키가 모두 따로다. 한 예약이 둘 다 해당돼도 서로 영향이 없다.
-- bookings 에는 칸을 더하지 않는다 — booking_superseded 가 bookings 열 순서를 그대로 베끼므로 칸을 더하면 넘겨주기가 깨진다.

create table if not exists public.partners (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (length(trim(name)) > 0),
  contact         text,
  code            text not null unique check (code ~ '^[A-Z0-9]{4,12}$'),
  commission_rate numeric(4,3) not null default 0.10,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);
alter table public.partners enable row level security;   -- 정책 없음: 함수로만 읽고 쓴다

-- 손님 한 사람에게 파트너는 하나(마지막으로 들어온 링크)
create table if not exists public.partner_guests (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete cascade,
  linked_at  timestamptz not null default now()
);
alter table public.partner_guests enable row level security;

-- 파트너 예약. 예약이 들어올 때 굳히고, 완료되면 수수료를 적는다. 넘겨준 사본이 지워지면 같이 지워진다.
create table if not exists public.partner_bookings (
  booking_id     uuid primary key references public.bookings(id) on delete cascade,
  partner_id     uuid not null references public.partners(id) on delete cascade,
  created_at     timestamptz not null default now(),
  base_vnd       bigint,
  commission_vnd bigint,
  status         text check (status in ('pending_payout', 'paid')),   -- 완료 전에는 null
  earned_at      timestamptz,
  paid_at        timestamptz
);
create index if not exists partner_bookings_partner_idx on public.partner_bookings (partner_id);
alter table public.partner_bookings enable row level security;

-- 손님이 파트너 링크로 들어왔을 때 앱이 부른다. 모르는 코드면 hint 로 알려 앱이 저장값을 지운다.
create or replace function public.claim_partner(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v_id uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '42501'; end if;
  select id into v_id from partners where code = upper(trim(coalesce(p_code, ''))) and is_active;
  if v_id is null then raise exception '제휴 코드를 찾을 수 없습니다.' using errcode = 'P0001', hint = 'partner_not_found'; end if;
  insert into partner_guests (user_id, partner_id, linked_at) values (uid, v_id, now())
  on conflict (user_id) do update set partner_id = excluded.partner_id, linked_at = excluded.linked_at;
  return jsonb_build_object('ok', true);
end $$;

-- 예약이 들어오면 30일 안에 이어진 파트너가 있는지 보고 굳힌다
create or replace function public.partner_tag_booking() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into partner_bookings (booking_id, partner_id)
  select new.id, g.partner_id from partner_guests g join partners p on p.id = g.partner_id
   where g.user_id = new.customer_id and p.is_active and g.linked_at > now() - interval '30 days'
  on conflict (booking_id) do nothing;
  return null;
end $$;
drop trigger if exists trg_partner_tag on public.bookings;
create trigger trg_partner_tag after insert on public.bookings
  for each row execute function public.partner_tag_booking();

-- 완료되면 수수료를 지급 대기로 적는다(한 번만)
create or replace function public.partner_commission_on_complete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update partner_bookings pb
     set base_vnd = greatest(0, coalesce(new.amount_vnd, 0) - coalesce(new.discount_vnd, 0)),
         commission_vnd = round(greatest(0, coalesce(new.amount_vnd, 0) - coalesce(new.discount_vnd, 0)) * p.commission_rate),
         status = 'pending_payout', earned_at = now()
    from partners p
   where pb.booking_id = new.id and p.id = pb.partner_id and pb.status is null;
  return null;
end $$;
drop trigger if exists trg_partner_commission on public.bookings;
create trigger trg_partner_commission after update of status on public.bookings
  for each row when (new.status = 'completed' and old.status is distinct from 'completed')
  execute function public.partner_commission_on_complete();

-- 관리자: 파트너 목록과 숫자
create or replace function public.admin_partner_list() returns setof jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception '관리자만 조회할 수 있습니다.' using errcode = '42501'; end if;
  return query
  select jsonb_build_object('id', p.id, 'name', p.name, 'contact', p.contact, 'code', p.code,
           'rate', p.commission_rate, 'is_active', p.is_active, 'created_at', p.created_at,
           'guests', (select count(*) from partner_guests g where g.partner_id = p.id),
           'bookings', (select count(*) from partner_bookings b where b.partner_id = p.id),
           'completed', (select count(*) from partner_bookings b where b.partner_id = p.id and b.status is not null),
           'pending_vnd', (select coalesce(sum(commission_vnd), 0) from partner_bookings b where b.partner_id = p.id and b.status = 'pending_payout'),
           'paid_vnd', (select coalesce(sum(commission_vnd), 0) from partner_bookings b where b.partner_id = p.id and b.status = 'paid'))
    from partners p order by p.created_at desc;
end $$;

-- 관리자: 파트너 만들기. 코드는 대문자·숫자 4~12자
create or replace function public.admin_partner_create(p_name text, p_contact text, p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_admin() then raise exception '관리자만 처리할 수 있습니다.' using errcode = '42501'; end if;
  insert into partners (name, contact, code)
  values (trim(p_name), nullif(trim(coalesce(p_contact, '')), ''), upper(trim(coalesce(p_code, ''))))
  returning id into v_id;
  return v_id;
exception
  when unique_violation then raise exception '이미 쓰는 코드입니다.' using errcode = 'P0001';
  when check_violation then raise exception '이름을 적고, 코드는 영문 대문자·숫자 4~12자로 적어 주세요.' using errcode = 'P0001';
end $$;

-- 관리자: 그 파트너의 지급 대기 수수료를 지급했다고 표시한다
create or replace function public.admin_partner_paid(p_partner uuid) returns integer
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public.is_admin() then raise exception '관리자만 처리할 수 있습니다.' using errcode = '42501'; end if;
  update partner_bookings set status = 'paid', paid_at = now()
   where partner_id = p_partner and status = 'pending_payout';
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.claim_partner(text), public.admin_partner_list(), public.admin_partner_create(text, text, text),
  public.admin_partner_paid(uuid), public.partner_tag_booking(), public.partner_commission_on_complete() from public, anon;
grant execute on function public.claim_partner(text), public.admin_partner_list(), public.admin_partner_create(text, text, text),
  public.admin_partner_paid(uuid) to authenticated;
