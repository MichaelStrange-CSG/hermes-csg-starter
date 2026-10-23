#!/bin/bash
# End-to-end checks on both profiles. Read-only except for two short test chats.
source "$(dirname "$0")/lib.sh"
stage_start "50-verify"
PID="$(lock PLUGIN_ID)"; PATCHED="$(lock DIRECTSDK_PATCHED_SHA256)"
PIN="$(lock HERMES_COMMIT)"; VERSION="$(lock HERMES_VERSION)"
FAILS=0
check() { if eval "$2"; then ok "$1"; else warn "CHECK FAILED: $1"; FAILS=$((FAILS+1)); fi; }

check "hermes --version is $VERSION" 'hermes --version 2>&1 | head -1 | grep -q "$VERSION"'
check "Hermes source is at the pinned commit" '[ "$(git -C "$HOME/.hermes/hermes-agent" rev-parse HEAD)" = "$PIN" ]'
check "Hermes source has the streaming patch" '[ "$(core_state "$HERMES_CHECKOUT")" = patched ]'
check "Hermes source has no other local changes" \
  '[ -z "$(git -C "$HERMES_CHECKOUT" status --short --untracked-files=no -- . ":!agent/turn_api_call.py" ":!providers/base.py")" ]'
check "Update checks are off" '[ "$(hermes config get updates.check 2>/dev/null)" = "false" ]'
check "Profile list shows Work" 'hermes profile list 2>&1 | grep -q "Work"'

for P in "" home; do
  NAME="${P:-Work}"
  H="$(hermes_home "$P")"
  check "$NAME: plugin files are the patched pinned version" '[ "$(plugin_state "$H/plugins/$PID")" = patched ]'
  check "$NAME: plugin enabled" 'plugin_enabled "$P" "$PID"'
  check "$NAME: provider is the Claude subscription" '[ "$(hermes ${P:+-p "$P"} config get model.provider 2>/dev/null)" = "$PID" ]'
  MODEL="$(hermes ${P:+-p "$P"} config get model.default 2>/dev/null)"
  info "$NAME: model $MODEL"
  check "$NAME: reasoning effort is $(lock REASONING_EFFORT)" '[ "$(hermes ${P:+-p "$P"} config get agent.reasoning_effort 2>/dev/null | head -1)" = "$(lock REASONING_EFFORT)" ]'

  # One real message with reasoning on. Claude decides per message whether to think at all, so an easy
  # question can come back with no thinking block. Classify from the saved session:
  #   visible = thinking block with text (patch working); hidden = thinking block, empty text (patch NOT
  #   working); none = Claude didn't think this time (inconclusive, ask again, up to 3 tries).
  ANSWERED=0; THINK=none; RLEN=0
  ALOG="$H/logs/agent.log"; ALOG_START=$(( $(wc -l < "$ALOG" 2>/dev/null || echo 0) ))
  for TRY in 1 2 3; do
    OUT="$( cd "$HOME" && with_timeout 300 hermes ${P:+-p "$P"} chat --format stream-json --reasoning high \
            -q 'What is 37*43 - 19*28 + 1234/2? Work it out carefully, then reply with only the final number.' 2>&1 )"
    printf '%s\n' "$OUT" | _redact > "$LOG_DIR/50-verify-$NAME.jsonl"
    printf '%s' "$OUT" | grep -q "1676" && ANSWERED=1
    SID="$(printf '%s' "$OUT" | sed -n 's/.*"session_id": *"\([^"]*\)".*/\1/p' | head -1)"
    [ -n "$SID" ] || continue
    EXP="$LOG_DIR/.verify-export.jsonl"
    ( cd "$HOME" && hermes ${P:+-p "$P"} sessions export "$EXP" --session-id "$SID" --yes >/dev/null 2>&1 )
    RES="$(/usr/bin/python3 -I -c 'import json,sys
state, n = "none", 0
for line in open(sys.argv[1]):
    for m in json.loads(line).get("messages", []):
        if m.get("role") != "assistant": continue
        n = max(n, len(m.get("reasoning") or ""))
        details = m.get("reasoning_details") or []
        if isinstance(details, str):
            try: details = json.loads(details)
            except ValueError: details = []
        for env in details if isinstance(details, list) else []:
            for msg in (env.get("messages") or []) if isinstance(env, dict) else []:
                for c in msg.get("content") or []:
                    if c.get("type") == "thinking":
                        if c.get("thinking"): state = "visible"
                        elif state == "none": state = "hidden"
if n > 0: state = "visible"
print(state, n)' "$EXP" 2>/dev/null || echo "none 0")"
    rm -f "$EXP"
    THINK="${RES% *}"; RLEN="${RES#* }"
    [ "$THINK" = none ] || break
    info "$NAME: Claude answered without thinking (try $TRY of 3); asking again"
  done
  check "$NAME: Claude answered a test message correctly" '[ "$ANSWERED" = 1 ]'
  # Streaming fix: the test chats must have used the streaming client, never the old non-streaming one.
  NEWLOG="$(tail -n +$((ALOG_START+1)) "$ALOG" 2>/dev/null | grep "$PID client created")"
  check "$NAME: replies stream (streaming fix working)" \
    'printf "%s" "$NEWLOG" | grep -q "(chat_completion_stream_request" && ! printf "%s" "$NEWLOG" | grep -q "(chat_completion_request"'
  info "$NAME: thinking: $THINK ($RLEN characters)"
  if [ "$THINK" = none ]; then
    warn "$NAME: Claude never used thinking in 3 test messages, so the thinking-display patch could not be confirmed here (the patch file itself checked out). Look for text in the thinking panel in the app."
  else
    check "$NAME: thinking text is visible (patch working)" '[ "$THINK" = visible ]'
  fi
done

echo "VERIFY_FAILS=$FAILS" >> "$LOG_DIR/flags.txt"
[ $FAILS -eq 0 ] || fail "$FAILS verification check(s) failed. See the WARN lines above and logs/50-verify-*.jsonl."
stage_done
