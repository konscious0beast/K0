#!/usr/bin/env bash
# Real-time combat balance harness (07 §11.4, R4): plays the floor-1 encounters on the real RtSim with the bot profiles
# of 07 §5.7 (tests/tools/rt_harness.gd via tests/tools/rt_harness_main.gd) and prints one line per encounter × hero
# × Liga tier × profile: losses with a Wilson 95 % interval, duration and HP loss (median [P10–P90]), potions, KOs,
# interrupted interrupt-worthy casts (person / AI), boss telegraph hits, the bot's GCD use — and "RT-BAND: ok|OUT"
# verdicts against the bands of 07 §11.1 (`typical` only). Seeds are fixed (SeedUtil.derive(4242, "harness", n)) — the
# numbers are reproducible. Exit 1 on script errors; out-of-band verdicts only with --strict-bands (R5b turns that on
# for the nightly once `typical` is calibrated from replays, 07 §11.3).
#
# Usage:
#   tools/rt_balance.sh [--seeds=20] [--first-seed=0] [--hero=kai|mopsula|both] [--liga=0|1|2|all]
#                       [--profile=typical|perfect|sloppy|all] [--encounters=all|regular|bosses|showboss|<id>,…]
#                       [--partner-preset=attack|support|careful] [--set=<kind>:<id>.<path>=<json>] [--out=<file>]
#                       [--strict-bands]
#   tools/rt_balance.sh --sequence [--seeds=20] [--hero=…]   # the floor in order (regeneration, heal items, §11.4)
#   tools/rt_balance.sh --perf                               # µs per RtSim.step with the real data (07 §3.15)
#   tools/rt_balance.sh --nightly [--out=<file.json>]        # CI nightly, 200 seeds: regular × both heroes, show
#                                                            # boss + bosses × both heroes × Liga 0/1/2, bosses
#                                                            # perfect / sloppy, 50 floor sequences (5 processes)
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"
NIGHTLY=0
OUT=""
PASS=()
for a in "$@"; do
  case "$a" in
    --nightly) NIGHTLY=1 ;;
    --out=*) out="${a#--out=}"; OUT="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")" ;;
    *) PASS+=("$a") ;;
  esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "rt_balance.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-rtbal-XXXXXX)"
UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
LOGS="$(mktemp -d -t ptd-rtbal-logs-XXXXXX)"
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
  echo "rt_balance.sh: IMPORT FAILED"; exit 1
fi

# run <name> <harness args…>: prints the RT lines; writes "<name>.status" (0 = ok) into $LOGS. With --out the JSON
# goes to <out> (nightly: <out without .json>-<name>.json).
run() {
  local name="$1" out o=() st=0
  shift
  if [ -n "$OUT" ]; then
    if [ "$NIGHTLY" -eq 1 ]; then o=("--out=${OUT%.json}-$name.json"); else o=("--out=$OUT"); fi
  fi
  out="$(timeout 21600 "$GODOT" --headless --path "$WORK" -s res://tests/tools/rt_harness_main.gd -- "$@" "${o[@]}" \
    2>&1 | filter_noise)"
  echo "$out" | grep -E '^RT(-SEQ|-PERF|-BAND)?: '
  if echo "$out" | grep -qE "$ERR_RE"; then echo "$out" | grep -E "$ERR_RE" | head -5; st=1; fi
  echo "$out" | grep -qE '^RT: done' || st=1
  echo "$out" | grep -qE '^RT: FAILED' && st=1
  echo "$st" > "$LOGS/$name.status"
}

NAMES=()
if [ "$NIGHTLY" -eq 1 ]; then
  NAMES=(regular bosses perfect sloppy sequence)
  run regular --seeds=200 --encounters=regular --hero=both --liga=0 "${PASS[@]}" > "$LOGS/regular" 2>&1 &
  run bosses --seeds=200 --encounters=showboss,bosses --hero=both --liga=all "${PASS[@]}" > "$LOGS/bosses" 2>&1 &
  run perfect --seeds=200 --encounters=bosses --hero=both --profile=perfect "${PASS[@]}" > "$LOGS/perfect" 2>&1 &
  run sloppy --seeds=200 --encounters=bosses --hero=both --profile=sloppy "${PASS[@]}" > "$LOGS/sloppy" 2>&1 &
  run sequence --seeds=50 --sequence --hero=both "${PASS[@]}" > "$LOGS/sequence" 2>&1 &
  wait
else
  NAMES=(main)
  run main "${PASS[@]}" > "$LOGS/main" 2>&1
fi

status=0
for n in "${NAMES[@]}"; do
  [ "$NIGHTLY" -eq 1 ] && echo "== nightly: $n =="
  cat "$LOGS/$n"
  [ "$(cat "$LOGS/$n.status" 2>/dev/null || echo 1)" = "0" ] || status=1
done
[ "$status" -eq 0 ] && echo "rt_balance.sh: OK" || echo "rt_balance.sh: FAILED"
exit "$status"
