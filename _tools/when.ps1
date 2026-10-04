# Probe OpenRevo process start time vs. plugin/config file mtimes.
Get-Process -Name open-revo -ErrorAction SilentlyContinue | ForEach-Object {
  $age = [math]::Round(((Get-Date) - $_.StartTime).TotalMinutes, 1)
  Write-Output ("pid {0}  start={1}  elapsed_min={2}" -f $_.Id, $_.StartTime.ToString('HH:mm:ss'), $age)
}
Write-Output '--- file mtimes'
$base = Join-Path $env:APPDATA 'OpenRevo'
$files = @('config.json','boot.log','plugins\skin-win10-dark\theme.css','plugins\skin-win10-dark\manifest.json','plugins\skin-win11-light\theme.css')
foreach ($f in $files) {
  $p = Join-Path $base $f
  if (Test-Path $p) { $i = Get-Item $p; Write-Output ("{0,-58} {1}" -f $f, $i.LastWriteTime.ToString('HH:mm:ss')) }
}
Write-Output ("now = {0}" -f (Get-Date).ToString('HH:mm:ss'))
