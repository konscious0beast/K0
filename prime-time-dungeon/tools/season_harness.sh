#!/usr/bin/env bash
# Staffel-Harness (09 §11.6, ST1-I): plays whole seasons headless in the core — RunSim with the season rules, the core
# bot of tests/tools/season_harness.gd (the goals of tests/tools/season_planner.gd, real RtSim combats with the
# RtBotPlayer `typical`), the cast model (CastSim) and the sleepers (SleepResolver) — in time lapse: the sessions of a
# play profile (tests/tools/season_profiles.gd), logout, absence and login, or Am Stück every floor's countdown. Prints
# one line per season run, the summary per series (per floor: minutes, Pflichtweg / vollständig, levels against the
# band, bosses, defeats, rescues, credits) and "HARNESS-BAND: ok|OUT|info" verdicts against the ST1-Gate bands of
# 09 §11.6 scaled to format 6 (09 Kap. 11.3, decisions I-1 …). Deterministic per seed (seed n = run seed n).
#
# Usage:
#   tools/season_harness.sh [--format=6] [--tempo=calendar|binge] [--profile=typical|20min|weekend|away2w|all]
#                           [--mode=net|no_net|both] [--strategy=auto|thorough|typical|rush] [--pace=human|fast]
#                           [--fighter=bot|autopilot] [--seeds=10] [--first-seed=0] [--jobs=1] [--speed=dev|<n>]
#                           [--time=<key>:<sec>,…] [--out=<file.json>] [--runs] [--strict-bands]
#   tools/season_harness.sh --gate [--seeds=20] [--jobs=…]   # the ST1 gate scaled to format 6: calendar, all four
#                                                            # profiles, Mit Netz and Ohne Netz
#   --format=12|18        refused (exit 3) until the floors 7–18 exist (ST1-C2; 09 decision I-2)
#   --speed               accepted (the ST1-gate command of 09 §11.6 names it); the time lapse is the profile's sessions
#   --jobs=N              N processes over the seeds (the summary merges them; a shared machine: keep N small)
#   --time                overrides of the time model (season_harness.gd TIME, calibration against tools/fullrun.sh)
#   --strict-bands        exit 1 when a verdict is OUT (default: the verdicts are measurements, exit 0)
# Exit: 0 ok; 1 script errors, a run with errors of the core bot, or --strict-bands with OUT verdicts; 2 bad
# arguments or no Godot; 3 the format is refused.
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"
JOBS=1
SEEDS=10
FIRST=0
STRICT=0
GATE=0
OUT=""
RUNS=()
PASS=()
for a in "$@"; do
  case "$a" in
    --jobs=[0-9]*) JOBS="${a#--jobs=}" ;;
    --seeds=[0-9]*) SEEDS="${a#--seeds=}" ;;
    --first-seed=[0-9]*) FIRST="${a#--first-seed=}" ;;
    --strict-bands) STRICT=1 ;;
    --gate) GATE=1 ;;
    --runs) RUNS=("--runs") ;;
    --out=*) out="${a#--out=}"; OUT="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")" ;;
    --format=[0-9]*|--tempo=calendar|--tempo=binge|--mode=net|--mode=no_net|--mode=both|--pace=human|--pace=fast) PASS+=("$a") ;;
    --profile=typical|--profile=20min|--profile=weekend|--profile=away2w|--profile=all) PASS+=("$a") ;;
    --strategy=auto|--strategy=thorough|--strategy=typical|--strategy=rush) PASS+=("$a") ;;
    --fighter=bot|--fighter=autopilot|--speed=*|--time=*) PASS+=("$a") ;;
    *) echo "season_harness.sh: unknown argument $a" >&2; exit 2 ;;
  esac
done
[ "$GATE" -eq 1 ] && PASS=(--format=6 --tempo=calendar --profile=all --mode=both "${PASS[@]}")
if [ "$JOBS" -lt 1 ] || [ "$SEEDS" -lt 1 ]; then
  echo "season_harness.sh: --jobs and --seeds must be ≥ 1" >&2; exit 2
fi
[ "$JOBS" -gt "$SEEDS" ] && JOBS="$SEEDS"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "season_harness.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-season-XXXXXX)"
UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
LOGS="$(mktemp -d -t ptd-season-logs-XXXXXX)"
export XDG_DATA_HOME="$UDIR/data" XDG_CONFIG_HOME="$UDIR/config" XDG_CACHE_HOME="$UDIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
trap 'rm -rf "$WORK" "$UDIR" "$LOGS"' EXIT
cp -r "$SRC/." "$WORK/"
rm -rf "$WORK/.godot"

ERR_RE='(SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid get index'
ERR_RE+='|Invalid set index|Cannot call method|Nonexistent function|Identifier .* not declared|Assertion failed)'
filter_noise() {
  grep -vE '^ALSA lib|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server.cpp|init_output_device'\
'|^\s+at: (init_output_device|initialize) ' || true
}

echo "== import =="
if timeout 300 "$GODOT" --headless --path "$WORK" --import 2>&1 | filter_noise | grep -qE "$ERR_RE"; then
  echo "season_harness.sh: IMPORT FAILED"; exit 1
fi

# main <name> <args…>: one harness process; its output goes to $LOGS/<name>, its exit code to $LOGS/<name>.code.
main() {
  local name="$1" code
  shift
  timeout 43200 "$GODOT" --headless --path "$WORK" -s res://tests/tools/season_harness_main.gd -- "$@" \
    > "$LOGS/$name.raw" 2>&1
  code=$?
  filter_noise < "$LOGS/$name.raw" > "$LOGS/$name"
  echo "$code" > "$LOGS/$name.code"
}

echo "== season harness: ${PASS[*]:-} --seeds=$SEEDS --first-seed=$FIRST --jobs=$JOBS =="
status=0
O=()
[ -n "$OUT" ] && O=("--out=$OUT")
if [ "$JOBS" -eq 1 ]; then
  main all "${PASS[@]}" "--seeds=$SEEDS" "--first-seed=$FIRST" "${RUNS[@]}" "${O[@]}"
  NAMES=(all)
else
  NAMES=()
  per=$(( (SEEDS + JOBS - 1) / JOBS ))
  k=0
  for (( s=0; s<SEEDS; s+=per )); do
    n=$per; [ $((s + n)) -gt "$SEEDS" ] && n=$((SEEDS - s))
    main "part$k" "${PASS[@]}" "--seeds=$n" "--first-seed=$((FIRST + s))" --part "--out=$LOGS/part$k.json" &
    NAMES+=("part$k")
    k=$((k + 1))
  done
  wait
fi
for n in "${NAMES[@]}"; do
  code="$(cat "$LOGS/$n.code" 2>/dev/null || echo 1)"
  if [ "$code" = "3" ]; then
    grep -E '^HARNESS: refused' "$LOGS/$n" | head -1
    echo "season_harness.sh: REFUSED"; exit 3
  fi
  if [ "$code" = "2" ]; then
    cat "$LOGS/$n"; echo "season_harness.sh: BAD ARGUMENTS"; exit 2
  fi
  grep -E '^HARNESS: (run|  error)' "$LOGS/$n"
  if grep -qE "$ERR_RE" "$LOGS/$n"; then grep -E "$ERR_RE" "$LOGS/$n" | head -5; status=1; fi
  grep -qE '^HARNESS: done' "$LOGS/$n" || status=1
  grep -qE '^HARNESS:   error' "$LOGS/$n" && status=1
done
if [ "$JOBS" -gt 1 ]; then
  parts="$(for n in "${NAMES[@]}"; do printf '%s,' "$LOGS/$n.json"; done)"
  main merged "--merge=${parts%,}" "${RUNS[@]}" "${O[@]}"
  NAMES=(merged)
  if grep -qE "$ERR_RE" "$LOGS/merged" || ! grep -qE '^HARNESS: done' "$LOGS/merged"; then
    cat "$LOGS/merged" | head -20; status=1
  fi
fi
last="$LOGS/${NAMES[0]}"
grep -E '^HARNESS(-BAND)?: (summary|ok|OUT|info|done)' "$last"
if [ "$STRICT" -eq 1 ] && grep -qE '^HARNESS-BAND: OUT' "$last"; then status=1; fi
[ "$status" -eq 0 ] && echo "season_harness.sh: OK" || echo "season_harness.sh: FAILED"
exit "$status"
