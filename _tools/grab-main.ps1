# Show the OpenRevo main dashboard window (parked hidden by the host), top-most grab its rect,
# then put it back to hidden. Must run elevated (UIPI blocks ShowWindow across integrity levels).
param([string]$Out = $null)
# 默认落盘 = 本脚本所在仓库的 _shots\，不再硬编码镜像树绝对路径
# （原先那套写法会导致「改了 A 树、抓到 B 树」）。
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots\real-main.png' }
$log = Join-Path (Split-Path $Out) 'grab-main.log'
function Say([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  Write-Host $line
  Add-Content -Path $log -Value $line -Encoding UTF8
}
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class GM {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
  public static IntPtr found = IntPtr.Zero;
  public static string Info = "";
  public static IntPtr FindByClass(uint targetPid, string cls, int minW) {
    found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p = 0; GetWindowThreadProcessId(h, out p);
      if (p != targetPid) return true;
      var sb = new StringBuilder(256); GetClassNameW(h, sb, 256);
      if (!sb.ToString().Equals(cls, StringComparison.OrdinalIgnoreCase)) return true;
      R r; GetWindowRect(h, out r);
      var tb = new StringBuilder(256); GetWindowTextW(h, tb, 256);
      Info = string.Format("hwnd={0} cls={1} title='{2}' rect=({3},{4})-({5},{6}) {7}x{8} vis={9}",
        h, sb.ToString(), tb.ToString(), r.L, r.T, r.Ri, r.B, r.Ri - r.L, r.B - r.T, IsWindowVisible(h));
      if ((r.Ri - r.L) < minW) return true;
      found = h; return false;
    }, IntPtr.Zero);
    return found;
  }
}
'@
[void][GM]::SetProcessDpiAwarenessContext([IntPtr](-4))
$proc = Get-Process open-revo -ErrorAction SilentlyContinue
if (-not $proc) { Say 'no open-revo process'; exit 1 }
$pid0 = [uint32]$proc[0].Id
$h = [GM]::FindByClass($pid0, 'tray_icon_app', 600)
Say ("probe: " + [GM]::Info)
if ($h -eq [IntPtr]::Zero) { Say ("dashboard window not found for pid {0}" -f $pid0); exit 1 }
Say ("found hwnd={0} pid={1}" -f $h, $pid0)
[void][GM]::ShowWindow($h, 5)   # SW_SHOW
Start-Sleep -Milliseconds 2500
$r = New-Object GM+R; [void][GM]::GetWindowRect($h, [ref]$r)
$w = $r.Ri-$r.L; $ht = $r.B-$r.T
Say ("rect=({0},{1})-({2},{3}) {4}x{5}" -f $r.L,$r.T,$r.Ri,$r.B,$w,$ht)
$top = [GM]::SetWindowPos($h, [IntPtr](-1), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)
Say "topmost=$top"
Start-Sleep -Milliseconds 800
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$g.Dispose(); $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Say "saved=$Out"
[void][GM]::SetWindowPos($h, [IntPtr](-2), $r.L, $r.T, 0, 0, 0x0001 -bor 0x0002 -bor 0x0010)
[void][GM]::ShowWindow($h, 0)   # SW_HIDE, restore the original hidden state
Say "hidden again"
