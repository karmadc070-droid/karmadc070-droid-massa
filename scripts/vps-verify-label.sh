#!/bin/sh
# ASCII only. Did the renamed column land on the deployed admin page?
F=/srv/massaviet-web/admin/index.html
echo "=== file ==="
ls -l "$F"
echo "=== new wording present? (expect 2+) ==="
grep -c '알림 받는 기기' "$F"
echo "=== old wording gone from the activity panel? ==="
grep -c '기기 없는 마사지사' "$F"
echo "=== the note line ==="
grep -o '알림이 닿지 않는 마사지사[^`]*' "$F" | head -1
echo "=== DONE ==="
