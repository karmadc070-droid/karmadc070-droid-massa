# store_installs 표를 만들고 admin_dashboard 에 스토어 설치 수(installs)를 더하는 일회용 패치 — VPS 에서 python3 로 돈다 (2026-11-15)
import subprocess, time
ts = time.strftime("%Y%m%d%H%M")


def psql(sql=None, inp=None):
    cmd = ["docker", "exec", "-i", "massa-db", "psql", "-U", "postgres", "-d", "postgres", "-At", "-v", "ON_ERROR_STOP=1"]
    p = subprocess.run(cmd + (["-c", sql] if sql else []), input=inp, capture_output=True, text=True)
    if p.returncode:
        raise SystemExit(p.stderr)
    return p.stdout


psql(inp="""
create table if not exists public.store_installs (
  day        date not null,
  store      text not null check (store in ('play','apple')),
  installs   int  not null default 0,
  updated_at timestamptz not null default now(),
  primary key (day, store)
);
alter table public.store_installs enable row level security;
""")

old = psql("select pg_get_functiondef(p.oid) from pg_proc p where proname='admin_dashboard'")
open(f"/root/backups/admin_dashboard.bak-{ts}.sql", "w").write(old + ";\n")

s = old
for a, b in [
    # 1) 설치 수 CTE — 스토어 통계는 하노이 날짜가 아니라 스토어 기준 날짜다 (Play 는 태평양 시간)
    ("""  first_seen as (""",
     """  ins as (
    select date_trunc(tr, si.day::timestamp) as k, sum(si.installs)::int as installs
    from store_installs si where si.day >= tp::date group by 1
  ),
  first_seen as ("""),
    # 2) series 에 installs
    ("""             'fee',       coalesce(b.fee,      0)) order by bu.k), '[]'::jsonb) as j""",
     """             'fee',       coalesce(b.fee,      0),
             'installs',  coalesce(i.installs, 0)) order by bu.k), '[]'::jsonb) as j"""),
    ("""    left join bk  b on b.k = bu.k
  ),""",
     """    left join bk  b on b.k = bu.k
    left join ins i on i.k = bu.k
  ),"""),
    # 3) sums 에 installs
    ("""           sum(coalesce(b.fee,0))::bigint    as fee
    from win w""",
     """           sum(coalesce(b.fee,0))::bigint    as fee,
           sum(coalesce(i.installs,0))::int  as installs
    from win w"""),
    ("""    left join bk  b on b.k = w.k
    group by w.w""",
     """    left join bk  b on b.k = w.k
    left join ins i on i.k = w.k
    group by w.w"""),
    # 4) 스토어 통계가 어느 날까지 들어왔는지
    ("""    'top',      (select j from top),""",
     """    'top',      (select j from top),
    'installs_through', (select jsonb_object_agg(store, d) from
                          (select store, max(day) d from store_installs group by store) x),"""),
]:
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)
psql(inp=s + ";\n")
open("/root/admin_dashboard.installs.sql", "w").write(s + ";\n")
print("ok", ts)
