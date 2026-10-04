---
name: openrevo-skin-plugin
description: 为 OpenRevo（open-revo.exe）开发、修改、验证 Windows 组件 UI 皮肤插件（skin plugin）。当任务涉及 OpenRevo 皮肤 / theme.css / manifest.json 的 skin 类型 / 把宿主改成 WinUI、Fluent、原生 Windows 观感 / 宿主主控台与迷你双面板的样式与不透明化 / 从 exe 里抽宿主真值 CSS / 真机截图与预览逐像素比对时，使用本技能。
---

# OpenRevo 皮肤插件开发技能

本技能沉淀自一次完整的实战：从零做出**四套 WinUI/Fluent 皮肤**（`skin-win11-light` / `skin-win11-dark` /
`skin-win10-light` / `skin-win10-dark`），把宿主主控台重排成 **WinUI3 左侧导航栏 + 完全不透明**，
并让**迷你面板**同步改造，最后在真机上完成像素级取证。

* 项目根目录（下文相对路径都基于它）：`D:\LIPis\Documents\code\openrevo-plugins\`
  （harness 工作区 `D:\LIPis\Documents\deepseek-harness\default-workspace\openrevo-win-skin\` 是**改名前的过期镜像**，别拿它当盘）
* 规范来源：`docs\OpenRevo_第三方插件开发手册.md`（v1.0，**用例 7 = 皮肤插件**，见其 L659 附近）
* 版式参照物（只读原型）：`D:\LIPis\desktop\openrevo ui`
* 宿主：`D:\Program Files\OpenRevo\open-revo.exe`（**唯一真值来源**，版本随发行变动）
* 产物安装位：`%APPDATA%\OpenRevo\plugins\<skin_id>\`；宿主配置：`%APPDATA%\OpenRevo\config.json`

## 30 秒上手

```bash
cd <项目根目录>
python build_skins.py --install      # 生成 + 安装四套皮肤到 %APPDATA%\OpenRevo\plugins\
bash _tools/verify.sh                # 验收总闸：重跑两页审计 + 逐条断言（132 条），全绿才算过
bash _tools/audit.sh                 # 无头 Chrome 跑四套变体的 computedStyle 审计 → _audit\<id>.audit.txt
# 装完必须重启宿主（宿主只在启动时枚举插件目录），走提权脚本：
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','<项目根目录>\_tools\kill-and-start.ps1'"
```

看效果：双击 `preview.html`（主窗）、`preview-mini.html`（迷你面板），顶部按钮即时切换四套皮肤。

## 动手前必读的硬约束

1. **宿主是唯一真值**：手册 §7 示例里的 `.overview-main-grid` / `.sensor-gauge-cluster` / `.cooling-fan-card` /
   `.power-mode-selector` 在发行版里**根本不存在**（在 WebView2 V8 代码缓存里逐字检索命中数为 0）。
   以 `_extracted\index-*.css` 的真实选择器为准，手册示例名只能当前向兼容层。详见 `reference/host-truth-extraction.md`。
2. **`theme.css` 必须是单文件**：宿主把整份 CSS 文本注入 `<style id="openrevo-custom-skin">`，
   `@import` 会按宿主文档 base URL（`tauri://`）解析，取不到插件目录里的相对文件。
3. **命名空间只能用 `[data-skin="<id>"]`**（手册 §7 硬性要求，皮肤互斥）。
   **绝不要**写 `body:not([data-skin])` 之类兜底手臂，那会误命中别的皮肤。
   挂到 `body` 上的浮层用 `body[data-skin="<id>"] …` 与 `body:has([data-skin="<id>"]) …` 两个手臂覆盖；
   `data-skin` 从来不写在 `<html>` 上。
4. **宿主大量使用 React 内联 `style={{…}}`**（`.acrylic-container` 的 `display:flex`、迷你根的
   `background:rgba(12,15,22,.96)`/`backdrop-filter:blur(28px)`/`width:100vw`…）→ 想压过它**只能**用 author `!important`。
5. **CSS 自定义属性的层叠陷阱**：元素上的局部声明**胜过**继承值。宿主在 `.mini-drawer-root` 与
   `[data-theme=mono|cyber] .mini-drawer-root` 上**重新声明**整套 `--theme-*`，所以皮肤必须在
   `[data-skin="<id>"] .mini-drawer-root[data-theme]`（0,3,0）这一层再声明一遍，并读**镜像变量** `--wf-hue-*`。
   六个槽位名 `pwr/gpu/hz/lux/kbd/bat` **一个都不能删**（宿主 mini 内联样式按名字取值），只能改它们的**取值**。
6. **宿主没有全局 `*{box-sizing:border-box}`** → 需要就自己写；**永远不要**给 `.mini-drawer-root` 加 `border`。
7. **宿主只在启动时枚举插件目录**：装完不重启，旧进程里根本没有新皮肤（先比 `_tools\when.ps1` 的进程启动时间
   与插件目录 mtime）。宿主进程是 `requireAdministrator`，`taskkill` 会被拒 → 用提权 `_tools\kill-and-start.ps1`。
   若 `active_skin` 指向的是**已被删掉的旧 ID**（换 ID / 改名的常见残局），光重启不够——宿主只在启动时读一次，
   而且**运行中会周期性整份回写 config**，所以顺序必须「停 → 改 → 启」，用 `_tools\set-active-skin.ps1`（见 pitfalls #37）。
8. **本机模型不支持图片输入**（`read_image` 报 `does not declare image input`）：所有观感判读只能靠
   直方图 / 列行亮度签名 / 分块 MAE / ASCII 渲染。见 `reference/real-machine-verification.md`。
9. **判读真机截图前先确认 z 序与遮挡**：`WindowFromPoint` 会**跳过** Tauri 的透明/分层窗口（回报的是下面的窗口），
   不能当 z 序证据；抓面板前必须**置顶**（提权脚本），否则拍到的是你自己浏览器。见 pitfalls 第 8/10 条。
10. **改完要能回到用户原状**：动过 `config.json` 的字段（例如为展开大面板临时改 `wake_window_mode`）必须还原，
    并留备份（`config.json.bak-*`）。
11. **宿主会自我更新并重启**：开发中途实测发生过一次（exe 于 `23:49:31` 被换成 8,496,640 B，进程 `23:54:17` 自动重启），
    所有**字节偏移/文件大小**类断言当场作废。动手前先比 exe 的 mtime/大小与进程启动时间；
    用**资产文件名里的内容哈希**（`index-<hash>.css`）判断宿主 CSS 有没有变——本次哈希没变、抽出来与旧构建逐字节相同，
    所以皮肤不受影响。详见 `real-machine-verification.md` §2.1。

## 配色纪律：只有两个强调色（硬约束）

用户口径（m00001 / m00053）：**「mini 模式只使用系统主题色进行强调」→「不要这么多颜色进行装饰，
一个系统主题色加一个重要强调色就行」**。

| 令牌 | 角色 | 适用范围 |
|---|---|---|
| `--wf-accent` + 派生 | **系统主题色** | 一切可交互 / 已选中 / 已启用：导航、tab 胶囊、按钮、开关、焦点环、滑块、指标卡（性能模式除外） |
| `--wf-important` + 派生 | **重要强调色**（暖橙 `--wf-hue-pwr`） | 只用于性能 / 功率 / 需要注意：性能模式卡、`active-beast` 狂暴档、功率徽标、休眠守卫、OEM 运行中 |
| `--wf-ok` / `-warn` / `-error` | 状态语义色 | 只表达真实状态（设备开/关、告警），**不得当装饰** |

发令牌时六槽只喂两个色：`hue_block("pwr", v["important"])` + 其余五个 `hue_block(k, v["accent"])`；
宿主私有 `--accent-pwr/-beast` → important、`--accent-gpu/-cool/-rgb/-lux` → accent。
**唯一有意保留的第三个颜色**是主控台 `.status-dot.dot-on` 的 `--wf-ok` 绿（4 个 8px 圆点）——那是设备开关的真实状态。
机制、内联覆盖清单与踩坑见 `reference/skin-authoring.md` §3.1 / §6.4；验收口径见下面的清单。

## 标准工作流

| 步骤 | 做什么 | 去哪看 |
|---|---|---|
| 1. 取真值 | 从 `open-revo.exe` 抽宿主 CSS/JS（`[path][brotli payload]` 格式）、核对真实类名与宿主 `!important` 对手规则 | `reference/host-truth-extraction.md` |
| 2. 写样式 | `src/base.css`（纯结构，全部选择器带 `__SKIN_ID__` 占位）+ `build_skins.py` 的 `VARIANTS` 令牌表 | `reference/skin-authoring.md` |
| 3. 本地预览 | `preview.html` / `preview-mini.html` 用**真实宿主类名 + 真实宿主 CSS** 复刻双面板，注入方式与宿主一致（`<style>` textContent，不是 `<link>`） | `reference/preview-and-audit.md` |
| 4. 无头审计 | `bash _tools/audit.sh` 取 computedStyle；用直方图/边缘签名/差分判断不透明与版式 | `reference/preview-and-audit.md` |
| 5. 真机取证 | 提权重启 → 唤醒/展开 → 置顶抓图 → 直方图 + 列行边缘 + 与预览分块 MAE | `reference/real-machine-verification.md` |

## 验收清单

- [ ] `python build_skins.py --install` 后 `<id>\theme.css` 与 `%APPDATA%\OpenRevo\plugins\<id>\theme.css` **字节一致**
- [ ] 四套变体审计里 `root.blur = none`、`root.bg` = 该变体实色；迷你 `--theme-pwr` 等读的是**皮肤镜像值**而不是宿主 mono 的 `#ffffff`
- [ ] **配色**：`PAGE=preview-mini.html bash _tools/audit.sh` 与 `bash _tools/audit.sh` 四套全部 `dom.hueFamilies = 2`；
      `python _tools\census.py _shots\mini-<id>.png` 报**色族数量 = 2**；
      六个 `--theme-*` 里只有 `pwr` 是暖橙，`gpu/hz/lux/kbd/bat` 全等于 `--wf-accent`；
      `--accent-pwr = --accent-beast = --wf-important`、`--accent-gpu/-cool/-rgb/-lux = --wf-accent`
- [ ] **正向条件**（**只看族数=2 不算过** —— 坏读数里全是宿主原色时族数也恰好是 2，见 `pitfalls.md` #35 / #39）：
      迷你 `skin_active` = 本变体、`rules_applied = 118`、`settle.remounts = 1`、`content.size = 410x621`；
      `ready.dot` / `themeBtn.cyber` / `oem.blocked` / `sponsorHeart` = accent、`oem.running` = important
- [ ] **以上全部由 `bash _tools/verify.sh` 断言**（主窗 + 迷你各四套，共 132 条）；动过预览页或皮肤 CSS 后，
      另跑 `PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8` 确认「异常 0 次」（偶发竞态只有它能抓）
- [ ] 预览页注入皮肤后，没有元素停在 `buttonface rgb(240,240,240)`
- [ ] 真机主窗：列边缘在 CSS **224.7 / 225.3** 处最强（侧栏生效）、宿主调色板 `(11,13,17)/(16,18,25)/(26,28,35)…` **计数为 0**
- [ ] 真机迷你面板：宿主色 ≈ 0、`(32,32,32)`/`(44,44,44)` 占比与预览一致（分块 MAE ≈ 20 以内）
- [ ] 窗口 < 760 CSS px 时导航自动退回顶部横条（`@media (max-width:760px)` 回退），且迷你面板完全不受侧栏规则影响
- [ ] `config.json` 回到用户原状（`active_skin` 是用户选的那套；临时改过的字段已还原）

## 参考文件地图

```
docs\
├── SKILL.md                              # 本文件：硬约束 + 工作流 + 验收清单
├── devlog.md                             # 开发记录：时间线 + 每一步的数字证据
├── OpenRevo_第三方插件开发手册.md          # 官方手册 v1.0（用例 7 = 皮肤）
└── reference\
    ├── host-truth-extraction.md           # 从 exe 抽宿主 CSS/JS、DOM 结构、宿主令牌与对手规则
    ├── skin-authoring.md                  # manifest/目录规范、令牌架构、特异性阶梯、双面板改造配方
    ├── preview-and-audit.md               # 预览页能力、无头 Chrome 命令、审计与像素判据
    ├── real-machine-verification.md       # 真机流程：提权重启/唤醒/置顶抓图/度量（含实测基线数字）
    └── pitfalls.md                        # 踩坑总表（按「现象 → 原因 → 对策」）
```

## 现状快照（本技能写下时）

* 四套皮肤已安装并被用户在宿主【插件】页选用（`active_skin = skin-win11-dark`），皮肤互斥、切换 0ms 热加载。
* 主窗：WinUI3 左侧栏（224px）+ 完全不透明，**真机已确证**（`_shots\real-dash-1500.png`）。
* 迷你面板：同步 WinUI3 化 + 不透明，**真机已确证**（`_shots\real-mini-clean.png`）。
* **配色已收敛为二色体系**（2026-10-04）：迷你面板色相族 6 → 2，主控台 2 族（accent + 状态点绿）。
  取证是**无头**的（DOM 普查 + PNG 像素普查），改完还没重抓真机图 —— 需要提权重启宿主才会加载新皮肤，
  会打断用户，须先征得同意。
* 已知残留（不影响「侧栏 + 不透明」两条结论）：迷你面板底部有一条细横向滚动条（宿主自身内容 **410×621** CSS > 窗口 610，
  纵向滚动条是宿主固有的，皮肤把它从 4px 加宽到 12px 后才引出横条）；主窗顶部 ~100 CSS px 与预览有亮度差
  （抓图时宿主停在别的 tab 页）。两者都写进 `devlog.md` 的「未决」段。
* 文档里的**数字**都在 2026-10-03 对着磁盘/宿主复核过一轮（修正了 `host-shell.css` 体积、CSS 规则数、`preview.html`
  行数、`build_skins.py` 行号等），并补上了「宿主自我更新」的复核流程与 `wins.ps1` 的澄清；核对过程与证据见 `devlog.md` §9。
