# 把 PNG 变成可读的 ASCII 灰度图（模型看不到图像，只能这样「看」版式）。
# 用法: python _tools/ascii.py <png> [cols] [rows]
import sys
from PIL import Image
p = sys.argv[1]
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 64
rows = int(sys.argv[3]) if len(sys.argv) > 3 else 0
im = Image.open(p).convert('RGB')
W, H = im.size
if not rows:
    rows = max(1, round(cols * H / W / 2.1))   # 字符宽高比 ~1:2.1
sm = im.resize((cols, rows), Image.BOX)
chars = ' .:-=+*#%@'
out = []
for y in range(rows):
    line = ''
    for x in range(cols):
        r, g, b = sm.getpixel((x, y))
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        line += chars[min(9, int(lum * 9.999))]
    out.append(line)
print(f'# {p}  {W}x{H} -> {cols}x{rows}')
print('\n'.join(out))
