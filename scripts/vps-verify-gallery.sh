#!/bin/sh
# ASCII only. Did the photo gallery land on the deployed admin page?
F=/srv/massaviet-web/admin/index.html
echo "=== file ==="
ls -l "$F"
echo "=== expected: data-gal 3, loadPhotos 2, lbMove 4, lbPaint 4, PHOTOS 6 ==="
for k in data-gal loadPhotos lbMove lbPaint PHOTOS data-lbgo; do
  printf "  %-12s %s\n" "$k" "$(grep -c "$k" "$F")"
done
echo "=== the old single-image path must still be there (data-img) ==="
grep -c 'data-img=' "$F"
echo "=== DONE ==="
