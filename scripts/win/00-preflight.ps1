# Read-only checks. Changes nothing on the PC.
# Exit 0 = ready. Exit 1 = a blocking problem (see the FAIL line).
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '00-preflight'
$sysFile = Join-Path $LogDir 'system.txt'
Set-Content -Path $sysFile -Value '' -Encoding UTF8
function Sys([string]$k, [string]$v) { Add-Content -Path $sysFile -Value (Protect-Text "${k}: $v") -Encoding UTF8 }

# --- Windows and hardware -----------------------------------------------------------------------
$os = Get-CimInstance Win32_OperatingSystem
$build = [int]$os.BuildNumber
$cs = Get-CimInstance Win32_ComputerSystem
$ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB)
$drive = Get-PSDrive -Name ($env:LOCALAPPDATA.Substring(0,1))
$freeGb = [math]::Floor($drive.Free / 1GB)
$arch = $env:PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
$longPaths = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
Sys 'OS' "$($os.Caption) (build $build, version $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).DisplayVersion))"
Sys 'Architecture' $arch
Sys 'Model' "$($cs.Manufacturer) $($cs.Model)"
Sys 'RAM' "$ramGb GB"
Sys 'Free disk' "$freeGb GB"
Sys 'PowerShell' "$($PSVersionTable.PSVersion)"
Sys 'Long paths enabled' "$longPaths"

$minBuild = [int](Get-Lock 'WINDOWS_MIN_BUILD')
if ($build -lt $minBuild) { Fail "Windows build $build is too old. Need Windows 10 version 1809 (build $minBuild) or newer." }
if ($build -lt 22000) {
    Warn "Windows 10 (build $build). Supported by Hermes' script install; this kit has not been tested on Windows 10 yet. Send the install report to the person who shared this kit when done."
} else {
    Ok "Windows 11 (build $build)"
}
if ($arch -eq 'ARM64') { Warn 'Windows on ARM. Supported by Hermes, but untested with this kit. Send the install report to the person who shared this kit when done.' }
elseif ($arch -ne 'AMD64') { Fail "Unsupported processor architecture '$arch'. Hermes needs 64-bit Windows." }
else { Ok "64-bit Windows ($arch)" }

if ($ramGb -ge 8) { Ok "RAM $ramGb GB" } else { Warn "RAM $ramGb GB. Hermes runs, but the desktop build and browser tools are slow under 8 GB." }
$minFree = [int](Get-Lock 'MIN_FREE_GB')
if ($freeGb -lt $minFree) { Fail "Only $freeGb GB free on drive $($drive.Name):. Need $minFree GB. Free up space and run this again." }
Ok "Free disk $freeGb GB"

# --- Claude Code CLI (reported here; 05-claude-cli fixes it) -------------------------------------
$claude = Get-ClaudeExe
if ($claude) {
    $cv = ((& $claude --version 2>$null) -join ' ').Split(' ')[0]
    Sys 'Claude Code' "$cv ($claude)"
    Ok "Claude Code CLI found: $cv"
} else {
    Sys 'Claude Code' 'not on PATH'
    Info 'Claude Code CLI (claude) not found on PATH. Stage 05 installs it.'
}
foreach ($v in $ConflictsFound) {
    $src = Get-PersistentSource $v
    if ($src) {
        Warn "Environment variable $v is set in $src. Hermes would inherit it: the Claude subscription plugin refuses to run with it, and it would bill an API key instead of the Claude plan. Remove it in Settings > System > About > Advanced system settings > Environment Variables."
    } elseif ($InClaudeCode) {
        Info "$v is set only in the Claude app session running this install. The scripts clear it; Hermes won't see it."
    } else {
        Warn "Environment variable $v is set in this session (not in the user or system environment). Hermes started from this window would inherit it; find where it is set and remove it."
    }
}
if ($env:HERMES_HOME) { Fail "HERMES_HOME is set ($env:HERMES_HOME). This kit installs to the standard location only. Ask the person who shared this kit with you." }

# --- Existing Hermes ----------------------------------------------------------------------------
$pin = Get-Lock 'HERMES_COMMIT'
$checkout = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent'
$marker = Join-Path $checkout '.hermes-bootstrap-complete'
if (Test-Path $checkout) {
    $pinned = ''
    if (Test-Path $marker) { try { $pinned = (Get-Content $marker -Raw | ConvertFrom-Json).pinnedCommit } catch {} }
    if ($pinned -eq $pin) { Ok 'Hermes is already installed at the pinned commit (re-run is safe).' }
    else { Fail "A different Hermes install already exists ($checkout). This kit does not overwrite it. Ask the person who shared this kit with you." }
} elseif (Test-Path (Join-Path $env:LOCALAPPDATA 'hermes')) {
    Fail "$env:LOCALAPPDATA\hermes exists but has no Hermes install in it. This kit will not overwrite it. Ask the person who shared this kit with you."
} else {
    Ok 'No existing Hermes install.'
}
$appx = Get-AppxPackage -Name '*Hermes*' -ErrorAction SilentlyContinue
if ($appx) { Warn "The Store/MSIX Hermes app is installed ($($appx.Name)). It is separate from this install; it may confuse which Hermes opens. Consider removing it." }

# --- Network ------------------------------------------------------------------------------------
$netFail = $false
$urls = @('https://github.com','https://raw.githubusercontent.com','https://codeload.github.com',
          'https://objects.githubusercontent.com','https://hermes-assets.nousresearch.com',
          'https://nodejs.org','https://registry.npmjs.org','https://pypi.org','https://files.pythonhosted.org',
          'https://claude.ai','https://api.anthropic.com')
foreach ($u in $urls) {
    $code = 0; $body = ''
    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -MaximumRedirection 5
        $code = [int]$r.StatusCode; $body = "$($r.Content)"
    } catch {
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    }
    if ($body -match 'umbrella|this site is blocked') { Warn "$u is BLOCKED by a web filter (Cisco Umbrella page). Ask IT to allow it."; $netFail = $true }
    elseif ($code -eq 0) { Warn "$u unreachable (no response)."; $netFail = $true }
    else { Say "  OK    $u ($code)" }
}
if (-not $netFail) { Ok 'All download sites reachable' } else { Warn 'Some download sites failed. The install will probably fail at that step.' }

Set-Content -Path (Join-Path $LogDir 'flags.txt') -Value "INTEL_MAC=0`nPLATFORM=windows-$build-$arch" -Encoding ASCII
Complete-Stage
