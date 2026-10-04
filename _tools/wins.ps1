# 列出某进程（默认 open-revo）的全部顶层窗口：类名/标题/物理矩形/可见性/DWM cloak。
# 必须先声明 PerMonitorV2，否则拿到的是虚拟化坐标（150% 缩放下会差 1.5 倍）。
$Name = 'open-revo'
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;using System.Collections.Generic;
public class WEnum {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  [DllImport("user32.dll")] public static extern long GetWindowLongPtrW(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  public struct R { public int L,T,Ri,B; }
  public static List<string> Dump(uint want) {
    var list = new List<string>();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid != want) return true;
      var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
      var c = new StringBuilder(512); GetClassNameW(h, c, 512);
      R r; GetWindowRect(h, out r);
      int cloaked = 0; DwmGetWindowAttribute(h, 14, out cloaked, 4);
      long ex = GetWindowLongPtrW(h, -20);
      list.Add(string.Format("hwnd={0} vis={1} cloak={2} dpi={3} rect=({4},{5})-({6},{7}) size={8}x{9} ex=0x{10:X} class='{11}' title='{12}'",
        h, IsWindowVisible(h), cloaked, GetDpiForWindow(h), r.L, r.T, r.Ri, r.B, r.Ri-r.L, r.B-r.T, ex, c, t));
      return true;
    }, IntPtr.Zero);
    return list;
  }
}
'@
[void][WEnum]::SetProcessDpiAwarenessContext([IntPtr](-4))
Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Output "--- pid $($_.Id)"
  [WEnum]::Dump([uint32]$_.Id) | ForEach-Object { Write-Output $_ }
}
