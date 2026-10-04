# Kill the running OpenRevo instance via a silently elevated helper, then relaunch it through its scheduled task.
$procs = @(Get-Process -Name open-revo -ErrorAction SilentlyContinue)
if ($procs.Count -gt 0) {
  $ids = ($procs | ForEach-Object { $_.Id }) -join ' '
  Write-Output ("killing: {0}" -f $ids)
  $inner = "Stop-Process -Id $($ids -replace ' ',',') -Force -ErrorAction SilentlyContinue"
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command', $inner
  Start-Sleep -Seconds 2
}
$left = @(Get-Process -Name open-revo -ErrorAction SilentlyContinue)
Write-Output ("alive after kill: {0}" -f (($left | ForEach-Object { $_.Id }) -join ','))
if ($left.Count -eq 0) {
  Start-ScheduledTask -TaskName 'OpenRevo'
  Start-Sleep -Seconds 8
  Get-Process -Name open-revo -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Output ("relaunched pid {0} start={1}" -f $_.Id, $_.StartTime.ToString('HH:mm:ss'))
  }
}
