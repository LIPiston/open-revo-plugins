# 先声明 PerMonitorV2 DPI 感知，再读窗口矩形 —— 否则在 150% 缩放下拿到的是虚拟化（逻辑）坐标，
# 会和 DXGI 全屏截图（物理像素）坐标空间不一致，导致裁错区域。
$Name = 'open-revo'
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;using System.Text;
public class W3 {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct R { public int L,T,Ri,B; }
}
'@
# PerMonitorV2 = -4；失败则退回 System DPI aware
if (-not [W3]::SetProcessDpiAwarenessContext([IntPtr](-4))) { [void][W3]::SetProcessDPIAware() }
Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object {
  $h = $_.MainWindowHandle
  if ($h -eq 0) { return }
  $r = New-Object 'W3+R'; [void][W3]::GetWindowRect($h, [ref]$r)
  Write-Output ("pid={0} hwnd={1} PHYSICAL rect=({2},{3})-({4},{5}) size={6}x{7} dpi={8}" -f `
    $_.Id, $h, $r.L, $r.T, $r.Ri, $r.B, ($r.Ri-$r.L), ($r.B-$r.T), [W3]::GetDpiForWindow($h))
}
