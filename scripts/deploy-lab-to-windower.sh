#!/usr/bin/env bash
# Copy the ac_lab style lab into the live Windower install. The lab has no
# user data of its own, so the whole folder is copied as is.
#
# Run from WSL, like deploy-to-windower.sh. Usage:
#   ./scripts/deploy-lab-to-windower.sh
# Override the destination if Windower ever moves:
#   WINDOWER_ADDONS_DIR="/mnt/d/some/other/path/addons" ./scripts/deploy-lab-to-windower.sh

set -euo pipefail

DEFAULT_ADDONS_DIR="/mnt/d/Program Files (x86)/Windower4/addons"
ADDONS_DIR="${WINDOWER_ADDONS_DIR:-$DEFAULT_ADDONS_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/../ac_lab"

if [ ! -d "$ADDONS_DIR" ]; then
    echo "error: Windower addons folder not found at: $ADDONS_DIR" >&2
    echo "       is Windower installed somewhere else? set WINDOWER_ADDONS_DIR." >&2
    exit 1
fi

mkdir -p "$ADDONS_DIR/ac_lab/textures"
cp -v "$SRC"/*.lua "$ADDONS_DIR/ac_lab/"
cp -v "$SRC"/textures/*.png "$ADDONS_DIR/ac_lab/textures/"

echo
echo "Deployed. In game: //lua load ac_lab   (or //lua reload ac_lab)"
