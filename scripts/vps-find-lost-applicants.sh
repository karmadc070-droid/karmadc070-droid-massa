#!/bin/sh
# ASCII only. Did anyone apply without ending up in providers?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. how many accounts exist at all ==='
$PSQL -c "select count(*) as users,
                 count(*) filter (where email_confirmed_at is null) as unconfirmed
          from auth.users;" 2>&1

echo '=== 2. kyc rows that point at no provider, or providers with no kyc ==='
$PSQL -c "select 'kyc without provider' as what, count(*) from provider_kyc k
          where not exists (select 1 from providers p where p.id=k.provider_id)
          union all
          select 'provider without kyc', count(*) from providers p
          where not exists (select 1 from provider_kyc k where k.provider_id=p.id);" 2>&1

echo '=== 3. accounts that look like therapists but have no provider row ==='
$PSQL -c "
select u.email,
       u.raw_user_meta_data->>'role'  as meta_role,
       u.raw_app_meta_data->>'provider' as signup,
       to_char(u.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as joined
from auth.users u
where not exists (select 1 from providers p
                  where p.profile_id = u.id or p.owner_id = u.id)
  and (u.raw_user_meta_data->>'role' is not null
       or exists (select 1 from profiles pr where pr.id=u.id and pr.role is not null))
order by u.created_at;" 2>&1

echo '=== 4. profiles.role breakdown ==='
$PSQL -c "select role, count(*) from profiles group by 1 order by 2 desc;" 2>&1

echo '=== 5. every account, newest first (who signed up recently) ==='
$PSQL -c "
select u.email,
       coalesce(pr.role,'-') as role,
       (select count(*) from providers p where p.profile_id=u.id or p.owner_id=u.id) as prov,
       to_char(u.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as joined
from auth.users u left join profiles pr on pr.id=u.id
order by u.created_at desc limit 30;" 2>&1
echo '=== DONE ==='
