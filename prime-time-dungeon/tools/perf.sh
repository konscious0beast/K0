#!/usr/bin/env bash
# Performance probe (02_TECH §12.5, docs/PERFORMANCE.md): renders floor 1 / battles / safe rooms under Xvfb and prints
# the §12.1 budget table (draw calls, primitives, lights, materials, memory, build times) plus the Router leak loop.
#
# Usage:
#   tools/perf.sh [--driver=opengl3|vulkan] [--res=1280x720] [--quality=high|low] [--only=startup,explore,battle,safe_room,leak]
#                 [--cycles=20] [--out=<file.md>] [--shots=<dir>] [--headless]
#   --driver=opengl3 (default) = gl_compatibility like CI screenshots; --driver=vulkan = Mobile renderer (needs a Vulkan
#   ICD, e.g. Mesa lavapipe: apt install mesa-vulkan-drivers). --headless: timing + leak loop only (no render metrics).
#   --shots=<dir>: saves the frame with the most draw calls of every table row as PNG.
#
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH). Exit code 1 = over budget or leak growth.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"
DRIVER="opengl3"
RES="1280x720"
HEADLESS=0
PASS=()
for a in "$@"; do
  case "$a" in
    --driver=*) DRIVER="${a#--driver=}" ;;
    --res=*) RES="${a#--res=}" ;;
    --headless) HEADLESS=1 ;;
    --out=*) out="${a#--out=}"; PASS+=("--out=$(cd "$(dirname "$out")" && pwd)/$(basename "$out")") ;;
    --shots=*) sd="${a#--shots=}"; mkdir -p "$sd"; PASS+=("--shots=$(cd "$sd" && pwd)") ;;
    *) PASS+=("$a") ;;
  esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "perf.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-perf-XXXXXX)"
# Isolated user:// (XDG data/config) per run: parallel runs (worktrees, CI shards) never share saves/settings.
UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
export XDG_DATA_HOME="$UDIR/data" XDG_CONFIG_HOME="$UDIR/config" XDG_CACHE_HOME="$UDIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
trap 'rm -rf "$WORK" "$UDIR"' EXIT
cp -r "$SRC/." "$WORK/"
rm -rf "$WORK/.godot"

NOISE='^ALSA lib|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server.cpp|init_output_device|^\s+at: (init_output_device|initialize) '
echo "== import =="
timeout 300 "$GODOT" --headless --path "$WORK" --import >/dev/null 2>&1 || { echo "perf.sh: import failed"; exit 1; }

METHOD="gl_compatibility"
[ "$DRIVER" = "vulkan" ] && METHOD="mobile"
run_godot() {   # run_godot <timeout> <args…>: headless or under Xvfb with the chosen driver
  local t="$1"; shift
  if [ "$HEADLESS" -eq 1 ]; then
    timeout "$t" "$GODOT" --headless --path "$WORK" "$@"
  else
    timeout "$t" xvfb-run -a -s "-screen 0 ${RES}x24" "$GODOT" --path "$WORK" --rendering-driver "$DRIVER" \
      --rendering-method "$METHOD" --resolution "$RES" "$@"
  fi
}

echo "== boot timer (real main scene, driver $DRIVER) =="
BOOT_LINE="$(run_godot 300 -s res://tests/perf/boot_timer.gd 2>&1 | grep -E '^BOOT:' | tail -n 1)"
echo "${BOOT_LINE:-BOOT: (failed)}"

echo "== perf probe (driver $DRIVER, $RES) =="
run_godot 2400 -s res://tests/perf/perf_probe.gd -- "--boot=$BOOT_LINE" "${PASS[@]}" 2>&1 | grep -vE "$NOISE"
code=${PIPESTATUS[0]}
echo "perf.sh: exit $code"
exit "$code"
