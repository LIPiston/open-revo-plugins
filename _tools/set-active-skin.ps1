# set-active-skin.ps1 —— 让 config.json 的 active_skin 真正指向新皮肤 ID（把 §3 ④ 收成一条命令）。
#
#   powershell -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1                    # 默认 skin-win11-dark
#   powershell -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 skin-win10-light
#   powershell -ExecutionPolicy Bypass -File _tools\set-active-skin.ps1 "" dry             # 只看现状与计划，什么都不改
#
# 参数走 $args（MSYS 调 powershell -File 时显式具名参数会被吃掉，见 HANDOVER §5）。
#
# 为什么不能简单地"改了就完事"：宿主（Tauri）运行中持有权威内存态，会**周期性整份回写** config，
# 把外部改写冲掉 —— 2026-10-04 实测两次（10:13:06、11:26:44），期间无人碰过它。见 pitfalls #37。
# 所以本脚本的顺序必须是：**停宿主 → 改 → 启宿主 → 复验**，缺一步都白做。
$ErrorActionPreference = 'Stop'
# PS 5.1 默认按控制台 OEM 代码页（本机 936）写输出，管道/重定向里会变乱码 —— 强制 UTF-8。
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$Skin = if ($args.Count -ge 1 -and $args[0]) { [string]$args[0] } else { 'skin-win11-dark' }
$Dry  = ($args.Count -ge 2 -and ([string]$args[1]).ToLower() -eq 'dry')

$base    = Join-Path $env:APPDATA 'OpenRevo'
$cfg     = Join-Path $base 'config.json'
$plugins = Join-Path $base 'plugins'

function Get-HostProcs { @(Get-Process -Name open-revo -ErrorAction SilentlyContinue) }

Write-Output "=== set-active-skin ==="
Write-Output ("target      = {0}{1}" -f $Skin, $(if ($Dry) { '   [DRY RUN —— 不会改任何东西]' } else { '' }))
if (-not (Test-Path $cfg)) { Write-Output "FAIL 找不到 $cfg"; exit 2 }

# 守卫 1：目标皮肤必须真的装在那儿，否则改完又是一个悬空 ID
$skinDir = Join-Path $plugins $Skin
if (-not (Test-Path (Join-Path $skinDir 'theme.css'))) {
  Write-Output "FAIL 目标皮肤不存在或没有 theme.css：$skinDir"
  Write-Output ("     已装皮肤：" + ((Get-ChildItem $plugins -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'skin-*' } | ForEach-Object { $_.Name }) -join ', '))
  exit 4
}

$before  = (Get-Content $cfg -Raw | ConvertFrom-Json).active_skin
$info    = Get-Item $cfg
Write-Output ("active_skin = {0}   (config.json {1} B, mtime {2})" -f $before, $info.Length, $info.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fff'))

$procs = Get-HostProcs
if ($procs.Count -gt 0) {
  Write-Output ("host        = 运行中，pid {0}（StartTime {1}）" -f (($procs | ForEach-Object { $_.Id }) -join ','), $procs[0].StartTime.ToString('HH:mm:ss'))
} else {
  Write-Output 'host        = 未运行'
}
if ($before -eq $Skin -and $procs.Count -eq 0) {
  Write-Output 'OK  active_skin 已是目标值且宿主停机 —— 直接启动宿主即可（Start-ScheduledTask -TaskName OpenRevo）。'
  if ($Dry) { exit 0 }
}

if ($Dry) {
  Write-Output '--- 计划（去掉 dry 参数即执行）---'
  Write-Output ("1. 停宿主" + $(if ($procs.Count -gt 0) { "（pid " + (($procs | ForEach-Object { $_.Id }) -join ',') + "，提权 Stop-Process -Force）" } else { "（已停机，跳过）" }))
  Write-Output  "2. 备份 config.json 为 config.json.bak-setskin-<时间戳>"
  Write-Output ("3. 把 ""active_skin"" 的值原位替换为 {0}（只动这一个字段，其余字节不变）" -f $Skin)
  Write-Output "4. 用 ConvertFrom-Json 回读复验，并打印 size/mtime 变化"
  Write-Output "5. 通过计划任务 OpenRevo 启动宿主，随后趁早比对 config.json 的 mtime/大小是否被回写（pitfalls #37）"
  exit 0
}

# 1) 停宿主（自提权，与 kill-and-start.ps1 同一套手法）
if ($procs.Count -gt 0) {
  $ids = ($procs | ForEach-Object { $_.Id }) -join ','
  Write-Output "stop        = 杀 pid $ids（提权）"
  $inner = "Stop-Process -Id $ids -Force -ErrorAction SilentlyContinue"
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$inner
  Start-Sleep -Seconds 2
  $left = Get-HostProcs
  if ($left.Count -gt 0) {
    Write-Output ("FAIL 宿主没停掉，仍是 pid {0} —— 就此停手，不改配置（否则必被回写）" -f (($left | ForEach-Object { $_.Id }) -join ','))
    exit 7
  }
  Write-Output 'stop        = 已停'
}

# 2) 备份
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$bak = "$cfg.bak-setskin-$stamp"
Copy-Item $cfg $bak -Force
Write-Output "backup      = $bak"

# 3) 只替换该字段的值。**不要**用 ConvertFrom-Json | ConvertTo-Json 往返：
#    PS 5.1 会重排键序并把非 ASCII 转义成 \uXXXX，配置里其他字段会一起变样。
$raw = Get-Content $cfg -Raw
$m = [regex]::Match($raw, '"active_skin"\s*:\s*"([^"]*)"')
if (-not $m.Success) { Write-Output 'FAIL config.json 里找不到 "active_skin" 字段'; exit 5 }
$new = $raw -replace '("active_skin"\s*:\s*")[^"]*(")', ('${1}' + $Skin + '${2}')

# 原文件是否带 BOM，就按原样写回（JSON 解析两边都认，但不必替宿主改风格）
$bytes  = [System.IO.File]::ReadAllBytes($cfg)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
[System.IO.File]::WriteAllText($cfg, $new, (New-Object System.Text.UTF8Encoding($hasBom)))

# 4) 复验
$afterVal  = (Get-Content $cfg -Raw | ConvertFrom-Json).active_skin
$afterInfo = Get-Item $cfg
Write-Output ("write       = {0} -> {1}   ({2} B {3}  ->  {4} B {5}, BOM={6})" -f `
  $before, $afterVal, $info.Length, $info.LastWriteTime.ToString('HH:mm:ss.fff'), `
  $afterInfo.Length, $afterInfo.LastWriteTime.ToString('HH:mm:ss.fff'), $hasBom)
if ($afterVal -ne $Skin) { Write-Output 'FAIL 复验不一致 —— 备份在上面，先别启动宿主'; exit 6 }
Write-Output ("OK          = active_skin 现在是 {0}，皮肤目录 {1}" -f $afterVal, $skinDir)

# 5) 启宿主
Start-ScheduledTask -TaskName 'OpenRevo'
Start-Sleep -Seconds 10
$now = Get-HostProcs
if ($now.Count -eq 0) {
  Write-Output 'WARN 计划任务 OpenRevo 启动了但没看到进程 —— 手动确认（_tools\when.ps1）'
} else {
  Write-Output ("start       = pid {0}  start={1}" -f (($now | ForEach-Object { $_.Id }) -join ','), $now[0].StartTime.ToString('HH:mm:ss'))
}
$final = Get-Item $cfg
Write-Output ("verify      = config.json 现在 {0} B, mtime {1}" -f $final.Length, $final.LastWriteTime.ToString('HH:mm:ss.fff'))
if ($final.LastWriteTime -gt $afterInfo.LastWriteTime) {
  Write-Output ("WARN 宿主启动后已回写 config.json（值是否还是 {0} 需再复读一次，见 pitfalls #37）" -f $Skin)
} else {
  Write-Output 'OK          启动后未见回写。稍后再复读一次确认（宿主会周期性整份回写）。'
}
