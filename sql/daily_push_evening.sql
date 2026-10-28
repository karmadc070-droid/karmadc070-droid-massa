-- massa 매일 푸시를 하루 2번(하노이 12:45, 18:00)으로 — 문구와 실행 기록을 slot(noon/evening)으로 나눈다
alter table public.daily_push_messages add column if not exists slot text not null default 'noon';
alter table public.daily_push_messages drop constraint if exists daily_push_messages_slot_check;
alter table public.daily_push_messages add constraint daily_push_messages_slot_check check (slot in ('noon','evening'));
alter table public.daily_push_messages drop constraint daily_push_messages_pkey;
alter table public.daily_push_messages add primary key (dow, slot);

alter table public.daily_push_runs add column if not exists slot text not null default 'noon';
alter table public.daily_push_runs drop constraint daily_push_runs_pkey;
alter table public.daily_push_runs add primary key (run_date, slot);

drop function if exists public.send_daily_push();
create or replace function public.send_daily_push(p_slot text default 'noon')
returns integer language sql security definer set search_path = '' as $$
  with d as (
    insert into public.daily_push_runs (run_date, slot)
    values ((now() at time zone 'Asia/Ho_Chi_Minh')::date, p_slot)
    on conflict (run_date, slot) do nothing
    returning run_date
  ), m as (
    select title, body from public.daily_push_messages, d
    where dow = extract(dow from d.run_date)::int and slot = p_slot
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
revoke all on function public.send_daily_push(text) from public, anon, authenticated;

insert into public.daily_push_messages (dow, slot, title, body) values
 (0,'evening',
  '{"ko":"일요일 저녁, 한 주 마무리","vi":"Tối Chủ nhật, khép lại một tuần","en":"Sunday evening wind-down","zh":"周日晚上，为一周收尾","ja":"日曜の夜、一週間の締めくくり"}',
  '{"ko":"집에서 받는 마사지로 편하게 쉬어 보세요","vi":"Thư giãn với massage tại nhà nhé","en":"Relax with a massage at home","zh":"在家享受按摩，好好放松","ja":"自宅でマッサージを受けてゆっくり休みましょう"}'),
 (1,'evening',
  '{"ko":"월요일 저녁, 뭉친 어깨 풀기","vi":"Tối thứ Hai, thả lỏng đôi vai","en":"Monday evening, loosen up","zh":"周一晚上，放松肩膀","ja":"月曜の夜、こった肩をほぐす"}',
  '{"ko":"오늘 밤 테라피스트가 집으로 찾아가요","vi":"Tối nay kỹ thuật viên đến tận nhà bạn","en":"A therapist can come to your home tonight","zh":"今晚理疗师可上门到您家","ja":"今夜セラピストがご自宅へ伺います"}'),
 (2,'evening',
  '{"ko":"퇴근 후엔 집에서 쉬세요","vi":"Tan làm rồi, nghỉ ngơi tại nhà","en":"After work, rest at home","zh":"下班后，在家休息","ja":"仕事のあとは自宅でひと休み"}',
  '{"ko":"이동 없이 집이나 호텔에서 마사지를 받아 보세요","vi":"Không cần di chuyển, massage ngay tại nhà hoặc khách sạn","en":"Get a massage at home or your hotel, no travel needed","zh":"无需出门，在家或酒店享受按摩","ja":"移動なしで自宅やホテルでマッサージを"}'),
 (3,'evening',
  '{"ko":"수요일 밤, 잠들기 전 휴식","vi":"Tối thứ Tư, thư giãn trước khi ngủ","en":"Wednesday night, unwind before bed","zh":"周三晚上，睡前放松","ja":"水曜の夜、寝る前にリラックス"}',
  '{"ko":"오늘 밤 예약하고 편하게 쉬어 보세요","vi":"Đặt lịch tối nay và nghỉ ngơi thoải mái","en":"Book for tonight and relax","zh":"预约今晚，轻松休息","ja":"今夜の予約をしてゆっくり休みましょう"}'),
 (4,'evening',
  '{"ko":"이번 주 고생한 나에게","vi":"Tặng bản thân sau một tuần vất vả","en":"Treat yourself after a long week","zh":"犒劳辛苦一周的自己","ja":"一週間がんばった自分へ"}',
  '{"ko":"오늘 저녁 방문 마사지로 쉬어 가세요","vi":"Tối nay massage tại nhà để thư giãn nhé","en":"Take a break with a home massage tonight","zh":"今晚来一次上门按摩吧","ja":"今夜は出張マッサージでひと休み"}'),
 (5,'evening',
  '{"ko":"금요일 밤, 원하는 시간에","vi":"Tối thứ Sáu, chọn giờ bạn muốn","en":"Friday night, at a time you choose","zh":"周五晚上，选您方便的时间","ja":"金曜の夜、好きな時間に"}',
  '{"ko":"주말 전 저녁, 원하는 시간에 예약해 보세요","vi":"Tối trước cuối tuần, đặt lịch vào giờ bạn muốn","en":"Book the evening slot that suits you before the weekend","zh":"周末前的晚上，预约您想要的时间","ja":"週末前の夜、好きな時間に予約しましょう"}'),
 (6,'evening',
  '{"ko":"토요일 밤, 여행 피로 풀기","vi":"Tối thứ Bảy, xua tan mệt mỏi chuyến đi","en":"Saturday night, ease travel fatigue","zh":"周六晚上，缓解旅途疲劳","ja":"土曜の夜、旅の疲れをほぐす"}',
  '{"ko":"관광 후 호텔에서 마사지를 받아 보세요","vi":"Sau khi tham quan, massage ngay tại khách sạn","en":"After sightseeing, get a massage at your hotel","zh":"观光后，在酒店享受按摩","ja":"観光のあとはホテルでマッサージを"}')
on conflict (dow, slot) do update set title = excluded.title, body = excluded.body;