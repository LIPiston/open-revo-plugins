# 开发记录（devlog）

一次完整实战的时间线：从读手册到四套皮肤上真机取证，附每一步的**数字证据**与**未决项**。

## 0. 任务与需求演进

| 消息 | 内容 |
|---|---|
| m00001 | 起点：参考原型 `D:\LIPis\desktop\openrevo ui`（只读）+ 手册 `D:\LIPis\downloads\OpenRevo_第三方插件开发手册.md` → **用手册「用例 7」给 OpenRevo 开发 Windows 组件 UI 插件**（用例 7 = 皮肤插件） |
| m00053 | 插件加载目录：`C:\Users\LIPis\AppData\Roaming\OpenRevo\plugins` |
| m00054 | 按手册标准工程树做（皮肤只需 `manifest.json` + `theme.css` + `assets\`） |
| m00236 | 「能够大面积修改成类似 `D:\LIPis\desktop\openrevo ui` 这里的效果吗 —— **传统 WinUI3 那样的侧栏切换 tab，然后取消掉半透明背景**」 |
| m00705 | 「**mini模式的也要做**」——把主控台的做法延伸到迷你面板 |
| m01586 | 「把开发记录做成一份skill放到 `D:\LIPis\Documents\code\openrevo-plugins\docs`」（= 本文件与同目录 SKILL.md 的由来） |

用户后来自己在宿主【插件】页把 `active_skin` 从 `skin-win10-dark` 切到了 **`skin-win11-dark`**。

## 1. 侦察：手册 ≠ 发行版

* 读手册 v1.0（783 行），确认 §7（L659 附近）：`plugin_type:"skin"`、`theme_css:"theme.css"`、
  `window:{width,height,resizable}`（切换皮肤时宿主 `resize_window` 并重新居中）、**0 ms 热加载**、皮肤互斥。
* 从 `open-revo.exe` 抽前端产物：`[路径][brotli 负载]` 拼接格式。当时那次构建：
  `index-C535NsqC.css` @ `7145918`、`index-CGlrizf7.js` @ `7153964`、CSS 负载 = `exe[7145944:7153964]`。
  **注意：这些偏移已被宿主自我更新取代（见 §9），别照抄。**
* 解出宿主 CSS **333 个 `{`**（50,997 B）；外壳子集存 `_extracted\host-shell.css`
  （**14,584 B / 86 行**——这是 §9 复核后的数字，早期笔记里写的「7,717 B / 40 规则」是错的）。
* **关键发现**：手册 §7 用例里的 `.overview-main-grid`、`.sensor-gauge-cluster`、`.cooling-fan-card`、
  `.power-mode-selector` 在宿主里**根本不存在**——在 WebView2 V8 代码缓存（72 个文件）里逐字检索命中 **0**。
  → 建立「以 exe 抽出的真值为唯一依据」的工作方式（详见 `reference/host-truth-extraction.md`）。
* 摸清宿主注入路径（bundle 逐字）：`load_plugin_theme_css` 返回 CSS 文本 → 塞进
  `<style id="openrevo-custom-skin">` 的 `textContent`。这一条决定了后面所有预览页的写法。
* 摸清 `data-skin` 挂在两个面板共用的外层 `div`（`{"data-theme":f,"data-skin":N||void 0,…}`），
  主控台根 `.acrylic-container`、迷你根 `.mini-drawer-root`。

## 2. 建预览台（把「看不见」变成「量得到」）

* 写了 `preview.html`（主控台）与 `preview-mini.html`（迷你面板），二者都**加载真实宿主 CSS**
  （`_extracted/host-shell.css`）、`<html data-theme="mono">`、棋盘格底图。
* 预览的 `activate(id)` 用同步 XHR 读 `<id>/theme.css` 再 `<style>.textContent` 注入——与宿主一致。
* **一次大坑换来一条铁律**：最初用 `<link rel=stylesheet disabled>` + 运行时启用来切换皮肤，
  结果预览里按钮渲染成浏览器默认的 `buttonface rgb(240,240,240)` / `buttontext rgb(0,0,0)`。
  逐项排除了宿主干扰、缺令牌、内联覆盖、选择器被丢、解析错误、样式表被禁用等可能，
  最终定位为「启用禁用样式表后，**已存在**的元素没有重算样式」；改成 `<style>` 注入后悖论消失。
  此后所有真值核对都在这个台子上做（判据见 `reference/preview-and-audit.md`）。

## 3. 四套皮肤与生成器

* `build_skins.py`：`VARIANTS` 驱动，`token_block(v)` / `hue_block(k,v)` / `manifest(v)` /
  `build_theme_css(v, base_src)` / `make_preview(v,path)`；`src/base.css` 里所有选择器带 `__SKIN_ID__` 占位。
* 四套变体落盘并安装（`python build_skins.py --install`）：

  | 变体 | 强调色 | 圆角 | 窗口(CSS) | theme.css |
  |---|---|---|---|---|
  | `skin-win11-light` | `#0067c0` | 8/12px | 1120×800 | 50,596 B |
  | `skin-win11-dark` | `#60cdff` | 8/12px | 1120×800 | 50,483 B |
  | `skin-win10-light` | `#0078d4` | 2px | 1080×780 | 50,393 B |
  | `skin-win10-dark` | `#1683d8` | 2px | 1080×780 | 50,323 B |

* `<id>\theme.css` 与 `%APPDATA%\OpenRevo\plugins\<id>\theme.css` **逐字节一致** → 安装即为最新。
* 安装后**必须重启宿主**才可见（宿主只在启动时枚举插件目录）——这一条先后坑了两次。

## 4. 主控台：WinUI3 侧栏 + 取消半透明（m00236）

* §14 配方：`.acrylic-container` 实色 + `backdrop-filter:none` + `border-radius:0` + 内描边；
  再用 `grid-template-areas: "wf-titlebar wf-titlebar" "wf-sidebar wf-content"` +
  `grid-template-columns: var(--wf-sidebar-w) minmax(0,1fr)`（`--wf-sidebar-w: 224px`）把导航栏挪到左侧。
* 隔离守卫：整个栅格段以 `.acrylic-container:has(> .sub-nav-wrapper)` 为前提（`:has(> .x)` 计 (0,1,0)，
  整条选择器 (0,6,0) + `!important`），因此**只对存在侧栏 DOM 的主控台生效，迷你面板天然不受影响**；
  另配 `@media (max-width:760px)` 窄窗回退（导航退回顶部横条）。
* 最强对手：宿主 `[data-theme=mono] .nav-tab.tab-sponsor.active{…!important}`（(0,4,0)+`!important`）——
  皮肤必须叠到 (0,6,0)+`!important` 才压得住。四层特异性阶梯完整记录在 `reference/skin-authoring.md` 第 4 节。

## 5. 迷你面板：同步改造（m00705）

两个失败与修复：

1. **改了背景还是半透明**：§8.2 的 `background` 没带 `!important`，输给宿主内联的 `rgba(12,15,22,.96)`。
   补 `!important` 后审计得到 `root.bg = rgb(32,32,32)`、`blur = none`。
2. **强调色还是宿主 mono 白**：宿主在 `.mini-drawer-root[data-theme=mono|cyber]`（0,2,0）上**局部重声明**
   整套 `--theme-*`，而「元素上的局部声明胜过继承值」。修复：新增 §8.1，在
   `[data-skin="X"] .mini-drawer-root[data-theme]`（0,3,0）重声明面板令牌，值一律读 `--wf-hue-*` **镜像变量**。
   四套变体审计确认 `--theme-pwr` 分别是 `#ff8c00 / #ff9d5c / #ca5010 / #d83b01`，
   `.m-quick-btn.active` 背景为该变体强调色 16%。

## 6. 真机取证

### 6.1 迷你面板（先做）

* 真机几何：物理 `615×916` = **CSS `410×610`**（宽固定 410，高由宿主 `fit_mini_window_height` +
  `ResizeObserver` 动态适配，**变化 >250px 才重算**）。
* 无遮挡抓图 `_shots/real-mini-clean.png`：`(44,44,44) 24.45%`、`(32,32,32) 18.61%`、`(56,56,56) 14.06%`；
  宿主色 ≈ 0 → 不透明达成 ✓；与 `preview-mini.html` 分块 **MAE 19.98**。
* 右缘解剖：CSS `x=402` 是卡片右描边，`x=402.7~406.7` 是滚动条槽，槽内 `y=0~302` 是滑块
  ⇒ 当时用「滑块占槽比例」反推 `scrollHeight ≈ 1180~1230`，同时用预览审计读到「宿主自身内容 663 高」
  ⇒ 结论：**纵向滚动是宿主固有的**（两者都 > 窗口 610）。
  > **2026-10-04 更正**：那个 663（以及当初接手文档里写的 666）是**被污染的读数** —— 当时审计代码里有一段诊断实验
  > 会往 `.m-grid-4` 里 append 新按钮、再 clone / 重新挂载节点，把内容撑高了 45px。删掉那段诊断后，
  > 干净读数是 **410×621**（`?audit=1` 的 `content.size`）。621 仍 > 610 ⇒ 定性结论不变，但**余量只有 11px**，
  > 不再是「差 53px」那么宽裕。滑块比例反推的 1180~1230 也不可信（皮肤把滚动条改成 12px 槽 + 4px 滑块，
  > 视觉滑块与轨道比例不再线性）。详见 §11。
* 取证过程本身贡献了半张 `pitfalls.md`：先用 `show-app.ps1`（不置顶）抓到的「面板」其实是我自己的浏览器；
  `PrintWindow` 对 Tauri 返回全 alpha=0；非提权 `SetWindowPos` 被 UIPI 拒绝；`WindowFromPoint` 跳过 Tauri 分层窗口，
  差点把 QQ 的遮挡当成皮肤缺陷。最后定型为「提权 + 置顶 + `CopyFromScreen`」。

### 6.2 主控台大面板（后做）

* 唤醒脚本 `_tools/wake-grab-dash.ps1`（提权）：启动第二个实例触发单实例唤醒 → 找 `title='OpenRevo'` 且宽度 ≥800
  的可见窗口（排掉 615px 的 mini）→ 置顶 → 抓 1200/1500ms 两帧 → 还原。
* 真机几何：`hwnd=852778 rect=(641,338)-(2343,1551) 1702×1213` 物理 = **1135×809 CSS @150%**
  ⇒ manifest 的 `window:{1120,800}` 是按**CSS 逻辑像素**生效（Tauri `LogicalSize`）；CSS 视口 >760 ⇒ 侧栏回退不触发。
* `_shots/real-dash-1500.png` 直方图：`(32,32,32) 30.25%`、`(44,44,44) 19.04%`、`(41,41,41) 16.96%`、
  `(56,56,56) 6.08%`、`(40,40,40) 4.80%`、`(39,39,39) 1.89%`、`(74,74,74) 1.81%`、`(59,59,59) 1.66%`、`(63,63,63) 0.92%`；
  **宿主色 `(11,13,17)/(16,18,25)/(26,28,35)/(12,15,22)/(17,20,30)/(24,27,37)` 计数全 0** ⇒ 完全不透明 ✓
* 列亮度边缘最强处在 CSS **`224.7 / 225.3`** = `--wf-sidebar-w: 224px` 的右边界 ⇒ **侧栏重排真机生效 ✓**；
  其余真机列边缘 `245.3/246.0`（预览同样有）、`668.7`、`676.7`、`1083.3`、`1100.0`。
* 与预览（`1120×800` @dsf1.5）对齐：最优 **dx=9 dy=0**（搜索 dx 0..26 / dy 0..34），
  **MAE 22.16**；分带：左栏 0–224 CSS **16.48** < 内容区 23.58 < 顶部 100 CSS 46.45 ≫ 底部 100 CSS 9.90。
  ASCII 对比显示：真机顶部是暗底 + **左侧栏区域一块亮块**（被重排的品牌/标题区），
  预览顶部则是一条横贯全宽的**高频抖动纹理**且亮块落在内容区 x≈0.33–0.45W。

## 7. 交付与现场还原

* `README.md`（278 行 / 24,984 B）更新：§7 增加第 7、8 条（四个变体的迷你令牌审计、真机大面板取证），
  坑列表新增 4 条（`show-app.ps1` 不置顶 / Tauri 不能最小化 / `wake_window_mode` 只在启动时读 / 模型不支持读图），
  §10 改为「已在真机取证 + 剩余差异」，`active_skin` 一句改为 `skin-win11-dark`。
* 现场还原：`config.json` 的 `wake_window_mode` 由临时 `"full"` 改回 `"mini"`（备份 `config.json.bak-skinverify`），
  提权重启宿主 → 新 `pid 22052`（start 19:50:27），mini 窗口 `hwnd=10684400` `615×916` `vis=False`（等用户唤醒），
  `active_skin="skin-win11-dark"`、`custom_plugin_toggles={"eva01-core":false}`。
* 清理：删除中间废图（`mg-*.png`、`mv-*.png`、`real-dash2.png`、`real-dash.png`、`real-main.png`、`real-dash-1200.png`）
  与临时 Chrome profile（`_shots/prof-*`），`_shots` 收敛到 7.0M。

## 8. 未决项（下次接手先看这里）

1. **迷你面板底部细横向滚动条**：皮肤把滚动条从 4px 加宽到 12px 后引出（纵向滚动本身是宿主固有的：
   宿主内容 **410×621** > 窗口 610，余量仅 11px；数字出处见 §6.1 的更正）。修法：
   `.mini-drawer-root{overflow-x:hidden !important}`，或把滚动条收细。
   **用户 m01586 明确表示「先不动，我自己看观感」**，故未改。
2. **主控台顶部 ~100 CSS px 与预览的亮度差**（分带 MAE 46.45）：抓图当时宿主停在**别的 tab 页**，
   内容区本身不同；顶部还多一条真机才有的高频纹理/亮块布局。需要在对齐同一个 tab 后重测，才能判断
   是皮肤差异还是「抓的不是同一屏」。
3. **OEM 助手弹窗与「极客调校」浮层**：条件渲染，本次只用
   `[data-skin="X"] div[style*="position: fixed"]` 近似，未真正复刻。
4. ~~`_tools\wins.ps1` 缺 `CharSet = CharSet.Unicode`~~ —— **已核实作废**：`wins.ps1:11-12` 已经带上。
   （同类澄清：`_tools\pin-grab.ps1` 内部确实调用了未定义的 `Say()`，仍然只有 `pin-grab-hwnd.ps1` / `wake-grab-dash.ps1` 可用。）
5. ~~`preview-mini.html` 里早期排查用的实验钩子（A–J）已无用，可以删掉。~~ —— **2026-10-04 已删**，
   并且发现它们一直在**污染**审计读数（`content.size` 被撑高 45px）。见 §11。
6. 用户在宿主【插件】页对四套皮肤的观感反馈尚未收到（皮肤本身功能已验收）。

## 9. 宿主自动更新复核（开发中途真实发生）

写完本文件当天，宿主**自我更新并自动重启**，把整轮取证用到的字节偏移全部作废。记录如下：

| 事实 | 旧 | 新 |
|---|---|---|
| `open-revo.exe` | 8,490,496 B | **8,496,640 B**（mtime `23:49:31`） |
| 进程 | `pid 22052`，start `19:50:27` | **`pid 22584`，start `23:54:17`**（自动重启） |
| CSS 资产 | `assets/index-C535NsqC.css` @ 7145919 | `assets/index-C535NsqC.css` @ **6941209**（切片名未变） |
| CSS 负载 | — | @ 6941234，brotli 流 **8,020 B** → 解压 **50,997 B** / **333 个 `{`** |
| JS 资产 | `index-CGlrizf7.js` | **`index-BzQyTcpV.js`** @ 7124459，负载 133,369 B → 解压 **594,906 B** |

**复核结论：皮肤不受影响。** 依据：

* CSS 切片名（内容哈希）没变，抽出来与旧构建的 `_extracted/index-C535NsqC.css` **逐字节相同**
  （`50,997 B`，sha256 `4cf6ca2416e263dd…`）⇒ 宿主类名/令牌/对手规则一字未改。
* 新 JS 里 28 个皮肤依赖标识**全部存在**：`load_plugin_theme_css`×2、`set_active_skin`×1、`openrevo-custom-skin`×4、
  `data-skin`×1、`data-theme`×3、`acrylic-container`×1、`mech-titlebar`×1、`sub-nav-wrapper`×1、`sub-nav-bar`×1、
  `nav-tab`×3、`tab-sponsor`×1、`glass-card`×32、`logo-badge`×2、`mini-drawer-root`×1、`mini-drawer-content`×1、
  `m-quick-btn`×12、`m-card`×14、`m-btn-action`×7、`m-foot-btn`×1、`m-select-menu`×3、`m-hz-dropdown-menu`×1、
  `m-mon-dropdown-menu`×1、`m-mon-badge-hz`×1、`fit_mini_window_height`×2、`ResizeObserver`×2、`wake_window_mode`×3、
  `plugin_type`×9、`theme_css`×2。
* 新 JS 的注入片段仍然一字不差地走 `<style id="openrevo-custom-skin">` 的 `textContent`，并且多出一条
  `else E && E.remove()`（取消皮肤时整个移除样式表）与 `resize_window({expanded:!0})`。

**顺带补到的一条真值**：exe 里除了压缩资产还有 Rust 侧明文字符串——`plugin_type` @ 6887819、
`load_plugin_theme_css` @ 6923005 ⇒ manifest 的权威键就是 **`plugin_type`**（当初双发 `type` 对冲是稳妥的）。

**方法论沉淀**：只要断言里带**字节偏移/文件大小**，它就是一个会过期的断言。正确姿势是「把方法写进文档、
把数字标成某次构建的示例」，并用**切片内容哈希**作为「宿主样式是否变化」的判据。

## 10. 配色收敛：六色族 → 二色族（用户口径 m00001 / m00053）

**用户要求**：「继续优化这个 ui 插件，mini 模式只使用系统主题色进行强调」→「不要这么多颜色进行装饰，
一个系统主题色加一个重要强调色就行」。

### 10.1 先量出现状，再动手

宿主原版给每个部件分配一个颜色：mini 六个指标卡六种色相、四种性能模式四种颜色、九个导航 tab 九种颜色。
改造前先从真机图量出**物证基线**（`docs/reference/pitfalls.md` 的思路：模型不能读图，就把图变成数字）：

| 面板 | 改造前色族（按色相聚类） |
|---|---|
| mini（真机，skin-win10-dark） | 青 4.86% / 蓝 2.61% / 橙红 1.43% / 绿 0.63% / 粉紫 0.30% / 黄 0.05% —— **6 族** |

### 10.2 收敛规则

| 令牌 | 角色 | 适用范围 |
|---|---|---|
| `--wf-accent` | **系统主题色** | 一切可交互 / 已选中 / 已启用 |
| `--wf-important` | **重要强调色**（暖橙，源自原 `hue_pwr`） | 只用于性能 / 功率与需要注意的状态 |
| `--wf-ok/-warn/-error` | 状态语义色 | 只表达真实状态，不得当装饰 |

关键判断：**别删 `--theme-*` 的六个槽位名**。宿主 mini 的内联样式读的就是 `var(--theme-pwr/gpu/hz/lux/kbd/bat)`
这六个名字（主控台大面板一处都不用），删掉就整块失效；正确做法是**保留槽位名、收敛取值**：
`pwr` → important，其余五个 → accent。

同理，宿主主控台自绘的部件（电源徽标 / 休眠守卫 / 电池模式单选）读的是宿主私有 `--accent-pwr/-beast/-gpu/-cool/-rgb/-lux`，
皮肤此前完全没碰过它们 —— 于是 cyber 主题下是彩虹、mono 主题下是纯白。现在一并归一：
`/pwr|beast/` → important，`/gpu|cool|rgb|lux/` → accent。

### 10.3 内联硬编码色只能靠 `!important` 打掉

宿主把一批颜色写在**内联 style** 里（令牌管不到）：READY 圆点 `#34d399` + 文字 `#6ee7b7`、
主题配色切换按钮 cyber 态 `rgba(56,189,248,.15)`/`#38bdf8`、OEM 徽标 `rgba(245,158,11,.15)`/`#fbbf24`（运行中）
与 `rgba(56,189,248,.1)`/`#38bdf8`（已被屏蔽）、赞助心形 `#f43f5e`。
这些在 `src\base.css` §8.4 里用 `[attr*="…"]` 属性选择器 + `!important` 逐条覆盖；
两态徽标用 title 文案区分（`正在运行` / `已被屏蔽`）。

> 踩坑：`--wf-accent-glow` **不存在**。实际是 `-hover/-press/-soft/-soft-strong/-border/-strong/-shadow/-on-accent`。
> 误用不存在的令牌不会报错，`box-shadow` 会静默变成 `none`（invalid at computed-value time），
> 只能靠审计读数发现。

### 10.4 验证：把「只剩两个颜色」变成可复跑的断言

1. `_tools\audit.sh` 里加了 **DOM 色彩普查**：遍历带内联色或 `--theme-*` 的元素，按 `Math.round(h/30)*30` 分桶。
   判无彩用**绝对彩度** `max-min < 24`，**不能用 HSL 的饱和度** —— `#f4f0f5` 这种带一丝紫的近白 S≈0.2，
   会凭空多出一个色相族（实测踩到）。
2. `_tools\census.py`：PNG 像素级色相族普查（环形贪心聚类，容差 30°）。
3. 结果：**mini 四套变体 `dom.hueFamilies = 2`、像素 `色族数量 = 2`**（accent 86% + important 14%）；
   主窗 `dom.hueFamilies = 2`（accent + 状态点绿）。隐藏夹具单独断言 `active-beast` = important。
4. `_shots\<id>-clean.png`（`?nofix=1`）：预览页自带的夹具（`SAFE MOCK` 徽标、六色令牌探针卡）不是宿主 UI，
   会把像素普查污染出假色族，故用属性标记 + URL 开关在截图时关掉。

### 10.5 保留的第三个颜色

主控台的 `.status-dot.dot-on` 仍是 `--wf-ok` 绿（4 个 8px 圆点，占全图 0.03%）。
**有意保留**：它表达「设备开/关」的真实状态，属于 `ok/warn/error 只表达真实状态` 这条纪律，
改成 accent 会让「已开启」和「已选中」看起来一样。这是本轮唯一主动不收敛的颜色。

## 11. 顺手修掉的两个**测量**缺陷（2026-10-04）

收敛配色（§10）时，为了让审计能回答「解析器到底留下了哪些规则」，`preview-mini.html` 的 `runAudit()` 里塞了一段
**决定性实验 A~J**：新建同 class 的按钮、注入 `!important` 测试样式、把 `theme.css` 规则原文重灌一遍、
clone 节点、重新挂载节点、反复触碰 class……用来定位「`.m-btn-action` 为什么不吃皮肤样式」。

根因（`<link>` 启用异步导致元素不重算）查清、改成 `<style>.textContent` 注入之后，这段代码**没删**。后果：

### 11.1 诊断代码污染了被测对象

它往 `.m-grid-4` 里 append 了新按钮和克隆节点，把 `.mini-drawer-content` **撑高 45px**。于是审计长期报
`content.size = 410×666`，而真实值是 **`410×621`**。文档里流传的「宿主内容 663 高」「差 56px」
都源自这个被污染的读数 —— 真实余量只有 **11px**（621 vs 窗口 610）。

定性结论（纵向滚动是宿主固有的、不是皮肤的锅）不变，但论据的余量窄了一个数量级。

### 11.2 陈旧产物冒充通过

`_audit/mini-skin-win10-light.audit.txt` 是更早一次运行的残留（那次皮肤没注入成功），里面全是宿主原色
（`#38bdf8`、`rgba(99,102,241,.25)`、纯白），但因为 `dom.hueFamilies` 恰好也算出 2，**看上去是「通过」**。

⇒ 教训：**负向条件（族数 = 2）挡不住这种错误**，必须配正向条件 —— 例如
`mini.--theme-pwr` 必须等于该变体的 important 值、`ready.dot.bg` 必须等于该变体的 accent。

> **【更正 · 2026-10-04（下一轮）】** 上面「那个 `.audit.txt` 是上一次运行的陈旧产物」的归因**已被证伪**。
> 同一现象在 `_tools/_stress.sh`（24 并发 × 6，逐次与单跑参考 diff）下当场复现 4/24 ≈ 17%：皮肤表已完整解析
> （`sheet[2] rules=118` 与通过态逐字段一致）、DOM 也一致，坏的是**解析期就完成过样式解析的那部分元素
> 没有被重新失效**（样式失效竞态），当场新起 Chrome 也一样 —— 不是读旧文件，也不是样式表被截断。
> 修复：`preview-mini.html` 的 `activate()` 末尾 `settleStyle()`（`data-skin` 落定后原地摘挂舞台子树），
> 修复后 48 次 0 异常，A/B 对照（同一份页面注释掉 `settleStyle()`）24 次 4 异常。详见 `reference/pitfalls.md` #39。
> **「正向条件」这条教训反而更重要了** —— 当初正是它把这个缺陷从「族数 = 2」的假通过里揪出来。

### 11.3 处置

* 删掉 `preview-mini.html` §636–709 的 A~J 实验（文件 743 → 668 行），只保留**只读**探针：
  `probe.hits` 规则命中列表、`sheet[i]` 解析统计、残留白检查、DOM 色彩普查。
* 四套变体重跑审计：`content.size` 从 666 变成一致的 **621**；`--theme-pwr` 四套 = 对应 important、
  其余五槽 = 对应 accent、`ready.dot`/`themeBtn.cyber`/`oem.blocked`/`sponsorHeart` = accent、
  `oem.running` = important、`dom.hueFamilies` = 2 —— 全部符合预期
  （这份干净读数表已落成 `_tools/verify.sh` 的 132 条断言，字段含义见 `reference/preview-and-audit.md` §6）。

> **纪律**：放进验收工具的诊断代码**只准读，不准改 DOM**；确需改就在 `finally` 里还原。
> 问题查清后要主动删掉实验代码 —— 留在那里的诊断会变成下一次的假数据。
> 这一条已写进 `reference/pitfalls.md` 第 34/35 条。

### 11.4 验收从「人眼对表」升级为可执行断言（2026-10-04 第二轮）

上一轮把验收写成了一张靠人读产物对数字的表（即原 `HANDOFF.md` §11.4；该接手文档已于 2026-10-04 删除，
原文件保留在 git 提交 `c1e2e03` 里）。它有两个已经付过学费的漏洞：
§11.2 的假通过（`dom.hueFamilies` 恰好也是 2），以及重跑多次之后**没人能证明每一条都被核过**。

这一轮做了两件事：

1. **根因收口**：迷你面板「偶发读到宿主原色」**不是**陈旧产物（§11.2 的更正是对的），是样式失效竞态。
   顺序连跑 30 次不复现，`xargs -P 6` 并发跑 24 次就出 4 次 —— 复现率 ≈ 17%（前提是把「能否复现」做成工具）。
   修复 = `preview-mini.html` 的 `settleStyle()`（`data-skin` 落定后原地摘挂舞台子树）；
   修复后 48×8 → **异常 0**；A/B 对照（注释掉 `settleStyle()` 的同一份页面）24×6 → 异常 4。
2. **验收可执行化**：新增 `_tools/verify.sh`（主窗 9 条×4 + 迷你 22 条×4 + 像素普查 4 条 = **132 条断言**）
   与 `_tools/_stress.sh`（并发压测，末尾报「异常 M 次」）。
   全量重跑：**「合计 132 条断言，失败 0 条」**（exit 0）；`bash _tools/shots.sh` 重出 **28 张图**；
   四套 mini 审计均含 `settle.remounts = 1`。

> 纪律：`dom.hueFamilies = 2` **单独出现不算通过**（负向条件会被「全是宿主原色」骗过）；
> 动过预览页或皮肤 CSS **必须**跑一次 `PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8`。
> 验收结论只认 `verify.sh` 的 exit code —— 这条已写进 `SKILL.md` 验收清单、`README.md` 维护约定
> 与 `_tools/verify.sh` 的文件头注释。

## 12. 文档整理与手册消化（2026-10-04 第三轮）

这一轮不改任何皮肤代码，只把「知识」收拢成能长期用的形态。

* **手册消化**：把 783 行的官方 v1.0 手册消化成 `reference/plugin-manual-digest.md` —— 定位、插件六形态矩阵、
  清单九字段、8 大硬件 IPC、遥测铁律、七用例、Safe Mode，外加一张 **§10「手册 ≠ 发行版」对照表**（7 条）。
  手册自身的不一致也记了：示例里的 `"type"` 是旧写法（权威键 `plugin_type`）、`always_on_top` vs `alwaysOnTop`、
  用例 3 的 `target` 字段不在字段表里。
* **环境与工具集中成一页**：新建 `reference/environment-and-tools.md`，把原先两份一次性接手文档里**长期有效**的部分
  收拢：环境硬事实 20 行（宿主会自我更新并重启、插件只在启动时枚举、宿主周期性整份回写 config、显示器缩放、
  双面板几何、`read_image` 不可用、抓图代价、BOM 纪律、MSYS 错位）、`_tools\` **34 个工具**的地图与取舍、
  证据文件索引、回退/还原（含三个未替用户还原的字段）、以及「本任务明确没做的事」。
* **删除接手文档**：`HANDOVER.md`（17,544 B）与 `HANDOFF.md`（33,300 B）已删。删之前先建了本仓库的**首个 git 提交**
  `c1e2e03`（113 个跟踪文件）—— 此前仓库 0 commit，删掉就不可恢复；同时加了 `.gitattributes` 的 `* -text`，
  因为本仓库存在「逐字节一致」类断言，git 默认的 CRLF↔LF 归一化会把这些证据改坏。
  保真验证：`git clone` 到 `_audit/_clonecheck` 后 `cmp` 八个字节敏感文件（两套 `theme.css`、`_extracted/host-shell.css`、
  `_tools/set-active-skin.ps1`、`_tools/who.ps1`、`docs/SKILL.md`、两份接手文档）全部 OK，克隆目录已删。
* **引用清理**：`_tools/verify.sh` 与 `_tools/set-active-skin.ps1` 的文件头注释、本文件四处历史引用（§6.1 / §11.3 / §11.4×2）
  全部改成指向现存文档；`docs/SKILL.md` 新增「官方手册消化件」一节、参考地图补两页、现状快照改为收尾时的事实；
  `docs/README.md` 的树与维护约定同步（并记上 DSH 技能副本路径）。`.ps1` 有 BOM，DSH 的 `edit` 会吃掉它，
  改完用 Python 补回并复核（`ef bb bf`），再用 `[Parser]::ParseFile` 确认 0 error。
* **顺手更正一条旧结论**：`_tools/pin-grab.ps1` 的 `Say()` **是已定义的**（第 8 行 `function Say($m){...}`），
  旧接手文档说它「未定义」是陈旧结论 —— 它当初无效的真实原因另有其人（`show-app.ps1` 只 show 不置顶、
  `capwin.ps1` 对 Tauri 返回全 alpha=0）。
