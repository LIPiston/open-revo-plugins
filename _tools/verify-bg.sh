#!/usr/bin/env bash
# verify-bg.sh —— 自定义背景（background 插件）的可执行验收。exit 1 就是没改完。
#
#   bash _tools/verify-bg.sh              # 已启用：先跑既有 132 条，再跑背景断言
#   NO_AUDIT=1 bash _tools/verify-bg.sh   # 复用 _audit/ 里已有的产物（快速复检）
#   bash _tools/verify-bg.sh off          # 未启用：断言「零泄漏」——没有 --bgimg-photo，
#                                         # 没有照片图层，产物目录已删除
#
# 为什么必须是**独立**脚本、而不是往 verify.sh 里塞：
#   既有 132 条断言是原四套皮肤的验收基线（含 `root.bgImage = none`、`container.alpha`
#   这类「不能有背景图」的正向断言）。背景图一旦烘进那四套皮肤，这些断言必然互斥。
#   所以默认只出**独立插件** `bg-custom`（不动任何皮肤目录），派生皮肤 `<id>-bg` 降级为
#   `--targets` 显式开启的可选导出。本脚本对新 id 立新的断言，旧 id 的 132 条一个字不改
#   （本脚本第一件事就是重跑它们，failed 直接计入总数）。
#
# 为什么不需要 audit-bg.sh：`_tools/audit.sh` 早就把 id 参数化了（`#<id>` → activate()
#   同步 XHR GET `<id>/theme.css`），`<id>-bg` 直接能审计。复制一份审计器只会让它漂移。
#
# 断言口径（每一条都是「正向写死」——见 verify.sh 头部的教训③）：
#   ① 结构：派生 theme.css = 原皮肤逐行相同 + 末尾只多出背景段（第 1 行插件名除外）
#   ② 启用：图层数/照片层/遮罩层/令牌/解码尺寸/size-position-repeat/兜底底色
#   ③ 不回归：皮肤自身布局与配色断言（blur/cols/areas/色族/令牌/探针色）原样通过
#   ④ 禁用：令牌不泄漏（bg.token.photo = no）、照片层计数归零、产物目录不在了
set -u
# Python 在 Git Bash 里默认按本地代码页输出中文 → 失败信息会变成乱码。钉死 UTF-8。
export PYTHONIOENCODING=utf-8
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
OUT=_audit
FAILS=0; N=0
MODE="${1:-on}"

chk() { # chk <文件> <字段名> <说明> <期望正则>  —— 与 verify.sh 同语义（父仓库复制一份，
        # 因为 verify.sh 是「执行到文件末」的脚本、不能 source；两处 chk 必须保持等价）
  local f="$1" field="$2" desc="$3" want="$4"
  N=$((N+1))
  local line; line=$(grep -m1 -E "^${field}[[:space:]]*=" "$f" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    echo "  FAIL  ${desc}  —— 文件里没有字段 ${field}（${f}）"
    FAILS=$((FAILS+1)); return
  fi
  local val="${line#*=}"
  val="${val#"${val%%[![:space:]]*}"}"
  # 审计里有 136KB 级的单行（data URI），超长值截断后再打日志，避免刷屏
  local shown="$val"; (( ${#shown} > 72 )) && shown="${shown:0:69}..."
  if [[ "$val" =~ $want ]]; then
    printf '  ok    %-52s %s\n' "$desc" "$shown"
  else
    printf '  FAIL  %-52s %s   （期望匹配 /%s/）\n' "$desc" "$shown" "$want"
    FAILS=$((FAILS+1))
  fi
}

chk_fs() { # chk_fs <说明> <期望存在 1/0> <路径>
  local desc="$1" want="$2" p="$3"
  N=$((N+1))
  local have=0; [[ -e "$p" ]] && have=1
  if [[ "$have" == "$want" ]]; then
    printf '  ok    %-52s %s\n' "$desc" "$([[ $want == 1 ]] && echo 存在 || echo 不存在)"
  else
    printf '  FAIL  %-52s %s（期望 %s）\n' "$desc" "$p" "$([[ $want == 1 ]] && echo 存在 || echo 不存在)"
    FAILS=$((FAILS+1))
  fi
}

regex_escape() { printf '%s' "$1" | sed 's/[][\\.^$*+?(){}|/]/\\&/g'; }

# 变体表：id | important | accent | important-rgb | accent-rgb | 明暗 | 底色 hex | 底色 rgb
# （前六列与 verify.sh 的 VARIANTS 逐字一致，改一处必须改两处）
VARIANTS=(
  "skin-win11-light|#ca5010|#0067c0|rgb\\(202, 80, 16\\)|rgb\\(0, 103, 192\\)|light|#f3f3f3|rgb\\(243, 243, 243\\)"
  "skin-win11-dark|#ff9d5c|#60cdff|rgb\\(255, 157, 92\\)|rgb\\(96, 205, 255\\)|dark|#202020|rgb\\(32, 32, 32\\)"
  "skin-win10-light|#d83b01|#0078d4|rgb\\(216, 59, 1\\)|rgb\\(0, 120, 212\\)|light|#f3f3f3|rgb\\(243, 243, 243\\)"
  "skin-win10-dark|#ff8c00|#1683d8|rgb\\(255, 140, 0\\)|rgb\\(22, 131, 216\\)|dark|#202020|rgb\\(32, 32, 32\\)"
)

# ---- 背景配置真值（从 bg.config.json 反推期望，而不是抄产物里的值）-------------
if [[ ! -f bg.config.json ]]; then
  echo "FAIL  没有 bg.config.json —— 先跑 python build_background.py set --image <图>"
  exit 1
fi
eval "$(python - <<'PY'
import shlex, sys
sys.path.insert(0, ".")
import bg_common as B
cfg = B.load_config()
print("ENABLED=%s" % (1 if cfg.get("enabled") else 0))
print("STANDALONE=%s" % (1 if cfg.get("standalone") else 0))
print("TARGETS=%s" % shlex.quote(" ".join(cfg.get("targets") or [])))
print("FIT=%s" % shlex.quote(cfg.get("fit") or "cover"))
print("SCOPE=%s" % shlex.quote(cfg.get("scope") or "both"))
print("IMG_SRC=%s" % shlex.quote(cfg.get("image") or ""))
print("REPEAT=%s" % shlex.quote(B.FIT[cfg.get("fit") or "cover"][1]))
PY
)"

# POS 归一化：CSS 里写 `center`，computed style 读到的是 `50% 50%`
norm_pos() {
  case "$1" in
    center) echo "50% 50%" ;; top) echo "50% 0%" ;; bottom) echo "50% 100%" ;;
    left) echo "0% 50%" ;; right) echo "100% 50%" ;;
    "top left") echo "0% 0%" ;; "top right") echo "100% 0%" ;;
    "bottom left") echo "0% 100%" ;; "bottom right") echo "100% 100%" ;;
    *) echo "$1" ;;
  esac
}

# 从产物**重新推导**期望（scrim 的 auto 取色依赖该变体底色；图片解码尺寸取 PIL 处理后
# 的产物，这样才能真正交叉验证「PIL 写出的字节 = 浏览器解码出的图」）
expect_for() { # expect_for <变体底色 hex> <产物目录> <position>
  python - "$1" "$2" "$3" <<'PY'
import sys
sys.path.insert(0, ".")
import bg_common as B
import PIL.Image
basehex, outdir, pos = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = B.load_config()
overlay = float(cfg.get("overlay", 0.42))
scrim = B.scrim_css(overlay, cfg.get("overlay_color", "auto"), basehex)
size, repeat = B.FIT[cfg.get("fit") or "cover"]
import os
w = h = 0
for ext in ("jpg", "png"):
    p = os.path.join(outdir, "assets", "background." + ext)
    if os.path.exists(p):
        with PIL.Image.open(p) as im:
            w, h = im.size
        break
print("|".join([scrim, size, repeat, pos, str(w), str(h)]))
PY
}

# 结构断言：派生 theme.css 必须 = 原皮肤**逐行相同**（只允许 id 替换与标题里多出的
# 「· 自定义背景」），且末尾只追加背景段。为什么不能直接字节比对：仓库以 __SKIN_ID__
# 为占位符生成文件，id 出现在每个选择器里，所以先归一化 id 再逐行比，才能证明
# 「皮肤本体一个字符没动」。
chk_prefix() { # chk_prefix <原 theme.css> <派生 theme.css> <原id> <派生id> <末尾期望规则数> <说明>
  local a="$1" b="$2" baseid="$3" did="$4" exp_tail="$5" desc="$6"
  N=$((N+1))
  local why
  why=$(python - "$a" "$b" "$baseid" "$did" "$exp_tail" <<'PY'
import sys
import re
pa, pb, baseid, did, exp_tail = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
def norm(s):
    return s.replace(did, baseid).replace(" · 自定义背景", "")
a = open(pa, encoding="utf-8").read().splitlines()
b = open(pb, encoding="utf-8").read().splitlines()
if len(b) <= len(a):
    print("派生文件不比原文件长（原 %d 行 / 派 %d 行）" % (len(a), len(b))); raise SystemExit
for i in range(len(a)):
    if norm(b[i]) != a[i]:
        print("第 %d 行偏离原皮肤\n      原: %r\n      派: %r" % (i + 1, a[i][:70], b[i][:70]))
        raise SystemExit
tail = "\n".join(b[len(a):])
# 注释里会引用宿主的规则原文（`.acrylic-container{background:…}`），所以先剥注释再数 `{`
braces = re.sub(r"/\*.*?\*/", "", tail, flags=re.S).count("{")
if braces != exp_tail:
    print("末尾追加段含 %d 条 CSS 规则，期望 %d" % (braces, exp_tail)); raise SystemExit
if "--bgimg-photo" not in tail:
    print("末尾追加段里找不到 --bgimg-photo"); raise SystemExit
if "自定义背景" not in b[0]:
    print("派生文件第 1 行没有标注「自定义背景」：%r" % b[0][:70]); raise SystemExit
print("OK")
PY
)
  if [[ "$why" == "OK" ]]; then
    printf '  ok    %-52s %s\n' "$desc" "= 原皮肤 + 末尾 ${exp_tail} 条背景规则"
  else
    printf '  FAIL  %-52s %s\n' "$desc" "$why"
    FAILS=$((FAILS+1))
  fi
}

# ---- ① 既有 132 条：先证明没把它碰坏 ------------------------------------------
if [[ "${NO_AUDIT:-0}" != "1" ]]; then
  echo "== 既有皮肤验收（_tools/verify.sh，原四套）=="
fi
if [[ "${SKIP_BASE:-0}" != "1" ]]; then
  _base_tmp="$(mktemp)"
  bash _tools/verify.sh > "$_base_tmp" 2>&1; _rc=$?
  if [[ "$_rc" == "0" ]]; then
    N=$((N+1)); printf '  ok    %-52s %s\n' "既有 132 条断言全绿（无回归）" "$(tail -1 "$_base_tmp")"
  else
    N=$((N+1)); echo "  FAIL  既有 132 条断言出现失败（详见 tail 输出）"; tail -6 "$_base_tmp"; FAILS=$((FAILS+1))
  fi
  rm -f "$_base_tmp"
fi

if [[ "$MODE" == "off" ]]; then
  echo
  echo "== 未启用模式：断言零泄漏 =="
  N=$((N+1))
  if [[ "$ENABLED" == "0" ]]; then
    printf '  ok    %-52s %s\n' "bg.config.json enabled = false" "enabled=false"
  else
    printf '  FAIL  %-52s %s\n' "bg.config.json enabled = false" "enabled=true"; FAILS=$((FAILS+1))
  fi
  # 必须消失的产物 id：独立插件（若开过）+ 每个派生的 <id>-bg。
  # 从配置反推，不写死 —— `--targets none` 时这里就只剩 bg-custom 一条腿。
  GONE=()
  [[ "$STANDALONE" == "1" ]] && GONE+=("bg-custom")
  for row in "${VARIANTS[@]}"; do
    IFS='|' read -r id imp acc imprgb accrgb light basehex bgrgb <<<"$row"
    [[ " $TARGETS " == *" $id "* ]] && GONE+=("$id-bg")
  done
  if [[ "${#GONE[@]}" == "0" ]]; then
    echo "  (bg.config.json 里既没有 standalone 也没有派生目标，没有需要消失的产物)"
  fi
  for did in "${GONE[@]}"; do
    chk_fs "产物目录已删除（$did）" 0 "$did"
    if [[ "${NO_AUDIT:-0}" != "1" ]]; then bash _tools/audit.sh "$did" >/dev/null 2>&1; fi
    f="$OUT/$did.audit.txt"
    echo "--- $did（期望：回落原皮肤，零泄漏）---"
    [[ -f "$f" ]] || { echo "  FAIL  产物缺失：$f"; FAILS=$((FAILS+1)); continue; }
    # 皮肤名字段必须回到原四套之一（`bg-custom` / `skin-*-bg` 这种 id 不允许出现）
    chk "$f" "skin_id"          "回落原皮肤（不是 $did）"           "^skin-win(11|10)-(light|dark)$"
    chk "$f" "bg.token.photo"   "禁用后不泄漏 --bgimg-photo"        "^no$"
    chk "$f" "bg.photo.count"   "禁用后没有照片图层"                 "^0$"
    # 不断言层总数的具体值：那是「回落哪套皮肤」的事，不是背景插件的事。
    # 这里只钉死「照片层 = 0」——背景插件的痕迹必须一点不剩。
    chk "$f" "bg.layers"        "照片层计数 = 0（其余层归原皮肤）"    "^[0-9]+ \(photo 0 \+"
    chk "$f" "bg.image.loaded"  "没有可解码的背景图"                 "^n/a$"
    chk "$f" "container.img"    "容器上没有背景图（原皮肤口径）"      "^none"
    chk "$f" "container.alpha"  "底色是纯色（非半透明 / 非照片兜底色）" "^rgb\("
  done
else
  # ---- ②③ 启用：派生皮肤（皮肤不回归 + 背景真的生效）----------------------------
  for row in "${VARIANTS[@]}"; do
    IFS='|' read -r id imp acc imprgb accrgb light basehex bgrgb <<<"$row"
    [[ " $TARGETS " == *" $id "* ]] || continue
    did="$id-bg"
    echo
    echo "== 启用：派生皮肤 $did =="
    chk_fs "派生产物目录存在（$did）" 1 "$did"
    [[ -d "$did" ]] || continue
    # 追加了几条背景规则 → 规则数 = 既有 118 + 1（令牌块）+ 1/2（主窗/迷你窗规则）
    extra=$(grep -cE "^\[data-skin=\"$did\"\] \.(acrylic-container\.acrylic-container|mini-drawer-root\.mini-drawer-root) \{$" "$did/theme.css" 2>/dev/null || true)
    exp_rules=$((118 + 1 + extra))
    chk_prefix "$id/theme.css" "$did/theme.css" "$id" "$did" "$((extra + 1))" "结构 = 原皮肤 + 背景段（逐行比对）"
    IFS='|' read -r SCRIM FIT_SIZE FIT_REPEAT FIT_POSCSS IMGW IMGH \
      <<<"$(expect_for "$basehex" "$did" "$(norm_pos "$(python -c "import sys;sys.path.insert(0,'.');import bg_common as B;print(B.load_config().get('position','center'))")")")"
    if [[ "$IMGW" == "0" ]]; then echo "  FAIL  读不到 $did/assets/background.* 的尺寸"; FAILS=$((FAILS+1)); continue; fi

    if [[ "${NO_AUDIT:-0}" != "1" ]]; then
      bash _tools/audit.sh "$did" >/dev/null 2>&1
      PAGE=preview-mini.html bash _tools/audit.sh "$did" >/dev/null 2>&1
    fi
    f="$OUT/$did.audit.txt"; fm="$OUT/mini-$did.audit.txt"
    [[ -f "$f"  ]] || { echo "  FAIL  产物缺失：$f";  FAILS=$((FAILS+1)); }
    [[ -f "$fm" ]] || { echo "  FAIL  产物缺失：$fm"; FAILS=$((FAILS+1)); }

    echo "--- 主窗（皮肤不回归）---"
    chk "$f" "skin_id"          "皮肤 id = $did"                    "^$did$"
    chk "$f" "rules_applied"    "规则数 = 118 + $((1+extra)) 条背景规则" "^${exp_rules}"
    chk "$f" "container.blur"   "容器不透明：blur=none"              "^none"
    chk "$f" "container.display" "容器仍是 grid"                     "^grid"
    chk "$f" "container.cols"   "两列 224px + 894px"                 "224px 894px"
    chk "$f" "container.areas"  "标题栏横跨两列"                     'wf-titlebar wf-titlebar.*wf-sidebar wf-content'
    chk "$f" "container.alpha"  "底色 = 变体底色（背景兜底色一致）"    "^${bgrgb}$"
    chk "$f" "--wf-important"   "important 令牌 = ${imp}"            "^${imp}$"
    chk "$f" "dom.hueFamilies"  "DOM 色族 = 2（照片不参与色族采样）"   "^2$"
    echo "--- 主窗（背景图层）---"
    chk "$f" "bg.probe.sel"     "探针落在面板根 .acrylic-container"   "^acrylic-container$"
    chk "$f" "bg.photo.count"   "照片层 = 1 层"                      "^1$"
    chk "$f" "bg.grad.count"    "遮罩层 = 1 层"                      "^1$"
    chk "$f" "bg.layers"        "总层数 = 2（不多不少）"               "^2 \(photo 1 \+ linear 1 \+ radial 0\)$"
    chk "$f" "bg.token.photo"   "令牌 --bgimg-photo 已注入"           "^yes$"
    chk "$f" "bg.image.loaded"  "浏览器真解码出图：${IMGW}x${IMGH}"     "^true ${IMGW}x${IMGH} dataURI [0-9]+B$"
    chk "$f" "bg.layer2.size"   "照片层 size = ${FIT_SIZE}"          "^$(regex_escape "$FIT_SIZE")$"
    chk "$f" "bg.layer2.pos"    "照片层 position = ${FIT_POSCSS}"     "^$(regex_escape "$FIT_POSCSS")$"
    chk "$f" "bg.layer2.repeat" "照片层 repeat = ${FIT_REPEAT}"      "^$(regex_escape "$FIT_REPEAT")$"
    chk "$f" "bg.scrim"         "遮罩 = 配置 overlay 推导值"          "^$(regex_escape "$SCRIM")$"
    chk "$f" "bg.base"          "兜底底色 = ${basehex}"              "^$(regex_escape "$basehex")$"

    echo "--- 迷你面板（皮肤不回归）---"
    chk "$fm" "skin_active"     "皮肤已注入并激活"                    "^$did$"
    chk "$fm" "rules_applied"   "规则数 = ${exp_rules}"              "^${exp_rules}"
    chk "$fm" "settle.remounts" "落地后强制重解析一次（防 17% 竞态）"   "^1 "
    chk "$fm" "root.blur"       "无模糊（模糊烘进图片）"               "^none"
    chk "$fm" "root.bg"         "兜底底色 = 变体底色"                 "^${bgrgb}$"
    chk "$fm" "root.size"       "面板 410x610"                       "^410x610$"
    chk "$fm" "content.size"    "内容 410x621（无诊断残留撑高）"       "^410x621$"
    chk "$fm" "dom.hueFamilies" "DOM 色族 = 2"                       "^2$"
    chk "$fm" "mini.--wf-accent"    "accent 令牌 = ${acc}"            "^${acc}$"
    chk "$fm" "mini.--wf-important" "important 令牌 = ${imp}"         "^${imp}$"
    chk "$fm" "ready.dot.bg"        "状态点 = accent"                 "^${accrgb}$"
    chk "$fm" "themeBtn.cyber.co"   "主题按钮（宿主内联青）被压成 accent" "^${accrgb}$"
    chk "$fm" "oem.blocked.co"      "OEM 未运行徽标 = accent"          "^${accrgb}$"
    chk "$fm" "oem.running.co"      "OEM 运行中徽标 = important"       "^${imprgb}$"
    chk "$fm" "sponsorHeart.col"    "赞助心 = accent"                 "^${accrgb}$"
    chk "$fm" "quickActive.col"     "快捷开关选中 = accent"            "^${accrgb}$"
    echo "--- 迷你面板（背景图层）---"
    chk "$fm" "bg.probe.sel"     "探针落在面板根 .mini-drawer-root"    "^mini-drawer-root$"
    chk "$fm" "bg.photo.count"   "照片层 = 1 层"                      "^1$"
    chk "$fm" "bg.grad.count"    "遮罩层 = 1 层"                      "^1$"
    chk "$fm" "bg.layers"        "总层数 = 2"                        "^2 \(photo 1 \+ linear 1 \+ radial 0\)$"
    chk "$fm" "bg.token.photo"   "令牌 --bgimg-photo 已注入"           "^yes$"
    chk "$fm" "bg.image.loaded"  "浏览器真解码出图：${IMGW}x${IMGH}"     "^true ${IMGW}x${IMGH} dataURI [0-9]+B$"
    chk "$fm" "bg.layer2.size"   "照片层 size = ${FIT_SIZE}"          "^$(regex_escape "$FIT_SIZE")$"
    chk "$fm" "bg.layer2.pos"    "照片层 position = ${FIT_POSCSS}"     "^$(regex_escape "$FIT_POSCSS")$"
    chk "$fm" "bg.layer2.repeat" "照片层 repeat = ${FIT_REPEAT}"      "^$(regex_escape "$FIT_REPEAT")$"
    chk "$fm" "bg.scrim"         "遮罩 = 配置 overlay 推导值"          "^$(regex_escape "$SCRIM")$"
    chk "$fm" "bg.base"          "兜底底色 = ${basehex}"              "^$(regex_escape "$basehex")$"
    # 迷你窗这一条与既有断言**方向相反**：基线要求 root.bgImage = none，背景皮肤要求它带上照片
    N=$((N+1))
    if [[ "$(grep -cE '^root.bgImage.*url\(' "$fm" 2>/dev/null || true)" != "0" ]] \
       && [[ "$(grep -cE '^root.bgImage.*linear-gradient\(' "$fm" 2>/dev/null || true)" != "0" ]]; then
      printf '  ok    %-52s %s\n' "迷你面板 root 背景图 = 遮罩 + 照片" "linear-gradient(...), url(data:...)"
    else
      printf '  FAIL  %-52s %s\n' "迷你面板 root 背景图 = 遮罩 + 照片" "root.bgImage 里没有 url(/linear-gradient("
      FAILS=$((FAILS+1))
    fi
  done

  # ---- ④ 独立插件 bg-custom：不依赖任何皮肤，只叠背景 --------------------------
  if [[ "$STANDALONE" == "1" ]]; then
    echo
    echo "== 独立插件 bg-custom（宿主默认 UI + 背景）=="
    chk_fs "独立插件目录存在（bg-custom）" 1 "bg-custom"
    if [[ -d bg-custom ]]; then
      if [[ "${NO_AUDIT:-0}" != "1" ]]; then
        bash _tools/audit.sh bg-custom >/dev/null 2>&1
        PAGE=preview-mini.html bash _tools/audit.sh bg-custom >/dev/null 2>&1
      fi
      f="$OUT/bg-custom.audit.txt"; fm="$OUT/mini-bg-custom.audit.txt"
      IFS='|' read -r SCRIM2 FIT_SIZE2 FIT_REPEAT2 FIT_POSCSS2 IMGW2 IMGH2 \
        <<<"$(expect_for "#0b0e14" "bg-custom" "$(norm_pos "$(python -c "import sys;sys.path.insert(0,'.');import bg_common as B;print(B.load_config().get('position','center'))")")")"
      [[ -f "$f"  ]] || { echo "  FAIL  产物缺失：$f";  FAILS=$((FAILS+1)); }
      [[ -f "$fm" ]] || { echo "  FAIL  产物缺失：$fm"; FAILS=$((FAILS+1)); }
      chk "$f" "skin_id"         "skin_id = bg-custom"                "^bg-custom$"
      chk "$f" "container.bg"    "兜底底色 = 宿主 .acrylic-container 底色" "^rgb\\(11, 14, 20\\)$"
      chk "$f" "bg.probe.sel"    "探针落在 .acrylic-container"          "^acrylic-container$"
      chk "$f" "bg.layers"       "总层数 = 2"                         "^2 \(photo 1 \+ linear 1 \+ radial 0\)$"
      chk "$f" "bg.token.photo"  "令牌已注入"                          "^yes$"
      chk "$f" "bg.image.loaded" "浏览器真解码出图：${IMGW2}x${IMGH2}"    "^true ${IMGW2}x${IMGH2} dataURI [0-9]+B$"
      chk "$f" "bg.layer2.size"  "照片层 size = ${FIT_SIZE2}"          "^$(regex_escape "$FIT_SIZE2")$"
      chk "$f" "bg.layer2.pos"   "照片层 position = ${FIT_POSCSS2}"     "^$(regex_escape "$FIT_POSCSS2")$"
      chk "$f" "bg.layer2.repeat" "照片层 repeat = ${FIT_REPEAT2}"     "^$(regex_escape "$FIT_REPEAT2")$"
      chk "$f" "bg.scrim"        "遮罩 = 配置 overlay 推导值"           "^$(regex_escape "$SCRIM2")$"
      chk "$f" "bg.base"         "兜底底色 = #0b0e14"                  "^#0b0e14$"
      chk "$fm" "skin_active"    "迷你面板也激活 bg-custom"             "^bg-custom$"
      chk "$fm" "bg.probe.sel"   "探针落在 .mini-drawer-root"           "^mini-drawer-root$"
      chk "$fm" "bg.photo.count" "照片层 = 1 层"                       "^1$"
      chk "$fm" "bg.image.loaded" "迷你面板也解码出图"                   "^true ${IMGW2}x${IMGH2} dataURI [0-9]+B$"
      chk "$fm" "bg.base"        "兜底底色 = #0b0e14"                  "^#0b0e14$"
    fi
  fi
fi

echo
echo "================ 合计 $N 条断言，失败 $FAILS 条 ================"
[[ "$FAILS" == "0" ]] && echo "全部通过。" || echo "有失败 —— 不要交付。"
exit $(( FAILS > 0 ? 1 : 0 ))
