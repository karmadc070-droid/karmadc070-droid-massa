-- 오늘 넣었다 철회한 마사지사 활동 위치 반올림 트리거(trg_provider_zz_round_latlng)와 함수를 지운다
-- 사진 핀 지도를 걷어내서 providers.lat/lng 를 쓰는 곳이 없다(19명 전원 null). 옛 앱도 이 칸을 쓰지 않아 영향 없음.
drop trigger if exists trg_provider_zz_round_latlng on public.providers;
drop function if exists public.round_provider_latlng();
