# Install an approved SOUL.md draft into a profile.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\win\60-soul.ps1 work soul-drafts\work-SOUL.md
#        powershell -NoProfile -ExecutionPolicy Bypass -File scripts\win\60-soul.ps1 home soul-drafts\home-SOUL.md
param([string]$Which = '', [string]$Draft = '')
. (Join-Path $PSScriptRoot 'lib.ps1')
Start-Stage "60-soul-$Which"
if ($Which -eq 'work') { $p = '' } elseif ($Which -eq 'home') { $p = 'home' } else { Fail "First argument must be 'work' or 'home'." }
if (-not [IO.Path]::IsPathRooted($Draft)) { $Draft = Join-Path $StarterRoot $Draft }
if (-not (Test-Path $Draft)) { Fail "Draft file not found: $Draft" }
$h = Get-HermesHome $p
if (-not $h) { Fail "Profile folder not found for $Which." }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$text = [IO.File]::ReadAllText($Draft)
$chars = $text.Length
if ($chars -lt 400) { Fail "Draft is only $chars characters; it is probably incomplete." }
if ($chars -gt 6000) { Fail "Draft is $chars characters. Trim it under 6,000 (aim for about 4,000); SOUL.md is sent with every message." }
if ($chars -gt 4500) { Warn "Draft is $chars characters; about 4,000 is the target." }
if ($text -notmatch '(?m)^# Identity') { Fail "Draft has no '# Identity' section. Follow the SOUL-BUILDER.md framework." }
if ($text -match '(?i)(sk-[a-z0-9_-]{16,}|password *[:=]|api[_ -]?key *[:=]|\b[0-9]{13,19}\b|BEGIN [A-Z ]*PRIVATE KEY)') {
    Fail 'Draft looks like it contains a secret, key or card-like number. Remove it; SOUL.md must never hold credentials.'
}

$dest = Join-Path $h 'SOUL.md'
if (Test-Path $dest) {
    Copy-Item $dest ("$dest.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Info "Backed up the previous $Which SOUL.md"
}
# UTF-8 without BOM, LF line endings: what Hermes expects.
[IO.File]::WriteAllText($dest, ($text -replace "`r`n", "`n"), $utf8)
if ((Get-ShaLf $dest) -ne (Get-ShaLf $Draft)) { Fail 'Written SOUL.md does not match the draft.' }
Copy-Item (Join-Path $StarterRoot 'SOUL-BUILDER.md') (Join-Path $h 'SOUL-BUILDER.md') -ErrorAction SilentlyContinue
Add-Content -Path (Join-Path $LogDir 'flags.txt') -Value "SOUL_$Which=$chars" -Encoding ASCII
Ok "$Which SOUL.md installed ($chars characters). New chats use it; open chats keep the old one."
Complete-Stage
