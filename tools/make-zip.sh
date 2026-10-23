#!/bin/bash
# Build dist/hermes-csg-starter-vX.Y.Z.zip from tracked files only (no logs, drafts or reports).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
V="$(tr -d '\r' < "$ROOT/VERSIONS.lock" | sed -n 's/^STARTER_VERSION=//p')"
bash "$ROOT/tools/check-release.sh" || exit 1
[ -z "$(git -C "$ROOT" status --porcelain)" ] || { echo "Working tree not clean; commit first."; exit 1; }
mkdir -p "$ROOT/dist"
OUT="$ROOT/dist/hermes-csg-starter-v$V.zip"
rm -f "$OUT"
git -C "$ROOT" archive --format=zip --prefix=hermes-csg-starter/ -o "$OUT" HEAD
shasum -a 256 "$OUT"
