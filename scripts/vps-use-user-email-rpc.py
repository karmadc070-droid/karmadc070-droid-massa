# emailFallback 이 GoTrue 관리자 API 대신 user_email RPC 를 쓰게 바꾼다 (2026-10-19)
# ★ auth.admin.getUserById 는 "Database error loading user" 로 실패했다.
import io, sys
P = "/root/massa/volumes/functions/send-push/index.ts"
src = io.open(P, encoding="utf-8").read()

if "user_email" in src:
    print("이미 RPC 를 쓰고 있다"); sys.exit(0)

old = '''    const { data, error: ue } = await db.auth.admin.getUserById(n.user_id);
    if (ue) { console.error("메일실패: 사용자조회", ue.message); return false; }
    const to = data?.user?.email;
    if (!to) { console.error("메일실패: 메일주소 없음", n.user_id); return false; }'''
assert old in src, "getUserById 구간을 못 찾았다"
new = '''    const { data: to, error: ue } = await db.rpc("user_email", { p: n.user_id });
    if (ue) { console.error("메일실패: 사용자조회", ue.message); return false; }
    if (!to) { console.error("메일실패: 메일주소 없음", n.user_id); return false; }'''
src = src.replace(old, new, 1)
io.open(P, "w", encoding="utf-8").write(src)
print("RPC 로 교체 완료")
