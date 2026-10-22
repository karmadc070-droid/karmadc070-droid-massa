-- 손님 기본정보(성명·전화·국적·성별)를 예약 전에 필수로 받고, 마사지사에게는 이름·국적·성별·이용 이력만 보여 주는 서버 규칙 (2026-10-23)
-- 화면(index.html)이 먼저 묻지만, 예전 iOS 빌드처럼 그 화면이 없는 앱도 있으므로 서버에서도 막는다.
-- 전화번호·이메일은 마사지사에게 주지 않는다 — 직거래 방지(연락처는 관리자만) 원칙과 같다.

create or replace function public.require_customer_basics()
returns trigger language plpgsql security definer set search_path = public as $$
declare p profiles%rowtype;
begin
  -- 손님 본인이 넣는 예약만 본다. 넘겨주기(크론, auth 없음)·관리자 대리 입력은 통과
  if auth.uid() is null or auth.uid() <> new.customer_id then return new; end if;
  select * into p from profiles where id = new.customer_id;
  if coalesce(trim(p.full_name), '') = '' or coalesce(trim(p.phone), '') = ''
     or coalesce(p.gender, '') = '' or coalesce(p.nationality, '') = '' then
    raise exception '예약 전에 계정 화면에서 성명·전화번호·국적·성별을 입력해 주세요. · Vui lòng nhập họ tên, số điện thoại, quốc tịch và giới tính trong Tài khoản trước khi đặt lịch.'
      using errcode = 'P0001', hint = 'profile_required';
  end if;
  return new;
end $$;

drop trigger if exists trg_require_customer_basics on public.bookings;
create trigger trg_require_customer_basics before insert on public.bookings
  for each row execute function public.require_customer_basics();

-- 마사지사가 받은 신청 화면에서 손님을 판단할 정보. 자기 신청(또는 관리자)만 볼 수 있다.
create or replace function public.provider_booking_customers(p_ids uuid[])
returns table (booking_id uuid, name text, nationality text, gender text, visits int, no_shows int, late_cancels int)
language sql stable security definer set search_path = public as $$
  select b.id, pr.full_name, pr.nationality, pr.gender,
         (select count(*)::int from bookings x where x.customer_id = b.customer_id and x.status = 'completed'),
         coalesce(pr.no_show_count, 0), coalesce(pr.cancel_count, 0)
    from bookings b
    join providers v on v.id = b.provider_id
    join profiles pr on pr.id = b.customer_id
   where b.id = any(p_ids)
     and (auth.uid() in (v.profile_id, v.owner_id)
          or exists (select 1 from profiles a where a.id = auth.uid() and a.role = 'admin'));
$$;
revoke all on function public.provider_booking_customers(uuid[]) from public, anon;
grant execute on function public.provider_booking_customers(uuid[]) to authenticated;
