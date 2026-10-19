#!/bin/sh
# ASCII only. What android options does the massa send-push edge function set?
F=/root/massa/volumes/functions/send-push/index.ts
echo "=== file: $F ==="
ls -l "$F" 2>&1
echo '=== channel / sound / android lines ==='
grep -n 'channel\|sound\|android\|notification' "$F" 2>&1 | head -40
echo '=== DONE ==='
