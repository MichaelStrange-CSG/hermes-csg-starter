# End-to-end checks on both profiles. Read-only except for two short test chats.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '50-verify'
$pluginId = Get-Lock 'PLUGIN_ID'; $patched = Get-Lock 'DIRECTSDK_PATCHED_SHA256'
$pin = Get-Lock 'HERMES_COMMIT'; $version = Get-Lock 'HERMES_VERSION'
$script:Fails = 0
function Check([string]$Name, [bool]$Pass) {
    if ($Pass) { Ok $Name } else { Warn "CHECK FAILED: $Name"; $script:Fails++ }
}

$hv = Invoke-Hermes @('--version')
Check "hermes --version is $version" ($hv -match [regex]::Escape($version))
$marker = Join-Path $env:LOCALAPPDATA 'hermes\hermes-agent\.hermes-bootstrap-complete'
$pinned = ''
if (Test-Path $marker) { try { $pinned = (Get-Content $marker -Raw | ConvertFrom-Json).pinnedCommit } catch {} }
Check 'Hermes is at the pinned commit' ($pinned -eq $pin)
Check 'Hermes source has the streaming patch' ((Get-CoreState $HermesCheckout) -eq 'patched')
Check 'Update checks are off' ((Invoke-Hermes @('config','get','updates.check')).Trim() -eq 'false')
Check 'Profile list shows Work' ((Invoke-Hermes @('profile','list')) -match 'Work')

foreach ($p in @('', 'home')) {
    $name = if ($p) { $p } else { 'Work' }
    $pa = @(); if ($p) { $pa = @('-p', $p) }
    $h = Get-HermesHome $p
    Check "${name}: plugin files are the patched pinned version" ((Get-PluginState (Join-Path $h "plugins\$pluginId")) -eq 'patched')
    Check "${name}: plugin enabled" (Test-PluginEnabled $p $pluginId)
    Check "${name}: provider is the Claude subscription" ((Invoke-Hermes ($pa + @('config','get','model.provider'))).Trim() -eq $pluginId)
    Info "${name}: model $((Invoke-Hermes ($pa + @('config','get','model.default'))).Trim())"
    $effort = Get-Lock 'REASONING_EFFORT'
    Check "${name}: reasoning effort is $effort" ((Invoke-Hermes ($pa + @('config','get','agent.reasoning_effort'))).Split("`n")[0].Trim() -eq $effort)

    # Claude decides per message whether to think at all, so classify from the saved session:
    #   visible = thinking block with text (patch working); hidden = thinking block, empty text (patch NOT
    #   working); none = Claude didn't think this time (inconclusive, ask again, up to 3 tries).
    $answered = $false; $think = 'none'; $rlen = 0
    $alog = Join-Path $h 'logs\agent.log'
    $alogStart = 0; if (Test-Path $alog) { $alogStart = @(Get-Content $alog).Count }
    for ($try = 1; $try -le 3; $try++) {
        $out = Invoke-HermesTimed ($pa + @('chat','--format','stream-json','--reasoning','high','-q','What is 37*43 - 19*28 + 1234/2? Work it out carefully, then reply with only the final number.')) 300
        Set-Content -Path (Join-Path $LogDir "50-verify-$name.jsonl") -Value (Protect-Text $out) -Encoding UTF8
        if ($out -match '1676') { $answered = $true }
        $m = [regex]::Match($out, '"session_id": *"([^"]+)"')
        if (-not $m.Success) { continue }
        $exp = Join-Path $LogDir '.verify-export.jsonl'
        Invoke-HermesTimed ($pa + @('sessions','export',$exp,'--session-id',$m.Groups[1].Value,'--yes')) 120 | Out-Null
        if (Test-Path $exp) {
            foreach ($line in (Get-Content $exp -Encoding UTF8)) {
                if (-not $line.Trim()) { continue }
                foreach ($msg in (($line | ConvertFrom-Json).messages)) {
                    if ($msg.role -ne 'assistant') { continue }
                    if ($msg.reasoning -and $msg.reasoning.Length -gt $rlen) { $rlen = $msg.reasoning.Length }
                    $details = $msg.reasoning_details
                    if ($details -is [string]) { try { $details = $details | ConvertFrom-Json } catch { $details = @() } }
                    foreach ($envl in @($details)) {
                        foreach ($nm in @($envl.messages)) {
                            foreach ($c in @($nm.content)) {
                                if ($c.type -eq 'thinking') {
                                    if ($c.thinking) { $think = 'visible' } elseif ($think -eq 'none') { $think = 'hidden' }
                                }
                            }
                        }
                    }
                }
            }
            Remove-Item $exp -ErrorAction SilentlyContinue
        }
        if ($rlen -gt 0) { $think = 'visible' }
        if ($think -ne 'none') { break }
        Info "${name}: Claude answered without thinking (try $try of 3); asking again"
    }
    Check "${name}: Claude answered a test message correctly" $answered
    # Streaming fix: the test chats must have used the streaming client, never the old non-streaming one.
    $created = @()
    if (Test-Path $alog) { $created = @(Get-Content $alog | Select-Object -Skip $alogStart | Where-Object { $_ -like "*$pluginId client created*" }) }
    $streamed = @($created | Where-Object { $_ -like '*(chat_completion_stream_request*' }).Count
    $unstreamed = @($created | Where-Object { $_ -like '*(chat_completion_request*' }).Count
    Check "${name}: replies stream (streaming fix working)" (($streamed -gt 0) -and ($unstreamed -eq 0))
    Info "${name}: thinking: $think ($rlen characters)"
    if ($think -eq 'none') {
        Warn "${name}: Claude never used thinking in 3 test messages, so the thinking-display patch could not be confirmed here (the patch file itself checked out). Look for text in the thinking panel in the app."
    } else {
        Check "${name}: thinking text is visible (patch working)" ($think -eq 'visible')
    }
}

Add-Content -Path (Join-Path $LogDir 'flags.txt') -Value "VERIFY_FAILS=$Fails" -Encoding ASCII
if ($Fails -gt 0) { Fail "$Fails verification check(s) failed. See the WARN lines above and logs\50-verify-*.jsonl." }
Complete-Stage
