#!/bin/sh
# 어드민 콘솔에 커진 글자 크기가 실제로 배포됐는지 서버 파일로 확인한다
F=$(ls /srv/massaviet-site/admin/index.html 2>/dev/null || ls /srv/*/admin/index.html 2>/dev/null | head -1)
echo "대상 파일: $F"
[ -n "$F" ] || { echo '★ 어드민 파일을 못 찾음'; exit 1; }
echo '=== 커진 값이 들어갔는가 (전부 1 이어야 한다) ==='
for s in 'font-size:16px' 'collapse;font-size:14.5px' '.tbl th{font-size:12.5px' '.card h3{font-size:16.5px'; do
  printf '  %-34s ' "$s"; grep -c -- "$s" "$F" || true
done
echo '=== 옛 값이 남아 있는가 (전부 0 이어야 한다) ==='
for s in 'font-size:14.5px;line-height:1.6' 'collapse;font-size:13px' '.tbl th{font-size:11.5px'; do
  printf '  %-34s ' "$s"; grep -c -- "$s" "$F" || true
done
echo '=== 수정 시각 ==='
ls -l "$F" | sed 's/^/  /'
echo '=== DONE ==='
