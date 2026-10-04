# OpenRevo 开发者圣经：全场景插件与扩展开发手册 (Plugin Developer Bible)

> **版本**：`v1.0 Official Specification`  
> **面向对象**：OpenRevo 社区极客、二次元/机甲皮肤设计师、独立客户端重构者、AI Agent 开发者、硬件自动化极客  
> **设计哲学**：基于微内核与能力网关，实现“按需分配运行时（Runtime on Demand）、物理沙盒隔离、可逆副作用、零污染与即插即用”。

> ⚠️ **本文件是官方 v1.0 原文存档，不是行为准则 —— 动手前先读 `reference/plugin-manual-digest.md` §10「手册 ≠ 发行版」。**
> 已知不一致（都已实测复核）：清单示例写 `"type"`，发行版认的权威键是 **`plugin_type`**；
> 示例里的 `.overview-main-grid` / `.sensor-gauge-cluster` / `.cooling-fan-card` / `.power-mode-selector`
> 在发行版 CSS 里**不存在**；手册的 `--core-*` / `--surface-*` / `--status-*` 令牌**不存在**（真值是 `--wf-*` 一套）；
> 手册说「插件页点刷新即热加载」，但宿主**只在启动时枚举插件目录** —— 皮肤必须重启宿主才会生效。

---

## 目录
1. [微内核架构宣言：OpenRevo 的本质是什么？](#1-微内核架构宣言openrevo-的本质是什么)
2. [6 种插件形态全景对照表 (一切皆插件生态矩阵)](#2-6-种插件形态全景对照表-一切皆插件生态矩阵)
3. [核心安全军规与沙盒边界 (Rule 4 硬件防火墙)](#3-核心安全军规与沙盒边界-rule-4-硬件防火墙)
4. [插件清单权威规范 (Plugin Manifest Reference)](#4-插件清单权威规范-plugin-manifest-reference)
5. [硬件 IPC 控制能力军火库速查 (Capabilities Cheat Sheet)](#5-硬件-ipc-控制能力军火库速查-capabilities-cheat-sheet)
6. [自适应遥测与动态心跳总线 (Telemetry Bus)](#6-自适应遥测与动态心跳总线-telemetry-bus)
7. [经典实战用例集 (从桌面桌宠到无头脚本)](#7-经典实战用例集-从桌面桌宠到无头脚本)
   - [用例 1: 50 行代码开发一个桌面异形机甲桌宠 (Widget)](#用例-1-50-行代码开发一个桌面异形机甲桌宠-widget)
   - [用例 2: 桌面“一键强冷”大开关挂件 (Widget)](#用例-2-桌面一键强冷大开关挂件-widget)
   - [用例 3: 纯文本脚本自定义开机仪式灯效 (Headless Service - 零 Webview)](#用例-3-纯文本脚本自定义开机仪式灯效-headless-service---零-webview)
   - [用例 4: 桌面 AI 助手 Function Calling 联动控制](#用例-4-桌面-ai-助手-function-calling-联动控制)
   - [用例 5: 完全重写前端！自建独立替代控制台 (Alternative Shell)](#用例-5-完全重写前端自建独立替代控制台-alternative-shell)
   - [用例 6: 进阶机甲桌宠工程规范 —— 边缘吸附灵动小球、动态换肤与跨插件事件总线 (Advanced Widget)](#用例-6-进阶机甲桌宠工程规范--边缘吸附灵动小球动态换肤与跨插件事件总线-advanced-widget)
   - [用例 7: 主窗口主题皮肤与插槽化布局重排 (Skin Plugin —— 一切皆插件)](#用例-7-主窗口主题皮肤与插槽化布局重排-skin-plugin--一切皆插件)
8. [UI 设计语言与 Design Tokens 复用指南](#8-ui-设计语言与-design-tokens-复用指南)
9. [调试与安全模式排错 (Safe Mode 二分法)](#9-调试与安全模式排错-safe-mode-二分法)

---

## 1. 微内核架构宣言：OpenRevo 的本质是什么？

很多开发者初次接触 OpenRevo 时，以为它仅仅是一个“机械革命第三方笔记本控制中心软件”。**这是对 OpenRevo 最大的低估**。

### 核心真相：OpenRevo 的本质是「笔记本硬件微内核平台（Hardware Microkernel）」
* **底座是真正的微内核 (Rust Core Engine)**：
  它掌控着 Ring0 ACPI 驱动通信、同方与宝龙达模具的 EC 物理寄存器钥匙库（Vault）、NVIDIA 显卡驱动交互、ITE 独立芯片的高性能 60 FPS 键盘流光推流（Better RGB）、低功耗蓝牙外置水冷魔盒通信以及底层键盘钩子。
* **官方自带的 `main` 主控制台，仅仅是一个“默认客户端”**：
  官方的 React 亚克力界面只是运行在微内核上的一个 Webview 展现层。
* **一切皆可插拔，前端完全可以自定义**：
  如果用户愿意，**完全可以关掉官方自带的 `main` 界面**，桌面上只挂一个极简的透明机甲桌宠；或者使用 Vue、Svelte、原生 HTML5、甚至是纯 Python 脚本，自建一套完全属于自己的赛博朋克控制台！微内核都会默默在后台提供坚如磐石的硬件驱动和毫秒级总线调度。

```
┌────────────────────────────────────────────────────────────────────────┐
│                        OpenRevo 微内核平台架构图                       │
├────────────────────────────────────────────────────────────────────────┤
│  [官方默认控制台]    [第三方异形桌宠]    [AI语音助手]    [极客自建客户端]   │
│  (React Full GUI)    (Chibi Widget)     (Desktop Agent) (Custom Webview) │
├────────────────────────────────────────────────────────────────────────┤
│                       Tauri 2 跨窗口事件与 IPC 通信总线                 │
│         ├─ hardware-state-updated (按需自适应毫秒级遥测流)              │
│         ├─ fan-boost-changed / physical-mode-switched (硬件状态广播)   │
│         └─ invoke('set_fan_boost') / invoke('set_power_mode') (控制API) │
├────────────────────────────────────────────────────────────────────────┤
│                   HAL Capability Broker 语义化能力网关                  │
│             (权限防呆 ➔ 边界钳位 ➔ 阻断裸 EC 寄存器 ➔ 自动析构)         │
├────────────────────────────────────────────────────────────────────────┤
│                 Hardware Vault (硬件钥匙库与原生内核驱动)               │
│      [Tongfang ACPI IOCTL]   [ITE Lighting HID]   [WinRT Bluetooth]    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 6 种插件形态全景对照表 (一切皆插件生态矩阵)

OpenRevo 坚决反对“无脑开 Webview”。我们确立了**按需分配运行时原则**与**“一切皆插件”大一统哲学**：无论桌面悬浮挂件、主控制台皮肤、功能插槽页还是无头服务，统一作为插件收拢在 `%APPDATA%\OpenRevo\plugins\<plugin_id>\` 下管理！

| 插件形态 (`plugin_type`) | 典型应用场景 | 运行时载体 | 增量内存开销 | 视窗特性 |
| :--- | :--- | :--- | :--- | :--- |
| **`skin` (主窗口皮肤外观)** | 机甲二次元主题换肤、模块插槽网格重排、自定义窗口尺寸与背景 | **宿主主窗口 Webview**<br>(动态注入 `theme.css` + `data-skin`) | **0 MB**<br>(纯样式与布局重排，极速热装卸) | 自动平滑重置主窗口几何尺寸 (`manifest.window`)，自适应锁定或自由拉伸 |
| **`tab` (主界面插槽选项卡)** | 显卡高级调试页、风扇实验室、社区扩展页面 | **宿主主窗口沙盒 iframe**<br>(安全隔离 + 跨域推流) | **< 5 MB**<br>(复用 Chromium 进程上下文) | 嵌入在官方主控制台顶栏 Sub-Nav 胶囊栏与内容视口中 |
| **`widget` (桌面悬浮挂件)** | 机甲能量核心桌宠、HUD 状态条、桌面看板娘、大开关 | **独立 Edge WebView2**<br>(物理沙盒隔离) | **15MB ~ 25MB**<br>(共享 Chromium 渲染段) | 全透明、无边框、置顶、跳过任务栏、可拖拽 |
| **`service` (无头后台服务)** | 开机欢迎灯效覆盖、自动温控曲线、按电量切模式 | **Rust 内置 Rhai 引擎 / 异步后台微任务** | **< 100 KB**<br>(极致轻量) | **完全无界面 (Zero GUI)**，坚决不弹窗 |
| **`shell` (替代型客户端)** | 用户嫌官方界面不好看，自建全新极简/赛博控制台 | **独立全尺寸 Webview** | ~35MB | 拥有主控权，可彻底取代官方 `main` 界面 |
| **`driver` (模具驱动适配)** | 适配宝龙达新机型、机械革命未来新架构 | **原生 Rust 动态库 (.dll)** | 0 运行时开销 | 直接与 ACPI/WMI 驱动对接 |

---

## 3. 核心安全军规与沙盒边界 (Rule 4 硬件防火墙)

笔记本硬件涉及高压供电、功耗墙释放与风扇转速。任何代码错误或越权写入都可能导致主板断电甚至硬件损坏。所有插件开发必须遵守以下铁律：

1. **绝对禁止裸物理寄存器交互（Rule 4 硬件资产钥匙库守则）**：
   * 严禁在插件中请求类似 `ec_write(0x1844, 0x01)` 或 dump 整块 EC RAM。
   * OpenRevo 仅对外暴露**“语义化硬件控制指令”**（如 `set_fan_boost(true)`）。
2. **硬件物理边界防呆（Guardrails）**：
   * 功耗墙调节范围由机型固件严格钳位（例如 PL4 必须 `<= 255W`，防 0xFF 翻转单字节溢出为 45W 慢充）。
   * 电池养护限额严格限制在 `60% ~ 100%` 之间。
3. **非侵入式执行（Non-blocking）**：
   * 严禁在主线程执行耗时同步阻塞；网络请求与大模型调用必须采用异步流式处理。

---

## 4. 插件清单权威规范 (Plugin Manifest Reference)

每个插件为一个独立文件夹，存放于 `%APPDATA%\OpenRevo\plugins\<plugin_id>\`。根目录下必须包含 `manifest.json`：

```json
{
  "id": "eva01-core",
  "name": "EVA-01 初号机 S2 能量核心",
  "version": "1.0.0",
  "author": "OpenRevo Community",
  "description": "异形拟态机甲桌宠挂件，支持结温脉冲呼吸、风扇转速联动与一键强冷暴走切换。",
  "plugin_type": "widget",
  "entry": "index.html",
  "window": {
    "width": 260,
    "height": 180,
    "transparent": true,
    "always_on_top": true,
    "resizable": false
  },
  "telemetry": {
    "enabled": true,
    "desiredIntervalMs": 1500,
    "sensors": [
      "cpu_temp",
      "cpu_fan_rpm",
      "cpu_power_w",
      "power_mode",
      "fan_boost"
    ]
  },
  "permissions": [
    "telemetry:read",
    "power:control",
    "fan:control"
  ]
}
```

### 清单字段详细说明

| 字段名 | 类型 | 是否必填 | 适用类型 | 描述 |
| :--- | :--- | :--- | :--- | :--- |
| `id` | `string` | **必填** | 全类型 | 插件全局唯一标识符（纯英文、数字、下划线、中划线） |
| `name` | `string` | **必填** | 全类型 | 人类可读的插件名称，展示于插件管理器 |
| `version` | `string` | **必填** | 全类型 | 语义化版本号（如 `1.0.0`） |
| `plugin_type` | `string` | **必填** | 全类型 | 插件形态：`"skin"` \| `"tab"` \| `"widget"` \| `"service"` \| `"shell"` |
| `theme_css` | `string` | `skin`必选 | `skin` | 皮肤样式表入口文件相对路径（如 `"theme.css"`） |
| `entry` | `string` | 可选 | `widget`/`tab`/`service` | 入口相对路径，如 `index.html` 或 `welcome.rhai` |
| `window` | `object` | 可选 | `widget`/`skin`/`shell` | 视窗几何属性（宽高、透明度、置顶、可调整大小） |
| `telemetry` | `object` | 可选 | 全类型 | 声明硬件遥测需求（见下文防独显唤醒机制） |
| `permissions` | `string[]`| 可选 | 全类型 | 声明所需权限（未声明将被安全网关拦截） |

---

## 5. 硬件 IPC 控制能力军火库速查 (Capabilities Cheat Sheet)

在独立 Webview 或插件前端中，只要引入 `@tauri-apps/api/core` 的 `invoke`，即可直接调用微内核暴露的 8 大硬件控制指令：

```javascript
import { invoke } from '@tauri-apps/api/core';
```

### 1. 一键全速强冷 (Fan Boost)
* **指令**：`invoke('set_fan_boost', { enable: boolean })`
* **硬件动作**：向 EC 写入强冷标志位，风扇瞬间以 5400+ RPM 暴走排气；托盘图标加风扇角标，广播 `fan-boost-changed`。

### 2. 性能模式切换 (Power Mode)
* **指令**：`invoke('set_power_mode', { mode: 1 | 2 | 3 | 4 })`
* **模式映射**：`1-办公(Office)`, `2-均衡(Balance)`, `3-狂暴(Turbo/Beast)`, `4-自定义(Custom)`。
* **硬件动作**：刷新 CPU PL1/PL2/PL4 功耗偏置，调整风扇曲线与动态背光，广播 `physical-mode-switched`。

### 3. 电池健康养护限额 (Battery Protect)
* **指令**：`invoke('set_battery_limit', { limit: number })`
* **参数范围**：`60 ~ 100`（通常设定为 60%、80% 或 100%）。
* **硬件动作**：写入 EC 电池控制寄存器。达到指定电量后硬件直接断充，避免电芯持续高压鼓包。

### 4. 屏幕刷新率瞬切 (Display Refresh Rate)
* **指令**：`invoke('switch_refresh_rate', { hz: number })`
* **常用参数**：`60`（离电省电）或 `165` / `240`（游戏电竞）。
* **硬件动作**：调用 Win32 底层显示配置无黑屏快速切换。

### 5. 显卡模式直连切换 (GPU MUX)
* **指令**：`invoke('set_gpu_mode', { mode: string })`
* **模式选项**：`"discrete"` (独显直连性能最大化), `"hybrid"` (混合输出兼顾续航)。

### 6. 四分区全彩键盘背光 (RGB Lighting)
* **指令**：`invoke('apply_four_zone_colors', { zone1: [r,g,b], zone2: [r,g,b], zone3: [r,g,b], zone4: [r,g,b] })`
* **硬件动作**：调用 ITE 键盘灯控接口下发色彩。

### 7. 第二代外置水冷魔盒调控 (BLE Cooler)
* **指令**：`invoke('set_water_cooler_speed', { level: number })`
* **硬件动作**：WinRT 蓝牙低功耗向水冷盒下发泵速与转速挡位。

### 8. 硬件外设软开关 (Device Switches)
* **指令**：`invoke('set_device_switch', { device: string, enabled: boolean })`
* **设备标识**：`"camera"` (摄像头), `"mic"` (麦克风), `"touchpad"` (触控板), `"winlock"` (Win键锁定)。

---

## 6. 自适应遥测与动态心跳总线 (Telemetry Bus)

### 1. 核心铁律：防独显唤醒 (Zero dGPU Wake-lock)
双显卡笔记本在轻度办公时，NVIDIA 独立显卡处于 **D3Cold 极深零功耗休眠 (0W)**。
* **严禁无脑索取 GPU 字段**：若挂件仅需要 CPU 结温和风扇转速，`manifest.json` 中**坚决不要声明 `gpu_*` 字段**！
* **内核保障**：若所有运行中的插件均未订阅 GPU，微内核**绝不调用 NVAPI**，让独显继续保持零功耗停机。

### 2. 纯陪伴小人 / 语音助手的“零功耗深睡模式”
纯陪伴小人或 AI 语音助手不需要任何传感器，只需在 `manifest.json` 中声明：
```json
"telemetry": {
  "enabled": false
}
```
内核看到此标记，即使挂着 5 个小人，**硬件遥测线程依然安详深睡，硬件零负担，CPU 维持极深 C-State**。

### 3. 前端消费数据总线流
在任何 Webview 挂件中，监听全局公频广播：
```javascript
import { listen } from '@tauri-apps/api/event';

// 监听每 1.5s 广播的硬件状态流
const unlisten = await listen('hardware-state-updated', (event) => {
  const data = event.payload; // HardwareState 强类型对象
  console.log(`CPU温度: ${data.cpu_temp}℃, 风扇转速: ${data.cpu_fan_rpm}RPM`);
});
```

---

## 7. 经典实战用例集 (从桌面桌宠到无头脚本)

### 用例 1: 50 行代码开发一个桌面异形机甲桌宠 (Widget)

新建文件夹 `%APPDATA%\OpenRevo\plugins\eva-pet\`，放置 `manifest.json` 与 `index.html`：

**`manifest.json`**：
```json
{
  "id": "eva-pet",
  "name": "EVA 机甲桌宠",
  "version": "1.0.0",
  "type": "widget",
  "window": { "width": 200, "height": 200, "transparent": true, "alwaysOnTop": true }
}
```

**`index.html`**：
```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { margin: 0; background: transparent; overflow: hidden; user-select: none; }
    #core {
      width: 180px; height: 180px; border-radius: 50%;
      background: rgba(15, 23, 42, 0.85); backdrop-filter: blur(16px);
      border: 2px solid var(--glow, #38bdf8);
      box-shadow: 0 0 24px var(--glow, #38bdf8);
      display: flex; flex-direction: column; align-items: center; justify-content: center;
      color: #fff; font-family: monospace; cursor: grab;
      transition: all 0.3s ease;
    }
  </style>
</head>
<body>
  <div id="core">
    <span style="font-size: 11px; opacity: 0.6;">S² 能量核心</span>
    <span id="temp" style="font-size: 38px; font-weight: 900;">--°</span>
    <span id="fan" style="font-size: 10px; opacity: 0.7;">-- RPM</span>
  </div>

  <script type="module">
    import { listen } from '@tauri-apps/api/event';
    import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';

    // 拖拽窗口支持（推荐使用 pointerdown 单一入口，严禁与 data-tauri-drag-region 混用导致底层冲突）
    document.getElementById('core').addEventListener('pointerdown', (e) => {
      if (e.button === 0) getCurrentWebviewWindow().startDragging();
    });

    // 消费硬件遥测流
    listen('hardware-state-updated', (e) => {
      const data = e.payload;
      const temp = data.cpu_temp || 45;
      document.getElementById('temp').innerText = `${temp}°`;
      document.getElementById('fan').innerText = `${data.cpu_fan_rpm || 0} RPM`;

      // 温度驱动核心变色：>80℃ 猩红, >68℃ 琥珀橙, 平常天蓝
      const glow = temp > 80 ? '#ef4444' : (temp > 68 ? '#f59e0b' : '#38bdf8');
      document.getElementById('core').style.setProperty('--glow', glow);
    });
  </script>
</body>
</html>
```

---

### 用例 2: 桌面“一键强冷”大开关挂件 (Widget)

用户嫌每次打开控制中心麻烦，只想在桌面上摆个硕大的实体质感按钮，按一下强冷，再按一下恢复：

```html
<button id="turbo-btn" style="width: 140px; height: 50px; background: #ef4444; color: #fff; border-radius: 12px; font-weight: bold; cursor: pointer;">
  🔥 切换全速强冷
</button>

<script type="module">
  import { invoke } from '@tauri-apps/api/core';
  import { listen } from '@tauri-apps/api/event';

  let isBoosting = false;
  const btn = document.getElementById('turbo-btn');

  // 点击立刻下发硬件强冷
  btn.addEventListener('click', async () => {
    isBoosting = !isBoosting;
    await invoke('set_fan_boost', { enable: isBoosting });
  });

  // 同步物理按键或托盘触发的状态改变
  listen('fan-boost-changed', (e) => {
    isBoosting = e.payload;
    btn.innerText = isBoosting ? '❄️ 强冷运行中' : '🔥 开启全速强冷';
    btn.style.background = isBoosting ? '#06b6d4' : '#ef4444';
  });
</script>
```

---

### 用例 3: 纯文本脚本自定义开机仪式灯效 (Headless Service - 零 Webview)

用户想自定义电脑开机时键盘的流光欢迎仪式，**完全不需要任何 Webview 窗口，仅占用 <100KB 内存**：

**`manifest.json`**：
```json
{
  "id": "cyber-welcome",
  "name": "赛博开机灯效仪式",
  "version": "1.0.0",
  "type": "service",
  "target": "lighting.welcome",
  "entry": "welcome.rhai"
}
```

**`welcome.rhai`**（嵌入式脚本，在 Rust 内部极速执行）：
```rust
// 当系统检测到用户开机登录时自动触发
fn on_startup_ceremony() {
    // 阶段 1: 冰蓝呼吸唤醒
    set_keyboard_rgb(0, 255, 255);
    sleep(400);
    // 阶段 2: 霓虹粉紫能量注入
    set_keyboard_rgb(255, 0, 128);
    sleep(400);
    // 阶段 3: 狂暴红脉冲
    set_keyboard_rgb(255, 30, 30);
    sleep(300);
}
```

---

### 用例 4: 桌面 AI 助手 Function Calling 联动控制

用户吼一声：“**帮我开一键强冷**”或“**有点热，吹大点风**”。  
桌面 AI 助手（Brain）解析意图后，通过 Function Calling 直接下发硬件指令：

```javascript
// AI Agent 内部注册的 Tools Schema
const tools = [
  {
    name: 'set_fan_boost',
    description: '开启或关闭机械革命笔记本全速强冷模式 (Fan Boost)',
    parameters: {
      type: 'object',
      properties: { enable: { type: 'boolean' } },
      required: ['enable']
    }
  }
];

// 当大模型返回 Tool Call 时执行
async function handleToolCall(toolCall) {
  if (toolCall.name === 'set_fan_boost') {
    const { enable } = JSON.parse(toolCall.arguments);
    // 直接下发微内核 Ring0 指令！
    await invoke('set_fan_boost', { enable });
    return `已成功${enable ? '开启' : '关闭'}强冷模式！`;
  }
}
```

---

### 用例 5: 完全重写前端！自建独立替代控制台 (Alternative Shell)

如果你觉得官方的 React 亚克力主界面不符合你的极客审美，**你可以完全重写一个前端**：

1. **设置开机不弹官方主窗口**：
   在 `%APPDATA%\OpenRevo\config.json` 中配置：
   ```json
   {
     "wake_window_mode": "mini",
     "autostart": true
   }
   ```
2. **注册自己的 `shell` 插件**：
   在插件目录中声明 `"type": "shell"`，OpenRevo 会拉起你的主窗口。你的窗口可以使用 Vue3、Svelte、SolidJS 或者 WebGL 3D 渲染整台笔记本的剖面结构，通过本手册第 5 节的 8 大硬件指令全面接管机器！

---

### 用例 6: 进阶机甲桌宠工程规范 —— 边缘吸附灵动小球、动态换肤与跨插件事件总线 (Advanced Widget)

如果你不仅想实现一个简单的状态展示板，而是希望开发一个**具备多套动态皮肤、动画序列、拖拽至屏幕边缘自动折叠为半露微光小球、并且能与其他插件联动呼应**的完整级桌面桌宠挂件，推荐采用以下标准工程解构：

#### 1. 进阶工业级工程目录树 (Standard Layout)
位于 `%APPDATA%\OpenRevo\plugins\eva01-companion/`：
```text
eva01-companion/
│
├── manifest.json              # [核心清单] 插件元数据、窗口物理尺寸、权限声明与遥测传感器列表
├── index.html                 # [视窗容器] Webview 视窗入口（纯 HTML5，透明无边框）
│
├── css/
│   ├── main.css               # 主布局、毛玻璃亚克力与交互微动效
│   ├── dock.css               # 边缘停靠、折叠小球形态与展开动画关键帧 (@keyframes)
│   └── themes/                # 动态换肤样式包 (CSS 变量设计令牌)
│       ├── eva01-purple.css   # 初号机经典紫绿配色
│       ├── eva02-asuka.css    # 二号机暴走红橙配色
│       └── cyber-dark.css     # 极客透明单色微光配色
│
├── js/
│   ├── app.js                 # 主逻辑调度入口、生命周期与 DOM 初始化
│   ├── dock.js                # 屏幕边缘碰撞检测、吸附停靠与小球折叠状态机
│   ├── bus.js                 # 跨插件事件总线广播与监听器 (Cross-Plugin Bus)
│   └── skin.js                # 动态无感热换肤引擎与本地偏好持久化
│
└── assets/                    # 静态资产仓库
    ├── animations/            # 动态动画序列（Lottie JSON / APNG / WebM 透明动图 / SVG 矢量）
    │   ├── idle.svg           # 待机平稳呼吸形态
    │   ├── boost.svg          # 强冷暴走喷射形态
    │   └── ball-orbit.svg     # 边缘贴边小球微动特效
    ├── sounds/                # 拟物音效（可选，如点击、暴走提示音）
    │   └── switch.mp3
    └── preview.png            # 插件在 OpenRevo 插件管理面板中展示的缩略封面
```

#### 2. 清单权威声明 (`manifest.json`)
```json
{
  "id": "eva01-companion",
  "name": "EVA-01 初号机灵动桌宠",
  "version": "1.2.0",
  "author": "OpenRevo Community",
  "description": "异形拟态机甲桌宠，支持边缘吸附小球、初号机/二号机动态换肤与跨插件事件联动。",
  "type": "widget",
  "entry": "index.html",
  "window": {
    "width": 240,
    "height": 180,
    "transparent": true,
    "alwaysOnTop": true,
    "resizable": false
  },
  "telemetry": {
    "enabled": true,
    "desiredIntervalMs": 1500,
    "sensors": [
      "cpu_temp",
      "cpu_fan_rpm",
      "fan_boost"
    ]
  },
  "permissions": [
    "telemetry:read",
    "fan:control",
    "power:control"
  ]
}
```

#### 3. 边缘吸附与折叠小球机制 (`dock.js` + `dock.css`)
利用 Tauri 的 `getCurrentWebviewWindow()` 动态嗅探窗口物理外框与当前屏幕边界。当挂件被拖拽至屏幕右侧边界（阈值 30px）时，窗口物理尺寸无缝收缩为 `48×48`，DOM 自动切换为吸附小球样式；当鼠标移入小球判定区时，自动弹开恢复完整面板：

```javascript
// js/dock.js
import { getCurrentWebviewWindow } from '@tauri-apps/api/webviewWindow';
import { currentMonitor } from '@tauri-apps/api/window';
import { LogicalSize, LogicalPosition } from '@tauri-apps/api/dpi';

const appWindow = getCurrentWebviewWindow();
let isDocked = false;

// 拖拽释放后触发贴边校验
export async function checkEdgeDock() {
  const monitor = await currentMonitor();
  if (!monitor) return;

  const scale = monitor.scaleFactor;
  const winPos = await appWindow.outerPosition();
  const screenW = monitor.size.width / scale;
  const curX = winPos.x / scale;

  // 靠近右侧边缘（小于 30px）触发吸附折叠
  if (screenW - (curX + 240) < 30) {
    isDocked = true;
    document.body.classList.add('docked-bubble');
    // 窗口平滑收缩为 48x48 悬浮微球，贴紧屏幕最右侧
    await appWindow.setSize(new LogicalSize(48, 48));
    await appWindow.setPosition(new LogicalPosition(screenW - 48, winPos.y / scale));
  }
}

// 悬停展开完整看板
export function initDockEvents() {
  const bubble = document.getElementById('bubble-hitbox');
  bubble.addEventListener('pointerenter', async () => {
    if (isDocked) {
      document.body.classList.remove('docked-bubble');
      await appWindow.setSize(new LogicalSize(240, 180));
    }
  });

  document.getElementById('core-panel').addEventListener('pointerleave', async () => {
    if (isDocked) {
      document.body.classList.add('docked-bubble');
      await appWindow.setSize(new LogicalSize(48, 48));
    }
  });
}
```

```css
/* css/dock.css */
:root {
  --core-accent: #6366f1;
  --core-glow: rgba(99, 102, 241, 0.4);
}

/* 正常展开看板 */
#core-panel {
  width: 240px;
  height: 180px;
  border-radius: 16px;
  background: rgba(15, 23, 42, 0.85);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.1);
  transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

/* 边缘折叠小球形态 */
body.docked-bubble #core-panel {
  display: none;
}
body.docked-bubble #bubble-hitbox {
  display: flex;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: rgba(15, 23, 42, 0.9);
  border: 2px solid var(--core-accent);
  box-shadow: 0 0 16px var(--core-glow);
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transform: translateX(10px); /* 贴边半露小球胶囊 */
}
```

#### 4. 多套皮肤无感热切换与资产组织 (`skin.js`)
皮肤切换采用 CSS Design Tokens 隔离，绝不在 JS 中写死任何样式数值：
```javascript
// js/skin.js
const THEMES = ['eva01-purple', 'eva02-asuka', 'cyber-dark'];

export function applyTheme(themeName) {
  // 1. 动态挂载主题样式表
  const link = document.getElementById('theme-stylesheet');
  link.href = `css/themes/${themeName}.css`;
  
  // 2. 动态切换动画形象
  const animImg = document.getElementById('companion-avatar');
  animImg.src = `assets/animations/${themeName}-idle.svg`;

  // 3. 持久化到插件本地独立存储
  localStorage.setItem('companion_theme', themeName);
}
```

#### 5. 跨插件与主视窗公频事件联动 (`bus.js`)
利用 OpenRevo 底层统一的 IPC 事件总线，插件之间可以跨视窗自由互通：

- **插件 A（桌宠挂件）在硬件剧烈过热时向公频广播自定义事件**：
  ```javascript
  import { emit } from '@tauri-apps/api/event';

  // 结温突破 85℃ 时广播“初号机暴走”联动信号
  export async function broadcastBerserk(temp) {
    await emit('plugin:eva01:berserk', {
      source: 'eva01-companion',
      temp,
      action: 'fan_boost_suggested'
    });
  }
  ```

- **插件 B（键盘流光插件 / AI 语音助手插件）监听并同步响应**：
  ```javascript
  import { listen } from '@tauri-apps/api/event';

  // 监听插件 A 的广播
  await listen('plugin:eva01:berserk', (event) => {
    const { temp } = event.payload;
    console.log(`收到初号机暴走联动: 当前结温 ${temp}℃`);
    
    // 联动 1: 键盘立即闪烁猩红警报流光
    // 联动 2: AI 看板娘切换为惊恐动画帧
  });
  ```

### 用例 7: 主窗口主题皮肤与插槽化布局重排 (Skin Plugin —— 一切皆插件)

> **目标**：不修改 OpenRevo 任何一行业务逻辑代码，仅通过纯 CSS 与声明式配置，彻底改变 OpenRevo 主窗口的视觉风格、色系基调、磨砂亚克力深度，并利用 CSS Grid 插槽重排仪表盘模块，甚至重新定义主窗口的初始物理尺寸与缩放能力。

#### 1. 核心设计原则：为什么“皮肤即插件”？
* **统一目录规范**：严禁创建孤立的 `skins/` 文件夹。所有皮肤均存放在 `%APPDATA%\OpenRevo\plugins\<skin_id>\`，在主控制台“插件管理”页享有统一的启闭开关、版本展示与元数据治理。
* **物理级 0 内存开销**：皮肤不创建独立 Webview 进程，纯粹将 `theme.css` 编译期注入宿主主窗口的 `<style id="openrevo-custom-skin">`，实现 0ms 热装卸与零内存损耗。
* **互斥安全激活**：同时只允许一个第三方皮肤处于激活状态。激活新皮肤自动卸载前一个皮肤，停用后立即无缝回退至默认主题与 960×740 视窗基准。

#### 2. 皮肤工程目录规范
```text
%APPDATA%\OpenRevo\plugins\mecha-eva01-skin\
├── manifest.json              # 核心元数据与主窗口视窗几何声明
├── theme.css                  # 皮肤全量样式表 (覆写 Tokens 与 Grid 插槽)
└── assets\                    # 本地背景贴图与字体资产
    ├── eva01_bg.webp
    └── neon_core.svg
```

#### 3. 插件清单声明 (`manifest.json`)
```json
{
  "id": "mecha-eva01-skin",
  "name": "EVA 初号机觉醒皮肤",
  "version": "1.0.0",
  "author": "NERV Engineering",
  "description": "初号机标志性紫绿觉醒电竞配色，自适应宽屏排版，支持传感器插槽重排与全息背景贴图。",
  "plugin_type": "skin",
  "theme_css": "theme.css",
  "window": {
    "width": 1080,
    "height": 780,
    "resizable": true
  }
}
```
* **`plugin_type: "skin"`**：告知内核这是一个主控制台皮肤，在插件面板中渲染为【主窗皮肤】专用徽标，并启用单选互斥控制。
* **`theme_css`**：指定相对于插件目录的 CSS 入口。
* **`window.width / height`**：声明该皮肤的最佳版面尺寸。当用户切换到此皮肤时，微内核自动触发 `resize_window` 平滑调整主窗口几何尺寸并自动屏幕居中。
* **`window.resizable: true`**：若该皮肤支持大屏响应式布局，可解锁主窗口的自由拖拽缩放能力。

#### 4. 样式编写实战与插槽重排 (`theme.css`)
当皮肤激活时，OpenRevo 宿主根容器会自动挂载 `data-skin="<skin_id>"` 属性。所有皮肤选择器必须以 `[data-skin="<skin_id>"]` 作为根命名空间，严格保证样式隔离：

```css
/* ============================================================
   1. 覆写 Design System Tokens (色彩/圆角/光效基调)
   ============================================================ */
[data-skin="mecha-eva01-skin"] {
  /* 品牌强调色：初号机装甲紫与高能荧光绿 */
  --core-accent: #a855f7;
  --core-glow: rgba(168, 85, 247, 0.4);
  --color-beast: #22c55e;
  
  /* 表面层级：深化暗夜紫亚克力 */
  --surface-overlay: rgba(16, 10, 26, 0.82);
  --surface-card: rgba(26, 16, 42, 0.72);
  --border-subtle: rgba(168, 85, 247, 0.22);
  --border-medium: rgba(168, 85, 247, 0.42);
  --border-highlight: #22c55e;
  
  /* 字体与圆角：锐利未来电竞硬朗倒角 */
  --radius-md: 4px;
  --radius-lg: 6px;
  --font-mech: 'Orbitron', 'Chakra Petch', sans-serif;
}

/* ============================================================
   2. 主容器全息贴图与背景扫描线
   ============================================================ */
[data-skin="mecha-eva01-skin"] .acrylic-container {
  background: 
    radial-gradient(circle at 90% 10%, rgba(34, 197, 94, 0.15), transparent 40%),
    radial-gradient(circle at 10% 90%, rgba(168, 85, 247, 0.18), transparent 50%),
    rgba(10, 6, 18, 0.92) !important;
  box-shadow: inset 0 0 80px rgba(0, 0, 0, 0.8), 0 0 32px rgba(168, 85, 247, 0.25);
}

/* ============================================================
   3. 顶栏胶囊导航与模式徽标机甲化
   ============================================================ */
[data-skin="mecha-eva01-skin"] .logo-badge {
  text-shadow: 0 0 10px #22c55e;
}

[data-skin="mecha-eva01-skin"] .nav-tab.active {
  background: rgba(168, 85, 247, 0.2) !important;
  border-color: #22c55e !important;
  color: #22c55e !important;
  box-shadow: 0 0 12px rgba(34, 197, 94, 0.35) !important;
}

/* ============================================================
   4. 仪表盘插槽化排版重排 (CSS Grid Slots)
   ============================================================ */
/* 
   OpenRevo 主控制台各个功能区块均带有标准的语义化类名与结构：
   - .overview-main-grid: 状态概览主网格容器
   - .power-mode-selector: 性能模式选择器
   - .sensor-gauge-cluster: 传感器仪表盘组
   - .cooling-fan-card: 双通道风扇卡片
*/
[data-skin="mecha-eva01-skin"] .overview-main-grid {
  display: grid !important;
  grid-template-columns: 1.5fr 1fr !important;
  gap: 20px !important;
}

/* 让风扇与结温传感器置顶为战术 HUD 仪表 */
[data-skin="mecha-eva01-skin"] .sensor-gauge-cluster {
  order: -1;
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.08), transparent);
  border-left: 3px solid #22c55e;
}

/* 按钮微动动画强化 */
[data-skin="mecha-eva01-skin"] .toggle-btn:hover {
  transform: translateY(-1px) scale(1.02);
  box-shadow: 0 0 14px var(--core-glow);
}
```

#### 5. 调试与即时生效
1. 编写好 `manifest.json` 与 `theme.css` 后，拷贝至 `%APPDATA%\OpenRevo\plugins\mecha-eva01-skin\`；
2. 打开 OpenRevo 主界面，点击顶部【插件】选项卡；
3. 点击右上角【刷新】按钮，列表中将检测到【EVA 初号机觉醒皮肤】，带有【主窗皮肤】专属角标；
4. 拨动开关，主窗口即刻完成：**CSS 动态热注入 + 视窗尺寸自动平滑拉伸至 1080×780 + 仪表盘网格插槽重排**！

---

## 8. UI 设计语言与 Design Tokens 复用指南

为了保证多主题（`cyber` 赛博多彩 与 `mono` 极简黑白工业风）无缝兼容，界面组件**严禁使用死板的十六进制裸色**，必须复用全局注入的 CSS 变量：

```css
/* 表面亚克力 */
background: var(--surface-card);
backdrop-filter: blur(16px);
border: 1px solid var(--border-medium);

/* 语义状态色 */
color: var(--status-ok);    /* 办公模式/正常 (绿) */
color: var(--status-info);  /* 均衡模式 (蓝) */
color: var(--color-beast);  /* 狂暴模式 (红) */

/* 圆角规范 */
border-radius: var(--radius-md); /* 8px */
border-radius: var(--radius-lg); /* 12px */
```

---

## 9. 调试与安全模式排错 (Safe Mode 二分法)

开发插件时，难免遇到死循环或语法错误。OpenRevo 建立了**实机 5 秒二分法排错机制**：

### 异常自愈指南
当第三方插件异常导致崩溃闪退时，**绝对无需重装 OpenRevo**：
1. 打开记事本：`%APPDATA%\OpenRevo\config.json`；
2. 找到 `custom_plugin_toggles` 节点；
3. 将疑似崩溃的插件 ID 改为 `false`：
   ```json
   "custom_plugin_toggles": {
     "faulty-plugin": false
   }
   ```
4. 保存并重新打开 OpenRevo，主内核将跳过该插件，秒级恢复稳定运行！
