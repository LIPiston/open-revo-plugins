# who-locks.ps1 —— 找出「哪个进程把这个目录当作当前工作目录（CWD）」。
#
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File _tools\who-locks.ps1 [目标目录]
#       不给参数时查 _tools 的上一级，也就是项目根目录。
#
# 为什么需要它：Windows 不允许 rename 一个正被任意进程当作 CWD 的目录。现象是
# msys 的 mv 报 "Device or resource busy"、cmd 的 ren 报「另一个程序正在使用此文件」，
# 而父目录里其它目录却能正常改名 —— 说明改名机制没坏，是目标目录被占着。
# Get-CimInstance Win32_Process 不暴露 CWD，所以这里直接读进程 PEB 里的 CurrentDirectory。
#
# 注意：不要改成 param() —— 经 MSYS 调 powershell -File 时反斜杠路径会被参数转换吃掉。

$BS = [char]92
$Target = Split-Path -Parent $PSScriptRoot
if ($args.Count -ge 1 -and $args[0]) { $Target = $args[0] }

$src = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class CwdProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_BASIC_INFORMATION {
        public IntPtr Reserved1;
        public IntPtr PebBaseAddress;
        public IntPtr Reserved2_0;
        public IntPtr Reserved2_1;
        public IntPtr UniqueProcessId;
        public IntPtr Reserved3;
    }

    [DllImport("ntdll.dll")]
    static extern int NtQueryInformationProcess(IntPtr h, int cls, ref PROCESS_BASIC_INFORMATION pbi, int len, out int ret);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(int access, bool inherit, int pid);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out IntPtr read);

    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr h);

    public static string Get(int pid) {
        IntPtr h = OpenProcess(0x0400 | 0x0010, false, pid);
        if (h == IntPtr.Zero) return null;
        try {
            var pbi = new PROCESS_BASIC_INFORMATION();
            int ret;
            if (NtQueryInformationProcess(h, 0, ref pbi, Marshal.SizeOf(pbi), out ret) != 0) return null;
            IntPtr read;
            byte[] b8 = new byte[8];
            if (!ReadProcessMemory(h, (IntPtr)(pbi.PebBaseAddress.ToInt64() + 0x20), b8, 8, out read)) return null;
            long pp = BitConverter.ToInt64(b8, 0);
            if (pp == 0) return null;
            byte[] us = new byte[16];
            if (!ReadProcessMemory(h, (IntPtr)(pp + 0x38), us, 16, out read)) return null;
            ushort len = BitConverter.ToUInt16(us, 0);
            long buf = BitConverter.ToInt64(us, 8);
            if (len == 0 || buf == 0) return "";
            byte[] path = new byte[len];
            if (!ReadProcessMemory(h, (IntPtr)buf, path, len, out read)) return null;
            return Encoding.Unicode.GetString(path);
        } finally {
            CloseHandle(h);
        }
    }
}
'@

Add-Type -TypeDefinition $src -Language CSharp -ErrorAction Stop

function Norm([string]$p) {
    if (-not $p) { return '' }
    return $p.Replace([string]$BS, '/').TrimEnd('/').ToLowerInvariant()
}

$t = Norm $Target
Write-Output "target = $t"
Write-Output ""
Write-Output "pid`tname`tstart`tcwd"
$script:hits = 0
$script:readable = 0
Get-Process | ForEach-Object {
    $cwd = $null
    try { $cwd = [CwdProbe]::Get($_.Id) } catch { }
    if ($null -ne $cwd) {
        $script:readable++
        $c = Norm $cwd
        if ($c -eq $t -or $c.StartsWith($t + '/')) {
            $st = ''
            try { $st = $_.StartTime.ToString('yyyy-MM-dd HH:mm:ss') } catch { }
            Write-Output ("{0}`t{1}`t{2}`t{3}" -f $_.Id, $_.ProcessName, $st, $cwd)
            $script:hits++
        }
    }
}
Write-Output ""
Write-Output ("--- cwd 可读的进程 " + $script:readable + " 个；把该目录当 CWD 的 " + $script:hits + " 个")
if ($script:hits -eq 0) {
    Write-Output "--- 没有进程把它当 CWD；若 rename 仍失败，占用者是持有目录句柄而非 CWD。"
}
