# emailFallback 이 왜 실패했는지 로그에 남긴다 (2026-10-19)
# ★ catch 로 조용히 false 를 돌려주고 있어서 'email_failed' 만 보이고 이유를 알 수 없었다.
import io, sys
P = "/root/massa/volumes/functions/send-push/index.ts"
src = io.open(P, encoding="utf-8").read()

if "메일실패:" in src:
    print("이미 로그가 들어가 있다"); sys.exit(0)

old = '''    const { data } = await db.auth.admin.getUserById(n.user_id);
    const to = data?.user?.email;
    if (!to) return false;'''
assert old in src, "getUserById 구간을 못 찾았다"
new = '''    const { data, error: ue } = await db.auth.admin.getUserById(n.user_id);
    if (ue) { console.error("메일실패: 사용자조회", ue.message); return false; }
    const to = data?.user?.email;
    if (!to) { console.error("메일실패: 메일주소 없음", n.user_id); return false; }'''
src = src.replace(old, new, 1)

old = '''    return r.ok;
  } catch (_e) { return false; }'''
assert old in src, "return r.ok 구간을 못 찾았다"
new = '''    if (!r.ok) console.error("메일실패: Resend", r.status, (await r.text()).slice(0, 300));
    return r.ok;
  } catch (e) { console.error("메일실패: 예외", String(e).slice(0, 300)); return false; }'''
src = src.replace(old, new, 1)

io.open(P, "w", encoding="utf-8").write(src)
print("로그 추가 완료")
