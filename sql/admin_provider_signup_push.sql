-- 마사지사가 새로 가입하면 관리자(profiles.role='admin')에게 앱 푸시 알림을 남긴다 (2026-11-15)
-- notifications 에 한 줄 넣으면 기존 발송기(massa_push.sh → send-push)가 1분 안에 관리자 폰으로 보낸다.
-- 메일 알림(notify_signup → notify-admin)은 그대로 두고, 이 트리거는 푸시만 더한다.
create or replace function public.push_admin_provider_signup()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  begin
    insert into public.notifications (user_id, title, body, kind, provider_id)
    select p.id,
           '새 마사지사 가입',
           coalesce(nullif(new.display_name, ''), '이름 미입력')
             || coalesce(' · ' || nullif(new.city_code, ''), '')
             || ' — 관리자 화면에서 확인해 주세요.',
           'admin_provider_signup',
           new.id
      from public.profiles p
     where p.role = 'admin';
  exception when others then
    -- 알림이 실패해도 가입은 막지 않는다
    raise warning '관리자 가입 푸시 생성 실패: %', sqlerrm;
  end;
  return new;
end
$$;

drop trigger if exists trg_push_admin_provider_signup on public.providers;
create trigger trg_push_admin_provider_signup
  after insert on public.providers
  for each row execute function public.push_admin_provider_signup();
