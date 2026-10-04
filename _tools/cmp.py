# 两张 PNG 的粗块差分：模型看不到图，只能靠数字判断「真机截图更像哪张候选渲染」。
# 用法: python _tools/cmp.py A.png B.png [块边长px]
import sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert('RGB')
b = Image.open(sys.argv[2]).convert('RGB')
bs = int(sys.argv[3]) if len(sys.argv) > 3 else 24
if a.size != b.size:
    b = b.resize(a.size, Image.LANCZOS)
W, H = a.size
diff = ImageChops.difference(a, b)
import statistics
px = diff.load(); ap = a.load(); bp = b.load()
tot = 0; n = 0
for y in range(H):
    for x in range(W):
        r, g, bl = px[x, y]; tot += (r + g + bl) / 3; n += 1
print(f'# {sys.argv[1]} vs {sys.argv[2]}  {W}x{H}  block={bs}')
print(f'MAE(all px) = {tot/n:.2f}   max block MAE 与分布见下')
rows = []
for by in range(0, H, bs):
    line = ''
    vals = []
    for bx in range(0, W, bs):
        s = c = 0
        for y in range(by, min(by + bs, H), 2):
            for x in range(bx, min(bx + bs, W), 2):
                r, g, bl = px[x, y]; s += (r + g + bl) / 3; c += 1
        v = s / max(1, c); vals.append(v)
        line += ' ' if v < 3 else ('.' if v < 8 else (':' if v < 16 else ('-' if v < 28 else ('=' if v < 45 else ('+' if v < 70 else ('*' if v < 110 else ('#' if v < 160 else '@')))))))
    rows.append((by, sum(vals) / len(vals), line))
for by, m, line in rows:
    print(f'y{by:4d} {m:6.1f} |{line}|')
# 每行平均差的峰值行（找差异最集中的水平带）
prof = []
for y in range(0, H, 4):
    s = 0
    for x in range(0, W, 3):
        r, g, bl = px[x, y]; s += (r + g + bl) / 3
    prof.append((s / (W // 3), y))
prof.sort(reverse=True)
print('top-6 差异行:', ', '.join(f'y{y}({v:.0f})' for v, y in prof[:6]))
