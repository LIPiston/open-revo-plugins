#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenRevo · Windows Fluent UI Skin —— 构建脚本
================================================
用法:
    python build_skins.py                # 仅生成到仓库根下的 skin-<id>/ 子目录项目
    python build_skins.py --install      # 生成并安装到 %APPDATA%\\OpenRevo\\plugins
    python build_skins.py --preview      # 仅重新生成 assets/preview.png

产物（每个皮肤 = 仓库根下的一个独立子目录项目，遵循手册用例 7 的皮肤工程目录规范）:
    <skin_id>/manifest.json
    <skin_id>/theme.css
    <skin_id>/assets/preview.png

设计要点:
  * theme.css = 令牌块(本脚本生成) + src/base.css(结构层，选择器以 [data-skin="<id>"] 命名空间隔离)
  * 令牌块同时覆写三套变量:
      1) 手册 §5/§8 记载的官方 Design Tokens (--core-accent / --surface-card / --radius-md ...)
      2) 从 open-revo.exe + WebView2 代码缓存中实测到的宿主运行期变量 (--accent-color / --text-dim / --theme-pwr* ...)
      3) 本皮肤私有变量 (--wf-*)，供结构层使用
  * 皮肤互斥 —— 四个皮肤各自独立安装，宿主插件面板中单选启用。

配色纪律（硬约束，四个变体一致）:
  整套 UI 只允许两个强调色，且职责不重叠：
    · 系统主题色 = VARIANTS["accent"]（即本变体对应的 Windows 系统强调色）
        负责一切「可交互 / 已选中 / 已开启」的强调：导航选中、开关、按钮、
        卡片标题、快捷开关激活、下拉选中、OSD、聚焦环。
    · 重要强调色 = VARIANTS["important"]（暖琥珀/橙，逐变体调过对比度）
        只用于「性能/功率」这一件最重要的事，以及真正需要用户注意的状态：
        mini「性能模式」卡片、狂暴模式按钮、功率徽标、需要接管的 OEM 服务状态。
    · --wf-ok / --wf-warn / --wf-error 仅表达真实状态语义（成功 / 警告 / 错误），
      不允许当作装饰色使用。
  历史教训：初版给 mini 六张卡片各配一个色相（橙/绿/紫/青/品红/黄），
  单张 410px 的面板里同时出现 6 个色相（真机取色统计：青 4.86% / 蓝 2.61% /
  橙红 1.43% / 绿 0.63% / 粉紫 0.30% / 黄 0.05%），观感碎、且与「系统主题色」
  这一概念互相打架。二色体系下 mini 只应出现 accent 与 important 两个色相族。
"""

import argparse
import json
import os
import shutil
import sys

# Windows 控制台默认 GBK，脚本里的中文提示会变乱码 —— 强制标准输出走 UTF-8。
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
# 每个皮肤就是仓库根下的一个子目录项目（skin-<winver>-<scheme>），不再套一层 dist/。
# 目录名即插件 id，宿主按 <id> 加载并挂 [data-skin="<id>"]。
SKINS_DIR = HERE
PLUGINS_DIR = os.path.join(
    os.environ.get("APPDATA", os.path.expanduser("~")), "OpenRevo", "plugins"
)

FONT_W11 = '"Segoe UI Variable Text", "Segoe UI Variable", "Segoe UI", system-ui, "Microsoft YaHei UI", sans-serif'
FONT_W11_NUM = '"Segoe UI Variable Display", "Segoe UI Variable", "Segoe UI", system-ui, "Microsoft YaHei UI", sans-serif'
FONT_W10 = '"Segoe UI", system-ui, "Microsoft YaHei UI", sans-serif'

# ---------------------------------------------------------------------------
# 皮肤变体表（四套，对应参考原型 Win10/Win11 × 浅色/深色）
# ---------------------------------------------------------------------------
VARIANTS = [
    dict(
        id="skin-win11-light",
        name="Windows 11 Fluent 浅色",
        family="win11",
        scheme="light",
        desc="Windows 11 Fluent Design 浅色主题：Mica 云母材质、8px 圆角、Segoe UI Variable 字体、#0067c0 系统强调色。",
        color_scheme="light",
        window_bg="rgba(243, 243, 243, .86)",
        bg="#f3f3f3",
        mica_1="rgba(0, 103, 192, .10)",
        mica_2="rgba(122, 92, 200, .08)",
        surface="rgba(255, 255, 255, .72)",
        surface_hover="rgba(255, 255, 255, .90)",
        surface_2="rgba(249, 249, 249, .62)",
        surface_3="rgba(240, 240, 240, .70)",
        control="rgba(255, 255, 255, .70)",
        control_hover="rgba(255, 255, 255, .94)",
        control_stroke="rgba(0, 0, 0, .07)",
        stroke="rgba(0, 0, 0, .06)",
        stroke_strong="rgba(0, 0, 0, .14)",
        window_stroke="rgba(255, 255, 255, .55)",
        titlebar="rgba(255, 255, 255, .50)",
        flyout="rgba(252, 252, 252, .88)",
        hover="rgba(0, 0, 0, .037)",
        press="rgba(0, 0, 0, .06)",
        text="#1c1b1f",
        text_2="#4a4650",
        text_3="#6b6572",
        text_4="#9a949f",
        scroll="rgba(0, 0, 0, .26)",
        scroll_hover="rgba(0, 0, 0, .42)",
        accent="#0067c0",
        accent_hover="#1b7ac8",
        accent_press="#005ba1",
        accent_soft="rgba(0, 103, 192, .10)",
        accent_soft_strong="rgba(0, 103, 192, .22)",
        accent_border="rgba(0, 103, 192, .30)",
        accent_strong="#004e8c",
        accent_shadow="rgba(0, 103, 192, .24)",
        on_accent="#ffffff",
        ok="#0f7b0f",
        ok_soft="rgba(15, 123, 15, .12)",
        ok_strong="#0a5c0a",
        info="#0067c0",
        info_soft="rgba(0, 103, 192, .12)",
        info_strong="#004e8c",
        warn="#9d5d00",
        warn_soft="rgba(157, 93, 0, .12)",
        error="#c42b1c",
        error_soft="rgba(196, 43, 28, .12)",
        error_strong="#9b1f13",
        shadow_1="0 1px 2px rgba(0, 0, 0, .05), 0 0 0 .5px rgba(0, 0, 0, .04)",
        shadow_2="0 2px 6px rgba(0, 0, 0, .10)",
        shadow_3="0 8px 28px rgba(0, 0, 0, .18)",
        radius_sm="4px",
        radius="4px",
        radius_lg="8px",
        radius_md_manual="8px",
        radius_lg_manual="12px",
        radius_window="0px",
        blur="30px",
        blur_soft="12px",
        font=FONT_W11,
        font_num=FONT_W11_NUM,
        # 二色强调体系（见文件头「配色纪律」）：
        #   系统主题色 = accent（本变体的 Windows 系统强调色）
        #   重要强调色 = important（性能/功率，以及「需要注意」的状态）
        important="#ca5010",
        important_strong="#8a3707",
        window_size=(1120, 800),
    ),
    dict(
        id="skin-win11-dark",
        name="Windows 11 Fluent 深色",
        family="win11",
        scheme="dark",
        desc="Windows 11 Fluent Design 深色主题：Mica 云母材质、8px 圆角、#60cdff 系统浅蓝强调色、暗色浮层。",
        color_scheme="dark",
        window_bg="rgba(32, 32, 32, .86)",
        bg="#202020",
        mica_1="rgba(96, 205, 255, .10)",
        mica_2="rgba(150, 120, 255, .08)",
        surface="rgba(255, 255, 255, .055)",
        surface_hover="rgba(255, 255, 255, .085)",
        surface_2="rgba(255, 255, 255, .04)",
        surface_3="rgba(255, 255, 255, .07)",
        control="rgba(255, 255, 255, .06)",
        control_hover="rgba(255, 255, 255, .095)",
        control_stroke="rgba(255, 255, 255, .09)",
        stroke="rgba(255, 255, 255, .09)",
        stroke_strong="rgba(255, 255, 255, .19)",
        window_stroke="rgba(255, 255, 255, .10)",
        titlebar="rgba(255, 255, 255, .035)",
        flyout="rgba(44, 44, 44, .92)",
        hover="rgba(255, 255, 255, .06)",
        press="rgba(255, 255, 255, .04)",
        text="#f4f0f5",
        text_2="#c9c5ce",
        text_3="#a9a4af",
        text_4="#7c7781",
        scroll="rgba(255, 255, 255, .28)",
        scroll_hover="rgba(255, 255, 255, .48)",
        accent="#60cdff",
        accent_hover="#7ad6ff",
        accent_press="#4db8e8",
        accent_soft="rgba(96, 205, 255, .14)",
        accent_soft_strong="rgba(96, 205, 255, .30)",
        accent_border="rgba(96, 205, 255, .36)",
        accent_strong="#8fdfff",
        accent_shadow="rgba(96, 205, 255, .22)",
        on_accent="#000000",
        ok="#6ccb5f",
        ok_soft="rgba(108, 203, 95, .16)",
        ok_strong="#8fe07f",
        info="#60cdff",
        info_soft="rgba(96, 205, 255, .16)",
        info_strong="#8fdfff",
        warn="#ffd166",
        warn_soft="rgba(255, 209, 102, .16)",
        error="#ff99a4",
        error_soft="rgba(255, 153, 164, .14)",
        error_strong="#ffb3bb",
        shadow_1="0 1px 2px rgba(0, 0, 0, .28)",
        shadow_2="0 2px 6px rgba(0, 0, 0, .34)",
        shadow_3="0 8px 28px rgba(0, 0, 0, .55)",
        radius_sm="4px",
        radius="4px",
        radius_lg="8px",
        radius_md_manual="8px",
        radius_lg_manual="12px",
        radius_window="0px",
        blur="30px",
        blur_soft="12px",
        font=FONT_W11,
        font_num=FONT_W11_NUM,
        important="#ff9d5c",
        important_strong="#ffc9a3",
        window_size=(1120, 800),
    ),
    dict(
        id="skin-win10-light",
        name="Windows 10 Fluent 浅色",
        family="win10",
        scheme="light",
        desc="Windows 10 Fluent Design 浅色主题：Acrylic 亚克力材质、2px 直角、Segoe UI 字体、#0078d4 系统强调色。",
        color_scheme="light",
        window_bg="rgba(243, 243, 243, .84)",
        bg="#f3f3f3",
        mica_1="rgba(0, 120, 212, .09)",
        mica_2="rgba(0, 120, 212, .04)",
        surface="rgba(255, 255, 255, .78)",
        surface_hover="rgba(255, 255, 255, .94)",
        surface_2="rgba(247, 247, 247, .70)",
        surface_3="rgba(237, 237, 237, .78)",
        control="rgba(255, 255, 255, .78)",
        control_hover="rgba(255, 255, 255, .96)",
        control_stroke="rgba(0, 0, 0, .10)",
        stroke="rgba(0, 0, 0, .10)",
        stroke_strong="rgba(0, 0, 0, .22)",
        window_stroke="rgba(255, 255, 255, .60)",
        titlebar="rgba(255, 255, 255, .62)",
        flyout="rgba(252, 252, 252, .92)",
        hover="rgba(0, 0, 0, .05)",
        press="rgba(0, 0, 0, .08)",
        text="#1b1b1b",
        text_2="#3d3d3d",
        text_3="#646464",
        text_4="#909090",
        scroll="rgba(0, 0, 0, .30)",
        scroll_hover="rgba(0, 0, 0, .46)",
        accent="#0078d4",
        accent_hover="#106ebe",
        accent_press="#005a9e",
        accent_soft="rgba(0, 120, 212, .10)",
        accent_soft_strong="rgba(0, 120, 212, .22)",
        accent_border="rgba(0, 120, 212, .32)",
        accent_strong="#004578",
        accent_shadow="rgba(0, 120, 212, .22)",
        on_accent="#ffffff",
        ok="#107c10",
        ok_soft="rgba(16, 124, 16, .12)",
        ok_strong="#0b5a0b",
        info="#0078d4",
        info_soft="rgba(0, 120, 212, .12)",
        info_strong="#004578",
        warn="#d83b01",
        warn_soft="rgba(216, 59, 1, .12)",
        error="#e81123",
        error_soft="rgba(232, 17, 35, .12)",
        error_strong="#a80000",
        shadow_1="0 1px 2px rgba(0, 0, 0, .08)",
        shadow_2="0 2px 6px rgba(0, 0, 0, .14)",
        shadow_3="0 8px 24px rgba(0, 0, 0, .22)",
        radius_sm="2px",
        radius="2px",
        radius_lg="2px",
        radius_md_manual="2px",
        radius_lg_manual="2px",
        radius_window="0px",
        blur="20px",
        blur_soft="8px",
        font=FONT_W10,
        font_num=FONT_W10,
        important="#d83b01",
        important_strong="#9c2a00",
        window_size=(1080, 780),
    ),
    dict(
        id="skin-win10-dark",
        name="Windows 10 Fluent 深色",
        family="win10",
        scheme="dark",
        desc="Windows 10 Fluent Design 深色主题：Acrylic 亚克力材质、2px 直角、#1683d8 系统强调色、暗色浮层。",
        color_scheme="dark",
        window_bg="rgba(32, 32, 32, .84)",
        bg="#202020",
        mica_1="rgba(22, 131, 216, .10)",
        mica_2="rgba(22, 131, 216, .05)",
        surface="rgba(255, 255, 255, .055)",
        surface_hover="rgba(255, 255, 255, .09)",
        surface_2="rgba(255, 255, 255, .04)",
        surface_3="rgba(255, 255, 255, .07)",
        control="rgba(255, 255, 255, .06)",
        control_hover="rgba(255, 255, 255, .10)",
        control_stroke="rgba(255, 255, 255, .10)",
        stroke="rgba(255, 255, 255, .10)",
        stroke_strong="rgba(255, 255, 255, .22)",
        window_stroke="rgba(255, 255, 255, .10)",
        titlebar="rgba(255, 255, 255, .03)",
        flyout="rgba(43, 43, 43, .94)",
        hover="rgba(255, 255, 255, .06)",
        press="rgba(255, 255, 255, .04)",
        text="#f5f5f5",
        text_2="#c8c8c8",
        text_3="#a6a6a6",
        text_4="#7a7a7a",
        scroll="rgba(255, 255, 255, .28)",
        scroll_hover="rgba(255, 255, 255, .48)",
        accent="#1683d8",
        accent_hover="#2b93e0",
        accent_press="#0f6cbd",
        accent_soft="rgba(22, 131, 216, .16)",
        accent_soft_strong="rgba(22, 131, 216, .32)",
        accent_border="rgba(22, 131, 216, .40)",
        accent_strong="#5aa9e6",
        accent_shadow="rgba(22, 131, 216, .24)",
        on_accent="#ffffff",
        ok="#6ccb5f",
        ok_soft="rgba(108, 203, 95, .16)",
        ok_strong="#8fe07f",
        info="#1683d8",
        info_soft="rgba(22, 131, 216, .18)",
        info_strong="#5aa9e6",
        warn="#ff8c00",
        warn_soft="rgba(255, 140, 0, .16)",
        error="#ff8a80",
        error_soft="rgba(255, 138, 128, .14)",
        error_strong="#ffb0a8",
        shadow_1="0 1px 2px rgba(0, 0, 0, .30)",
        shadow_2="0 2px 6px rgba(0, 0, 0, .36)",
        shadow_3="0 8px 24px rgba(0, 0, 0, .55)",
        radius_sm="2px",
        radius="2px",
        radius_lg="2px",
        radius_md_manual="2px",
        radius_lg_manual="2px",
        radius_window="0px",
        blur="20px",
        blur_soft="8px",
        font=FONT_W10,
        font_num=FONT_W10,
        important="#ff8c00",
        important_strong="#ffbe7a",
        window_size=(1080, 780),
    ),
]


def rgba(hex_color: str, alpha: float) -> str:
    """#rrggbb + alpha -> rgba(...) 字符串。"""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return "rgba(%d, %d, %d, %s)" % (r, g, b, ("%.3f" % alpha).rstrip("0").rstrip("."))


def token_block(v: dict) -> str:
    """生成皮肤令牌块：官方 Design Tokens + 宿主实测运行期变量 + 皮肤私有变量。"""
    L = []
    a = L.append

    def hue_block(key: str, value: str) -> None:
        """写一组色到宿主槽位 --theme-<key>{,-border,-dim,-glow}，并镜像到 --wf-hue-<key>*。

        为什么必须镜像：宿主在迷你面板的根元素 **自身** 上重新声明了整套 --theme-*
        （`.mini-drawer-root[data-theme=mono|cyber]`，特异性 (0,2,0)），元素本地声明
        永远胜过从祖先 [data-skin="…"] 继承下来的值。皮肤必须用
        `[data-skin="…"] .mini-drawer-root[data-theme]` (0,3,0) 在 mini 根上再声明一次，
        而那一处只能用皮肤私有变量名，否则会自引用。见 src/base.css 第 8.1 节。"""
        a("  --theme-%s: %s;" % (key, value))
        a("  --theme-%s-border: %s;" % (key, rgba(value, .40)))
        a("  --theme-%s-dim: %s;" % (key, rgba(value, .14)))
        a("  --theme-%s-glow: %s;" % (key, rgba(value, .30)))
        a("  --wf-hue-%s: %s;" % (key, value))
        a("  --wf-hue-%s-border: %s;" % (key, rgba(value, .40)))
        a("  --wf-hue-%s-dim: %s;" % (key, rgba(value, .14)))
        a("  --wf-hue-%s-glow: %s;" % (key, rgba(value, .30)))

    a('/* OpenRevo · Windows Fluent UI Skin · %s' % v["name"])
    a('   skin_id: %s  |  由 build_skins.py 生成，请勿手工编辑 theme.css' % v["id"])
    a('   生成源: src/base.css + VARIANTS["%s"] */' % v["id"])
    a('[data-skin="%s"] {' % v["id"])
    a("  color-scheme: %s;" % v["color_scheme"])
    a("")
    a("  /* ---------- 1. 官方 Design Tokens（手册 §5 用例 7 / §8）---------- */")
    a("  --core-accent: %s;" % v["accent"])
    a("  --core-glow: %s;" % v["accent_shadow"])
    a("  --surface-overlay: %s;" % v["flyout"])
    a("  --surface-card: %s;" % v["surface"])
    a("  --border-subtle: %s;" % v["stroke"])
    a("  --border-medium: %s;" % v["stroke"])
    a("  --border-highlight: %s;" % v["accent_border"])
    a("  --radius-md: %s;" % v["radius_md_manual"])
    a("  --radius-lg: %s;" % v["radius_lg_manual"])
    a("  --font-mech: %s;" % v["font"])
    a("  --status-ok: %s;" % v["ok"])
    a("  --status-info: %s;" % v["info"])
    a("  --status-warn: %s;" % v["warn"])
    a("  --status-error: %s;" % v["error"])
    a("  --color-beast: %s;" % v["error"])
    a("")
    a("  /* ---------- 2. 宿主运行期变量（实测自 open-revo.exe / WebView2 代码缓存）---------- */")
    a("  --accent-color: %s;" % v["accent"])
    # 宿主私有强调色族。宿主在 `:root,[data-theme=cyber]` 上声明了一套赛博彩虹，
    # 在 `[data-theme=mono]` 上又把它们全刷成白色；主控台的功率徽标
    # （.power-header-zap-badge → --accent-pwr）、防休眠组件（--accent-beast）、
    # 电池模式 radio（--accent-pwr/gpu/cool）直接读这些变量。
    # 皮肤在这里一次性归一，宿主自绘部件也一并对齐二色体系。
    for _acc_key, _acc_val in (("pwr", v["important"]), ("beast", v["important"]),
                               ("gpu", v["accent"]), ("cool", v["accent"]),
                               ("rgb", v["accent"]), ("lux", v["accent"])):
        a("  --accent-%s: %s;" % (_acc_key, _acc_val))
        a("  --accent-%s-dim: %s;" % (_acc_key, rgba(_acc_val, .14)))
        a("  --accent-%s-border: %s;" % (_acc_key, rgba(_acc_val, .40)))
        a("  --accent-%s-glow: %s;" % (_acc_key, rgba(_acc_val, .30)))
    a("  --color-brand: %s;" % v["accent"])
    a("  --color-office: %s;" % v["ok"])
    a("  --color-balance: %s;" % v["info"])
    a("  --color-beast: %s;" % v["error"])
    a("  --color-fan: %s;" % v["accent"])
    a("  --color-gold: %s;" % v["warn"])
    a("  --glow-color: %s;" % v["accent_shadow"])
    a("  --border-glow: %s;" % v["stroke"])
    a("  --surface-badge: %s;" % v["surface_2"])
    a("  --icon-bg: %s;" % v["surface_2"])
    a("  --icon-border: %s;" % v["stroke"])
    a("  --text-secondary: %s;" % v["text_2"])
    a("  --text-muted: %s;" % v["text_2"])
    a("  --text-dim: %s;" % v["text_3"])
    a("  --status-ok-dim: %s;" % v["ok_soft"])
    a("  --status-info-dim: %s;" % v["info_soft"])
    a("  --status-warn-dim: %s;" % v["warn_soft"])
    a("  --status-error-dim: %s;" % v["error_soft"])
    # ---- 二色强调体系 --------------------------------------------------------
    # 宿主 mini 面板用 var(--theme-{pwr,gpu,hz,lux,kbd,bat}) 给六张卡片（性能模式 /
    # 显卡模式 / 屏幕刷新率 / 屏幕亮度 / 键盘背光 / 电池健康）各染一个色相，这是整份 UI 里
    # 「拿一堆颜色做装饰」的唯一来源。收口后只剩两个层级：
    #   --theme-pwr（性能模式）= 重要强调色 —— 唯一保留的第二色
    #   --theme-其余五个       = 系统主题色 —— 与导航 / 开关 / 选中态同一个颜色
    hue_block("pwr", v["important"])
    for _hue_slot in ("gpu", "hz", "lux", "kbd", "bat"):
        hue_block(_hue_slot, v["accent"])
    a("")
    a("  /* ---------- 3. 皮肤私有变量 ---------- */")
    for k, val in (
        ("bg", v["bg"]), ("window-bg", v["window_bg"]), ("window-stroke", v["window_stroke"]),
        ("mica-1", v["mica_1"]), ("mica-2", v["mica_2"]),
        ("surface", v["surface"]), ("surface-hover", v["surface_hover"]),
        ("surface-2", v["surface_2"]), ("surface-3", v["surface_3"]),
        ("control", v["control"]), ("control-hover", v["control_hover"]),
        ("control-stroke", v["control_stroke"]), ("stroke", v["stroke"]),
        ("stroke-strong", v["stroke_strong"]), ("titlebar", v["titlebar"]),
        ("flyout", v["flyout"]), ("hover", v["hover"]), ("press", v["press"]),
        ("text", v["text"]), ("text-2", v["text_2"]), ("text-3", v["text_3"]), ("text-4", v["text_4"]),
        ("scroll", v["scroll"]), ("scroll-hover", v["scroll_hover"]),
        ("accent", v["accent"]), ("accent-hover", v["accent_hover"]), ("accent-press", v["accent_press"]),
        ("accent-soft", v["accent_soft"]), ("accent-soft-strong", v["accent_soft_strong"]),
        ("accent-border", v["accent_border"]), ("accent-strong", v["accent_strong"]),
        ("accent-shadow", v["accent_shadow"]), ("on-accent", v["on_accent"]),
        ("ok", v["ok"]), ("ok-soft", v["ok_soft"]), ("ok-strong", v["ok_strong"]),
        ("info", v["info"]), ("info-soft", v["info_soft"]), ("info-strong", v["info_strong"]),
        ("warn", v["warn"]), ("warn-soft", v["warn_soft"]),
        ("error", v["error"]), ("error-soft", v["error_soft"]), ("error-strong", v["error_strong"]),
        ("shadow-1", v["shadow_1"]), ("shadow-2", v["shadow_2"]), ("shadow-3", v["shadow_3"]),
        ("radius-sm", v["radius_sm"]), ("radius", v["radius"]), ("radius-lg", v["radius_lg"]),
        ("radius-window", v["radius_window"]), ("blur", v["blur"]), ("blur-soft", v["blur_soft"]),
        # 不透明侧栏底色：浅色方案略压暗、深色方案略提亮，均为实色系（不再依赖亚克力）
        ("sidebar-bg", "rgba(0, 0, 0, .04)" if v.get("scheme") == "light" else "rgba(255, 255, 255, .04)"),
        ("font", v["font"]), ("font-num", v["font_num"]),
    ):
        a("  --wf-%s: %s;" % (k, val))
    a("")
    a("  /* ---- 二色强调体系的语义别名 --------------------------------------------")
    a("     结构层只用 --wf-accent*（系统主题色）与 --wf-important*（重要强调色）两个名字，")
    a("     不再直接读 --wf-hue-* 色相槽位 —— 槽位是给宿主 --theme-* 用的接线端子。")
    a("     重要强调色与槽位 pwr 同源，因此只在这里做一次指针别名，避免两处写同一串色值。 */")
    a("  --wf-important: var(--wf-hue-pwr);")
    a("  --wf-important-soft: var(--wf-hue-pwr-dim);")
    a("  --wf-important-border: var(--wf-hue-pwr-border);")
    a("  --wf-important-glow: var(--wf-hue-pwr-glow);")
    a("  --wf-important-strong: %s;" % v["important_strong"])
    a("")
    a("  /* ---------- 4. 参考原型（build.py 变体）别名，便于原型页直接复用 ---------- */")
    a("  --bg: %s;" % v["bg"])
    a("  --surface: %s;" % v["surface"])
    a("  --surface2: %s;" % v["surface_2"])
    a("  --text: %s;" % v["text"])
    a("  --muted: %s;" % v["text_3"])
    a("  --border: %s;" % v["stroke"])
    a("  --accent: %s;" % v["accent"])
    a("  --accent-soft: %s;" % v["accent_soft"])
    a("  --success: %s;" % v["ok"])
    a("  --radius: %s;" % v["radius"])
    a("}")
    return "\n".join(L) + "\n"


def manifest(v: dict) -> dict:
    """生成 manifest.json。

    ⚠️ 类型字段的兼容处理：开发手册 §2/§7 规定字段名为 `plugin_type`，
    但随宿主一同发行的官方插件 eva01-core 用的是 `type`。
    两者必须都写，才能保证无论微内核读哪个键都能识别为皮肤插件
    （serde 默认忽略未知字段，多写一个别名没有副作用）。
    同理，window 下的 `alwaysOnTop` / `transparent` 也补上 camelCase 别名。
    """
    w, h = v["window_size"]
    return {
        "id": v["id"],
        "name": v["name"],
        "version": "1.0.0",
        "author": "OpenRevo Fluent Skin Kit",
        "description": v["desc"],
        # 手册字段名（§4 / §7）
        "plugin_type": "skin",
        # 官方样例 eva01-core 使用的别名
        "type": "skin",
        "theme_css": "theme.css",
        "window": {
            "width": w,
            "height": h,
            "resizable": True,
            "transparent": False,
            "alwaysOnTop": False,
        },
    }


def build_theme_css(v: dict, base_src: str) -> str:
    return token_block(v) + "\n" + base_src.replace("__SKIN_ID__", v["id"])


# ---------------------------------------------------------------------------
# 预览缩略图（assets/preview.png）—— 插件管理与文档展示用
# ---------------------------------------------------------------------------
def parse_color(value: str):
    """'#rrggbb' 或 'rgba(r, g, b, a)' -> (r, g, b, a255)。"""
    s = value.strip()
    if s.startswith("#"):
        h = s.lstrip("#")
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    if s.startswith("rgba"):
        parts = s[s.index("(") + 1: s.rindex(")")].split(",")
        r, g, b = (int(float(p)) for p in parts[:3])
        a = float(parts[3])
        return (r, g, b, int(round(a * 255)))
    if s.startswith("rgb"):
        parts = s[s.index("(") + 1: s.rindex(")")].split(",")
        r, g, b = (int(float(p)) for p in parts[:3])
        return (r, g, b, 255)
    raise ValueError("unsupported color: %r" % value)


def over(fg, bg):
    """fg over bg (both RGBA tuples) -> RGBA tuple."""
    a = fg[3] / 255.0
    return tuple(int(round(fg[i] * a + bg[i] * (1 - a))) for i in range(3)) + (255,)


def make_preview(v: dict, path: str, photo=None) -> None:
    """photo：与画布同尺寸（W*S × H*S）的 RGB 图（背景图 + 遮罩，已烘好）。

    给定时改成「照片打底 + 半透明 UI 层合成」，缩略图与实际皮肤一致；
    不给定时逐像素等同历史输出 —— 四套既有 preview.png 不受影响。
    """
    from PIL import Image, ImageDraw, ImageFont

    W, H, S = 640, 360, 2  # S = 超采样倍率
    photo_mode = photo is not None
    img = Image.new("RGBA" if photo_mode else "RGB", (W * S, H * S),
                    (0, 0, 0, 0) if photo_mode else (24, 24, 24))
    d = ImageDraw.Draw(img)

    def C(value, bg=(24, 24, 24)):
        if photo_mode:
            return parse_color(value)          # 保留 alpha，交由末尾合成
        return over(parse_color(value), bg + (255,)) if len(bg) == 3 else over(parse_color(value), bg)

    def CT(value):
        """标题栏用的实色三元组；photo 模式保留 alpha。"""
        r = C(value, bg[:3])
        return r if photo_mode else r[:3]

    bg = C(v["bg"])
    surface = C(v["surface"], bg[:3])
    surface2 = C(v["surface_2"], bg[:3])
    stroke = C(v["stroke"], bg[:3])
    text = C(v["text"], bg[:3])
    text3 = C(v["text_3"], bg[:3])
    accent = C(v["accent"], bg[:3])
    accent_soft = C(v["accent_soft"], surface[:3])

    def rr(box, r, fill=None, outline=None, width=1):
        d.rounded_rectangle([c * S for c in box], radius=r * S, fill=fill, outline=outline, width=width * S)

    if not photo_mode:
        d.rectangle([0, 0, W * S, H * S], fill=bg)
    # 主窗口
    rr((16, 14, W - 16, H - 14), 6, fill=surface, outline=stroke, width=1)
    # 标题栏
    title_h = 34
    d.rounded_rectangle([16 * S, 14 * S, (W - 16) * S, (14 + title_h) * S], radius=6 * S, fill=CT(v["titlebar"]))
    d.line([(16 * S, (14 + title_h) * S), ((W - 16) * S, (14 + title_h) * S)], fill=stroke, width=S)
    # 品牌徽标
    rr((26, 14 + 8, 26 + 18, 14 + 26), 4, fill=accent)
    # 顶部导航胶囊（第 3 个为选中态）
    nx = 62
    for i in range(7):
        w = 44
        active = i == 2
        rr((nx, 14 + 10, nx + w, 14 + 26), 4,
           fill=accent_soft if active else None,
           outline=accent if active else stroke, width=1)
        d.rectangle([(nx + 10) * S, (14 + 17) * S, (nx + w - 10) * S, (14 + 19) * S],
                    fill=accent if active else text3)
        nx += w + 6
    # 性能模式卡片
    my = 14 + title_h + 16
    mx = 32
    for i in range(4):
        w = 118
        active = i == 1
        rr((mx, my, mx + w, my + 52), int(v["radius"].rstrip("px")) + 2,
           fill=accent_soft if active else surface2,
           outline=accent if active else stroke, width=1)
        d.rectangle([(mx + 12) * S, (my + 14) * S, (mx + 52) * S, (my + 19) * S], fill=accent if active else text)
        d.rectangle([(mx + 12) * S, (my + 26) * S, (mx + w - 14) * S, (my + 30) * S], fill=text3)
        mx += w + 10
    # 指标卡片
    ky = my + 66
    kx = 32
    # 指标卡片：历史上是四个色相（橙 / 绿 / 紫 / 青），现在只有「性能」是重要强调色，
    # 其余三张与系统主题色同色 —— 预览图本身就是「二色体系」的证据。
    hues = [v["important"], v["accent"], v["accent"], v["accent"]]
    for i in range(4):
        w = 118
        rr((kx, ky, kx + w, ky + 62), int(v["radius"].rstrip("px")) + 2, fill=surface2, outline=stroke, width=1)
        d.rectangle([(kx + 12) * S, (ky + 14) * S, (kx + 30) * S, (ky + 18) * S], fill=C(hues[i], bg[:3]))
        d.rectangle([(kx + 12) * S, (ky + 26) * S, (kx + 74) * S, (ky + 42) * S], fill=text)
        d.rectangle([(kx + 12) * S, (ky + 48) * S, (kx + w - 14) * S, (ky + 52) * S], fill=text3)
        kx += w + 10
    # 强调色板
    sy = ky + 76
    sx = 32
    # 强调色板：左边两个是「二色强调体系」（系统主题色 + 重要强调色），
    # 右边三个是只表达真实状态的语义色（成功 / 警告 / 错误），不参与装饰。
    for c in (v["accent"], v["important"], v["ok"], v["warn"], v["error"]):
        rr((sx, sy, sx + 30, sy + 16), 3, fill=C(c, bg[:3]), outline=stroke, width=1)
        sx += 36
    # 文本标签
    font_cn = font_lat = font_small = None
    for cand, size, kind in (
        ("C:/Windows/Fonts/msyh.ttc", 17, "cn"),
        ("C:/Windows/Fonts/segoeui.ttf", 17, "lat"),
        ("C:/Windows/Fonts/msyh.ttc", 11, "sm"),
    ):
        try:
            f = ImageFont.truetype(cand, size * S)
        except Exception:
            continue
        if kind == "cn" and font_cn is None:
            font_cn = f
        elif kind == "lat" and font_lat is None:
            font_lat = f
        elif kind == "sm" and font_small is None:
            font_small = f
    if font_cn is None:
        font_cn = ImageFont.load_default()
    if font_small is None:
        font_small = font_cn
    d.text((62 * S, sy * S + 2 * S), v["name"] + "  ·  " + v["id"], font=font_cn, fill=text)
    d.text((32 * S, (sy + 26) * S), "plugin_type: skin   theme_css: theme.css   " +
           ("resizable" if True else ""), font=font_small, fill=text3)

    if photo_mode:
        # PIL 的 ImageDraw 是「直接写像素」而非 alpha 混合：UI 层必须画在独立透明
        # 画布上，最后一步再与照片合成，否则半透明填充会把照片整块替换掉。
        img = Image.alpha_composite(photo.convert("RGBA"), img)
    img = img.convert("RGB").resize((W, H), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="OpenRevo Windows Fluent UI Skin builder")
    ap.add_argument("--install", action="store_true", help="安装到 %%APPDATA%%\\OpenRevo\\plugins")
    ap.add_argument("--preview", action="store_true", help="仅重新生成预览图")
    args = ap.parse_args()

    with open(os.path.join(SRC, "base.css"), "r", encoding="utf-8") as fh:
        base_src = fh.read()
    if "__SKIN_ID__" not in base_src:
        print("!! src/base.css 缺少 __SKIN_ID__ 占位符", file=sys.stderr)
        return 2

    targets = []
    for v in VARIANTS:
        out_dir = os.path.join(SKINS_DIR, v["id"])
        os.makedirs(os.path.join(out_dir, "assets"), exist_ok=True)
        if args.preview:
            make_preview(v, os.path.join(out_dir, "assets", "preview.png"))
            print("  preview  -> %s" % os.path.join(out_dir, "assets", "preview.png"))
            continue
        with open(os.path.join(out_dir, "theme.css"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(build_theme_css(v, base_src))
        with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(manifest(v), fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        make_preview(v, os.path.join(out_dir, "assets", "preview.png"))
        css_kb = os.path.getsize(os.path.join(out_dir, "theme.css")) / 1024.0
        print("  build    -> %s/  (theme.css %.1f KB, %sx%s)" %
              (v["id"], css_kb, v["window_size"][0], v["window_size"][1]))
        targets.append(out_dir)

    if args.preview:
        return 0

    if args.install:
        os.makedirs(PLUGINS_DIR, exist_ok=True)
        for src_dir in targets:
            dst = os.path.join(PLUGINS_DIR, os.path.basename(src_dir))
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            shutil.copytree(src_dir, dst)
            print("  install  -> %s" % dst)
        print("\n已安装 %d 个皮肤插件，重启 OpenRevo 或点击【插件】页右上角刷新即可看到。" % len(targets))

    return 0


if __name__ == "__main__":
    sys.exit(main())
