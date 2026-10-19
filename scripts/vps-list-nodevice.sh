#!/bin/sh
# 알림 기기가 없는 승인 마사지사 명단 — 메일 보낼 대상을 뽑는다
# ★ provider_kyc.phone 은 없는 컬럼이다 (앞서 짐작해 쓰다 쿼리가 깨졌다). providers.phone 만 쓴다.
docker exec massa-db psql -U postgres -d postgres -c "
select p.display_name as 이름,
       coalesce(u.email,'(계정없음)') as 메일,
       coalesce(p.phone,'-') as 연락처,
       (select count(*) from push_tokens t
         where t.user_id = coalesce(p.profile_id, p.owner_id)) as 기기수,
       coalesce(to_char(u.last_sign_in_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI'),'없음') as 마지막로그인
from providers p
left join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
where p.application_status = 'approved'
order by 기기수, p.display_name;"
