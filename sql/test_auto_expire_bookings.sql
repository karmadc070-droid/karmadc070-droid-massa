-- auto_expire_bookings.sql 의 자동 취소·손님 제재 제외·알림 제외를 확인하는 테스트 (로컬 재현 DB 전용, 끝에 rollback)
\set ON_ERROR_STOP 1
begin;
\ir auto_expire_bookings.sql
-- 두 번 적용해도 안전한지
\ir auto_expire_bookings.sql

alter table bookings disable trigger trg_guard_booking_distance;
alter table bookings disable trigger trg_require_customer_basics;
alter table bookings disable trigger trg_guard_rejected_rebook;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000c1', 'c1@test.local');
insert into profiles (id) values ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
insert into providers (id, display_name, application_status, is_active) values ('00000000-0000-0000-0000-0000000000a1', '[TEST] p1', 'pending', false);
insert into services (id, name, duration_min, price_vnd) values ('00000000-0000-0000-0000-0000000000f1', 't', 60, 300000);

create temp table cut as select date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh' as t;
-- r1: 어제 23:30 신청(지난 것) → 취소 대상 / r2: 오늘 01:00 신청 → 아님 / r3: 어제 확정 → 그대로 / r4: 이틀 전 신청 → 취소
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, status, amount_vnd)
select '00000000-0000-0000-0000-0000000000b1'::uuid, '00000000-0000-0000-0000-0000000000c1'::uuid, '00000000-0000-0000-0000-0000000000a1'::uuid, '00000000-0000-0000-0000-0000000000f1'::uuid, t - interval '30 min', 'requested'::booking_status, 300000 from cut union all
select '00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', t + interval '1 hour', 'requested', 300000 from cut union all
select '00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', t - interval '5 hour', 'requested', 300000 from cut union all
select '00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', t - interval '2 day', 'requested', 300000 from cut;
-- guard 가 insert 를 requested 로 만들므로 r3 은 따로 확정으로 바꾼다(postgres 는 guard 우회)
update bookings set status = 'confirmed', accepted_at = now() where id = '00000000-0000-0000-0000-0000000000b3';

create temp table n0 as select count(*) c from notifications;

do $$ declare n int; begin
  n := public.expire_stale_bookings();
  if n <> 2 then raise exception 'FAIL expire count % (want 2)', n; end if;
  raise notice 'PASS expire count 2';
end $$;

do $$ begin
  if (select status from bookings where id='00000000-0000-0000-0000-0000000000b1') <> 'cancelled' then raise exception 'FAIL b1'; end if;
  if (select cancelled_by||'|'||cancel_reason from bookings where id='00000000-0000-0000-0000-0000000000b1') <> 'expired|시간 경과 자동 취소' then raise exception 'FAIL b1 reason'; end if;
  if (select status from bookings where id='00000000-0000-0000-0000-0000000000b2') <> 'requested' then raise exception 'FAIL b2 should stay'; end if;
  if (select status from bookings where id='00000000-0000-0000-0000-0000000000b3') <> 'confirmed' then raise exception 'FAIL b3 should stay'; end if;
  if (select status from bookings where id='00000000-0000-0000-0000-0000000000b4') <> 'cancelled' then raise exception 'FAIL b4'; end if;
  raise notice 'PASS statuses';
  if (select count(*) from notifications) <> (select c from n0) then raise exception 'FAIL notifications created'; end if;
  raise notice 'PASS no notifications';
  if (select rejected_at from bookings where id='00000000-0000-0000-0000-0000000000b1') is not null then raise exception 'FAIL rejected_at set'; end if;
  raise notice 'PASS no provider reject';
end $$;

-- 두 번 돌려도 더 바뀌지 않는다
do $$ begin if public.expire_stale_bookings() <> 0 then raise exception 'FAIL second run'; end if; raise notice 'PASS idempotent'; end $$;

-- 로컬 덤프는 권한이 빠져 있어 운영과 같은 최소 권한만 준다(테스트 전용)
grant usage on schema public, auth to authenticated;
grant select, update on bookings, profiles, providers to authenticated;

-- 손님 제재: 자동 취소 2건은 세지 않고, 손님이 직접 임박 취소한 건은 센다
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000c1","role":"authenticated"}', true);
do $$ declare n int; begin
  n := public.refresh_customer_penalty('00000000-0000-0000-0000-0000000000c1');
  if n <> 0 then raise exception 'FAIL penalty counts expired (%)', n; end if;
  raise notice 'PASS penalty ignores expired';
end $$;
reset role;
update bookings set status='cancelled', cancelled_at = scheduled_at - interval '10 min', cancelled_by='customer' where id='00000000-0000-0000-0000-0000000000b2';
set local role authenticated;
do $$ declare n int; begin
  n := public.refresh_customer_penalty('00000000-0000-0000-0000-0000000000c1');
  if n <> 1 then raise exception 'FAIL penalty should count customer late cancel (%)', n; end if;
  raise notice 'PASS penalty still counts customer';
end $$;
reset role;

-- 다른 취소 알림은 그대로
update bookings set status='requested', cancelled_at=null, cancelled_by=null where id='00000000-0000-0000-0000-0000000000b2';
update bookings set status='cancelled', cancelled_by='admin' where id='00000000-0000-0000-0000-0000000000b2';
do $$ begin
  if not exists (select 1 from notifications where booking_id='00000000-0000-0000-0000-0000000000b2' and kind='booking_cancelled') then raise exception 'FAIL admin cancel notification missing'; end if;
  raise notice 'PASS other cancel notifications unchanged';
end $$;

-- 앱 사용자는 부를 수 없다
set local role authenticated;
do $$ begin
  begin perform public.expire_stale_bookings(); raise exception 'FAIL authenticated can call';
  exception when insufficient_privilege then raise notice 'PASS authenticated denied'; end;
end $$;
reset role;
rollback;
