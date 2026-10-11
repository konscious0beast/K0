#!/usr/bin/env bash
# Platform matrix (05 Kap. 2 S0 gate; required before every SIM_VERSION bump, 07 §12.2 / 08 §10.2 Nr. 17): the same
# N core bot runs (RunSim, varied seeds, fixed decisions — tests/tools/platform_matrix_bot.gd) on every leg; each run is
# replayed by RunSim.replay and must match its checkpoints; one digest per leg over all final hashes and checkpoint
# hashes. A leg passes when its digest equals the reference leg (Linux x86-64 headless, the later server/verifier).
#
# Legs this script runs on a Linux x86-64 machine:
#   headless   godot --headless (dummy renderer) — the reference
#   opengl3    godot --rendering-driver opengl3 under Xvfb (a real GL context; needs xvfb-run)
# The other legs of 05 Kap. 2 — Windows x64, Linux/Android arm64, macOS/iOS arm64, Web (wasm) — run the same tool on
# their runner or device (`godot --headless --path game -s res://tests/tools/platform_matrix.gd -- --runs=20`) and
# compare the "MATRIX: digest" line with the reference; until then they are an open release gate ("[ausstehend]").
#
# Usage: tools/platform_matrix.sh [--runs=20] [--legs=headless,opengl3]
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"
RUNS=20
LEGS="headless,opengl3"
for a in "$@"; do
  case "$a" in
    --runs=*) RUNS="${a#--runs=}" ;;
    --legs=*) LEGS="${a#--legs=}" ;;
    *) echo "platform_matrix.sh: unknown argument $a" >&2; exit 2 ;;
  esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "platform_matrix.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-matrix-XXXXXX)"
UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
export XDG_DATA_HOME="$UDIR/data" XDG_CONFIG_HOME="$UDIR/config" XDG_CACHE_HOME="$UDIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
trap 'rm -rf "$WORK" "$UDIR"' EXIT
cp -r "$SRC/." "$WORK/"
rm -rf "$WORK/.godot"

ERR_RE='(SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid get index|Invalid set index|Cannot call method|Nonexistent function|Identifier .* not declared|Assertion failed)'
filter_noise() {
  grep -vE '^ALSA lib|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server.cpp|init_output_device|^\s+at: (init_output_device|initialize) ' || true
}

echo "== import =="
if timeout 300 "$GODOT" --headless --path "$WORK" --import 2>&1 | filter_noise | grep -qE "$ERR_RE"; then
  echo "platform_matrix.sh: IMPORT FAILED"; exit 1
fi

status=0
ref=""
IFS=',' read -r -a LEG_LIST <<< "$LEGS"
for leg in "${LEG_LIST[@]}"; do
  echo "== leg $leg ($RUNS runs) =="
  case "$leg" in
    headless)
      out="$(timeout 1800 "$GODOT" --headless --path "$WORK" -s res://tests/tools/platform_matrix.gd -- "--runs=$RUNS" \
        2>&1 | filter_noise)" ;;
    opengl3)
      if ! command -v xvfb-run >/dev/null 2>&1; then
        echo "platform_matrix.sh: leg opengl3 needs xvfb-run"; status=1; continue
      fi
      out="$(timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --path "$WORK" \
        -s res://tests/tools/platform_matrix.gd -- "--runs=$RUNS" 2>&1 | filter_noise)" ;;
    *) echo "platform_matrix.sh: unknown leg $leg"; status=1; continue ;;
  esac
  echo "$out" | grep -E '^MATRIX: ' | tail -n $((RUNS + 1))
  if echo "$out" | grep -qE "$ERR_RE"; then echo "$out" | grep -E "$ERR_RE" | head -5; status=1; fi
  digest="$(echo "$out" | grep -E '^MATRIX: digest ' | awk '{print $3}')"
  if [ -z "$digest" ] || ! echo "$out" | grep -qE '^MATRIX: digest .* replay ok '; then
    echo "platform_matrix.sh: leg $leg FAILED (no digest or a replay did not match)"; status=1; continue
  fi
  if [ -z "$ref" ]; then ref="$digest"
  elif [ "$digest" != "$ref" ]; then echo "platform_matrix.sh: leg $leg digest differs from the reference"; status=1
  fi
done

if [ $status -eq 0 ]; then echo "platform_matrix.sh: OK digest $ref (legs: $LEGS)"; else echo "platform_matrix.sh: FAILED"; fi
exit $status
