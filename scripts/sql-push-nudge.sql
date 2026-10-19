-- 알림을 안 켠 마사지사에게 보낼 재촉 메일 기록 (2026-10-19)
--
-- 왜 — 승인된 13명 중 12명이 기기 0개다. 예약이 와도 본인은 모른다.
-- 켤 때까지 주기적으로 찔러야 하는데, 몇 번 보냈는지 어딘가에 남겨야
-- 같은 사람에게 무한정 보내지 않는다.
create table if not exists public.push_nudges (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  sent_count   int not null default 0,
  last_sent_at timestamptz
);
alter table public.push_nudges enable row level security;
-- 본인도 볼 필요가 없다. 서버(service_role)만 쓴다.

-- 지금 재촉 메일을 보내야 할 사람 목록.
-- 조건 — 승인된 마사지사 · 기기 0개 · 마지막 발송 후 3시간 경과 · 아직 상한 미만
create or replace function public.push_nudge_targets(p_gap_hours int, p_max int)
returns table (user_id uuid, email text, display_name text, sent_count int)
language sql
security definer
set search_path to 'public'
as $$
  select u.id, u.email, pr.display_name, coalesce(n.sent_count, 0)
  from providers pr
  join auth.users u on u.id = coalesce(pr.profile_id, pr.owner_id)
  left join push_nudges n on n.user_id = u.id
  where pr.application_status = 'approved'
    and u.email is not null
    and not exists (select 1 from push_tokens t where t.user_id = u.id)
    and coalesce(n.sent_count, 0) < p_max
    and (n.last_sent_at is null or n.last_sent_at < now() - make_interval(hours => p_gap_hours))
  group by u.id, u.email, pr.display_name, n.sent_count;
$$;

revoke execute on function public.push_nudge_targets(int, int) from public;
revoke execute on function public.push_nudge_targets(int, int) from anon;
revoke execute on function public.push_nudge_targets(int, int) from authenticated;
grant execute on function public.push_nudge_targets(int, int) to service_role;

-- 보낸 뒤 기록
create or replace function public.push_nudge_mark(p uuid)
returns void
language sql
security definer
set search_path to 'public'
as $$
  insert into push_nudges (user_id, sent_count, last_sent_at)
  values (p, 1, now())
  on conflict (user_id) do update
    set sent_count = push_nudges.sent_count + 1, last_sent_at = now();
$$;

revoke execute on function public.push_nudge_mark(uuid) from public;
revoke execute on function public.push_nudge_mark(uuid) from anon;
revoke execute on function public.push_nudge_mark(uuid) from authenticated;
grant execute on function public.push_nudge_mark(uuid) to service_role;
