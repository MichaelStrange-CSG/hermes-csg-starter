# Point the Work (default) profile at the Claude subscription plugin and pick the best model the
# user's Claude plan answers on, trying VERSIONS.lock MODEL_PREFERENCE in order with a real test message.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '25-model'
$pluginId = Get-Lock 'PLUGIN_ID'
$models = (Get-Lock 'MODEL_PREFERENCE').Split(',')

foreach ($kv in @(@('model.provider', $pluginId), @('model.base_url', "process://$pluginId"), @('model.api_mode', 'chat_completions'))) {
    Invoke-Hermes @('config','set',$kv[0],$kv[1]) | Out-Null
    if ($LastHermesExit -ne 0) { Fail "config set $($kv[0]) failed" }
}

$chosen = ''
$testLog = Join-Path $LogDir '25-model-tests.log'
foreach ($m in $models) {
    $m = $m.Trim()
    Invoke-Hermes @('config','set','model.default',$m) | Out-Null
    if ($LastHermesExit -ne 0) { Fail 'config set model.default failed' }
    Info "Testing model $m (one short message on the user's Claude plan)"
    $out = Invoke-HermesTimed @('chat','-Q','-q','Reply with exactly the word READY and nothing else.') 240
    Add-Content -Path $testLog -Value (Protect-Text "$out`n--- $m ---") -Encoding UTF8
    if ($out -match 'READY') { $chosen = $m; break }
    Warn "Model $m did not answer on this plan (details in logs\25-model-tests.log)"
}
if (-not $chosen) { Fail "No Claude model answered. Check 'claude auth status' and the plan, and see logs\25-model-tests.log." }
Add-Content -Path (Join-Path $LogDir 'flags.txt') -Value "MODEL=$chosen" -Encoding ASCII
Ok "Work profile model: $chosen via $pluginId"

# Default thinking depth, same as the reference setup. Hermes reads agent.reasoning_effort though
# `config set` doesn't list it as known, hence --force to skip that notice.
$effort = Get-Lock 'REASONING_EFFORT'
Invoke-Hermes @('config','set','agent.reasoning_effort',$effort,'--force') | Out-Null
if ((Invoke-Hermes @('config','get','agent.reasoning_effort')).Split("`n")[0].Trim() -ne $effort) { Fail "agent.reasoning_effort did not save as $effort" }
Add-Content -Path (Join-Path $LogDir 'flags.txt') -Value "EFFORT=$effort" -Encoding ASCII
Ok "Reasoning effort: $effort"

Complete-Stage
