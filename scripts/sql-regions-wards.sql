-- 프엉(phường) 9곳을 regions 에 넣고, providers 에 지역 칸을 붙이고, 기존 6명을 옮긴다.
--
-- 프엉 이름·좌표는 내가 외워서 적은 것이 아니라 구글 Places API(신규)가 돌려준 값이다.
-- ★ 그래서 'Mỹ Đình' 이 'Từ Liêm' 으로 바뀐 것을 잡아냈다 — 2025 통합으로 흡수됐다.
-- 손으로 적었으면 마사지사 4명이 없는 프엉에 묶였을 것이다.
--
-- 원본 자유입력(providers.service_area)은 지우지 않는다. 변환이 틀렸을 때 되돌릴 근거다.

begin;

-- 1. 프엉 9곳
insert into public.regions (code, parent_code, level, name_vi, name_ko, name_en, lat, lng, sort) values
  ('hanoi.tu-liem',     'hanoi',  2, 'Từ Liêm',      '뜨리엠',   'Tu Liem',      21.02729, 105.77408, 1),
  ('hanoi.ba-dinh',     'hanoi',  2, 'Ba Đình',      '바딘',     'Ba Dinh',      21.03474, 105.83784, 2),
  ('hanoi.cau-giay',    'hanoi',  2, 'Cầu Giấy',     '꺼우저이', 'Cau Giay',     21.03340, 105.79087, 3),
  ('hanoi.tay-ho',      'hanoi',  2, 'Tây Hồ',       '떠이호',   'Tay Ho',       21.05062, 105.82316, 4),
  ('hanoi.hoan-kiem',   'hanoi',  2, 'Hoàn Kiếm',    '호안끼엠', 'Hoan Kiem',    21.03362, 105.84958, 5),
  ('hanoi.tay-mo',      'hanoi',  2, 'Tây Mỗ',       '떠이모',   'Tay Mo',       20.99933, 105.75272, 6),
  ('danang.hai-chau',   'danang', 2, 'Hải Châu',     '하이쩌우', 'Hai Chau',     16.07854, 108.21699, 1),
  ('gialai.quy-nhon',   'gialai', 2, 'Quy Nhơn',     '꾸이년',   'Quy Nhon',     13.77822, 109.24152, 1),
  ('gialai.quy-nhon-nam','gialai',2, 'Quy Nhơn Nam', '꾸이년남', 'Quy Nhon Nam', 13.72571, 109.20584, 2)
on conflict (code) do nothing;

-- 2. providers 에 지역 칸
alter table public.providers add column if not exists city_code  text references public.regions(code);
alter table public.providers add column if not exists ward_codes text[] not null default '{}';

comment on column public.providers.city_code  is '활동 성·직할시 (regions.level=1)';
comment on column public.providers.ward_codes is '활동 프엉 목록 (regions.level=2). 빈 배열이면 성 전체';
comment on column public.providers.service_area is '옛 자유입력. 보관용이며 화면 기준으로 쓰지 않는다 (2026-10-11)';

create index if not exists idx_providers_city on public.providers(city_code);

-- 3. 기존 6명 옮기기 (2026-10-11 사장님 승인)
update public.providers set city_code='hanoi',
       ward_codes = array['hanoi.tu-liem','hanoi.ba-dinh','hanoi.tay-ho']
 where display_name = 'Thanh hà';
update public.providers set city_code='hanoi',
       ward_codes = array['hanoi.hoan-kiem','hanoi.tu-liem']
 where display_name = 'Kun';
update public.providers set city_code='hanoi',
       ward_codes = array['hanoi.tu-liem','hanoi.ba-dinh','hanoi.cau-giay','hanoi.tay-mo']
 where display_name = 'Thảo';
update public.providers set city_code='hanoi',
       ward_codes = array['hanoi.tu-liem']
 where display_name = 'Hồng Trà';
update public.providers set city_code='hanoi',
       ward_codes = array['hanoi.tu-liem','hanoi.ba-dinh','hanoi.cau-giay','hanoi.tay-ho','hanoi.hoan-kiem']
 where display_name = 'Trần Thành';
-- Lê Thúy Hiền 은 'Đà Nẵng' 이라고 도시만 적었다. 프엉을 내가 찍지 않는다.
-- 빈 배열 = 다낭 전체. 본인에게 물어본 뒤 채운다.
update public.providers set city_code='danang', ward_codes='{}'
 where display_name = 'Lê Thúy Hiền';

-- 4. 가드 — 6명 모두 성이 채워졌는가. 하나라도 비면 이름을 잘못 짚은 것이다.
do $$
declare n int; m int;
begin
  select count(*) into n from public.providers where city_code is null;
  if n > 0 then
    raise exception '성이 안 채워진 마사지사가 %명 있다 — 이름을 잘못 짚었다. 중단한다', n;
  end if;
  select count(*) into m from public.regions where level = 2;
  if m <> 9 then raise exception '프엉이 9개여야 하는데 %개다 — 중단한다', m; end if;
end $$;

commit;
