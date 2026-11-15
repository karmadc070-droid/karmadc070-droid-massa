# App Store Connect 판매 보고서(일별 SUMMARY)에서 massa 첫 다운로드 수를 받아 massa DB store_installs 에 넣는다
# VPS /root/play/apple_installs.py — 크론 하루 한 번. 키 /root/play/apple.p8 (chmod 600), 역할 '판매 및 보고'
import base64, csv, datetime, gzip, io, json, os, subprocess, tempfile, time, urllib.error, urllib.parse, urllib.request

KEY = "/root/play/apple.p8"
KEY_ID = "84N3CXLQGH"
ISSUER = "dfd368a4-ed50-4498-bd03-4e00997b2719"
VENDOR = "94707488"
APPLE_ID = "6804698319"          # massa
NEW_TYPES = {"1", "1F", "1T"}    # 유료·무료·범용 앱의 첫 다운로드 (업데이트 7, 재다운로드 3 은 제외)
DAYS = 10                        # 애플 일별 보고서는 하루 늦고 가끔 다시 나온다. 최근 며칠을 매번 다시 받는다


def b64(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def der_to_raw(der):
    # openssl 이 주는 ECDSA DER 서명(SEQUENCE{r,s})을 JWT 가 쓰는 r||s 64바이트로 바꾼다
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        n = der[i + 1]; v = der[i + 2:i + 2 + n]; i += 2 + n
        out += v.lstrip(b"\x00").rjust(32, b"\x00")
    return out


def token():
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}).encode())
    body = b64(json.dumps({"iss": ISSUER, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}).encode())
    msg = f"{head}.{body}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY], input=msg,
                         capture_output=True, check=True).stdout
    return f"{head}.{body}.{b64(der_to_raw(der))}"


def day_installs(tok, d):
    q = urllib.parse.urlencode({"filter[frequency]": "DAILY", "filter[reportType]": "SALES",
                                "filter[reportSubType]": "SUMMARY", "filter[vendorNumber]": VENDOR,
                                "filter[reportDate]": d.isoformat(), "filter[version]": "1_0"})
    req = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/salesReports?" + q,
                                 headers={"Authorization": f"Bearer {tok}", "Accept": "application/a-gzip"})
    try:
        raw = urllib.request.urlopen(req).read()
    except urllib.error.HTTPError as e:
        if e.code == 404:  # 그날 판매가 하나도 없거나 아직 안 나왔다
            return None
        raise
    rows = csv.DictReader(io.StringIO(gzip.decompress(raw).decode()), delimiter="\t")
    return sum(int(r["Units"]) for r in rows
               if r.get("Apple Identifier") == APPLE_ID and r.get("Product Type Identifier") in NEW_TYPES)


def main():
    tok = token()
    today = datetime.datetime.now(datetime.timezone.utc).date()
    rows = []
    for k in range(1, DAYS + 1):
        d = today - datetime.timedelta(days=k)
        n = day_installs(tok, d)
        if n is not None:
            rows.append((d.isoformat(), n))
    if not rows:
        print("no rows"); return
    values = ",".join(f"('{d}','apple',{n})" for d, n in rows)
    sql = (f"insert into public.store_installs(day, store, installs) values {values} "
           "on conflict (day, store) do update set installs = excluded.installs, updated_at = now();")
    subprocess.run(["docker", "exec", "-i", "massa-db", "psql", "-U", "postgres", "-d", "postgres",
                    "-v", "ON_ERROR_STOP=1", "-q"], input=sql, text=True, check=True)
    print(f"{datetime.datetime.now().isoformat()} apple rows={len(rows)} " + " ".join(f"{d}:{n}" for d, n in rows))


if __name__ == "__main__":
    main()
