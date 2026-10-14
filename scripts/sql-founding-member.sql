-- 창립 멤버 100명 — 첫 20건은 수수료를 떼지 않는다.
--
-- 사이트에 이렇게 적어 두었다 (site-src/content_ko.py)
--   "창립 멤버 100명을 찾습니다 / 첫 20건은 고객이 낸 금액을 전액 가져갑니다.
--    날짜가 아니라 건수로 세니, 다 쓰실 때까지 혜택이 그대로 남아 있습니다."
-- 지금까지 이 약속을 세는 곳이 아무 데도 없었다. 말만 있고 기계가 없었다.
--
-- 세는 기준 — 사장님 지시대로 '확정'이다. 단, 취소·노쇼는 빼고 살아 있는 건만 센다.
-- 마사지사가 수락했는데 손님이 취소한 건까지 20건에서 깎으면 약속과 다르다.

begin;

-- ── 1. 창립 멤버 번호 (1~100) ────────────────────────────────
alter table providers add column if not exists founding_no integer;
create unique index if not exists providers_founding_no_uniq
  on providers (founding_no) where founding_no is not null;

-- 이미 승인된 사람부터 가입 순으로 번호를 준다.
with ranked as (
  select id, row_number() over (order by created_at, id) as rn
    from providers
   where application_status = 'approved' and founding_no is null
)
update providers p set founding_no = r.rn
  from ranked r
 where p.id = r.id and r.rn <= 100;

-- ── 2. 혜택을 쓴 건수 ────────────────────────────────────────
-- 확정된 뒤 살아 있는 예약만. 취소·노쇼는 세지 않는다.
create or replace function founding_used(p_provider uuid)
returns integer
language sql stable
security definer
set search_path = public
as $fn$
  select count(*)::int from bookings
   where provider_id = p_provider
     and status in ('confirmed', 'on_the_way', 'in_progress', 'completed');
$fn$;

create or replace function founding_left(p_provider uuid)
returns integer
language sql stable
security definer
set search_path = public
as $fn$
  select case when (select founding_no from providers where id = p_provider) is null
              then 0
              else greatest(0, 20 - public.founding_used(p_provider)) end;
$fn$;

grant execute on function founding_used(uuid), founding_left(uuid) to authenticated;

-- ── 3. 수수료율에 혜택을 반영 ────────────────────────────────
-- ★ 여기를 고쳐야 실제로 돈이 안 나간다. 화면에 숫자만 띄우는 건 반쪽이다.
--   예약을 만드는 BEFORE INSERT 시점이라 그 예약은 아직 테이블에 없다.
--   그래서 '이미 쌓인 건수 < 20' 이면 이번 건이 공짜다 — 정확히 20건이 공짜가 된다.
create or replace function fee_rate_of(p_provider uuid)
returns numeric
language sql stable
security definer
set search_path = public
as $fn$
  select case
    when (select founding_no from public.providers where id = p_provider) is not null
     and public.founding_used(p_provider) < 20
    then 0::numeric
    else coalesce(
      (select (s.value->'tiers'->>pr.fee_tier::text)::numeric
         from public.providers pr, public.app_settings s
        where pr.id = p_provider and s.key = 'fee'),
      (select (value->>'rate')::numeric from public.app_settings where key = 'fee'),
      0.20)
  end;
$fn$;

-- ── 4. 승인할 때 번호를 준다 (100번까지만) ───────────────────
create or replace function grant_founding_no()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.application_status = 'approved'
     and coalesce(old.application_status::text, '') <> 'approved'
     and new.founding_no is null
     and (select count(*) from providers where founding_no is not null) < 100 then
    new.founding_no := coalesce((select max(founding_no) from providers), 0) + 1;
  end if;
  return new;
end
$fn$;

drop trigger if exists trg_grant_founding_no on providers;
create trigger trg_grant_founding_no
  before update of application_status on providers
  for each row execute function grant_founding_no();

commit;
