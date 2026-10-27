-- sql/booking_superseded.sql 을 트랜잭션 안에서 적용해 보고 수락·재수락·손님 취소를 시험한 뒤 전부 되돌린다
-- 실행: (echo 'begin;'; cat booking_superseded.sql; cat test_booking_superseded.sql; echo 'rollback;') | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 등장인물: 손님 C, 마사지사 A(Vui)·B(Mi)·C2(Huỳnh như). 묶음 g1 = b1(A)·b2(B, 원본)·b3(C2), 묶음 g2 = b4(A)·b5(B)

set local session_replication_role = replica;   -- 시험 예약 만들 때만 트리거 우회
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, amount_vnd, status, group_id, created_at) values
 ('00000000-0000-4000-8000-0000000000b2', 'f8e73589-6145-4180-a325-6af5b777757c', '697e7085-98e5-499a-8c80-a9a037763170', (select id from services limit 1), now() + interval '2 hour', 500000, 'requested', '00000000-0000-4000-8000-0000000000a1', now() - interval '15 min'),
 ('00000000-0000-4000-8000-0000000000b1', 'f8e73589-6145-4180-a325-6af5b777757c', '5452a420-6b22-48b8-94f9-ba90851a86be', (select id from services limit 1), now() + interval '2 hour', 500000, 'requested', '00000000-0000-4000-8000-0000000000a1', now()),
 ('00000000-0000-4000-8000-0000000000b3', 'f8e73589-6145-4180-a325-6af5b777757c', '0faf6bad-5fed-4a2e-b716-c7975be1e44d', (select id from services limit 1), now() + interval '2 hour', 500000, 'requested', '00000000-0000-4000-8000-0000000000a1', now()),
 ('00000000-0000-4000-8000-0000000000b4', 'f8e73589-6145-4180-a325-6af5b777757c', '5452a420-6b22-48b8-94f9-ba90851a86be', (select id from services limit 1), now() + interval '3 hour', 500000, 'requested', '00000000-0000-4000-8000-0000000000a2', now()),
 ('00000000-0000-4000-8000-0000000000b5', 'f8e73589-6145-4180-a325-6af5b777757c', '697e7085-98e5-499a-8c80-a9a037763170', (select id from services limit 1), now() + interval '3 hour', 500000, 'requested', '00000000-0000-4000-8000-0000000000a2', now());
insert into notifications (user_id, title, kind, booking_id) values
 ('7c6969e9-506c-4ab4-ab0c-f14589e6a6ef', 't', 'booking_new', '00000000-0000-4000-8000-0000000000b1'),
 ('707be270-c181-46cc-a04d-5dfad46205a5', 't', 'booking_new', '00000000-0000-4000-8000-0000000000b2'),
 ('0f35d5b7-967a-4102-a6f3-06f94896a4bf', 't', 'booking_new', '00000000-0000-4000-8000-0000000000b3'),
 ('f8e73589-6145-4180-a325-6af5b777757c', 't', 'info',        '00000000-0000-4000-8000-0000000000b2');
set local session_replication_role = origin;

\echo '--- A 가 b1 수락'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"7c6969e9-506c-4ab4-ab0c-f14589e6a6ef","role":"authenticated"}', true);
select status from accept_booking('00000000-0000-4000-8000-0000000000b1');
reset role;
do $$ declare n int; begin
  select count(*) into n from bookings where group_id = '00000000-0000-4000-8000-0000000000a1';
  if n <> 1 then raise exception 'FAIL 1: 묶음 g1 이 bookings 에 %행', n; end if;
  raise notice 'PASS 1 묶음 g1 은 bookings 에 1행(확정)';
  select count(*) into n from booking_superseded
   where id in ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000b3')
     and accepted_booking_id = '00000000-0000-4000-8000-0000000000b1' and status = 'requested';
  if n <> 2 then raise exception 'FAIL 2: booking_superseded 에 %행', n; end if;
  raise notice 'PASS 2 b2·b3 는 booking_superseded 에 그대로(requested) 옮겨짐';
  select count(*) into n from notifications
   where booking_id in ('00000000-0000-4000-8000-0000000000b2', '00000000-0000-4000-8000-0000000000b3');
  if n <> 0 then raise exception 'FAIL 3: 옮긴 사본을 가리키는 알림 %건', n; end if;
  raise notice 'PASS 3 옮긴 사본을 가리키는 알림 0건(새 신청 알림 지움)';
  select count(*) into n from notifications
   where user_id = 'f8e73589-6145-4180-a325-6af5b777757c' and kind = 'info' and title = 't'
     and booking_id = '00000000-0000-4000-8000-0000000000b1';
  if n <> 1 then raise exception 'FAIL 4: 손님 info 알림이 수락된 예약으로 안 옮겨짐'; end if;
  raise notice 'PASS 4 손님 info 알림은 수락된 예약(b1)으로 옮겨짐';
  select count(*) into n from notifications
   where kind = 'booking_taken' and booking_id is null and created_at = now()
     and user_id in ('707be270-c181-46cc-a04d-5dfad46205a5', '0f35d5b7-967a-4102-a6f3-06f94896a4bf');
  if n <> 2 then raise exception 'FAIL 5: 진 마사지사 알림 %건', n; end if;
  raise notice 'PASS 5 B·C2 에게 링크 없는 "먼저 수락" 알림 2건';
  select count(*) into n from bookings where cancel_reason = '다른 테라피스트가 먼저 수락했습니다' and group_id = '00000000-0000-4000-8000-0000000000a1';
  if n <> 0 then raise exception 'FAIL 6'; end if;
  raise notice 'PASS 6 system 취소 행이 생기지 않음';
end $$;

\echo '--- B 가 옛 화면에서 b2 수락'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"707be270-c181-46cc-a04d-5dfad46205a5","role":"authenticated"}', true);
do $$ begin
  perform accept_booking('00000000-0000-4000-8000-0000000000b2');
  raise exception 'FAIL 7: 옮긴 사본이 수락됨';
exception when insufficient_privilege then
  if sqlerrm not like '%먼저 수락%' then raise exception 'FAIL 7: 오류 문구 %', sqlerrm; end if;
  raise notice 'PASS 7 B 재수락 → "%"', sqlerrm;
end $$;
do $$ declare n int; begin
  select count(*) into n from booking_superseded;
  if n <> 0 then raise exception 'FAIL 8: 마사지사가 booking_superseded 를 %행 읽음', n; end if;
  raise notice 'PASS 8 마사지사는 booking_superseded 를 못 읽음';
end $$;
\echo '--- 없는 id'
do $$ begin
  perform accept_booking('00000000-0000-4000-8000-0000000000ff');
  raise exception 'FAIL 9';
exception when insufficient_privilege then
  if sqlerrm not like '%찾을 수 없%' then raise exception 'FAIL 9: %', sqlerrm; end if;
  raise notice 'PASS 9 없는 예약 → "%"', sqlerrm;
end $$;

\echo '--- 수락 전 손님 취소(g2 의 b4)'
select set_config('request.jwt.claims', '{"sub":"f8e73589-6145-4180-a325-6af5b777757c","role":"authenticated"}', true);
update bookings set status = 'cancelled', cancelled_at = now(), cancel_reason = '시험', cancelled_by = 'customer'
 where id = '00000000-0000-4000-8000-0000000000b4';
reset role;
do $$ declare n int; begin
  select count(*) into n from bookings where id = '00000000-0000-4000-8000-0000000000b4' and status = 'cancelled' and cancelled_by = 'customer';
  if n <> 1 then raise exception 'FAIL 10'; end if;
  select count(*) into n from notifications where booking_id = '00000000-0000-4000-8000-0000000000b4' and kind = 'booking_cancelled_by_customer';
  if n < 1 then raise exception 'FAIL 10: 마사지사 취소 알림 없음'; end if;
  select count(*) into n from booking_superseded where group_id = '00000000-0000-4000-8000-0000000000a2';
  if n <> 0 then raise exception 'FAIL 10: 손님 취소가 옮겨짐'; end if;
  raise notice 'PASS 10 손님 취소는 예전처럼 cancelled/customer + 마사지사 알림, 옮기지 않음';
end $$;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"707be270-c181-46cc-a04d-5dfad46205a5","role":"authenticated"}', true);
select status from accept_booking('00000000-0000-4000-8000-0000000000b5');
reset role;
do $$ declare n int; begin
  select count(*) into n from bookings where group_id = '00000000-0000-4000-8000-0000000000a2';
  if n <> 2 then raise exception 'FAIL 11: g2 %행', n; end if;
  raise notice 'PASS 11 손님이 취소한 사본은 남고(취소 기록), 나머지 수락 정상';
end $$;