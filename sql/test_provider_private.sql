-- sql/provider_private.sql 을 트랜잭션 안에서 적용해 보고 anon·손님·마사지사 본인·다른 마사지사·관리자로 시험한 뒤 되돌린다
-- 실행: (echo 'begin;'; cat provider_private.sql; cat test_provider_private.sql) | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- P1 Vui(5452a420, profile 7c6969e9), P2 Mi(profile 707be270), C 손님 f8e73589, A 관리자 0bf03ce4

-- 시험용 신청 중(pending) 마사지사 한 명 — 트리거 우회, 롤백됨
set local session_replication_role = replica;
insert into providers (id, kind, display_name, application_status, is_active)
values ('00000000-0000-4000-8000-0000000000f1', 'masseur', 'TEST PENDING', 'pending', false);
set local session_replication_role = origin;

do $$ declare n int; begin
  select count(*) into n from providers where coalesce(lat, lng, last_lat, last_lng) is not null or last_seen_at is not null
     or coalesce(zalo, kakao, photo_url_orig) is not null or photo_urls_orig is not null;
  if n <> 0 then raise exception 'FAIL 0: providers 에 비공개 값이 %행 남음', n; end if;
  select count(*) into n from provider_private where photo_url_orig is not null or photo_urls_orig is not null;
  raise notice 'PASS 0 기존 값 이동 — providers 비공개 칸 0행, provider_private 원본 사진 %행', n;
end $$;

-- anon
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ declare n int; r record; begin
  select count(*) into n from providers where application_status <> 'approved';
  if n <> 0 then raise exception 'FAIL 1: anon 이 미승인 %행을 봄', n; end if;
  select * into r from providers limit 1;            -- 옛 앱의 select('*') 가 그대로 돈다
  select count(*) into n from providers;
  begin
    perform 1 from provider_private;
    raise exception 'FAIL 1: anon 이 provider_private 를 읽음';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 1 anon — select * OK(승인 %행), 미승인 0행, provider_private 거부', n;
end $$;

-- 손님
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f8e73589-6145-4180-a325-6af5b777757c","role":"authenticated"}', true);
do $$ declare n int; m int; begin
  select count(*) into n from providers where application_status <> 'approved';
  select count(*) into m from provider_private;
  if n <> 0 or m <> 0 then raise exception 'FAIL 2: 손님 미승인 %행, provider_private %행', n, m; end if;
  raise notice 'PASS 2 손님 — 미승인 0행, provider_private 0행';
end $$;

-- 마사지사 본인: 위치를 써도 providers 에는 null, provider_private 에만 남는다
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"7c6969e9-506c-4ab4-ab0c-f14589e6a6ef","role":"authenticated"}', true);
do $$ declare n int; r record; begin
  update providers set lat = 21.0301, lng = 105.8402, last_lat = 21.0301, last_lng = 105.8402, last_seen_at = now(), is_active = is_active
   where id = '5452a420-6b22-48b8-94f9-ba90851a86be';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 3: 본인 update %행', n; end if;
  select lat, last_lat, last_seen_at into r from providers where id = '5452a420-6b22-48b8-94f9-ba90851a86be';
  if r.lat is not null or r.last_lat is not null or r.last_seen_at is not null then raise exception 'FAIL 3: providers 에 위치가 남음'; end if;
  select * into r from provider_private where provider_id = '5452a420-6b22-48b8-94f9-ba90851a86be';
  if r.last_lat is distinct from 21.0301 then raise exception 'FAIL 3: 본인이 provider_private 를 못 읽음 (%)', r.last_lat; end if;
  begin
    update provider_private set zalo = 'x';
    raise exception 'FAIL 3: 본인이 provider_private 에 직접 씀';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 3 본인 — 위치 쓰기 OK, providers 칸 null, provider_private 본인 행 읽기 OK, 직접 쓰기 거부';
end $$;

-- 다른 마사지사
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"707be270-c181-46cc-a04d-5dfad46205a5","role":"authenticated"}', true);
do $$ declare n int; begin
  select count(*) into n from provider_private where provider_id = '5452a420-6b22-48b8-94f9-ba90851a86be';
  if n <> 0 then raise exception 'FAIL 4: 다른 마사지사가 남의 비공개 행을 읽음'; end if;
  select count(*) into n from providers where application_status <> 'approved';
  if n <> 0 then raise exception 'FAIL 4: 다른 마사지사가 미승인 %행을 봄', n; end if;
  raise notice 'PASS 4 다른 마사지사 — 남의 비공개 0행, 미승인 0행';
end $$;

-- 관리자: 미승인 행·모든 비공개 행을 본다. zalo 를 넣어도 provider_private 로 간다
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"0bf03ce4-ed36-463c-88ae-6c068d16bb2b","role":"authenticated"}', true);
do $$ declare n int; m int; r record; begin
  select count(*) into n from providers where application_status <> 'approved';
  update providers set zalo = '0900000000' where id = '697e7085-98e5-499a-8c80-a9a037763170';
  select zalo into r from providers where id = '697e7085-98e5-499a-8c80-a9a037763170';
  select count(*) into m from provider_private;
  if n < 1 or r.zalo is not null or m < 2 then raise exception 'FAIL 5: 관리자 미승인 %행, providers.zalo %, 비공개 %행', n, r.zalo, m; end if;
  select count(*) into m from provider_private where zalo = '0900000000';
  raise notice 'PASS 5 관리자 — 미승인 %행 봄, zalo 는 providers 에 null·provider_private 에 %행, 비공개 전체 읽기', n, m;
end $$;

-- 마사지사 신청(insert)도 통과하는가 — 신청 직후 본인 행을 읽을 수 있어야 한다
reset role;
select 'pending 행 수(postgres)' as chk, count(*) from providers where application_status = 'pending';
rollback;
\echo '--- 롤백 뒤'
select to_regclass('public.provider_private') as tbl,
       (select pg_get_expr(polqual, polrelid) from pg_policy where polname = 'providers_public_read') as public_read,
       (select count(*) from providers where photo_url_orig is not null) as orig_still_on_providers;
