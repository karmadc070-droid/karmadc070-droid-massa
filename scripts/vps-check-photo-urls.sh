#!/bin/sh
# ASCII only. Are photo_urls full http addresses, or storage paths needing a signed URL?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== shape of photo_url vs photo_urls ==='
$PSQL -c "select display_name,
                 left(photo_url, 60) as main,
                 left(photo_urls[1], 60) as first_gallery
          from providers
          where application_status='approved' and photo_urls is not null
          order by display_name limit 5;" 2>&1

echo '=== how many are plain http? ==='
$PSQL -c "select count(*) filter (where photo_url like 'http%')      as main_http,
                 count(*) filter (where photo_urls[1] like 'http%')  as gal_http,
                 count(*) filter (where photo_urls[1] is not null
                                   and photo_urls[1] not like 'http%') as gal_path
          from providers where application_status='approved';" 2>&1

echo '=== is the bucket public? ==='
$PSQL -c "select id, name, public from storage.buckets order by name;" 2>&1
echo '=== DONE ==='
