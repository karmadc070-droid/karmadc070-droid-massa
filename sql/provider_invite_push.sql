-- 마사지사 친구 초대 홍보 푸시(하노이 12:30·19:00)를 만들고, 손님용 데일리 푸시에서 승인된 마사지사를 뺀다 (2026-10-29)
-- 마사지사는 하루 2번 이 푸시만, 손님은 기존 2번(12:45·18:00)만 받는다.
-- 실행 기록은 daily_push_runs(run_date, slot) 를 같이 쓴다 — slot 'prov_noon' / 'prov_evening'. 같은 날 두 번 불러도 한 번만 나간다.
-- VPS 크론(서버 시계 KST): 30 14 * * * = 하노이 12:30, 0 21 * * * = 하노이 19:00

-- 1) 손님 데일리 푸시: 승인된 마사지사 계정은 받지 않는다. 나머지는 daily_push_evening_photo.sql 그대로.
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
  ), pv as ( -- 오늘의 테라피스트: 승인·정지 아님·사진 있음·테스트 아님, 날짜로 돌아가며 1명 (저녁만)
    select x.id, x.display_name, x.photo_url
    from (select p.id, p.display_name, p.photo_url,
                 row_number() over (order by p.id) - 1 as rn, count(*) over () as cnt
          from public.providers p
          where p.application_status = 'approved'
            and coalesce(p.photo_url, '') <> ''
            and p.display_name not like '[TEST]%'
            and (p.suspended_until is null or p.suspended_until < now())) x, d
    where p_slot = 'evening' and x.rn = (d.run_date - date '2026-10-28') % x.cnt
  ), u as ( -- 사용자당 1건: 가장 최근 기기의 언어, 모르는 언어는 en. 승인된 마사지사는 빼고(마사지사 전용 푸시가 따로 있다), 신청 중인 사람은 사진 없이
    select distinct on (t.user_id) t.user_id,
           case when t.lang in ('ko','vi','en','zh','ja') then t.lang else 'en' end as lang,
           exists (select 1 from public.providers q where q.profile_id = t.user_id or q.owner_id = t.user_id) as is_prov
    from public.push_tokens t join public.profiles p on p.id = t.user_id
    where not exists (select 1 from public.providers a
                       where (a.profile_id = t.user_id or a.owner_id = t.user_id) and a.application_status = 'approved')
    order by t.user_id, t.updated_at desc nulls last
  ), ins as (
    insert into public.notifications (user_id, kind, title, body, image_url, provider_id)
    select u.user_id,
           case when pv.id is not null and not u.is_prov then 'promo_provider' else 'notice' end,
           m.title ->> u.lang,
           case when pv.id is not null and not u.is_prov
                then ('{"ko":"오늘의 테라피스트 · ","vi":"Kỹ thuật viên hôm nay · ","en":"Today''s therapist · ","zh":"今日理疗师 · ","ja":"今日のセラピスト · "}'::jsonb ->> u.lang)
                     || pv.display_name || ' — ' || (m.body ->> u.lang)
                else m.body ->> u.lang end,
           case when not u.is_prov then replace(pv.photo_url, '/storage/v1/object/public/', '/storage/v1/render/image/public/') || '?width=540&quality=60' end,
           case when not u.is_prov then pv.id end
    from u cross join m left join pv on true
    returning 1
  )
  select count(*)::int from ins;
$$;
revoke all on function public.send_daily_push(text) from public, anon, authenticated;

-- 2) 마사지사 친구 초대 홍보. 문구 3개를 날짜·시간대로 돌린다. 누르면 앱이 마사지사 초대 화면을 연다(kind invite_promo).
--    이미 10명 보상을 다 받은 마사지사에게는 보내지 않는다.
create or replace function public.send_provider_invite_push(p_slot text default 'noon')
returns integer language sql security definer set search_path = '' as $$
  with d as (
    insert into public.daily_push_runs (run_date, slot)
    values ((now() at time zone 'Asia/Ho_Chi_Minh')::date, 'prov_' || p_slot)
    on conflict (run_date, slot) do nothing
    returning run_date
  ), c as (
    select '[
      {"t":{"ko":"마사지사 친구를 초대하세요","vi":"Mời bạn kỹ thuật viên","en":"Invite a therapist friend","zh":"邀请技师朋友","ja":"セラピストの友達を招待"},
       "b":{"ko":"친구 1명당 100,000동, 최대 1,000,000동까지 적립돼요","vi":"Mỗi người bạn 100.000đ, tối đa 1.000.000đ","en":"100,000₫ per friend, up to 1,000,000₫","zh":"每邀请1位得100,000越南盾，最高1,000,000越南盾","ja":"1人につき100,000ドン、最大1,000,000ドン"}},
      {"t":{"ko":"함께 일할 동료를 데려오세요","vi":"Rủ đồng nghiệp cùng làm","en":"Bring a colleague on board","zh":"带同事一起来","ja":"一緒に働く仲間を誘いましょう"},
       "b":{"ko":"초대한 친구가 승인되고 첫 서비스를 마치면 100,000동","vi":"Nhận 100.000đ khi bạn được mời được duyệt và hoàn thành đơn đầu tiên","en":"Get 100,000₫ when your friend is approved and finishes their first job","zh":"朋友通过审核并完成首单，您得100,000越南盾","ja":"友達が承認され初回の施術を終えると100,000ドン"}},
      {"t":{"ko":"초대 보상 최대 1,000,000동","vi":"Thưởng mời bạn tới 1.000.000đ","en":"Earn up to 1,000,000₫ for invites","zh":"邀请奖励最高1,000,000越南盾","ja":"招待報酬は最大1,000,000ドン"},
       "b":{"ko":"내 초대 링크를 보내기만 하면 돼요. 앱에서 확인하세요","vi":"Chỉ cần gửi link mời của bạn. Mở ứng dụng để xem","en":"Just share your invite link. Open the app to see it","zh":"只需分享您的邀请链接，在应用中查看","ja":"招待リンクを送るだけ。アプリで確認してください"}}
    ]'::jsonb as v
  ), m as (
    select c.v -> (((d.run_date - date '2026-10-29') * 2 + case when p_slot = 'evening' then 1 else 0 end) % 3) as x
    from c, d
  ), u as (
    select distinct on (t.user_id) t.user_id,
           case when t.lang in ('ko','vi','en','zh','ja') then t.lang else 'en' end as lang
    from public.push_tokens t
    where exists (select 1 from public.providers a
                   where (a.profile_id = t.user_id or a.owner_id = t.user_id)
                     and a.application_status = 'approved' and a.display_name not like '[TEST]%')
      and (select count(*) from public.referral_rewards r where r.inviter_id = t.user_id) < 10
    order by t.user_id, t.updated_at desc nulls last
  ), ins as (
    insert into public.notifications (user_id, kind, title, body)
    select u.user_id, 'invite_promo', m.x -> 't' ->> u.lang, m.x -> 'b' ->> u.lang
    from u cross join m
    returning 1
  )
  select count(*)::int from ins;
$$;
revoke all on function public.send_provider_invite_push(text) from public, anon, authenticated;
