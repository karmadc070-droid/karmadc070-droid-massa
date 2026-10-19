#!/bin/sh
# ASCII only. Is there ANY booking history to build an accept-rate panel from?
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== live table ==='
$PSQL -c "select count(*) as rows,
                 count(*) filter (where accepted_at is not null) as accepted,
                 count(*) filter (where completed_at is not null) as completed,
                 min(created_at)::date as first, max(created_at)::date as last
          from bookings;" 2>&1

echo '=== backups ==='
$PSQL -c "select 'backup_20261015' t, count(*),
                 count(*) filter (where accepted_at is not null) as accepted,
                 min(created_at)::date as first, max(created_at)::date as last
          from bookings_backup_20261015
          union all
          select 'backup_20261015b', count(*),
                 count(*) filter (where accepted_at is not null),
                 min(created_at)::date, max(created_at)::date
          from bookings_backup_20261015b;" 2>&1

echo '=== if any history exists, what did it look like per provider ==='
$PSQL -c "select coalesce(p.display_name,'(unknown)') as masseur,
                 count(*) as got,
                 count(*) filter (where b.accepted_at is not null) as accepted,
                 count(*) filter (where b.completed_at is not null) as completed
          from bookings_backup_20261015 b
          left join providers p on p.id = b.provider_id
          group by 1 order by 2 desc limit 20;" 2>&1
echo '=== DONE ==='
