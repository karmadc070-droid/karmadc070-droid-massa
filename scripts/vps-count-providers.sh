#!/bin/sh
# ASCII only. Count therapists every way they get counted, to find the mismatch.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 1. raw breakdown: kind x status x active ==='
$PSQL -c "select kind, application_status, is_active, count(*)
          from providers group by 1,2,3 order by 1,2,3;" 2>&1

echo '=== 2. totals ==='
$PSQL -c "select count(*) as all_rows,
                 count(*) filter (where application_status='approved') as approved,
                 count(*) filter (where application_status='approved' and is_active) as approved_on,
                 count(*) filter (where application_status='pending')  as pending,
                 count(*) filter (where application_status='rejected') as rejected
          from providers;" 2>&1

echo '=== 3. what a customer actually sees (approved + on duty) ==='
$PSQL -c "select display_name, kind, city_code, is_active,
                 (lat is null) as no_coords
          from providers
          where application_status='approved' and is_active
          order by city_code, display_name;" 2>&1

echo '=== 4. approved but OFF duty (counted as approved, invisible to customers) ==='
$PSQL -c "select p.display_name, p.city_code, u.email
          from providers p left join auth.users u on u.id=coalesce(p.profile_id,p.owner_id)
          where p.application_status='approved' and not p.is_active;" 2>&1

echo '=== 5. waiting / rejected ==='
$PSQL -c "select p.display_name, p.application_status, p.city_code, u.email,
                 to_char(p.created_at at time zone 'Asia/Seoul','MM-DD HH24:MI') as joined
          from providers p left join auth.users u on u.id=coalesce(p.profile_id,p.owner_id)
          where p.application_status not in ('approved')
          order by p.created_at;" 2>&1

echo '=== 6. rows with no linked account (orphans) ==='
$PSQL -c "select display_name, application_status, is_active
          from providers
          where profile_id is null and owner_id is null;" 2>&1

echo '=== 7. duplicates by display_name ==='
$PSQL -c "select display_name, count(*) from providers
          group by 1 having count(*) > 1;" 2>&1

echo '=== 8. what the admin dashboard function reports ==='
$PSQL -c "select * from admin_dashboard();" 2>&1 | head -20
echo '=== DONE ==='
