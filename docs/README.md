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
├── OpenRevo_第三方插件开发手册.md         # 官方手册 v1.0（用例 7 = 皮肤插件）
└── reference\
    ├── host-truth-extraction.md          # 从 exe 抽宿主 CSS/JS；宿主 DOM/令牌/!important 对手规则
    ├── skin-authoring.md                 # manifest/目录、令牌与镜像架构、特异性阶梯、双面板配方
    ├── preview-and-audit.md              # 预览页能力与 URL 参数、无头 Chrome 命令、像素判据
    ├── real-machine-verification.md      # 提权重启/唤醒/置顶抓图/度量与实测基线
    └── pitfalls.md                       # 踩坑总表：现象 → 原因 → 对策
```

## 怎么用

* **人**：先读 `SKILL.md` 的「动手前必读的硬约束」，再按「标准工作流」表走；卡住时查 `pitfalls.md`。
* **Agent**：把整个 `docs\` 当作技能目录（建议目录名 `openrevo-skin-plugin\`），加载 `SKILL.md` 作为入口；
  只有需要细节时才读 `reference\` 下的文件，避免一次性灌入全部内容。

## 维护约定

* 宿主升级后，`reference\host-truth-extraction.md` 里的**字节偏移、规则条数**会失效，必须重新定位
  （真实案例与复核流程：`devlog.md` §9、`reference\real-machine-verification.md` §2.1）；
  `real-machine-verification.md` 里的几何/直方图/MAE 是**该版本的基线**，仅用于回归对比。
* 代码改完请同步这三处：`README.md`（项目根）、`docs\devlog.md`（这一轮新增了什么）、
  以及受影响的 `docs\reference\*.md`。
* **配色是硬约束**：整份 UI 只有 `--wf-accent`（系统主题色）+ `--wf-important`（重要强调色）两个装饰色
  （用户口径 m00001 / m00053）。加新部件时先读 `SKILL.md` 的「配色纪律」一节；
  改完必须跑 `bash _tools\verify.sh`（验收总闸，132 条断言，`exit 1` 就是没改完）；它内含 `audit.sh`
  的 `dom.hueFamilies = 2` 与 `census.py` 的色族数 = 2，并额外核对正向条件 —— **只看族数 = 2 会骗人**：
  坏读数里全是宿主原色时，族数也恰好是 2（`pitfalls.md` #35 / #39）。动过预览页或皮肤 CSS 后，另跑
  `PAGES=preview-mini.html:mini bash _tools\_stress.sh 48 8`，须报「异常 0 次」。
* **本目录只在权威树 `D:\LIPis\Documents\code\openrevo-plugins\` 维护。**
  历史上同一份内容散在两棵树里，已踩过「改了 A 树、审计了 B 树」的坑；
  harness 工作区那棵 `…\default-workspace\openrevo-win-skin\` 是 2026-10-04 改名前的快照，**已作废，不要再同步**。
