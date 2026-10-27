#!/usr/bin/env bash
# Copy the addon's code files from this repo's working tree into the live
# Windower install, so changes can be tried in the game without a release.
#
# Run from WSL (this machine dual-boots into Windows for FFXI; the repo is
# worked on from WSL2 against the Windows D: drive). Usage:
#   ./scripts/deploy-to-windower.sh
# Override the destination if Windower ever moves:
#   WINDOWER_ADDONS_DIR="/mnt/d/some/other/path/addons" ./scripts/deploy-to-windower.sh

set -euo pipefail

DEFAULT_ADDONS_DIR="/mnt/d/Program Files (x86)/Windower4/addons"
ADDONS_DIR="${WINDOWER_ADDONS_DIR:-$DEFAULT_ADDONS_DIR}"
DST="$ADDONS_DIR/abilities_cooldown"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/../abilities_cooldown"

if [ ! -d "$DST" ]; then
    echo "error: addon folder not found at: $DST" >&2
    echo "       is Windower installed somewhere else? set WINDOWER_ADDONS_DIR." >&2
    exit 1
fi

# Code only. data/profiles.lua is the player's real, gitignored whitelist and
# data/state.json is saved box positions; neither is ever touched here.
FILES=(
    abilities_cooldown.lua
    ac_config.lua
    ac_resolve.lua
    ac_state.lua
    ac_timers.lua
    ac_view.lua
    data/profiles.example.lua
)

for f in "${FILES[@]}"; do
    cp -v "$SRC/$f" "$DST/$f"
done

echo
echo "Deployed. In game: //lua reload abilities_cooldown"
