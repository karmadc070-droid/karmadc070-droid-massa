#!/bin/sh
# 마사지사 본인이 영업을 켤 때 나오는 오류 '문구'를 눈으로 확인한다
# (앞선 테스트에서 실패는 났는데 메시지가 stderr 로 새어 안 보였다 — 뭐 때문에 막혔는지 확인해야 한다)
docker exec -i massa-db psql -U postgres -d postgres 2>&1 <<'SQL'
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"c36cb967-552b-41b5-8e71-7b0f1d3c4382","role":"authenticated"}';
update providers set is_active=true where id='660cd0da-8007-4833-848f-1b54cecad1fc';
rollback;
SQL
