#!/usr/bin/env bash
# Plays Floor 1 end to end with the full-run bot (02_TECH §11.4.1) in an isolated temp copy of the project:
# import, then `godot --headless --fixed-fps 60 -- --autoplay=full [--strategy=…] [--seed=…]` (every frame advances
# 1/60 s × FullRun TIME_SCALE of game time, independent of the wall clock). A run passes when it prints
# "FULLRUN: OK …", exits 0 and logs no error line (same ERR_RE as check.sh).
#
# Usage:
#   tools/fullrun.sh [--strategy=thorough|rush|dawdle|typical|all] [--hero=kai|mopsula] [--seed=<int>]
#                    [--pace=fast|human] [--liga=0|1|2] [--log-dir=<dir>]
#     thorough (default)  every group, chest, event and room; bosses; stairs → summary → credits
#     rush                safe rooms, gates and bosses only (under-levelled)
#     dawdle              idles after the first save until the floor collapses → Sendeschluss → load → finishes
#     typical             thorough without the side groups a4/b3/c2 and without stray hunting (GDD §13 player)
#     all                 thorough, rush and dawdle as Kai plus thorough as Graf Mopsula after one import (CI)
#   --hero=mopsula        the run controls Graf Mopsula (06 §1: bark instead of the field strike, safe-room switch)
#   --pace=human          human-pace model (02_TECH §11.4.1: looks around, decides, reads) for the GDD §13 floor time
#   --liga=1|2            06-C Unterhosen-Liga strategy: the controlled hero (1) / both (2) never wear armor or an
#                         accessory (06 §4.3; the run must win at least one battle in the Liga)
#
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../game"
GODOT="${GODOT:-godot}"
QUIT_AFTER=95000          # frames; safety net behind the bot's own watchdog (FullRun WATCHDOG_FRAMES 90000)
STRATEGIES=(thorough)
HERO="kai"
ALL=0
SEED_ARG=()
PACE_ARG=()
LIGA_ARG=()
LOG_DIR=""
for a in "$@"; do
  case "$a" in
    --strategy=all) STRATEGIES=(thorough rush dawdle); ALL=1 ;;
    --strategy=thorough|--strategy=rush|--strategy=dawdle|--strategy=typical) STRATEGIES=("${a#--strategy=}") ;;
    --hero=kai|--hero=mopsula) HERO="${a#--hero=}" ;;
    --seed=*) SEED_ARG=("$a") ;;
    --pace=fast|--pace=human) PACE_ARG=("$a") ;;
    --liga=0|--liga=1|--liga=2) LIGA_ARG=("$a") ;;
    --log-dir=*) LOG_DIR="${a#--log-dir=}" ;;
    *) echo "fullrun.sh: unknown argument $a" >&2; exit 2 ;;
  esac
done

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "fullrun.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
  exit 2
fi

WORK="$(mktemp -d -t ptd-fullrun-XXXXXX)"
# Isolated user:// (XDG data/config) per run: parallel runs (worktrees, CI shards) never share saves/settings.
UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
export XDG_DATA_HOME="$UDIR/data" XDG_CONFIG_HOME="$UDIR/config" XDG_CACHE_HOME="$UDIR/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
trap 'rm -rf "$WORK" "$UDIR"' EXIT
cp -r "$SRC/." "$WORK/"
rm -rf "$WORK/.godot"

ERR_RE='(SCRIPT ERROR|Parse Error|Compile Error|Failed to load script|Invalid call|Invalid access|Invalid get index|Invalid set index|Cannot call method|Nonexistent function|ERROR: .*(res://|GDScript|Shader|shader)|SHADER ERROR|Identifier .* not declared|Assertion failed)'

filter_noise() {
  grep -vE '^ALSA lib|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server.cpp|init_output_device|^\s+at: (init_output_device|initialize) ' || true
}

echo "== import =="
out="$(timeout 300 "$GODOT" --headless --path "$WORK" --import 2>&1 | filter_noise)"
if echo "$out" | grep -qE "$ERR_RE"; then
  echo "$out" | tail -n 40
  echo "fullrun.sh: IMPORT FAILED"; exit 1
fi

# Runs as "<strategy>:<hero>"; --strategy=all adds the Graf Mopsula run (06 package A) to the Kai runs.
RUNS=()
for st in "${STRATEGIES[@]}"; do RUNS+=("$st:$HERO"); done
if [ $ALL -eq 1 ] && [ "$HERO" = "kai" ]; then RUNS+=("thorough:mopsula"); fi

status=0
for run in "${RUNS[@]}"; do
  st="${run%%:*}"
  hero="${run##*:}"
  echo "== full run: strategy $st hero $hero ${SEED_ARG[*]:-} ${PACE_ARG[*]:-} ${LIGA_ARG[*]:-} (Floor 1, headless, fixed 60 fps) =="
  start=$(date +%s)
  out="$(timeout 900 "$GODOT" --headless --path "$WORK" --fixed-fps 60 --quit-after "$QUIT_AFTER" \
        -- --autoplay=full "--strategy=$st" "--hero=$hero" "${SEED_ARG[@]}" "${PACE_ARG[@]}" "${LIGA_ARG[@]}" \
        2>&1 | filter_noise)"
  code=${PIPESTATUS[0]}
  end=$(date +%s)
  log_name="fullrun_$st"
  [ "$hero" != "kai" ] && log_name="fullrun_${st}_$hero"
  [ ${#LIGA_ARG[@]} -gt 0 ] && log_name="${log_name}_liga${LIGA_ARG[0]#--liga=}"
  if [ -n "$LOG_DIR" ]; then mkdir -p "$LOG_DIR" && printf '%s\n' "$out" > "$LOG_DIR/$log_name.log"; fi
  echo "$out" | grep -E '^FULLRUN: (\[|stats|OK)|Assertion failed|SCRIPT ERROR|ERROR:' | grep -v '^FULLRUN: \[[0-9]*\]   hype' \
    | tail -n 120
  echo "wall time: $((end - start)) s"
  ok=1
  if [ "$code" -ne 0 ]; then echo "fullrun.sh: $run exit code $code"; ok=0; fi
  if echo "$out" | grep -qE "$ERR_RE"; then echo "fullrun.sh: $run has error lines"; ok=0; fi
  if ! echo "$out" | grep -qE '^FULLRUN: OK '; then echo "fullrun.sh: $run printed no 'FULLRUN: OK' line"; ok=0; fi
  [ $ok -eq 1 ] || status=1
done

if [ $status -eq 0 ]; then echo "fullrun.sh: OK"; else echo "fullrun.sh: FAILED"; fi
exit $status
