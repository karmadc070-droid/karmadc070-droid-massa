-- 알림이 꺼진 마사지사는 영업 ON(목록 노출)을 할 수 없다.
--
-- 왜 (2026-10-18) — 손님이 신청해도 마사지사가 모르면 예약이 성사되지 않는다.
-- 실제로 푸시 토큰이 0건이었고 아무도 알림을 받지 못하고 있었다.
--
-- 알림 권한 자체는 강제할 수 없다. 안드로이드 13+·iOS 모두 런타임 권한이고
-- 사용자가 거부할 수 있으며 우회 수단은 없다. 그래서 **제품 규칙으로 강제**한다.
--   "알림을 켜야 주문을 받을 수 있다"
-- 등록된 기기(push_tokens)가 하나도 없으면 is_active 를 켤 수 없게 막는다.
--
-- ★ 화면에만 두면 규칙이 아니다. REST 로 바로 쏘면 그만이다. 서버에서 막는다.
--   (KYC 잠금 guard_provider_kyc 과 같은 방식)
--
-- 끄는 것은 언제나 허용한다. 막히는 건 '켜는 것'뿐이다 —
-- 알림이 꺼졌다고 이미 영업 중인 사람을 잠가버리면 빠져나올 길이 없다.

begin;

create or replace function public.provider_has_device(p_provider uuid)
returns boolean
language sql stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from push_tokens t
     where t.user_id in (
       select owner_id from providers where id = p_provider
       union
       select profile_id from providers where id = p_provider
     )
  );
$fn$;

create or replace function public.guard_provider_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  -- 끄는 것·그대로 두는 것은 통과
  if coalesce(new.is_active, false) = false then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.is_active, false) = true then return new; end if;

  -- 여기부터는 '꺼짐 → 켜짐' 이거나 '켜진 채로 새로 만들기'
  if not public.provider_has_device(new.id) then
    raise exception '알림을 켜야 영업을 시작할 수 있습니다. 앱에서 알림을 허용해 주세요.'
      using errcode = '42501', hint = 'push_required';
  end if;
  return new;
end
$fn$;

drop trigger if exists trg_guard_provider_push on public.providers;
create trigger trg_guard_provider_push
  before insert or update of is_active on public.providers
  for each row execute function public.guard_provider_push();

commit;

select 'push required ok' as result;
