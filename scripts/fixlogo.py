# 가슴 로고 글자를 지우고 "massa" 자수 글씨를 다시 그려 NN_final.png 를 만드는 스크립트
# 사용법: python fixlogo.py rNN x0 y0 x1 y1   (대략 상자, 0~1 비율. 상자 안의 어두운 글자만 찾아 지운다)
import sys, cv2, numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

n = sys.argv[1]
fx0, fy0, fx1, fy1 = map(float, sys.argv[2:6])
im = cv2.imread(f"{n}_orig.png")
h, w = im.shape[:2]
x0, y0, x1, y1 = int(fx0 * w), int(fy0 * h), int(fx1 * w), int(fy1 * h)
roi = im[y0:y1, x0:x1]
lab = cv2.cvtColor(roi, cv2.COLOR_BGR2LAB)
L = lab[:, :, 0].astype(np.float32)
bg = np.median(L)
dark = (L < bg - 35).astype(np.uint8) * 255
# 상자 테두리에 닿는 덩어리(V넥 트림·머리카락)는 글자가 아니므로 버린다
cnt, lbl, st, _ = cv2.connectedComponentsWithStats(dark)
rh, rw = dark.shape
for i in range(1, cnt):
    x, y, ww, hh, a = st[i]
    if x == 0 or y == 0 or x + ww >= rw or y + hh >= rh or a < 4:
        dark[lbl == i] = 0
ys, xs = np.nonzero(dark)
tx0, tx1, ty0, ty1 = xs.min(), xs.max(), ys.min(), ys.max()
px = roi[dark > 0].astype(np.float32)
ink = np.median(px[px.sum(1) <= np.percentile(px.sum(1), 30)], axis=0)  # 기존 글자의 진한 색(BGR)
mask = np.zeros((h, w), np.uint8)
mask[y0:y1, x0:x1] = cv2.dilate(dark, np.ones((5, 5), np.uint8), iterations=2)
out = cv2.inpaint(im, mask, 7, cv2.INPAINT_TELEA)
# 지운 자리에 원단 결(잡티)을 다시 입혀 매끈한 얼룩이 보이지 않게 한다
hp = roi.astype(np.float32) - cv2.GaussianBlur(roi, (0, 0), 2).astype(np.float32)
sig = hp[dark == 0].std(axis=0)
noise = np.random.normal(0, 1, (h, w, 1)).astype(np.float32) * sig.reshape(1, 1, 3)
m3 = (cv2.GaussianBlur(mask, (0, 0), 2).astype(np.float32) / 255)[:, :, None]
out = np.clip(out.astype(np.float32) + noise * m3, 0, 255).astype(np.uint8)

# 새 글씨: 기존 글자 상자 높이·가운데에 맞춘다
bw, bh = tx1 - tx0, ty1 - ty0
cxp, cyp = x0 + (tx0 + tx1) / 2, y0 + (ty0 + ty1) / 2
pil = Image.fromarray(cv2.cvtColor(out, cv2.COLOR_BGR2RGB))
FONT = r"C:\Windows\Fonts\georgia.ttf"
font_px = 100
f0 = ImageFont.truetype(FONT, font_px)
b0 = f0.getbbox("massa")
ang = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0  # 기울어진 글자면 각도(반시계 +)
span = bw / max(0.5, np.cos(np.radians(ang)))
font_px = max(10, int(100 * span * 0.85 / (b0[2] - b0[0])))  # 기존 글자 폭에 맞춘다
font = ImageFont.truetype(FONT, font_px)
l, t, r, b = font.getbbox("massa")
layer = Image.new("RGBA", pil.size, (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
color = (int(ink[2]), int(ink[1]), int(ink[0]), 255)
if ang:
    d.text((cxp - (r - l) / 2 - l, cyp - (b - t) / 2 - t), "massa", font=font, fill=color)
    layer = layer.rotate(ang, resample=Image.BICUBIC, center=(cxp, cyp))
else:
    d.text((cxp - (r - l) / 2 - l, y0 + ty1 - b), "massa", font=font, fill=color)  # 기존 글자 밑선에 맞춘다
layer = layer.filter(ImageFilter.GaussianBlur(0.4))
pil = Image.alpha_composite(pil.convert("RGBA"), layer).convert("RGB")
res = cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)
if w > 1080:
    res = cv2.resize(res, (1080, round(h * 1080 / w)), interpolation=cv2.INTER_AREA)
cv2.imwrite(f"{n}_final.png", res)
# 확인용: 원본/결과 로고 부분 확대
s = res.shape[1] / w
pad = 40
c0 = im[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad]
r0 = cv2.resize(res, (w, h))[max(0, y0 - pad):y1 + pad, max(0, x0 - pad):x1 + pad]
prev = np.vstack([c0, r0])
scale = 600 / prev.shape[1]
cv2.imwrite(f"fix_{n}.jpg", cv2.resize(prev, None, fx=scale, fy=scale))
print(n, "text box", tx0 + x0, ty0 + y0, tx1 + x0, ty1 + y0, "font", font_px)
