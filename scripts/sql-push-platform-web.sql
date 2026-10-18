-- push_tokens 에 'web'(안드로이드 TWA·브라우저 웹푸시)을 허용한다.
--
-- 왜 (2026-10-18) — 웹푸시를 붙이고 테스트했더니 브라우저 구독은 정상으로 만들어지는데
-- DB 저장이 조용히 실패했다. 원인은 제약 하나였다.
--   CHECK (platform = 'ios')
-- 아이폰만 있던 시절에 박아 둔 것이라 'web' 이 들어오면 23514 로 거부한다.
-- 앱에서는 .then(성공, 실패) 로 오류를 삼키고 있어서 화면에는 아무 표시도 안 났다.
--
-- ★ 교훈: '구독은 됐는데 토큰이 0건'이면 앱이 아니라 저장 쪽을 먼저 본다.

alter table public.push_tokens drop constraint if exists push_tokens_platform_check;
alter table public.push_tokens add constraint push_tokens_platform_check
  check (platform in ('ios', 'web'));

select 'push platform web ok' as result;
