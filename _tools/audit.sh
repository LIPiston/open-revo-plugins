#!/usr/bin/env bash
# 无人值守样式审计：headless Chrome 打开 <PAGE>?audit=1#<skin_id>，
# dump-dom 后抽出 AT_AUDIT_BEGIN..AT_AUDIT_END 段落。
# 用法：
#   bash _tools/audit.sh [skin_id ...]                       主窗（preview.html）
#   PAGE=preview-mini.html bash _tools/audit.sh [skin_id ...]  迷你面板
#   不给 skin_id = 四个变体全跑
# 为什么需要：模型看不到图像，只能用「computedStyle 断言」代替肉眼验收。
#
# 两页的差别只在 URL：主窗用 ?allactive=1 额外把 .tab-gpu/.tab-sponsor/.tab-plugin-custom
# 都点亮，以便对宿主 mono 的 (0,4,0)+!important 选中态做对抗验证；
# 迷你面板没有 tab 概念，且 .m-quick-btn/.m-select-item 的 .active 在静态 DOM 里就已经写死。
set -u
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/_audit"; mkdir -p "$OUT"
# 被审计的页面必须就是本脚本所在的这棵树 —— 原先这里硬编码了另一棵镜像树的绝对路径，
# 结果是「改了 A 树、审计了 B 树」。（cygpath 在 Git Bash 下可用；无 cygpath 时退回手工拼接。）
if command -v cygpath >/dev/null 2>&1; then _root_win="$(cygpath -m "$ROOT")"
else _root_win="$(printf '%s' "$ROOT" | sed 's|\\|/|g; s|^/\([A-Za-z]\)/|\1:/|')"; fi
BASE="file:///${_root_win#/}"
PAGE="${PAGE:-preview.html}"
case "$PAGE" in
  *mini*) TAG="mini-"; QUERY="audit=1" ;;            # 迷你窗 410×610
  *)      TAG="";      QUERY="audit=1&allactive=1" ;; # 主窗 1120×800
esac
VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=(skin-win11-light skin-win11-dark skin-win10-light skin-win10-dark)
for v in "${VARIANTS[@]}"; do
  PROF="$(cygpath -w "$(mktemp -d)")"
  "$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$PROF" \
     --hide-scrollbars --virtual-time-budget=3000 --window-size=1240,900 \
     --allow-file-access-from-files \
     --dump-dom "$BASE/$PAGE?$QUERY#$v" > "$OUT/$TAG$v.dom.html" 2>/dev/null
  sed -n '/AT_AUDIT_BEGIN/,/AT_AUDIT_END/p' "$OUT/$TAG$v.dom.html" \
    | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g' > "$OUT/$TAG$v.audit.txt"
  echo "======== $TAG$v ========"
  cat "$OUT/$TAG$v.audit.txt"
done
