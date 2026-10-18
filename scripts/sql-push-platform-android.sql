-- push_tokens 에 'android'(네이티브 FCM) 를 허용한다.
--
-- 왜 (2026-10-18) — 안드로이드를 TWA(웹 껍데기)에서 Capacitor 네이티브로 옮긴다.
-- 웹푸시는 소리·헤드업 배너를 낼 수 없다(알림 채널을 웹이 못 건드린다).
-- 네이티브로 가면 중요도 5(긴급) 채널을 직접 만들 수 있다.
--
-- 'web' 도 남겨 둔다 — 옛 TWA 를 쓰는 사람과 PC 브라우저가 당분간 그 경로를 쓴다.

alter table public.push_tokens drop constraint if exists push_tokens_platform_check;
alter table public.push_tokens add constraint push_tokens_platform_check
  check (platform in ('ios', 'web', 'android'));

select 'push platform android ok' as result;
