#!/bin/sh
# 테스트에 필요한 값들 (services 칼럼 / 성·시 코드 / bookings 칼럼)
# ★ 한글을 SQL 문자열 안에 쓰지 않는다. 파이프로 흘려 넣으면 깨진다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== services columns ==='
$PSQL -c "select column_name, data_type from information_schema.columns
          where table_name='services' order by ordinal_position;" 2>&1

echo '=== services rows ==='
$PSQL -c "select * from services order by 1 limit 5;" 2>&1

echo '=== level 1 regions ==='
$PSQL -c "select code, name_en, lat, lng from regions where level=1 order by sort limit 8;" 2>&1

echo '=== providers columns ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='providers' order by ordinal_position;" 2>&1

echo '=== messages columns ==='
$PSQL -c "select column_name from information_schema.columns
          where table_name='messages' order by ordinal_position;" 2>&1
echo '=== DONE ==='
