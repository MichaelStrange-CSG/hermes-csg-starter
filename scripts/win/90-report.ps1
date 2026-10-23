# Build the install report for the kit maintainer. Contains machine facts and check results only:
# no email, no SOUL.md text, no memory, no file contents, home folder shown as ~.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\win\90-report.ps1 [notes-file]
param([string]$Notes = '')
. (Join-Path $PSScriptRoot 'lib.ps1')
$script:Stage = '90-report'
$out = Join-Path $StarterRoot 'INSTALL-REPORT.md'
function Get-Flag([string]$k) {
    $f = Join-Path $LogDir 'flags.txt'
    if (-not (Test-Path $f)) { return '' }
    $v = ''
    foreach ($l in (Get-Content $f)) { if ($l.StartsWith("$k=")) { $v = $l.Substring($k.Length + 1) } }
    return $v
}
$rows = @()
if (Test-Path $StatusFile) { $rows = @(Get-Content $StatusFile | ForEach-Object { ,($_ -split "`t") }) }
# A stage counts as failed only if its most recent outcome is FAIL (a failure fixed by a re-run is "resolved").
$last = @{}
foreach ($r in $rows) { if ($r.Count -ge 3 -and ($r[2] -eq 'DONE' -or $r[2] -eq 'FAIL')) { $last[$r[1]] = $r[2] } }
$failedStages = @($last.Keys | Where-Object { $last[$_] -eq 'FAIL' } | Sort-Object)
$fails = $failedStages.Count
$resolved = [math]::Max(0, @($rows | Where-Object { $_[2] -eq 'FAIL' }).Count - $fails)
$warns = @($rows | Where-Object { $_[2] -eq 'WARN' }).Count
$done = (@($rows | Where-Object { $_[2] -eq 'DONE' } | ForEach-Object { $_[3] }) | Sort-Object -Unique) -join ' '
if ($fails -eq 0 -and $done -match '50-verify') { $result = 'SUCCESS' } elseif ($fails -eq 0) { $result = 'INCOMPLETE' } else { $result = 'FAILED' }

$sb = New-Object System.Text.StringBuilder
function L([string]$s = '') { [void]$sb.AppendLine($s) }
L '# Hermes starter install report'; L
L '| | |'; L '|---|---|'
L "| Result | **$result** |"
L "| Platform | Windows ($(Get-Flag 'PLATFORM')) |"
L "| Kit version | $(Get-Lock 'STARTER_VERSION') |"
L "| Report created | $(Get-Date -Format 'yyyy-MM-dd HH:mm K') |"
$failedText = if ($fails -gt 0) { $failedStages -join ' ' } else { 'none' }
L "| Failed stages | $failedText |"
L "| Warnings / failures fixed by a re-run | $warns / $resolved |"
L "| Stages completed | $done |"
L "| Model chosen | $(Get-Flag 'MODEL') (reasoning effort: $(Get-Flag 'EFFORT')) |"
L "| SOUL.md sizes (chars) | work: $(Get-Flag 'SOUL_work') / home: $(Get-Flag 'SOUL_home') |"
L; L '## System'; L '```'
if (Test-Path (Join-Path $LogDir 'system.txt')) { L ((Get-Content (Join-Path $LogDir 'system.txt')) -join "`n") }
L ("Hermes: " + (Invoke-Hermes @('--version')).Split("`n")[0])
L '```'; L; L '## Profiles'; L '```'
if (Test-Path (Join-Path $LogDir '30-profile-list.txt')) { L ((Get-Content (Join-Path $LogDir '30-profile-list.txt')) -join "`n") }
L '```'; L; L '## Step log'; L '```'
foreach ($r in $rows) { L ($r[0..3] -join "`t") }
L '```'; L
if ($Notes) {
    if (-not [IO.Path]::IsPathRooted($Notes)) { $Notes = Join-Path $StarterRoot $Notes }
    if (Test-Path $Notes) { L '## Notes from the installer (Claude Code)'; L; L (Protect-Text ([IO.File]::ReadAllText($Notes))); L }
}
L '## Last lines of any failed step'
foreach ($st in $failedStages) {
    foreach ($f in (Get-ChildItem $LogDir -Filter "$st*.log" -ErrorAction SilentlyContinue)) {
        L "### $($f.Name)"; L '```'; L (Protect-Text ((Get-Content $f.FullName -Tail 40) -join "`n")); L '```'
    }
}
$text = $sb.ToString() -replace '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '<email removed>'
[IO.File]::WriteAllText($out, $text, (New-Object System.Text.UTF8Encoding($false)))
$desk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Hermes-Install-Report.md'
Copy-Item $out $desk -ErrorAction SilentlyContinue
Write-Host "Report written to INSTALL-REPORT.md and $desk (result: $result)"
