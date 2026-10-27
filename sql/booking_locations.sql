-- 마사지사가 '출발'한 뒤 도착까지 그 예약의 손님·담당 마사지사·관리자에게만 보이는 실시간 위치 (예약당 최신 한 줄)
-- 쓰기: 담당 마사지사, 예약이 on_the_way 일 때만. 읽기: 손님·담당·관리자. on_the_way 를 벗어나면 줄을 지운다.
-- providers.last_lat/last_lng 는 providers_public_read(USING true)라 누구나 읽으므로 실시간 좌표를 거기 두지 않는다.

create table if not exists public.booking_locations (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  lat        double precision not null check (lat between -90 and 90),
  lng        double precision not null check (lng between -180 and 180),
  accuracy   real,
  updated_at timestamptz not null default now()
);

alter table public.booking_locations enable row level security;
revoke all on public.booking_locations from anon, authenticated;
grant select, insert, update on public.booking_locations to authenticated;

-- 담당 마사지사이고 지금 이동 중인 예약인가 (가드 guard_booking_write 와 같은 기준: profile_id 또는 owner_id)
create or replace function public.booking_loc_can_write(p_booking uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1 from bookings b join providers pr on pr.id = b.provider_id
     where b.id = p_booking and b.status = 'on_the_way'
       and (pr.profile_id = auth.uid() or pr.owner_id = auth.uid()))
$$;

-- 그 예약의 손님·담당 마사지사·관리자인가
create or replace function public.booking_loc_can_read(p_booking uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select public.is_admin() or exists (
    select 1 from bookings b left join providers pr on pr.id = b.provider_id
     where b.id = p_booking
       and (b.customer_id = auth.uid() or pr.profile_id = auth.uid() or pr.owner_id = auth.uid()))
$$;

revoke execute on function public.booking_loc_can_write(uuid) from public, anon;
revoke execute on function public.booking_loc_can_read(uuid) from public, anon;
grant execute on function public.booking_loc_can_write(uuid) to authenticated;
grant execute on function public.booking_loc_can_read(uuid) to authenticated;

drop policy if exists booking_locations_read on public.booking_locations;
create policy booking_locations_read on public.booking_locations
  for select to authenticated using (public.booking_loc_can_read(booking_id));

drop policy if exists booking_locations_insert on public.booking_locations;
create policy booking_locations_insert on public.booking_locations
  for insert to authenticated with check (public.booking_loc_can_write(booking_id));

drop policy if exists booking_locations_update on public.booking_locations;
create policy booking_locations_update on public.booking_locations
  for update to authenticated
  using (public.booking_loc_can_write(booking_id))
  with check (public.booking_loc_can_write(booking_id));

-- 갱신 시각은 서버 시각으로만
create or replace function public.booking_loc_touch()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_booking_loc_touch on public.booking_locations;
create trigger trg_booking_loc_touch
  before insert or update on public.booking_locations
  for each row execute function public.booking_loc_touch();

-- 도착(in_progress)·취소·완료 등으로 on_the_way 를 벗어나면 위치를 지운다
create or replace function public.booking_loc_clear()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if old.status = 'on_the_way' and new.status is distinct from 'on_the_way' then
    delete from booking_locations where booking_id = new.id;
  end if;
  return null;
end $$;

drop trigger if exists trg_booking_loc_clear on public.bookings;
create trigger trg_booking_loc_clear
  after update of status on public.bookings
  for each row execute function public.booking_loc_clear();

-- 손님 화면이 바로 받도록 Realtime 발행에 넣는다 (구독자 RLS 로 걸러진다)
do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'booking_locations') then
    alter publication supabase_realtime add table public.booking_locations;
  end if;
end $$;