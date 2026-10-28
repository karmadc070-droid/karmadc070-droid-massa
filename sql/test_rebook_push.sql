-- sql/rebook_push.sql 을 트랜잭션 안에서 적용해 보고 재예약 푸시 대상·문구·중복 방지를 시험한 뒤 전부 되돌린다
-- 실행: (echo 'begin;'; cat rebook_push.sql test_rebook_push.sql; echo 'rollback;') | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 등장인물 ([TEST], 전부 롤백) — 손님 C1~C12 (…0201~0212), 마사지사 P1 승인·사진, P2 정지, P3 승인·사진 없음, C10 은 승인된 마사지사 계정(P4)

set local session_replication_role = replica;   -- 시험 계정·예약을 만들 때만 트리거 우회
insert into auth.users (id, email, created_at, instance_id, aud, role)
select ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'rebook-test-' || n || '@example.com', now() - interval '60 days',
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated'
from generate_series(201, 212) n;
insert into profiles (id, full_name) select id, '[TEST] ' || email from auth.users where email like 'rebook-test-%@example.com';
insert into providers (id, display_name, application_status, is_active, photo_url, suspended_until, profile_id) values
 ('00000000-0000-4000-8000-000000000301', '[TEST]x', 'approved', true, 'https://h/storage/v1/object/public/provider-photos/p1.png', null, null),
 ('00000000-0000-4000-8000-000000000302', 'RebookTwo', 'approved', true, 'https://h/storage/v1/object/public/provider-photos/p2.png', now() + interval '3 days', null),
 ('00000000-0000-4000-8000-000000000303', 'RebookThree', 'approved', true, null, null, null),
 ('00000000-0000-4000-8000-000000000304', 'RebookFour', 'approved', true, null, null, '00000000-0000-4000-8000-000000000210');
-- P1 은 [TEST] 이름이면 일반 문구로 빠지므로 여기서만 실제 이름처럼 바꾼다
update providers set display_name = 'RebookOne' where id = '00000000-0000-4000-8000-000000000301';
insert into push_tokens (token, user_id, platform, lang, updated_at)
select 'rebook-test-token-0000000000000000-' || n, ('00000000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid, 'android',
       case n when 201 then 'ko' when 202 then 'vi' when 212 then 'ja' else 'en' end, now()
from generate_series(201, 212) n where n <> 207;          -- C7 은 기기 없음
-- C1 은 기기 둘: 최근 것(zh)이 이긴다
insert into push_tokens (token, user_id, platform, lang, updated_at) values ('rebook-test-token-0000000000000000-201b', '00000000-0000-4000-8000-000000000201', 'web', 'zh', now() + interval '1 minute');
-- 예약: (손님, 마사지사, 완료 며칠 전, 상태, 만든 날 며칠 전)
insert into bookings (id, booking_no, customer_id, provider_id, scheduled_at, amount_vnd, status, completed_at, created_at)
select gen_random_uuid(), 'TEST-RB-' || c || '-' || mk, ('00000000-0000-4000-8000-' || lpad(c::text, 12, '0'))::uuid,
       ('00000000-0000-4000-8000-' || lpad(p::text, 12, '0'))::uuid,
       now() - make_interval(days => coalesce(dc, mk) ), 500000, st::booking_status,
       case when dc is null then null else now() - make_interval(days => dc) end, now() - make_interval(days => mk)
from (values
  (201, 301, 15, 'completed', 16),   -- C1 → P1 사진 푸시
  (202, 302, 15, 'completed', 16),   -- C2 → P2 정지 → 일반 문구
  (203, 301, 15, 'completed', 16),   -- C3 → 완료 뒤 새 예약(취소) 있음 → 없음
  (203, 301, null, 'cancelled', 5),
  (204, 301, 15, 'completed', 20),   -- C4 → 다가오는 예약 있음 → 없음
  (204, 301, null, 'confirmed', 18),
  (205, 301, 10, 'completed', 11),   -- C5 → 아직 10일 → 없음
  (206, 301, 30, 'completed', 31),   -- C6 → 30일 전 → 없음
  (207, 301, 15, 'completed', 16),   -- C7 → 기기 없음 → 없음
  (208, 301, 15, 'completed', 16),   -- C8 → 5일 전에 이미 받음 → 없음
  (209, 303, 16, 'completed', 17),   -- C9 → 완료 둘, 최근(P1, 15일) 것 하나만
  (209, 301, 15, 'completed', 16),
  (210, 301, 15, 'completed', 16),   -- C10 → 승인된 마사지사 계정 → 없음
  (211, 303, 15, 'completed', 16),   -- C11 → P3 사진 없음 → en 이름 문구, 사진 없음
  (212, 304, 15, 'completed', 16)    -- C12 → ja, P4
) v(c, p, dc, st, mk);
insert into rebook_push_log (booking_id, user_id, sent_at)
select b.id, b.customer_id, now() - interval '5 days' from bookings b
 where b.customer_id = '00000000-0000-4000-8000-000000000206';   -- C6 의 옛 예약으로 '받은 기록'을 만들어 C8 에 쓴다
update rebook_push_log set user_id = '00000000-0000-4000-8000-000000000208' where user_id = '00000000-0000-4000-8000-000000000206';
set local session_replication_role = origin;

\echo '--- 첫 실행'
select set_config('t.n1', send_rebook_push()::text, true);
\echo '--- 두 번째 실행 (같은 날 다시)'
select set_config('t.n2', send_rebook_push()::text, true);

select right(n.user_id::text, 3) as c, n.kind, n.title, n.body, n.image_url, right(n.provider_id::text, 3) as p
from notifications n where n.user_id::text like '00000000-0000-4000-8000-0000000002%' order by 1;

do $$
declare n int; r record;
  function_c text := '00000000-0000-4000-8000-000000000';
begin
  select count(*) into n from notifications where user_id::text like '00000000-0000-4000-8000-0000000002%';
  if n <> 5 then raise exception 'FAIL 1: 시험 손님 알림 %건 (C1·C2·C9·C11·C12 5건이어야)', n; end if;
  if (select count(*) from notifications where user_id::text not like '00000000-0000-4000-8000-0000000002%' and kind = 'rebook') <> 0
     then raise exception 'FAIL 1b: 실제 손님에게 rebook 이 생김'; end if;
  raise notice 'PASS 1 대상 5명만 (새 예약·다가오는 예약·10일·30일·기기 없음·14일 안 재발송·마사지사 계정 제외)';

  select * into r from notifications where user_id = (function_c || '201')::uuid;
  if r.kind <> 'rebook' or r.title <> '再约上次的理疗师RebookOne吗？' or r.provider_id <> (function_c || '301')::uuid
     or r.image_url <> 'https://h/storage/v1/render/image/public/provider-photos/p1.png?width=540&quality=60'
     then raise exception 'FAIL 2: C1 % % % %', r.kind, r.title, r.provider_id, r.image_url; end if;
  raise notice 'PASS 2 C1 최근 기기 언어(zh)·이름·사진 변환 주소·provider_id';

  select * into r from notifications where user_id = (function_c || '202')::uuid;
  if r.title <> 'Đặt lịch lại nhé' or r.image_url is not null or r.provider_id is not null
     then raise exception 'FAIL 3: C2 % % %', r.title, r.image_url, r.provider_id; end if;
  raise notice 'PASS 3 C2 정지된 테라피스트 → 일반 문구(vi), 사진·프로필 없음';

  select * into r from notifications where user_id = (function_c || '209')::uuid;
  if r.provider_id <> (function_c || '301')::uuid then raise exception 'FAIL 4: C9 %', r.provider_id; end if;
  raise notice 'PASS 4 C9 완료 둘 중 최근 예약 하나만';

  select * into r from notifications where user_id = (function_c || '211')::uuid;
  if r.title <> 'Book RebookThree again?' or r.image_url is not null or r.provider_id <> (function_c || '303')::uuid
     then raise exception 'FAIL 5: C11 % % %', r.title, r.image_url, r.provider_id; end if;
  raise notice 'PASS 5 C11 en, 사진 없는 테라피스트도 이름·프로필';

  select * into r from notifications where user_id = (function_c || '212')::uuid;
  if r.title <> '前回のセラピストRebookFourさん、また呼びませんか？' then raise exception 'FAIL 6: C12 %', r.title; end if;
  if exists (select 1 from notifications where user_id::text like '00000000-0000-4000-8000-0000000002%' and (title is null or body is null))
     then raise exception 'FAIL 6b: 빈 문구'; end if;
  raise notice 'PASS 6 ja 문구, 빈 문구 없음';

  if current_setting('t.n1') <> '5' or current_setting('t.n2') <> '0' then
    raise exception 'FAIL 7: 첫 % 두 번째 %', current_setting('t.n1'), current_setting('t.n2'); end if;
  if (select count(*) from rebook_push_log where user_id::text like '00000000-0000-4000-8000-0000000002%') <> 6
     then raise exception 'FAIL 7b: 기록 수'; end if;
  raise notice 'PASS 7 두 번째 실행 0건(예약당 한 번), 기록 5+기존 1';
end $$;

\echo '--- 일반 사용자는 기록을 못 읽고 함수도 못 부른다'
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000201","role":"authenticated"}', true);
do $$ begin
  perform 1 from rebook_push_log; raise exception 'FAIL 8';
exception when insufficient_privilege then raise notice 'PASS 8a rebook_push_log 읽기 거부'; end $$;
do $$ begin
  perform send_rebook_push(); raise exception 'FAIL 8b';
exception when insufficient_privilege then raise notice 'PASS 8b send_rebook_push 호출 거부'; end $$;
reset role;
