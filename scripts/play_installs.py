# Play Console 통계 버킷에서 massa 일별 설치 수(Daily User Installs)를 받아 massa DB store_installs 에 넣는다
# VPS /root/play/play_installs.py — 크론 하루 한 번. 서비스 계정 키 /root/play/sa.json (chmod 600)
import base64, csv, datetime, io, json, os, subprocess, tempfile, time, urllib.parse, urllib.request

KEY = "/root/play/sa.json"
BUCKET = "pubsite_prod_6224655638055994426"
PKG = "app.massa.hanoi"


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def sign(msg, pem):
    # google-auth 가 VPS 에 없어 JWT 를 openssl 로 서명한다. 키는 잠깐 600 임시 파일에 둔다.
    fd, path = tempfile.mkstemp()
    try:
        os.write(fd, pem.encode()); os.close(fd)
        return subprocess.run(["openssl", "dgst", "-sha256", "-sign", path],
                              input=msg, capture_output=True, check=True).stdout
    finally:
        os.remove(path)


def token():
    sa = json.load(open(KEY))
    now = int(time.time())
    head = b64(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": sa["client_email"], "aud": sa["token_uri"],
                           "scope": "https://www.googleapis.com/auth/devstorage.read_only",
                           "iat": now, "exp": now + 3600}).encode())
    jwt = f"{head}.{body}." + b64(sign(f"{head}.{body}".encode(), sa["private_key"]))
    data = urllib.parse.urlencode({"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                                   "assertion": jwt}).encode()
    return json.load(urllib.request.urlopen(sa["token_uri"], data))["access_token"]


def month_rows(tok, ym):
    name = f"stats/installs/installs_{PKG}_{ym}_overview.csv"
    url = f"https://storage.googleapis.com/storage/v1/b/{BUCKET}/o/{urllib.parse.quote(name, safe='')}?alt=media"
    try:
        raw = urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})).read()
    except urllib.error.HTTPError as e:
        if e.code == 404:  # 그 달 파일이 아직 없다 (월초)
            return []
        raise
    return [(r["Date"], int(r["Daily User Installs"] or 0))
            for r in csv.DictReader(io.StringIO(raw.decode("utf-16")))]


def main():
    tok = token()
    first = datetime.date.today().replace(day=1)
    prev = (first - datetime.timedelta(days=1)).replace(day=1)
    rows = month_rows(tok, prev.strftime("%Y%m")) + month_rows(tok, first.strftime("%Y%m"))
    if not rows:
        print("no rows"); return
    values = ",".join(f"('{d}','play',{n})" for d, n in rows)
    sql = (f"insert into public.store_installs(day, store, installs) values {values} "
           "on conflict (day, store) do update set installs = excluded.installs, updated_at = now();")
    subprocess.run(["docker", "exec", "-i", "massa-db", "psql", "-U", "postgres", "-d", "postgres",
                    "-v", "ON_ERROR_STOP=1", "-q"], input=sql, text=True, check=True)
    print(f"{datetime.datetime.now().isoformat()} play rows={len(rows)} last={rows[-1][0]}")


if __name__ == "__main__":
    main()
