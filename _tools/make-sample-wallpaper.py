#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成仓库自带的示例壁纸 assets/sample-wallpaper.jpg（2560x1440）。

为什么仓库里要自带一张示例图：
  `bg.config.json` 需要一个**可复现**的默认值 —— 谁 clone 下来都能 `build` 出同一个
  产物，`verify-bg.sh` 才有意义。用户要换成自己的图只需要
  `python build_background.py set --image <自己的图> --install`。

画面元素是有意的：
  · 大范围低对比渐变 —— 用来暴露 JPEG 色带（banding）
  · 四个角的内嵌 L 形角标 —— 一眼看出 fit/position 是 cover 还是 stretch/tile
  · 一条斜向细亮线 —— 模糊参数（--blur）有没有生效，看它还利不利
"""

from __future__ import annotations

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "sample-wallpaper.jpg")

W, H = 2560, 1440
TOP = (11, 16, 32)
BOTTOM = (27, 42, 74)

# 柔光斑：(r, g, b, x, y, 半径)
BLOBS = [
    (40, 80, 180, 620, 420, 520),
    (92, 62, 200, 1900, 320, 560),
    (30, 120, 160, 1520, 1120, 600),
    (120, 70, 170, 300, 1120, 480),
    (60, 140, 200, 1180, 700, 420),
]


def main() -> int:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))

    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, g, b, cx, cy, rad in BLOBS:
        gd.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=(r, g, b))
    glow = glow.filter(ImageFilter.GaussianBlur(190))
    img = ImageChops.add(img, glow, scale=1.35)   # scale>1 = 压暗，避免糊成一片白

    # 斜向细亮线：模糊与否，一眼可辨
    streak = Image.new("RGB", (W, H), (0, 0, 0))
    sd = ImageDraw.Draw(streak)
    sd.line([(-100, 1060), (W + 100, 300)], fill=(70, 96, 150), width=3)
    sd.line([(-100, 1240), (W + 100, 700)], fill=(40, 60, 100), width=2)
    img = ImageChops.add(img, streak.filter(ImageFilter.GaussianBlur(1.2)))

    # 四角 L 形角标（内嵌 40px）：fit=cover/contain/stretch 的取景差异肉眼可判
    corner = ImageDraw.Draw(img)
    for x, y, dx, dy in ((40, 40, 1, 1), (W - 40, 40, -1, 1),
                         (40, H - 40, 1, -1), (W - 40, H - 40, -1, -1)):
        corner.line([(x, y), (x + dx * 120, y)], fill=(120, 150, 200), width=2)
        corner.line([(x, y), (x, y + dy * 120)], fill=(120, 150, 200), width=2)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "JPEG", quality=92, optimize=True, progressive=True)
    print("wrote %s  (%dx%d, %.1f KB)" % (OUT, W, H, os.path.getsize(OUT) / 1024.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
