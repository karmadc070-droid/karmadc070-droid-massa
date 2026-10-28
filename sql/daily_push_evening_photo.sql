-- massa 저녁 푸시에 '오늘의 테라피스트' 사진·프로필을 붙인다 (손님 기기만, 날마다 한 명씩 돌아가며, 2026-10-28)
alter table public.notifications
  add column if not exists image_url text,
  add column if not exists provider_id uuid references public.providers(id) on delete set null;

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
  ), u as ( -- 사용자당 1건: 가장 최근 기기의 언어, 모르는 언어는 en. 테라피스트 본인 계정은 사진 없이
    select distinct on (t.user_id) t.user_id,
           case when t.lang in ('ko','vi','en','zh','ja') then t.lang else 'en' end as lang,
           exists (select 1 from public.providers q where q.profile_id = t.user_id or q.owner_id = t.user_id) as is_prov
    from public.push_tokens t join public.profiles p on p.id = t.user_id
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
           -- 원본 사진은 2MB 안팎 PNG 라 Android 알림 한도(1MB)를 넘는다 → 저장소 변환 주소로 540px 축소본을 쓴다
           case when not u.is_prov then replace(pv.photo_url, '/storage/v1/object/public/', '/storage/v1/render/image/public/') || '?width=540&quality=60' end,
           case when not u.is_prov then pv.id end
    from u cross join m left join pv on true
    returning 1
  )
  select count(*)::int from ins;
$$;
revoke all on function public.send_daily_push(text) from public, anon, authenticated;