#!/usr/bin/env bash
# Performance probe (02_TECH §12.5, docs/PERFORMANCE.md): renders floor 1 / real-time combats / safe rooms under Xvfb
# and prints the §12.1 budget table (draw calls, primitives, lights, materials, memory, build times) plus the Router
# leak loop. The CTB battle scene and its "battle" section are gone (R5b part 2b, 07 §12.6).
#
# Usage:
#   tools/perf.sh [--driver=opengl3|vulkan] [--res=1280x720] [--quality=high|low] [--only=startup,explore,safe_room,combat,leak]
#                 [--cycles=20] [--out=<file.md>] [--shots=<dir>] [--headless] [--look=worst]
#   --only=combat (or combat_regular,combat_two_groups,combat_boss_queen): the real-time combat in the world (07 §8.10,
#   R2) with effects — telegraph pool full, zones, hits, extras, the queen's adds — plus a timing pass (exploration vs.
#   combat at the same spot, the CombatDirector's own cost per frame).
#   --driver=opengl3 (default) = gl_compatibility like CI screenshots; --driver=vulkan = Mobile renderer (needs a Vulkan
#   ICD, e.g. Mesa lavapipe: apt install mesa-vulkan-drivers). --headless: timing + leak loop only (no render metrics).
#   --shots=<dir>: saves the frame with the most draw calls of every table row as PNG.
#   --look=worst: every section with a candidate persona in the heaviest look (08 §6.2, K2: Kai ≤ 3 000 tris, 7 meshes).
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

# --- Stempelduell (10, SD2) -------------------------------------------------------------------------------------------
# Scenario "stempel" (10 §6.10): tests/perf/sd_perf_probe.gd — the table against the Stempelmeister with the Durchsage
# on the board in the real GlobalUi: UI draw calls <= 120, 0 3D, rulebook <= 50 ms, table <= 300 ms, move <= 2 ms,
# preview <= 3 ms, no _process while it waits. --only=stempel runs it alone and exits with its code; a full run (no
# --only) starts with it and stops on a failure; --only lists without "stempel" skip it.
SD_ONLY=""
for a in "${PASS[@]}"; do
  case "$a" in --only=*) SD_ONLY="${a#--only=}" ;; esac
done
if [ -z "$SD_ONLY" ] || [[ ",$SD_ONLY," == *",stempel,"* ]]; then
  echo "== stempel (10 §6.10, driver $DRIVER, $RES) =="
  run_godot 600 -s res://tests/perf/sd_perf_probe.gd 2>&1 | grep -vE "$NOISE"
  sd_code=${PIPESTATUS[0]}
  if [ "$SD_ONLY" = "stempel" ] || [ "$sd_code" -ne 0 ]; then
    echo "perf.sh: exit $sd_code"
    exit "$sd_code"
  fi
fi
# --- end Stempelduell ------------------------------------------------------------------------------------------------

echo "== boot timer (real main scene, driver $DRIVER) =="
BOOT_LINE="$(run_godot 300 -s res://tests/perf/boot_timer.gd 2>&1 | grep -E '^BOOT:' | tail -n 1)"
echo "${BOOT_LINE:-BOOT: (failed)}"

echo "== perf probe (driver $DRIVER, $RES) =="
run_godot 2400 -s res://tests/perf/perf_probe.gd -- "--boot=$BOOT_LINE" "${PASS[@]}" 2>&1 | grep -vE "$NOISE"
code=${PIPESTATUS[0]}
echo "perf.sh: exit $code"
exit "$code"
