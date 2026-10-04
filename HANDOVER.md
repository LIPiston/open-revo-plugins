# 交接文档 · openrevo-plugins 改名与整理

> 生成：2026-10-04　|　**更新：2026-10-04（第二轮）**　|　权威树：`D:\LIPis\Documents\code\openrevo-plugins\`
> 上一会话的工作区仍指向**已删除**的旧路径 `...\code\openrevo-win-skin\`，本文件即新会话的起点。

## 0. 一句话状态

**内容层改名、目录改名、宿主已装副本迁移、文档同步、全部验收证据重出、文档收尾三件套、以及
迷你审计那个 17% 的假读数 —— 均已完成。验收已从「人眼对表」升级为 `_tools/verify.sh` 的 132 条断言。**
**真机取证（用户选 C）已完成并给出结论**：宿主 12:06:33 自己把 `active_skin` 写成了 `skin-win11-dark`
（悬空 ID 已自愈），且新旧两代皮肤**除 ID 外逐字节相同** ⇒ 外观上没有任何东西在等重启，
原来那件"需用户授权的 ④"因此**降级为可选**（§3 ④）。
外加一件用户自留：harness 镜像树（§3 ⑤）。

## 1. 目标与验收口径

* 用户原话（**上一轮会话**发出的需求）：**「重命名整个项目成 openrevo-plugins / 已经实现的 win10 win11 皮肤插件作为子文件夹项目」**
* 本轮（第二轮）用户指令：**「接手然后继续完成你的事情」** —— 即按本文件 §3 收尾。
* 结构要求（m00004）：`openrevo-plugins/*skin-win11-light/*skin-win11-dark/...`
* 验收：四套皮肤是**仓库根级**子目录；插件 ID 去掉 `fluent`；文档/脚本/预览页无过期路径；
  `_tools/audit.sh` 四套门控全过。

## 2. 已完成（每条都有证据）

| # | 事项 | 证据 |
|---|---|---|
| 1 | 仓库四份 `theme.css` / `manifest.json` 的 ID 改为 `skin-win11-light\|dark`、`skin-win10-light\|dark` | 改名前后 `cmp` **逐字节一致**（改名是纯命名，行为中性） |
| 2 | `dist\` 这一层取消，产物直接落仓库根 | 根目录 15 个条目，`dist` 已不存在 |
| 3 | 目录改名 `openrevo-win-skin\` → `openrevo-plugins\` | 旧路径 `No such file or directory`；新路径 170 文件 |
| 4 | `_tools/` 里 8 个 ps1 + `shoot1.sh` 的硬编码镜像树绝对路径解耦 | 全仓 `grep default-workspace _tools/` 归零 |
| 5 | 20→21 个 `_tools/*.ps1` **全部带 UTF-8 BOM** | 缺 BOM = 0；`[Parser]::ParseFile` 0 error（**第二轮复验：22/22 带 BOM、0 error**，含新增的 `set-active-skin.ps1`） |
| 6 | `_tools/pin-grab.ps1` 调用未定义的 `Say` | 已补 `$log` 与 `function Say` |
| 7 | `_tools/grab-main.ps1` 被整文件重写吃掉 BOM（我埋的雷） | 已补 BOM，见 pitfalls #16 |
| 8 | 宿主已装副本迁移 | `%APPDATA%\OpenRevo\plugins\` 下四个新 `skin-*` 在位，旧 `win11-fluent-*`/`win10-fluent-*` 已删 |
| 9 | `README.md` / `HANDOFF.md` / `docs/*` 同步新命名 | 残留引用只剩「旧→新对照表」里的历史记录 |
| 10 | 验收证据全量重出 | 主窗 + mini + 基线审计全过；28 张截图；mini 四套 `色族数量 = 2` |
| 11 | **收尾①**：`README.md` §2.1 那句假话改掉 | 原 94-96 行声称 `active_skin` 已改写；现 `README.md:94-99` 写明它仍是旧值、必须停机改、宿主回写实测（见 pitfalls #37） |
| 12 | **收尾②**：`docs/reference/pitfalls.md` 补 #36/#37/#38 + 增强 #16 | 行 30–39 齐（`grep -c '^\| 3[0-9] \|'` = 10）；文件 52 行；`head -c3` = `23 20 e8`（无 BOM） |
| 13 | **收尾③**：`_tools/rename-project.ps1` 注释指回 #16 / #36 | 该文件 BOM 被 `edit` 工具吃掉 → 已用 python 一行补回，`[Parser]::ParseFile` = `PARSE OK: 0 error` |
| 14 | **迷你审计「偶发读到宿主原色」根因锁定 + 修复**（旧文档归因「陈旧产物」已被证伪） | `preview-mini.html` 的 `settleStyle()`；修复前 24 并发×6 → 异常 4，修复后 48×8 → **0**，A/B 对照（注释掉 `settleStyle()` 的同一份页面）24×6 → 4。见 pitfalls #39 |
| 15 | **验收从「人眼对表」升级为可执行断言**：`_tools/verify.sh` | 132 条断言 / 失败 0；含 `settle.remounts = 1`、`--theme-*` 六槽、五个探针色值、`content.size = 410x621`、像素色族 = 2 |
| 16 | **把 §3 ④ 收成一条命令**：`_tools/set-active-skin.ps1 [skin] [dry]` | 自带两道守卫（宿主没停掉就拒绝改 / 目标皮肤无 `theme.css` 就拒绝改）；改写逻辑在临时副本上已验：仅 `active_skin` 一个字段变、其余字节全同（3680 → 3678 B）、`ConvertFrom-Json` 回读 = 目标值；`dry` 空跑输出正确；解析 0 error、BOM `ef bb bf` |
| 17 | **真机取证（用户选 C，只取不改）**：宿主是否已应用新皮肤 | 提权 `wake-grab-dash.ps1` 抓到大面板两张 `_shots/real-dash-{1200,1500}.png`（1702×1213）；同面 A/B 对 10-03 19:42 旧图：MAE 全图 2.59 / 左栏 1.00 / 顶栏 1.30 / 内容 2.99，差异 >40 仅 2.845% 且集中在内容区图表带（navy bbox `(379,759)-(1659,872)`）；**决定性**：旧 ID `dist/win11-fluent-dark/theme.css` 与新 `skin-win11-dark/theme.css` 除 ID 外 **diff = 0 行** ⇒ 改名行为中性、外观零变化、像素不可判别；同时发现宿主 12:06:33 **自己**把 `active_skin` 写成 `skin-win11-dark`（悬空 ID 自愈）。结论与教训落在 `docs/reference/real-machine-verification.md` §9 |

审计门控实测值（四套一致）：`container.blur = none`、`container.display = grid`、
`container.cols = 224px 894px`、`container.areas = "wf-titlebar wf-titlebar" "wf-sidebar wf-content"`、
`dom.hueFamilies = 2`；mini 另有 `mini.--theme-pwr` = 该变体 important 值（如 win11-dark `#ff9d5c`）。
基线 `_audit/mini-off.audit.txt` 为宿主默认：`root.bg = rgba(12,15,22,.96)` / `root.blur = blur(28px)`。

**第二轮验收（2026-10-04，全量重跑）**：`bash _tools/verify.sh` → 「合计 **132 条断言，失败 0 条**」（exit 0）；
`bash _tools/shots.sh` 重出 **28 张图**；四套 mini 审计均含 `settle.remounts = 1`；
`PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8` → **异常 0 次**。
以后验收只认 `verify.sh` 的 exit code —— `dom.hueFamilies = 2` 单独出现**不算通过**（见 pitfalls #35 / #39）。

## 3. 剩余动作（原 ① ② ③ 已在第二轮完成，证据见 §2 的 11/12/13 行）

### ✅ ① 改掉 `README.md:94-96`（当时那句话是**假话**）—— 已完成

下面这段就是实际写进去的文本（现 `README.md:94-99`），原文声称 `config.json` 的 `active_skin` 已改写，实测被宿主覆盖回去了，见 #37：

```
* 已装副本也已同步换名：`%APPDATA%\OpenRevo\plugins\` 下的旧目录已删除，四套新目录已在位。
* ⚠️ `config.json` 的 `active_skin` **仍是旧值 `win11-fluent-dark`**（备份 `config.json.bak-skinrename`）。
  改写它必须在**宿主停机时**做 —— 宿主运行中会把 `config.json` 按内存里的旧值整份覆盖回去
  （2026-10-04 10:13:06 实测：改写后约 6 分钟被覆盖，同一秒落盘的 `models.json` 可佐证是宿主写的）。
  正确流程：提权停宿主 → 改 `active_skin` 为 `skin-win11-dark` → 启宿主。
```

### ✅ ② `docs/reference/pitfalls.md` 补两条 —— 已完成（实际补了三条）

计划只补 #36、#37，动手时又撞出一条**工具级**的坑，于是多补了 **#38**：

* **#38 用 DSH 的 `edit`/`write` 改 `_tools/*.ps1` 会静默吃掉文件头的 UTF-8 BOM** ——
  改完脚本突然报 4 条 PS 语法错误（`表达式或语句中包含意外的标记` / `缺少右括号` / `字符串缺少终止符` /
  `语句块缺少右括号`），症状与 #16 完全一致，实测 `head -c3` 由 `ef bb bf` 变 `23 20 72`。
  对策：改完立刻 `head -c3 x.ps1 | od -An -tx1`，缺了就
  `python -c "p='x.ps1'; d=open(p,'rb').read(); open(p,'wb').write(bytes([0xef,0xbb,0xbf])+d)"` 补回，再跑 `ParseFile`。
  **不要用「我只改了注释」推断 BOM 还在。**

原计划的两条（实际写入位置在 `## 一句话教训` 之前，沿用现有「现象 → 原因 → 对策」三列）：

* **#36 改项目目录名一律 `Device or resource busy`**：Windows 拒绝 rename 任何进程的当前工作目录，
  **包括你自己这条命令的 shell**；DSH 的 bash 工具默认 CWD 就是会话工作区（= 项目根），
  所以 `cd <项目> && mv …` 是纯粹自我阻塞。对策：从项目外面执行并显式指定工作目录
  （DSH 用 `workdir=<父目录>`），改跑 `_tools\rename-project.ps1`。
  用 `_tools\who-locks.ps1` 分类：CWD 表非空 = 第一类（关掉那些进程）；CWD 表为空仍失败 = 第二类
  （句柄占用，必须提权用 `handle.exe` 查）。
* **#37 改了 `config.json` 又被覆盖回旧值**：宿主（Tauri）运行中持有权威内存态，会整份回写 config，
  把外部改写冲掉。对策：**只在宿主停机时改**；改完比对同一时刻落盘的 `models.json` 的 mtime 判断是否被宿主回写。

同时**增强 #16**：症状除 `无法对参数 Name 执行参数验证` 外，还包括整段
`表达式或语句中包含意外的标记"}"` / `ExpectedValueExpression` 且行号指向文件末尾无关的 `}`；
根因是 PS 5.1 按 GBK 解码**无 BOM** 的 `.ps1`；关键是**整文件重写会静默吃掉 BOM**（21 个里唯一没 BOM 的就是被改过的那个），
改完必须复验 `head -c3 | od -An -tx1` 得 `ef bb bf` 再跑 `ParseFile`。

### ✅ ③ `_tools/rename-project.ps1` 的注释引用了 `pitfalls.md #36` —— 已完成

②做完才成立。顺手把该脚本当作「改名标准动作」保留。
（落地时这条自己撞上了 #38：改注释的 `edit` 调用把 BOM 吃掉，已按 #38 的 python 一行补回并 `ParseFile` 复验。**这个坑连注释改动都不放过**。）

### ④ 提权停宿主 → 改 `active_skin` → 启宿主（**已降级**：悬空 ID 已自愈，且外观零变化）

**2026-10-04 12:06:33 这条自己好了**：`config.json` 的 `active_skin` 已变成 `skin-win11-dark`（3678 B，比之前少 2 字节）。
**不是脚本改的**（无 `config.json.bak-setskin-*`；宿主仍是 pid 3976 / StartTime 09:48:00，脚本没跑过），
同一波 UI 动作的邻居是 `profiles\LIPiston.json`（12:05:19）⇒ 宿主在运行中重扫了插件目录并按新 ID 落盘。
（这与下面"只在启动时枚举"的旧观察相反；它是否已把新 ID 载入内存，外部无法确证。）

更关键的是**外观上本来就没有东西在等重启**：宿主内存里那套旧 ID 皮肤与 `skin-win11-dark` **除 ID 外逐字节相同**
（`dist/win11-fluent-dark/theme.css` vs `skin-win11-dark/theme.css`：都是 1292 行、374 个 `--wf-*` 令牌、
色字面量计数一致；裸 diff 440 行全是 ID 串，ID 归一后 **diff = 0 行**）⇒ 改名是行为中性的，
真机截图**无法判别**换没换皮肤（同面 MAE：左栏 1.00 / 顶栏 1.30 / 内容 2.99，差异全在图表内容带）。
详见 `docs/reference/real-machine-verification.md` §9。

⇒ 于是 ④ 的收益只剩「让进程内存态与磁盘目录名一致」，**不再是功能或外观修复**，可以降级为"下次自然重启时生效"。
若仍要立刻做，命令如下（自带守卫：宿主没停掉就拒绝改；目标皮肤目录不存在就拒绝改；改完 `ConvertFrom-Json` 回读复验）：

```powershell
# 1) 先空跑看清楚它要做什么（不改任何东西）
powershell -NoProfile -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 skin-win11-dark dry

# 2) 确认无误后真跑：停宿主 → 备份 config.json → 只替换 active_skin 一个字段 → 回读复验 → 启宿主 → 查是否被回写
powershell -NoProfile -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 skin-win11-dark
```

顺序不能反：**宿主运行中会周期性整份回写 `config.json`**（2026-10-04 实测三次：10:13:06、11:26:44、12:06:33，
期间无人碰过它，见 pitfalls #37），所以「先改再重启」必被冲掉，只能「先停 → 改 → 启」。

脚本会自己提权（`Start-Process -Verb RunAs`）杀宿主，并用计划任务 `OpenRevo` 重启 —— 与 `_tools\kill-and-start.ps1`
同一套手法。跑完再复读一次 `config.json` 的 mtime/大小确认没被回写，并用 `_tools\when.ps1` 比进程 `StartTime`
与插件目录 mtime（pitfalls #7）。**这一步会打断用户正在用的宿主，所以必须先拿到授权。**

> `active_skin` 选哪套：默认 `skin-win11-dark`；`_tools\set-active-skin.ps1` 的第二参数留空即为默认，
> 换别的写第一参数（`skin-win11-light` / `skin-win10-light` / `skin-win10-dark`）。

### ⑤ 用户自留：harness 镜像树

`D:\LIPis\Documents\deepseek-harness\default-workspace\openrevo-win-skin\`（149 文件，仍是旧 ID）
**全程未动**，已被文档标记为作废快照。移/删/留由用户定。

## 4. 已排除 —— 别再走一遍

* 改名失败**不是**权限问题（提权也不解决 sharing violation）、**不是**瞬时锁（连试 10 次全 busy）、
  **不是** VS Code、**不是**索引器 —— 是**我自己 shell 的 CWD**。子目录能改名、只有根目录不能，与此吻合。
* 原 19 个 `_tools/*.ps1` 里 **18 个本来就有 BOM**，唯一没有的就是被我改过的那个。
* **主窗像素色族数从来不是验收口径**（主窗 clean 图恒报 3 族，第 2/3 族只有 4~277 px）。
  验收看 `dom.hueFamilies = 2`（accent + 状态点绿），见 `docs/devlog.md:229`。
* `_tools/who-locks.ps1` 输出「把它当 CWD 的 0 个」**不等于没被占用**，但那次它恰恰说明可以下手改名了。

## 5. 环境事实（踩过的都在这）

* 本机**只有 `python`，没有 `python3`**（后者走 Microsoft Store 别名，exit 49）。
* **PowerShell 5.1**；当前 shell **未提权**（`IsInRole(Administrator)` = False）；管理员下才能枚举系统句柄表。
* 宿主 `open-revo.exe` pid 3976，StartTime `2026/10/4 9:48:00`，`requireAdministrator`。
* 模型**读不了图**（`does not declare image input`），观感判读一律走直方图/亮度/MAE/ASCII。
* **反斜杠经工具 JSON 往返会被吃一层**：Python 源码里写 `"\\_"` 会静默变成 `\_`，`\r`/`\1` 更会被当控制字符。
  要生成反斜杠**一律用 `BS = chr(92)` 拼接**，不要写在字面量里。
* **MSYS 调 `powershell -File script.ps1 -Path 'D:\…'` 时显式参数会被吃掉**（实测绑定为空）→ 改用 `$args[0]`。
* **DSH 的 bash 工具默认 CWD = 会话工作区** —— 凡是 rename/删除该目录本身的操作，必须先切到父目录。
* **DSH 的 `edit`/`write` 会静默吃掉 `.ps1` 文件头的 UTF-8 BOM**（见 pitfalls #38）——
  凡是改过 `_tools/*.ps1`，收工前一律 `head -c3 | od -An -tx1` 复验一遍。
* **偶发竞态必须靠并发压测抓**：顺序连跑 30 次都不复现的 17% 抖动，`xargs -P 8` 一轮就出 4 次
  （`_tools/_stress.sh`）。排「偶发」问题时，先把「能不能稳定复现」变成工具，再谈根因。

## 6. 新会话注意事项

* 工作区请设成 `D:\LIPis\Documents\code\openrevo-plugins`，否则写入会被沙箱拒绝（旧路径已不存在）。
* 验收命令（**首选 `verify.sh`**，它把下面几条全包了）：
  * `bash _tools/verify.sh` —— 132 条断言，全绿才算过；`NO_AUDIT=1` 可复用已有产物快速复检。
  * 底层命令：`bash _tools/audit.sh`；`PAGE=preview-mini.html bash _tools/audit.sh`；
    `bash _tools/shots.sh`（28 张图）；`python _tools/census.py _shots/mini-<id>.png`。
  * **回归压测**（只在动过 `preview-mini.html` / 皮肤 CSS 后用）：`PAGES=preview-mini.html:mini bash _tools/_stress.sh 48 8`
    —— 逐次与单跑参考 diff，末尾必须报「异常 0 次」。这是唯一能抓到那个 17% 竞态的办法（见 pitfalls #39）。
* **纪律**：不要只看 `dom.hueFamilies = 2` 就判通过 —— 负向条件挡不住「全是宿主原色」的假通过（pitfalls #35/#39）。
  必须看**正向**条件：`skin_active`、`rules_applied = 118`、`settle.remounts = 1`、`--theme-*` 六槽、五个探针色值。
* 味道：阿里味，压力 L0。

## 7. 失败计数（供恢复核对）

* 上一会话：未出现同一子目标验收的重复失败；唯一一次弯路是「排查改名占用者」，
  根因定位靠 L2 三假设 + 对照实验（子目录 vs 根目录、干净 CWD vs 脏 CWD），**已收敛**。
* 第二轮：改名占用那条路**没有**重走。真正花掉两次迭代的是迷你面板那个假读数 ——
  **第一次的归因（「那是上一次运行的陈旧产物」）是错的**，它是把「偶发」当成了「残留」，
  于是「删掉 `_audit/*.txt` 重跑」这个动作**永远修不掉它**。判定它错的是并发压测：
  当场新起 Chrome 也能复现（`sheet rules=118` 逐字段一致，排除了截断与旧文件）。
  教训不是"再仔细点"，是**偶发问题要先把复现率变成数字，再下根因**（`_tools/_stress.sh`）。
* 当前状态：**无未决失败**。`_tools/verify.sh` 132 条断言全绿；压测 48×8 异常 0。
  §3 ④（提权停宿主换 ID）在真机取证后**已降级为可选**（悬空 ID 已自愈、且新旧皮肤除 ID 外逐字节相同），
  不是失败、也不再是验收门；唯一仍未做的是「把抓图时唤醒的大面板收起」这一条副作用。
