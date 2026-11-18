-- 마사지사가 수락한 뒤 '갈 수 없어요'로 취소할 수 있게 한다 (2026-11-19, 사용자 승인)
-- 적용: docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -1 < sql/provider_cancel.sql
-- 운영의 현재 정의에서 필요한 곳만 바꿔 다시 만든다. 두 번 돌려도 '이미 반영됨'으로 끝난다.

-- 1) 가드: 확정·이동 중에서 마사지사가 취소하면 사유 필수, cancelled_by·cancelled_at 은 서버가 정한다.
--    마사지사가 cancelled_by 를 다른 값(예: customer)으로 넣어 손님 제재로 돌리는 것도 막는다.
do $$
declare
  d text := pg_get_functiondef('public.guard_booking_write'::regproc);
  a text := '    if ''no_show_at''   = any(ch) then new.no_show_at   := now(); end if;' || chr(10);
  b text := a
    || '    -- 수락한 뒤 ''갈 수 없어요'' (2026-11-19): 사유 필수, 누가 취소했는지는 서버가 정한다' || chr(10)
    || '    if new.status = ''cancelled'' and old.status in (''confirmed'', ''on_the_way'') then' || chr(10)
    || '      if coalesce(btrim(new.cancel_reason), '''') = '''' then' || chr(10)
    || '        raise exception ''못 가는 이유를 적어 주세요.'' using errcode = ''42501'';' || chr(10)
    || '      end if;' || chr(10)
    || '      new.cancelled_by := ''provider'';' || chr(10)
    || '      new.cancelled_at := now();' || chr(10)
    || '    elsif ''cancelled_by'' = any(ch) then' || chr(10)
    || '      raise exception ''취소한 사람은 바꿀 수 없습니다.'' using errcode = ''42501'';' || chr(10)
    || '    end if;' || chr(10);
begin
  if position('''provider''' in d) > 0 then
    raise notice 'guard_booking_write: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'guard_booking_write 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;

-- 2) 알림: 손님에게 사유와 함께 알리고(푸시 제목은 send-push 의 booking_cancelled 번역), 관리자에게도 알린다(다시 잡아 줄 수 있게).
do $$
declare
  d text := pg_get_functiondef('public.notify_booking_event'::regproc);
  a text := '  elsif new.status = ''cancelled'' and coalesce(new.cancelled_by, '''') <> ''customer'' then' || chr(10);
  b text := '  elsif new.status = ''cancelled'' and new.cancelled_by = ''provider'' then' || chr(10)
    || '    -- 마사지사가 수락 뒤 못 가게 됨 (2026-11-19)' || chr(10)
    || '    v_body := v_body || coalesce('' · '' || nullif(btrim(new.cancel_reason), ''''), '''');' || chr(10)
    || '    insert into notifications (user_id, title, body, kind, booking_id)' || chr(10)
    || '    values (new.customer_id, ''테라피스트가 갈 수 없게 되었습니다'', v_body, ''booking_cancelled'', new.id);' || chr(10)
    || '    insert into notifications (user_id, title, body, kind, booking_id)' || chr(10)
    || '    select id, ''테라피스트가 수락한 예약을 취소했습니다'', v_body, ''booking_cancelled_by_provider'', new.id' || chr(10)
    || '      from profiles where role = ''admin'';' || chr(10)
    || '    return new;' || chr(10)
    || a;
begin
  if position('''provider''' in d) > 0 then
    raise notice 'notify_booking_event: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'notify_booking_event 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;

-- 3) 제재: 마사지사가 취소한 건은 손님 '임박 취소'로 세지 않는다.
do $$
declare
  d text := pg_get_functiondef('public.refresh_customer_penalty'::regproc);
  a text := 'coalesce(cancelled_by, '''') <> ''expired'' and scheduled_at';
  b text := 'coalesce(cancelled_by, '''') not in (''expired'', ''provider'') and scheduled_at';
begin
  if position('''provider''' in d) > 0 then
    raise notice 'refresh_customer_penalty: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'refresh_customer_penalty 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;
