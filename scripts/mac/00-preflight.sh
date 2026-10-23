#!/bin/bash
# Read-only checks. Changes nothing on the Mac.
# Exit 0 = ready. Exit 1 = a blocking problem (see the FAIL line). Exit 3 = Xcode Command Line Tools missing.
source "$(dirname "$0")/lib.sh"
stage_start "00-preflight"
: > "$LOG_DIR/system.txt"
sys() { printf '%s: %s\n' "$1" "$2" | _redact >> "$LOG_DIR/system.txt"; }

# --- Mac and hardware ---------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || fail "This is not a Mac. Use the Windows scripts instead."
MACOS="$(sw_vers -productVersion)"
ARCH="$(uname -m)"
TRANSLATED="$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)"
MODEL="$(sysctl -n hw.model 2>/dev/null)"
CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
RAM_GB=$(( $(sysctl -n hw.memsize) / 1073741824 ))
FREE_GB=$(df -k "$HOME" | awk 'NR==2{print int($4/1048576)}')
sys "OS" "macOS $MACOS ($(sw_vers -buildVersion))"
sys "Architecture" "$ARCH (rosetta=$TRANSLATED)"
sys "Model" "$MODEL"
sys "CPU" "$CPU"
sys "RAM" "${RAM_GB} GB"
sys "Free disk" "${FREE_GB} GB"

if [ "$TRANSLATED" = "1" ]; then
  warn "This shell runs under Rosetta on an Apple Silicon Mac. Results may be x86_64. Treat this Mac as Apple Silicon."
fi
if [ "$ARCH" = "x86_64" ] && [ "$TRANSLATED" != "1" ]; then
  warn "Intel Mac. Hermes does not officially support Intel Macs; this install is best effort. Send the install report to the person who shared this kit when done."
  echo "INTEL_MAC=1" > "$LOG_DIR/flags.txt"
else
  echo "INTEL_MAC=0" > "$LOG_DIR/flags.txt"
  ok "Apple Silicon Mac ($ARCH)"
fi

MIN_OS="$(lock MACOS_MIN)"
ver_ge "$MACOS" "$MIN_OS" || fail "macOS $MACOS is too old. Hermes needs macOS $MIN_OS or newer (Node.js 26 floor). Update macOS first."
ok "macOS $MACOS (need $MIN_OS+)"

[ "$RAM_GB" -ge 8 ] && ok "RAM ${RAM_GB} GB" || warn "RAM ${RAM_GB} GB. Hermes runs, but the Desktop build and browser tools are slow under 8 GB."
MIN_FREE="$(lock MIN_FREE_GB)"
[ "$FREE_GB" -ge "$MIN_FREE" ] || fail "Only ${FREE_GB} GB free disk space; need ${MIN_FREE} GB. Free up space and run this again."
ok "Free disk ${FREE_GB} GB"

# --- Developer tools ----------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1 || ! /usr/bin/git --version >/dev/null 2>&1; then
  status_add FAIL "Xcode Command Line Tools missing"
  say "  FAIL  Apple's Command Line Tools (git) are not installed."
  say "        Run:  xcode-select --install"
  say "        A macOS window opens. The user clicks Install (may need an admin password), waits for it to finish,"
  say "        then run this preflight again."
  exit 3
fi
ok "Command Line Tools: $(/usr/bin/git --version)"
command -v curl >/dev/null || fail "curl is missing (it ships with macOS; something is wrong with this Mac)."

# --- Claude Code CLI (reported here; 05-claude-cli.sh fixes it) ---------------------------------
CLAUDE="$(claude_bin)"
if [ -n "$CLAUDE" ]; then
  CV="$("$CLAUDE" --version 2>/dev/null | awk '{print $1}')"
  sys "Claude Code" "$CV ($CLAUDE)"
  ok "Claude Code CLI found: $CV"
else
  sys "Claude Code" "not on PATH"
  info "Claude Code CLI (claude) not found on PATH. Stage 05 installs it."
fi

for v in $CONFLICTS_FOUND; do
  SRC="$(persistent_source "$v")"
  if [ -n "$SRC" ]; then
    warn "Environment variable $v is set in $SRC. Hermes would inherit it: the Claude subscription plugin refuses to run with it, and it would bill an API key instead of the Claude plan. Remove it from $SRC."
  elif [ "$IN_CLAUDE_CODE" = 1 ]; then
    info "$v is set only in the Claude app session running this install. The scripts clear it; Hermes won't see it."
  else
    warn "Environment variable $v is set in this session (source not found in shell startup files). Hermes started from this shell would inherit it; find where it is set and remove it."
  fi
done

# --- Existing Hermes ----------------------------------------------------------------------------
PIN="$(lock HERMES_COMMIT)"
if [ -d "$HOME/.hermes/hermes-agent/.git" ]; then
  HEAD="$(git -C "$HOME/.hermes/hermes-agent" rev-parse HEAD 2>/dev/null)"
  if [ "$HEAD" = "$PIN" ]; then
    ok "Hermes is already installed at the pinned commit (re-run is safe)."
  else
    fail "A different Hermes install already exists (~/.hermes, commit ${HEAD:0:12}). This kit does not overwrite it. Ask the person who shared this kit with you before going further."
  fi
elif [ -e "$HOME/.hermes" ]; then
  fail "~/.hermes exists but is not a Hermes git install. This kit will not overwrite it. Ask the person who shared this kit with you."
else
  ok "No existing Hermes install."
fi
for app in "/Applications/Hermes.app" "$HOME/Applications/Hermes.app"; do
  [ -d "$app" ] && warn "A Hermes app already exists at $app. Stage 10 leaves it alone."
done

# --- Network ------------------------------------------------------------------------------------
# The install downloads from these. A 000 means blocked or unreachable from this Mac's command line.
NET_FAIL=0
for url in https://github.com https://raw.githubusercontent.com https://codeload.github.com \
           https://objects.githubusercontent.com https://hermes-assets.nousresearch.com \
           https://nodejs.org https://registry.npmjs.org https://pypi.org https://files.pythonhosted.org \
           https://claude.ai https://api.anthropic.com; do
  body="$(curl -s -L --max-time 20 -o - -w '\n__CODE__%{http_code}' "$url" 2>/dev/null | tail -c 4000)"
  code="${body##*__CODE__}"
  if echo "$body" | grep -qiE "umbrella|cisco.*block|this site is blocked"; then
    warn "$url is BLOCKED by a web filter (Cisco Umbrella page). Ask IT to allow it."; NET_FAIL=1
  elif [ "$code" = "000" ]; then
    warn "$url unreachable (no response)."; NET_FAIL=1
  else
    say "  OK    $url ($code)"
  fi
done
[ "$NET_FAIL" = 0 ] && ok "All download sites reachable" || warn "Some download sites failed. The install will probably fail at that step."

stage_done
exit 0
