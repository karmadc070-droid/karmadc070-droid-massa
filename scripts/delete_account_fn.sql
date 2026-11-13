-- 로그인 사용자가 앱 안에서 자기 계정을 직접 삭제하도록 하는 함수 (Apple 5.1.1(v) 요건)
-- public 테이블은 모두 public.profiles를 FK로 물고 있으므로 profiles를 먼저 지우면
-- bookings/reviews/favorites/messages/user_coupons는 CASCADE, 나머지는 SET NULL로 정리된다.

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $fn$
DECLARE
  uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;
  -- 마사지사·업체 계정이면 목록에서 먼저 내린다. 안 내리면 주인 없는 마사지사가 계속 보여서
  -- 손님 예약이 아무도 못 받고 시간 경과로 취소된다 (Thanh hà 8건, 2026-11-13 확인)
  UPDATE public.providers SET is_active = false WHERE profile_id = uid OR owner_id = uid;
  DELETE FROM public.profiles WHERE id = uid;
  DELETE FROM auth.users WHERE id = uid;
END;
$fn$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
