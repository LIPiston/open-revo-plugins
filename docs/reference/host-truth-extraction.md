# 提取宿主真值（host truth extraction）

**目的**：写皮肤前必须先知道宿主**真实的类名、令牌、`!important` 对手规则和 DOM 结构**。手册里的示例类名不可信。

## 1. 从 `open-revo.exe` 抽前端产物

宿主是 Tauri 应用，前端产物被**内联进 exe**，格式是拼接的 `[文件路径字符串][brotli 负载]` 序列：

* 格式：`[资产路径字符串][brotli 负载]` 依次拼接；负载**紧跟在路径字符串之后**（`payload = path_offset + len(path)`）。
* 关联位置：`assets/index-C535NsqC.css` → 路径 @ **6941209**、负载 @ **6941234**、压缩流 **8,020 B** → 解压 **50,997 B**；
  `assets/index-BzQyTcpV.js` → 路径 @ **7124459**、负载 @ **7124483**、压缩流 **133,369 B** → 解压 **594,906 B**。
  （exe 本次 8,496,640 B。**这些数字随版本变动，只当定位方法的示例，绝不要写死进代码。**）
* 解压后：完整宿主 CSS **50,997 B / 333 个 `{`**（sha256 `4cf6ca2416e263dd…`）；外壳/主题子集另存 `_extracted\host-shell.css`
  （14,584 B / 86 行：`acrylic-container|mech-titlebar|sub-nav|nav-tab|glass-card|logo-badge|mini-drawer-root`）。
* JS：完整抽取物在 `_extracted\new-build\index-BzQyTcpV.js`（594,906 B）；早期那份 `_extracted\bundle.partial.js`
  （584,148 B / 1012 行，**尾部被截断**，来自更旧的构建）已被取代。迷你面板的决定性片段另有逐字切片
  `_extracted\_mini_L0.js`、`_mini_G0.js`、`_mini_q0.js`、`_mini_spec.txt`、`_mini_strings.txt`。

### 定位精确流尾（必须做，否则解不出来）

`brotli.decompress(切片)` **要求切片正好是一个流**：多带一个字节的尾部数据就会 `brotli.error: decoder failed`，
少一个字节也失败。所以要么先知道下一个资产路径的偏移（流尾 = 下一个路径起始），要么用增量解码器逐块喂到 `is_finished()`。
本仓库用的稳健写法（先粗后细）：

```python
d = brotli.Decompressor(); out = bytearray(); pos = start; CH = 4096
while pos < start + limit:
    chunk = data[pos:pos+CH]
    try: out += d.process(chunk)
    except Exception: err_at = pos - start; break      # 这一块里越过了流尾
    pos += len(chunk)
    if d.is_finished(): break                          # 正常结束
# 在 [err_at, err_at+CH] 区间里用完整流解码精确定位流尾
for j in range(0, CH + 1):
    try: blob = brotli.decompress(data[start:start+err_at+j]); break
    except Exception: continue
```

**陷阱一：brotli 没有魔数**。偏移错一个字节也会「成功」解出一堆垃圾或直接抛错，不会自我暴露。
解压后**必须**校验产物（开头是否合理、`{` 条数是否稳定、关键类名是否可 grep）。

**陷阱二：宿主会自我更新并重启**。本次开发中途就发生了：exe 于 `23:49:31` 被替换（8,490,496 → 8,496,640 B，
CSS 路径偏移 `7145918 → 6941209`，JS 切片名 `index-CGlrizf7.js → index-BzQyTcpV.js`），进程在 `23:54:17` 自动重启。
**判据：文件名里的哈希就是内容哈希**——本次 CSS 切片名仍是 `index-C535NsqC.css`，抽出来与旧构建**逐字节相同**，
所以宿主 CSS 没变、皮肤不受影响；JS 切片名变了，说明 JS 变了，需要重新抽。下次更新照这个流程复核一遍即可。

**陷阱三：`open-revo.exe` 里除了压缩资产，还有 Rust 侧明文字符串**。本次实测明文命中：
`plugin_type` @ 6887819、`load_plugin_theme_css` @ 6923005 → 前者证明 manifest 的权威键是 **`plugin_type`**（编写时仍双发 `type` 对冲），
后者是宿主内核对外的命令名。

## 2. 交叉核对「这个类名真的存在吗」

手动拷手册里的选择器去写样式是本项目最大的坑。可靠的核对手段是宿主 WebView2 的 **V8 代码缓存**：

```
%LOCALAPPDATA%\com.openrevo.controlcenter\EBWebView\Default\Code Cache\js\   # 本次 72 个文件
```

对里面的文件逐字 grep 类名字面量（这些是宿主真实执行过的 JS，含编译后的字符串表），
再用 `_extracted\index-*.css` 交叉确认。

**实测结论：手册 §7 用例里的 `.overview-main-grid`、`.sensor-gauge-cluster`、`.cooling-fan-card`、
`.power-mode-selector` 等示例名，在发行版里命中数为 0。** 皮肤只能针对 `_extracted` 里的真实选择器写；
若想兼容手册示例名，只能额外写一组「前向兼容手臂」。

## 3. 宿主如何注入皮肤 CSS（决定预览页必须怎么复刻）

bundle 里的注入代码**逐字**如下（从最新构建 `_extracted\new-build\index-BzQyTcpV.js` 抽出，仅加了换行）：

```js
…openrevo-custom-skin");
if (w) {
  const F = await m("load_plugin_theme_css", { pluginId: w });
  E || (E = document.createElement("style"), E.id = "openrevo-custom-skin", document.head.appendChild(E)),
  E.textContent = F;
} else E && E.remove();                       // 取消皮肤时移除 <style>
e && c && await m("resize_window", { expanded: !0 })
} catch (E) { console.error("Failed to apply skin:", E) }
```

注意 `else E && E.remove()`：宿主**取消勾选皮肤时是把 `<style>` 整个删掉**，而不是注入空样式表——
所以皮肤必须**自带完整观感**（包括命名空间内的全部默认值），不能依赖「上一次注入的残留」。

要点：

* 宿主把 `theme.css` 的**整份文本**塞进 `<style id="openrevo-custom-skin">`（不是 `<link>`）→ 预览页必须照做。
* 因为 base URL 是宿主文档（`tauri://`），`theme.css` 里的 `@import` **取不到插件目录**，所以**必须单文件**。
* **曾经因为这个吃过一个大坑**：预览页最初用 `<link rel=stylesheet disabled>` + 运行时启用，结果**已存在的元素保持旧样式**
  （按钮停在浏览器默认 `buttonface rgb(240,240,240)`）。改成 `<style>.textContent` 注入后一致。详见 `pitfalls.md`。

## 4. `data-skin` 挂在哪、两个面板的根是谁

bundle 里两个面板共用同一层包装：

```js
n.jsx("div", { "data-theme": f, "data-skin": N || void 0, style: { width: "100%", height: "100%" }, children: … })
```

* `data-skin` 与 `data-theme` **写在同一个元素上**，两个面板都是；`data-skin` **从不写在 `<html>` 上**。
* 主控台根 = `.acrylic-container`；迷你面板根 = `.mini-drawer-root`。

### 主控台 DOM

```
div.acrylic-container
├── div.mech-titlebar[data-tauri-drag-region]        # .logo-badge(22×22) + "OPENREVO" + .badge-tag("社区定制版本号: v0.8.8-2075447") + 窗控按钮 + mono/cyber 切换
├── div.sub-nav-wrapper > div.sub-nav-bar > button.nav-tab   # 8 个 tab
└── div（无 class，flex:1; padding:16px; overflowY:auto）     # 内容区，没有页面标题层
```

tab 依次为：`overview, gpu, tuning, lighting, water, system, plugins, sponsor`。

### 迷你面板 DOM

```
div.mini-drawer-root[data-theme]
    内联: width:100vw; height:100vh; background:rgba(12,15,22,.96);
          backdrop-filter:blur(28px); color:#f8fafc
└── div.mini-drawer-content  (display:flex; flex-direction:column; gap:5.5px; padding:9px 11px; width:100%)
    ├── header（拖拽区，border-bottom rgba(255,255,255,.06)，.logo-badge img 19×19，4 个内联彩色图标按钮）
    ├── 性能模式（.m-card + .m-grid-4 × 4 个 .m-btn-action）
    ├── 显卡模式
    ├── 刷新率 + 亮度（slider）
    ├── 键盘背光 / 电池健康
    ├── .m-quick-grid × 6 个 .m-quick-btn + 状态行
    └── 底行（checkbox + .m-foot-btn.expand + 可选的 OEM 弹窗 div[style*="position: fixed"]）
```

**OEM 助手弹窗与「极客调校」浮层是条件渲染的**，本项目只做了近似（用 `[style*="position: fixed"]` 手臂兜），
未真正复刻——遇到相关需求需要重新取真值。

## 5. 宿主 `:root` 令牌（主控台）

```css
--surface-base: rgba(11,14,20,.94);
--surface-card: rgba(22,27,34,.75);
--radius-xs:4px; --radius-sm:6px; --radius-md:8px; --radius-lg:12px; --radius-xl:16px;
--color-brand:#6366f1; --color-office:#10b981; --color-balance:#3b82f6;
--color-beast:#f43f5e; --color-fan:#06b6d4; --color-gold:#f59e0b;
--font-mech: "Chakra Petch";
```

## 6. 宿主关键规则（皮肤要压过的「对手」）

### 主控台

```css
.acrylic-container{ background: radial-gradient(...) + #0b0e14f0;
                    backdrop-filter: blur(24px) saturate(180%); border-radius:14px;
                    box-shadow: 0 16px 40px #0009, inset 0 1px #ffffff1a }
.mech-titlebar{ padding:10px 16px; background:#00000040 }
.sub-nav-bar{ display:flex; gap:6px; padding:8px 16px; background:#00000026 }
.nav-tab{ padding:6.5px 13px; border-radius:8px; background:#ffffff09; font-size:11.5px; font-weight:600 }
.glass-card{ background: var(--bg-card); border-radius:10px; padding:12px; backdrop-filter: blur(12px) }
[data-theme=mono] .nav-tab.tab-sponsor.active{ …!important }   /* (0,4,0) + !important —— 最难压的一条 */
```

### 迷你面板

```css
.mini-drawer-root{ --text-muted:#94a3b8; --text-dim:#64748b;
                   --border-subtle:rgba(255,255,255,.08); --border-hover:rgba(255,255,255,.16);
                   --bg-card:rgba(18,22,32,.75) }                 /* (0,1,0) 局部令牌声明 */
.mini-drawer-root[data-theme=mono], .mini-drawer-root[data-theme=cyber]{ …重新声明整套 --theme-*… }  /* (0,2,0) */
[data-theme=mono] .m-quick-btn.active{ background:#ffffff24; border-color:#ffffff73; color:#fff;
                                      box-shadow: 0 0 10px #ffffff1f }   /* (0,3,0) */
.m-card{ background: var(--bg-card); border:1px solid var(--border-subtle); border-radius:8px;
         padding:6px 10px; display:flex; flex-direction:column; gap:5px }
.m-btn-action,.m-btn-hz,.m-btn-bat{ background:#ffffff08; border:1px solid rgba(255,255,255,.07);
                                    color: var(--text-muted) }     /* hover:#ffffff12 / #ffffff26 */
.m-quick-btn{ height:48px; border-radius:7px; background:#ffffff09 }
.m-quick-btn.active{ background:#38bdf826; border-color:#38bdf873; color:#38bdf8 }
.mini-drawer-root::-webkit-scrollbar{ width:4px }
.mini-drawer-root::-webkit-scrollbar-track{ background:transparent }
.mini-drawer-root::-webkit-scrollbar-thumb{ background:#ffffff29; border-radius:4px }
.mini-drawer-root::-webkit-scrollbar-thumb:hover{ background:#ffffff52 }
.sub-nav-bar::-webkit-scrollbar{ height:3px }
```

下拉类：`.m-select-menu` / `.m-hz-dropdown-menu` / `.m-mon-dropdown-menu`。

### 两条容易忽略的「宿主事实」

* 宿主**没有**全局 `*{box-sizing:border-box}`。
* 宿主**没有**任何 `button` / `.m-btn-*` 规则，也**没有** `#f0f0f0` 字面量——所以看到 `buttonface` 一定是你自己的问题（见 `pitfalls.md` 第 1/23 条）。

## 7. 由 JSX 内联样式决定的 `!important` 清单

宿主用 React 内联 `style={{…}}` 写死了下面这些属性，**普通选择器压不过**，必须 author `!important`：

* `.acrylic-container`：容器布局/背景/圆角/阴影相关
* `.mini-drawer-root`：`width/height`（`100vw/100vh`）、`background`（`rgba(12,15,22,.96)`）、`backdrop-filter`（`blur(28px)`）、`color`
* 迷你头部 4 个图标按钮的内联颜色
* 迷你底行的 `.m-foot-btn.expand` 等

（`!important` 的合法性依据：作者源里的 `!important` 胜过普通声明，而内联样式**不是** `!important`，因此作者 `!important` 能压过内联。）
