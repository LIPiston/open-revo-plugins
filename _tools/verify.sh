#!/usr/bin/env bash
# verify.sh —— 把 HANDOFF.md §11.4 的验收表落成**可执行断言**（不靠肉眼、不靠运气）。
#
#   bash _tools/verify.sh            # 先重跑两页审计，再逐条断言
#   NO_AUDIT=1 bash _tools/verify.sh # 复用 _audit/ 里已有的产物（快速复检）
#
# 为什么要有这个脚本：
#   ① §11.4 原先只是一张写在文档里的表，靠人读产物对数字 —— 人眼会看漏，也会被"看上去通过"骗过。
#   ② 曾经有过一次「负向条件（色族数=2）恰好成立」的假通过（坏读数里全是宿主原色，族数也是 2）。
#      所以这里每条**正向**断言都写死：令牌值 / 探针值必须等于该变体的预期值本身。
#   ③ 迷你面板有 17% 的样式失效竞态（见 pitfalls #39），断言里带 `settle.remounts = 1` 把
#      「皮肤确实落地」这件事也钉死。
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
OUT=_audit
FAILS=0; N=0

chk() { # chk <文件> <字段名> <说明> <期望正则>
  local f="$1" field="$2" desc="$3" want="$4"
  N=$((N+1))
  local line; line=$(grep -m1 -E "^${field}[[:space:]]*=" "$f" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    echo "  FAIL  ${desc}  —— 文件里没有字段 ${field}（${f}）"
    FAILS=$((FAILS+1)); return
  fi
  # 只把 `=` 右边的值拿去匹配：整行匹配会把字段名也算进去，得到一片假失败
  local val="${line#*=}"
  val="${val#"${val%%[![:space:]]*}"}"
  if [[ "$val" =~ $want ]]; then
    printf '  ok    %-52s %s\n' "$desc" "$val"
  else
    printf '  FAIL  %-52s %s   （期望匹配 /%s/）\n' "$desc" "$val" "$want"
    FAILS=$((FAILS+1))
  fi
}

# 变体表：id | important | accent | important-rgb | accent-rgb | 明暗
VARIANTS=(
  "skin-win11-light|#ca5010|#0067c0|rgb\\(202, 80, 16\\)|rgb\\(0, 103, 192\\)|light"
  "skin-win11-dark|#ff9d5c|#60cdff|rgb\\(255, 157, 92\\)|rgb\\(96, 205, 255\\)|dark"
  "skin-win10-light|#d83b01|#0078d4|rgb\\(216, 59, 1\\)|rgb\\(0, 120, 212\\)|light"
  "skin-win10-dark|#ff8c00|#1683d8|rgb\\(255, 140, 0\\)|rgb\\(22, 131, 216\\)|dark"
)

if [[ "${NO_AUDIT:-0}" != "1" ]]; then
  echo "== 重跑审计（主窗 + 迷你，各四套）=="
  rm -f "$OUT"/*.audit.txt "$OUT"/*.dom.html
  bash _tools/audit.sh                          >/dev/null 2>&1 || echo "  (主窗 audit.sh 非零退出)"
  PAGE=preview-mini.html bash _tools/audit.sh   >/dev/null 2>&1 || echo "  (迷你 audit.sh 非零退出)"
fi

echo
echo "== 主窗 preview.html =="
for row in "${VARIANTS[@]}"; do
  IFS='|' read -r id imp acc imprgb accrgb light <<<"$row"
  f="$OUT/$id.audit.txt"
  echo "--- $id ---"
  [[ -f "$f" ]] || { echo "  FAIL  产物缺失：$f"; FAILS=$((FAILS+1)); continue; }
  bg=$( [[ $light == light ]] && echo "rgb\\(243, 243, 243\\)" || echo "rgb\\(32, 32, 32\\)" )
  chk "$f" "container.blur"       "容器不透明：blur=none"                 "^none"
  chk "$f" "container.display"    "容器是 grid"                           "^grid"
  chk "$f" "container.cols"       "两列 224px + 894px"                    "224px 894px"
  chk "$f" "container.areas"      "标题栏横跨两列"                        'wf-titlebar wf-titlebar.*wf-sidebar wf-content'
  chk "$f" "container.alpha"      "底色是纯色（非半透明）"                "^${bg}"
  chk "$f" "rules_applied"        "皮肤规则 118 条全部生效"                "^118"
  chk "$f" "--wf-important"       "important 令牌 = ${imp}"               "^${imp}$"
  chk "$f" "--theme-pwr"          "important 令牌 = ${imp}"               "^${imp}$"
  chk "$f" "dom.hueFamilies"      "DOM 色族 = 2"                          "^2$"
done

echo
echo "== 迷你面板 preview-mini.html =="
for row in "${VARIANTS[@]}"; do
  IFS='|' read -r id imp acc imprgb accrgb light <<<"$row"
  f="$OUT/mini-$id.audit.txt"
  echo "--- $id ---"
  [[ -f "$f" ]] || { echo "  FAIL  产物缺失：$f"; FAILS=$((FAILS+1)); continue; }
  bg=$( [[ $light == light ]] && echo "rgb\\(243, 243, 243\\)" || echo "rgb\\(32, 32, 32\\)" )
  chk "$f" "skin_active"          "皮肤已注入并激活"                      "^$id$"
  chk "$f" "rules_applied"        "皮肤规则 118 条全部生效"                "^118"
  chk "$f" "settle.remounts"      "落地后强制重解析一次（防 17% 竞态）"     "^1 "
  chk "$f" "root.bg"              "面板底色纯粹（宿主值被压掉）"           "^${bg}$"
  chk "$f" "root.bgImage"         "无背景图"                              "^none$"
  chk "$f" "root.blur"            "无模糊"                                "^none"
  chk "$f" "root.size"            "面板 410x610"                          "^410x610$"
  chk "$f" "content.size"         "内容 410x621（无诊断残留撑高）"          "^410x621$"
  chk "$f" "dom.hueFamilies"      "DOM 色族 = 2"                          "^2$"
  # 正向条件：宿主会把 --theme-* 全刷成白色，这六槽必须等于本变体的两个令牌
  chk "$f" "mini.--theme-pwr"     "important 槽 = ${imp}"                 "^${imp}$"
  for slot in bat gpu hz kbd lux; do
    chk "$f" "mini.--theme-${slot}" "accent 槽 ${slot} = ${acc}"           "^${acc}$"
  done
  chk "$f" "mini.--wf-accent"     "accent 令牌 = ${acc}"                  "^${acc}$"
  chk "$f" "mini.--wf-important"  "important 令牌 = ${imp}"               "^${imp}$"
  # 探针：凡是皮肤要压过宿主内联/高优先级规则的地方，都必须落在本变体的色上
  chk "$f" "ready.dot.bg"         "状态点 = accent"                       "^${accrgb}$"
  chk "$f" "themeBtn.cyber.co"    "主题按钮（宿主内联青）被压成 accent"     "^${accrgb}$"
  chk "$f" "oem.blocked.co"       "OEM 未运行徽标 = accent"                "^${accrgb}$"
  chk "$f" "oem.running.co"       "OEM 运行中徽标 = important"             "^${imprgb}$"
  chk "$f" "sponsorHeart.col"     "赞助心 = accent"                       "^${accrgb}$"
  chk "$f" "quickActive.col"      "快捷开关选中 = accent（(0,4,0) 压 (0,3,0)）" "^${accrgb}$"
done

echo
echo "== 像素普查（census.py，需要 _shots/mini-<id>.png）=="
for row in "${VARIANTS[@]}"; do
  IFS='|' read -r id imp acc imprgb accrgb light <<<"$row"
  shot="_shots/mini-$id.png"
  if [[ ! -f "$shot" ]]; then echo "  skip  $id —— 没有 $shot（先跑 bash _tools/shots.sh）"; continue; fi
  n=$(python _tools/census.py "$shot" 2>/dev/null | grep -oE '色族[^0-9]*[0-9]+' | grep -oE '[0-9]+$' | head -1)
  N=$((N+1))
  if [[ "$n" == "2" ]]; then echo "  ok    像素色族 = 2（$id）"
  else echo "  FAIL  像素色族 = ${n:-?}（$id，期望 2）"; FAILS=$((FAILS+1)); fi
done

echo
echo "================ 合计 $N 条断言，失败 $FAILS 条 ================"
[[ "$FAILS" == "0" ]] && echo "全部通过。" || echo "有失败 —— 不要交付。"
exit $(( FAILS > 0 ? 1 : 0 ))
