# Temporarily raise the OpenRevo panel window to HWND_TOPMOST, grab its rect, then restore.
param([string]$Out = $null)
# 默认落盘 = 本脚本所在仓库的 _shots\，不再硬编码镜像树绝对路径
# （原先那套写法会导致「改了 A 树、抓到 B 树」）。
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots\real-mini-clean.png' }
# 修补：原脚本后面调用了 Say 却从未定义它（运行时 CommandNotFoundException），这里补上。
$log = Join-Path (Split-Path $Out) 'pin-grab.log'
function Say($m){ $l = "$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $l; Write-Host $l }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class PG {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
  public static IntPtr Find(string title) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512); GetWindowTextW(h, sb, 512);
      if (sb.ToString().Equals(title, StringComparison.OrdinalIgnoreCase)) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
'@
[void][PG]::SetProcessDpiAwarenessContext([IntPtr](-4))
$h = [PG]::Find('OpenRevo')
if ($h -eq [IntPtr]::Zero) { Say 'panel not visible'; exit 1 }
$r = New-Object PG+R; [void][PG]::GetWindowRect($h, [ref]$r)
$w = $r.Ri-$r.L; $ht = $r.B-$r.T
Say ("before rect=({0},{1})-({2},{3}) {4}x{5}" -f $r.L,$r.T,$r.Ri,$r.B,$w,$ht)
$top = [PG]::SetWindowPos($h, [IntPtr](-1), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)  # NOSIZE|NOMOVE|NOACTIVATE
Say "topmost=$top"
Start-Sleep -Milliseconds 600
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Say "saved=$Out"
$back = [PG]::SetWindowPos($h, [IntPtr](-2), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)  # NOTOPMOST
Say "restored=$back"
