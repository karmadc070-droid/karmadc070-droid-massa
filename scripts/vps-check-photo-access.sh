#!/bin/sh
# ASCII only. How many photos per therapist, and can the admin read photo_urls via PostgREST?
PSQL="docker exec massa-db psql -U postgres -d postgres"
AID=$($PSQL -At -c "select id from profiles where role='admin' limit 1;")

echo '=== photo counts ==='
$PSQL -c "select display_name,
                 (photo_url is not null) as has_main,
                 coalesce(array_length(photo_urls,1),0) as gallery,
                 coalesce(array_length(photo_urls_orig,1),0) as gallery_orig,
                 (video_url is not null) as has_video
          from providers where application_status='approved'
          order by 3 desc, display_name;" 2>&1

echo '=== RLS on providers ==='
$PSQL -c "select polname, cmd, qual::text
          from pg_policies p join pg_policy pol on pol.polname=p.policyname
          where p.tablename='providers' and p.cmd='SELECT';" 2>&1 | head -12
$PSQL -c "select policyname, cmd from pg_policies where tablename='providers';" 2>&1

echo '=== can an admin select photo_urls as authenticated? ==='
$PSQL -c "
begin;
set local role authenticated;
set local request.jwt.claims = '{\"sub\":\"$AID\",\"role\":\"authenticated\"}';
select display_name, coalesce(array_length(photo_urls,1),0) as n
from providers where application_status='approved' order by 2 desc limit 5;
rollback;" 2>&1
echo '=== DONE ==='
