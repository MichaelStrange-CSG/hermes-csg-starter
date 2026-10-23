# Parse-check every .ps1 in a folder, flag non-ASCII bytes (PowerShell 5.1 misreads them in BOM-less
# files), and unit-test lib.ps1's pure helpers. Usage: pwsh -NoProfile -File tools/lint-ps.ps1 scripts/win
param([string]$Dir = 'scripts/win')
$Dir = (Resolve-Path $Dir).Path
$bad = 0
foreach ($f in Get-ChildItem $Dir -Filter *.ps1) {
    $tokens = $null; $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    $nonAscii = @([IO.File]::ReadAllBytes($f.FullName) | Where-Object { $_ -gt 127 }).Count
    if ($errs.Count -gt 0) { $bad++; Write-Host "PARSE ERRORS $($f.Name):"; $errs | ForEach-Object { Write-Host "   line $($_.Extent.StartLineNumber): $($_.Message)" } }
    elseif ($nonAscii -gt 0) { $bad++; Write-Host "NON-ASCII $($f.Name): $nonAscii bytes" }
    else { Write-Host "ok  $($f.Name)" }
}
if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = Join-Path ([IO.Path]::GetTempPath()) 'fakelocal' }
if (-not $env:USERPROFILE)  { $env:USERPROFILE = [IO.Path]::GetTempPath() }
if (-not $env:USERNAME)     { $env:USERNAME = 'tester' }
. (Join-Path $Dir 'lib.ps1')
foreach ($t in @(@('2.1.300','2.1.293',$true), @('2.1.293','2.1.293',$true), @('2.1.29','2.1.293',$false),
                 @('2.2.0','2.1.293',$true), @('1.9.999','2.1.293',$false))) {
    if ((Test-VersionAtLeast $t[0] $t[1]) -ne $t[2]) { $bad++; Write-Host "VERSION FAIL $($t[0]) >= $($t[1])" }
}
$probe = Join-Path ([IO.Path]::GetTempPath()) 'crlf-probe.txt'
[IO.File]::WriteAllText($probe, "a`r`nb`r`n"); $h1 = Get-ShaLf $probe
[IO.File]::WriteAllText($probe, "a`nb`n");     $h2 = Get-ShaLf $probe
Remove-Item $probe
if ($h1 -ne $h2) { $bad++; Write-Host 'SHA-LF FAIL' }
if (-not (Get-Lock 'HERMES_COMMIT')) { $bad++; Write-Host 'LOCK FAIL' }
Remove-Item -Recurse -Force (Join-Path (Resolve-Path (Join-Path $Dir '..\..')) 'logs') -ErrorAction SilentlyContinue
Write-Host "problems: $bad"
exit $bad
