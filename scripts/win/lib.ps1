# Shared helpers for the Windows install scripts. Dot-sourced, never run directly.
# Written for Windows PowerShell 5.1 (the Windows 10 default) and PowerShell 7. ASCII only on purpose:
# PowerShell 5.1 misreads non-ASCII characters in BOM-less script files.
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$script:StarterRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:LogDir = Join-Path $StarterRoot 'logs'
$script:StatusFile = Join-Path $LogDir 'status.txt'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$script:Stage = '?'

# Hermes publishes its command in %LOCALAPPDATA%\hermes\bin; Claude Code in %USERPROFILE%\.local\bin.
# The installers add them to the user PATH, but this process started before that.
$script:HermesBinDir = Join-Path $env:LOCALAPPDATA 'hermes\bin'
$script:ClaudeBinDir = Join-Path $env:USERPROFILE '.local\bin'
foreach ($d in @($ClaudeBinDir, $HermesBinDir)) {
    if (($env:Path -split ';') -notcontains $d) { $env:Path = "$d;$env:Path" }
}

# The Claude plugin refuses to run when these are set, and they would bill an API key instead of the plan.
$script:ConflictVars = @('ANTHROPIC_API_KEY','ANTHROPIC_AUTH_TOKEN','ANTHROPIC_BASE_URL','ANTHROPIC_FOUNDRY_API_KEY','CLAUDE_CODE_USE_BEDROCK','CLAUDE_CODE_USE_VERTEX','CLAUDE_CODE_USE_FOUNDRY')
$script:ConflictsFound = @()
foreach ($v in $ConflictVars) {
    if ([Environment]::GetEnvironmentVariable($v)) { $script:ConflictsFound += $v; Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }
}
# Remember whether Claude Code launched us (the Claude app sets some of the vars above for its own session).
$script:InClaudeCode = [bool]($env:CLAUDECODE -or $env:CLAUDE_CODE_ENTRYPOINT)
# Where a variable would persist for Hermes: the User or Machine environment. '' = this session only.
function Get-PersistentSource([string]$Name) {
    if ([Environment]::GetEnvironmentVariable($Name, 'User')) { return 'your user environment variables' }
    if ([Environment]::GetEnvironmentVariable($Name, 'Machine')) { return 'the system environment variables' }
    return ''
}
# These scripts run inside Claude Code; keep its session markers away from the claude processes Hermes starts.
foreach ($v in @('CLAUDECODE','CLAUDE_CODE_ENTRYPOINT','CLAUDE_CODE_SSE_PORT','CLAUDE_CODE_EXECPATH')) { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }

function Get-Lock([string]$Key) {
    foreach ($line in (Get-Content (Join-Path $StarterRoot 'VERSIONS.lock'))) {
        $t = $line.Trim()
        if ($t.StartsWith("$Key=")) { return $t.Substring($Key.Length + 1) }
    }
    return ''
}

function Protect-Text([string]$Text) {
    if ($null -eq $Text) { return '' }
    $t = $Text.Replace($env:USERPROFILE, '~')
    if ($env:USERNAME) { $t = $t -replace [regex]::Escape($env:USERNAME), '<user>' }
    return $t
}

function Add-Status([string]$Kind, [string]$Msg) {
    $line = "{0}`t{1}`t{2}`t{3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Stage, $Kind, (Protect-Text $Msg)
    Add-Content -Path $StatusFile -Value $line -Encoding UTF8
}
function Say([string]$m)  { Write-Host $m }
function Ok([string]$m)   { Write-Host "  OK    $m";   Add-Status 'OK' $m }
function Info([string]$m) { Write-Host "  INFO  $m";   Add-Status 'INFO' $m }
function Warn([string]$m) { Write-Host "  WARN  $m";   Add-Status 'WARN' $m }
function Fail([string]$m, [int]$Code = 1) {
    Write-Host "  FAIL  $m"; Add-Status 'FAIL' $m
    Write-Host ""; Write-Host "STOPPED in ${Stage}: $m"; Write-Host "Do not work around this. Report it to the user."
    Set-Content -Path (Join-Path $LogDir "$Stage.exit") -Value $Code -Encoding ASCII
    exit $Code
}
function Start-Stage([string]$Name) {
    $script:Stage = $Name
    Remove-Item (Join-Path $LogDir "$Name.exit") -ErrorAction SilentlyContinue
    Say ""; Say "=== $Name ==="; Add-Status 'START' $Name
}
function Complete-Stage {
    Say "=== ${Stage}: done ==="; Add-Status 'DONE' $Stage
    Set-Content -Path (Join-Path $LogDir "$Stage.exit") -Value 0 -Encoding ASCII
    exit 0
}

# sha256 with CR bytes removed, so a CRLF checkout hashes the same as the LF original.
function Get-ShaLf([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $lf = New-Object System.Collections.Generic.List[byte] $bytes.Length
    foreach ($b in $bytes) { if ($b -ne 13) { $lf.Add($b) } }
    $sha = [Security.Cryptography.SHA256]::Create()
    return (($sha.ComputeHash($lf.ToArray()) | ForEach-Object { $_.ToString('x2') }) -join '')
}
function Get-FileSha([string]$Path) { return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLower() }

# Streaming-fix state of a file / the plugin folder / the Hermes checkout: pristine, patched or other.
# Hashes live in VERSIONS.lock as <KEY>_PRISTINE_SHA256 and <KEY>_PATCHED_SHA256.
$script:HermesCheckout = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent'
function Get-FileState([string]$Path, [string]$Key) {
    $h = Get-ShaLf $Path
    if ($h -and ($h -eq (Get-Lock "${Key}_PATCHED_SHA256"))) { return 'patched' }
    if ($h -and ($h -eq (Get-Lock "${Key}_PRISTINE_SHA256"))) { return 'pristine' }
    return 'other'
}
function Get-PairState([string]$A, [string]$B) { if ($A -eq $B) { return $A }; return 'other' }
function Get-PluginState([string]$Dir) {
    return (Get-PairState (Get-FileState (Join-Path $Dir 'directsdk.py') 'DIRECTSDK') (Get-FileState (Join-Path $Dir '__init__.py') 'PLUGIN_INIT'))
}
function Get-CoreState([string]$Dir) {
    return (Get-PairState (Get-FileState (Join-Path $Dir 'agent\turn_api_call.py') 'CORE_TURN') (Get-FileState (Join-Path $Dir 'providers\base.py') 'CORE_BASE'))
}

# git.exe: the one on PATH, else the PortableGit the Hermes installer staged under hermes\tools.
function Get-GitExe {
    $c = Get-Command git -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $tools = Join-Path $env:LOCALAPPDATA 'hermes\tools'
    if (Test-Path $tools) {
        foreach ($d in (Get-ChildItem -Path $tools -Directory -Filter 'git-*' -ErrorAction SilentlyContinue)) {
            $g = Join-Path $d.FullName 'cmd\git.exe'
            if (Test-Path $g) { return $g }
        }
    }
    return $null
}

# Apply a kit patch inside $Dir, all files or none (git apply is atomic). The ceiling stops git from
# adopting a repository above the folder, which would silently skip paths. A CRLF checkout may need
# --ignore-whitespace. Returns $true on success; callers verify the result by hash.
function Invoke-KitPatch([string]$Dir, [string]$PatchFile) {
    $git = Get-GitExe
    if (-not $git) { Say 'git.exe not found'; return $false }
    $oldCeil = $env:GIT_CEILING_DIRECTORIES
    $env:GIT_CEILING_DIRECTORIES = (Split-Path -Parent $Dir)
    Push-Location $Dir
    try {
        foreach ($ws in @($false, $true)) {
            $extra = @(); if ($ws) { $extra = @('--ignore-whitespace') }
            & $git apply --check @extra $PatchFile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                & $git apply @extra $PatchFile 2>&1 | Out-Null
                return ($LASTEXITCODE -eq 0)
            }
        }
        Say (Protect-Text ((& $git apply --check $PatchFile 2>&1 | Select-Object -First 5 | ForEach-Object { "$_" }) -join "`n"))
        return $false
    } finally {
        Pop-Location
        $env:GIT_CEILING_DIRECTORIES = $oldCeil
    }
}

function ConvertTo-VersionParts([string]$V) {
    return @($V.Trim() -split '\.' | ForEach-Object { $d = ($_ -replace '[^0-9].*$',''); if ($d) { [int]$d } else { 0 } })
}
function Test-VersionAtLeast([string]$A, [string]$B) {
    $pa = ConvertTo-VersionParts $A
    $pb = ConvertTo-VersionParts $B
    for ($i = 0; $i -lt 4; $i++) {
        $x = 0; $y = 0
        if ($i -lt $pa.Count) { $x = [int]$pa[$i] }
        if ($i -lt $pb.Count) { $y = [int]$pb[$i] }
        if ($x -gt $y) { return $true }
        if ($x -lt $y) { return $false }
    }
    return $true
}

function Get-HermesExe { $c = Get-Command hermes -ErrorAction SilentlyContinue; if ($c) { return $c.Source }; return $null }
function Get-ClaudeExe { $c = Get-Command claude -ErrorAction SilentlyContinue; if ($c) { return $c.Source }; return $null }

# Run hermes and return its combined output as one string. Never throws.
function Invoke-Hermes([string[]]$HArgs) {
    $out = & hermes @HArgs 2>&1 | ForEach-Object { "$_" }
    $script:LastHermesExit = $LASTEXITCODE
    return ($out -join "`n")
}

# Run hermes with a time limit (seconds) from the user's home folder; returns the output.
function Invoke-HermesTimed([string[]]$HArgs, [int]$Seconds) {
    $exe = Get-HermesExe
    $outFile = Join-Path $LogDir ('hermes-run-' + [guid]::NewGuid().ToString('N') + '.txt')
    $quoted = ($HArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"','\"') + '"' } else { $_ } }) -join ' '
    $p = Start-Process -FilePath $exe -ArgumentList $quoted -WorkingDirectory $env:USERPROFILE -NoNewWindow -PassThru `
         -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"
    if (-not $p.WaitForExit($Seconds * 1000)) {
        try { & taskkill /PID $p.Id /T /F | Out-Null } catch {}
        Add-Content -Path $outFile -Value "`n[timed out after $Seconds s]"
    }
    $text = ''
    if (Test-Path $outFile) { $text += [IO.File]::ReadAllText($outFile) }
    if (Test-Path "$outFile.err") { $text += "`n" + [IO.File]::ReadAllText("$outFile.err") }
    Remove-Item $outFile, "$outFile.err" -ErrorAction SilentlyContinue
    return $text
}

# True when the plugin is enabled in the profile ('' = Work/default). --plain prints full names.
function Test-PluginEnabled([string]$Profile, [string]$Name) {
    $a = @()
    if ($Profile) { $a += @('-p', $Profile) }
    $a += @('plugins', 'list', '--enabled', '--plain')
    foreach ($line in (Invoke-Hermes $a).Split("`n")) {
        $parts = @($line.Trim() -split '\s+')
        if ($parts.Count -gt 0 -and $parts[-1] -eq $Name) { return $true }
    }
    return $false
}

function Get-HermesHome([string]$Profile = '') {
    $a = @()
    if ($Profile) { $a += @('-p', $Profile) }
    $a += @('config', 'path')
    $p = (Invoke-Hermes $a).Trim().Split("`n")[-1].Trim()
    if ($p -and (Test-Path $p)) { return (Split-Path -Parent $p) }
    return $null
}
