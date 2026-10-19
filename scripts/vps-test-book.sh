#!/bin/sh
# 2단계 — demo 손님이 [TEST] 마사지사에게 예약을 넣는다 (2026-10-19).
# 앱이 보내는 것과 같은 모양으로 bookings 에 직접 넣는다 (앱도 RPC 없이 insert 한다).
PSQL="docker exec massa-db psql -U postgres -d postgres"
CUST='adec3c30-746b-47db-bd8d-53ae164a142c'   # demo@massa.app
PROV='47482472-7f32-4d7e-af2b-e97bd5dd83f5'   # [TEST] massa owner
SVC='018fd662-d37e-41c7-b819-410adef47ff0'    # 60분 코스 500,000

echo '=== 1. 예약 넣기 ==='
$PSQL -c "
insert into bookings (customer_id, provider_id, service_id, scheduled_at,
                      location_type, hotel_name, room_number, front_desk_note,
                      lat, lng, status, group_id, payment_method, amount_vnd)
values ('$CUST', '$PROV', '$SVC', now() + interval '2 hours',
        'hotel', 'TEST Hotel', '1004', 'TEST booking - ignore',
        21.0278, 105.8342, 'requested', gen_random_uuid(), 'cash', 500000)
returning id, booking_no, status, amount_vnd;" 2>&1

echo '=== 2. 알림이 생겼는가 (notify_booking_event 트리거) ==='
$PSQL -c "select n.id, n.user_id, n.kind, n.title, n.body, n.created_at
          from notifications n
          where n.created_at > now() - interval '2 minutes'
          order by n.created_at desc;" 2>&1

echo '=== 3. 그 알림이 누구에게 갔는가 ==='
$PSQL -c "select u.email, n.kind, n.title, coalesce(n.push_tries, -1) as tries, n.push_sent_at
          from notifications n join auth.users u on u.id = n.user_id
          where n.created_at > now() - interval '2 minutes';" 2>&1

echo '=== 4. 받는 사람 기기 수 ==='
$PSQL -c "select u.email, count(t.id) as devices
          from auth.users u left join push_tokens t on t.user_id = u.id
          where u.id in ('$CUST', (select profile_id from providers where id = '$PROV'))
          group by 1;" 2>&1
echo '=== DONE ==='
