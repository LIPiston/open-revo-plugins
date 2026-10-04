# Capture the whole primary display in physical pixels (PerMonitorV2 aware) to a PNG.
param([string]$Out = $null)
# 默认落盘 = 本脚本所在仓库的 _shots\（原先硬编码镜像树绝对路径）。
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots\screen.png' }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;
public class DpiCtx { [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c); }
'@
[void][DpiCtx]::SetProcessDpiAwarenessContext([IntPtr](-4))
Start-Sleep -Milliseconds 300
$w = [System.Windows.Forms.SystemInformation]::VirtualScreen 2>$null
Add-Type -AssemblyName System.Windows.Forms
$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
Write-Output ("virtual screen: {0},{1} {2}x{3}" -f $vs.X, $vs.Y, $vs.Width, $vs.Height)
$bmp = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.X, $vs.Y, 0, 0, (New-Object System.Drawing.Size($vs.Width, $vs.Height)))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output ("saved: {0}" -f $Out)
