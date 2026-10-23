# Install the Claude Subscription DirectSDK plugin at the pinned commit into the default (Work) profile,
# apply the streaming fix (plugin patch + Hermes core patch, see VERSIONS.lock), and enable the plugin.
# Every touched file is checked by hash before and after; anything unexpected stops the stage.
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage '20-plugin'
$src = Get-Lock 'PLUGIN_SOURCE'; $sha = Get-Lock 'PLUGIN_SHA'; $pluginId = Get-Lock 'PLUGIN_ID'
if (-not (Get-HermesExe)) { Fail 'hermes command not found. Run 10-hermes first.' }
if (-not (Get-GitExe)) { Fail 'git.exe not found (the Hermes installer normally provides it). Run 10-hermes first.' }

$home0 = Get-HermesHome
if (-not $home0) { Fail 'Could not find the Hermes home folder.' }
$pdir = Join-Path $home0 "plugins\$pluginId"
$core = $HermesCheckout

# --- Plugin ---
if (Test-Path (Join-Path $pdir 'directsdk.py')) {
    $st = Get-PluginState $pdir
    if (($st -eq 'patched') -or ($st -eq 'pristine')) { Ok 'Plugin already present at the pinned version.' }
    else { Fail "A different version of the Claude plugin is already installed ($pdir). Not replacing it. Ask the person who shared this kit with you." }
} else {
    Info "Installing $src at $($sha.Substring(0,12))"
    $out = Invoke-Hermes @('plugins','install',$src,'--ref',$sha,'--yes-deps','--enable')
    Set-Content -Path (Join-Path $LogDir '20-plugin-install.log') -Value (Protect-Text $out) -Encoding UTF8
    if ($LastHermesExit -ne 0) { Say (Protect-Text $out); Fail 'Plugin install failed (log: logs\20-plugin-install.log).' }
    if (-not (Test-Path (Join-Path $pdir 'directsdk.py'))) { Fail "Plugin install reported success but $pdir\directsdk.py is missing." }
    if ((Get-PluginState $pdir) -ne 'pristine') { Fail 'Installed plugin files do not match the pinned commit. Not patching.' }
    Ok 'Plugin installed (pinned, unmodified files verified)'
}
# A "custom (unreviewed) source" warning in the install log is expected for a commit-pinned install from
# Nous Research's official repo.
if ((Get-PluginState $pdir) -eq 'pristine') {
    $bk = Join-Path $LogDir ('backup-plugin-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $bk | Out-Null
    Copy-Item (Join-Path $pdir 'directsdk.py'), (Join-Path $pdir '__init__.py') $bk
    if (-not (Invoke-KitPatch $pdir (Join-Path $StarterRoot 'patches\directsdk-streaming-plugin.patch'))) {
        Fail 'Plugin patch did not apply; plugin left as it was.'
    }
}
if ((Get-PluginState $pdir) -ne 'patched') { Fail 'Plugin files are wrong after patching. Originals are in logs\backup-plugin-*. Stop and ask the person who shared this kit with you.' }
Ok 'Plugin streaming patch applied and verified (replies stream, thinking text shows)'

# --- Hermes core ---
$coreState = Get-CoreState $core
if ($coreState -eq 'patched') {
    Ok 'Hermes streaming patch already applied.'
} elseif ($coreState -eq 'pristine') {
    if (-not (Invoke-KitPatch $core (Join-Path $StarterRoot 'patches\directsdk-streaming-core.patch'))) {
        Fail 'Hermes core patch did not apply; Hermes left as it was.'
    }
    if ((Get-CoreState $core) -ne 'patched') { Fail 'Hermes files are wrong after patching. Undo: git -C %LOCALAPPDATA%\hermes\hermes-agent checkout -- agent/turn_api_call.py providers/base.py' }
    Ok 'Hermes streaming patch applied and verified'
} else {
    Fail 'Hermes files agent\turn_api_call.py or providers\base.py have unexpected changes. Not patching. Ask the person who shared this kit with you.'
}

Invoke-Hermes @('plugins','enable',$pluginId) | Out-Null
if (-not (Test-PluginEnabled '' $pluginId)) { Say (Protect-Text (Invoke-Hermes @('plugins','list','--plain'))); Fail 'Plugin is not enabled.' }
Ok 'Plugin enabled in the Work (default) profile'

Complete-Stage
