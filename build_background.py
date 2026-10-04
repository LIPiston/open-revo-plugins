#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""OpenRevo 自定义背景图 —— 构建 / 安装 CLI。

    python build_background.py set --image D:\\pics\\wall.jpg [--fit cover] [--install]
    python build_background.py off   [--uninstall]
    python build_background.py build [--install]
    python build_background.py status
    python build_background.py install

为什么需要这一层（而不是在皮肤里直接写死图片路径）：
  宿主 exe 内**不存在**任何背景图 / 壁纸设置项（全字符串检索命中 0），config.json
  也没有对应键 —— 自定义背景只能走 skin 的 theme.css 注入。而 active_skin 是
  **单值**：独立做一套「背景皮肤」会顶掉用户当前的 Fluent 皮肤。所以本工具生成的是
  **派生皮肤** `<原id>-bg`（= 原皮肤令牌块 + src/base.css + 背景图层），
  既保留原皮肤全部观感又带上背景图；原四套皮肤目录与既有 132 条验收断言
  一个字节都不动。

产物（每个目标一份）：
    <id>-bg/{manifest.json, theme.css, assets/{background.<ext>, preview.png}}
    bg-custom/{...}                       ← 独立插件：只加背景，不动宿主默认 UI
`bg.config.json` 只记录源图路径与参数；每次构建都从源图重新编码，
所以调 blur / max_width / overlay 只需改参数重跑，不用手工搬 base64。
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import shutil
import sys

# 中文输出在 Windows 上是硬需求：Git Bash 的 stdout/stderr 默认绑到本地代码页（gbk），
# 而这里的提示与报错全是 UTF-8 中文 —— 不显式改流，用户看到的是「δ֪Ƥ�� id」这种乱码。
# 只改流，不动系统区域设置（PEP 540 的 UTF-8 模式会把子进程 I/O 也一起改，副作用太大）。
for _name in ("stdout", "stderr"):
    _s = getattr(sys, _name, None)
    if _s is not None and (getattr(_s, "encoding", "") or "").lower().replace("-", "") != "utf8":
        try:
            setattr(sys, _name, io.TextIOWrapper(_s.buffer, encoding="utf-8", errors="replace"))
        except (AttributeError, ValueError):
            pass

import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bg_common as bg          # noqa: E402
import build_skins as skins     # noqa: E402

STATUS_OK = "  ok  "
STATUS_NO = "  --  "


# ---------------------------------------------------------------------------
# 宿主侧
# ---------------------------------------------------------------------------
def host_config_path() -> str:
    return os.path.join(os.environ.get("APPDATA") or "", "OpenRevo", "config.json")


def host_active_skin():
    """读宿主的 active_skin。读不到不算错 —— 只是没法自动猜目标皮肤。"""
    path = host_config_path()
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return (json.load(fh) or {}).get("active_skin"), path
    except Exception:
        return None, path


def sha1(path: str) -> str:
    try:
        with open(path, "rb") as fh:
            return hashlib.sha1(fh.read()).hexdigest()[:12]
    except OSError:
        return "-"


def image_path(cfg: dict) -> str:
    """bg.config.json 里的 image 允许写相对路径 —— 一律相对仓库根解析。"""
    p = (cfg.get("image") or "").strip()
    if not p:
        return ""
    return p if os.path.isabs(p) else os.path.normpath(os.path.join(HERE, p))


def rel_image(p: str) -> str:
    """写进 bg.config.json 的路径：仓库内的图存相对路径。

    绝对路径会被写进一个提交进 git 的配置文件 —— 换台机器就失效，
    而图本身往往就在仓库里（assets/sample-wallpaper.jpg）。仓库外的图才保留绝对路径。
    """
    p = os.path.abspath(os.path.expanduser(p))
    rel = os.path.relpath(p, HERE)
    return rel.replace(os.sep, "/") if not rel.startswith("..") else p


def dir_state(path: str) -> str:
    tc = os.path.join(path, "theme.css")
    if not os.path.isfile(tc):
        return STATUS_NO
    return "%s theme.css %7.1f KB  sha1 %s" % (STATUS_OK, os.path.getsize(tc) / 1024.0, sha1(tc))


# ---------------------------------------------------------------------------
# 目标皮肤
# ---------------------------------------------------------------------------
def resolve_targets(spec: str, cfg: dict) -> list:
    """把 --targets 解析成「要派生哪些皮肤」的列表。

    `none` = 一个都不派生，只出独立插件 `bg-custom`，与任何皮肤零耦合（推荐口径）。
    """
    ids = [v["id"] for v in skins.VARIANTS]
    if spec in ("none", "-", "无"):
        return []
    if spec == "all":
        return list(ids)
    if spec:
        picked = [s.strip() for s in spec.split(",") if s.strip()]
    else:
        # 留空 = 沿用配置里已有的选择，**不**去猜宿主 active_skin：
        # 独立插件是默认口径，重跑 set 改图不该把派生皮肤偷偷加回来。
        picked = [t for t in (cfg.get("targets") or []) if t]
    unknown = [p for p in picked if p not in ids]
    if unknown:
        raise SystemExit("!! 未知皮肤 id：%s（可用：none、all、或逗号分隔的皮肤 id）"
                         % ", ".join(unknown))
    return picked


# ---------------------------------------------------------------------------
# 预览缩略图：把背景图按 cover 裁到画布并压上遮罩
# ---------------------------------------------------------------------------
def photo_layer(image, cfg: dict, size):
    from PIL import Image

    W, H = size
    im = image.convert("RGB")
    scale = max(W / im.width, H / im.height)
    nw = max(W, int(round(im.width * scale)))
    nh = max(H, int(round(im.height * scale)))
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - W) // 2, (nh - H) // 2
    im = im.crop((left, top, left + W, top + H))

    r, g, b, a = bg.scrim_rgba(cfg.get("overlay"), cfg.get("overlay_color"),
                               cfg.get("base_color") or "#0b0e14")
    if a > 0:
        im = Image.blend(im, Image.new("RGB", (W, H), (r, g, b)), a)
    return im


# ---------------------------------------------------------------------------
# 落盘
# ---------------------------------------------------------------------------
def emit(outputs: list, image: dict, cfg: dict, quiet=False) -> list:
    written = []
    for o in outputs:
        d = os.path.join(HERE, o["dir"])
        ad = os.path.join(d, "assets")
        os.makedirs(ad, exist_ok=True)

        with open(os.path.join(d, "theme.css"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(o["theme_css"])
        with open(os.path.join(d, "manifest.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(o["manifest"], fh, ensure_ascii=False, indent=2)
            fh.write("\n")

        # 烘进 theme.css 的那张图同时落盘为证据：assets/background.<ext> 所见即所得
        for old in ("background.jpg", "background.png"):
            p = os.path.join(ad, old)
            if os.path.isfile(p):
                os.remove(p)
        with open(os.path.join(ad, "background" + image["ext"]), "wb") as fh:
            fh.write(image["data"])

        # 缩略图与真实观感一致：派生皮肤走 make_preview 的 photo 合成路径
        prev = os.path.join(ad, "preview.png")
        if o["kind"] == "derived":
            lay = photo_layer(image["image"], {**cfg, "base_color": o["base_variant"]["bg"]}, (1280, 720))
            skins.make_preview(o["variant"], prev, photo=lay)
        else:
            photo_layer(image["image"], cfg, (640, 360)).save(prev, "PNG")

        kb = os.path.getsize(os.path.join(d, "theme.css")) / 1024.0
        written.append(o["dir"])
        if not quiet:
            print("  build    -> %s/  (theme.css %7.1f KB, %s)" % (o["dir"], kb, o["kind"]))
    return written


def remove_tree(path: str, uninstall: bool) -> bool:
    """删仓库里的产物目录；uninstall=True 时连插件目录里那份一起删。"""
    hit = False
    for root in (HERE, skins.PLUGINS_DIR) if uninstall else (HERE,):
        d = os.path.join(root, path)
        if os.path.isdir(d):
            shutil.rmtree(d)
            hit = True
    return hit


def guard_active(ids_to_remove: list, active, force: bool) -> bool:
    """拒绝删掉宿主正在使用的那个皮肤目录 —— 删了 config 就指向一个悬空 ID。

    不是「不能删」，是「不能这样删」：先切走再删，或者显式 --force 认账。
    """
    if active and active in ids_to_remove and not force:
        fallback = active[: -len(bg.BG_SUFFIX)] if active.endswith(bg.BG_SUFFIX) else "skin-win11-dark"
        print("!! 宿主 active_skin 正指向 %s，拒绝删除（删了 config 就是悬空 ID）。" % active)
        print("   先切回基础皮肤再删：")
        print("     powershell -ExecutionPolicy Bypass -File _tools\\set-active-skin.ps1 %s" % fallback)
        print("   确实要留着悬空 ID，就加 --force。")
        return False
    return True


# ---------------------------------------------------------------------------
# 子命令
# ---------------------------------------------------------------------------
def cmd_set(args) -> int:
    cfg = bg.load_config()
    cfg.update({
        "enabled": True,
        "image": rel_image(args.image),
        "scope": args.scope,
        "standalone": not args.no_standalone,
    })
    if args.fit:
        cfg["fit"] = args.fit
    if args.position:
        cfg["position"] = " ".join(args.position.lower().split())
    if args.overlay is not None:
        cfg["overlay"] = args.overlay
    if args.overlay_color:
        cfg["overlay_color"] = args.overlay_color
    if args.blur is not None:
        cfg["blur"] = args.blur
    if args.max_width:
        cfg["max_width"] = args.max_width
    if args.quality:
        cfg["quality"] = args.quality
    cfg["targets"] = resolve_targets(args.targets, {"targets": cfg.get("targets")})

    bg.validate_config(cfg)
    if not os.path.isfile(cfg["image"]):
        raise SystemExit("!! 背景图不存在：%s" % cfg["image"])

    bg.save_config(cfg)
    print("配置写入 %s" % bg.CONFIG_PATH)
    rc = cmd_build(args, cfg=cfg)
    if rc == 0 and args.activate:
        if cfg["targets"]:
            rc = activate(cfg["targets"][0] + bg.BG_SUFFIX)
        elif cfg.get("standalone", True):
            rc = activate(bg.STANDALONE_ID)
        else:
            print("!! 没有可激活的产物（既没选派生目标，也关了 standalone）")
    return rc


def cmd_off(args) -> int:
    cfg = bg.load_config()
    cfg["enabled"] = False
    bg.save_config(cfg)
    print("配置写入 %s（enabled=false）" % bg.CONFIG_PATH)

    active, _ = host_active_skin()
    stale = [d for d in bg.all_generated_dirs(skins.VARIANTS) if os.path.isdir(os.path.join(HERE, d))]
    if not guard_active(stale, active, args.force):
        return 3
    for d in bg.all_generated_dirs(skins.VARIANTS):
        where = []
        if os.path.isdir(os.path.join(HERE, d)):
            where.append("仓库")
        if args.uninstall and os.path.isdir(os.path.join(skins.PLUGINS_DIR, d)):
            where.append("插件目录")
        if not where:
            continue
        remove_tree(d, args.uninstall)
        print("  remove   -> %s  (%s)" % (d, " + ".join(where)))
    if stale:
        print("\n重启 OpenRevo 后背景插件才真正消失（宿主只在启动时枚举插件目录）：")
        print("  powershell -ExecutionPolicy Bypass -File _tools\\kill-and-start.ps1")
    return 0


def cmd_build(args, cfg=None) -> int:
    cfg = cfg or bg.load_config()
    if not cfg.get("enabled"):
        print("背景未启用。先：python build_background.py set --image <图>")
        return 0

    bg.validate_config(cfg)
    src = image_path(cfg)
    if not os.path.isfile(src):
        raise SystemExit("!! bg.config.json 里的源图不存在：%r" % (src or cfg.get("image")))

    image = bg.render_image(src, cfg)
    if image["oversize"]:
        print("!! 警告：编码后 %.2f MB，超过 %.0f MB 预算。theme.css 会被宿主整份读入内存，"
              "\n   建议调小 --max-width / --quality 或加大 --blur。"
              % (len(image["uri"]) / 1048576.0, bg.URI_BUDGET / 1048576.0))
    print("源图   %s  %dx%d -> %dx%d  %s  %.2f MB  base64"
          % (os.path.basename(src), image["src_size"][0], image["src_size"][1],
             image["out_size"][0], image["out_size"][1], image["mime"], len(image["data"]) / 1048576.0))

    outputs = bg.derived_outputs(image, cfg, skins.VARIANTS)
    emit(outputs, image, cfg)

    # 清扫：改了 targets / 关了 standalone 之后，旧产物不该留在仓库里冒充现状
    wanted = {o["dir"] for o in outputs}
    stale = [d for d in bg.all_generated_dirs(skins.VARIANTS)
             if d not in wanted and os.path.isdir(os.path.join(HERE, d))]
    if stale and not guard_active(stale, host_active_skin()[0], args.force):
        return 3
    for d in stale:
        remove_tree(d, args.install)
        print("  stale    -> %s/ 已清理" % d)

    if args.install:
        os.makedirs(skins.PLUGINS_DIR, exist_ok=True)
        for o in outputs:
            src_dir = os.path.join(HERE, o["dir"])
            dst = os.path.join(skins.PLUGINS_DIR, o["dir"])
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            shutil.copytree(src_dir, dst)
            print("  install  -> %s" % dst)
        # 插件目录里的陈旧副本同样要清，否则旧背景插件还在生效
        for d in bg.all_generated_dirs(skins.VARIANTS):
            if d not in wanted:
                p = os.path.join(skins.PLUGINS_DIR, d)
                if os.path.isdir(p):
                    shutil.rmtree(p)
                    print("  stale    -> %s 已清理（插件目录）" % p)

    print("\n重启 OpenRevo 生效（宿主只在启动时枚举插件目录）：")
    print("  powershell -ExecutionPolicy Bypass -File _tools\\kill-and-start.ps1")
    return 0


def cmd_install(args) -> int:
    args.install = True
    return cmd_build(args)


def cmd_status(args) -> int:
    cfg = bg.load_config()
    active, cfg_path = host_active_skin()
    img = image_path(cfg)
    print("配置            : %s" % bg.CONFIG_PATH)
    print("启用            : %s" % ("是" if cfg.get("enabled") else "否（背景层不会注入）"))
    print("源图            : %s%s" % (img or "(未设置)",
                                     "" if (img and os.path.isfile(img)) else "   <- 不存在/未设置"))
    print("参数            : fit=%s  position=%s  overlay=%s  overlay_color=%s  blur=%s"
          % (cfg.get("fit"), cfg.get("position"), cfg.get("overlay"), cfg.get("overlay_color"), cfg.get("blur")))
    print("                  max_width=%s  quality=%s  scope=%s  standalone=%s"
          % (cfg.get("max_width"), cfg.get("quality"), cfg.get("scope"), cfg.get("standalone")))
    print("派生目标        : %s" % (", ".join(cfg.get("targets") or []) or "(无)"))
    print("宿主 active_skin: %s" % (active or "(读不到)"))
    print("宿主 config     : %s%s" % (cfg_path, "" if os.path.isfile(cfg_path) else "   <- 不存在"))
    print("宿主插件目录    : %s" % skins.PLUGINS_DIR)
    print("")
    print("产物（仓库 -> 插件目录，sha1 一致才算真的同步过）:")
    for d in bg.all_generated_dirs(skins.VARIANTS):
        repo = os.path.join(HERE, d)
        inst = os.path.join(skins.PLUGINS_DIR, d)
        r = dir_state(repo)
        i = dir_state(inst)
        mark = ""
        if os.path.isfile(os.path.join(repo, "theme.css")) and os.path.isfile(os.path.join(inst, "theme.css")):
            mark = "   同步一致" if sha1(os.path.join(repo, "theme.css")) == sha1(os.path.join(inst, "theme.css")) \
                else "   ⚠ 仓库与插件目录不一致（重新 --install）"
        print("  %-22s repo[%s]  installed[%s]%s" % (d, r.strip() or "--", i.strip() or "--", mark))
    return 0


def activate(skin_id: str) -> int:
    ps = os.path.join(HERE, "_tools", "set-active-skin.ps1")
    if not os.path.isfile(ps):
        print("!! 找不到 %s" % ps)
        return 4
    import subprocess
    cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", ps, skin_id]
    print("\n切换 active_skin -> %s（会停宿主、改配置、再启动；需要提权）" % skin_id)
    try:
        return subprocess.call(cmd)
    except Exception as exc:                                  # pragma: no cover
        print("!! 调用失败：%s" % exc)
        return 4


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="OpenRevo 自定义背景图构建器",
                                 formatter_class=argparse.RawDescriptionHelpFormatter,
                                 epilog=__doc__.split("产物（")[0].split("为什么")[0])
    sub = ap.add_subparsers(dest="cmd")

    p_set = sub.add_parser("set", help="启用并配置背景图（隐含 build）")
    p_set.add_argument("--image", required=True, help="源图路径（jpg/png/webp...）")
    p_set.add_argument("--fit", choices=sorted(bg.FIT), help="cover(默认)/contain/stretch/tile/center")
    p_set.add_argument("--position", help="center(默认)/top/bottom/left/right/left top/...")
    p_set.add_argument("--overlay", type=float, help="遮罩不透明度 0..1（默认 0.42）")
    p_set.add_argument("--overlay-color", help="auto(默认)/#rrggbb")
    p_set.add_argument("--blur", type=float, help="高斯模糊半径（像素，默认 0）")
    p_set.add_argument("--max-width", type=int, help="降采样上限宽度（默认 2560）")
    p_set.add_argument("--quality", type=int, help="JPEG 质量（默认 88）")
    p_set.add_argument("--scope", default="both", choices=list(bg.SCOPES), help="both(默认)/main/mini")
    p_set.add_argument("--targets", help="派生目标：`none`=只出独立插件（默认口径）｜all｜逗号分隔的皮肤 id｜留空 = 沿用 bg.config.json 里的现值")
    p_set.add_argument("--no-standalone", action="store_true", help="不生成独立的 bg-custom 插件")

    p_off = sub.add_parser("off", help="关闭背景并清理产物")
    p_build = sub.add_parser("build", help="按现有 bg.config.json 重建")
    sub.add_parser("install", help="把已生成的产物同步到 %%APPDATA%%\\OpenRevo\\plugins")
    sub.add_parser("status", help="打印配置 / 产物 / 宿主状态")

    for p in (p_set, p_off, p_build, sub.choices["install"]):
        p.add_argument("--install", action="store_true",
                       help="同步到 %%APPDATA%%\\OpenRevo\\plugins（off 时配合 --uninstall 才删插件目录那份）")
        p.add_argument("--uninstall", action="store_true", help="off 时连插件目录里的那份一起删")
        p.add_argument("--force", action="store_true", help="允许删除宿主 active_skin 指向的产物")
    p_set.add_argument("--activate", action="store_true",
                       help="构建后切 active_skin：有派生目标就切 <id>-bg，否则切 bg-custom")

    args = ap.parse_args()
    if not args.cmd:
        ap.print_help()
        return 1

    if args.cmd == "set":
        return cmd_set(args)
    if args.cmd == "off":
        return cmd_off(args)
    if args.cmd == "build":
        return cmd_build(args)
    if args.cmd == "install":
        return cmd_install(args)
    if args.cmd == "status":
        return cmd_status(args)
    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
