# 손으로 만든 유니폼 사진을 마사지사 첫 사진으로 넣는다 — <원본>_uniform.png 로 저장소에 올리고 photo_urls[1]·photo_url 교체
# VPS 에서: python3 uniform_put.py <provider_id> <png 파일>  (Gemini 크레딧 없이 Gemini 웹으로 변환한 사진용, 2026-11-15)
import re, subprocess, sys, urllib.request

pid, src = sys.argv[1], sys.argv[2]
ENV = dict(l.split("=", 1) for l in open("/root/massa/.env").read().splitlines() if "=" in l and not l.startswith("#"))
KEY, PORT = ENV["SERVICE_ROLE_KEY"], ENV.get("KONG_HTTP_PORT", "8000")


def psql(sql):
    p = subprocess.run(["docker", "exec", "-i", "massa-db", "psql", "-U", "postgres", "-d", "postgres",
                        "-At", "-v", "ON_ERROR_STOP=1"], input=sql, text=True, capture_output=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return p.stdout.strip()


url = psql("select photo_urls[1] from public.providers where id = '%s';" % pid)
if not url:
    raise SystemExit("사진 없음")
base = url.split("?")[0]
path = re.search(r"/object/public/provider-photos/(.+)$", base).group(1)
redo = base.endswith("_uniform.png")  # 이미 유니폼 — 가슴 로고만 고친 사진으로 같은 자리를 덮어쓴다
new_path = path if redo else re.sub(r"\.[A-Za-z0-9]+$", "", path) + "_uniform.png"
req = urllib.request.Request("http://127.0.0.1:%s/storage/v1/object/provider-photos/%s" % (PORT, new_path),
                             data=open(src, "rb").read(), method="POST",
                             headers={"Authorization": "Bearer " + KEY, "apikey": KEY,
                                      "Content-Type": "image/png", "x-upsert": "true"})
urllib.request.urlopen(req, timeout=60).read()
new = base if redo else re.sub(r"\.[A-Za-z0-9]+$", "", base) + "_uniform.png"
if urllib.request.urlopen(urllib.request.Request(new, method="HEAD"), timeout=30).status != 200:
    raise SystemExit("공개 주소 확인 실패 " + new)
if redo:  # 주소가 같으면 앱·브라우저가 옛 사진을 캐시에서 보여 준다
    new += "?v=%d" % int(__import__("time").time())
psql("update public.providers set photo_urls[1] = '%s', "
     "photo_url = case when photo_url = '%s' then '%s' else photo_url end where id = '%s';" % (new, url, new, pid))
print("교체", pid, new)
