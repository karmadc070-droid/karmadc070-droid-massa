#!/bin/sh
# ASCII only. Does the sender read FCM's reply, or does it call everything "sent"?
F=/root/massa/volumes/functions/send-push/index.ts
echo '=== fcm send block (180-235) ==='
sed -n '180,235p' "$F"
echo '=== result handling (290,330) ==='
sed -n '290,330p' "$F"
echo '=== DONE ==='
