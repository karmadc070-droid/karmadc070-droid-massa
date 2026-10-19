#!/bin/sh
# ASCII only. Is the activity panel actually in the deployed admin page?
F=/srv/massaviet-web/admin/index.html
echo "=== file ==="
ls -l "$F"
echo "=== expect: rpc call 1, section id 2 (nav + card), loader call 1 ==="
echo -n "  admin_provider_activity : "; grep -c "admin_provider_activity" "$F"
echo -n "  s-activity              : "; grep -c "s-activity" "$F"
echo -n "  loadActivity()          : "; grep -c "loadActivity()" "$F"
echo -n "  visit_days              : "; grep -c "visit_days" "$F"
echo "=== the new columns ==="
grep -n "앱 들어온 날" "$F" | head -2
echo "=== DONE ==="
