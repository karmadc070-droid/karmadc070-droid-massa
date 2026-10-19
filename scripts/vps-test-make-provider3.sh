#!/bin/sh
# 1단계(재시도 2) — guard_provider_kyc 가 서류 4종을 요구한다. 맞는 규칙이다.
# 테스트 계정이므로 표시 전용 더미 값을 넣는다. 인증 마크(is_verified·credential_verified)는
# 건드리지 않는다 — 허위 신뢰 표시를 만들면 안 된다. 끝나면 cleanup 으로 통째로 지운다.
PSQL="docker exec massa-db psql -U postgres -d postgres"
UID_ME='0bf03ce4-ed36-463c-88ae-6c068d16bb2b'

echo '=== 0. provider_kyc 칼럼 ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='provider_kyc' order by ordinal_position;" 2>&1

echo '=== 1. KYC 더미 넣기 ==='
$PSQL -c "
insert into provider_kyc (provider_id, applicant_id, reg_type, contact,
                          id_front_url, id_back_url, bank_name, bank_account)
select p.id, '$UID_ME', 'freelancer', 'TEST-0000-0000',
       'TEST-NOT-A-REAL-DOCUMENT', 'TEST-NOT-A-REAL-DOCUMENT',
       'TEST BANK', 'TEST-0000'
from providers p where p.profile_id = '$UID_ME'
  and not exists (select 1 from provider_kyc k where k.provider_id = p.id)
returning provider_id;" 2>&1

echo '=== 2. 승인 + 출근 ==='
$PSQL -c "update providers set application_status = 'approved', is_active = true, reviewed_at = now()
          where profile_id = '$UID_ME'
          returning id, display_name, application_status, is_active;" 2>&1

echo '=== 3. 결과 (인증 마크는 꺼져 있어야 한다) ==='
$PSQL -c "select id, display_name, application_status, is_active,
                 is_verified, credential_verified, sort_priority
          from providers where profile_id = '$UID_ME';" 2>&1
echo '=== DONE ==='
