# 行/列亮度签名：把图压成 N 行的平均亮度条，便于用文本比较两张图的纵向版式节奏。
# 用法: python _tools/prof.py A.png [B.png ...] [--n 48]
import sys
from PIL import Image
args = [a for a in sys.argv[1:] if not a.startswith('--')]
n = 48
if '--n' in sys.argv: n = int(sys.argv[sys.argv.index('--n') + 1])
CH = ' .:-=+*#%@'
for p in args:
    im = Image.open(p).convert('RGB'); W, H = im.size
    g = im.convert('L')
    rowmean = [sum(g.crop((0, y, W, y + 1)).getdata()) / W for y in range(H)]
    colmean = [sum(g.crop((x, 0, x + 1, H)).getdata()) / H for x in range(W)]
    step = H / n
    rs = ''.join(CH[min(9, int(rowmean[min(H - 1, int(i * step + step / 2))] / 25.6))] for i in range(n))
    step = W / n
    cs = ''.join(CH[min(9, int(colmean[min(W - 1, int(i * step + step / 2))] / 25.6))] for i in range(n))
    print(f'{p}  {W}x{H}')
    print(f'  rows|{rs}|')
    print(f'  cols|{cs}|')
