# For a list of screen points, report which top-level window owns the point (WindowFromPoint / root owner).
param([int[]]$Points = @(1900,900, 2050,900, 2100,900, 2200,900, 2500,900, 2050,1400, 2400,1400, 2050,700, 2400,700))
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class Who {
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint f);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct POINT { public int X, Y; }
  public struct R { public int L,T,Ri,B; }
  public static string At(int x, int y) {
    var p = new POINT(); p.X = x; p.Y = y;
    IntPtr h = WindowFromPoint(p);
    IntPtr root = GetAncestor(h, 2);
    uint pid; GetWindowThreadProcessId(root, out pid);
    var t = new StringBuilder(512); GetWindowTextW(root, t, 512);
    var c = new StringBuilder(512); GetClassNameW(root, c, 512);
    R r; GetWindowRect(root, out r);
    string pname = "?";
    try { pname = System.Diagnostics.Process.GetProcessById((int)pid).ProcessName; } catch {}
    return string.Format("({0},{1}) -> pid={2} {3} class='{4}' title='{5}' rect=({6},{7})-({8},{9}) {10}x{11}", x, y, pid, pname, c, t, r.L, r.T, r.Ri, r.B, r.Ri-r.L, r.B-r.T);
  }
}
'@
[void][Who]::SetProcessDpiAwarenessContext([IntPtr](-4))
for ($i = 0; $i + 1 -lt $Points.Count; $i += 2) { Write-Output ([Who]::At($Points[$i], $Points[$i+1])) }
