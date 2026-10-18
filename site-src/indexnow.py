# 배포 뒤 IndexNow(Bing 등)에 바뀐 주소만 알린다 — 옛 sitemap 과 새 sitemap 을 비교(새 주소·lastmod 변경). 사용법: python3 indexnow.py <옛 sitemap> <새 sitemap 이 있는 docroot> [--all]
import json, os, re, sys, urllib.request

HOST = "massaviet.com"

def parse(x):
    return {re.search(r"<loc>([^<]+)", u).group(1): (re.search(r"<lastmod>([^<]+)", u) or [None, ""])[1]
            for u in re.findall(r"<url>([\s\S]*?)</url>", x)}

def main():
    old_path, root = sys.argv[1], sys.argv[2]
    send_all = "--all" in sys.argv
    # 키는 docroot 의 <키>.txt (내용 = 파일 이름) — build.py 가 site-src/indexnow-key.txt 로 만든다
    key = next((f[:-4] for f in os.listdir(root) if re.fullmatch(r"[0-9a-f]{32}\.txt", f)
                and open(os.path.join(root, f)).read().strip() == f[:-4]), None)
    if not key:
        print("indexnow: no key"); return
    old = parse(open(old_path, encoding="utf-8").read()) if os.path.exists(old_path) else {}
    new = parse(open(os.path.join(root, "sitemap.xml"), encoding="utf-8").read())
    urls = [u for u, lm in new.items() if send_all or u not in old or old[u] != lm]
    if not urls:
        print("indexnow: no change"); return
    body = json.dumps({"host": HOST, "key": key, "keyLocation": f"https://{HOST}/{key}.txt", "urlList": urls}).encode()
    req = urllib.request.Request("https://api.indexnow.org/indexnow", data=body,
                                 headers={"Content-Type": "application/json; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            print(f"indexnow: {len(urls)} urls -> HTTP {r.status}")
    except Exception as e:   # 알림 실패로 배포를 실패시키지 않는다
        print(f"indexnow failed: {e}")

if __name__ == "__main__":
    main()
