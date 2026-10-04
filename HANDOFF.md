# 交接文档 · OpenRevo Windows 组件 UI 皮肤插件

> 写给**换工作区之后**接手的你（或下一个 Agent）。
> 目标：只读这一份就能继续干活，不需要回溯原会话。
> 最后更新：2026-10-04（宿主构建 8,496,640 B / 2026-10-03 23:49:31 未变）
> 本轮（2026-10-04）：**配色收敛为「系统主题色 + 重要强调色」两个装饰色**，mini 面板六色族 → 二色族。见 §1 状态表与 §11（新增）。
> 本轮（2026-10-04 续）：**项目改名 `openrevo-win-skin\` → `openrevo-plugins\`，四套皮肤升格为根级子目录项目，插件 ID 去掉 `fluent`**。见 §0.1。

---

## 0. 本文件在哪里

| 位置 | 路径 | 用途 |
|---|---|---|
| 工作区根（原始要求） | `D:\LIPis\Documents\deepseek-harness\default-workspace\HANDOFF.md` | 旧位置的副本 |
| 过期镜像树 | `D:\LIPis\Documents\deepseek-harness\default-workspace\openrevo-win-skin\HANDOFF.md` | ⚠️ **未随本次改名同步，已作废** |
| 独立项目根（**权威副本**） | `D:\LIPis\Documents\code\openrevo-plugins\HANDOFF.md` | 长期位置 |

**如果你切换到一个全新的空白工作区**：这份文件不在里面，把 `D:\LIPis\Documents\code\openrevo-plugins\`
放进去（或告诉我新路径，我补一份）。**权威副本 = `D:\LIPis\Documents\code\openrevo-plugins\`**。

> ⚠️ **不要再把 harness 工作区那棵当盘**。它是改名前的快照，插件 ID 还是旧的 `win11-fluent-*`。
> 历史上已经踩过一次「改了 A 树、审计了 B 树」——README §3 记着这个坑。
> 那棵树要怎么处理（改名 / 删除 / 保留）待用户拍板。

### 0.1 本次改名（2026-10-04）

| 旧 | 新 |
|---|---|
| 项目根 `openrevo-win-skin\` | `openrevo-plugins\` |
| `dist\win11-fluent-light\` | `skin-win11-light\`（**直接放在仓库根**，`dist\` 这一层已取消） |
| `dist\win11-fluent-dark\` | `skin-win11-dark\` |
| `dist\win10-fluent-light\` | `skin-win10-light\` |
| `dist\win10-fluent-dark\` | `skin-win10-dark\` |

* 改名是**纯命名**，产物内容除 ID 字符串外逐字节未变（改名前后 `cmp` 对拍过四套 `theme.css` + `manifest.json`）。
* 已装副本同步换名：`%APPDATA%\OpenRevo\plugins\` 下旧目录已删，`config.json` 的
  `active_skin` 由 `win11-fluent-dark` 改成 `skin-win11-dark`（备份 `config.json.bak-skinrename`）。
* 宿主**只在启动时枚举插件目录**，所以新 ID 要**提权重启宿主**才生效 —— 这一步会打断用户，需先问。

---

## 1. 一分钟看懂：任务是什么、现在到哪了

**任务**：给 OpenRevo（`D:\Program Files\OpenRevo\open-revo.exe`）做一个 **skin 类插件**，
把宿主改成**传统 WinUI3 观感**：

1. 主控台（大面板）：**左侧 224px 导航栏**式的 tab 切换（原本是顶部横排 tab）+ **取消半透明**背景；
2. 迷你面板（mini）：**同步 WinUI3 化 + 取消半透明**（原本是 `rgba(12,15,22,.96)` + `blur(28px)`）。

**状态：两条都已真机取证完成。** 皮肤包四套（Win11/Win10 × 明/暗）已安装，
用户在宿主【插件】页自行选中了 `skin-win11-dark`。

| 目标 | 状态 | 证据 |
|---|---|---|
| 主窗 224px 侧栏 + 不透明 | ✅ 真机确证 | `_shots\real-dash-1500.png`：列边缘在 CSS `224.7/225.3` 最强；宿主调色板计数为 0 |
| mini WinUI3 化 + 不透明 | ✅ 真机确证 | `_shots\real-mini-clean.png`：宿主色 ≈0，与预览分块 MAE 19.98 |
| mini **只用系统主题色强调**（用户口径） | ✅ 无头取证 | `python _tools\census.py _shots\mini-<id>.png` → 四套变体**色族数量 = 2**；DOM 普查 `dom.hueFamilies = 2` |
| 整份 UI 收敛为**两个装饰色** | ✅ 无头取证 | `--theme-pwr`→important、其余五个→accent；`--accent-pwr/-beast`→important、其余→accent；构建产物与已装副本逐字节一致 |
| 开发记录 → 可复用技能包 | ✅ 已交付 | `openrevo-plugins\docs\`（`SKILL.md` + 7 个 md；镜像树那份已因改名脱钩） |
| 用户观感确认 | ⏳ 未收到 | — |
| mini 底部细横向滚动条 | ⏸ 用户决定「先不动」 | 见 §6 |
| 主窗顶部 ~100 CSS px 与预览亮度差 | ⏳ 未解释完 | 见 §6（非版式问题） |
| 本轮改动后的**真机**复验 | ⏳ 未做 | 需提权重启宿主（会打断用户，先问） |

---

## 2. 交付物清单

### 2.1 皮肤插件（产物）

```
%APPDATA%\OpenRevo\plugins\
├── skin-win11-light\    manifest.json + theme.css(55,967 B) + assets\preview.png
├── skin-win11-dark\     manifest.json + theme.css(55,867 B) + assets\preview.png
├── skin-win10-light\    manifest.json + theme.css(55,776 B) + assets\preview.png
├── skin-win10-dark\     manifest.json + theme.css(55,701 B) + assets\preview.png
└── eva01-core\            （用户自己装的另类插件，当前 toggle=false，与本任务无关）
```

| 皮肤 id | 系统主题色 `--wf-accent` | 重要强调色 `--wf-important` | 圆角 | manifest `window` | `--on-accent` |
|---|---|---|---|---|---|
| `skin-win11-light` | `#0067c0` | `#ca5010`（strong `#8a3707`） | 8 / 12 px | 1120×800 | `#fff` |
| `skin-win11-dark` | `#60cdff` | `#ff9d5c`（strong `#ffc9a3`） | 8 / 12 px | 1120×800 | `#000` |
| `skin-win10-light` | `#0078d4` | `#d83b01`（strong `#9c2a00`） | 2 px | 1080×780 | `#fff` |
| `skin-win10-dark` | `#1683d8` | `#ff8c00`（strong `#ffbe7a`） | 2 px | 1080×780 | `#000` |

> 四套已装副本与根级 `<id>\theme.css` **逐字节一致**（55,967 / 55,867 / 55,776 / 55,701 B；
> sha256 前 16 位 `a472d92aa86b9c78` / `4139297fc9e33b5b` / `84c1618cb830dcfb` / `8af68ac0546c65bb`）→ 无需重装。
> （改名前的旧尺寸是 56,407 / 56,307 / 56,216 / 56,141 B，每套少的 440 B 正好等于「ID 短 1 字符 × 该字符串在文件里出现约 440 次」。）
> 宿主把 `window` 的宽高当 **CSS 逻辑像素**（Tauri `LogicalSize`），实测 150% 缩放下主窗物理 1702×1213。

### 2.2 项目树（源码 + 工具 + 文档 + 证据）

```
openrevo-plugins\                ← 项目根（2026-10-04 由 openrevo-win-skin 改名）
├── HANDOFF.md                ← 本文件
├── README.md                 项目说明（含 §1.2 配色纪律、§2.1 命名沿革、§7 验证情况）
├── build_skins.py            生成器（31,752 B / 707 行）：VARIANTS / token_block / hue_block / manifest / build_theme_css / make_preview
├── src\base.css              ← **唯一手写源**（47,088 B / 1,095 行）；每个选择器都带 __SKIN_ID__ 占位
├── skin-win11-light\         ← 四套子目录项目 = 构建产物，也是可直接安装的插件目录
├── skin-win11-dark\            每套 3 个文件：manifest.json + theme.css + assets\preview.png
├── skin-win10-light\
├── skin-win10-dark\
├── preview.html              主控台预览（654 行 / 39,818 B），可在浏览器里切四套皮肤
├── preview-mini.html         迷你面板预览（743 行 / 52,520 B），逐字复刻真实 DOM
├── docs\                     ★ **技能包 + 开发记录**（见 §2.3）
├── _tools\                   29 个脚本：构建/审计/截图/色彩普查/抓真机窗口（见 §5）
├── _extracted\               从 exe 抽出的宿主真值 CSS/JS（含 _host_mini.css 与 new-build\ 最新一轮）
├── _audit\                   四套变体 × 主窗/迷你面板的 computedStyle 审计输出
└── _shots\                   全部截图与度量图（含 -clean.png 清洁图，供 census.py）
```

### 2.3 技能包 / 开发记录（`docs\`，8 个 md + 官方手册）

| 文件 | 内容 |
|---|---|
| `SKILL.md` | **入口**：11 条硬约束 + 五步工作流 + 7 项验收清单 + 参考地图 |
| `README.md` | 索引、怎么用、维护约定 |
| `devlog.md` | 10 节开发记录：时间线 + 每一步的数字证据 + §8 未决项 + §9 宿主自动更新复核 |
| `reference\host-truth-extraction.md` | 从 exe 抽真值定式（`[path][brotli payload]`、增量解码定位流尾）、宿主 DOM/令牌/`!important` 对手规则 |
| `reference\skin-authoring.md` | manifest 双键与权威键、`--wf-hue-*` 镜像令牌架构、**特异性阶梯表**、主控台与 mini 两套配方、滚动条 |
| `reference\preview-and-audit.md` | 预览页与 URL 参数、无头 Chrome 命令、四条像素判据 |
| `reference\real-machine-verification.md` | 提权重启 / 唤醒 / 置顶抓图脚本对比、实测几何基线、度量管线、收尾清单 |
| `reference\pitfalls.md` | 29 条「现象 → 原因 → 对策」 |
| `OpenRevo_第三方插件开发手册.md` | 官方手册 v1.0（**用例 7 = 皮肤插件**，L659 附近） |

**新 Agent 的第一步**：读 `docs\SKILL.md`，需要细节再读 `docs\reference\` 对应文件。

---

## 3. 环境事实（接手前必须知道的硬事实）

| 事实 | 值 / 说明 |
|---|---|
| 宿主 exe | `D:\Program Files\OpenRevo\open-revo.exe`，**唯一真值来源**；当前 **8,496,640 B / mtime 2026-10-03 23:49:31** |
| 宿主进程 | `open-revo.exe` **requireAdministrator** → `taskkill /F` 会被拒（拒绝访问）。当前 **pid 22584 / start 23:54:17** |
| **宿主会自我更新并重启** | 开发中途真实发生过一次（8,490,496 → 8,496,640 B，进程自动重启）→ **所有字节偏移当场作废**。动手前先比 exe 的 mtime/大小与进程 StartTime；用**资产文件名里的内容哈希**（`index-<hash>.css`）判断宿主 CSS 是否变化 |
| 插件枚举时机 | **只在宿主启动时枚举插件目录**。装完不重启 = 皮肤不生效（先比 `when.ps1` 的进程启动时间与插件目录 mtime） |
| `wake_window_mode` | **只在启动时读入**。当前 `mini`（已还原用户原状，备份 `config.json.bak-skinverify`） |
| 配置 | `%APPDATA%\OpenRevo\config.json`：`active_skin="skin-win11-dark"`、`custom_plugin_toggles={"eva01-core":false}`、`power_mode=1`、`refresh_rate=300`、`gpu_mode="dgpu"` |
| 显示器 | 2560×1600 @150% → WebView2 dsf=1.5 |
| 主窗几何 | 物理 1702×1213 = **CSS 1135×809**（客户区 ≈1120×800 CSS）；隐藏时被停在 `(-32000,-32000)` 缩成 237×39 |
| mini 几何 | 物理 615×916 = **CSS 410×610**（宽固定 410，高由宿主的 `ResizeObserver` + `fit_mini_window_height` 动态定；变化 >250px 才触发） |
| mini 内容高度 | 宿主自身内容 **410×621** vs 窗口 610 → **纵向滚动是宿主固有的**（余量仅 11px）。早期文档里的 663 / 666 是被诊断代码污染的读数，见 §11.5 |
| ⚠️ 本机模型**不能读图** | `read_image` 报 `does not declare image input` → 所有观感判读只能靠直方图 / 列行亮度签名 / 分块 MAE / ASCII 渲染（`_tools\prof.py`、`cmp.py`、`ascii.py`） |
| ⚠️ 抓真机图会**弹窗+置顶** | 会打断用户。非必要不抓；必须抓时按 §5 用提权脚本并事后还原 |

---

## 4. 怎么继续（命令速查）

```bash
cd D:\LIPis\Documents\code\openrevo-plugins

# 1) 改皮肤：只改 src\base.css（结构）和 build_skins.py 的 VARIANTS（四套差异）
python build_skins.py --install      # 生成四套 skin-*\ 并安装到 %APPDATA%\OpenRevo\plugins\
python build_skins.py --preview      # 只重建 assets\preview.png

# 2) 本地验证（不打扰用户，首选）
bash _tools/verify.sh                # 验收总闸：重跑两页审计 + 逐条断言（NO_AUDIT=1 复用已有产物）——只认它的 exit code
bash _tools/audit.sh                 # 四套变体 computedStyle 审计 → _audit\<id>.audit.txt
PAGE=preview-mini.html bash _tools/audit.sh   # 迷你面板四套 → _audit\mini-<id>.audit.txt
PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8   # 回归压测（改过预览页/皮肤 CSS 后必跑）→ 须「异常 0 次」
bash _tools/shots.sh                 # 批量截图（含 <id>-clean.png）
python _tools/census.py _shots\mini-skin-win11-dark.png   # 像素级色相族普查（验收「只剩两个色族」）
# 或直接开 preview.html / preview-mini.html，点顶部按钮切四套皮肤看

# 3) 让宿主加载新皮肤（必须重启，且要提权）
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','D:\LIPis\Documents\code\openrevo-plugins\_tools\kill-and-start.ps1'"
#    ⚠️ 若 active_skin 指向的是**已被删掉的旧 ID**（改名/换 ID 后的常见残局），光重启不够 —— 顺序必须是「停 → 改 → 启」：
powershell -NoProfile -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 skin-win11-dark dry   # 先空跑看计划
powershell -NoProfile -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 skin-win11-dark       # 真跑（自己提权停宿主、改、启）

# 4) 真机取证（会置顶弹窗，谨慎）
powershell -File _tools\allwins.ps1        # 列全部可见窗口：hwnd/pid/class/title/rect
powershell -File _tools\when.ps1           # 宿主进程 StartTime（比插件 mtime 判断是否需重启）
powershell -File _tools\who.ps1            # z 序 / 遮挡确认
#   提权：唤醒大面板并抓图；或对指定 hwnd 置顶抓图
#   _tools\wake-grab-dash.ps1     → _shots\real-dash-1500.png
#   _tools\pin-grab-hwnd.ps1 -Hwnd <n> -Out <png>
```

**验收信号（照 `docs\SKILL.md` 的 7 项清单）**：构建产物与已装副本逐字节一致；四套审计 `root.blur=none`、
`root.bg` 为该变体实色、`--theme-pwr` = 该变体 `--wf-important`（不是宿主 mono 白）、
`--theme-{gpu,hz,lux,kbd,bat}` 四套全等于 `--wf-accent`、`dom.hueFamilies = 2`（主窗与迷你面板都是）；
`census.py` 对 `mini-<id>.png` 报 **色族数量 = 2**；真机主窗列边缘在 CSS `224.7/225.3` 最强、
宿主调色板计数为 0；`config.json` 已回到用户原状。

> ⚠️ **只看 `dom.hueFamilies = 2` 不算通过**：坏读数里全是宿主原色时族数**也恰好是 2**（pitfalls #35 / #39）。
> 必须同时满足正向条件 —— `skin_active` = 本变体、`rules_applied = 118`、`settle.remounts = 1`（迷你）、
> `--theme-*` 六槽、`ready.dot` / `themeBtn.cyber` / `oem.*` / `sponsorHeart` 五个探针色值。
> 这些已全部落成 `_tools/verify.sh` 的 **132 条断言**（主窗 + 迷你各四套），跑一次即可，不必再用眼睛对表。

---

## 5. `_tools\` 脚本地图（34 个，挑重要的）

| 用途 | 脚本 | 说明 |
|---|---|---|
| 构建/安装 | `build_skins.py --install` | 唯一正确安装路径 |
| **预览审计** | **`verify.sh`**、`audit.sh`、`_stress.sh`（并发压测抓偶发竞态）、`shots.sh`、`shoot1.sh <page> <name> <w> <h> <query> <skin\|off> [dsf]`、`repro-btn.html` | 无头 Chrome，不打扰用户 |
| 度量 | `cmp.py`（分块 MAE）、`prof.py`（行/列亮度 ASCII 签名）、`ascii.py`（ASCII 渲染）、**`census.py`（像素级色相族普查）** | **模型不能读图，这几件是眼睛** |
| 重启宿主 | **`kill-and-start.ps1`（提权，可靠）**、`restart.ps1`（走 `Stop-ScheduledTask`，进程没死会跳过重启） | 宿主需管理员权限 |
| **切 `active_skin`** | **`set-active-skin.ps1 [skin] [dry]`** | 停宿主 → 备份 → 只替换 `active_skin` 一个字段（其余字节不动）→ 回读复验 → 启宿主；宿主没停掉就拒绝改（pitfalls #37）。**只在 `active_skin` 指向已删旧 ID 时用** |
| 列窗口 | `allwins.ps1`（全部可见窗口）、`listwins.ps1`、`wins.ps1`、`who.ps1`、`when.ps1` | 均带 `CharSet=CharSet.Unicode`，中文标题才读得全 |
| **抓真机图** | **`wake-grab-dash.ps1`**（唤醒大面板 + 提权置顶 + 抓图 + 还原）、**`pin-grab-hwnd.ps1 -Hwnd <n> -Out <png>`** | 这两个是唯一可靠路径 |
| 抓图反例（别用） | `capwin.ps1`（`PrintWindow` 对 Tauri 返回全 alpha=0 黑图）、`min-grab.ps1`（Tauri 不能最小化）、`move-grab.ps1`、`show-app.ps1`（只 show **不置顶** → 会拍到自己的浏览器）、`pin-grab.ps1`（内部 `Say()` 未定义） | 全部写进 `pitfalls.md` |
| 已废弃 | `cdp.py`、`relaunch-debug.ps1`、`scan_ebwebview.py`（Tauri/wry 不理 `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS`） | 别复活，注册表项已清理 |

> `_tools\*.ps1` 含中文注释的**必须存成 UTF-8 BOM**，否则 PS 5.1 按 GBK 解码报
> `Get-Process : 无法对参数 Name 执行参数验证。参数为 Null 或空`。

---

## 6. 未决项 / 下一步建议（按优先级）

1. **等用户观感反馈**（当前唯一出口）。要调的话集中在：迷你底部那条横向滚动条、主窗顶部 ~100 CSS px 的亮度差、
   侧栏宽度（`--wf-sidebar-w:224px`）、**重要强调色的取值与用量**（`--wf-important`，见 §11）、圆角。
2. **mini 底部细横向滚动条**（用户已说「先不动」）。成因链已查清：
   宿主自身内容 **410×621** CSS > 窗口 610（余量仅 11px）→ 纵向滚动固有；皮肤把滚动条从宿主 4px 加宽到 12px 后引出横条
   （`src\base.css:97` `::-webkit-scrollbar{width:12px;height:12px}`、`:104` thumb、`:494` `scrollbar-width:thin`）。
   修法（未做）：在 mini 根加 `overflow-x: hidden !important`、把滚动条收回 4–8px、或压掉 §8 的内边距让内容 ≤610。
   （数字更正与取证过程见 `docs\devlog.md` §6.1、`HANDOFF.md` §11.5。）
3. **主窗顶部 ~100 CSS px 与预览有亮度差**（分带 MAE：顶部 46.45 vs 侧栏 16.48、底部 9.90）。
   已知**不是**版式问题（224.7 边缘在真机存在）；怀疑抓图时宿主停在**别的 tab 页**导致内容区不同。
   下次取证时先切到 `overview` tab 再抓，可一次性排除。
4. **OEM 助手弹窗 / 「极客调校」浮层**只做了近似（`[style*="position: fixed"]` 手臂），未真正复刻——有相关需求要重新取真值。
5. 可选清理：`_extract\`（工作区根，29 MB 的 V8 代码缓存扫描日志，仅用于证明手册示例类名在发行版不存在）可删。
   `docs\` 只在权威树 `D:\LIPis\Documents\code\openrevo-plugins\` 维护 —— harness 工作区那棵已因改名脱钩，**别再去同步它**。

---

## 7. 回退 / 还原（用户现场）

* **停用皮肤**：宿主【插件】页取消勾选（宿主会 `remove()` 掉 `<style id="openrevo-custom-skin">`，立即恢复原观感）。
* **配置还原**：`wake_window_mode` 已是用户原值 `mini`；备份在 `%APPDATA%\OpenRevo\config.json.bak-skinverify`（本轮改名前的备份是 `config.json.bak-skinrename`）。
* **彻底移除**：删除 `%APPDATA%\OpenRevo\plugins\skin-win11-light|skin-win11-dark|skin-win10-light|skin-win10-dark` 四个目录，重启宿主。
  （改名前的旧目录 `win11-fluent-*` / `win10-fluent-*` 已在本轮删除，不需要再动。）
* **动过 `config.json` 必须还原并留备份**（`config.json.bak-*`）——这是硬约束第 10 条。

---

## 8. 回归基线数字（换了环境要重新测，别当常量）

| 指标 | 本次值 |
|---|---|
| 主窗（真机）几何 | 1702×1213 物理 = 1135×809 CSS @150% |
| 主窗列边缘（CSS） | `224.7/225.3`（最强，= `--wf-sidebar-w`）、245.3/246.0、668.7、676.7、1083.3、1100.0 |
| 主窗 vs 预览 | 对齐 dx=9 dy=0；**全局 MAE 22.16**；分带：侧栏 16.48 < 内容 23.58 < 顶部(100CSS) 46.45；底部 9.90 |
| 主窗调色板 | `(32,32,32)` 30.25%、`(44,44,44)` 19.04%、`(41,41,41)` 16.96%、`(56,56,56)` 6.08%；**宿主色计数全 0** |
| mini（真机） | 615×916 物理 = 410×610 CSS；`(44,44,44)` 24.45%、`(32,32,32)` 18.61%、`(56,56,56)` 14.06%；宿主色 ≈0 |
| mini vs 预览 | 分块 MAE **19.98**；滚动条滑块约占半高 → `scrollHeight ≈ 1180–1230` |
| 宿主 CSS（抽出的真值） | 50,997 B / 333 个 `{`；sha256 `4cf6ca2416e263dd…`（与上一构建逐字节相同） |
| 宿主 CSS 资产 | `assets/index-C535NsqC.css` @ 6941209（负载 @ 6941234）；JS `index-BzQyTcpV.js` @ 7124459 |
| 关键真值 | exe 内 Rust 明文字符串 `plugin_type` @ 6887819、`load_plugin_theme_css` @ 6923005 ⇒ manifest 权威键是 `plugin_type`（仍双发 `type` 对冲） |

---

## 9. 证据文件索引（出问题先看这些）

| 文件 | 是什么 |
|---|---|
| `_shots\real-dash-1500.png` | 真机主窗成品（侧栏生效、不透明的像素证据） |
| `_shots\real-dash-aligned.png` | 与预览对齐后的差分底图 |
| `_shots\prev-dash-1120at15.png` | 预览按真机 dsf=1.5 / 1120×800 渲染 |
| `_shots\real-mini-clean.png` | 真机迷你面板（无遮挡） |
| `_audit\mini-<id>.audit.txt` | 四套变体 computedStyle 审计（`root.bg`/`root.blur`/`--theme-pwr`/`quickActive.bg`） |
| `_extracted\index-C535NsqC.css` | 宿主完整 CSS（真值） |
| `_extracted\host-shell.css` | 宿主外壳/主题子集（14,584 B / 86 行，预览页加载它） |
| `_extracted\new-build\` | 宿主自我更新后的重新抽取（CSS/JS） |
| `docs\devlog.md` §9 | 宿主自动更新复核全过程（旧/新对照表） |
| 工作区根 `_extract\scan2.log` | 29 MB：V8 代码缓存扫描输出，用于证明手册示例类名确实不存在 |

---

## 10. 本任务明确**没有**做的事（不要以为已经做了）

* 没有改宿主 exe / 没有注入任何 hook；一切是**插件文件 + 宿主自身机制**。
* 没有复刻 OEM 助手弹窗与「极客调校」浮层的真实外观（只做了近似手臂）。
* 没有修 mini 底部横滚动条（用户决定暂缓）。
* 没有拿到用户对四套皮肤的观感确认。
* 没有在本轮宿主更新后**重新抓真机像素**（只用「CSS 资产内容哈希未变、逐字节相同」推断皮肤不受影响）。
  如需铁证，切到 `overview` tab 后重抓一次即可（会弹窗，先问用户）。
* **二色体系改造（§11）只做了无头取证，没有在改完后重抓真机图**——需要提权重启宿主才会加载新皮肤，会打断用户，未经同意不做。

---

## 11. 二色强调体系（2026-10-04 · 本轮改动全在此）

**用户口径**：「mini 模式只使用系统主题色进行强调」→「不要这么多颜色进行装饰，一个系统主题色加一个重要强调色就行」。

### 11.1 规则

| 令牌 | 角色 | 适用范围 |
|---|---|---|
| `--wf-accent` | **系统主题色** | 一切可交互 / 已选中 / 已启用：导航选中态、tab 胶囊、按钮选中、开关、焦点环、滑块、六个指标卡（性能模式除外） |
| `--wf-important` | **重要强调色**（暖橙，源自原来的 `hue_pwr`） | 只用于性能 / 功率与需要注意的状态：mini 性能模式卡、`active-beast` 狂暴档、功率徽标、休眠守卫、OEM 服务运行中、OEM 弹窗描边 |
| `--wf-ok/-warn/-error` | 状态语义色 | 只表达真实状态（设备开/关、温度告警），不得当装饰 |

派生令牌：`--wf-important-soft/-border/-glow`（= `--wf-hue-pwr-dim/-border/-glow`）与 `--wf-important-strong`（每变体对比度调过的深/浅号）。

### 11.2 令牌映射（改在 `build_skins.py`）

* `token_block()`：`hue_block("pwr", v["important"])` + `for _hue_slot in ("gpu","hz","lux","kbd","bat"): hue_block(_hue_slot, v["accent"])`。
  **六个 `--theme-*` 槽位名一个都没删**（宿主 mini 的内联样式读的就是这六个名字），只把取值收敛。
* 宿主私有 `--accent-*`（主控台自绘部件的电源徽标 / 休眠守卫 / 电池模式单选读它）：
  `pwr`、`beast` → `important`；`gpu`、`cool`、`rgb`、`lux` → `accent`（各带 `-dim`/`-border`/`-glow`）。
* `VARIANTS` 里删掉了 `hue_pwr/hue_bat/hue_gpu/hue_hz/hue_kbd/hue_lux`，新增 `important` + `important_strong`：
  win11-light `#ca5010`/`#8a3707`；win11-dark `#ff9d5c`/`#ffc9a3`；win10-light `#d83b01`/`#9c2a00`；win10-dark `#ff8c00`/`#ffbe7a`。

### 11.3 `src\base.css` 的改动

* **§5 性能模式选择器**：原来四个档位四种颜色（绿/蓝/红/强调色）→ 合并成两组：
  `active-office / active-balance / active-custom / .remote-office` 走 accent 三件套；`active-beast` 走 important 三件套。
* **§8.1**：新增「★ 二色强调体系」注释，说明六个槽位名保留、取值收敛。
* **§8.4**（宿主内联硬编码色，只能用 `!important` 打掉）：
  * READY 圆点 `#34d399` / 文字 `#6ee7b7` → accent（`.m-quick-grid + div > div:last-child > div|span`）；
  * 主题配色切换按钮 cyber 态 → accent（按 `title*="极简纯单色"` 命中）；
  * OEM 徽标：`title*="正在运行"` → important 三件套；`title*="已被屏蔽"` → accent 三件套；
  * OEM 助手弹窗 / 极客调校浮层（`[style*="position: fixed"]`）描边 → `--wf-important-border`；
  * 头部赞助心形 `#f43f5e` → accent（与主窗侧栏 `.sponsor-tab-heart` 同色）。
* **主窗 `.sponsor-tab-heart`**：改成 `color: var(--wf-accent) !important; fill: currentColor !important; filter: drop-shadow(...) !important`
  ——宿主在 `[data-theme=mono]` 下有同特异性 + `!important` 的白色规则，靠皮肤样式表后注入取胜。

> ⚠️ **踩坑**：`--wf-accent-glow` **不存在**。实际存在的 accent 令牌是
> `--wf-accent` / `-hover` / `-press` / `-soft` / `-soft-strong` / `-border` / `-strong` / `-shadow`(rgba accent .22) / `-on-accent`。
> 曾误用 `-glow` 导致 `box-shadow` 无效（invalid at computed-value time，静默变 `none`）。

### 11.4 验证（可重跑）

* **DOM 普查**：`audit.sh` 里的 `dom.hueFamilies` —— 主窗四套 = 2、迷你面板四套 = 2。
  主窗的 2 族 = 210° accent + 120° 状态点绿（`--wf-ok`，4 个 8px 圆点，**有意保留**：那是设备开/关的真实状态，不是装饰）；
  隐藏夹具里的 `active-beast` 单独印证 important：`rgba(255,157,92,.14)` + `rgb(255,201,163)`。
* **像素普查**：`python _tools\census.py _shots\mini-<id>.png` → **色族数量 = 2**
  （win11-dark：198.9° 蓝青 86.16% + 23.1° 橙 13.84%；改造前真机基线是青/蓝/橙红/绿/粉紫/黄 6 族）。
* **四套变体的干净读数**（2026-10-04 重跑，删掉诊断实验之后）：

  | 变体 | `--theme-pwr` | 其余五槽 = `--wf-accent` | `ready.dot` / `themeBtn.cyber` / `oem.blocked` / `sponsorHeart` | `oem.running` | `dom.hueFamilies` |
  |---|---|---|---|---|---|
  | skin-win11-light | `#ca5010` | `#0067c0` | `rgb(0,103,192)` | `rgb(202,80,16)` | 2 |
  | skin-win11-dark  | `#ff9d5c` | `#60cdff` | `rgb(96,205,255)` | `rgb(255,157,92)` | 2 |
  | skin-win10-light | `#d83b01` | `#0078d4` | `rgb(0,120,212)` | `rgb(216,59,1)` | 2 |
  | skin-win10-dark  | `#ff8c00` | `#1683d8` | `rgb(22,131,216)` | `rgb(255,140,0)` | 2 |

  **迷你另有前置条件**：`skin_active` = 本变体 ID、`rules_applied = 118`、`settle.remounts = 1`（见 §11.6）。
  这张表已**逐条落成可执行断言**：`bash _tools/verify.sh` → 「合计 132 条断言，失败 0 条」。
  以后验收只认这个 exit code，不再用眼睛对表 —— 负向条件（族数=2）会骗人，见 §11.5 第 2 条。

### 11.5 顺手修掉的两个**测量**缺陷（2026-10-04）

收敛配色时，为了让审计能回答「解析器留下了哪些规则」，`preview-mini.html` 的 `runAudit()` 里有一段
**决定性实验 A~J**：新建同 class 的按钮、注入 `!important` 测试样式、把 `theme.css` 规则原文重灌一遍、
clone 节点、重新挂载、触碰 class……用来定位「`.m-btn-action` 为什么不吃皮肤样式」。

问题解决后这段代码**没删**，后果是：

1. **污染被测对象** —— 它往 `.m-grid-4` 里 append 了新按钮和克隆节点，把 `.mini-drawer-content` 撑高 45px。
   于是审计一直报 `content.size = 410×666`，而**真实值是 `410×621`**（删掉实验后重跑）。
   文档里流传的「宿主内容 663 高」「差 56px」都源自这个被污染的读数；真实余量只有 **11px**。
2. **陈旧产物冒充通过** —— `_audit/mini-skin-win10-light.audit.txt` 是更早一次运行的残留（当时皮肤没注入成功），
   里面全是宿主原色（`#38bdf8`、`rgba(99,102,241,.25)`、纯白），但因为 `dom.hueFamilies` 恰好也是 2，
   看上去「通过」。**负向条件（族数=2）挡不住这种错误**，必须配正向条件（`mini.--theme-pwr` 必须等于该变体的 important 值）。
   > **【更正 · 2026-10-04（下一轮）】**「陈旧产物」这个归因**不成立**：同一现象已当场复现
   > （`PAGES=preview-mini.html:mini bash _tools/_stress.sh 24 6`，24 次异常 4 次 ≈ 17%），是
   > **运行时注入 `<style>` 后、解析期已解析过样式的那部分元素偶发不被重新失效**的样式失效竞态
   > （当场新起 Chrome、`sheet rules=118` 与通过态一致，排除了「读旧文件」和「样式表被截断」）。
   > 修复 = `preview-mini.html` 的 `settleStyle()`（`data-skin` 落定后原地摘挂舞台子树）；审计产物新增
   > `settle.remounts` 计数。详见 `docs/reference/pitfalls.md` #39。「必须配正向条件」这条纪律不变 ——
   > 它正是当初发现这个缺陷的探针。

处置：删掉 §636–709 的 A~J 实验（`preview-mini.html` 743 → 668 行），只保留**只读**探针
（`probe.hits` 规则命中列表、`sheet[i]` 解析统计、残留白检查、色彩普查）；四套变体重跑后
`content.size` 从 666 变为一致的 **621**，其余验收字段与预期全部吻合。

> 纪律：**放进验收工具的诊断代码只准读，不准改 DOM**。确需改就在 `finally` 里还原。
> 问题查清后要主动删掉实验代码 —— 留在那里的诊断会变成下一次的假数据。

### 11.6 验收升级为可执行断言（2026-10-04 第二轮）

验收表原来只是「写在文档里的一张表」，靠人读产物对数字。两个后果已经付过学费：
§11.5 第 2 条的假通过（族数恰好也是 2），以及那张表在多次重跑后**没人能证明每一条都被核过**。

现在落成两个脚本：

* **`_tools/verify.sh`** —— 验收总闸。先重跑两页审计（`NO_AUDIT=1` 复用已有产物），再逐条断言：
  主窗 9 条 × 4 套（`container.blur/display/cols/areas/alpha`、`rules_applied`、`--wf-important`、
  `--theme-pwr`、`dom.hueFamilies`）、迷你 22 条 × 4 套（`skin_active`、`rules_applied`、`settle.remounts`、
  `root.bg/bgImage/blur/size`、`content.size`、族数、`--theme-*` 六槽、两个令牌、
  `ready.dot` / `themeBtn.cyber` / `oem.blocked` / `oem.running` / `sponsorHeart` / `quickActive` 探针色值）
  \+ 像素普查 4 条 = **132 条**。末行报「合计 N 条断言，失败 M 条」，`exit 1` 即**不许交付**。
  实测（2026-10-04 第二轮，全量重跑）：**132 条 / 失败 0**。
* **`_tools/_stress.sh`** —— 并发压测。`PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8`：
  先单跑一份参考，再 8 并发跑 48 次，逐次与参考 `diff`，末尾报「异常 M 次」。
  **顺序连跑 30 次都抓不到的 17% 抖动，它一轮就出 4 次** —— 排「偶发」问题，先得把复现变成工具。

纪律也一并写进文档（而不是留在记忆里）：动过预览页或皮肤 CSS **必须**跑压测；
**只有 `verify.sh` 的 exit code 才算验收结论**，`dom.hueFamilies = 2` 单独出现不算。

### 11.7 真机取证：外观上没有任何东西在等重启（2026-10-04 第二轮）

本轮二色体系改完后一直只做过无头取证，于是提权抓了真机大面板。结论有两层：

* **改名是行为中性的，所以"换没换皮肤"是伪命题**：旧 ID `dist\win11-fluent-dark\theme.css` 与新
  `skin-win11-dark\theme.css` 都是 1292 行、374 个 `--wf-*` 令牌、色字面量计数一致；裸 diff 440 行全是 ID 串，
  **ID 归一后 diff = 0 行**。宿主内存里那份（旧 ID，09:48 启动时枚举到的）渲染结果与新的逐像素一致。
* **同面 A/B（同尺寸 1702×1213）也印证了**：与 10-03 19:42 的旧图相比 MAE 全图 2.59、左栏 1.00、顶栏 1.30、
  内容区 2.99；差异 >40 的像素只占 2.845%，集中在内容区图表带（navy bbox `(379,759)-(1659,872)`）。
  ⇒ 皮肤外壳没变，变的是面板里的动态内容。

另外两件顺带查实的事实：

* 宿主 **12:06:33 自己**把 `config.json` 的 `active_skin` 写成了 `skin-win11-dark`（3678 B）——
  悬空 ID 自愈，且**不是我改的**（无 `config.json.bak-setskin-*`，宿主从未停过）。
* `read_image` **实测不可用**（`model "cn:deepseek-v4.1-flash" does not declare image input`）——
  观感问题只能转成数字/ASCII，别指望"看一眼图"。
* 抓图副作用：`wake-grab-dash.ps1` 只还原 z 序、**不还原停车位置**，抓完大面板会留在桌面上（需手动收起）。

细节与教训见 `docs/reference/real-machine-verification.md` §7 / §8 / §9。
