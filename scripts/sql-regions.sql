-- 지역(성·시 → 프엉·싸) 2단계 구조와 좌표를 담는 표를 만든다.
--
-- 2025-07-01 행정구역 개편 기준이다. 성·직할시 63개 → 34개로 통합됐고
-- 구(quận)·현(huyện) 단계는 폐지돼 성 아래가 바로 프엉(phường)·싸(xã)다.
-- 출처 — 베트남 정부 포털 2025-04-15 공문.
--
-- lat/lng 는 거리(km) 계산용 중심점이다. 마사지사 집 좌표를 쓰지 않는 이유는
-- 손님이 여러 지점에서 거리를 재면 집 위치가 역산되기 때문이다.

begin;

create table if not exists public.regions (
  code        text primary key,                                   -- 'hanoi' · 'hanoi.my-dinh'
  parent_code text references public.regions(code) on delete restrict,
  level       smallint not null check (level in (1, 2)),           -- 1=성·시, 2=프엉·싸
  name_vi     text not null,
  name_ko     text not null,
  name_en     text not null,
  lat         double precision,
  lng         double precision,
  is_active   boolean not null default true,
  sort        integer not null default 0
);

comment on table public.regions is '2025 개편 기준 베트남 행정구역. level 1=성·직할시(34), 2=프엉·싸';

create index if not exists idx_regions_parent on public.regions(parent_code);

-- 1단계 — 성·직할시 34개
insert into public.regions (code, parent_code, level, name_vi, name_ko, name_en, lat, lng, sort) values
  ('hanoi',       null, 1, 'Hà Nội',            '하노이',     'Hanoi',            21.0278, 105.8342,  1),
  ('hcmc',        null, 1, 'TP. Hồ Chí Minh',   '호치민',     'Ho Chi Minh City', 10.7769, 106.7009,  2),
  ('danang',      null, 1, 'Đà Nẵng',           '다낭',       'Da Nang',          16.0544, 108.2022,  3),
  ('haiphong',    null, 1, 'Hải Phòng',         '하이퐁',     'Hai Phong',        20.9230, 106.6650,  4),
  ('hue',         null, 1, 'Huế',               '후에',       'Hue',              16.4637, 107.5909,  5),
  ('cantho',      null, 1, 'Cần Thơ',           '껀터',       'Can Tho',          10.0452, 105.7469,  6),
  ('gialai',      null, 1, 'Gia Lai',           '자라이',     'Gia Lai',          13.7820, 109.2190, 10),
  ('khanhhoa',    null, 1, 'Khánh Hòa',         '칸호아',     'Khanh Hoa',        12.2388, 109.1967, 11),
  ('lamdong',     null, 1, 'Lâm Đồng',          '럼동',       'Lam Dong',         11.9404, 108.4583, 12),
  ('daklak',      null, 1, 'Đắk Lắk',           '닥락',       'Dak Lak',          12.6667, 108.0500, 13),
  ('quangngai',   null, 1, 'Quảng Ngãi',        '꽝응아이',   'Quang Ngai',       15.1214, 108.8044, 14),
  ('quangtri',    null, 1, 'Quảng Trị',         '꽝찌',       'Quang Tri',        17.4689, 106.6223, 15),
  ('nghean',      null, 1, 'Nghệ An',           '응에안',     'Nghe An',          18.6796, 105.6813, 16),
  ('hatinh',      null, 1, 'Hà Tĩnh',           '하띤',       'Ha Tinh',          18.3560, 105.8877, 17),
  ('thanhhoa',    null, 1, 'Thanh Hóa',         '타인호아',   'Thanh Hoa',        19.8067, 105.7852, 18),
  ('ninhbinh',    null, 1, 'Ninh Bình',         '닌빈',       'Ninh Binh',        20.2506, 105.9745, 19),
  ('hungyen',     null, 1, 'Hưng Yên',          '흥옌',       'Hung Yen',         20.6464, 106.0511, 20),
  ('bacninh',     null, 1, 'Bắc Ninh',          '박닌',       'Bac Ninh',         21.2730, 106.1946, 21),
  ('quangninh',   null, 1, 'Quảng Ninh',        '꽝닌',       'Quang Ninh',       20.9510, 107.0800, 22),
  ('langson',     null, 1, 'Lạng Sơn',          '랑선',       'Lang Son',         21.8530, 106.7610, 23),
  ('caobang',     null, 1, 'Cao Bằng',          '까오방',     'Cao Bang',         22.6657, 106.2570, 24),
  ('thainguyen',  null, 1, 'Thái Nguyên',       '타이응우옌', 'Thai Nguyen',      21.5942, 105.8480, 25),
  ('tuyenquang',  null, 1, 'Tuyên Quang',       '뚜옌꽝',     'Tuyen Quang',      21.8230, 105.2140, 26),
  ('laocai',      null, 1, 'Lào Cai',           '라오까이',   'Lao Cai',          21.7229, 104.9113, 27),
  ('phutho',      null, 1, 'Phú Thọ',           '푸토',       'Phu Tho',          21.3227, 105.4019, 28),
  ('sonla',       null, 1, 'Sơn La',            '선라',       'Son La',           21.3273, 103.9141, 29),
  ('dienbien',    null, 1, 'Điện Biên',         '디엔비엔',   'Dien Bien',        21.3860, 103.0230, 30),
  ('laichau',     null, 1, 'Lai Châu',          '라이쩌우',   'Lai Chau',         22.3964, 103.4590, 31),
  ('dongnai',     null, 1, 'Đồng Nai',          '동나이',     'Dong Nai',         10.9574, 106.8426, 32),
  ('tayninh',     null, 1, 'Tây Ninh',          '떠이닌',     'Tay Ninh',         11.3100, 106.0980, 33),
  ('vinhlong',    null, 1, 'Vĩnh Long',         '빈롱',       'Vinh Long',        10.2537, 105.9722, 34),
  ('dongthap',    null, 1, 'Đồng Tháp',         '동탑',       'Dong Thap',        10.3600, 106.3600, 35),
  ('camau',       null, 1, 'Cà Mau',            '까마우',     'Ca Mau',            9.1769, 105.1524, 36),
  ('angiang',     null, 1, 'An Giang',          '안장',       'An Giang',         10.0124, 105.0809, 37)
on conflict (code) do nothing;

-- 가드 — 34개가 아니면 내가 옮겨 적다 빠뜨린 것이다. 멈춘다.
do $$
declare n int;
begin
  select count(*) into n from public.regions where level = 1;
  if n <> 34 then
    raise exception '성·시가 34개여야 하는데 %개다 — 중단한다', n;
  end if;
end $$;

-- RLS — 지역 목록은 누구나 읽는다. 쓰기는 관리자만.
alter table public.regions enable row level security;

drop policy if exists regions_read_all on public.regions;
create policy regions_read_all on public.regions for select using (true);

drop policy if exists regions_admin_write on public.regions;
create policy regions_admin_write on public.regions for all
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'))
  with check (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

commit;
