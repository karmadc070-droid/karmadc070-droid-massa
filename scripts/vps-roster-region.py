# admin_provider_list 함수에 활동 지역 세 칸만 보탠다. 나머지 줄은 건드리지 않는다.
#
# ★ docker exec -i 는 stdin 을 끝까지 빨아들인다. 이 스크립트가 파이프로 실행되면
#   뒤쪽 명령이 통째로 사라진다. 그래서 psql 호출마다 입력을 명시적으로 준다.
import subprocess, sys

def psql(args, inp=None):
    return subprocess.run(
        ['docker', 'exec', '-i', 'massa-db', 'psql', '-U', 'postgres', '-d', 'postgres'] + args,
        input=(inp or ''), capture_output=True, text=True)

r = psql(['-t', '-A', '-c',
          "select pg_get_functiondef(p.oid) from pg_proc p "
          "join pg_namespace n on n.oid=p.pronamespace "
          "where n.nspname='public' and p.proname='admin_provider_list';"])
src = r.stdout.strip()
if not src.startswith('CREATE OR REPLACE FUNCTION'):
    sys.exit('함수 정의를 못 읽었다 — ' + r.stderr.strip()[:200])
if 'city_name' in src:
    sys.exit('이미 들어가 있다 — 할 일 없음')

anchor = "pr.rating, pr.review_count, pr.base_district as district,"
if src.count(anchor) != 1:
    sys.exit(f'기준 줄이 {src.count(anchor)}곳이다 — 1곳이어야 한다. 중단')

add = (anchor + "\n"
       "           pr.city_code,\n"
       "           (select r.name_ko from regions r where r.code = pr.city_code) as city_name,\n"
       "           (select string_agg(r.name_vi, ' · ' order by r.sort)\n"
       "              from regions r where r.code = any(pr.ward_codes)) as ward_names,")

out = psql(['-v', 'ON_ERROR_STOP=1'], src.replace(anchor, add, 1) + '\n')
print(out.stdout.strip() or out.stderr.strip())
if out.returncode:
    sys.exit('적용 실패')

chk = psql(['-t', '-A', '-c',
            "select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace "
            "where n.nspname='public' and p.proname='admin_provider_list' "
            "and pg_get_functiondef(p.oid) like '%city_name%';"])
print('확인 — city_name 포함 함수 수:', chk.stdout.strip(), '(1 이어야 한다)')
