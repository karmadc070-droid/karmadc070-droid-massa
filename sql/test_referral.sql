-- sql/referral.sql·provider_invite_push.sql 을 트랜잭션 안에서 적용해 보고 친구 초대 전 과정과 푸시 대상을 시험한 뒤 전부 되돌린다
-- 실행: (echo 'begin;'; cat referral.sql provider_invite_push.sql test_referral.sql; echo 'rollback;') | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 등장인물 ([TEST] 계정, 전부 롤백) — I1 손님 초대자(가입 10일), F1 새 친구, OLD 가입 5일 된 계정,
--   T1 초대하는 마사지사(PT1), 이미 보상받은 더미 8명, T2·T3·T4 새 마사지사(PT2·PT3·PT4)

set local session_replication_role = replica;   -- 시험 계정·예약을 만들 때만 트리거 우회
insert into auth.users (id, email, created_at, instance_id, aud, role)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'ref-test-' || n || '@example.com',
       case n when 101 then now() - interval '10 days' when 103 then now() - interval '5 days'
              when 111 then now() - interval '30 days' else now() end,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
from (select unnest(array[101,102,103,111,112,113,114,121,122,123,124,125,126,127,128]) n) s;
insert into profiles (id, full_name)
select id, '[TEST] ' || email from auth.users where email like 'ref-test-%@example.com';
insert into providers (id, display_name, profile_id, application_status, is_active)
select ('00000000-0000-4000-8000-' || lpad((n + 100)::text, 12, '0'))::uuid, '[TEST] ref ' || n,
       ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'approved', false
from unnest(array[111,112,113,114]) n;
set local session_replication_role = origin;

\echo '--- 코드 만들기'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000101","role":"authenticated"}', true);
select set_config('t.c_i1', my_referral() ->> 'code', true), set_config('t.k_i1', my_referral() ->> 'kind', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000111","role":"authenticated"}', true);
select set_config('t.c_t1', my_referral() ->> 'code', true), set_config('t.k_t1', my_referral() ->> 'kind', true);
reset role;
do $$ begin
  if current_setting('t.k_i1') <> 'customer' or current_setting('t.k_t1') <> 'provider' or length(current_setting('t.c_i1')) <> 6 or current_setting('t.c_i1') = current_setting('t.c_t1') then raise exception 'FAIL 1'; end if;
  if (select count(*) from referral_codes where user_id = '00000000-0000-4000-8000-000000000101') <> 1 then raise exception 'FAIL 1b: 코드가 두 번 생김'; end if;
  raise notice 'PASS 1 코드 6자리, 다시 불러도 같은 코드, 손님/마사지사 구분';
end $$;

\echo '--- 등록 막기'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000101","role":"authenticated"}', true);
do $$ begin perform claim_referral(current_setting('t.c_i1')); raise exception 'FAIL 2';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS 2 자기 코드 → "%"', sqlerrm; end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000103","role":"authenticated"}', true);
do $$ begin perform claim_referral(current_setting('t.c_i1')); raise exception 'FAIL 3';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS 3 가입 5일 된 계정 → "%"', sqlerrm; end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000102","role":"authenticated"}', true);
do $$ begin perform claim_referral('ZZZZZZ'); raise exception 'FAIL 4';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS 4 없는 코드 → "%"', sqlerrm; end $$;
select set_config('t.f1_can_before', my_referral() ->> 'can_enter', true);
select set_config('t.f1_kind', claim_referral(lower(current_setting('t.c_i1'))) ->> 'kind', true);
do $$ begin perform claim_referral(current_setting('t.c_t1')); raise exception 'FAIL 5';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'PASS 5 두 번째 초대자 → "%"', sqlerrm; end $$;
select set_config('t.f1_can_after', my_referral() ->> 'can_enter', true);
-- 마사지사 초대: T2·T3·T4 가 T1 코드 등록
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000112","role":"authenticated"}', true);
select set_config('t.t2_kind', claim_referral(current_setting('t.c_t1')) ->> 'kind', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000113","role":"authenticated"}', true);
select claim_referral(current_setting('t.c_t1'));
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000114","role":"authenticated"}', true);
select claim_referral(current_setting('t.c_t1'));
-- 직접 읽기는 막혀 있어야 한다
do $$ declare n int; begin
  select count(*) into n from referrals; if n <> 0 then raise exception 'FAIL 6: 일반 사용자가 referrals %행', n; end if;
  select count(*) into n from referral_codes; if n <> 0 then raise exception 'FAIL 6b'; end if;
  raise notice 'PASS 6 일반 사용자는 referrals·referral_codes 를 못 읽음';
end $$;
reset role;
do $$ begin
  if current_setting('t.f1_kind') <> 'customer' or current_setting('t.t2_kind') <> 'provider' or current_setting('t.f1_can_before') <> 'true' or current_setting('t.f1_can_after') <> 'false' then
    raise exception 'FAIL 7: % % % %', current_setting('t.f1_kind'), current_setting('t.t2_kind'), current_setting('t.f1_can_before'), current_setting('t.f1_can_after'); end if;
  raise notice 'PASS 7 소문자 코드도 등록, 손님/마사지사 종류, 등록 후 입력칸 닫힘';
end $$;

\echo '--- 손님 보상: F1 첫 완료 → I1 쿠폰'
set local session_replication_role = replica;
insert into bookings (id, customer_id, provider_id, scheduled_at, amount_vnd, status) values
 ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000102', '02f0c514-a5ae-4e85-9c11-2da5956c80b2', now(), 500000, 'in_progress'),
 ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000102', '02f0c514-a5ae-4e85-9c11-2da5956c80b2', now(), 500000, 'in_progress'),
 ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000101', '02f0c514-a5ae-4e85-9c11-2da5956c80b2', now() + interval '1 day', 500000, 'confirmed');
set local session_replication_role = origin;
update bookings set status = 'completed', completed_at = now() where id = '00000000-0000-4000-8000-000000000301';
do $$ declare n int; c record; begin
  select count(*) into n from user_coupons u join coupons cp on cp.id = u.coupon_id
   where u.customer_id = '00000000-0000-4000-8000-000000000101' and cp.personal and not cp.is_active
     and cp.discount_type = 'amount' and cp.discount_value = 100000 and not u.is_used;
  if n <> 1 then raise exception 'FAIL 8: I1 쿠폰 %장', n; end if;
  select count(*) into n from notifications where user_id = '00000000-0000-4000-8000-000000000101' and kind = 'referral_reward';
  if n <> 1 then raise exception 'FAIL 9: 알림 %건', n; end if;
  raise notice 'PASS 8·9 I1 쿠폰함에 100,000₫ 개인 쿠폰 1장 + referral_reward 알림 1건';
end $$;
\echo '--- 두 번째 완료·같은 예약 재완료 → 그대로'
update bookings set status = 'completed', completed_at = now() where id = '00000000-0000-4000-8000-000000000302';
update bookings set status = 'in_progress' where id = '00000000-0000-4000-8000-000000000301';
update bookings set status = 'completed' where id = '00000000-0000-4000-8000-000000000301';
do $$ declare n int; begin
  select count(*) into n from user_coupons where customer_id = '00000000-0000-4000-8000-000000000101';
  if n <> 1 then raise exception 'FAIL 10: 쿠폰 %장', n; end if;
  raise notice 'PASS 10 보상은 한 번만 (쿠폰 1장 그대로)';
end $$;

\echo '--- 쿠폰: 남은 못 받고, I1 은 예약에 쓴다'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000102","role":"authenticated"}', true);
do $$ begin
  insert into user_coupons (customer_id, coupon_id)
  select '00000000-0000-4000-8000-000000000102', id from coupons where code like 'REF-%' limit 1;
  raise exception 'FAIL 11';
exception when insufficient_privilege then raise notice 'PASS 11 다른 사람은 초대 쿠폰을 받을 수 없음 → "%"', sqlerrm; end $$;
do $$ declare n int; begin
  select count(*) into n from coupons where is_active; if n <> 3 then raise exception 'FAIL 12: 공개 쿠폰 %', n; end if;
  raise notice 'PASS 12 받을 수 있는 쿠폰 목록(is_active)은 그대로 3장';
end $$;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000101","role":"authenticated"}', true);
update bookings set coupon_id = (select coupon_id from user_coupons where customer_id = '00000000-0000-4000-8000-000000000101'),
                    discount_vnd = 1, payment_method = 'card_onsite'
 where id = '00000000-0000-4000-8000-000000000303';
select set_config('t.i1_stats', my_referral()::text, true);
reset role;
select current_setting('t.i1_stats') as i1_stats;
do $$ declare b record; begin
  select discount_vnd, (select is_used from user_coupons where customer_id = '00000000-0000-4000-8000-000000000101') as used
    into b from bookings where id = '00000000-0000-4000-8000-000000000303';
  if b.discount_vnd <> 100000 or not b.used then raise exception 'FAIL 13: %', b; end if;
  if (current_setting('t.i1_stats')::jsonb ->> 'invited')::int <> 1 or (current_setting('t.i1_stats')::jsonb ->> 'earned_vnd')::int <> 100000 then raise exception 'FAIL 14'; end if;
  raise notice 'PASS 13·14 쿠폰 적용(할인 100,000 서버 계산, 사용 처리), 통계 초대 1·보상 100,000';
end $$;

\echo '--- 마사지사 보상: 더미 8명 적립(800,000) 뒤 T2·T3 완료 → 1,000,000, T4 는 상한'
insert into referrals (invitee_id, inviter_id, kind, inviter_provider_id, code, rewarded_at)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, '00000000-0000-4000-8000-000000000111', 'provider',
       '00000000-0000-4000-8000-000000000211', current_setting('t.c_t1'), now()
from generate_series(121, 128) n;
insert into referral_rewards (invitee_id, inviter_id, provider_id, amount_vnd)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, '00000000-0000-4000-8000-000000000111',
       '00000000-0000-4000-8000-000000000211', 100000
from generate_series(121, 128) n;
set local session_replication_role = replica;
insert into bookings (id, customer_id, provider_id, scheduled_at, amount_vnd, status) values
 ('00000000-0000-4000-8000-000000000312', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000212', now(), 500000, 'in_progress'),
 ('00000000-0000-4000-8000-000000000313', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000213', now(), 500000, 'in_progress'),
 ('00000000-0000-4000-8000-000000000314', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000214', now(), 500000, 'in_progress'),
 ('00000000-0000-4000-8000-000000000315', '00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000212', now(), 500000, 'in_progress');
set local session_replication_role = origin;
update bookings set status = 'completed', completed_at = now()
 where id in ('00000000-0000-4000-8000-000000000312', '00000000-0000-4000-8000-000000000313', '00000000-0000-4000-8000-000000000314');
update bookings set status = 'completed', completed_at = now() where id = '00000000-0000-4000-8000-000000000315';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000111","role":"authenticated"}', true);
select set_config('t.t1_stats', my_referral()::text, true);
reset role;
select current_setting('t.t1_stats') as t1_stats;
do $$ declare n int; s bigint; begin
  select count(*), sum(amount_vnd) into n, s from referral_rewards
   where inviter_id = '00000000-0000-4000-8000-000000000111' and status = 'pending_payout';
  if n <> 10 or s <> 1000000 then raise exception 'FAIL 15: %건 %', n, s; end if;
  if (select rewarded_at from referrals where invitee_id = '00000000-0000-4000-8000-000000000114') is null
     or exists (select 1 from referral_rewards where invitee_id = '00000000-0000-4000-8000-000000000114') then
    raise exception 'FAIL 16: T4 상한 처리'; end if;
  select count(*) into n from notifications where user_id = '00000000-0000-4000-8000-000000000111' and kind = 'referral_bonus';
  if n <> 2 then raise exception 'FAIL 17: 알림 %건', n; end if;
  if (current_setting('t.t1_stats')::jsonb ->> 'rewarded')::int <> 10 or (current_setting('t.t1_stats')::jsonb ->> 'pending_vnd')::int <> 1000000
     or (current_setting('t.t1_stats')::jsonb ->> 'invited')::int <> 11 then raise exception 'FAIL 18'; end if;
  raise notice 'PASS 15~18 10명·1,000,000₫ pending_payout, T4 는 연결만(적립 0), T2 두 번째 완료는 추가 없음, 알림 2건, 통계 11명 초대·10/10';
end $$;

\echo '--- 관리자 지급 처리'
do $$ begin perform admin_referral_paid('00000000-0000-4000-8000-000000000211'); raise exception 'FAIL 19';
exception when insufficient_privilege then raise notice 'PASS 19 관리자 아니면 지급 처리 거부'; end $$;
select set_config('request.jwt.claims', '{"sub":"' || (select id from profiles where role = 'admin' limit 1) || '","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.paid_n', admin_referral_paid('00000000-0000-4000-8000-000000000211')::text, true);
reset role;
do $$ begin
  if current_setting('t.paid_n')::int <> 10 or exists (select 1 from referral_rewards where status = 'pending_payout' and inviter_id = '00000000-0000-4000-8000-000000000111') then raise exception 'FAIL 20'; end if;
  raise notice 'PASS 20 관리자가 지급 처리 → 10건 paid';
end $$;

\echo '--- 데일리 푸시 대상'
delete from daily_push_runs where run_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date;
select set_config('t.cust_n', send_daily_push('noon')::text, true);
select set_config('t.prov_n', send_provider_invite_push('noon')::text, true);
select set_config('t.prov_again', send_provider_invite_push('noon')::text, true);
select set_config('t.prov_eve', send_provider_invite_push('evening')::text, true);
do $$ declare n int; begin
  select count(*) into n from notifications x where x.kind in ('notice', 'promo_provider') and x.created_at = now()
     and exists (select 1 from providers a where (a.profile_id = x.user_id or a.owner_id = x.user_id) and a.application_status = 'approved');
  if n <> 0 then raise exception 'FAIL 21: 마사지사가 손님 푸시 %건', n; end if;
  if current_setting('t.prov_n')::int < 1 or current_setting('t.prov_again')::int <> 0 or current_setting('t.prov_eve') <> current_setting('t.prov_n') then raise exception 'FAIL 22'; end if;
  select count(*) into n from notifications x where x.kind = 'invite_promo' and x.created_at = now()
     and not exists (select 1 from providers a where (a.profile_id = x.user_id or a.owner_id = x.user_id) and a.application_status = 'approved');
  if n <> 0 then raise exception 'FAIL 23: 손님이 마사지사 푸시 %건', n; end if;
  if exists (select 1 from notifications where kind = 'invite_promo' and created_at = now() and (title is null or body is null)) then raise exception 'FAIL 24: 빈 문구'; end if;
  raise notice 'PASS 21~24 마사지사는 손님 푸시 0건, 마사지사 푸시 %건·같은 날 두 번째 0건·저녁 슬롯 따로, 손님은 마사지사 푸시 0건, 문구 빈칸 없음 (손님 푸시 %건)', current_setting('t.prov_n'), current_setting('t.cust_n');
end $$;
select title, body from notifications where kind = 'invite_promo' and created_at = now() limit 2;
