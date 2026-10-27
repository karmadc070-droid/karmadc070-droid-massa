-- sql/booking_locations.sql 을 트랜잭션 안에서 적용해 보고 권한을 시험한 뒤 전부 되돌린다 (앞에 begin; + 마이그레이션을 붙여 실행)
-- 실행: (echo 'begin;'; cat booking_locations.sql; cat test_booking_locations.sql) | docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1
-- 등장인물: P1 Vui(담당), P2 Mi(다른 마사지사), C1 담당 예약 손님, C2 다른 손님, A 관리자

set local session_replication_role = replica;   -- 시험 예약 만들 때만 트리거 우회
insert into bookings (id, customer_id, provider_id, service_id, scheduled_at, amount_vnd, status, lat, lng)
values ('00000000-0000-4000-8000-0000000000b1', 'f8e73589-6145-4180-a325-6af5b777757c', '5452a420-6b22-48b8-94f9-ba90851a86be',
        (select id from services limit 1), now() + interval '1 hour', 500000, 'confirmed', 21.03, 105.85);
set local session_replication_role = origin;

\echo '--- 발행 목록에 들어갔나'
select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1;

-- P1 담당 마사지사
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"7c6969e9-506c-4ab4-ab0c-f14589e6a6ef","role":"authenticated"}', true);
do $$ begin
  insert into booking_locations (booking_id, lat, lng) values ('00000000-0000-4000-8000-0000000000b1', 21.01, 105.81);
  raise exception 'FAIL 1: confirmed 상태에서 위치 쓰기가 됐다';
exception when insufficient_privilege then raise notice 'PASS 1 confirmed 상태 위치 쓰기 거부';
end $$;
do $$ declare n int; begin
  update bookings set status = 'on_the_way' where id = '00000000-0000-4000-8000-0000000000b1' and status = 'confirmed';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 2: 담당 마사지사가 출발로 못 바꿨다 (%건)', n; end if;
  raise notice 'PASS 2 담당 마사지사 confirmed→on_the_way';
end $$;
do $$ declare n int; begin
  insert into booking_locations (booking_id, lat, lng, accuracy) values ('00000000-0000-4000-8000-0000000000b1', 21.011, 105.811, 12)
    on conflict (booking_id) do update set lat = excluded.lat, lng = excluded.lng, accuracy = excluded.accuracy;
  insert into booking_locations (booking_id, lat, lng, accuracy, updated_at) values ('00000000-0000-4000-8000-0000000000b1', 21.012, 105.812, 9, '2000-01-01')
    on conflict (booking_id) do update set lat = excluded.lat, lng = excluded.lng, accuracy = excluded.accuracy, updated_at = excluded.updated_at;
  select count(*) into n from booking_locations where lat = 21.012 and updated_at > now() - interval '1 minute';
  if n <> 1 then raise exception 'FAIL 3: 담당 upsert 결과 이상 (%건)', n; end if;
  raise notice 'PASS 3 담당 upsert 두 번 OK, updated_at 은 서버 시각(보낸 2000-01-01 무시)';
end $$;
do $$ begin
  delete from booking_locations;
  raise exception 'FAIL 4: 담당이 지우기가 됐다';
exception when insufficient_privilege then raise notice 'PASS 4 담당도 delete 권한 없음';
end $$;
reset role;  -- 알림은 손님 것이라 postgres 로 센다
select 'notifications 손님 출발 알림' as chk, count(*) from notifications where booking_id = '00000000-0000-4000-8000-0000000000b1' and kind = 'booking_on_the_way';

-- P2 다른 마사지사
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"707be270-c181-46cc-a04d-5dfad46205a5","role":"authenticated"}', true);
do $$ declare n int; begin
  begin
    insert into booking_locations (booking_id, lat, lng) values ('00000000-0000-4000-8000-0000000000b1', 1, 1);
    raise exception 'FAIL 5: 다른 마사지사 insert 가 됐다';
  exception when insufficient_privilege or unique_violation then null; end;
  update booking_locations set lat = 1 where booking_id = '00000000-0000-4000-8000-0000000000b1';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 5: 다른 마사지사 update %건', n; end if;
  select count(*) into n from booking_locations;
  if n <> 0 then raise exception 'FAIL 5: 다른 마사지사가 %건 읽음', n; end if;
  raise notice 'PASS 5 다른 마사지사 쓰기 거부·읽기 0건';
end $$;

-- C1 그 예약의 손님
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"f8e73589-6145-4180-a325-6af5b777757c","role":"authenticated"}', true);
do $$ declare n int; begin
  select count(*) into n from booking_locations where booking_id = '00000000-0000-4000-8000-0000000000b1';
  if n <> 1 then raise exception 'FAIL 6: 손님이 못 읽음 (%건)', n; end if;
  update booking_locations set lat = 1;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'FAIL 6: 손님 update %건', n; end if;
  raise notice 'PASS 6 손님 읽기 1건·update 0건';
end $$;

-- C2 다른 손님
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"a8d974d1-9050-44af-af45-a52d87bb1474","role":"authenticated"}', true);
do $$ declare n int; begin
  select count(*) into n from booking_locations;
  if n <> 0 then raise exception 'FAIL 7: 다른 손님이 %건 읽음', n; end if;
  raise notice 'PASS 7 다른 손님 읽기 0건';
end $$;

-- anon
reset role; set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  perform 1 from booking_locations;
  raise exception 'FAIL 8: anon 이 읽기 권한을 가짐';
exception when insufficient_privilege then raise notice 'PASS 8 anon 읽기 권한 없음(거부)';
end $$;

-- 관리자
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"0bf03ce4-ed36-463c-88ae-6c068d16bb2b","role":"authenticated"}', true);
do $$ declare n int; begin
  select count(*) into n from booking_locations;
  if n <> 1 then raise exception 'FAIL 9: 관리자 읽기 %건', n; end if;
  raise notice 'PASS 9 관리자 읽기 1건';
end $$;

-- P1 도착 → 줄이 지워지고 다시 못 쓴다
reset role; set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"7c6969e9-506c-4ab4-ab0c-f14589e6a6ef","role":"authenticated"}', true);
do $$ declare n int; begin
  update bookings set status = 'in_progress' where id = '00000000-0000-4000-8000-0000000000b1' and status = 'on_the_way';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FAIL 10: 도착으로 못 바꿈'; end if;
  select count(*) into n from booking_locations;
  if n <> 0 then raise exception 'FAIL 10: 도착 뒤에도 위치가 %건 남음', n; end if;
  begin
    insert into booking_locations (booking_id, lat, lng) values ('00000000-0000-4000-8000-0000000000b1', 21.0, 105.8);
    raise exception 'FAIL 10: 도착 뒤 위치 쓰기가 됐다';
  exception when insufficient_privilege then null; end;
  raise notice 'PASS 10 담당 on_the_way→in_progress, 위치 줄 삭제, 이후 쓰기 거부';
end $$;
reset role;
select 'postgres 로 본 남은 위치' as chk, count(*) from booking_locations;

rollback;
\echo '--- 롤백 뒤'
select to_regclass('public.booking_locations') as tbl, (select count(*) from bookings where id = '00000000-0000-4000-8000-0000000000b1') as test_booking;