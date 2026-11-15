# 마사지사 첫 번째 사진이 아직 유니폼으로 안 바뀐 사람을 찾아 uniform-transform 으로 바꾸고 DB 사진 주소를 교체한다
# VPS /root/massa/uniform_backfill.py — 크론 매시 17분. 가입 때 변환이 실패(예: Gemini 크레딧 소진)해도 여기서 다시 한다.
# Gemini 가 402(크레딧 소진)를 주면 바로 멈춘다. 원본 파일은 저장소에 그대로 남는다(<원본>_uniform.png 를 새로 만든다).
import json, re, subprocess, sys, urllib.error, urllib.request

ENV = dict(l.split("=", 1) for l in open("/root/massa/.env").read().splitlines() if "=" in l and not l.startswith("#"))
KEY = ENV["SERVICE_ROLE_KEY"]
FN = "http://127.0.0.1:%s/functions/v1/uniform-transform" % ENV.get("KONG_HTTP_PORT", "8000")
DRY = "--dry" in sys.argv


def psql(sql):
    p = subprocess.run(["docker", "exec", "-i", "massa-db", "psql", "-U", "postgres", "-d", "postgres",
                        "-At", "-F", "\t", "-v", "ON_ERROR_STOP=1"], input=sql, text=True, capture_output=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return [l.split("\t") for l in p.stdout.splitlines() if l]


rows = psql("select id, photo_urls[1] from public.providers "
            "where kind = 'masseur' and photo_urls[1] is not null and photo_urls[1] not like '%\\_uniform.png%' order by created_at;")  # 끝의 ?v= 도 허용
print("대상", len(rows))
done = 0
for pid, url in rows:
    base = url.split("?")[0]  # 일부 주소는 캐시용 ?v= 가 붙어 있다
    m = re.search(r"/object/public/provider-photos/(.+)$", base)
    if not m:
        print("주소 형식 다름", pid, url); continue
    path = m.group(1)
    if DRY:
        print("대상", pid, path); continue
    req = urllib.request.Request(FN, data=json.dumps({"bucket": "provider-photos", "path": path}).encode(),
                                 headers={"Authorization": "Bearer " + KEY, "apikey": KEY, "Content-Type": "application/json"})
    try:
        body = json.load(urllib.request.urlopen(req, timeout=120))
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        print("실패", pid, e.code, detail[:300])
        if "RESOURCE_EXHAUSTED" in detail or "credits" in detail:
            print("Gemini 크레딧 소진 — 중단"); break
        continue
    if not body.get("url"):
        print("실패", pid, body); continue
    new = re.sub(r"\.[A-Za-z0-9]+$", "", base) + "_uniform.png"  # 함수가 돌려주는 주소는 내부 주소라 원래 주소에서 만든다
    if urllib.request.urlopen(urllib.request.Request(new, method="HEAD"), timeout=30).status != 200:
        print("새 파일 확인 실패", pid, new); continue
    psql("update public.providers set photo_urls[1] = '%s', "
         "photo_url = case when photo_url = '%s' then '%s' else photo_url end where id = '%s';" % (new, url, new, pid))
    done += 1
    print("교체", pid)
print("교체 완료", done)
