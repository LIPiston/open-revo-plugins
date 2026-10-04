param([int]$Hwnd=852778,[string]$OutDir=$null)
# 默认落盘 = 本脚本所在仓库的 _shots\（原先硬编码镜像树绝对路径）。
if (-not $OutDir) { $OutDir = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots' }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
public class MG {
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("shcore.dll")] public static extern int SetProcessDpiAwarenessContext(int v);
 public struct RECT { public int L,T,R,B; }
}
'@
[void][MG]::SetProcessDpiAwarenessContext(-4)
$log = Join-Path $OutDir 'min-grab.log'
function Say($m){ $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Add-Content -Path $log -Value $l; Write-Host $l }
function Grab([string]$name,[int]$L,[int]$T,[int]$R,[int]$B){
  $bmp = New-Object System.Drawing.Bitmap ($R-$L), ($B-$T)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($L,$T,0,0,$bmp.Size)
  $g.Dispose(); $p = Join-Path $OutDir $name; $bmp.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  Say "saved $name"
}
$h = [IntPtr]$Hwnd
$r = New-Object MG+RECT; [void][MG]::GetWindowRect($h,[ref]$r)
Say "rect=($($r.L),$($r.T))-$($r.R),$($r.B) vis=$([MG]::IsWindowVisible($h))"
Grab 'mg-visible.png' $r.L $r.T $r.R $r.B
[void][MG]::ShowWindow($h,6)   # SW_MINIMIZE
Start-Sleep -Milliseconds 1200
Grab 'mg-minimized.png' $r.L $r.T $r.R $r.B
[void][MG]::ShowWindow($h,9)   # SW_RESTORE
Start-Sleep -Milliseconds 1500
Grab 'mg-restored.png' $r.L $r.T $r.R $r.B
$r2 = New-Object MG+RECT; [void][MG]::GetWindowRect($h,[ref]$r2)
Say "after-restore rect=($($r2.L),$($r2.T))-$($r2.R),$($r2.B) vis=$([MG]::IsWindowVisible($h))"
