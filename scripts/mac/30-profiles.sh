#!/bin/bash
# Two profiles: the built-in default profile shown as "Work", and a "home" profile cloned from it
# (same plugin, patch and model; its own empty memory). Hermes always keeps the default profile, so
# renaming it is how we end up with exactly two.
source "$(dirname "$0")/lib.sh"
stage_start "30-profiles"
PID="$(lock PLUGIN_ID)"; PATCHED="$(lock DIRECTSDK_PATCHED_SHA256)"

hermes profile rename default Work > /dev/null 2>&1 || fail "Could not set the default profile's display name to Work."
ok "Default profile now shows as 'Work' (its internal id stays 'default')"

if hermes profile show home >/dev/null 2>&1; then
  ok "Profile 'home' already exists"
else
  hermes profile create home --clone-from default --no-alias --description "Personal use. Kept separate from work." \
    > "$LOG_DIR/30-profile-create.log" 2>&1 || { tail -15 "$LOG_DIR/30-profile-create.log" | _redact; fail "Could not create the home profile."; }
  ok "Created profile 'home' (cloned settings and plugin from Work)"
fi

HH="$(hermes_home home)"; [ -n "$HH" ] || fail "Could not find the home profile folder."
[ "$(plugin_state "$HH/plugins/$PID")" = patched ] || fail "The home profile does not have the patched plugin."
hermes -p home plugins enable "$PID" >/dev/null 2>&1
plugin_enabled home "$PID" || fail "Plugin not enabled in the home profile."
for k in model.provider model.default; do
  [ "$(hermes config get $k 2>/dev/null)" = "$(hermes -p home config get $k 2>/dev/null)" ] || fail "home profile $k differs from Work."
done
hermes -p home config set updates.check false >/dev/null
EFFORT="$(lock REASONING_EFFORT)"
hermes -p home config set agent.reasoning_effort "$EFFORT" --force >/dev/null 2>&1
[ "$(hermes -p home config get agent.reasoning_effort 2>/dev/null | head -1)" = "$EFFORT" ] || fail "home profile reasoning effort is not $EFFORT."
ok "home profile: patched plugin enabled, same model as Work, reasoning effort $EFFORT"

# Clone copies these from Work; at install time they're empty, but never carry work notes into home.
for f in memories/MEMORY.md memories/USER.md; do
  [ -s "$HH/$f" ] && warn "home profile $f is not empty after cloning; review it." 
done

hermes profile list 2>&1 | _redact > "$LOG_DIR/30-profile-list.txt"
cat "$LOG_DIR/30-profile-list.txt"
stage_done
