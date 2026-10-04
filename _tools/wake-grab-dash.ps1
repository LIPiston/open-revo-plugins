param([int]$MinWidth=800)
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;
public class WG {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
  public struct R { public int L,T,Ri,B; }
  public static IntPtr Best(int minW) {
    IntPtr found = IntPtr.Zero; int best = 0;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      if (!IsWindowVisible(h)) return true;
      var sb = new StringBuilder(512); GetWindowTextW(h, sb, 512);
      if (!sb.ToString().Equals("OpenRevo", StringComparison.OrdinalIgnoreCase)) return true;
      R r; GetWindowRect(h, out r); int w = r.Ri-r.L, ht = r.B-r.T;
      if (w >= minW && w*ht > best) { best = w*ht; found = h; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
'@
$base = Join-Path (Split-Path -Parent $PSScriptRoot) '_shots'
$log=Join-Path $base 'wake-grab-dash.log'
function Say($m){ $l="$((Get-Date).ToString('HH:mm:ss')) $m"; Add-Content -Path $log -Value $l; Write-Host $l }
[void][WG]::SetProcessDpiAwarenessContext([IntPtr](-4))
Say "launching wake"
Start-Process 'D:\Program Files\OpenRevo\open-revo.exe' -ErrorAction SilentlyContinue | Out-Null
foreach ($t in 1200,1500) {
  Start-Sleep -Milliseconds $t
  $h=[WG]::Best($MinWidth)
  if ($h -eq [IntPtr]::Zero) { Say "no window >= $MinWidth px yet"; continue }
  $r=New-Object WG+R; [void][WG]::GetWindowRect($h,[ref]$r)
  $w=$r.Ri-$r.L; $ht=$r.B-$r.T
  Say ("found hwnd=$h rect=({0},{1})-({2},{3}) {4}x{5}" -f $r.L,$r.T,$r.Ri,$r.B,$w,$ht)
  $top=[WG]::SetWindowPos($h,[IntPtr](-1),$r.L,$r.T,0,0,0x0001 -bor 0x0002 -bor 0x0010)
  Start-Sleep -Milliseconds 350
  $bmp=New-Object System.Drawing.Bitmap($w,$ht)
  $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($r.L,$r.T,0,0,(New-Object System.Drawing.Size($w,$ht))); $g.Dispose()
  $p=Join-Path $base ("real-dash-{0}.png" -f $t)
  $bmp.Save($p,[System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); Say "saved=$p"
  [void][WG]::SetWindowPos($h,[IntPtr](-2),$r.L,$r.T,0,0,0x0001 -bor 0x0002 -bor 0x0010)
}
