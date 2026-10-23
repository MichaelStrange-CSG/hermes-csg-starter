#!/bin/bash
# Install Hermes Agent with the official installer, pinned to the exact commit in VERSIONS.lock.
# Takes 5-20 minutes. Writes everything under ~/.hermes and ~/.local/bin; no admin rights needed.
source "$(dirname "$0")/lib.sh"
stage_start "10-hermes"
PIN="$(lock HERMES_COMMIT)"
WANT_SHA="$(lock HERMES_INSTALL_SH_SHA256)"
VERSION="$(lock HERMES_VERSION)"
CHECKOUT="$HOME/.hermes/hermes-agent"

if [ -d "$CHECKOUT/.git" ] && [ "$(git -C "$CHECKOUT" rev-parse HEAD 2>/dev/null)" = "$PIN" ] && [ -n "$(hermes_bin)" ]; then
  ok "Hermes already installed at the pinned commit; skipping the installer."
else
  INSTALLER="$LOG_DIR/hermes-install.sh"
  # --retry covers GitHub's transient 429/5xx answers (seen in rehearsal).
  curl -fsSL --retry 4 --retry-delay 15 "https://raw.githubusercontent.com/NousResearch/hermes-agent/$PIN/scripts/install.sh" -o "$INSTALLER" \
    || fail "Could not download the Hermes installer from GitHub."
  GOT_SHA="$(shasum -a 256 "$INSTALLER" | awk '{print $1}')"
  [ "$GOT_SHA" = "$WANT_SHA" ] || fail "Hermes installer checksum mismatch (got $GOT_SHA). Not running it."
  ok "Hermes installer downloaded and verified (sha256 $WANT_SHA)"
  info "Running the Hermes installer pinned to $VERSION (${PIN:0:12}). This takes a while; progress is in logs/10-hermes-install.log"
  bash "$INSTALLER" --commit "$PIN" --non-interactive > "$LOG_DIR/10-hermes-install.log" 2>&1
  RC=$?
  rm -f "$INSTALLER"
  [ $RC -eq 0 ] || { tail -25 "$LOG_DIR/10-hermes-install.log" | _redact; fail "Hermes installer exited with code $RC (log: logs/10-hermes-install.log)."; }
fi

HB="$(hermes_bin)"
[ -n "$HB" ] || fail "The hermes command was not found after install (expected ~/.local/bin/hermes)."
HEAD="$(git -C "$CHECKOUT" rev-parse HEAD 2>/dev/null)"
[ "$HEAD" = "$PIN" ] || fail "Hermes checkout is at ${HEAD:0:12}, expected ${PIN:0:12}."
HV="$(hermes --version 2>&1 | head -1)"
echo "$HV" | grep -q "$VERSION" || fail "hermes --version reports '$HV', expected $VERSION."
ok "$HV"

# Pinned install: no update prompts or banners. (`hermes update` still works if someone runs it on purpose,
# but it would leave the version this kit was tested on. See README "Staying pinned".)
hermes config set updates.check false >/dev/null || fail "Could not set updates.check"
ok "Update checks turned off (pinned install)"

# Make `hermes` available in new Terminal windows. The installer normally does this; confirm.
if ! grep -qsE 'PATH=.*\.local/bin' "$HOME/.zshrc" "$HOME/.zprofile" 2>/dev/null; then
  printf '\n# Hermes Agent command\ncase ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' >> "$HOME/.zshrc"
  ok "Added ~/.local/bin to PATH in ~/.zshrc"
fi

stage_done
