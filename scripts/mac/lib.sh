#!/bin/bash
# Shared helpers for the macOS install scripts. Sourced, never run directly.
# Every stage appends one line per result to logs/status.txt; 90-report.sh turns that into the report.
set -u

STARTER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$STARTER_ROOT/logs"
STATUS_FILE="$LOG_DIR/status.txt"
mkdir -p "$LOG_DIR"

# Hermes publishes its command in ~/.local/bin; Claude Code's shell may not have it on PATH yet.
export PATH="$HOME/.local/bin:$PATH"

lock() { tr -d '\r' < "$STARTER_ROOT/VERSIONS.lock" | grep -E "^$1=" | head -1 | cut -d= -f2-; }

_redact() { sed -e "s#$HOME#~#g" -e "s#$(id -un)#<user>#g"; }
status_add() { printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${STAGE:-?}" "$1" "$2" | _redact >> "$STATUS_FILE"; }

say()  { printf '%s\n' "$*"; }
ok()   { printf '  OK    %s\n' "$*"; status_add OK "$*"; }
info() { printf '  INFO  %s\n' "$*"; status_add INFO "$*"; }
warn() { printf '  WARN  %s\n' "$*"; status_add WARN "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; status_add FAIL "$*"; printf '\nSTOPPED in %s: %s\nDo not work around this. Report it to the user.\n' "${STAGE:-?}" "$*"; exit 1; }
stage_start() {
  STAGE="$1"; say ""; say "=== $1 ==="; status_add START "$1"
  rm -f "$LOG_DIR/$1.exit"
  # Long stages run in the background; the .exit file tells Claude Code the stage finished and how.
  trap 'echo $? > "$LOG_DIR/$STAGE.exit"' EXIT
  # A stage killed from outside (agent tool time limit, Ctrl-C) must not look like success: without these
  # traps bash ran the EXIT trap with status 0 and wrote 0 to the .exit file (seen in the v1.1.0 link test).
  trap 'status_add FAIL "Stopped from outside by SIGTERM (killed or timed out)"; exit 143' TERM
  trap 'status_add FAIL "Stopped from outside by SIGINT"; exit 130' INT
  trap 'status_add FAIL "Stopped from outside by SIGHUP"; exit 129' HUP
}
stage_done()  { say "=== $STAGE: done ==="; status_add DONE "$STAGE"; }

# sha256 with CRLF normalized to LF, so the same file hashes the same on Windows and macOS.
sha_lf() { [ -f "$1" ] || return 0; tr -d '\r' < "$1" | shasum -a 256 | awk '{print $1}'; }

# apply_patch <folder> <patch file>: apply a kit patch inside <folder>, all files or none (git apply is
# atomic). The ceiling stops git from adopting a repository above the folder, which would silently skip
# paths. Callers verify the result by hash.
apply_patch() {
  ( cd "$1" || exit 1
    export GIT_CEILING_DIRECTORIES="$(dirname "$1")"
    if git apply --check "$2" 2>/dev/null; then git apply "$2"
    elif git apply --check --ignore-whitespace "$2" 2>/dev/null; then git apply --ignore-whitespace "$2"
    else git apply --check "$2" 2>&1 | head -5 | _redact; exit 1; fi )
}

# Streaming-fix state of a file / the plugin folder / the Hermes checkout: pristine, patched or other.
# Hashes live in VERSIONS.lock as <KEY>_PRISTINE_SHA256 and <KEY>_PATCHED_SHA256.
file_state() {
  local h; h="$(sha_lf "$1")"
  if [ -n "$h" ] && [ "$h" = "$(lock "${2}_PATCHED_SHA256")" ]; then echo patched
  elif [ -n "$h" ] && [ "$h" = "$(lock "${2}_PRISTINE_SHA256")" ]; then echo pristine
  else echo other; fi
}
_pair_state() { [ "$1" = "$2" ] && echo "$1" || echo other; }
plugin_state() { _pair_state "$(file_state "$1/directsdk.py" DIRECTSDK)" "$(file_state "$1/__init__.py" PLUGIN_INIT)"; }
core_state() { _pair_state "$(file_state "$1/agent/turn_api_call.py" CORE_TURN)" "$(file_state "$1/providers/base.py" CORE_BASE)"; }
HERMES_CHECKOUT="$HOME/.hermes/hermes-agent"

# ver_ge A B: true when dotted version A >= B.
ver_ge() {
  local IFS=.; local -a a=($1) b=($2); local i
  for i in 0 1 2 3; do
    local x=${a[$i]:-0} y=${b[$i]:-0}
    x=${x%%[!0-9]*}; y=${y%%[!0-9]*}; x=${x:-0}; y=${y:-0}
    ((10#$x > 10#$y)) && return 0
    ((10#$x < 10#$y)) && return 1
  done
  return 0
}

hermes_bin() { command -v hermes 2>/dev/null || { [ -x "$HOME/.local/bin/hermes" ] && echo "$HOME/.local/bin/hermes"; }; }
claude_bin() { command -v claude 2>/dev/null || { [ -x "$HOME/.local/bin/claude" ] && echo "$HOME/.local/bin/claude"; }; }

# Hermes home of a profile (default unless an argument is given), from Hermes itself.
hermes_home() {
  local p; p="$(hermes ${1:+-p "$1"} config path 2>/dev/null | tail -1)"
  [ -n "$p" ] && dirname "$p"
}

# Run a command with a time limit (macOS has no `timeout`).
with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

# The plugin refuses to run when these are set, and they would bill an API key instead of the plan.
# Record which were set (preflight warns), then clear them for this script and its children only.
CONFLICT_VARS="ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_FOUNDRY_API_KEY CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY"
CONFLICTS_FOUND=""
for _v in $CONFLICT_VARS; do [ -n "${!_v:-}" ] && CONFLICTS_FOUND="$CONFLICTS_FOUND $_v"; unset "$_v"; done
# Remember whether Claude Code launched us (the Claude app sets some of the vars above for its own session).
IN_CLAUDE_CODE=0; [ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ] && IN_CLAUDE_CODE=1
# Where a variable would persist for Hermes: a shell startup file or the macOS GUI (launchctl) environment.
# Prints the source, or nothing when it only exists in this session.
persistent_source() {
  local v="$1" f
  for f in "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.profile"; do
    grep -qsE "^[[:space:]]*(export[[:space:]]+)?$v=" "$f" && { echo "~/${f##*/}"; return; }
  done
  [ -n "$(launchctl getenv "$v" 2>/dev/null)" ] && echo "launchctl (macOS app environment)"
}
# These scripts run inside Claude Code; don't let its session markers leak into the claude processes Hermes starts.
unset CLAUDECODE CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_SSE_PORT CLAUDE_CODE_EXECPATH 2>/dev/null

# True when plugin $2 is enabled in profile $1 ("" = Work/default). --plain prints full names.
plugin_enabled() { hermes ${1:+-p "$1"} plugins list --enabled --plain 2>/dev/null | awk '{print $NF}' | grep -qx "$2"; }

# Hermes answers a one-line test prompt. Usage: hermes_ask <profile|""> <seconds> <prompt>. Prints the reply.
hermes_ask() {
  local p="$1" t="$2" q="$3"
  ( cd "$HOME" && with_timeout "$t" hermes ${p:+-p "$p"} chat -Q -q "$q" 2>&1 )
}
