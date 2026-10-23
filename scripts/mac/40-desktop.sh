#!/bin/bash
# Build the Hermes desktop app on this Mac from the pinned source and put it in ~/Applications.
# Building locally (not downloading the store-style app) keeps it pinned and works on Intel Macs.
# Takes 5-15 minutes. Run it in the background and wait for logs/40-desktop.exit.
source "$(dirname "$0")/lib.sh"
stage_start "40-desktop"

info "Building the desktop app (log: logs/40-desktop-build.log)"
( cd "$HOME" && hermes desktop --build-only ) > "$LOG_DIR/40-desktop-build.log" 2>&1
RC=$?
[ $RC -eq 0 ] || { tail -30 "$LOG_DIR/40-desktop-build.log" | _redact; fail "Desktop build failed with code $RC. Hermes still works in Terminal ('hermes'); report this to the person who shared this kit."; }

REL="$HOME/.hermes/hermes-agent/apps/desktop/release"
APP=""
for d in mac-arm64 mac mac-universal; do [ -d "$REL/$d/Hermes.app" ] && { APP="$REL/$d/Hermes.app"; break; }; done
[ -n "$APP" ] || fail "Build finished but no Hermes.app was found under $REL."
ok "Built $(basename "$(dirname "$APP")")/Hermes.app"

DEST="$HOME/Applications/Hermes.app"
mkdir -p "$HOME/Applications"
if [ -d "$DEST" ]; then
  if pgrep -f "$DEST/Contents/MacOS/Hermes" >/dev/null; then
    fail "Hermes is open. Quit it (Cmd+Q) and run this stage again."
  fi
  mv "$DEST" "$DEST.old-$(date +%Y%m%d-%H%M%S)"
fi
/usr/bin/ditto "$APP" "$DEST" || fail "Could not copy Hermes.app to ~/Applications."
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
ok "Installed $DEST (open it from Launchpad, Spotlight or ~/Applications)"

stage_done
