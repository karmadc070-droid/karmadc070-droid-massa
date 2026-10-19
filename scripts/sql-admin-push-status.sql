-- 관리자 화면에서 '누가 알림을 안 켰는지' 보기 위한 조회 (2026-10-19)
--
-- 왜 — 10/19 첫 실제 예약이 마사지사에게 닿지 않았다. 기기가 0개였는데
-- 관리자 화면 어디에도 그게 보이지 않아, 사고가 난 뒤에야 알았다.
--
-- ★ push_tokens 는 본인만 읽는다(RLS). 그래서 관리자도 개수를 셀 수 없다.
--   토큰 값은 절대 내보내지 않고, '있다/없다' 와 개수만 돌려준다.
create or replace function public.admin_push_status()
returns table (provider_id uuid, device_count int)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not exists (
    select 1 from public.profiles p
     where p.id = auth.uid() and p.role in ('admin', 'reviewer')
  ) then
    raise exception '권한이 없습니다' using errcode = '42501';
  end if;

  return query
    select pr.id,
           (select count(*)::int from public.push_tokens t
             where t.user_id = coalesce(pr.profile_id, pr.owner_id))
    from public.providers pr;
end
$$;

revoke execute on function public.admin_push_status() from public;
grant execute on function public.admin_push_status() to authenticated;
