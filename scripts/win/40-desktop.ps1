# Build the Hermes desktop app on this PC from the pinned source and create Start menu + Desktop shortcuts.
# Building locally (not the Store/MSIX app) keeps it pinned and works on Windows 10.
# Takes 5-15 minutes. Run it in the background and wait for logs\40-desktop.exit.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '40-desktop'

$log = Join-Path $LogDir '40-desktop-build.log'
Info 'Building the desktop app (log: logs\40-desktop-build.log)'
Push-Location $env:USERPROFILE
& hermes desktop --build-only *> $log
$rc = $LASTEXITCODE
Pop-Location
if ($rc -ne 0) {
    Get-Content $log -Tail 30 | ForEach-Object { Say (Protect-Text $_) }
    Fail "Desktop build failed with code $rc. Hermes still works in PowerShell ('hermes'); report this to the person who shared this kit."
}

$rel = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent\apps\desktop\release'
$exe = $null
foreach ($d in @('win-unpacked','win-arm64-unpacked','win-ia32-unpacked')) {
    $c = Join-Path $rel "$d\Hermes.exe"
    if (Test-Path $c) { $exe = $c; break }
}
if (-not $exe) { Fail "Build finished but no Hermes.exe was found under $rel." }
Ok "Built $exe"

# Same shortcut targets the official installer creates.
$shell = New-Object -ComObject WScript.Shell
$workDir = Split-Path -Parent $exe
$icon = Join-Path $workDir 'resources\icon.ico'
if (-not (Test-Path $icon)) { $icon = $exe }
foreach ($lnk in @((Join-Path ([Environment]::GetFolderPath('Programs')) 'Hermes.lnk'),
                   (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Hermes.lnk'))) {
    try {
        $sc = $shell.CreateShortcut($lnk)
        $sc.TargetPath = $exe; $sc.WorkingDirectory = $workDir; $sc.IconLocation = "$icon,0"; $sc.Description = 'Hermes Agent'
        $sc.Save()
        Ok "Shortcut: $lnk"
    } catch { Warn "Could not create shortcut $lnk : $($_.Exception.Message)" }
}

Complete-Stage
