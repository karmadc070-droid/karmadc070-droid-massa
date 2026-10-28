-- sql/partner.sql 을 트랜잭션 안에서 적용해 보고 파트너 생성·손님 연결·예약 귀속·수수료·지급을 시험한 뒤 전부 되돌린다
-- 실행: (echo 'begin;'; cat partner.sql test_partner.sql; echo 'rollback;') | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 등장인물 ([TEST] 계정, 전부 롤백) — A 관리자, G1 연결된 손님, G2 연결 안 된 손님, G3 31일 전에 연결된 손님

set local session_replication_role = replica;
insert into auth.users (id, email, created_at, instance_id, aud, role)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'partner-test-' || n || '@example.com', now(),
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
from unnest(array[501,502,503,504]) n;
insert into profiles (id, full_name)
select id, '[TEST] ' || email from auth.users where email like 'partner-test-%@example.com';
update profiles set role = 'admin' where id = '00000000-0000-4000-8000-000000000501';
update profiles set phone = '0900000000', gender = 'female', nationality = 'KR' where full_name like '[TEST] partner-test-%';   -- 예약 전 필수 정보
set local session_replication_role = origin;

\echo '--- 파트너 만들기'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000502","role":"authenticated"}', true);
do $$ begin perform admin_partner_create('[TEST] x', null, 'TESTX1'); raise exception 'FAIL 1';
exception when insufficient_privilege then raise notice 'PASS 1 손님은 파트너를 못 만든다'; end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000501","role":"authenticated"}', true);
select set_config('t.p1', admin_partner_create('[TEST] Demo Residence', '0900 000 000', 'testp1')::text, true);
select set_config('t.p2', admin_partner_create('[TEST] Demo Hotel', null, 'TESTP2')::text, true);
do $$ begin perform admin_partner_create('[TEST] dup', null, 'TESTP1'); raise exception 'FAIL 2';
exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; raise notice 'PASS 2 같은 코드 거부 → "%"', sqlerrm; end $$;
do $$ begin perform admin_partner_create('[TEST] bad', null, 'a-b'); raise exception 'FAIL 3';
exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; raise notice 'PASS 3 잘못된 코드 거부 → "%"', sqlerrm; end $$;

\echo '--- 손님 연결'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000502","role":"authenticated"}', true);
select claim_partner('testp1');
do $$ begin perform claim_partner('NOPE99'); raise exception 'FAIL 4';
exception when raise_exception then if sqlerrm like 'FAIL%' then raise; end if; raise notice 'PASS 4 모르는 코드 거부 → "%"', sqlerrm; end $$;
do $$ declare n int; begin select count(*) into n from partners; if n <> 0 then raise exception 'FAIL 5: 손님이 파트너 % 행을 읽음', n; end if;
  raise notice 'PASS 5 손님은 partners 를 직접 못 읽는다'; end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000504","role":"authenticated"}', true);
select claim_partner('TESTP1');
reset role;
update partner_guests set linked_at = now() - interval '31 days' where user_id = '00000000-0000-4000-8000-000000000504';

\echo '--- 예약 귀속 (손님 셋이 예약)'
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, amount_vnd, status, lat, lng)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
       ('00000000-0000-4000-8000-' || lpad(c::text, 12, '0'))::uuid,
       (select id from providers where display_name = 'Kun' limit 1), (select id from services where is_active limit 1),
       now() + interval '1 day', 500000, 'requested', 21.03, 105.85
from (values (601, 502), (602, 503), (603, 504)) v(n, c);
do $$ declare n int; begin
  select count(*) into n from partner_bookings where booking_id = '00000000-0000-4000-8000-000000000601' and partner_id = current_setting('t.p1')::uuid;
  if n <> 1 then raise exception 'FAIL 6: 연결된 손님 예약이 귀속 안 됨'; end if;
  select count(*) into n from partner_bookings where booking_id in ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000603');
  if n <> 0 then raise exception 'FAIL 7: 연결 안 됨/31일 지난 손님 예약이 귀속됨 %', n; end if;
  raise notice 'PASS 6·7 연결 30일 안 예약만 귀속 (연결 없음·31일 지남은 제외)';
end $$;

\echo '--- 완료 → 수수료'
update bookings set discount_vnd = 100000 where id = '00000000-0000-4000-8000-000000000601';
update bookings set status = 'completed', completed_at = now() where id in ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000602');
select set_config('t.amt', amount_vnd::text, true) from bookings where id = '00000000-0000-4000-8000-000000000601';   -- 서버가 굳힌 금액
update bookings set status = 'in_progress' where id = '00000000-0000-4000-8000-000000000601';
update bookings set amount_vnd = 900000 where id = '00000000-0000-4000-8000-000000000601';
update bookings set status = 'completed' where id = '00000000-0000-4000-8000-000000000601';
do $$ declare r record; begin
  select * into r from partner_bookings where booking_id = '00000000-0000-4000-8000-000000000601';
  if r.status <> 'pending_payout' or r.base_vnd <> current_setting('t.amt')::int - 100000 or r.commission_vnd <> round(r.base_vnd * 0.10) then
    raise exception 'FAIL 8: % % % (금액 %)', r.status, r.base_vnd, r.commission_vnd, current_setting('t.amt'); end if;
  perform set_config('t.com', r.commission_vnd::text, true);
  raise notice 'PASS 8 완료 → 지급 대기 %₫ (금액 % - 쿠폰 100,000 의 10%%), 금액이 바뀌고 다시 완료돼도 그대로', r.commission_vnd, current_setting('t.amt');
end $$;

\echo '--- 관리자 목록·지급'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000503","role":"authenticated"}', true);
do $$ begin perform admin_partner_list(); raise exception 'FAIL 9';
exception when insufficient_privilege then raise notice 'PASS 9 손님은 목록을 못 본다'; end $$;
do $$ begin perform admin_partner_paid(current_setting('t.p1')::uuid); raise exception 'FAIL 9b';
exception when insufficient_privilege then raise notice 'PASS 9b 손님은 지급 표시를 못 한다'; end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000501","role":"authenticated"}', true);
do $$ declare j jsonb; n int; begin
  select x into j from admin_partner_list() x where x->>'id' = current_setting('t.p1');
  if (j->>'guests')::int <> 2 or (j->>'bookings')::int <> 1 or (j->>'completed')::int <> 1 or (j->>'pending_vnd')::int <> current_setting('t.com')::int then
    raise exception 'FAIL 10: %', j; end if;
  n := admin_partner_paid(current_setting('t.p1')::uuid);
  if n <> 1 then raise exception 'FAIL 11: %', n; end if;
  select x into j from admin_partner_list() x where x->>'id' = current_setting('t.p1');
  if (j->>'pending_vnd')::int <> 0 or (j->>'paid_vnd')::int <> current_setting('t.com')::int then raise exception 'FAIL 12: %', j; end if;
  raise notice 'PASS 10~12 목록 (손님 2·예약 1·완료 1·대기 %) → 지급 1건 → 대기 0·지급 %', current_setting('t.com'), current_setting('t.com');
end $$;

\echo '--- 다른 파트너 링크로 다시 들어오면 마지막 것'
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000502","role":"authenticated"}', true);
select claim_partner('TESTP2');
reset role;
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, amount_vnd, status, lat, lng)
values ('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-000000000502', (select id from providers where display_name = 'Kun' limit 1),
        (select id from services where is_active limit 1), now() + interval '2 day', 500000, 'requested', 21.03, 105.85);
do $$ begin
  if (select partner_id from partner_bookings where booking_id = '00000000-0000-4000-8000-000000000604') <> current_setting('t.p2')::uuid
  then raise exception 'FAIL 13'; end if;
  if (select partner_id from partner_bookings where booking_id = '00000000-0000-4000-8000-000000000601') <> current_setting('t.p1')::uuid
  then raise exception 'FAIL 14: 지난 예약의 귀속이 바뀜'; end if;
  raise notice 'PASS 13·14 새 예약은 새 파트너, 지난 예약은 그대로';
end $$;

\echo '--- anon'
set local role anon;
do $$ declare n int; begin select count(*) into n from partners; if n <> 0 then raise exception 'FAIL 15'; end if;
  select count(*) into n from partner_bookings; if n <> 0 then raise exception 'FAIL 15b'; end if;
  raise notice 'PASS 15 anon 은 파트너·귀속 0행'; end $$;
do $$ begin perform claim_partner('TESTP1'); raise exception 'FAIL 16';
exception when insufficient_privilege then raise notice 'PASS 16 anon 은 claim_partner 실행 권한 없음'; end $$;
reset role;
