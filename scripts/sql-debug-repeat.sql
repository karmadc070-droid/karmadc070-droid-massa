-- 반복이 왜 안 잡히는지 확인 (읽기 + 직접 호출)
\echo '=== now() 와 대상 행 ==='
select now() as now_utc, id, kind, push_tries, pushed_at, next_push_at, is_read, booking_id
from notifications where title like 'TEST4%';

\echo '=== (b) 조건을 하나씩 평가 ==='
select kind = 'booking_new'                      as c_kind,
       next_push_at is not null                  as c_notnull,
       next_push_at <= now()                     as c_due,
       push_tries < 10                           as c_tries,
       is_read = false                           as c_unread,
       created_at > now() - interval '10 minutes' as c_fresh,
       (booking_id is null)                      as c_nobooking
from notifications where title like 'TEST4%';

\echo '=== 현재 등록된 함수 본문 ==='
select prosrc from pg_proc where proname = 'claim_unpushed_notifications';

\echo '=== 함수를 직접 호출하면 잡히는가 ==='
select id, kind, push_tries from claim_unpushed_notifications();
