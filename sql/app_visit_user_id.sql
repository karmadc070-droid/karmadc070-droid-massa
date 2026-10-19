-- app_visit 에 '누가' 를 남긴다 — 마사지사별 방문을 세기 위한 칸 하나
--
-- 지금까지 app_visit 은 device_id 와 role 만 남겼다. 그래서 "마사지사 방문 22회"
-- 는 셀 수 있어도 "누가 몇 번" 은 셀 수 없었다 (2026-10-20).
--
-- 과거 기록은 복원할 수 없다. 이 칸은 배포 시점부터 쌓인다.
-- 로그인 전 방문은 계속 null 이다. 누구인지 알 방법이 없고, 알 필요도 없다.
--
-- track_visit 은 기존 정의를 그대로 두고 user_id 만 얹는다. 시그니처(인자 3개)와
-- role 판정, 타임존, left() 자르기, 충돌 처리 방식은 손대지 않는다.
-- 앱이 호출하는 모양이 그대로여야 하므로 이것만은 바꾸면 안 된다.

alter table public.app_visit
  add column if not exists user_id uuid references auth.users(id) on delete set null;

-- 마사지사별 집계가 이 칸으로 묶이므로 인덱스를 둔다.
create index if not exists app_visit_user_idx
  on public.app_visit (user_id, visit_date)
  where user_id is not null;

create or replace function public.track_visit(p_device text, p_platform text default null::text, p_lang text default null::text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare uid uuid := auth.uid(); r text;
begin
  if uid is not null then
    r := case when exists (select 1 from providers pr
                            where pr.profile_id = uid or pr.owner_id = uid)
               then 'provider' else 'customer' end;
  end if;

  insert into public.app_visit (visit_date, device_id, platform, lang, is_member, role, user_id)
  values ((now() at time zone 'Asia/Ho_Chi_Minh')::date,
          left(p_device, 64), left(p_platform, 24), left(p_lang, 8), uid is not null, r, uid)
  on conflict (visit_date, device_id) do update
    -- 로그인 전에 한 번 열고 나중에 로그인하는 사람이 많다. 알게 된 쪽으로 올린다.
    -- 예전 do nothing 이면 그 날은 영영 '로그인 전' 으로 남는다.
    set is_member = public.app_visit.is_member or excluded.is_member,
        role      = coalesce(excluded.role, public.app_visit.role),
        -- 같은 이유로 사람도 알게 된 쪽으로 올린다. 한 기기를 두 사람이 쓰면
        -- 그날 먼저 로그인한 사람으로 남는다. 드문 일이고 더 정교할 이유가 없다.
        user_id   = coalesce(public.app_visit.user_id, excluded.user_id);
end $function$;
