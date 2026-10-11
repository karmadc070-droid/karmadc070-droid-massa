# 예약에 저장된 구글 place_id 로 성·프엉을 알아내 bookings.city_code / ward_code 를 채운다.
#
# 왜 구글에 묻나 — 베트남은 2025-07-01 에 성을 63→34 로 합치고 구(quận) 단계를 없앴다.
# 'Mỹ Đình' 처럼 사라진 이름이 많아 내 기억으로 맞추면 틀린다. 구글은 개편을 따라간다.
#
# 처음 보는 프엉은 regions 에 자동으로 넣는다 (좌표까지). 전국 3,321개를 미리 깔지 않고
# 실제로 쓰인 곳만 자라게 한다.
#
# ★ curl 이 아니라 IPv4 로 나가야 한다. 키에 IP 제한이 걸려 있고 VPS 는 기본 IPv6 다.

import json, re, subprocess, sys, unicodedata, urllib.request, socket

DRY = '--apply' not in sys.argv

# 키에 IP 제한이 걸려 있어 IPv4 로만 나가야 한다.
_orig = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: [x for x in _orig(*a, **k) if x[0] == socket.AF_INET]


def psql(sql):
    r = subprocess.run(
        ['docker', 'exec', '-i', 'massa-db', 'psql', '-U', 'postgres', '-d', 'postgres',
         '-t', '-A', '-F', '\x1f', '-c', sql],
        capture_output=True, text=True)
    if r.returncode:
        raise SystemExit('psql 실패 — ' + r.stderr.strip())
    return [ln.split('\x1f') for ln in r.stdout.strip().split('\n') if ln.strip()]


def norm(s):
    """성 이름 대조용. 'TP. Hồ Chí Minh' 과 'Thành phố Hồ Chí Minh' 을 같게 만든다."""
    s = unicodedata.normalize('NFD', (s or '').lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').replace('đ', 'd')
    s = re.sub(r'\b(thanh pho|tp\.?|tinh|province|city)\b', ' ', s)
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def slug(s):
    s = unicodedata.normalize('NFD', (s or '').lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn').replace('đ', 'd')
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


KEY = next((l.split('=', 1)[1].strip()
            for l in open('/root/massa/.env', encoding='utf-8')
            if l.startswith('GOOGLE_MAPS_KEY=')), None)
if not KEY:
    raise SystemExit('GOOGLE_MAPS_KEY 가 없다')


def place(pid):
    req = urllib.request.Request(
        f'https://places.googleapis.com/v1/places/{pid}?languageCode=vi',
        headers={'X-Goog-Api-Key': KEY,
                 'X-Goog-FieldMask': 'location,addressComponents'})
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.load(r)
    comp = {}
    for c in d.get('addressComponents', []):
        for t in c.get('types', []):
            comp.setdefault(t, c.get('longText'))
    return comp, d.get('location') or {}


# 성 대조표 — 정규화한 이름 → code
CITIES = {norm(v): c for c, v in psql("select code, name_vi from regions where level=1")}
WARDS = {c for (c,) in psql("select code from regions where level=2")}

rows = psql("""select id, booking_no, place_id, coalesce(address,'')
                 from bookings
                where place_id is not null and place_id <> '' and city_code is null""")
if not rows:
    print('채울 예약이 없다.')
    raise SystemExit

print(f"{'예약번호':<16} {'성':<10} {'프엉':<16} 비고")
done = 0
for bid, no, pid, addr in rows:
    try:
        comp, loc = place(pid)
    except Exception as e:
        print(f'{no:<16} {"-":<10} {"-":<16} 구글 호출 실패 — {e}')
        continue

    cname = comp.get('administrative_area_level_1')
    wname = comp.get('locality') or comp.get('administrative_area_level_2')
    ccode = CITIES.get(norm(cname))
    if not ccode:
        print(f'{no:<16} {"?":<10} {"-":<16} ★ 성 "{cname}" 을 34개 목록에서 못 찾음 — 건너뜀')
        continue

    wcode = None
    if wname:
        wcode = f'{ccode}.{slug(wname)}'
        if wcode not in WARDS:
            # 처음 보는 프엉 — 좌표와 함께 새로 넣는다
            if not DRY:
                psql(f"""insert into regions (code,parent_code,level,name_vi,name_ko,name_en,lat,lng,sort)
                         values ({q(wcode)},{q(ccode)},2,{q(wname)},{q(wname)},{q(wname)},
                                 {loc.get('latitude') or 'null'},{loc.get('longitude') or 'null'},99)
                         on conflict (code) do nothing""")
            WARDS.add(wcode)
            note = '프엉 새로 등록'
        else:
            note = ''
    else:
        note = '프엉 불명 — 성만'

    if not DRY:
        psql(f"update bookings set city_code={q(ccode)}, "
             f"ward_code={q(wcode) if wcode else 'null'} where id={q(bid)}")
    print(f'{no:<16} {ccode:<10} {(wcode or "-"):<16} {note}')
    done += 1

print()
print(f'{"[연습] 아무것도 바꾸지 않았다. 반영하려면 --apply" if DRY else f"{done}건 반영 완료"}')
