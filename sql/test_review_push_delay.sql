-- review_push_delay.sql 의 후기 요청 푸시 지연(예약 시각+3h, 베트남 시간 08~22시)을 확인하는 테스트 (로컬 재현 DB 전용, 끝에 rollback)
\set ON_ERROR_STOP 1
begin;
\ir review_push_delay.sql
-- 두 번 적용해도 안전한지
\ir review_push_delay.sql

-- 운영과 같은 권한(덤프에는 권한이 빠져 있다): claim 은 postgres·service_role 만
revoke all on function public.claim_unpushed_notifications() from public, anon, authenticated;

-- 1) 발송 가능 시간 (베트남 시간 = UTC+7)
do $$ begin
  if public.review_push_window_open('2026-10-31 23:30+07') then raise exception 'FAIL 23:30 open'; end if;
  if public.review_push_window_open('2026-11-01 03:00+07') then raise exception 'FAIL 03:00 open'; end if;
  if public.review_push_window_open('2026-11-01 07:59+07') then raise exception 'FAIL 07:59 open'; end if;
  if not public.review_push_window_open('2026-11-01 08:00+07') then raise exception 'FAIL 08:00 closed'; end if;
  if not public.review_push_window_open('2026-11-01 12:00+07') then raise exception 'FAIL 12:00 closed'; end if;
  if not public.review_push_window_open('2026-11-01 21:59+07') then raise exception 'FAIL 21:59 closed'; end if;
  if public.review_push_window_open('2026-11-01 22:00+07') then raise exception 'FAIL 22:00 open'; end if;
  raise notice 'PASS window 08:00~22:00 (23:30·03:00·07:59·22:00 closed)';
end $$;

alter table bookings disable trigger trg_guard_booking_distance;
alter table bookings disable trigger trg_require_customer_basics;
alter table bookings disable trigger trg_guard_rejected_rebook;

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000c1', 'c1@test.local');
insert into profiles (id) values ('00000000-0000-0000-0000-0000000000c1') on conflict do nothing;
insert into providers (id, display_name, application_status, is_active) values ('00000000-0000-0000-0000-0000000000a1', '[TEST] p1', 'pending', false);
insert into services (id, name, duration_min, price_vnd) values ('00000000-0000-0000-0000-0000000000f1', 't', 60, 300000);

-- d1: 1시간 전 시작(아직 +3h 전) / d2: 5시간 전 시작(이미 +3h 지남) / d4: 5시간 전 시작이지만 후기를 이미 씀
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, status, amount_vnd) values
 ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', now() - interval '1 hour', 'requested', 300000),
 ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', now() - interval '5 hour', 'requested', 300000),
 ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', now() - interval '5 hour', 'requested', 300000);
update bookings set status = 'confirmed', accepted_at = now() where id::text like '00000000-0000-0000-0000-0000000000d%';
-- 앞선 알림(새 신청·확정)은 이미 보낸 것으로 둔다
update notifications set pushed_at = now() where booking_id::text like '00000000-0000-0000-0000-0000000000d%';
update bookings set status = 'completed', completed_at = now() where id::text like '00000000-0000-0000-0000-0000000000d%';

-- 2) 완료하면 알림 행은 생기지만 아직 보내지 않았고, 보낼 시각이 예약 시각 + 3h(이미 지났으면 지금)
do $$ begin
  if (select count(*) from notifications where kind='booking_completed' and booking_id::text like '00000000-0000-0000-0000-0000000000d%' and pushed_at is null) <> 3 then raise exception 'FAIL 3 unpushed review notifications'; end if;
  if (select next_push_at from notifications n join bookings b on b.id=n.booking_id where n.kind='booking_completed' and b.id='00000000-0000-0000-0000-0000000000d1') <> (select scheduled_at + interval '3 hours' from bookings where id='00000000-0000-0000-0000-0000000000d1') then raise exception 'FAIL d1 next_push_at'; end if;
  if (select next_push_at from notifications where kind='booking_completed' and booking_id='00000000-0000-0000-0000-0000000000d2') <> now() then raise exception 'FAIL d2 next_push_at'; end if;
  raise notice 'PASS completed → review notification waits for scheduled_at + 3h';
end $$;

insert into reviews (booking_id, customer_id, provider_id, rating) values ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 5);
-- 다른 알림이 영향받지 않는지 보기 위한 새 공지 1건
insert into notifications (user_id, title, body, kind) values ('00000000-0000-0000-0000-0000000000c1', '[TEST] 공지', 't', 'notice');

-- 3) 밤(22:00~08:00): 후기 요청은 안 나가고, 공지는 그대로 나간다
create or replace function public.review_push_window_open(ts timestamptz) returns boolean language sql immutable as $f$ select false $f$;
create temp table c1 as select kind, booking_id from public.claim_unpushed_notifications();
do $$ begin
  if exists (select 1 from c1 where kind='booking_completed') then raise exception 'FAIL review pushed at night'; end if;
  if not exists (select 1 from c1 where kind='notice') then raise exception 'FAIL notice not pushed'; end if;
  raise notice 'PASS night hold (review) / other notifications unaffected';
end $$;

-- 4) 08:00 이후: d2 만 나간다 (d1 은 +3h 전, d4 는 후기를 이미 씀)
create or replace function public.review_push_window_open(ts timestamptz) returns boolean language sql immutable as $f$ select true $f$;
create temp table c2 as select kind, booking_id from public.claim_unpushed_notifications();
do $$ begin
  if (select count(*) from c2 where kind='booking_completed') <> 1 then raise exception 'FAIL want exactly 1 review push'; end if;
  if not exists (select 1 from c2 where booking_id='00000000-0000-0000-0000-0000000000d2') then raise exception 'FAIL d2 not pushed'; end if;
  raise notice 'PASS day: d2 pushed once, d1 waits for +3h, d4 skipped (already reviewed)';
end $$;

-- 5) 다시 돌려도 중복 없음
do $$ begin
  if exists (select 1 from public.claim_unpushed_notifications() where kind='booking_completed') then raise exception 'FAIL duplicate review push'; end if;
  raise notice 'PASS no duplicate on re-run';
end $$;

-- 6) d1 의 +3h 가 되면 나간다 (시각을 앞당겨 확인)
update notifications set next_push_at = now() - interval '1 minute' where kind='booking_completed' and booking_id='00000000-0000-0000-0000-0000000000d1';
do $$ begin
  if not exists (select 1 from public.claim_unpushed_notifications() where booking_id='00000000-0000-0000-0000-0000000000d1') then raise exception 'FAIL d1 not pushed after +3h'; end if;
  raise notice 'PASS d1 pushed once +3h passed';
end $$;

-- 7) 앱 사용자는 claim·시간 함수를 부를 수 없다
grant usage on schema public to authenticated;
set local role authenticated;
do $$ begin
  begin perform public.claim_unpushed_notifications(); raise exception 'FAIL authenticated could claim';
  exception when insufficient_privilege then raise notice 'PASS authenticated cannot claim'; end;
  begin perform public.review_push_window_open(now()); raise exception 'FAIL authenticated could call window fn';
  exception when insufficient_privilege then raise notice 'PASS authenticated cannot call window fn'; end;
end $$;
reset role;

rollback;
