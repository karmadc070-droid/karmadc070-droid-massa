-- 서류 없는 마사지사는 승인도 활동도 못 하게 막는다.
--
-- 왜 DB 인가 — 신청 화면(index.html)에는 이미 필수 검사가 있다.
-- 그런데 Kun 은 연락처만 있고 신분증·계좌가 하나도 없는 채로 승인·활동 중이다.
-- 화면 검사는 개발자 도구로 우회되고, 관리자가 실수로 누를 수도 있다.
-- 손님 집 문을 열어 주는 일이라 마지막 빗장은 서버에 있어야 한다.
--
-- 필수 네 가지 — 연락처 · 신분증 앞면 · 신분증 뒷면 · 계좌번호
-- (은행명과 사업자등록증은 화면에서만 받는다. 사장님이 말씀하신 네 가지만 잠근다.)
--
-- ★ 기존 행은 건드리지 않는다. '승인으로 바뀌는 순간'과 '활동 켜지는 순간'만 본다.
--   Kun 은 사장님 결정으로 그대로 둔다. 다만 한 번 끄면 서류 없이는 다시 못 켠다.

begin;

create or replace function kyc_required_missing(p_provider uuid)
returns text[]
language sql stable
security definer
set search_path = public
as $fn$
  select coalesce(array_remove(array[
    case when coalesce(nullif(trim(k.contact), ''), pf.phone, pr.phone) is null
         then '연락처' end,
    case when nullif(trim(k.id_front_url), '')   is null then '신분증 앞면' end,
    case when nullif(trim(k.id_back_url), '')    is null then '신분증 뒷면' end,
    case when nullif(trim(k.bank_account), '')   is null then '계좌번호' end
  ], null), array[]::text[])
  from providers pr
  left join provider_kyc k on k.provider_id = pr.id
  left join profiles pf    on pf.id = pr.profile_id
  where pr.id = p_provider;
$fn$;

grant execute on function kyc_required_missing(uuid) to authenticated;

create or replace function guard_provider_kyc()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  lack text[];
  turning_on   boolean;
  approving    boolean;
begin
  -- 끄는 것·반려하는 것은 언제나 허용한다. 막는 건 '켜는 쪽'뿐이다.
  approving  := new.application_status = 'approved'
                and coalesce(old.application_status::text, '') <> 'approved';
  turning_on := coalesce(new.is_active, false) and not coalesce(old.is_active, false);
  if not (approving or turning_on) then
    return new;
  end if;

  lack := public.kyc_required_missing(new.id);
  if cardinality(lack) > 0 then
    raise exception '서류가 없어 승인·활동할 수 없습니다: %', array_to_string(lack, ' · ')
      using errcode = '42501', hint = 'kyc_incomplete';
  end if;

  -- ★ providers.phone 에는 번호를 넣지 않는다 (2026-10-15 확인).
  --   strip_provider_phone 트리거가 일부러 항상 null 로 지운다.
  --   providers 는 손님 앱이 읽는 테이블이고 provider_kyc 는 관리자만 읽는다.
  --   번호를 여기로 옮기면 개인정보가 샌다. 정본은 provider_kyc.contact 하나다.

  return new;
end
$fn$;

drop trigger if exists trg_guard_provider_kyc on providers;
create trigger trg_guard_provider_kyc
  before update on providers
  for each row execute function guard_provider_kyc();

-- 새로 만드는 신청도 막는다. is_active 를 켠 채로 바로 넣는 경로가 있으면 안 된다.
create or replace function guard_provider_kyc_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.application_status = 'approved' or coalesce(new.is_active, false) then
    -- 만들면서 바로 승인·활동으로 넣는 건 사람 손으로만 가능해야 한다.
    if not public.is_admin() then
      raise exception '신청은 심사 대기 상태로만 만들 수 있습니다.' using errcode = '42501';
    end if;
  end if;
  return new;
end
$fn$;

drop trigger if exists trg_guard_provider_kyc_insert on providers;
create trigger trg_guard_provider_kyc_insert
  before insert on providers
  for each row execute function guard_provider_kyc_insert();

commit;
