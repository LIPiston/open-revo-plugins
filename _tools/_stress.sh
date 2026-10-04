#!/usr/bin/env bash
# 压测：并发跑 headless Chrome，把每次的审计段与「单跑参考」逐行 diff。
# 用法： PAGES=preview-mini.html:mini bash _tools/_stress.sh [N] [并发]
set -u
CHROME="${CHROME:-/c/Program Files/Google/Chrome/Application/chrome.exe}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-24}"; P="${2:-6}"
PAGE="${PAGES%%:*}"; TAG="${PAGES##*:}"
ROOTW="$(cygpath -m "$ROOT")"; BASE="file:///$ROOTW"
if [ "$TAG" = "mini" ]; then Q="audit=1"; else Q="audit=1&allactive=1"; fi
V="${VARIANT:-skin-win10-light}"
D="$ROOT/_audit/_stress_$TAG"; rm -rf "$D"; mkdir -p "$D"
U="$BASE/$PAGE?$Q#$V"
run_one() {  # $1=输出名
  local i="$1" PROF; PROF="$(cygpath -w "$(mktemp -d)")"
  "$CHROME" --headless=new --disable-gpu --no-first-run --user-data-dir="$PROF" \
    --hide-scrollbars --virtual-time-budget=3000 --window-size=1240,900 \
    --allow-file-access-from-files --dump-dom "$U" > "$D/$i.dom.html" 2>/dev/null
  sed -n '/AT_AUDIT_BEGIN/,/AT_AUDIT_END/p' "$D/$i.dom.html" \
    | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g' > "$D/$i.audit.txt"
  rm -rf "$PROF"
}
export -f run_one; export CHROME D U
run_one ref
seq 1 "$N" | xargs -P "$P" -I{} bash -c 'run_one {}'
bad=0
for i in $(seq 1 "$N"); do
  if ! diff -q "$D/ref.audit.txt" "$D/$i.audit.txt" >/dev/null 2>&1; then bad=$((bad+1)); echo "DIFF run $i"; fi
done
echo "== $PAGE $V : $N 次，异常 $bad 次 =="
if [ "$bad" -gt 0 ]; then
  echo "---- 首个异常 run 与参考的差异 ----"
  for i in $(seq 1 "$N"); do
    if ! diff -q "$D/ref.audit.txt" "$D/$i.audit.txt" >/dev/null 2>&1; then
      diff "$D/ref.audit.txt" "$D/$i.audit.txt" | head -40; break
    fi
  done
fi
