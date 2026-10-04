param([int]$Hwnd=852778,[int]$Dx=500,[int]$Dy=400,[string]$OutDir=$null)
# 默认落盘 = 本脚本所在仓库的 _shots\（原先硬编码镜像树绝对路径）。
if (-not $OutDir) { $OutDir = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots' }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
public class MV {
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int cx,int cy,uint f);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
 [DllImport("shcore.dll")] public static extern int SetProcessDpiAwarenessContext(int v);
 public struct RECT { public int L,T,R,B; }
}
'@
[void][MV]::SetProcessDpiAwarenessContext(-4)
$log = Join-Path $OutDir 'move-grab.log'
function Say($m){ $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Add-Content -Path $log -Value $l; Write-Host $l }
function Grab([string]$name,[int]$L,[int]$T,[int]$R,[int]$B){
  $bmp = New-Object System.Drawing.Bitmap ($R-$L), ($B-$T)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($L,$T,0,0,$bmp.Size); $g.Dispose()
  $bmp.Save((Join-Path $OutDir $name),[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); Say "saved $name"
}
$h=[IntPtr]$Hwnd
$r=New-Object MV+RECT; [void][MV]::GetWindowRect($h,[ref]$r)
$w=$r.R-$r.L; $h2=$r.B-$r.T; $x=$r.L; $y=$r.T
Say "orig rect=($x,$y) size=${w}x${h2}"
Grab 'mv-A-atP.png' $x $y ($x+$w) ($y+$h2)
$ok=[MV]::SetWindowPos($h,[IntPtr]::Zero,($x+$Dx),($y+$Dy),0,0,0x0011)
Say "SetWindowPos ok=$ok -> ($($x+$Dx),$($y+$Dy))"
Start-Sleep -Milliseconds 1500
Grab 'mv-B-atP2.png' ($x+$Dx) ($y+$Dy) ($x+$Dx+$w) ($y+$Dy+$h2)
Grab 'mv-M2-backdropAtP.png' $x $y ($x+$w) ($y+$h2)
$ok2=[MV]::SetWindowPos($h,[IntPtr]::Zero,$x,$y,0,0,0x0011)
Start-Sleep -Milliseconds 1500
$r3=New-Object MV+RECT; [void][MV]::GetWindowRect($h,[ref]$r3)
Say "restored ok=$ok2 rect=($($r3.L),$($r3.T))-($($r3.R),$($r3.B))"
Grab 'mv-C-restored.png' $x $y ($x+$w) ($y+$h2)
