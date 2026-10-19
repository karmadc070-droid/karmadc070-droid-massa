#!/bin/sh
# ASCII only. Did the new traffic-tile label land on the deployed admin page?
F=/srv/massaviet-web/admin/index.html
echo "=== deployed admin file ==="
ls -l "$F"
echo "=== the foot line (should carry units now) ==="
grep -n 'v_cust)}' "$F" | head -3
echo "=== table header for v_prov ==="
grep -n "k: 'v_prov'" "$F"
echo "=== over https, as the browser sees it ==="
curl -s "https://massaviet.com/admin/index.html" | grep -c 'v_cust)}.*\\xed\\x9a\\x8c' 2>/dev/null
curl -s "https://massaviet.com/admin/index.html" | grep -n 'v_cust)}' | head -2
echo "=== DONE ==="
