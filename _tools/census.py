# 色彩普查：把 PNG 里的像素按「色相聚类」统计成色族占比。
#
# 为什么需要：README §7 的验收信号就是「面板里出现了几个色相族」。屏幕像素是唯一
# 不可争辩的物证 —— 模型看不到图，所以把图变成数字：
#   · 无彩色（背景 / 文字 / 灰度描边）不参与色族统计；
#   · 有彩色像素按色相做环形贪心聚类（容差 30°，跨 0°/360° 正确合并）；
#   · 每个色族给出加权平均色相、代表色、像素数与占比（占全图 / 占有彩色）。
#
# 基线（二色体系改造前，skin-win10-dark 真机 mini 抓图）：
#   青 4.86% / 蓝 2.61% / 橙红 1.43% / 绿 0.63% / 粉紫 0.30% / 黄 0.05%
# 改造目标：只剩「系统主题色」与「重要强调色」两个色族。
#
# 用法: python _tools/census.py _shots/mini-skin-win11-dark.png [...]
import sys
from PIL import Image

# Windows 控制台默认是 GBK，中文色名会变乱码 —— 强制标准输出走 UTF-8。
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

TOL = 30.0          # 色相聚类容差（度）
SAT_MIN = 0.10      # 低于此饱和度视为无彩色（灰底/白字/黑描边）
DELTA_MIN = 22      # 通道极差低于此值也视为无彩色（防止深灰被算成有色）

NAMES = [(15, '红'), (45, '橙'), (70, '黄'), (100, '黄绿'), (150, '绿'),
         (175, '青绿'), (195, '青'), (215, '蓝青'), (245, '蓝'), (270, '紫蓝'),
         (295, '紫'), (325, '品红'), (345, '玫红'), (360, '红')]


def hue_name(h):
    for edge, name in NAMES:
        if h <= edge:
            return name
    return '红'


def rgb2hsl(r, g, b):
    r, g, b = r / 255.0, g / 255.0, b / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    l = (mx + mn) / 2.0
    if d == 0:
        return 0.0, 0.0, l
    s = d / (1 - abs(2 * l - 1)) if abs(2 * l - 1) < 1 else 1.0
    if mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60.0, s, l


def cluster(bins):
    """bins: {整数色相度数: 像素数} —— 环形贪心聚类，返回 [(平均色相, 像素数), ...]"""
    live = {h: n for h, n in bins.items() if n > 0}
    out = []
    while live:
        seed = max(live, key=lambda k: live[k])
        members = [h for h in live
                   if min((h - seed) % 360, (seed - h) % 360) <= TOL]
        total = sum(live[h] for h in members)
        # 环形加权平均：先取相对 seed 的有符号偏差，避免 0°/360° 断裂
        num = den = 0.0
        for h in members:
            dev = ((h - seed + 180) % 360) - 180
            num += dev * live[h]
            den += live[h]
        mean = (seed + num / den) % 360.0
        out.append((mean, total))
        for h in members:
            del live[h]
    out.sort(key=lambda t: -t[1])
    return out


for path in sys.argv[1:]:
    try:
        im = Image.open(path).convert('RGB')
    except Exception as exc:                                  # noqa: BLE001
        print(f'{path}: 打不开 ({exc})')
        continue
    W, H = im.size
    px = im.load()
    total = W * H
    neutral = 0
    bins = {}
    quant = {}
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            q = (r >> 4 << 4, g >> 4 << 4, b >> 4 << 4)
            quant[q] = quant.get(q, 0) + 1
            h, s, l = rgb2hsl(r, g, b)
            if s < SAT_MIN or (max(r, g, b) - min(r, g, b)) < DELTA_MIN:
                neutral += 1
                continue
            bins[int(h)] = bins.get(int(h), 0) + 1
    chroma = total - neutral
    fams = cluster(bins)
    print(f'===== {path}  {W}x{H}  {total} px =====')
    print(f'  无色(背景/文字/灰度) {neutral:7d}  {neutral / total * 100:6.2f}%')
    print(f'  有色                 {chroma:7d}  {chroma / total * 100:6.2f}%')
    print(f'  色族数量 = {len(fams)}')
    for i, (h, n) in enumerate(fams):
        # 用该族出现最多的量化色当代表色（比平均色更接近肉眼所见）
        rep = None
        for (qr, qg, qb), qn in quant.items():
            cr, cg, cb = qr + 8, qg + 8, qb + 8
            if max(cr, cg, cb) - min(cr, cg, cb) < DELTA_MIN:
                continue
            qh, _qs, _ql = rgb2hsl(cr, cg, cb)
            if min((qh - h) % 360, (h - qh) % 360) <= TOL:
                if rep is None or qn > rep[1]:
                    rep = ((qr, qg, qb), qn)
        hexs = '#%02x%02x%02x' % rep[0] if rep else '-'
        print(f'  [{i}] 色相 {h:6.1f}° {hue_name(h):<3}  {n:7d} px'
              f'  占全图 {n / total * 100:6.2f}%  占有色 {n / max(1, chroma) * 100:6.2f}%'
              f'  代表色 {hexs}')
    print('  出现最多的 8 个量化色（>>4，含无色）:')
    for q, n in sorted(quant.items(), key=lambda t: -t[1])[:8]:
        # 注意：这里不能用 f-string —— 量化色是 RGB 三元组，得走 % 格式化，
        # 而 % 与 {} 混用会把结尾那个字面 % 当成转换符（incomplete format）。
        print('    #%02x%02x%02x  %7d  %6.2f%%'
              % (q[0], q[1], q[2], n, n / total * 100))
    print()
