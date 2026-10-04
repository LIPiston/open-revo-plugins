# Capture one window's content with PrintWindow(PW_RENDERFULLCONTENT) into a PNG.
param([string]$Match = 'OpenRevo', [string]$Out = $null)
# 默认落盘 = 本脚本所在仓库的 _shots\。原先硬编码另一棵镜像树的绝对路径，
# 结果是「改了 A 树、抓到 B 树」。
if (-not $Out) { $Out = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots\win-mini.png' }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class Cap {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
  public static IntPtr Found = IntPtr.Zero; public static string FoundTitle = "";
  public static string Find(string match) {
    Found = IntPtr.Zero; FoundTitle = "";
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512); GetWindowTextW(h, sb, 512); string t = sb.ToString();
      if (t.Equals(match, StringComparison.OrdinalIgnoreCase)) { Found = h; FoundTitle = t; return false; }
      return true;
    }, IntPtr.Zero);
    return FoundTitle;
  }
}
'@
[void][Cap]::SetProcessDpiAwarenessContext([IntPtr](-4))
$t = [Cap]::Find($Match)
if ($t -eq '') { Write-Output "not found: $Match"; exit 1 }
Write-Output ("title='" + $t + "'")
$r = New-Object Cap+R
[void][Cap]::GetWindowRect([Cap]::Found, [ref]$r)
$w = $r.Ri - $r.L; $h = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [Cap]::PrintWindow([Cap]::Found, $hdc, 2)
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
Write-Output ("hwnd={0} rect=({1},{2})-({3},{4}) {5}x{6} printwindow={7} -> {8}" -f [Cap]::Found,$r.L,$r.T,$r.Ri,$r.B,$w,$h,$ok,$Out)
