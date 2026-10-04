# 结束当前 OpenRevo（管理员权限运行中），再带 WebView2 远程调试端口重新启动。
# 必须由 DSH 以 `Start-Process -Verb RunAs` 调用：脚本自身需要管理员权限才能
# 结束那个以 RunLevel=Highest 运行的实例。全程只弹一次 UAC。
$ErrorActionPreference = 'Continue'

$port = 9222
$exe  = 'D:\Program Files\OpenRevo\open-revo.exe'

if (-not (Test-Path $exe)) { throw "找不到 $exe" }

Write-Host "[relaunch] 结束现有 OpenRevo 进程 ..."
Get-Process -Name 'open-revo' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("          kill pid " + $_.Id)
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { Write-Host "          失败: $($_.Exception.Message)" }
}
Start-Sleep -Seconds 2
$left = @(Get-Process -Name 'open-revo' -ErrorAction SilentlyContinue)
Write-Host ("[relaunch] 残留进程数 = " + $left.Count)
# 顺带清掉可能残留的 WebView2 子进程，避免旧的调试端点占用端口
Get-Process -Name 'msedgewebview2' -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -like '*com.openrevo.controlcenter*' } |
    ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch { } }
Start-Sleep -Seconds 1

# 关键：WebView2 在创建浏览器进程时读取这个变量
$env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = "--remote-debugging-port=$port"
Set-ItemProperty -Path 'HKCU:\Environment' -Name 'WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS' `
                 -Value "--remote-debugging-port=$port"

Write-Host "[relaunch] WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS = $env:WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS"
Write-Host "[relaunch] 启动 $exe"
Start-Process -FilePath $exe

$deadline = (Get-Date).AddSeconds(60)
$found = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 800
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/json/version" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $found = $true; break }
    } catch { }
}
if ($found) {
    Write-Host "[relaunch] OK：调试端口 $port 已就绪"
    try {
        $j = Invoke-WebRequest -Uri "http://127.0.0.1:$port/json/list" -UseBasicParsing -TimeoutSec 5
        Write-Host "[relaunch] targets:"
        Write-Host $j.Content
    } catch { }
} else {
    Write-Host "[relaunch] 警告：60 秒内没等到端口 $port"
}
