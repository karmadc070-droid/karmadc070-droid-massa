-- 활동 지역 밖 예약을 서버에서 막는다 (인터록).
--
-- 왜 필요했나 (2026-10-15) — 30km 규칙을 index.html 에만 넣었다.
-- 옛 iOS 앱(1.0.13)에는 그 코드가 없어서, 하노이 손님이 다낭 마사지사를 약 600km 밖에서
-- 두 건이나 신청했고 그대로 들어왔다. 화면에만 둔 규칙은 규칙이 아니다.
--
-- 기준 두 가지 — 하나라도 걸리면 막는다.
--   1) 좌표를 둘 다 아는데 30km 를 넘을 때
--   2) 성(city_code)을 둘 다 아는데 서로 다를 때
-- ★ 모르면 막지 않는다. '모른다'는 '멀다'가 아니다 — 좌표 없는 마사지사를 영영 못 쓰게 된다.

begin;

alter table app_settings add column if not exists note text;

-- 마사지사의 대표 좌표. 집 주소가 아니라 활동 프엉(없으면 성)의 중심점이다.
create or replace function provider_point(p_provider uuid)
returns table (lat double precision, lng double precision, city text)
language sql stable
security definer
set search_path = public
as $fn$
  select coalesce(w.lat, c.lat), coalesce(w.lng, c.lng), pr.city_code
    from providers pr
    left join lateral (
      select r.lat, r.lng from regions r
       where r.code = any(pr.ward_codes) and r.lat is not null
       order by r.sort limit 1) w on true
    left join regions c on c.code = pr.city_code
   where pr.id = p_provider;
$fn$;

create or replace function guard_booking_distance()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  pp record;
  km numeric;
  lim numeric := coalesce((select (value->>'far_block_km')::numeric
                             from app_settings where key = 'booking'), 30);
begin
  if new.provider_id is null then return new; end if;
  select * into pp from public.provider_point(new.provider_id);
  if not found then return new; end if;

  -- 1) 좌표로 재기 (하버사인, km)
  if new.lat is not null and new.lng is not null and pp.lat is not null then
    km := 2 * 6371 * asin(sqrt(
            power(sin(radians(pp.lat - new.lat) / 2), 2)
            + cos(radians(new.lat)) * cos(radians(pp.lat))
              * power(sin(radians(pp.lng - new.lng) / 2), 2)));
    if km > lim then
      raise exception '이 테라피스트의 활동 지역에서 너무 멉니다 (약 %km). 가까운 분을 골라 주세요.',
        round(km)
        using errcode = '42501', hint = 'too_far';
    end if;
  end if;

  -- 2) 성이 다르면 막는다. 출장 마사지는 그 성 안에서만 성립한다.
  if new.city_code is not null and pp.city is not null and new.city_code <> pp.city then
    raise exception '예약 지역과 테라피스트의 활동 지역이 다릅니다.'
      using errcode = '42501', hint = 'other_province';
  end if;

  return new;
end
$fn$;

drop trigger if exists trg_guard_booking_distance on bookings;
create trigger trg_guard_booking_distance
  before insert on bookings
  for each row execute function guard_booking_distance();

commit;
