#!/bin/sh
# 홈뷰티(therapist) 가 한 명이라도 있는가 + 로그인한 계정이 관리자인가
docker exec massa-db psql -U postgres -d postgres -c "
select kind as 종류, application_status as 상태, count(*)
from providers group by 1,2 order by 1,2;"

docker exec massa-db psql -U postgres -d postgres -c "
select u.email, p.role as 역할
from profiles p join auth.users u on u.id = p.id
where p.role in ('admin','reviewer');"
