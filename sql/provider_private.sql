-- providers 의 공개 범위를 줄인다 — 위치·연락처·원본 사진 칸은 본인·관리자만 읽는 provider_private 로 옮기고, 공개 읽기는 승인된 행만
-- 왜 칸 권한(column grant)이 아닌가 — 스토어에 나가 있는 옛 앱이 providers 를 select('*') 로 읽는다.
--   칸 하나라도 revoke 하면 '*' 가 통째로 permission denied 가 되어 옛 앱 목록이 죽는다(scripts/sql-hide-provider-phone.sql 과 같은 판단).
--   그래서 칸은 providers 에 그대로 두고(옛 앱의 select('*')·update 가 그대로 돈다) 값만 provider_private 로 옮긴다.
--   이후 providers 에 들어오는 값도 트리거가 provider_private 로 돌리고 providers 쪽은 null 로 저장한다.
-- 옮기는 칸: lat, lng, last_lat, last_lng, last_seen_at(위치), zalo, kakao(연락처, phone 은 이미 strip_provider_phone 이 비운다),
--   photo_url_orig, photo_urls_orig(보정 전 원본 사진)
-- 앱이 읽는 곳: 손님 앱은 lat/lng 가 비면 활동 프엉 중심을 쓴다(provCoord, 19명 전원 이미 null). zalo/kakao 는 관리자 화면에서만 보였다.
-- 되돌리기: 맨 아래 주석 참고

create table if not exists public.provider_private (
  provider_id     uuid primary key references public.providers(id) on delete cascade deferrable initially deferred,
  lat             double precision,
  lng             double precision,
  last_lat        double precision,
  last_lng        double precision,
  last_seen_at    timestamptz,
  zalo            text,
  kakao           text,
  photo_url_orig  text,
  photo_urls_orig text[],
  updated_at      timestamptz not null default now()
);

alter table public.provider_private enable row level security;
revoke all on public.provider_private from anon, authenticated;
grant select on public.provider_private to authenticated;   -- 쓰기는 아래 트리거(security definer)만 한다

drop policy if exists provider_private_read on public.provider_private;
create policy provider_private_read on public.provider_private
  for select to authenticated
  using (public.is_admin() or exists (
    select 1 from public.providers p
     where p.id = provider_id and (p.profile_id = auth.uid() or p.owner_id = auth.uid())));

-- providers 에 들어오는 비공개 값을 provider_private 로 돌리고 providers 에는 null 로 남긴다.
-- 이름을 zz 로 시작해 가드(trg_provider_guard, 바꿀 수 있는 칸 검사) 뒤에 돈다.
create or replace function public.divert_provider_private()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if coalesce(new.lat, new.lng, new.last_lat, new.last_lng) is not null or new.last_seen_at is not null
     or coalesce(new.zalo, new.kakao, new.photo_url_orig) is not null or new.photo_urls_orig is not null then
    insert into provider_private as pp (provider_id, lat, lng, last_lat, last_lng, last_seen_at, zalo, kakao, photo_url_orig, photo_urls_orig)
    values (new.id, new.lat, new.lng, new.last_lat, new.last_lng, new.last_seen_at, new.zalo, new.kakao, new.photo_url_orig, new.photo_urls_orig)
    on conflict (provider_id) do update set
      lat             = coalesce(excluded.lat, pp.lat),
      lng             = coalesce(excluded.lng, pp.lng),
      last_lat        = coalesce(excluded.last_lat, pp.last_lat),
      last_lng        = coalesce(excluded.last_lng, pp.last_lng),
      last_seen_at    = coalesce(excluded.last_seen_at, pp.last_seen_at),
      zalo            = coalesce(excluded.zalo, pp.zalo),
      kakao           = coalesce(excluded.kakao, pp.kakao),
      photo_url_orig  = coalesce(excluded.photo_url_orig, pp.photo_url_orig),
      photo_urls_orig = coalesce(excluded.photo_urls_orig, pp.photo_urls_orig),
      updated_at      = now();
  end if;
  new.lat := null; new.lng := null; new.last_lat := null; new.last_lng := null; new.last_seen_at := null;
  new.zalo := null; new.kakao := null; new.photo_url_orig := null; new.photo_urls_orig := null;
  return new;
end $$;

drop trigger if exists trg_provider_zz_private on public.providers;
create trigger trg_provider_zz_private
  before insert or update on public.providers
  for each row execute function public.divert_provider_private();

-- 지금 들어 있는 값을 옮긴다 — 같은 값으로 update 하면 위 트리거가 provider_private 로 옮기고 providers 쪽을 비운다
update public.providers set lat = lat
 where coalesce(lat, lng, last_lat, last_lng) is not null or last_seen_at is not null
    or coalesce(zalo, kakao, photo_url_orig) is not null or photo_urls_orig is not null;

-- 공개 읽기는 승인된 행만. 신청 중·반려된 사람(이름·사진·소개)은 더 이상 anon·다른 손님에게 보이지 않는다.
-- 본인·관리자는 providers_owner_read(authenticated: 본인·승인·관리자)로 계속 본다.
drop policy if exists providers_public_read on public.providers;
create policy providers_public_read on public.providers
  for select using (application_status = 'approved');

-- 되돌리기(값은 provider_private 에 남는다):
--   drop trigger if exists trg_provider_zz_private on public.providers; drop function if exists public.divert_provider_private();
--   drop policy if exists providers_public_read on public.providers; create policy providers_public_read on public.providers for select using (true);
