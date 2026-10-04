# Restart the OpenRevo app through its scheduled task and report pids before/after.
param([switch]$Stop)
$t = Get-ScheduledTask -TaskName 'OpenRevo' -ErrorAction Stop
$i = $t | Get-ScheduledTaskInfo
Write-Output ("task state={0}  lastRun={1}  lastResult={2}" -f $t.State, $i.LastRunTime, $i.LastTaskResult)
$before = (Get-Process -Name open-revo -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id) -join ','
Write-Output ("before pids: {0}" -f $before)
if ($Stop -or $true) {
  try { Stop-ScheduledTask -TaskName 'OpenRevo' -ErrorAction Stop; Write-Output 'Stop-ScheduledTask: ok' }
  catch { Write-Output ("Stop-ScheduledTask FAILED: {0}" -f $_.Exception.Message) }
  Start-Sleep -Seconds 3
  $mid = (Get-Process -Name open-revo -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id) -join ','
  Write-Output ("after stop pids: {0}" -f $mid)
  if (-not $mid) {
    Start-ScheduledTask -TaskName 'OpenRevo'
    Write-Output 'Start-ScheduledTask: ok'
    Start-Sleep -Seconds 6
    $after = Get-Process -Name open-revo -ErrorAction SilentlyContinue
    foreach ($p in $after) { Write-Output ("after start pid {0} start={1}" -f $p.Id, $p.StartTime.ToString('HH:mm:ss')) }
  }
}
