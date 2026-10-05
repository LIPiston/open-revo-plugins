# OpenRevo 皮肤插件 · 文档与技能包

这个目录同时承担两件事：

1. **开发记录**：`devlog.md` 记录这一轮从读手册到真机取证的完整时间线、每一步的数字证据与未决项。
2. **可复用技能**：`SKILL.md` + `reference\*.md` 是一份按 Agent Skills 规范组织的技能包
   （YAML frontmatter 的 `name` / `description`，主文件 + 分层参考文件），供下次开发或修改 OpenRevo 皮肤时直接加载。

## 文件

```
docs\
├── README.md                            # 本文件
├── SKILL.md                             # 技能入口：硬约束 + 工作流 + 验收清单 + 参考地图
├── devlog.md                            # 开发记录（时间线 + 证据 + 未决项）
├── OpenRevo_第三方插件开发手册.md         # 官方手册 v1.0 存档（用例 7 = 皮肤插件）
└── reference\
    ├── plugin-dev-0.8.8-skill.md         # 官方新版 Skill（0.8.8）逐条实测对照 + 背景壁纸通道
    ├── plugin-manual-digest.md           # 手册消化件 + 「手册 ≠ 发行版」对照表
    ├── host-truth-extraction.md          # 从 exe 抽宿主 CSS/JS；宿主 DOM/令牌/!important 对手规则
    ├── skin-authoring.md                 # manifest/目录、令牌与镜像架构、特异性阶梯、双面板配方
    ├── background-plugin.md              # 自定义背景图独立插件：data URI、遮罩同层、0.8.7 单通道互斥 → 0.8.8 background 通道
    ├── preview-and-audit.md              # 预览页能力与 URL 参数、无头 Chrome 命令、像素判据
    ├── real-machine-verification.md      # 提权重启/唤醒/置顶抓图/度量与实测基线
    ├── environment-and-tools.md          # 环境硬事实 + 工具地图 + 证据索引 + 回退清单
    └── pitfalls.md                       # 踩坑总表：现象 → 原因 → 对策
```

> **仓库外的原文**：开发者新版 skill 在 `D:\LIPis\desktop\openrevo-plugin-dev\SKILL.md`（415 行）。
> 它**不在本仓库内**，所以上面的对照页 `plugin-dev-0.8.8-skill.md` 是它的**唯一耐久存档**；
> 原文若变动，以本页记录的实测判定为准重新核对。

## 怎么用

* **人**：先读 `SKILL.md` 的「动手前必读的硬约束」，再按「标准工作流」表走；卡住时查 `pitfalls.md`。
* **Agent**：把整个 `docs\` 当作技能目录（建议目录名 `openrevo-skin-plugin\`），加载 `SKILL.md` 作为入口；
  只有需要细节时才读 `reference\` 下的文件，避免一次性灌入全部内容。
  另有一份对应的 DSH 技能可直接召唤：`C:\Users\LIPis\.dsh\skills\openrevo-skin-plugin\SKILL.md`
  （**浓缩版入口**，真值仍以本目录为准；本目录改了要顺手同步它）。

## 维护约定

* 要接手/交接这摊事（环境、工具在哪、证据在哪、怎么退回用户原状、哪些明确没做）→ 直接看
  `reference\environment-and-tools.md`。原先那两份一次性接手文档（`HANDOVER.md` / `HANDOFF.md`）已于
  2026-10-04 删除，耐久内容全部并入该页；原件保留在 git 提交 `c1e2e03` 里，随时可取回。
* 宿主升级后，`reference\host-truth-extraction.md` 里的**字节偏移、规则条数**会失效，必须重新定位
  （真实案例与复核流程：`devlog.md` §9、`reference\real-machine-verification.md` §2.1）；
  `real-machine-verification.md` 里的几何/直方图/MAE 是**该版本的基线**，仅用于回归对比。
* 代码改完请同步这三处：`README.md`（项目根）、`docs\devlog.md`（这一轮新增了什么）、
  以及受影响的 `docs\reference\*.md`。
* **配色是硬约束**：整份 UI 只有 `--wf-accent`（系统主题色）+ `--wf-important`（重要强调色）两个装饰色
  （用户口径 m00001 / m00053）。⚠️ `--wf-*` 是**本工具链自己的前缀**（`build_skins.py` 的 `token_block()` :352
  把配色写进宿主 `--theme-<key>{,-border,-dim,-glow}` 槽位后镜像而来），**不是宿主令牌** —— 宿主真值是
  `--surface-*` / `--border-*` / `--text-*` / `--status-*` / `--radius-*`（见 `reference\plugin-dev-0.8.8-skill.md` §5.2）。
  加新部件时先读 `SKILL.md` 的「配色纪律」一节；
  改完必须跑 `bash _tools\verify.sh`（验收总闸，132 条断言，`exit 1` 就是没改完）；它内含 `audit.sh`
  的 `dom.hueFamilies = 2` 与 `census.py` 的色族数 = 2，并额外核对正向条件 —— **只看族数 = 2 会骗人**：
  坏读数里全是宿主原色时，族数也恰好是 2（`pitfalls.md` #35 / #39）。动过预览页或皮肤 CSS 后，另跑
  `PAGES=preview-mini.html:mini bash _tools\_stress.sh 48 8`，须报「异常 0 次」。
* **背景插件是独立的一条链**：真值在 `bg.config.json`，模板在 `src\background.css`，改完跑
  `python build_background.py build`（重新编码图片）再跑 `bash _tools\verify-bg.sh` —— 它第一条就是
  「既有 132 条无回归」，所以背景链不会绕过皮肤验收。产物 `bg-custom\`（默认）与 `<id>-bg\`（显式
  `--targets` 才有）**入库即装即用**，与四套 `skin-*\` 同等对待；`assets\sample-wallpaper.jpg` 是
  确定性源图，保证任何 clone 都能构建出同一份产物。⚠️ **0.8.7** 宿主只有一条 CSS 注入通道、`active_skin` 单值，
  那时「背景插件」与「Fluent 皮肤」在宿主层面互斥；**0.8.8 已新增 `plugin_type:"background"` 的独立通道**
  （`active_background` → `<style id="openrevo-custom-background">`），两者可同时启用 —— 详见
  `reference\background-plugin.md` §0、`reference\plugin-dev-0.8.8-skill.md` §1。
  **按用户口径 m00785，这部分功能「先不做」**：代码与验收都在，但**刻意不装进宿主、不激活**
  （宿主侧零改动，`active_skin` 仍是 `skin-win11-dark`）。卡点已在 0.8.8 解除，但本仓库产物仍是
  `plugin_type:"skin"` 形态，改造前装上仍会顶掉皮肤；改造清单见 `reference\plugin-dev-0.8.8-skill.md` §7 第 8 项，
  现状说明见 `reference\background-plugin.md` §0.2。
* **本目录只在权威树 `D:\LIPis\Documents\code\openrevo-plugins\` 维护。**
  历史上同一份内容散在两棵树里，已踩过「改了 A 树、审计了 B 树」的坑；
  harness 工作区那棵 `…\default-workspace\openrevo-win-skin\` 是 2026-10-04 改名前的快照，**已作废，不要再同步**。
