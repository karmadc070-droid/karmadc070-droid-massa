-- 마사지사별 활동 지표를 관리자에게 돌려주는 함수 (수락률·반응속도·완료)
--
-- 왜 만드나. 2026-10-19 밤에 알아낸 것이 있다. 지금까지 들어온 예약 17건 중
-- 수락된 것이 0건이다. 마사지사가 게을러서가 아니라 수락할 화면이 없었고
-- 알림도 가지 않았기 때문이다. 둘 다 1.1.105 에서 고쳐진다.
-- 이 함수는 그 수리가 실제로 통했는지 재는 계기판이다. 기준선은 0 이다.
--
-- 기기 수를 같이 돌려준다. 수락률이 0 인 사람이 기기도 0 이면 그건 성실도가
-- 아니라 알림이 닿지 않은 것이다. 둘을 나란히 두지 않으면 사람을 오해한다.

create or replace function public.admin_provider_activity()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  out_rows jsonb;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception '관리자만 조회할 수 있습니다.' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(r order by r->>'name'), '[]'::jsonb) into out_rows
  from (
    select jsonb_build_object(
      'id',        pr.id,
      'name',      pr.display_name,
      'city',      (select rg.name_ko from regions rg where rg.code = pr.city_code),
      'is_active', pr.is_active,
      -- 받을 수 있는 기기가 없으면 수락률을 탓할 수 없다.
      'devices',   (select count(*) from push_tokens t
                     where t.user_id = coalesce(pr.profile_id, pr.owner_id)),
      'got',       coalesce(b.got, 0),
      'accepted',  coalesce(b.accepted, 0),
      'rejected',  coalesce(b.rejected, 0),
      'completed', coalesce(b.completed, 0),
      'cancelled', coalesce(b.cancelled, 0),
      -- 받은 게 없으면 비율은 null 이다. 0% 로 적으면 안 받은 사람과
      -- 받고도 안 한 사람이 같아 보인다.
      'accept_rate', case when coalesce(b.got,0) = 0 then null
                          else round(100.0 * b.accepted / b.got) end,
      -- 평균 수락 시간(초). 손님은 이 숫자만큼 기다린다.
      'accept_sec', b.accept_sec,
      'last_got',   b.last_got,
      -- 앱 방문. app_visit.user_id 는 2026-10-20 에 생겼으므로 그 전 기록은 없다.
      -- 하루 한 기기에 한 줄이라 '며칠 들어왔나' 에 가깝다. 횟수가 아니다.
      'visit_days', coalesce(v.days, 0),
      'last_visit', v.last_visit
    ) as r
    from providers pr
    left join lateral (
      select count(*)                                              as got,
             count(*) filter (where x.accepted_at  is not null)    as accepted,
             count(*) filter (where x.rejected_at  is not null)    as rejected,
             count(*) filter (where x.completed_at is not null)    as completed,
             count(*) filter (where x.cancelled_by = 'provider')   as cancelled,
             round(avg(extract(epoch from (x.accepted_at - x.created_at)))
                   filter (where x.accepted_at is not null))::int  as accept_sec,
             max(x.created_at)                                     as last_got
      from bookings x
      where x.provider_id = pr.id
    ) b on true
    left join lateral (
      select count(*)::int     as days,
             max(a.visit_date) as last_visit
      from app_visit a
      where a.user_id = coalesce(pr.profile_id, pr.owner_id)
    ) v on true
    where pr.application_status = 'approved'
  ) s;

  return jsonb_build_object(
    'rows', out_rows,
    -- 전체 합계. 개인별로 0 이어도 전체가 0 인지 한 사람만 0 인지 바로 보인다.
    'total', (select jsonb_build_object(
                'got',       count(*),
                'accepted',  count(*) filter (where accepted_at  is not null),
                'completed', count(*) filter (where completed_at is not null))
              from bookings)
  );
end;
$$;

revoke all on function public.admin_provider_activity() from public;
grant execute on function public.admin_provider_activity() to authenticated;
