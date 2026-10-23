#!/bin/bash
# Make sure the Claude Code command-line tool (`claude`) is installed, new enough, and signed in.
# The Claude desktop app has Claude Code built in, but Hermes needs the separate `claude` command.
# Exit 0 = ready. Exit 2 = installed but the user must sign in (see START-HERE.md). Exit 1 = failure.
source "$(dirname "$0")/lib.sh"
stage_start "05-claude-cli"
MIN="$(lock CLAUDE_CODE_MIN)"

CLAUDE="$(claude_bin)"
if [ -z "$CLAUDE" ]; then
  info "Installing Claude Code with Anthropic's official installer (https://claude.ai/install.sh)"
  curl -fsSL https://claude.ai/install.sh -o "$LOG_DIR/claude-install.sh" || fail "Could not download the Claude Code installer."
  bash "$LOG_DIR/claude-install.sh" > "$LOG_DIR/05-claude-install.log" 2>&1 || { tail -20 "$LOG_DIR/05-claude-install.log"; fail "Claude Code installer failed (log: logs/05-claude-install.log)."; }
  rm -f "$LOG_DIR/claude-install.sh"
  CLAUDE="$(claude_bin)"
  [ -n "$CLAUDE" ] || fail "Claude Code installed but 'claude' is not in ~/.local/bin. See logs/05-claude-install.log."
fi

CV="$("$CLAUDE" --version 2>/dev/null | awk '{print $1}')"
if ! ver_ge "$CV" "$MIN"; then
  info "Claude Code $CV is older than $MIN; running 'claude update'"
  "$CLAUDE" update > "$LOG_DIR/05-claude-update.log" 2>&1 || true
  CV="$("$CLAUDE" --version 2>/dev/null | awk '{print $1}')"
  ver_ge "$CV" "$MIN" || fail "Claude Code is $CV, need $MIN or newer, and 'claude update' did not fix it (log: logs/05-claude-update.log)."
fi
ok "Claude Code $CV at $CLAUDE (need $MIN+)"
# Preflight recorded the state before this stage; replace that line with what's installed now.
SYS="$LOG_DIR/system.txt"
if [ -f "$SYS" ]; then grep -v '^Claude Code:' "$SYS" > "$SYS.tmp"; mv "$SYS.tmp" "$SYS"; fi
printf 'Claude Code: %s (%s)\n' "$CV" "$CLAUDE" | _redact >> "$SYS"

# Sign-in check. Only loggedIn and the plan type are recorded; never the email or org.
AUTH="$("$CLAUDE" auth status --json 2>/dev/null)"
PLAN="$(printf '%s' "$AUTH" | sed -n 's/.*"subscriptionType": *"\([^"]*\)".*/\1/p' | head -1)"
METHOD="$(printf '%s' "$AUTH" | sed -n 's/.*"authMethod": *"\([^"]*\)".*/\1/p' | head -1)"
if printf '%s' "$AUTH" | grep -qE '"loggedIn": *true'; then
  if [ "$METHOD" != "claude.ai" ]; then
    warn "Claude Code is signed in with '$METHOD', not a Claude subscription. Hermes' Claude plugin needs a Claude.ai (Pro/Max/Team) sign-in. Run: claude auth login --claudeai"
  fi
  grep -v '^Claude plan:' "$SYS" > "$SYS.tmp" 2>/dev/null; mv "$SYS.tmp" "$SYS"
  printf 'Claude plan: %s\n' "${PLAN:-unknown}" >> "$SYS"
  ok "Claude Code is signed in (plan: ${PLAN:-unknown})"
  stage_done
  exit 0
fi

status_add NEEDS_LOGIN "Claude Code is not signed in"
say "  ACTION  Claude Code is installed but not signed in."
say "          Run 'claude auth login' (it opens the browser), the user approves with their OWN Claude account,"
say "          then run this script again."
exit 2
