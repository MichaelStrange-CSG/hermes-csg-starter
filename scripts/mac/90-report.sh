#!/bin/bash
# Build the install report for the kit maintainer. Contains machine facts and check results only:
# no email, no SOUL.md text, no memory, no file contents, home folder shown as ~.
# Usage: bash scripts/mac/90-report.sh [notes-file]   (notes-file: Claude Code's plain-language notes)
source "$(dirname "$0")/lib.sh"
STAGE="90-report"
NOTES="${1:-}"
case "$NOTES" in ""|/*) ;; *) [ -f "$NOTES" ] || NOTES="$STARTER_ROOT/$NOTES" ;; esac
OUT="$STARTER_ROOT/INSTALL-REPORT.md"
flag() { grep -E "^$1=" "$LOG_DIR/flags.txt" 2>/dev/null | tail -1 | cut -d= -f2-; }

# A stage counts as failed only if its most recent outcome is FAIL (a failure fixed by a re-run is "resolved").
FAILED_STAGES=$(awk -F'\t' '$3=="DONE"||$3=="FAIL"{last[$2]=$3} END{for(s in last) if(last[s]=="FAIL") print s}' "$STATUS_FILE" 2>/dev/null | sort | tr '\n' ' ')
FAILS=$(echo $FAILED_STAGES | wc -w | tr -d ' ')
RESOLVED=$(awk -F'\t' '$3=="FAIL"' "$STATUS_FILE" 2>/dev/null | wc -l | tr -d ' '); RESOLVED=$((RESOLVED - FAILS)); [ $RESOLVED -lt 0 ] && RESOLVED=0
WARNS=$(awk -F'\t' '$3=="WARN"' "$STATUS_FILE" 2>/dev/null | wc -l | tr -d ' ')
DONE=$(awk -F'\t' '$3=="DONE"{print $4}' "$STATUS_FILE" 2>/dev/null | sort -u | tr '\n' ' ')
if [ "$FAILS" = 0 ] && echo "$DONE" | grep -q "50-verify"; then RESULT="SUCCESS"; elif [ "$FAILS" = 0 ]; then RESULT="INCOMPLETE"; else RESULT="FAILED"; fi
PLATFORM="Apple Silicon Mac"; [ "$(flag INTEL_MAC)" = 1 ] && PLATFORM="Intel Mac (unsupported platform, best effort)"

{
  echo "# Hermes starter install report"
  echo
  echo "| | |"
  echo "|---|---|"
  echo "| Result | **$RESULT** |"
  echo "| Platform | $PLATFORM |"
  echo "| Kit version | $(lock STARTER_VERSION) |"
  echo "| Report created | $(date '+%Y-%m-%d %H:%M %Z') |"
  echo "| Failed stages | ${FAILED_STAGES:-none} |"
  echo "| Warnings / failures fixed by a re-run | $WARNS / $RESOLVED |"
  echo "| Stages completed | $DONE |"
  echo "| Model chosen | $(flag MODEL) (reasoning effort: $(flag EFFORT)) |"
  echo "| SOUL.md sizes (chars) | work: $(flag SOUL_work) · home: $(flag SOUL_home) |"
  echo
  echo "## System"
  echo '```'
  cat "$LOG_DIR/system.txt" 2>/dev/null
  echo "Hermes: $(hermes --version 2>&1 | head -1)"
  echo '```'
  echo
  echo "## Profiles"
  echo '```'
  cat "$LOG_DIR/30-profile-list.txt" 2>/dev/null
  echo '```'
  echo
  echo "## Step log"
  echo '```'
  cut -f1-4 "$STATUS_FILE" 2>/dev/null
  echo '```'
  echo
  if [ -n "$NOTES" ] && [ -f "$NOTES" ]; then
    echo "## Notes from the installer (Claude Code)"
    echo
    _redact < "$NOTES"
    echo
  fi
  echo "## Last lines of any failed step"
  for st in $FAILED_STAGES; do
    for f in "$LOG_DIR/$st"*.log; do
      [ -f "$f" ] || continue
      echo "### $(basename "$f")"; echo '```'; tail -40 "$f" | _redact; echo '```'
    done
  done
} > "$OUT"

# Last-chance scrub: drop anything that looks like an email address.
sed -i '' -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/<email removed>/g' "$OUT"
cp "$OUT" "$HOME/Desktop/Hermes-Install-Report.md" 2>/dev/null && DESK=" and ~/Desktop/Hermes-Install-Report.md"
echo "Report written to INSTALL-REPORT.md$DESK (result: $RESULT)"
