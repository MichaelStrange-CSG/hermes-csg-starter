# Two profiles: the built-in default profile shown as "Work", and a "home" profile cloned from it
# (same plugin, patch and model; its own empty memory). Hermes always keeps the default profile, so
# renaming it is how we end up with exactly two.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '30-profiles'
$pluginId = Get-Lock 'PLUGIN_ID'; $patched = Get-Lock 'DIRECTSDK_PATCHED_SHA256'

Invoke-Hermes @('profile','rename','default','Work') | Out-Null
if ($LastHermesExit -ne 0) { Fail "Could not set the default profile's display name to Work." }
Ok "Default profile now shows as 'Work' (its internal id stays 'default')"

Invoke-Hermes @('profile','show','home') | Out-Null
if ($LastHermesExit -eq 0) {
    Ok "Profile 'home' already exists"
} else {
    $out = Invoke-Hermes @('profile','create','home','--clone-from','default','--no-alias','--description','Personal use. Kept separate from work.')
    Set-Content -Path (Join-Path $LogDir '30-profile-create.log') -Value (Protect-Text $out) -Encoding UTF8
    if ($LastHermesExit -ne 0) { Say (Protect-Text $out); Fail 'Could not create the home profile.' }
    Ok "Created profile 'home' (cloned settings and plugin from Work)"
}

$hh = Get-HermesHome 'home'
if (-not $hh) { Fail 'Could not find the home profile folder.' }
if ((Get-PluginState (Join-Path $hh "plugins\$pluginId")) -ne 'patched') { Fail 'The home profile does not have the patched plugin.' }
Invoke-Hermes @('-p','home','plugins','enable',$pluginId) | Out-Null
if (-not (Test-PluginEnabled 'home' $pluginId)) { Fail 'Plugin not enabled in the home profile.' }
foreach ($k in @('model.provider','model.default')) {
    $w = (Invoke-Hermes @('config','get',$k)).Trim()
    $h = (Invoke-Hermes @('-p','home','config','get',$k)).Trim()
    if ($w -ne $h) { Fail "home profile $k differs from Work." }
}
Invoke-Hermes @('-p','home','config','set','updates.check','false') | Out-Null
$effort = Get-Lock 'REASONING_EFFORT'
Invoke-Hermes @('-p','home','config','set','agent.reasoning_effort',$effort,'--force') | Out-Null
if ((Invoke-Hermes @('-p','home','config','get','agent.reasoning_effort')).Split("`n")[0].Trim() -ne $effort) { Fail "home profile reasoning effort is not $effort." }
Ok "home profile: patched plugin enabled, same model as Work, reasoning effort $effort"

foreach ($f in @('memories\MEMORY.md','memories\USER.md')) {
    $p = Join-Path $hh $f
    if ((Test-Path $p) -and ((Get-Item $p).Length -gt 0)) { Warn "home profile $f is not empty after cloning; review it." }
}

$list = Protect-Text (Invoke-Hermes @('profile','list'))
Set-Content -Path (Join-Path $LogDir '30-profile-list.txt') -Value $list -Encoding UTF8
Say $list
Complete-Stage
