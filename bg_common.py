#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OpenRevo 自定义背景 —— 共享层（配置 / 图片处理 / CSS 渲染）。

被 `build_background.py`（CLI）与 `_tools/verify-bg.sh` 的校验逻辑共同依赖；
不含任何副作用，import 它不会写盘。
"""

from __future__ import annotations

import base64
import io
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
BG_TEMPLATE = os.path.join(SRC, "background.css")
CONFIG_PATH = os.path.join(HERE, "bg.config.json")

# 派生皮肤的后缀：skin-win11-dark -> skin-win11-dark-bg
BG_SUFFIX = "-bg"

# 独立背景插件（不带动皮肤 UI）的固定 id
STANDALONE_ID = "bg-custom"

# 迷你窗 / 主窗两份规则块的裁剪标记（scope 用）
MARK_MAIN = ("/* __BG_MAIN_BEGIN__ */", "/* __BG_MAIN_END__ */")
MARK_MINI = ("/* __BG_MINI_BEGIN__ */", "/* __BG_MINI_END__ */")

# 单张图片编码进 theme.css 后的体积上限：theme.css 会被宿主整份读进内存再塞进
# <style>，所以不是「磁盘上的字节」，而是「DOM 里的字节 ×2」（文本 + CSSOM）。
# 4 MB 是个保守的门槛，超过就明确告警而不是默默产出一个卡启动的插件。
URI_BUDGET = 4 * 1024 * 1024

FIT = {
    # fit -> (background-size, background-repeat)
    "cover": ("cover", "no-repeat"),
    "contain": ("contain", "no-repeat"),
    "stretch": ("100% 100%", "no-repeat"),
    "tile": ("auto", "repeat"),
    "center": ("auto", "no-repeat"),
}

POSITIONS = {
    "center", "top", "bottom", "left", "right",
    "left top", "top left", "left bottom", "bottom left",
    "right top", "top right", "right bottom", "bottom right",
    "center top", "center bottom", "center left", "center right",
}

SCOPES = ("both", "main", "mini")

DEFAULT_CONFIG = {
    "enabled": False,
    "image": "",
    "fit": "cover",
    "position": "center",
    "overlay": 0.42,
    "overlay_color": "auto",
    "blur": 0,
    "max_width": 2560,
    "quality": 88,
    "scope": "both",
    "targets": [],
    "standalone": True,
}


# ---------------------------------------------------------------------------
# 颜色
# ---------------------------------------------------------------------------
def parse_color(value: str):
    """'#rgb' / '#rrggbb' / 'rgb(...)' / 'rgba(...)' -> (r, g, b, a255)。"""
    s = (value or "").strip()
    if s.startswith("#"):
        h = s.lstrip("#")
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        if len(h) not in (6, 8):
            raise ValueError("unsupported hex color: %r" % value)
        r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
        a = int(h[6:8], 16) if len(h) == 8 else 255
        return (r, g, b, a)
    if s.startswith("rgb"):
        parts = s[s.index("(") + 1: s.rindex(")")].replace("/", " ").replace(",", " ").split()
        r, g, b = (int(round(float(p))) for p in parts[:3])
        a = int(round(float(parts[3]) * 255)) if len(parts) > 3 else 255
        return (r, g, b, a)
    raise ValueError("unsupported color: %r" % value)


def luminance(value: str) -> float:
    """感知亮度 0..1（sRGB 权重），用来决定 'auto' 遮罩该压黑还是提白。"""
    r, g, b, _ = parse_color(value)
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def scrim_rgba(overlay, overlay_color: str, base_hex: str):
    """把遮罩解算成 (r, g, b, alpha 0..1)。CSS 与预览图共用同一套解算，不各写一份。"""
    a = 0.0 if overlay is None else float(overlay)
    a = min(1.0, max(0.0, a))
    color = (overlay_color or "auto").strip()
    if color.lower() in ("auto", ""):
        # 深色皮肤压黑、浅色皮肤提白：让皮肤自己的文字色继续保持可读对比
        color = "#000000" if luminance(base_hex) < 0.5 else "#ffffff"
    r, g, b, _ = parse_color(color)
    return (r, g, b, a)


def scrim_css(overlay, overlay_color: str, base_hex: str) -> str:
    """遮罩层：一个恒定色的 linear-gradient。

    为什么是 gradient 而不是 `background-color`：多重背景里只有 <image> 才能当
    层，颜色只能放最后一层。用两张同色渐变拼成一层，层数就恒为 2
    （遮罩 + 图片），验收断言不用为 overlay=0 开特例。
    """
    r, g, b, a = scrim_rgba(overlay, overlay_color, base_hex)
    one = "rgba(%d, %d, %d, %.3f)" % (r, g, b, a)
    return "linear-gradient(%s, %s)" % (one, one)


# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
def load_config(path: str = CONFIG_PATH) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as fh:
            cfg.update(json.load(fh) or {})
    return cfg


def save_config(cfg: dict, path: str = CONFIG_PATH) -> None:
    out = {k: cfg.get(k, v) for k, v in DEFAULT_CONFIG.items()}
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def validate_config(cfg: dict) -> None:
    """把非法参数挡在构建之前 —— 报错要指向字段名，别让人猜。"""
    if cfg.get("fit") not in FIT:
        raise ValueError("fit 必须是 %s 之一，收到 %r" % ("/".join(sorted(FIT)), cfg.get("fit")))
    pos = " ".join(str(cfg.get("position") or "center").lower().split())
    if pos not in POSITIONS:
        raise ValueError("position 不支持 %r（可用：%s）" % (cfg.get("position"), ", ".join(sorted(POSITIONS))))
    if str(cfg.get("scope") or "both") not in SCOPES:
        raise ValueError("scope 必须是 %s 之一" % "/".join(SCOPES))
    if cfg.get("overlay") is not None:
        float(cfg["overlay"])
    float(cfg.get("blur") or 0)
    int(cfg.get("max_width") or 0)
    int(cfg.get("quality") or 0)


# ---------------------------------------------------------------------------
# 图片
# ---------------------------------------------------------------------------
def render_image(path: str, cfg: dict) -> dict:
    """读取源图 -> EXIF 校正 -> 降采样 -> 可选高斯模糊 -> 编码 -> data URI。

    顺序是有意的：**先缩放再模糊**。模糊半径因此是「最终画布上的像素」，
    换个 max_width 得到的观感一致，而不是小图上一片糊、大图上没效果。
    """
    from PIL import Image, ImageFilter, ImageOps

    if not path or not os.path.isfile(path):
        raise FileNotFoundError("背景图不存在：%r" % path)

    im = Image.open(path)
    im = ImageOps.exif_transpose(im) or im  # 手机竖拍照片带 Orientation=6，不转就是躺着的
    src_size = im.size

    max_w = int(cfg.get("max_width") or 0)
    if max_w and im.width > max_w:
        im = im.resize((max_w, max(1, int(round(im.height * max_w / im.width)))), Image.LANCZOS)

    blur = float(cfg.get("blur") or 0)
    if blur > 0:
        im = im.filter(ImageFilter.GaussianBlur(blur))

    rgba = im.convert("RGBA")
    # getextrema()[0] 是 alpha 通道最小值：== 255 说明「格式带 alpha 但其实全不透明」
    transparent = rgba.getchannel("A").getextrema()[0] < 255

    buf = io.BytesIO()
    if transparent:
        rgba.save(buf, "PNG", optimize=True)
        mime, ext = "image/png", ".png"
    else:
        im.convert("RGB").save(buf, "JPEG", quality=int(cfg.get("quality") or 88),
                               optimize=True, progressive=True)
        mime, ext = "image/jpeg", ".jpg"

    data = buf.getvalue()
    uri = 'url("data:%s;base64,%s")' % (mime, base64.b64encode(data).decode("ascii"))
    return {
        "uri": uri,
        "mime": mime,
        "ext": ext,
        "data": data,
        "image": rgba,
        "out_size": im.size,
        "src_size": src_size,
        "oversize": len(uri) > URI_BUDGET,
    }


# ---------------------------------------------------------------------------
# CSS 渲染
# ---------------------------------------------------------------------------
def _cut_block(css: str, marks, keep: bool, note: str) -> str:
    begin, end = marks
    i = css.index(begin)
    j = css.index(end) + len(end)
    return (css[:i] + note + css[j:]) if not keep else (css[:i] + css[i + len(begin):j - len(end)] + css[j:])


def render_bg_css(skin_id: str, image: dict, cfg: dict, template: str | None = None) -> str:
    """把背景模板渲染成某个 skin id 的追加样式块。"""
    if template is None:
        with open(BG_TEMPLATE, "r", encoding="utf-8") as fh:
            template = fh.read()

    fit = cfg.get("fit") or "cover"
    size, repeat = FIT[fit]
    position = " ".join(str(cfg.get("position") or "center").lower().split())
    scope = str(cfg.get("scope") or "both")
    base = cfg.get("base_color") or "#0b0e14"

    out = template
    for token, value in (
        ("__BG_PHOTO__", image["uri"]),
        ("__BG_SCRIM__", scrim_css(cfg.get("overlay"), cfg.get("overlay_color"), base)),
        ("__BG_BASE__", base),
        ("__BG_SIZE__", size),
        ("__BG_POSITION__", position),
        ("__BG_REPEAT__", repeat),
        ("__SKIN_ID__", skin_id),
    ):
        out = out.replace(token, value)

    # scope=both 时只去掉标记，保留两份规则；否则整块抠掉并留下说明注释
    out = _cut_block(out, MARK_MAIN, scope in ("both", "main"),
                     "/* 主窗背景：本次 scope=%s，未注入 */\n" % scope)
    out = _cut_block(out, MARK_MINI, scope in ("both", "mini"),
                     "/* 迷你窗背景：本次 scope=%s，未注入 */\n" % scope)
    return out


def derived_outputs(image: dict, cfg: dict, variants: list) -> list:
    """算出这次要落盘的全部产物（纯函数，不写盘）。

    targets 里的每一项是一次「派生皮肤」：令牌块 + src/base.css + 背景块，
    原四套皮肤一个字节都不动，既有 132 条断言继续成立。
    """
    import build_skins  # 同目录，复用 token_block/manifest/build_theme_css，保证非背景部分逐字节一致

    with open(os.path.join(SRC, "base.css"), "r", encoding="utf-8") as fh:
        base_src = fh.read()

    by_id = {v["id"]: v for v in variants}
    targets = [t for t in (cfg.get("targets") or []) if t]
    for t in targets:
        if t not in by_id:
            raise ValueError("targets 里的 %r 不是已知皮肤 id（%s）" % (t, ", ".join(sorted(by_id))))

    out = []
    for tid in targets:
        base_v = by_id[tid]
        v = dict(base_v)
        v["id"] = tid + BG_SUFFIX
        v["name"] = base_v["name"] + " · 自定义背景"
        v["desc"] = ("在「%s」皮肤之上叠加用户自定义背景图（fit=%s, overlay=%s, scope=%s）；"
                     "由 build_background.py 生成。" % (base_v["name"], cfg.get("fit"),
                                                        cfg.get("overlay"), cfg.get("scope")))
        scfg = dict(cfg)
        scfg["base_color"] = base_v["bg"]  # 兜底底色 = 该变体的皮肤底色
        bg_css = render_bg_css(v["id"], image, scfg)
        theme = build_skins.build_theme_css(v, base_src) + "\n" + bg_css
        out.append({"dir": v["id"], "kind": "derived", "id": v["id"], "variant": v,
                    "theme_css": theme, "manifest": build_skins.manifest(v),
                    "base_variant": base_v})

    if cfg.get("standalone", True):
        v = {
            "id": STANDALONE_ID,
            "name": "自定义背景图",
            "desc": ("只提供背景图，不改动宿主默认界面（独立于任何皮肤）。"
                     "由 build_background.py 生成。"),
            "window_size": (1120, 800),
            "bg": "#0b0e14",   # 宿主 .acrylic-container 的底色 #0b0e14f0
        }
        scfg = dict(cfg)
        scfg["base_color"] = v["bg"]
        bg_css = render_bg_css(v["id"], image, scfg)
        out.append({"dir": v["id"], "kind": "standalone", "id": v["id"], "variant": v,
                    "theme_css": bg_css, "manifest": build_skins.manifest(v),
                    "base_variant": None})

    return out


def generated_dirs(variants: list, cfg: dict) -> list:
    """当前配置下应当存在的产物目录（含派生皮肤与独立插件）。"""
    dirs = [t + BG_SUFFIX for t in (cfg.get("targets") or []) if t]
    if cfg.get("standalone", True):
        dirs.append(STANDALONE_ID)
    return dirs


def all_generated_dirs(variants: list) -> list:
    """所有**可能**被本工具生成的目录 —— 关背景时用来做清扫，避免残留。"""
    return [v["id"] + BG_SUFFIX for v in variants] + [STANDALONE_ID]


def read_template() -> str:
    with open(BG_TEMPLATE, "r", encoding="utf-8") as fh:
        return fh.read()
