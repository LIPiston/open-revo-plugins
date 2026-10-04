# List every visible top-level window: hwnd, pid, process, class, title, physical rect.
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class AW {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
  public static System.Collections.Generic.List<string> Rows = new System.Collections.Generic.List<string>();
  public static void Go() {
    Rows.Clear();
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      R r; GetWindowRect(h, out r);
      int w = r.Ri-r.L, ht = r.B-r.T;
      if (w <= 0 || ht <= 0) return true;
      var t = new StringBuilder(512); GetWindowTextW(h, t, 512);
      var c = new StringBuilder(512); GetClassNameW(h, c, 512);
      uint pid; GetWindowThreadProcessId(h, out pid);
      string pn = "?"; try { pn = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch {}
      Rows.Add(string.Format("hwnd={0} pid={1} {2} class='{3}' title='{4}' rect=({5},{6})-({7},{8}) {9}x{10}",
        h, pid, pn, c, t, r.L, r.T, r.Ri, r.B, w, ht));
      return true;
    }, IntPtr.Zero);
  }
}
'@
[void][AW]::SetProcessDpiAwarenessContext([IntPtr](-4))
[AW]::Go()
[AW]::Rows | ForEach-Object { Write-Output $_ }
