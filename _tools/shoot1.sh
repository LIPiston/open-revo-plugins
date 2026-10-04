#!/usr/bin/env bash
# 单张无头截图（shots.sh 的按需版）。
# 用法: bash _tools/shoot1.sh <page> <name> <w> <h> <query> <skin_id|off> [deviceScaleFactor]
# 例: bash _tools/shoot1.sh preview-mini.html candA 410 610 "bare=1&notrans=1" skin-win10-dark 1.5
# 坑1: 本机 python 是 Windows 版，喂 MSYS 绝对路径 /d/... 会 FileNotFoundError → 一律 cygpath -w。
# 坑2: set -u 下空数组 "${extra[@]}" 在老 bash 会 unbound → 用 ${extra[@]+"${extra[@]}"}。
set -u
CH="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/_shots"; mkdir -p "$OUT"
# 被截图的页面必须就是本脚本所在的这棵树 —— 原先这里硬编码了另一棵镜像树的绝对路径，
# 结果是「改了 A 树、截了 B 树」。（cygpath 在 Git Bash 下可用；无 cygpath 时退回手工拼接。）
if command -v cygpath >/dev/null 2>&1; then _root_win="$(cygpath -m "$ROOT")"
else _root_win="$(printf '%s' "$ROOT" | sed 's|\\|/|g; s|^/\([A-Za-z]\)/|\1:/|')"; fi
BASE="file:///${_root_win#/}"
write="$(cygpath -w "$OUT/$2.png")"; prof="$(cygpath -w "$(mktemp -d)")"
extra=()
[ $# -ge 7 ] && extra=(--force-device-scale-factor="$7")
"$CH" --headless=new --disable-gpu --no-first-run --user-data-dir="$prof" --hide-scrollbars \
  --allow-file-access-from-files --virtual-time-budget=3000 --window-size="$3,$4" \
  ${extra[@]+"${extra[@]}"} --screenshot="$write" "$BASE/$1?$5#$6" >/dev/null 2>&1
python -c "
from PIL import Image
im = Image.open(r'$write'); print('$2.png', im.size)
"
