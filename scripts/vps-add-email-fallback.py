# 푸시를 받을 기기가 없으면 메일로 대신 보낸다 — send-push 에 끼워 넣는 패치 (2026-10-19)
#
# 왜 — 10/19 첫 실제 예약이 마사지사에게 닿지 않았다. 기기가 0개라 10번 모두 버려졌고
# (push_result = 'no_device'), 손님은 그냥 기다렸다. 알림을 켤 때까지 메일이라도 가야 한다.
#
# ★ 재시도마다 보내면 한 건에 메일 10통이 간다. 첫 시도(push_tries <= 1)에만 보낸다.
import io, re, sys

P = "/root/massa/volumes/functions/send-push/index.ts"
src = io.open(P, encoding="utf-8").read()

if "emailFallback" in src:
    print("이미 들어가 있다 — 아무것도 하지 않는다"); sys.exit(0)

# 1) RESEND 키 읽기
old = 'const NOTIFY_SECRET = Deno.env.get("NOTIFY_SECRET") ?? "";'
assert old in src, "NOTIFY_SECRET 줄을 못 찾았다"
src = src.replace(old, old + '\nconst RESEND_KEY = Deno.env.get("RESEND_KEY") ?? "";'
                  '\nconst MAIL_FROM = "massa <massa@moahagwon.com>";', 1)

# 2) Noti 타입에 push_tries 추가
old = "type Noti = { id: string; user_id: string; title: string | null; body: string | null; kind: string; booking_id: string | null };"
assert old in src, "Noti 타입을 못 찾았다"
src = src.replace(old,
    "type Noti = { id: string; user_id: string; title: string | null; body: string | null; "
    "kind: string; booking_id: string | null; push_tries: number | null };", 1)

# 3) 메일 대체 함수
fn = '''
// 받을 기기가 없을 때 쓰는 마지막 수단. 베트남어로만 보낸다 — 마사지사는 전원 베트남 사람이다.
const MAIL_SUBJ: Record<string, string> = {
  booking_new: "massa — Có lịch đặt mới đang chờ bạn",
  approved: "massa — Đơn đăng ký của bạn đã được duyệt",
  notice: "massa — Thông báo",
  info: "massa — Thông báo",
};
async function emailFallback(db: any, n: Noti): Promise<boolean> {
  if (!RESEND_KEY) return false;
  try {
    const { data } = await db.auth.admin.getUserById(n.user_id);
    const to = data?.user?.email;
    if (!to) return false;
    const body = [
      n.body ?? "",
      "",
      "Mở ứng dụng: https://app.massaviet.com",
      "",
      "★ Bạn nhận email này vì tài khoản chưa bật thông báo.",
      "Hãy mở ứng dụng và bật thông báo — nếu không, đơn mới sẽ chuyển cho người khác.",
      "",
      "massa",
    ].join("\\n");
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${RESEND_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: MAIL_FROM,
        to: [to],
        subject: MAIL_SUBJ[n.kind] ?? "massa — Thông báo",
        text: body,
      }),
    });
    return r.ok;
  } catch (_e) { return false; }
}
'''
anchor = "Deno.serve(async (req) => {"
assert anchor in src, "Deno.serve 를 못 찾았다"
src = src.replace(anchor, fn + "\n" + anchor, 1)

# 4) 기기 없음 분기 교체
old = '''    if (!mine.length) {
      noDevice++;
      await db.from("notifications").update({ push_result: "no_device" }).eq("id", n.id);
      continue;
    }'''
assert old in src, "기기 없음 분기를 못 찾았다"
new = '''    if (!mine.length) {
      noDevice++;
      // 기기가 없으면 메일로 대신 보낸다. 재시도마다 보내면 스팸이 되므로 첫 시도에만.
      let res = "no_device";
      if ((n.push_tries ?? 1) <= 1 && ["booking_new", "approved", "notice", "info"].includes(n.kind)) {
        const ok = await emailFallback(db, n);
        if (ok) emailed++;
        res = ok ? "no_device+emailed" : "no_device+email_failed";
      }
      await db.from("notifications").update({ push_result: res }).eq("id", n.id);
      continue;
    }'''
src = src.replace(old, new, 1)

# 5) 카운터
old = "  let sent = 0, removed = 0, noDevice = 0;"
assert old in src, "카운터 줄을 못 찾았다"
src = src.replace(old, "  let sent = 0, removed = 0, noDevice = 0, emailed = 0;", 1)

old = 'return json({ ok: true, claimed: notis.length, sent, removed, noDevice, errors: errors.slice(0, 3) });'
assert old in src, "응답 줄을 못 찾았다"
src = src.replace(old,
    'return json({ ok: true, claimed: notis.length, sent, removed, noDevice, emailed, errors: errors.slice(0, 3) });', 1)

io.open(P, "w", encoding="utf-8").write(src)
print("패치 완료")
