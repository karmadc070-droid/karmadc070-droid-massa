-- 채팅 본문에 전화번호·외부 메신저 아이디를 쓰지 못하게 막는다.
--
-- 왜 (2026-10-18) — 마사지사는 손님 연락처를 못 본다(profiles RLS 가 self+admin 뿐).
-- 그래서 남은 유출 경로는 둘뿐이다. ① 채팅에 "제 번호 09xx 로 연락주세요" ② 현장 대면.
-- ②는 어떤 플랫폼도 못 막는다. ①은 막을 수 있고, 여기서 막는다.
--
-- 화면에서만 막으면 소용없다. 앱을 우회해 REST 로 바로 넣으면 그만이다. 서버에서 막는다.
--
-- 과하게 막지 않으려고 한 것
--  · 가격(300.000 VND), 시간(14:30), 호실(1203) 은 정상 대화다. 막으면 안 된다.
--  · 그래서 "숫자가 많다"가 아니라 **전화번호 모양**일 때만 막는다.
--  · 베트남 번호는 0 또는 +84 로 시작하는 9~11자리다. 구분자(공백·점·하이픈)를 끼워도 잡는다.

begin;

create or replace function public.guard_no_contact_in_message()
returns trigger
language plpgsql
as $fn$
declare
  body text := coalesce(new.body, '');
  low  text := lower(coalesce(new.body, ''));
begin
  -- 1) 전화번호 모양. 0 또는 +84 로 시작해 숫자 9~10개가 이어질 때.
  --    구분자(공백·점·하이픈·괄호)가 끼어 있어도 잡는다.
  --    ★ 숫자만 뽑아 붙이는 방식은 쓰지 않는다. "0 phut ... 123456789" 처럼
  --      무관한 숫자가 이어 붙어 멀쩡한 대화를 막아버린다.
  if body ~ '(\+?84|0)[\s.()-]*([0-9][\s.()-]*){8,9}[0-9]' then
    raise exception '연락처는 주고받을 수 없습니다. 예약과 결제는 앱 안에서 진행해 주세요.'
      using errcode = '42501', hint = 'contact_blocked';
  end if;

  -- 2) 외부 메신저로 빼돌리는 흔한 표현
  if low ~ '(zalo|whatsapp|telegram|kakao|viber|wechat|messenger|facebook\.com|fb\.com|m\.me/|t\.me/|wa\.me/|zalo\.me/)' then
    raise exception '외부 메신저 안내는 보낼 수 없습니다. 대화는 앱 안에서 해주세요.'
      using errcode = '42501', hint = 'contact_blocked';
  end if;

  return new;
end
$fn$;

drop trigger if exists trg_guard_no_contact on public.messages;
create trigger trg_guard_no_contact
  before insert on public.messages
  for each row execute function public.guard_no_contact_in_message();

commit;

select 'no-contact-in-chat ok' as result;
