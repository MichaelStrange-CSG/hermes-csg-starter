#!/bin/bash
# Maintainer rehearsal: run the whole macOS kit in a throwaway HOME. Never touches the real ~/.hermes.
# The maintainer's Claude login is linked in (read-only use) so model and verify stages make real calls.
# Usage: bash tools/rehearse-mac.sh            (all stages, then cleanup)
#        KEEP=1 bash tools/rehearse-mac.sh     (keep the scratch HOME for inspection)
#        STAGES="00-preflight 10-hermes" bash tools/rehearse-mac.sh
set -u
KIT_SRC="$(cd "$(dirname "$0")/.." && pwd)"
R="$HOME/.hermes/cache/scratch/starter-rehearsal-$$"
mkdir -p "$R/home/.local/bin" "$R/home/Library" "$R/home/Desktop" "$R/tmp"
ln -s "$HOME/Library/Keychains" "$R/home/Library/Keychains"
ln -s "$HOME/.claude" "$R/home/.claude"
[ -e "$HOME/.claude.json" ] && ln -s "$HOME/.claude.json" "$R/home/.claude.json"
CL="$(command -v claude)"; [ -n "$CL" ] && ln -s "$CL" "$R/home/.local/bin/claude"
mkdir -p "$R/home/hermes-csg-starter"
git -C "$KIT_SRC" ls-files -z | (cd "$KIT_SRC" && xargs -0 tar -cf - --) | tar -xf - -C "$R/home/hermes-csg-starter"
KIT="$R/home/hermes-csg-starter"

# Sample SOUL drafts so stage 60 can be exercised.
mkdir -p "$KIT/soul-drafts"
cat > "$KIT/soul-drafts/work-SOUL.md" <<'EOF'
# Identity

You are a calm, precise operator working for Rehearsal User, project lead. The work is branch security and network projects: camera system installs, access control panels, switch and firewall configuration, and the project paperwork that ties them together. You are a sharp project lead who tracks every loose end, not a chatbot performing helpfulness.

You exist to get each project to done on the date promised, and to leave a record someone else can trust.

# Style

- Direct, plain, and specific. Name the system, the setting, the evidence, and the next action.
- Match length to the ask. A status check gets a status.
- Lead with the answer or the action. Context comes after, only if it changes the decision.
- Every project update ends with owner, date, and next step.

# Judgment

- Assume production until told otherwise. Default to careful, auditable, least-surprise changes.
- Separate observed fact, inference, and guess. Say which is which.
- Before sending anything to a customer, committing to a price or date, or changing a schedule: show it and wait for a yes.

# Confidentiality

- Customer and company data is confidential. Keep it in the task.
- This is the Work profile. Personal matters belong to the Home profile.

# Avoid

- Filler, praise, and restating the request.
- Inventing part numbers, versions, or ticket facts you have not verified.
EOF
sed 's/branch security and network projects.*/personal: house projects, family logistics, travel and hobbies./' \
  "$KIT/soul-drafts/work-SOUL.md" > "$KIT/soul-drafts/home-SOUL.md"

STAGES="${STAGES:-00-preflight 05-claude-cli 10-hermes 20-plugin 25-model 30-profiles 40-desktop 50-verify}"
run() {
  env -i HOME="$R/home" USER="$(id -un)" LOGNAME="$(id -un)" SHELL=/bin/zsh TERM=xterm-256color \
      LANG=en_US.UTF-8 TMPDIR="$R/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/bash "$KIT/scripts/mac/$1.sh" "${@:2}"
}
RC=0
for s in $STAGES; do
  echo ">>> $s $(date +%H:%M:%S)"; run "$s"; RC=$?; echo "<<< $s rc=$RC"
  [ $RC -eq 0 ] || break
done
if [ $RC -eq 0 ]; then
  run 60-soul work soul-drafts/work-SOUL.md && run 60-soul home soul-drafts/home-SOUL.md || RC=1
fi
echo "- Maintainer rehearsal run (tools/rehearse-mac.sh)." > "$KIT/logs/installer-notes.md"
run 90-report logs/installer-notes.md
echo; sed -n 1,16p "$KIT/INSTALL-REPORT.md"
if [ "${KEEP:-0}" = 1 ]; then echo "Kept: $R"; else rm -rf "$R"; echo "Cleaned up $R"; fi
exit $RC
