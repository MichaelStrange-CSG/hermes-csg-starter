# Make sure the Claude Code command-line tool (claude) is installed, new enough, and signed in.
# The Claude desktop app has Claude Code built in, but Hermes needs the separate `claude` command.
# Exit 0 = ready. Exit 2 = installed but the user must sign in (see START-HERE.md). Exit 1 = failure.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '05-claude-cli'
$min = Get-Lock 'CLAUDE_CODE_MIN'

$claude = Get-ClaudeExe
if (-not $claude) {
    Info "Installing Claude Code with Anthropic's official installer (https://claude.ai/install.ps1)"
    $log = Join-Path $LogDir '05-claude-install.log'
    & powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://claude.ai/install.ps1 | iex' *> $log
    $claude = Get-ClaudeExe
    if (-not $claude) { Fail "Claude Code installer ran but 'claude' was not found in $ClaudeBinDir. See logs\05-claude-install.log." }
}

$cv = ((& $claude --version 2>$null) -join ' ').Split(' ')[0]
if (-not (Test-VersionAtLeast $cv $min)) {
    Info "Claude Code $cv is older than $min; running 'claude update'"
    & $claude update *> (Join-Path $LogDir '05-claude-update.log')
    $cv = ((& $claude --version 2>$null) -join ' ').Split(' ')[0]
    if (-not (Test-VersionAtLeast $cv $min)) { Fail "Claude Code is $cv, need $min or newer, and 'claude update' did not fix it (log: logs\05-claude-update.log)." }
}
Ok "Claude Code $cv at $claude (need $min+)"
# Preflight recorded the state before this stage; replace that line with what's installed now.
$sysFile = Join-Path $LogDir 'system.txt'
function Set-SysLine([string]$Key, [string]$Value) {
    $lines = @()
    if (Test-Path $sysFile) { $lines = @(Get-Content $sysFile | Where-Object { -not $_.StartsWith("${Key}:") }) }
    $lines += (Protect-Text "${Key}: $Value")
    Set-Content -Path $sysFile -Value $lines -Encoding UTF8
}
Set-SysLine 'Claude Code' "$cv ($claude)"

# Sign-in check. Only loggedIn, method and plan type are recorded; never the email or org.
$auth = $null
try { $auth = ((& $claude auth status --json 2>$null) -join "`n") | ConvertFrom-Json } catch {}
if ($auth -and $auth.loggedIn) {
    if ($auth.authMethod -ne 'claude.ai') {
        Warn "Claude Code is signed in with '$($auth.authMethod)', not a Claude subscription. Hermes' Claude plugin needs a Claude.ai (Pro/Max/Team) sign-in. Run: claude auth login --claudeai"
    }
    Set-SysLine 'Claude plan' "$($auth.subscriptionType)"
    Ok "Claude Code is signed in (plan: $($auth.subscriptionType))"
    Complete-Stage
}

Add-Status 'NEEDS_LOGIN' 'Claude Code is not signed in'
Say '  ACTION  Claude Code is installed but not signed in.'
Say "          Run 'claude auth login' (it opens the browser), the user approves with their OWN Claude account,"
Say '          then run this script again.'
Set-Content -Path (Join-Path $LogDir "$Stage.exit") -Value 2 -Encoding ASCII
exit 2
