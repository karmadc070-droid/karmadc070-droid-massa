-- massa 데일리 푸시: 매일 하노이 12:45 에 기기가 있는 모든 사용자에게 요일별 문구를 기기 언어(ko/vi/en/zh/ja)로 보낸다 (2026-10-28)
-- 발송 경로는 공지와 같다: notifications(kind='notice') 행 → trg_kick_send_push → send-push.
-- send-push 는 notice 의 title/body 를 그대로 쓰므로 언어는 여기서 고른다(그 사용자의 최근 기기 push_tokens.lang).
-- VPS 크론: 45 14 * * * (KST 14:45 = 하노이 12:45)

create table if not exists public.daily_push_messages (
  dow smallint primary key check (dow between 0 and 6), -- extract(dow): 0=일 … 6=토
  title jsonb not null,
  body jsonb not null
);
alter table public.daily_push_messages enable row level security; -- 정책 없음: 서버만 읽는다

create table if not exists public.daily_push_runs (
  run_date date primary key, -- 하노이 날짜. 이미 있으면 그날은 다시 안 보낸다
  created_at timestamptz not null default now()
);
alter table public.daily_push_runs enable row level security;

insert into public.daily_push_messages (dow, title, body) values
(1, jsonb_build_object('ko','월요일 피로, 집에서 풀기','vi','Xua tan mệt mỏi đầu tuần','en','Shake off Monday','zh','周一的疲惫，在家放松','ja','月曜の疲れを自宅で'),
    jsonb_build_object('ko','테라피스트가 집이나 호텔로 찾아가요','vi','Kỹ thuật viên đến tận nhà hoặc khách sạn của bạn','en','A therapist comes to your home or hotel','zh','理疗师上门到您家或酒店','ja','セラピストがご自宅やホテルへ伺います')),
(2, jsonb_build_object('ko','도착까지 실시간 확인','vi','Theo dõi đường đến trực tiếp','en','Track the arrival live','zh','实时查看到达进度','ja','到着をリアルタイムで確認'),
    jsonb_build_object('ko','테라피스트가 오는 위치를 앱에서 볼 수 있어요','vi','Xem vị trí kỹ thuật viên đang đến ngay trên ứng dụng','en','See where your therapist is on the way in the app','zh','在应用中查看理疗师的实时位置','ja','セラピストの現在地をアプリで確認できます')),
(3, jsonb_build_object('ko','한 주의 중간, 쉬어 가요','vi','Giữa tuần, nghỉ một chút','en','Midweek break','zh','周中，休息一下','ja','週の真ん中にひと休み'),
    jsonb_build_object('ko','오늘 저녁 방문 마사지를 예약해 보세요','vi','Đặt massage tại nhà cho tối nay nhé','en','Book a home massage for this evening','zh','预约今晚的上门按摩吧','ja','今夜の出張マッサージを予約しませんか')),
(4, jsonb_build_object('ko','뷰티도 집에서','vi','Làm đẹp ngay tại nhà','en','Beauty, at your door','zh','美容也能上门','ja','美容もご自宅で'),
    jsonb_build_object('ko','뷰티 서비스도 방문으로 받을 수 있어요','vi','Dịch vụ làm đẹp cũng có thể đến tận nơi','en','Beauty services can come to you too','zh','美容服务也可以上门为您服务','ja','美容サービスも出張で受けられます')),
(5, jsonb_build_object('ko','금요일 밤, 호텔에서 휴식','vi','Tối thứ Sáu thư giãn','en','Friday night unwind','zh','周五晚，在酒店放松','ja','金曜の夜はホテルで癒し'),
    jsonb_build_object('ko','호텔 방으로 테라피스트를 불러 보세요','vi','Gọi kỹ thuật viên đến phòng khách sạn của bạn','en','Have a therapist come to your hotel room','zh','请理疗师到您的酒店房间','ja','ホテルの部屋にセラピストを呼べます')),
(6, jsonb_build_object('ko','주말엔 집에서 마사지','vi','Cuối tuần massage tại nhà','en','Weekend massage at home','zh','周末在家按摩','ja','週末は自宅でマッサージ'),
    jsonb_build_object('ko','가까운 테라피스트를 앱에서 찾아보세요','vi','Tìm kỹ thuật viên gần bạn trên ứng dụng','en','Find a therapist near you in the app','zh','在应用中找到附近的理疗师','ja','近くのセラピストをアプリで探せます')),
(0, jsonb_build_object('ko','새 주를 가볍게','vi','Nhẹ nhàng đón tuần mới','en','Reset for the week','zh','轻松迎接新一周','ja','新しい週を軽やかに'),
    jsonb_build_object('ko','내일을 위해 오늘 몸을 풀어 보세요','vi','Thư giãn hôm nay để sẵn sàng cho ngày mai','en','Relax today so you''re ready for tomorrow','zh','今天放松一下，为明天做好准备','ja','明日に備えて今日は体をほぐしましょう'))
on conflict (dow) do update set title = excluded.title, body = excluded.body;

create or replace function public.send_daily_push() returns integer
language sql security definer set search_path = '' as $$
  with d as (
    insert into public.daily_push_runs (run_date)
    values ((now() at time zone 'Asia/Ho_Chi_Minh')::date)
    on conflict (run_date) do nothing
    returning run_date
  ), m as (
    select title, body from public.daily_push_messages, d
    where dow = extract(dow from d.run_date)::int
  ), u as ( -- 사용자당 1건: 가장 최근 기기의 언어, 모르는 언어는 en
    select distinct on (t.user_id) t.user_id,
           case when t.lang in ('ko','vi','en','zh','ja') then t.lang else 'en' end as lang
    from public.push_tokens t join public.profiles p on p.id = t.user_id
    order by t.user_id, t.updated_at desc nulls last
  ), ins as (
    insert into public.notifications (user_id, kind, title, body)
    select u.user_id, 'notice', m.title ->> u.lang, m.body ->> u.lang
    from u cross join m
    returning 1
  )
  select count(*)::int from ins;
$$;
revoke execute on function public.send_daily_push() from public, anon, authenticated;