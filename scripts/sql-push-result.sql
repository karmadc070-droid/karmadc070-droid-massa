-- 알림이 실제로 기기에 갔는지를 기록한다.
--
-- 왜 필요했나 (2026-10-18) — send-push 는 claim_unpushed_notifications 로 먼저 pushed_at 을
-- 찍고 그 다음에 토큰을 찾는다. 받을 기기가 없으면 아무 데도 안 가면서 '보냄'으로 남았다.
-- 실제로 알림 26건이 전부 pushed_at 이 찍혀 있었는데 push_tokens 는 0행이었다.
-- DB 만 보면 잘 나간 것처럼 보였다. 안 보낸 건 안 보냈다고 남겨야 한다.
--
-- 값: 'sent' · 'no_device' · 'failed: <사유>' · null(아직 처리 전)

alter table public.notifications add column if not exists push_result text;

comment on column public.notifications.push_result is
  '푸시 실제 결과. sent / no_device / failed:<사유>. pushed_at 은 처리 시각일 뿐 도달을 뜻하지 않는다.';

select 'push_result ok' as result;
