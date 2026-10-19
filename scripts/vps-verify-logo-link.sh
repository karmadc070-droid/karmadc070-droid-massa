#!/bin/sh
# 어드민 로고가 소개 홈 링크로 배포됐는지 확인
F=/srv/massaviet-web/admin/index.html
echo "대상: $F"
echo '=== 링크가 들어갔는가 (1 이어야 한다) ==='
printf '  a.logo + massaviet.com : '; grep -c 'class="logo" href="https://massaviet.com/"' "$F" || true
printf '  display:block 스타일   : '; grep -c 'nav.side .logo{display:block' "$F" || true
echo '=== 옛 div 가 남아 있는가 (0 이어야 한다) ==='
printf '  <div class="logo">     : '; grep -c '<div class="logo">' "$F" || true
echo '=== 해당 줄 ==='
grep -o 'class="logo"[^>]*>massa' "$F" | sed 's/^/  /'
ls -l "$F" | sed 's/^/  /'
echo '=== DONE ==='
