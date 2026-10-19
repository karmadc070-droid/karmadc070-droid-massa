#!/bin/sh
# 운영 콘솔에 '알림 꺼짐' 표시가 실제로 배포됐는지 확인
# ★ 밖에서 curl 로 확인하면 안 된다 — /admin/* 는 구글 로그인 뒤에 있어서
#   로그인 페이지가 돌아오고, 0건으로 보여 엉뚱한 결론을 내게 된다 (실제로 그랬다).
F=/srv/massaviet-web/admin/console/index.html
echo "대상: $F"
ls -l "$F" | sed 's/^/  /'
for s in 'admin_push_status' '알림 꺼짐' "k:'nodev'"; do
  printf '  %-24s %s\n' "$s" "$(grep -c -- "$s" "$F")"
done
echo '=== DONE ==='
