#!/usr/bin/env bash
# Build the release zip players download: the abilities_cooldown folder as
# committed at a git ref, so a player's own data/profiles.lua and
# data/state.json (gitignored) can never end up in it. The version comes from
# _addon.version at that ref.
#
# Usage:
#   ./scripts/make-release-zip.sh            # zip of HEAD
#   ./scripts/make-release-zip.sh v0.2.0     # zip of a tag or commit
# Writes dist/abilities_cooldown-<version>.zip and prints its path.

set -euo pipefail

REF="${1:-HEAD}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

VERSION="$(git show "$REF:abilities_cooldown/abilities_cooldown.lua" \
    | sed -n "s/^_addon.version *= *'\([^']*\)'.*/\1/p")"
if [ -z "$VERSION" ]; then
    echo "error: no _addon.version found in abilities_cooldown.lua at $REF" >&2
    exit 1
fi

mkdir -p dist
OUT="dist/abilities_cooldown-$VERSION.zip"
git archive --format=zip -o "$OUT" "$REF" abilities_cooldown
echo "$OUT"
