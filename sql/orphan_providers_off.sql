-- 계정을 지워 주인이 없어진 마사지사를 목록에서 내리는 1회성 정리 (2026-11-13)
-- delete_my_account 가 providers 를 그대로 두어서, 지운 계정의 마사지사가 계속 노출되고 있었다.
-- 지우지 않고 is_active 만 끈다. 되돌리려면 같은 id 로 true 로 바꾸면 된다.
update public.providers
   set is_active = false
 where profile_id is null and owner_id is null and is_active
returning id, display_name;