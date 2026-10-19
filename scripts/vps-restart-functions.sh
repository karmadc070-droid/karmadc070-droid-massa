#!/bin/sh
# ASCII only. Restart the massa edge-functions container so the channel change takes.
echo '=== massa containers ==='
docker ps --format '{{.Names}}' | grep -i massa
NAME=$(docker ps --format '{{.Names}}' | grep -i massa | grep -i 'function\|edge' | head -1)
echo "picked: $NAME"
[ -n "$NAME" ] && docker restart "$NAME" < /dev/null 2>&1 | tail -1
sleep 8
docker ps --format '{{.Names}} {{.Status}}' | grep -i massa
echo '=== DONE ==='
