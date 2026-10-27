-- 마사지사 활동 기준 위치(providers.lat/lng)를 소수 둘째 자리(약 1km)로 반올림해서만 저장하게 하는 트리거
-- 앱도 반올림해서 보내지만, 앱을 고쳐 정밀 좌표를 보내도 DB 에는 둘째 자리까지만 남게 서버에서 한 번 더 자른다.
-- 되돌리기: drop trigger if exists trg_provider_zz_round_latlng on public.providers; drop function if exists public.round_provider_latlng();

create or replace function public.round_provider_latlng()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.lat := round(new.lat::numeric, 2)::double precision;
  new.lng := round(new.lng::numeric, 2)::double precision;
  return new;
end $$;

drop trigger if exists trg_provider_zz_round_latlng on public.providers;
create trigger trg_provider_zz_round_latlng
  before insert or update of lat, lng on public.providers
  for each row execute function public.round_provider_latlng();