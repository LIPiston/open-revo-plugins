param([int]$Hwnd=0,[string]$Out=$null)
# 默认落盘 = 本脚本所在仓库的 _shots\，不再硬编码镜像树绝对路径
# （原先那套写法会导致「改了 A 树、抓到 B 树」）。
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots\real-dash2.png' }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class PH {
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
}
'@
$log = Join-Path (Split-Path $Out) 'pin-grab-hwnd.log'
function Say($m){ $l = "$(Get-Date -Format 'HH:mm:ss') $m"; Add-Content -Path $log -Value $l; Write-Host $l }
[void][PH]::SetProcessDpiAwarenessContext([IntPtr](-4))
$h = [IntPtr]$Hwnd
if ($h -eq [IntPtr]::Zero) { Say 'need -Hwnd'; exit 1 }
$r = New-Object PH+R; [void][PH]::GetWindowRect($h, [ref]$r)
$w = $r.Ri-$r.L; $ht = $r.B-$r.T
Say ("hwnd=$Hwnd vis=$([PH]::IsWindowVisible($h)) rect=({0},{1})-({2},{3}) {4}x{5}" -f $r.L,$r.T,$r.Ri,$r.B,$w,$ht)
$top = [PH]::SetWindowPos($h, [IntPtr](-1), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)
Say "topmost=$top"
Start-Sleep -Milliseconds 900
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Say "saved=$Out"
$back = [PH]::SetWindowPos($h, [IntPtr](-2), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)
Say "restored=$back"
