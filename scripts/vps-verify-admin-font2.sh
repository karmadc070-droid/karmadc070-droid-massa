#!/bin/sh
# 2차 글자 크기 상향이 실제 배포본에 반영됐는지 확인
F=/srv/massaviet-web/admin/index.html
echo "대상: $F"
echo '=== 새 값 (전부 1) ==='
for s in 'font-size:17.5px' 'collapse;font-size:15.5px' '.tbl th{font-size:13.5px' '.top h1{font-size:29px' '.card h3{font-size:18px'; do
  printf '  %-34s %s\n' "$s" "$(grep -c -- "$s" "$F" 2>/dev/null || echo 0)"
done
echo '=== 옛 값 (전부 0) ==='
for s in 'var(--sans);font-size:16px' 'collapse;font-size:14.5px' '.tbl th{font-size:12.5px' '.top h1{font-size:27px'; do
  printf '  %-34s %s\n' "$s" "$(grep -c -- "$s" "$F" 2>/dev/null || echo 0)"
done
ls -l "$F" | sed 's/^/  /'
echo '=== DONE ==='
