#!/bin/bash
# Release guard: every download link and folder name the agent sees must match STARTER_VERSION.
# Run before tagging; make-zip.sh runs it too. Exit 1 lists any stale reference.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$(tr -d '\r' < "$ROOT/VERSIONS.lock" | sed -n 's/^STARTER_VERSION=//p')"
[ -n "$V" ] || { echo "STARTER_VERSION missing from VERSIONS.lock"; exit 1; }
RC=0
for f in README.md AGENTS.md; do
  [ -f "$ROOT/$f" ] || continue
  # Every tag and folder reference must carry the current version.
  BAD="$(grep -noE 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+|hermes-csg-starter-[0-9]+\.[0-9]+\.[0-9]+|release \*\*v[0-9.]+\*\*|current release: v[0-9.]+' "$ROOT/$f" \
        | grep -vE "v$V|-$V\$|-$V[^0-9]" || true)"
  [ -z "$BAD" ] || { echo "$f has references to another version (want $V):"; echo "$BAD"; RC=1; }
  grep -q "codeload.github.com/MichaelStrange-CSG/hermes-csg-starter/tar.gz/refs/tags/v$V" "$ROOT/$f" || { echo "$f has no download link for v$V"; RC=1; }
done
[ $RC -eq 0 ] && echo "OK: README/AGENTS download links match v$V"
exit $RC
