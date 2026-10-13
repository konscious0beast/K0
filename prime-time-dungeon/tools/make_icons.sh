#!/usr/bin/env bash
# Regenerates the export launcher icons in game/art/icons/ from game/icon.svg (02_TECH §12.3).
# Usage: GODOT=<godot 4.7 binary> tools/make_icons.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME="$HERE/../game"
GODOT="${GODOT:-godot}"
WORK="$(mktemp -d -t ptd-icons-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$GAME/." "$WORK/"
rm -rf "$WORK/.godot"
timeout 300 "$GODOT" --headless --path "$WORK" --import >/dev/null 2>&1
mkdir -p "$GAME/art/icons"
timeout 120 "$GODOT" --headless --path "$WORK" -s res://tests/tools/make_icons.gd -- --out="$(cd "$GAME/art/icons" && pwd)" \
  2>&1 | grep -E '^ICON:|Assertion failed'
exit "${PIPESTATUS[0]}"
