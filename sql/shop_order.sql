-- massaviet.com/shop 장바구니가 남기는 주문 요청. 결제를 붙이기 전까지 관리자가 전화로 확인한다 (2026-11-19).
--
-- contact_request 와 같은 길로 간다. 폼 → 테이블 → 트리거(pg_net) → notify-admin.
-- notify-admin 시크릿은 app_settings 안에만 있고 브라우저는 보지 못한다.
-- items·total_vnd 는 브라우저가 계산해 보낸 참고값이다. 결제를 붙일 때 서버 계산으로 바꾼다.
--
-- 적용: scripts/vps-apply-shop-order.sh

create table if not exists public.shop_order (
  id          uuid primary key default gen_random_uuid(),
  items       jsonb not null,             -- [{id, name, price, qty}]
  total_vnd   bigint not null,
  name        text not null,
  phone       text not null,
  address     text not null,
  note        text,
  lang        text,                       -- 주문한 화면 언어 (vi/ko/en)
  created_at  timestamptz not null default now(),
  handled_at  timestamptz,                -- 관리자가 처리 표시할 때 채운다
  constraint shop_order_len check (
    jsonb_typeof(items) = 'array' and jsonb_array_length(items) between 1 and 50 and
    length(items::text) <= 20000 and
    total_vnd between 0 and 1000000000 and
    length(name)    between 1 and 80  and
    length(phone)   between 1 and 40  and
    length(address) between 1 and 300 and
    length(coalesce(note,'')) <= 1000 and
    length(coalesce(lang,'')) <= 5
  )
);

create index if not exists shop_order_new on public.shop_order (created_at desc);

alter table public.shop_order enable row level security;

-- 손님은 넣기만 한다. 남의 주문을 읽을 수 있으면 이름·전화·주소가 통째로 샌다.
drop policy if exists shop_order_insert_anyone on public.shop_order;
create policy shop_order_insert_anyone on public.shop_order
  for insert to anon, authenticated with check (true);

drop policy if exists shop_order_read_admin on public.shop_order;
create policy shop_order_read_admin on public.shop_order
  for select to authenticated
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- 누구나 넣을 수 있는 자리라 분당 10건으로 막는다 (메일 폭주 방지).
create or replace function public.shop_order_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.shop_order
       where created_at > now() - interval '1 minute') >= 10 then
    raise exception 'Vui lòng thử lại sau.' using errcode = '53400';
  end if;
  return new;
end $$;

drop trigger if exists trg_shop_order_guard on public.shop_order;
create trigger trg_shop_order_guard before insert on public.shop_order
  for each row execute function public.shop_order_guard();

-- 알림. 실패해도 주문 요청 자체는 저장돼야 한다.
create or replace function public.notify_shop_order()
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
      body    := jsonb_build_object('action', 'shop_order', 'order_id', new.id),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning '주문 요청 알림 전송 실패: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists trg_notify_shop_order on public.shop_order;
create trigger trg_notify_shop_order after insert on public.shop_order
  for each row execute function public.notify_shop_order();

select 'shop_order ok' as result;
