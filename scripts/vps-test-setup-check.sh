#!/bin/sh
# 실전 테스트 전 현재 상태 확인 (2026-10-19)
# 사장님을 테스트 마사지사로 세우고, 예약 → 알림 → 수락 → 채팅까지 돌려 보기 전에
# 지금 무엇이 있고 무엇이 없는지부터 읽는다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
ME='karmadc070@gmail.com'

echo '=== 1. 내 계정 ==='
$PSQL -c "select u.id, u.email, p.role, p.full_name
          from auth.users u left join profiles p on p.id = u.id
          where u.email = '$ME';" 2>&1

echo '=== 2. 내 마사지사 등록 (있나) ==='
$PSQL -c "select pr.id, pr.display_name, pr.kind, pr.application_status, pr.is_active, pr.city_code
          from providers pr
          join auth.users u on u.id = coalesce(pr.profile_id, pr.owner_id)
          where u.email = '$ME';" 2>&1

echo '=== 3. 내 기기(푸시 토큰) ==='
$PSQL -c "select platform, left(token, 28) as token_head, lang
          from push_tokens t join auth.users u on u.id = t.user_id
          where u.email = '$ME';" 2>&1

echo '=== 4. 손님 역할로 쓸 만한 테스트 계정 ==='
$PSQL -c "select u.email, p.role,
                 (select count(*) from push_tokens t where t.user_id = u.id) as devices
          from auth.users u left join profiles p on p.id = u.id
          where u.email in ('demo@massa.app') or u.email like '%test%';" 2>&1

echo '=== 5. 예약을 만드는 함수가 무엇인가 ==='
$PSQL -c "select p.proname, pg_get_function_identity_arguments(p.oid) as args
          from pg_proc p join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname like '%booking%'
          order by 1;" 2>&1

echo '=== 6. 서비스 목록 (예약에 쓸 것) ==='
$PSQL -c "select id, code, base_price_vnd, duration_min from services order by base_price_vnd limit 8;" 2>&1

echo '=== 7. 성·시 코드 ==='
$PSQL -c "select code, name_ko from regions where level = 1 and name_ko in ('하노이','호치민');" 2>&1
echo '=== DONE ==='
