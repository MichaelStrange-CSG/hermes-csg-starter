# Install Hermes Agent with the official Windows installer, pinned to the exact commit in VERSIONS.lock.
# Takes 5-20 minutes. Installs under %LOCALAPPDATA%\hermes; no admin rights needed.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '10-hermes'
$pin = Get-Lock 'HERMES_COMMIT'
$wantSha = Get-Lock 'HERMES_INSTALL_PS1_SHA256'
$version = Get-Lock 'HERMES_VERSION'
$checkout = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent'
$marker = Join-Path $checkout '.hermes-bootstrap-complete'

$pinned = ''
if (Test-Path $marker) { try { $pinned = (Get-Content $marker -Raw | ConvertFrom-Json).pinnedCommit } catch {} }
if (($pinned -eq $pin) -and (Get-HermesExe)) {
    Ok 'Hermes already installed at the pinned commit; skipping the installer.'
} else {
    $installer = Join-Path $LogDir 'hermes-install.ps1'
    # Retries cover GitHub's transient 429/5xx answers (seen in rehearsal).
    $dlError = ''
    for ($i = 1; $i -le 5; $i++) {
        try {
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/NousResearch/hermes-agent/$pin/scripts/install.ps1" -OutFile $installer -UseBasicParsing
            $dlError = ''; break
        } catch { $dlError = $_.Exception.Message; if ($i -lt 5) { Start-Sleep -Seconds 15 } }
    }
    if ($dlError) { Fail "Could not download the Hermes installer from GitHub: $dlError" }
    $got = Get-FileSha $installer
    if ($got -ne $wantSha) { Fail "Hermes installer checksum mismatch (got $got). Not running it." }
    Ok "Hermes installer downloaded and verified (sha256 $wantSha)"
    Info "Running the Hermes installer pinned to $version ($($pin.Substring(0,12))). This takes a while; progress is in logs\10-hermes-install.log"
    $log = Join-Path $LogDir '10-hermes-install.log'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installer -Commit $pin -NonInteractive *> $log
    $rc = $LASTEXITCODE
    Remove-Item $installer -ErrorAction SilentlyContinue
    if ($rc -ne 0) {
        Get-Content $log -Tail 25 | ForEach-Object { Say (Protect-Text $_) }
        Fail "Hermes installer exited with code $rc (log: logs\10-hermes-install.log)."
    }
}

if (-not (Get-HermesExe)) { Fail "The hermes command was not found after install (expected in $HermesBinDir)." }
$hv = (Invoke-Hermes @('--version')).Split("`n")[0]
if ($hv -notmatch [regex]::Escape($version)) { Fail "hermes --version reports '$hv', expected $version." }
# The installer records the commit it pinned in .hermes-bootstrap-complete.
$pinned = ''
if (Test-Path $marker) { try { $pinned = (Get-Content $marker -Raw | ConvertFrom-Json).pinnedCommit } catch {} }
if ($pinned -ne $pin) { Fail "Hermes install marker shows commit '$pinned', expected $pin." }
Ok $hv

# Pinned install: no update prompts or banners.
Invoke-Hermes @('config','set','updates.check','false') | Out-Null
if ($LastHermesExit -ne 0) { Fail 'Could not set updates.check' }
Ok 'Update checks turned off (pinned install)'

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -like "*$HermesBinDir*") { Ok 'hermes is on your user PATH (new PowerShell windows will find it)' }
else { Warn "hermes is not on the user PATH. New terminals may not find it; the installer normally adds $HermesBinDir." }

Complete-Stage
