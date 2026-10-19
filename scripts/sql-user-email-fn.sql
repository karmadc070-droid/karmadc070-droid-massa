-- 알림 받을 사람의 메일 주소를 읽는 함수 (2026-10-19)
--
-- 왜 — send-push 가 auth.admin.getUserById 로 주소를 읽다가
-- "Database error loading user" 로 실패했다. GoTrue 관리자 API 를 거치지 않고
-- DB 에서 바로 읽는 게 단순하고 덜 깨진다.
--
-- ★ 메일 주소는 개인정보다. service_role 만 부를 수 있게 하고
--   anon·authenticated 에서는 실행 권한을 뺀다.
create or replace function public.user_email(p uuid)
returns text
language sql
security definer
set search_path to 'public'
as $$ select email from auth.users where id = p $$;

revoke execute on function public.user_email(uuid) from public;
revoke execute on function public.user_email(uuid) from anon;
revoke execute on function public.user_email(uuid) from authenticated;
grant execute on function public.user_email(uuid) to service_role;
