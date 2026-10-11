-- 예약이 어느 성·프엉에서 일어났는지 담는 칸을 만든다.
--
-- 값은 앱이 보내지 않는다. 예약에 이미 저장되는 구글 place_id 로 서버가 나중에 채운다
-- (scripts/vps-booking-region.sh). 그래야 앱 출시 없이 지금 있는 예약부터 쓸 수 있다.

begin;

alter table public.bookings add column if not exists city_code text references public.regions(code);
alter table public.bookings add column if not exists ward_code text references public.regions(code);

comment on column public.bookings.city_code is '예약 장소의 성·직할시. place_id 로 서버가 채운다';
comment on column public.bookings.ward_code is '예약 장소의 프엉. 모르면 비어 있다';

create index if not exists idx_bookings_city on public.bookings(city_code);

commit;
