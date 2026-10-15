-- 채팅은 마사지사가 먼저 건다.
--
-- 사장님 방침 (2026-10-15): 손님이 먼저 말을 걸게 두면 안 된다.
-- 수락한 마사지사가 손님에게 재확인 메시지를 보내는 것이 맞다. Glow 도 그렇게 돈다.
--
-- 왜 그게 맞나 — 손님은 "올까 안 올까"를 모른 채 기다린다. 먼저 연락이 오면 그 불안이
-- 사라진다. 오늘 지운 신고 두 건("không đến", "không thấy nhân viên đâu")이 정확히
-- 그 공백에서 나왔다.
--
-- 화면에서 버튼을 숨기는 것만으로는 부족하다. 여기서 막는다.

begin;

create or replace function guard_first_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.sender_role <> 'customer' then
    return new;   -- 마사지사·관리자는 언제나 먼저 보낼 수 있다
  end if;

  if exists (select 1 from messages m
              where m.customer_id = new.customer_id
                and m.provider_id = new.provider_id
                and m.sender_role <> 'customer') then
    return new;   -- 이미 마사지사가 말을 걸었다 — 손님도 답할 수 있다
  end if;

  raise exception '테라피스트가 먼저 연락드립니다. 조금만 기다려 주세요.'
    using errcode = '42501', hint = 'provider_first';
end
$fn$;

drop trigger if exists trg_guard_first_message on messages;
create trigger trg_guard_first_message
  before insert on messages
  for each row execute function guard_first_message();

-- 손님 화면에서 "채팅을 열 수 있나"를 한 번에 묻기 위한 함수.
-- 예약 목록마다 메시지 테이블을 뒤지면 느리다.
create or replace function chats_opened()
returns setof uuid
language sql stable
security definer
set search_path = public
as $fn$
  select distinct provider_id from messages
   where customer_id = auth.uid() and sender_role <> 'customer';
$fn$;

grant execute on function chats_opened() to authenticated;

commit;
