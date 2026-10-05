# 自定义背景图（background 插件）

一句话：**把一张本地图片变成 OpenRevo 的窗口背景** —— 主窗（`.acrylic-container`）和迷你面板
（`.mini-drawer-root`）都铺上它，并叠一层可调遮罩保证文字照样能读。

## 0. 一个独立插件：`bg-custom`

本插件就是**一个普通插件** `bg-custom`，作用只有一个：把一张本地图片铺成 OpenRevo 的窗口背景。
它不带任何皮肤令牌、不改宿主默认界面的配色与布局，**与 `skin-*` 那四套 win 皮肤没有任何依赖关系**
—— 删掉 `skin-*/` 它照样能构建、照样能装。

> **0.8.8 起宿主开了第二条 CSS 通道**（完整取证见 `reference/plugin-dev-0.8.8-skill.md`）：
> `plugin_type:"background"` 的插件走 `active_background` 槽位 →
> `<style id="openrevo-custom-background">`，与皮肤的 `active_skin` →
> `<style id="openrevo-theme-skin">` **互不干扰、可以同时启用**。
> 下面 §0.0 的三条约束是 **0.8.7 的历史**，第 1、2 条已被 0.8.8 解除。

### 0.0 宿主硬约束（0.8.7 版；0.8.8 已解除前两条）

1. ~~**宿主没有任何背景图能力**~~ → **0.8.8 已解除**。0.8.7 时 `open-revo.exe` 里
   `background_image|backgroundImage|wallpaper|bg_image` 命中 0、`config.json` 里没有任何背景相关键，
   背景**只能**由皮肤插件的 `theme.css` 注入。0.8.8 新增 `active_background` 槽位 +
   **Background Engine**（Rust 侧直接读插件目录里的图片文件并自己生成 Data URI），见 §0.1。
2. ~~**宿主只认一个 CSS 通道**~~ → **0.8.8 已解除**。0.8.7 全树只有
   `<style id="openrevo-custom-skin">` 一处注入点，内容来自 `load_plugin_theme_css({pluginId})`；
   而 `active_skin` **是单值**（宿主切换逻辑对 `plugin_type === "skin"` 的插件执行
   `enabled: T.id === D`，其他类型走 `set_custom_plugin_enabled`，永远不注入 CSS）。
   → 那个版本里**背景插件与 Fluent 皮肤在宿主层面互斥**，这是宿主的设计、不是本插件的选择。
   0.8.8 把它拆成两个独立槽位，互斥关系消失（插件卡片徽标分开：皮肤「主窗皮肤」/ 背景「背景壁纸」）。
3. **`theme.css` 必须自包含** —— **这条仍然成立**：宿主把整份 CSS 文本塞进 `<style>`，不注入 base URL；
   `@import` / 相对 `url()` 都取不到插件目录里的图片，`file://` 在 `tauri://` origin 下会被 WebView2 拒。
   → 走 **`theme_css` 通道**时，图片必须内联成 **base64 `data:` URI**（exe 里只有 tauri 协议的 CSP 头名字、
   没有指令文本，`data:` 可用）。
   ⚠️ 0.8.8 的 `background` 通道有**零代码**替代路径（§0.1 路 A2），但
   「作者在 CSS 里写相对 `url()`、Rust 帮忙改写成 Data URI」**没有任何证据** ——
   `background_css` 里仍然得写内联 `data:` 或外链。

> 0.8.7 时还有一条推论：「插件类型只有 `skin|tab|widget|service|shell` 五种，`shell` 是整窗替换主界面
> 而非样式通道，所以能注入 CSS 的形态有且只有 `skin`」。**该推论已作废**：0.8.8 前端里
> `plugin_type` 的取值字面量只有 `background|skin|tab|widget` 四种（`service`/`shell`/`driver` 在 JS 里
> 没有字面量，开发者 skill §2 的「七形态表」未获证实）。

### 0.1 两条路：`background` 通道（0.8.8+）与派生皮肤

**路 A（0.8.8+，宿主原生通道）** —— `plugin_type:"background"`，插件只提供背景，与皮肤**同时启用**。
两种写法：

* **A1 自带 CSS**：manifest 写 `"plugin_type":"background"` + `"background_css":"background.css"`，
  CSS 里把背景铺在 `.openrevo-shell` 与 `.mini-drawer-root` 上。这条通道是**独立注入点**，
  所以 CSS 里**不需要**再写 `[data-skin="…"]` 前缀，`html[data-skin]` 兜底手臂也不必加。
* **A2 零代码 / 零 base64**：只放 `manifest.json` + 一张**固定文件名**的图
  （`background|wallpaper|bg` × `.jpg/.jpeg/.png/.webp` 共 12 个，大小写不敏感，见
  `plugin-dev-0.8.8-skill.md` §3）。Rust 侧 Background Engine 自己读文件、自己生成
  `url("data:<mime>;base64,…")` 模板并注入 —— **不写一行 CSS、不存 base64**。
  ⚠️ 开发者 skill §6 方式 B 写的 `"image":"wallpaper.jpg"` 键在 0.8.8 里**不存在**
  （exe 里 0 命中，manifest 字段表里也没有 `image`）—— 别写；机制是**固定文件名探测**。

**路 B（0.8.7 起可用，本仓库当前产物形态）** —— 把两层 CSS 合并进**同一份** `theme.css`，
即**派生皮肤** `<id>-bg`（= 原皮肤逐字节不动 + 末尾追加背景段）。它是**可选导出**，默认不生成：

```bash
python build_background.py set --image assets/sample-wallpaper.jpg --targets skin-win11-dark
```

| 产物 | 是什么 | 何时生成 |
|---|---|---|
| `bg-custom` | **独立插件**（默认）：只有背景段，宿主默认 UI 不动 | 只要 `standalone: true`（默认） |
| `<id>-bg`（如 `skin-win11-dark-bg`） | **派生皮肤**：原皮肤 + 背景段，用作「Fluent 皮肤 + 背景」 | 仅当 `--targets` 显式指定时 |

派生走的是**新 id 的新目录**，不是改原皮肤 —— 原四套皮肤的 132 条验收断言
（含 `root.bgImage = none`、`container.alpha` 这类「不能有背景图」的正向断言）一个字都不用改。

### 0.2 现状：做完了，仍按 m00785 刻意不装

**这个插件已经实现完毕、三档验收全绿**，但**还没有装进宿主、也没有激活**。

原始原因（m00785，0.8.7 时代）是上面第 2 条约束解不开：当时只有一条 CSS 通道，
装上去就会顶掉用户当前的 `skin-win11-dark`。用户口径 m00785 的决定是
「既然已知不行那就先不做，然后更新文档，等待开发者开放更多接口」。

**0.8.8 把那个卡点解除了**（`active_background` 与 `active_skin` 解耦，见 §0.1 路 A），
但本仓库产物**仍是路 B 形态**（`plugin_type:"skin"` 的独立插件 `bg-custom`），
所以「装上会顶掉皮肤」这件事在**当前产物形态下依然成立** —— 不装的决定因此继续有效，
直到把 `bg-custom` 改造成 `plugin_type:"background"`（改造清单见
`reference/plugin-dev-0.8.8-skill.md` §7 第 8 项）。

所以仓库侧的正确状态是：

* 代码、模板、产物、验收脚本、文档全部就位（`bg.config.json` 是构建真值，`bg-custom/` 已入库）；
* `%APPDATA%\OpenRevo\plugins\` 里**没有** `bg-custom`，宿主 `config.json` 的 `active_skin` 保持原值；
* 宿主侧零改动 —— 谁也没有被顶掉。

选择装的话，**0.8.8 下的操作口径**（脚本尚未实现，需手工或改造后使用）：
把 `bg-custom` 的 manifest 改成 `"plugin_type":"background"` + `"background_css":"theme.css"`
（或改名 `background.css`），装进插件目录后点插件页的【刷新】出现在列表里，再打开它的开关 ——
此操作只写 `active_background`，**不动** `active_skin`。在那之前，`--targets <skin_id>` 的派生皮肤
就是「皮肤 + 背景」的替代方案。

## 1. 快速使用

```bash
# ① 指图 + 选参数（默认只出独立插件 bg-custom；相对路径按仓库根解析）
python build_background.py set --image assets/sample-wallpaper.jpg

# ② 装进宿主插件目录
#    ⚠️ 按用户口径 m00785 这一步当前刻意不执行（当前产物是 skin 形态，会顶掉 skin-win11-dark，见 §0.2）
#    0.8.8 起宿主支持第二条通道，把产物改成 plugin_type:"background" 后即可与皮肤并存（§0.1 路 A）
python build_background.py install --activate

# ③ 看现状（启用状态 / 源图 / 参数 / 每个产物的 sha1 与装没装）
python build_background.py status

# ④ 回退：禁用并删掉产物（宿主进程里的那套要重启才消失）
python build_background.py off
```

单独构建 / 只构建不装：`python build_background.py build`。
想让某个 Fluent 皮肤也带上背景：加 `--targets skin-win11-dark`（见 §0.1）。

### 参数表（`set` 与 `build` 通用）

| 参数 | 默认 | 说明 |
|---|---|---|
| `--image` | — | 源图路径（相对路径相对仓库根）。`set` 会写进 `bg.config.json`，`build` 沿用配置 |
| `--fit` | `cover` | `cover` / `contain` / `stretch`（`100% 100%`）/ `tile`（`auto`+`repeat`）/ `center`（原始尺寸） |
| `--position` | `center` | 任意 `background-position` 值（`center`、`top left`、`50% 20%`…） |
| `--overlay` | `0.42` | 遮罩不透明度 0~1。`0` = 不压暗（仍然有那一层，见 §3.2） |
| `--overlay-color` | `auto` | `auto` = 按皮肤底色亮度自动选：亮度 < 0.5 用黑，否则用白 |
| `--blur` | `0` | 高斯模糊半径（**烘进图片**，不是运行期 `backdrop-filter`，见 §3.4） |
| `--max-width` | `2560` | 超过则按 LANCZOS 降采样（**降采样之后**才模糊，换 `max-width` 观感一致） |
| `--quality` | `88` | JPEG 质量；带 alpha 的图自动转 PNG（无损） |
| `--scope` | `both` | `both` / `main`（只主窗）/ `mini`（只迷你面板） |
| `--targets` | `none`（只出独立插件） | `none` / `all` / 逗号分隔的皮肤 id。**留空 = 沿用 `bg.config.json` 里的现值**（不猜宿主 `active_skin`，免得改图时偷偷多出派生皮肤）。未知 id 会报错并列出可用值 |
| `--no-standalone` | — | 不生成 `bg-custom`（只想出派生皮肤时用） |
| `--install` / `--uninstall` | — | 同步到 / 从 `%APPDATA%\OpenRevo\plugins\` 增删 |
| `--activate` | — | 装完调 `_tools\set-active-skin.ps1` 激活：有派生目标就激活 `<t>-bg`，否则激活 `bg-custom` |

`bg.config.json`（入库，是构建的唯一真值）**只存源图路径和参数，不存 base64** —— 每次构建重新编码，
所以换 `--max-width` / `--quality` 不会退化成二次压缩。

## 2. 产物长什么样

```
bg-custom\                     # 默认产物：只有 3 条背景规则，没有皮肤令牌
├── manifest.json              # 当前是 plugin_type:"skin"（0.8.8 可改 "background"+background_css，见 §0.1 路 A）
├── theme.css                  # 139 KB（背景段 + 内联 base64 图）
└── assets\
    ├── background.jpg         # PIL 处理后的成品（2560×1440 q88，入库，便于复核与直接取用）
    └── preview.png             # 插件卡片缩略图：自绘 UI 叠在照片上（合成而非覆盖，见 §4.1）

skin-win11-dark-bg\            # 仅 --targets 指定时：派生皮肤
├── manifest.json              # id/name/version 派生（plugin_type/type/theme_css/window 与母本一致）
├── theme.css                  # = 原皮肤 1292 行（id 替换后逐行相同）+ 91 行背景段 → 194 KB
└── assets\                    # 同上
```

背景段固定 **3 条规则**（`verify-bg.sh` 按规则数钉死）：

> 选择器前缀是「合并进 `theme.css`」（§0.1 路 B）这个形态逼出来的：宿主把这份 CSS 当**皮肤**注入，
> 所以必须靠 `[data-skin="<id>"]` 把自己限定在启用该皮肤时生效。
> 若改走 0.8.8 的 `background` 通道（路 A1），前缀反而多余 —— 那条通道只在该背景被激活时才注入。

1. `[data-skin="<id>"] , html[data-skin="<id>"] { --bgimg-photo / --bgimg-scrim / --bgimg-base
   / --bgimg-size / --bgimg-position / --bgimg-repeat }` —— **令牌**。
   `html[data-skin]` 那一路是兜底：预览页把 `data-skin` 挂在 `<html>` 上模拟宿主语义，两条手臂都要认。
2. `[data-skin="<id>"] .acrylic-container.acrylic-container { … }` —— 主窗。
3. `[data-skin="<id>"] .mini-drawer-root.mini-drawer-root { … }` —— 迷你面板。

`--scope main/mini` 会按 `src/background.css` 里的 `/* __BG_MAIN_BEGIN__ */ …` 标记裁掉不需要的那条。

## 3. 工作原理（每一处都是被宿主逼出来的）

### 3.1 画在**面板根**上

主窗的面板根是 `.acrylic-container`（`width:100%;height:100%;display:flex`），迷你窗是
`.mini-drawer-root`（`100vw/100vh`）—— 两者都铺满整窗，是唯一「整块画布」。

要压过的对手有两层：

* **宿主自己的 CSS**：`.acrylic-container{background:radial-gradient(…),radial-gradient(…),#0b0e14f0}` ——
  独立插件 `bg-custom` 面对的就是它（`bg-custom/theme.css` 里没有 `src/base.css`，也没有皮肤令牌）。
* `src/base.css` 自己（**仅派生皮肤会遇到**）：`.acrylic-container`（(0,2,0)）与
  `[data-skin] .mini-drawer-root{background: var(--wf-bg) !important}`（(0,2,0)）—— 注意 base.css 里有
  **两处** `background: var(--wf-bg) !important`（第 692 / 1095 行）。
* 宿主给 `.mini-drawer-root` 的**内联** `background:rgba(12,15,22,.96)` —— **仅 0.8.7**；
  0.8.8 把这批内联删掉了（改由 `.mini-drawer-root` 规则里的 `background:var(--surface-base,…)`
  + `backdrop-filter:blur(28px)` 承担），见 `host-truth-extraction.md` §7。

对策：**类名写两遍**。`.acrylic-container.acrylic-container` = (0,3,0)，同样压过宿主内联（内联只在
(1,0,0) 这一档压过高特异性规则，而内联本身只声明了 `background` 简写、`!important` 是作者侧唯一解）。
类名重复计数与「这里没有别的类名可写」这件事本身无关，纯粹是为了抬特异性 —— 因此
`bg-custom` 与派生皮肤用的是**同一条规则、同一个模板**，不需要两套 CSS。

> 0.8.8 兼容性：`.mini-drawer-root.mini-drawer-root` = (0,2,0) **同时**打赢两版 ——
> `!important` 压 0.8.7 的内联，(0,2,0) 压 0.8.8 那条 (0,1,0) 的 `.mini-drawer-root` 规则。
> 也就是说 0.8.8 下 `!important` 已经**不是必需**，但留着不产生副作用，无需为版本分叉两套模板。
> 同理 `.acrylic-container` 在 0.8.8 里与 `.openrevo-shell` 是**同一个元素**（两个类都在根上），
> 所以既有的选择器不做任何改动就继续命中原有的那块画布。

### 3.2 遮罩写在同一个 `background-image` 里

```css
background-image: var(--bgimg-scrim), var(--bgimg-photo) !important;
background-size: cover, var(--bgimg-size) !important;
background-position: center, var(--bgimg-position) !important;
background-repeat: no-repeat, var(--bgimg-repeat) !important;
```

第一层是遮罩（`linear-gradient(rgba(r,g,b,a), rgba(r,g,b,a))`），第二层才是照片 —— 不需要伪元素、
不需要 `z-index`、不占额外层级，也不用管兄弟元素的层叠上下文。

`scrim_css()` 恒输出**两个同色停靠点**（而不是 `overlay=0` 时省掉这一层）：这样**层数恒为 2**，
`verify-bg.sh` 的 `bg.layers = 2 (photo 1 + linear 1 + radial 0)` 一条断言就能覆盖所有 overlay 取值，
不必给 `overlay=0` 开特例。

兜底：`background-color: var(--bgimg-base)`（= 该变体的皮肤底色）——图片还没解码完或解码失败时，
窗口是皮肤底色而不是白屏。

### 3.3 只用长手属性，绝不写 `background:` 简写

`background` 简写会重置**整个 background 族**（`-color` / `-image` / `-size` / `-position` /
`-repeat` / `-attachment` / `-clip` / `-origin`）。这条规则要同时表达「底色兜底 + 两层图片 +
每层各自的 size/position/repeat」，用简写就会踩两件事：

* `background: var(--bgimg-base)` 会把同一规则里已写好的 `background-image` 一起抹掉 ——
  顺序一变就静默失效（不报错、只是背景没了）。
* 简写**表达不了**逐层参数（第 1 层恒 `cover`、第 2 层按 `--bgimg-size`）。

> 纠错记录：早先的注释把理由写成「简写会把 `src/base.css` 的 border/box-shadow 一起清掉」——
> 这是**错的**。简写只影响 background 族，`border` / `box-shadow` 是另外的属性族；
> 而且是不同的规则，跨规则本来就不存在互相清掉。（已在 `src/background.css` 同步改正。）

### 3.4 模糊烘进图片，运行期不开 `backdrop-filter`

* 少一次全窗合成（`backdrop-filter` 每帧都要读回下层像素）。
* 保持既有的 `container.blur = none` 断言成立 —— 皮肤本体从不使用 `backdrop-filter`，背景也不破例。

### 3.5 图片编码

`bg_common.render_image()`：`Image.open` → `ImageOps.exif_transpose`（手机照片的方向）→
超过 `--max-width` 才 LANCZOS 降采样 → **降采样之后**才 `GaussianBlur(radius=--blur)`（半径按最终
画布像素算，所以改 `--max-width` 观感一致）→ 用 `getchannel("A").getextrema()[0] < 255` 判断是否**真的**
有透明像素（全不透明的 PNG 会白占体积）→ 有则 PNG、无则 JPEG(q88, optimize, progressive) →
`url("data:<mime>;base64,…")`。

体积：2560×1440 的示例图 → 136 339 B 的 data URI（约 133 KB），派生皮肤 `theme.css` 194 KB。
`URI_BUDGET = 4 MiB` 是告警阈值 —— 宿主会把整份 `theme.css` 读进内存再塞进 `<style>`。

## 4. 验收（可执行，不靠肉眼）

```bash
bash _tools/verify-bg.sh              # 已启用：先跑既有 132 条，再跑背景断言
NO_AUDIT=1 bash _tools/verify-bg.sh   # 复用 _audit/ 产物，快速复检
bash _tools/verify-bg.sh off          # 未启用：断言「零泄漏」
```

断言总数随配置变化（脚本按 `bg.config.json` 现场推导，不写死）：

| 配置 | 实测总数 | 构成 |
|---|---|---|
| `targets: []`（默认，只出独立插件） | **18** | 1 条无回归 + `bg-custom` 17 条 |
| `--targets skin-win11-dark` | **68** | 1 条无回归 + 派生皮肤 50 条（结构 2 + 主窗 9 + 主窗背景 11 + 迷你 16 + 迷你背景 12）+ `bg-custom` 17 条 |
| `off`（`targets: []`，只有 `bg-custom` 要消失） | **10** | 1 条无回归 + 1 条 `enabled=false` + 1 个产物 × 8 条 |
| `off`（曾在 `--targets skin-win11-dark` 之后） | **18** | 同上，`bg-custom` + `skin-win11-dark-bg` 共 2 个产物 × 8 条 |

> 总数是**推导**出来的，不是常数：off 模式按「配置里开过哪些产物」逐个去断言，
> 所以 `--targets none` 时是 10 条而不是 18 条。表中数字都是实际运行值。

为什么另开一个脚本而不是往 `verify.sh` 里塞：既有 132 条里含 `root.bgImage = none` 这类
**「不能有背景图」的正向断言**，与背景功能互斥。派生皮肤用新 id，两边各管各的：
`verify-bg.sh` 的**第一条断言就是「既有 132 条全绿」**，失败计入同一个总数。

断言构成（启用态，派生部分）：

* **结构 1 条/目标**：派生 `theme.css` 与原皮肤**逐行比对**，只允许 id 替换与标题里多出的
  「· 自定义背景」，且末尾恰好追加 3 条规则。（不能直接字节比对：id 出现在每个选择器里。）
* **主窗 8 条/目标**：`skin_id`、规则数 = 118 + 3、`container.blur/display/cols/areas/alpha`、
  `--wf-important`、`dom.hueFamilies = 2`。
* **主窗背景 11 条/目标**：探针落点、`photo.count = 1`、`grad.count = 1`、`layers = 2`、
  `token.photo = yes`、**`image.loaded = true 2560x1440 dataURI <N>B`**（浏览器真的解码出了图）、
  `layer2.size/pos/repeat`、`scrim`、`base`。
* **迷你面板 16 + 11 条/目标**：皮肤那 16 条沿用 `verify.sh` 的口径；背景那 11 条同上，
  外加一条**与基线方向相反**的断言 —— 基线要求 `root.bgImage = none`，背景皮肤要求
  `root.bgImage` 里含 `url(` 与 `linear-gradient(`。
* **独立插件 `bg-custom` 17 条**：主/迷你两页各验一遍背景层；不断言皮肤布局（它就没有皮肤）。

`off` 模式的「必须消失」清单同样是推导出来的：`bg-custom`（若开过）+ 每个 `--targets` 选中过的
`<id>-bg`，逐个断言**目录已删**、宿主回落原皮肤（`skin_id` 匹配 `^skin-win(11|10)-(light|dark)$`）、
`--bgimg-photo` 零泄漏、照片层 = 0、无可解码图、`container.img = none`、底色是纯色。
删旧断言的取舍：`bg.layers` 的具体总数与 `container.bg` 的具体颜色都取决于**回落哪套皮肤**，
不是背景插件的事，钉死它们等于把皮肤的断言混进来。

期望值不是抄产物的：`verify-bg.sh` 每轮从 `bg.config.json` **重新推导**遮罩 RGBA、fit 对应的
`size/repeat`、`position` 的 computed 形式（`center` → `50% 50%`），并用 PIL 读**产物文件**的尺寸去
比对浏览器解码出的 `naturalWidth` —— 于是「PIL 写出的字节 = 浏览器解出来的图」也被钉死。

### 4.1 预览页探针

`preview.html` / `preview-mini.html` 的审计块里新增 `bg.*` 字段（`bg.photo.count` / `bg.grad.count` /
`bg.token.photo` / `bg.image.loaded` …）。探针只读 DOM、不改 DOM：读 computed `backgroundImage`
数 `url(` / `linear-gradient(` / `radial-gradient(` 的出现次数（base64 字母表里没有 `(` `)`，
所以按次数数字符串不会被 data URI 污染），再另起 `new Image()` **真解码**一次拿 `naturalWidth`。

> **踩过的坑**：`.acrylic-container` 在 4 套原皮肤下的 computed `backgroundImage` 本来就是
> `none`（底色是纯色），而 base.css 那条 mica 规则是两层 `radial-gradient`。所以「层数 = 2」
> **不能**证明照片生效 —— 必须看 `photo.count` / `grad.count` / `image.loaded`。

## 5. 已知坑（本轮新踩的）

| 现象 | 原因 | 对策 |
|---|---|---|
| 缩略图上半透明部件盖住了照片 | PIL `ImageDraw` 是**直接写像素**、不是 alpha 混合 | UI 画在 RGBA 透明层上，最后 `alpha_composite(photo, ui)` 再 `convert("RGB").resize()` |
| `rules_applied` 从 118 变成 121 | 背景段确实多了 3 条规则 | 断言写成 `118 + 1 + extra`，`extra` 用选择器实际计数，不写死 |
| 「派生文件与原皮肤逐行相同」直接字节比失败 | 头部注释第 1~3 行含 **skin id** 与插件名 | 比对前归一化：id 替换 + 去掉「· 自定义背景」 |
| 追加段 `{` 计数 = 6 而非 3 | 模板头部注释里引用了宿主的规则原文（`.acrylic-container{…}`） | 先剥注释再数 `{` |
| 失败信息打印成乱码 | Python 在 Git Bash 下按本地代码页输出中文（stdout/stderr = `gbk`） | 脚本里 `export PYTHONIOENCODING=utf-8`；CLI 自身也在 `build_background.py` 顶部把 stdout/stderr 重新包成 UTF-8（只改流，不动系统区域设置，避免 PEP 540 连带改子进程 I/O） |
| 预览页 `preview-mini.html` 的审计锚点没匹配上 | 两页缩进不同（4 空格 vs 6 空格） | 打补丁脚本带 `assert count == 1`，一次只改一处 |
| 重跑 `set --image …` 会偷偷多出派生皮肤 | 旧逻辑在 `--targets` 留空时回落宿主 `active_skin` | 留空 = **沿用配置现值**；派生必须显式 `--targets`。默认口径就是独立插件 |
| `bg.config.json` 里写进绝对路径 | `set` 存的是 `os.path.abspath` | 仓库内的图存相对路径（`rel_image()`），换机器仍可 build；仓库外才保绝对 |
| `--targets none` 时 off 模式一条断言都不跑 | off 分支原先只遍历被 targets 选中的变体 | 改成推导「必须消失的 id 列表」= `bg-custom`（若开过）+ 每个 `<id>-bg` |

## 6. 文件清单

| 文件 | 角色 |
|---|---|
| `bg.config.json` | 构建真值：源图路径 + 全部参数（入库） |
| `src/background.css` | 背景段**模板**（含 `__SKIN_ID__` / `__BG_*__` 占位符与 scope 裁剪标记） |
| `bg_common.py` | 无副作用的共享层：配置、颜色、PIL 编码、CSS 渲染、派生变体计算 |
| `build_background.py` | CLI：`set` / `off` / `build` / `install` / `status` |
| `build_skins.py` | 原皮肤构建器；本轮**纯增量**加了 `make_preview(v, path, photo=None)` |
| `_tools/make-sample-wallpaper.py` | 确定性生成 `assets/sample-wallpaper.jpg`（任何 clone 都能 build 出同一产物） |
| `_tools/verify-bg.sh` | 背景验收（默认 18 / 派生 68 / off 10~18 条，随配置推导） |
| `bg-custom/` | 默认产物（**入库**，即装即用，与四套 `skin-*\` 同等对待） |
| `<id>-bg/` | 仅 `--targets` 指定时产生的派生皮肤。`.gitignore` 里已忽略（`*-bg/`）：它由「已入库的原皮肤 + 已入库的 `bg.config.json`」完全重新推导，属本机试验产物 |

## 7. 退回原状

```bash
python build_background.py off --uninstall   # 配置置 false + 删仓库产物 + 删已装副本
powershell -ExecutionPolicy Bypass -File _tools\kill-and-start.ps1   # 宿主重启后彻底消失
```

`off` / `--uninstall` 有护栏：**拒绝删除宿主 `active_skin` 正指向的产物目录**（除非 `--force`），
并提示先 `_tools\set-active-skin.ps1 <基础皮肤 id>` 切走。
