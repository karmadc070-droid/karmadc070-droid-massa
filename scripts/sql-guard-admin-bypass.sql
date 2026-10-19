-- 관리자 승인은 알림 규칙에 걸리지 않게 한다 (2026-10-19)
--
-- 왜 — guard_provider_push 는 is_active 가 꺼짐→켜짐 일 때 푸시 기기를 요구한다.
-- 그런데 reviewApp(관리자 승인)이 application_status 와 함께 is_active=true 를 넣어서,
-- 알림을 한 번도 안 켠 신청자는 관리자가 승인조차 할 수 없었다.
-- 이 규칙의 본래 뜻은 '마사지사가 스스로 영업을 켤 때' 이므로 관리자·심사자는 지나가게 한다.
-- 마사지사 본인이 켜는 경우에는 그대로 막는다 — 알림 없는 사람에게 예약이 가면 손님이 기다리다 펑크를 맞는다.
create or replace function public.guard_provider_push()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- 끄는 것·그대로 두는 것은 통과
  if coalesce(new.is_active, false) = false then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.is_active, false) = true then return new; end if;

  -- ★ 관리자·심사자가 하는 일은 통과 (승인·반려·운영 정리)
  if exists (
    select 1 from public.profiles p
     where p.id = auth.uid() and p.role in ('admin', 'reviewer')
  ) then
    return new;
  end if;

  -- 여기부터는 마사지사 본인이 '꺼짐 → 켜짐' 으로 바꾸는 경우
  if not public.provider_has_device(new.id) then
    raise exception '알림을 켜야 영업을 시작할 수 있습니다. 앱에서 알림을 허용해 주세요.'
      using errcode = '42501', hint = 'push_required';
  end if;
  return new;
end
$function$;
