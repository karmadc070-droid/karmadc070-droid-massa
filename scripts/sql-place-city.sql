-- 손님이 고른 장소(place_id)의 성을 기억해 두고, 예약이 들어올 때 그 성으로 '다른 성 거절'을 실제로 작동시킨다 (2026-10-29)
--
-- 왜 — 예약의 성(bookings.city_code)은 나중에 vps-booking-region.py 가 채운다. 예약 순간에는 비어 있어서
--   guard_booking_distance 의 '다른 성' 검사가 한 번도 걸리지 않았다.
--   실제로 떠이닌성 Bến Lức(호치민 중심에서 27km)에서 호치민 마사지사에게 2건이 들어왔다.
--   그 마사지사는 활동 프엉이 없어 성 중심점으로 거리를 재니 50km 기준 안이었다.
-- 장소의 성은 places-search 함수가 손님이 장소를 고를 때 구글 주소(성 단계)에서 읽어 여기에 적는다.
-- 거리 기준은 50km 그대로 둔다. 같은 성 안에서도 성 중심점이 먼 손님(호치민은 빈즈엉·붕따우까지 합쳐졌다)을 막지 않으려고.

begin;

create table if not exists public.place_city (
  place_id   text primary key,
  city_code  text not null references public.regions(code),
  created_at timestamptz not null default now()
);
alter table public.place_city enable row level security;   -- 정책 없음: 서비스 키(함수)와 security definer 트리거만 쓴다

create or replace function public.guard_booking_distance()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  pp record;
  km numeric;
  lim numeric := coalesce((select (value->>'far_block_km')::numeric
                             from app_settings where key = 'booking'), 30);
begin
  if new.provider_id is null then return new; end if;
  select * into pp from public.provider_point(new.provider_id);
  if not found then return new; end if;

  -- 좌표가 없으면 거리를 잴 수가 없다. 잴 수 없으면 받지 않는다.
  if new.lat is null or new.lng is null then
    raise exception '지도에서 숙소·건물을 골라 주세요. 위치를 알아야 테라피스트가 찾아갑니다.'
      using errcode = '42501', hint = 'need_place';
  end if;

  if pp.lat is not null then
    km := 2 * 6371 * asin(sqrt(
            power(sin(radians(pp.lat - new.lat) / 2), 2)
            + cos(radians(new.lat)) * cos(radians(pp.lat))
              * power(sin(radians(pp.lng - new.lng) / 2), 2)));
    if km > lim then
      raise exception '이 테라피스트의 활동 지역에서 너무 멉니다 (약 %km). 가까운 분을 골라 주세요.',
        round(km) using errcode = '42501', hint = 'too_far';
    end if;
  end if;

  -- 예약 순간에는 성이 비어 있다. 손님이 고른 장소의 성을 알고 있으면 채운다 (2026-10-29)
  if new.city_code is null and new.place_id is not null then
    select pc.city_code into new.city_code from public.place_city pc where pc.place_id = new.place_id;
  end if;

  if new.city_code is not null and pp.city is not null and new.city_code <> pp.city then
    raise exception '해당 지역에 마사지사가 없습니다.'
      using errcode = '42501', hint = 'other_province';
  end if;

  return new;
end
$function$;

-- 오늘 20km 로 낮췄던 것을 되돌린다 — 성 검사가 범위 밖을 맡는다
update app_settings set value = jsonb_set(value, '{far_block_km}', '50') where key = 'booking';

commit;
