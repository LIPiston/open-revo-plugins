# 用力：进程 MainWindowHandle + DWM cloak 状态 + 窗口矩形/样式
param([string]$Name = 'open-revo')
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;using System.Text;
public class W2 {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  public struct R { public int L,T,Ri,B; }
}
'@
Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object {
  $p = $_
  $h = $p.MainWindowHandle
  if ($h -eq 0) { Write-Output ("pid={0} MainWindowHandle=0 (无主窗)" -f $p.Id); return }
  $r = New-Object 'W2+R'; [void][W2]::GetWindowRect($h, [ref]$r)
  $sb = New-Object Text.StringBuilder 512; [void][W2]::GetWindowTextW($h, $sb, 512)
  $style = [W2]::GetWindowLong($h, -16); $ex = [W2]::GetWindowLong($h, -20)
  $clk = 0; $hr = [W2]::DwmGetWindowAttribute($h, 14, [ref]$clk, 4)
  Write-Output ("pid={0} hwnd={1} title='{2}' rect=({3},{4})-({5},{6}) size={7}x{8}" -f `
    $p.Id, $h, $sb.ToString(), $r.L, $r.T, $r.Ri, $r.B, ($r.Ri-$r.L), ($r.B-$r.T))
  Write-Output ("  visible={0} iconic={1} style=0x{2:X} ex=0x{3:X} dwmHr=0x{4:X} cloaked={5}" -f `
    [W2]::IsWindowVisible($h), [W2]::IsIconic($h), $style, $ex, $hr, $clk)
}
