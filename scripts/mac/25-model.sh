#!/bin/bash
# Point the Work (default) profile at the Claude subscription plugin and pick the best model the
# user's Claude plan answers on, trying VERSIONS.lock MODEL_PREFERENCE in order with a real test message.
source "$(dirname "$0")/lib.sh"
stage_start "25-model"
PID="$(lock PLUGIN_ID)"
IFS=',' read -r -a MODELS <<< "$(lock MODEL_PREFERENCE)"

hermes config set model.provider "$PID" >/dev/null       || fail "config set model.provider failed"
hermes config set model.base_url "process://$PID" >/dev/null || fail "config set model.base_url failed"
hermes config set model.api_mode chat_completions >/dev/null || fail "config set model.api_mode failed"

CHOSEN=""
for m in "${MODELS[@]}"; do
  hermes config set model.default "$m" >/dev/null || fail "config set model.default failed"
  info "Testing model $m (one short message on the user's Claude plan)"
  OUT="$(hermes_ask "" 240 'Reply with exactly the word READY and nothing else.')"
  printf '%s\n--- %s ---\n' "$OUT" "$m" | _redact >> "$LOG_DIR/25-model-tests.log"
  if printf '%s' "$OUT" | grep -q "READY"; then CHOSEN="$m"; break; fi
  warn "Model $m did not answer on this plan (details in logs/25-model-tests.log)"
done
[ -n "$CHOSEN" ] || fail "No Claude model answered. Check 'claude auth status' and the plan, and see logs/25-model-tests.log."
echo "MODEL=$CHOSEN" >> "$LOG_DIR/flags.txt"
ok "Work profile model: $CHOSEN via $PID"

# Default thinking depth, same as the reference setup. Hermes reads agent.reasoning_effort (hermes_constants
# resolve_reasoning_config) though `config set` doesn't list it as known, hence --force to skip that notice.
EFFORT="$(lock REASONING_EFFORT)"
hermes config set agent.reasoning_effort "$EFFORT" --force >/dev/null 2>&1 || fail "config set agent.reasoning_effort failed"
[ "$(hermes config get agent.reasoning_effort 2>/dev/null | head -1)" = "$EFFORT" ] || fail "agent.reasoning_effort did not save as $EFFORT"
echo "EFFORT=$EFFORT" >> "$LOG_DIR/flags.txt"
ok "Reasoning effort: $EFFORT"

stage_done
