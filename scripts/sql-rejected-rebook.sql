-- 마사지사가 거절한 손님이 24시간 안에 같은 마사지사에게 다시 예약하는 것을 막는다 (2026-10-29)
-- 거절 기록은 bookings.rejected_at 이다(마사지사 거절 = status cancelled + rejected_at).
-- 자동 전달(fanout_stale_bookings)은 한 건씩 예외를 삼키므로 여기서 막혀도 나머지는 계속 간다.
begin;

create or replace function public.guard_rejected_rebook() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.customer_id is not null and new.provider_id is not null and exists (
    select 1 from public.bookings b
    where b.customer_id = new.customer_id
      and b.provider_id = new.provider_id
      and b.rejected_at > now() - interval '24 hours'
  ) then
    raise exception '마사지사가 요청을 거절하였습니다.' using hint = 'rejected_rebook';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_rejected_rebook on public.bookings;
create trigger trg_guard_rejected_rebook before insert on public.bookings
  for each row execute function public.guard_rejected_rebook();

-- Huỳnh như: 활동 지역이 'Quận 7 phú mỹ hưng' 인데 좌표가 없어 호찌민 중심에서 거리를 쟀다.
-- 거리는 provider_point(동 중심 → 없으면 성 중심)로 잰다. 호찌민에는 동이 하나도 없어서
-- 푸미흥이 속한 새 행정동 Tân Mỹ 를 추가하고 그 동으로 지정한다.
-- (처음엔 providers.lat 을 넣었으나 그 값은 provider_private 로 옮겨질 뿐 거리 계산에 안 쓰여 되돌렸다)
delete from public.provider_private
where provider_id = '0faf6bad-5fed-4a2e-b716-c7975be1e44d' and lat = 10.729 and lng = 106.709
  and last_lat is null and zalo is null and kakao is null and photo_url_orig is null;
insert into public.regions (code, parent_code, level, name_vi, name_ko, name_en, lat, lng, is_active, sort)
values ('hcmc.tan-my', 'hcmc', 2, 'Tân Mỹ (Phú Mỹ Hưng)', '떤미(푸미흥)', 'Tan My (Phu My Hung)', 10.7295, 106.7105, true, 99)
on conflict (code) do nothing;
update public.providers set ward_codes = array['hcmc.tan-my']
where id = '0faf6bad-5fed-4a2e-b716-c7975be1e44d';

commit;
