#!/bin/bash
# Install an approved SOUL.md draft into a profile.
# Usage: bash scripts/mac/60-soul.sh work soul-drafts/work-SOUL.md
#        bash scripts/mac/60-soul.sh home soul-drafts/home-SOUL.md
source "$(dirname "$0")/lib.sh"
WHICH="${1:-}"; DRAFT="${2:-}"
stage_start "60-soul-$WHICH"
case "$WHICH" in
  work) P="" ;;
  home) P="home" ;;
  *) fail "First argument must be 'work' or 'home'." ;;
esac
case "$DRAFT" in /*) ;; *) [ -f "$DRAFT" ] || DRAFT="$STARTER_ROOT/$DRAFT" ;; esac
[ -f "$DRAFT" ] || fail "Draft file not found: $DRAFT"
H="$(hermes_home "$P")"; [ -d "$H" ] || fail "Profile folder not found for $WHICH."

CHARS=$(wc -m < "$DRAFT" | tr -d ' ')
[ "$CHARS" -ge 400 ] || fail "Draft is only $CHARS characters; it is probably incomplete."
[ "$CHARS" -le 6000 ] || fail "Draft is $CHARS characters. Trim it under 6,000 (aim for about 4,000); SOUL.md is sent with every message."
[ "$CHARS" -le 4500 ] || warn "Draft is $CHARS characters; about 4,000 is the target."
grep -qE '^# Identity' "$DRAFT" || fail "Draft has no '# Identity' section. Follow the SOUL-BUILDER.md framework."
if grep -qiE '(sk-[a-z0-9_-]{16,}|password *[:=]|api[_ -]?key *[:=]|\b[0-9]{13,19}\b|BEGIN [A-Z ]*PRIVATE KEY)' "$DRAFT"; then
  fail "Draft looks like it contains a secret, key or card-like number. Remove it; SOUL.md must never hold credentials."
fi

if [ -f "$H/SOUL.md" ]; then
  cp "$H/SOUL.md" "$H/SOUL.md.bak-$(date +%Y%m%d-%H%M%S)"
  info "Backed up the previous $WHICH SOUL.md"
fi
cp "$DRAFT" "$H/SOUL.md" || fail "Could not write $WHICH SOUL.md"
cmp -s "$DRAFT" "$H/SOUL.md" || fail "Written SOUL.md does not match the draft."
cp "$STARTER_ROOT/SOUL-BUILDER.md" "$H/SOUL-BUILDER.md" 2>/dev/null
echo "SOUL_$WHICH=$CHARS" >> "$LOG_DIR/flags.txt"
ok "$WHICH SOUL.md installed ($CHARS characters). New chats use it; open chats keep the old one."
stage_done
