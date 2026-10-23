#!/bin/bash
# Install the Claude Subscription DirectSDK plugin at the pinned commit into the default (Work) profile,
# apply the streaming fix (plugin patch + Hermes core patch, see VERSIONS.lock), and enable the plugin.
# Every touched file is checked by hash before and after; anything unexpected stops the stage.
source "$(dirname "$0")/lib.sh"
stage_start "20-plugin"
SRC="$(lock PLUGIN_SOURCE)"; SHA="$(lock PLUGIN_SHA)"; PID="$(lock PLUGIN_ID)"
[ -n "$(hermes_bin)" ] || fail "hermes command not found. Run 10-hermes.sh first."
command -v git >/dev/null || fail "git not found (it comes with the Xcode command line tools)."

HOME_DIR="$(hermes_home)"; [ -n "$HOME_DIR" ] || fail "Could not find the Hermes home folder."
PDIR="$HOME_DIR/plugins/$PID"
CORE="$HERMES_CHECKOUT"

# --- Plugin ---
if [ -f "$PDIR/directsdk.py" ]; then
  case "$(plugin_state "$PDIR")" in
    patched|pristine) ok "Plugin already present at the pinned version." ;;
    *) fail "A different version of the Claude plugin is already installed ($PDIR). Not replacing it. Ask the person who shared this kit with you." ;;
  esac
else
  info "Installing $SRC at ${SHA:0:12}"
  hermes plugins install "$SRC" --ref "$SHA" --yes-deps --enable > "$LOG_DIR/20-plugin-install.log" 2>&1 \
    || { tail -20 "$LOG_DIR/20-plugin-install.log" | _redact; fail "Plugin install failed (log: logs/20-plugin-install.log)."; }
  [ -f "$PDIR/directsdk.py" ] || fail "Plugin install reported success but $PDIR/directsdk.py is missing."
  [ "$(plugin_state "$PDIR")" = pristine ] || fail "Installed plugin files do not match the pinned commit. Not patching."
  ok "Plugin installed (pinned, unmodified files verified)"
fi
# A "custom (unreviewed) source" warning in the install log is expected for a commit-pinned install
# from Nous Research's official repo.
if [ "$(plugin_state "$PDIR")" = pristine ]; then
  BK="$LOG_DIR/backup-plugin-$(date +%Y%m%d-%H%M%S)"; mkdir -p "$BK"
  cp "$PDIR/directsdk.py" "$PDIR/__init__.py" "$BK/"
  apply_patch "$PDIR" "$STARTER_ROOT/patches/directsdk-streaming-plugin.patch" \
    || fail "Plugin patch did not apply; plugin left as it was."
fi
[ "$(plugin_state "$PDIR")" = patched ] \
  || fail "Plugin files are wrong after patching. Originals are in logs/backup-plugin-*. Stop and ask the person who shared this kit with you."
ok "Plugin streaming patch applied and verified (replies stream, thinking text shows)"

# --- Hermes core ---
[ "$(git -C "$CORE" rev-parse HEAD 2>/dev/null)" = "$(lock HERMES_COMMIT)" ] || fail "Hermes is not at the pinned commit; not patching it."
case "$(core_state "$CORE")" in
  patched) ok "Hermes streaming patch already applied." ;;
  pristine)
    apply_patch "$CORE" "$STARTER_ROOT/patches/directsdk-streaming-core.patch" \
      || fail "Hermes core patch did not apply; Hermes left as it was."
    [ "$(core_state "$CORE")" = patched ] \
      || fail "Hermes files are wrong after patching. Undo: git -C ~/.hermes/hermes-agent checkout -- agent/turn_api_call.py providers/base.py"
    ok "Hermes streaming patch applied and verified" ;;
  *) fail "Hermes files agent/turn_api_call.py or providers/base.py have unexpected changes. Not patching. Ask the person who shared this kit with you." ;;
esac

# --enable can be skipped when the install runs without a terminal; enable explicitly and check.
hermes plugins enable "$PID" >/dev/null 2>&1
plugin_enabled "" "$PID" || { hermes plugins list --plain 2>&1 | grep -iE "claude" | _redact; fail "Plugin is not enabled."; }
ok "Plugin enabled in the Work (default) profile"

stage_done
