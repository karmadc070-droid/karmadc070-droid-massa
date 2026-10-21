-- massaviet.com 의 제휴·상담 폼이 남기는 문의. 관리자에게 메일로 알린다 (2026-10-21).
--
-- 왜 테이블을 거치는가. notify-admin 함수는 NOTIFY_SECRET 으로 잠겨 있다.
-- 공개 웹페이지에 그 시크릿을 박으면 누구나 메일을 쏘는 중계기가 된다.
-- 그래서 입금 신고와 같은 길로 간다. 폼 → 테이블 → 트리거(pg_net) → notify-admin.
-- 시크릿은 app_settings 안에만 있고 브라우저는 보지 못한다.
--
-- 적용: scripts/vps-apply-contact.sh

create table if not exists public.contact_request (
  id          uuid primary key default gen_random_uuid(),
  company     text not null,
  person      text not null,
  phone       text not null,
  email       text not null,
  region      text,
  message     text,
  lang        text,                       -- 폼을 띄운 페이지 언어 (ko/en/vi)
  created_at  timestamptz not null default now(),
  handled_at  timestamptz,                -- 콘솔에서 처리 표시할 때 채운다
  constraint contact_len check (
    length(company) between 1 and 120 and
    length(person)  between 1 and 80  and
    length(phone)   between 1 and 40  and
    length(email)   between 3 and 160 and
    length(coalesce(region,''))  <= 120 and
    length(coalesce(message,'')) <= 4000
  )
);

create index if not exists contact_request_new on public.contact_request (created_at desc);

alter table public.contact_request enable row level security;

-- 손님은 넣기만 한다. 남의 문의를 읽을 수 있으면 연락처가 통째로 샌다.
drop policy if exists contact_insert_anyone on public.contact_request;
create policy contact_insert_anyone on public.contact_request
  for insert to anon, authenticated with check (true);

drop policy if exists contact_read_admin on public.contact_request;
create policy contact_read_admin on public.contact_request
  for select to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- 누구나 넣을 수 있는 자리라 한 번 긁히면 메일이 수천 통 나간다.
-- 분당 10건으로 막는다. 사람이 쓰는 폼이 1분에 10건을 넘길 일은 없다.
create or replace function public.contact_request_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.contact_request
       where created_at > now() - interval '1 minute') >= 10 then
    raise exception '잠시 후 다시 시도해 주세요.' using errcode = '53400';
  end if;
  return new;
end $$;

drop trigger if exists trg_contact_guard on public.contact_request;
create trigger trg_contact_guard before insert on public.contact_request
  for each row execute function public.contact_request_guard();

-- 알림. 실패해도 문의 자체는 저장돼야 한다 — 메일은 부수적인 일이다.
create or replace function public.notify_contact_request()
returns trigger language plpgsql security definer set search_path = public as $$
declare cfg jsonb; u text; s text;
begin
  select value into cfg from public.app_settings where key = 'notify';
  u := coalesce(cfg->>'url', '');
  s := coalesce(cfg->>'secret', '');
  if u = '' then return new; end if;
  begin
    perform net.http_post(
      url     := u,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-notify-secret', s),
      body    := jsonb_build_object('action', 'contact_request', 'contact_id', new.id),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning '상담 문의 알림 전송 실패: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists trg_notify_contact on public.contact_request;
create trigger trg_notify_contact after insert on public.contact_request
  for each row execute function public.notify_contact_request();

select 'contact_request ok' as result;
