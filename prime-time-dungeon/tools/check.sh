#!/usr/bin/env bash
# Verifies the Godot project in an isolated temp copy (safe to run concurrently).
#
# Usage:
#   tools/check.sh                 # import + unit tests + headless smoke run of main scene
#   tools/check.sh --tests-only [--filter=<substr>]
#                                  # import + unit tests (optionally only test files whose name contains <substr>)
#   tools/check.sh --shot <res://scene.tscn> <out.png> [frames] [WxH]
#                                  # render a scene under Xvfb and save a screenshot
#
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "check.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-check-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cp -r "$SRC/." "$WORK/"
rm -rf "$WORK/.godot"

# Lines that indicate real problems in Godot output. Audio driver noise is ignored.
ERR_RE='(SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid get index|Invalid set index|Cannot call method|Nonexistent function|ERROR: .*(res://|GDScript|Shader|shader)|SHADER ERROR|Identifier .* not declared|Assertion failed)'

filter_noise() {
  grep -vE '^ALSA lib|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server.cpp|init_output_device|^\s+at: (init_output_device|initialize) ' || true
}

run_import() {
  echo "== import =="
  local out
  out="$(timeout 300 "$GODOT" --headless --path "$WORK" --import 2>&1 | filter_noise)"
  echo "$out" | tail -n 40
  if echo "$out" | grep -qE "$ERR_RE"; then
    echo "check.sh: IMPORT FAILED (errors above)"; return 1
  fi
}

run_tests() {
  echo "== tests ${TEST_FILTER:+(filter: $TEST_FILTER)} =="
  local out code
  local extra=()
  [ -n "${TEST_FILTER:-}" ] && extra=(-- "--filter=$TEST_FILTER")
  out="$(timeout 600 "$GODOT" --headless --path "$WORK" -s res://tests/run_tests.gd "${extra[@]}" 2>&1 | filter_noise)"
  code=${PIPESTATUS[0]}
  echo "$out"
  if [ "$code" -ne 0 ] || echo "$out" | grep -qE "$ERR_RE"; then
    echo "check.sh: TESTS FAILED (exit $code)"; return 1
  fi
}

run_smoke() {
  echo "== smoke (main scene, headless, 600 frames, autoplay) =="
  local out
  out="$(timeout 300 "$GODOT" --headless --path "$WORK" --quit-after 600 -- --autoplay 2>&1 | filter_noise)"
  echo "$out" | tail -n 60
  if echo "$out" | grep -qE "$ERR_RE"; then
    echo "check.sh: SMOKE FAILED (errors above)"; return 1
  fi
}

run_shot() {
  local scene="$1" out_png="$2" frames="${3:-90}" res="${4:-1280x720}"
  echo "== screenshot $scene -> $out_png =="
  local abs_out
  abs_out="$(cd "$(dirname "$out_png")" && pwd)/$(basename "$out_png")"
  local out
  out="$(timeout 300 xvfb-run -a -s "-screen 0 ${res}x24" "$GODOT" --path "$WORK" \
        --rendering-driver opengl3 --resolution "$res" -s res://tests/capture.gd -- \
        --scene="$scene" --out="$abs_out" --frames="$frames" 2>&1 | filter_noise)"
  echo "$out" | tail -n 40
  if echo "$out" | grep -qE "$ERR_RE"; then
    echo "check.sh: SHOT HAD ERRORS (see above)"; return 1
  fi
  [ -f "$abs_out" ] || { echo "check.sh: no screenshot written"; return 1; }
  echo "saved $abs_out"
}

status=0
case "${1:-}" in
  --tests-only)
    case "${2:-}" in --filter=*) TEST_FILTER="${2#--filter=}" ;; esac
    run_import || status=1
    [ $status -eq 0 ] && { run_tests || status=1; }
    ;;
  --shot)
    shift
    run_import || status=1
    [ $status -eq 0 ] && { run_shot "$@" || status=1; }
    ;;
  *)
    run_import || status=1
    [ $status -eq 0 ] && { run_tests || status=1; }
    [ $status -eq 0 ] && { run_smoke || status=1; }
    ;;
esac

if [ $status -eq 0 ]; then echo "check.sh: OK"; else echo "check.sh: FAILED"; fi
exit $status
