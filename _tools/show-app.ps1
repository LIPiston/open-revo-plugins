# Launch OpenRevo without --minimized (ShellExecute triggers silent elevation) and report window visibility.
Start-Process -FilePath 'D:\Program Files\OpenRevo\open-revo.exe' -ErrorAction Stop
Start-Sleep -Seconds 6
$procs = @(Get-Process -Name open-revo -ErrorAction SilentlyContinue)
Write-Output ("pids: {0}" -f (($procs | ForEach-Object { $_.Id }) -join ','))
