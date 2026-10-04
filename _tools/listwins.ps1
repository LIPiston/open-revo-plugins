# 列出所有可见顶层窗口（用于测量真机迷你面板/大面板的实际窗口尺寸）。
# 用法： powershell -NoProfile -ExecutionPolicy Bypass -File _tools/listwins.ps1 [标题正则，默认 OpenRevo]
param([string]$Pattern = 'OpenRevo')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class W {
  public delegate bool CB(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(CB c, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  public struct R { public int L, T, Ri, B; }
}
'@
$found = 0
$cb = [W+CB]{
  param($h, $l)
  if ([W]::IsWindowVisible($h)) {
    $sb = New-Object Text.StringBuilder 512
    [void][W]::GetWindowTextW($h, $sb, 512)
    $t = $sb.ToString()
    if ($t -match $Pattern) {
      $r = New-Object 'W+R'
      [void][W]::GetWindowRect($h, [ref]$r)
      $p = 0
      [void][W]::GetWindowThreadProcessId($h, [ref]$p)
      Write-Output ("hwnd={0} pid={1} rect=({2},{3})-({4},{5}) size={6}x{7} title='{8}'" -f `
        $h, $p, $r.L, $r.T, $r.Ri, $r.B, ($r.Ri - $r.L), ($r.B - $r.T), $t)
      $script:found++
    }
  }
  return $true
}
[void][W]::EnumWindows($cb, [IntPtr]::Zero)
if ($found -eq 0) { Write-Output "no visible top-level window matching '$Pattern'" }
