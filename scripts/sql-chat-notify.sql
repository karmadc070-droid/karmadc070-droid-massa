-- 채팅 메시지가 오면 받는 사람에게 알림을 만들고, 앱의 실시간 구독(채팅·알림)이 실제로 받도록 publication 에 테이블을 넣는다
-- 2026-10-22: messages 에 알림 트리거가 없어 상대가 메시지를 알 방법이 없었고, supabase_realtime 이 비어 있어 앱의 postgres_changes 구독도 아무것도 받지 못했다.
-- 대화(예약)별 첫 알림은 kind='chat_first' → send-push 가 기기 없는 사람에게 메일로 대신 보낸다. 이후는 'chat' (푸시만).
-- 같은 사람·같은 예약에 2분 안에 또 오면 알림을 만들지 않는다 (연속 메시지 폭탄 방지).

create or replace function public.notify_new_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_bk   uuid;
  v_from text;
begin
  select id into v_bk from bookings
   where customer_id = new.customer_id and provider_id = new.provider_id and status <> 'cancelled'
   order by scheduled_at desc limit 1;

  if new.sender_role = 'provider' then
    select display_name into v_from from providers where id = new.provider_id;
  else
    v_from := 'Khách';
  end if;

  insert into notifications (user_id, title, body, kind, booking_id)
  select r.u, '새 메시지가 왔습니다',
         coalesce(v_from, 'massa') || ': ' || left(new.body, 80),
         case when exists (select 1 from notifications x
                            where x.user_id = r.u and x.kind in ('chat', 'chat_first')
                              and x.booking_id is not distinct from v_bk)
              then 'chat' else 'chat_first' end,
         v_bk
    from (select new.customer_id as u where new.sender_role = 'provider'
          union select owner_id   from providers where id = new.provider_id and new.sender_role = 'customer'
          union select profile_id from providers where id = new.provider_id and new.sender_role = 'customer') r
   where r.u is not null
     and not exists (select 1 from notifications x
                      where x.user_id = r.u and x.kind in ('chat', 'chat_first')
                        and x.booking_id is not distinct from v_bk
                        and x.created_at > now() - interval '2 minutes');
  return new;
exception when others then
  raise warning '채팅 알림 생성 실패: %', sqlerrm;   -- 알림 실패로 메시지 저장까지 막지 않는다
  return new;
end $$;

drop trigger if exists trg_notify_new_message on public.messages;
create trigger trg_notify_new_message after insert on public.messages
  for each row execute function public.notify_new_message();

-- 앱의 채팅 화면·알림 토스트는 postgres_changes 구독을 이미 쓰고 있다. publication 에 넣어야 실제로 온다.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
