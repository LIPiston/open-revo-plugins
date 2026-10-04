#!/usr/bin/env bash
# 变体截图：
#   _shots/<id>.png          —— ?bare=1 窗口填满视口，整张图就是窗口本体，用于「不透明」像素判据
#   _shots/preview-<id>.png  —— 常规整页截图（含棋盘格背景 + 皮肤切换条），供人眼看整体版式
#   _shots/<id>-probe.png    —— ?bgprobe=1 把底色换成纯品红，与上一张做差分（证明窗口不透明）
#   _shots/<id>-clean.png    —— ?nofix=1 关掉预览页自带夹具，供像素级色彩普查（_tools/census.py）用
#   _shots/mini-<id>.png / mini-preview-<id>.png / mini-<id>-probe.png —— 迷你面板（preview-mini.html，410×610）
set -u
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/_shots"; mkdir -p "$OUT"
# 被审计的页面必须就是本脚本所在的这棵树 —— 原先这里硬编码了另一棵镜像树的绝对路径，
# 结果是「改了 A 树、审计了 B 树」。（cygpath 在 Git Bash 下可用；无 cygpath 时退回手工拼接。）
if command -v cygpath >/dev/null 2>&1; then _root_win="$(cygpath -m "$ROOT")"
else _root_win="$(printf '%s' "$ROOT" | sed 's|\\|/|g; s|^/\([A-Za-z]\)/|\1:/|')"; fi
BASE="file:///${_root_win#/}"
shoot() { # page name w h query id
  local page="$1" name="$2" w="$3" h="$4" q="$5" id="$6" prof
  prof="$(cygpath -w "$(mktemp -d)")"
  "$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$prof" \
    --hide-scrollbars --allow-file-access-from-files --virtual-time-budget=3000 \
    --window-size="$w,$h" --screenshot="$(cygpath -w "$OUT/$name.png")" \
    "$BASE/$page?$q#$id" >/dev/null 2>&1
  echo "  $name.png  ($(stat -c%s "$OUT/$name.png") bytes)"
}
for spec in "skin-win11-light 1120 800" "skin-win11-dark 1120 800" \
            "skin-win10-light 1080 780" "skin-win10-dark 1080 780"; do
  set -- $spec
  shoot preview.html "$1" "$2" "$3" "bare=1&notrans=1" "$1"
  shoot preview.html "preview-$1" 1240 900 "notrans=1" "$1"
  # ?nofix=1 关掉预览页自带的夹具（SAFE MOCK 徽标 / 六色令牌探针卡）——
  # 像素级色彩普查只该统计「模拟的宿主界面」，夹具留下会多出假色族。
  shoot preview.html "$1-clean" "$2" "$3" "bare=1&notrans=1&nofix=1" "$1"
done

# 不透明度差分探针：同一变体、同一尺寸，只把页面底色换成纯品红再截一张。
for spec in "skin-win11-light 1120 800" "skin-win11-dark 1120 800" \
            "skin-win10-light 1080 780" "skin-win10-dark 1080 780"; do
  set -- $spec
  shoot preview.html "$1-probe" "$2" "$3" "bare=1&notrans=1&bgprobe=1" "$1"
done

# ---- 迷你面板（真机尺寸 410×610；高度在宿主里由 fit_mini_window_height 动态调整）----
for id in skin-win11-light skin-win11-dark skin-win10-light skin-win10-dark; do
  # 迷你面板的夹具（mono 主题按钮态 / OEM 运行态）本来就在 style="display:none" 的容器里，
  # 位图上不可见，所以不需要 -clean 版本。
  shoot preview-mini.html "mini-$id" 410 610 "bare=1&notrans=1" "$id"
  shoot preview-mini.html "mini-preview-$id" 520 800 "notrans=1" "$id"
done
for id in skin-win11-light skin-win11-dark skin-win10-light skin-win10-dark; do
  shoot preview-mini.html "mini-$id-probe" 410 610 "bare=1&notrans=1&bgprobe=1" "$id"
done
