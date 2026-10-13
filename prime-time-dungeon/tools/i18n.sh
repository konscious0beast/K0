#!/usr/bin/env bash
# The language tools (docs/11 §1.11, SP-8): the msgid extractor (GDScript, headless) and GNU gettext for merge and
# format checks. Godot runs in an isolated temp copy of the project (like check.sh); only `extract` and `merge` write
# into the repository (game/locale/pot/*.pot and game/locale/<lang>/*.po).
#
# Usage:
#   tools/i18n.sh extract                  # game/locale/pot/{ui,data,mod_lines,stempel}.pot + the report (dynamic
#                                          # calls, msgids in several domains or contexts)
#   tools/i18n.sh merge [--lang=en]        # msgmerge each PO with its POT: new entries empty, changed ones "fuzzy",
#                                          # gone ones "#~" (a missing PO is created with msginit)
#   tools/i18n.sh stats [--lang=en] [--pack=<dir>]
#                                          # coverage per domain and context (translated / fuzzy / empty, words open);
#                                          # with a pack folder: the base msgids that still name what it renamed (§3.6)
#   tools/i18n.sh lint [--file=res://<script>]
#                                          # German literals outside Tx per file (test_11_literals) and the PENDING
#                                          # table to paste; with --file the lines of that script
#   tools/i18n.sh check [--lang=en] [--no-gettext]
#                                          # msgfmt --check-format --check-header, the rules of test_11_po_rules
#                                          # (placeholders, lengths, digits, glyphs), POT current (extract without a
#                                          # diff), PO merged with its POT; the same for every pack PO
#                                          # (game/packs/<id>/locale/<lang>.po, 11 §3.6); --no-gettext: without msgfmt
#
# Env: GODOT=<path to godot 4.7 binary> (default: "godot" on PATH). GNU gettext (msgmerge, msgfmt, msginit) for merge
# and check: apt-get install gettext.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$HERE/../game" && pwd)"
GODOT="${GODOT:-godot}"
DOMAINS=(ui data mod_lines stempel)
TOOL="res://tests/tools/i18n/i18n_tool.gd"

CMD="${1:-}"
[ $# -gt 0 ] && shift
LANG_CODE="en"
PACK=""
FILE_ARG=()
GETTEXT=1
for a in "$@"; do
  case "$a" in
    --lang=*) LANG_CODE="${a#--lang=}" ;;
    --pack=*) PACK="$(cd "${a#--pack=}" && pwd)" || { echo "i18n.sh: no folder ${a#--pack=}" >&2; exit 2; } ;;
    --no-gettext) GETTEXT=0 ;;
    --file=*) FILE_ARG=("$a") ;;
    *) echo "i18n.sh: unknown argument $a" >&2; exit 2 ;;
  esac
done

need_gettext() {
  for t in "$@"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      echo "i18n.sh: GNU gettext ($t) not found — apt-get install gettext" >&2
      exit 2
    fi
  done
}

WORK=""
UDIR=""
cleanup() { [ -n "$WORK" ] && rm -rf "$WORK"; [ -n "$UDIR" ] && rm -rf "$UDIR"; }
trap cleanup EXIT

# Import a temp copy once (class cache for the tool scripts); isolated user:// like check.sh.
prepare_godot() {
  if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "i18n.sh: Godot binary not found (set GODOT=/path/to/godot)" >&2
    exit 2
  fi
  WORK="$(mktemp -d -t ptd-i18n-XXXXXX)"
  UDIR="$(mktemp -d -t ptd-user-XXXXXX)"
  export XDG_DATA_HOME="$UDIR/data" XDG_CONFIG_HOME="$UDIR/config" XDG_CACHE_HOME="$UDIR/cache"
  mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
  cp -r "$SRC/." "$WORK/"
  rm -rf "$WORK/.godot"
  timeout 600 "$GODOT" --headless --path "$WORK" --import >/dev/null 2>&1 || { echo "i18n.sh: import failed"; exit 1; }
}

# run_tool <command> [options]: the GDScript side; prints its I18N lines, returns its exit code.
run_tool() {
  local out code
  out="$(timeout 900 "$GODOT" --headless --path "$WORK" -s "$TOOL" -- "$@" 2>&1)"
  code=$?
  echo "$out" | grep -E '^I18N:|i18n_tool:|SCRIPT ERROR|Parse Error|ERROR:' | sed 's/^I18N: //'
  if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Compile Error'; then return 1; fi
  return $code
}

merge_lang() {
  need_gettext msgmerge msginit
  local status=0
  mkdir -p "$SRC/locale/$LANG_CODE"
  for d in "${DOMAINS[@]}"; do
    local pot="$SRC/locale/pot/$d.pot" po="$SRC/locale/$LANG_CODE/$d.po"
    [ -f "$pot" ] || { echo "i18n.sh: missing $pot — run extract first"; return 1; }
    if [ ! -f "$po" ]; then
      msginit --no-translator --no-wrap --locale="$LANG_CODE" -i "$pot" -o "$po" >/dev/null 2>&1 \
        || { echo "i18n.sh: msginit failed for $po"; status=1; continue; }
    fi
    if msgmerge --quiet --update --backup=none --no-wrap --previous "$po" "$pot"; then
      echo "merged $po"
    else
      echo "i18n.sh: msgmerge failed for $po"; status=1
    fi
  done
  return $status
}

check_lang() {
  local status=0
  if [ $GETTEXT -eq 1 ]; then
    need_gettext msgfmt
    for d in "${DOMAINS[@]}"; do
      local po="$SRC/locale/$LANG_CODE/$d.po" out
      out="$(msgfmt --check-format --check-header -o /dev/null "$po" 2>&1)"
      if [ $? -ne 0 ]; then
        echo "$out"; echo "i18n.sh: msgfmt --check $po FAILED"; status=1
      else
        echo "msgfmt --check-format --check-header $po: ok"
      fi
    done
    for po in "$SRC"/packs/*/locale/*.po; do        # the content packs' PO files (11 §3.6)
      [ -f "$po" ] || continue
      local out
      out="$(msgfmt --check-format --check-header -o /dev/null "$po" 2>&1)"
      if [ $? -ne 0 ]; then
        echo "$out"; echo "i18n.sh: msgfmt --check $po FAILED"; status=1
      else
        echo "msgfmt --check-format --check-header $po: ok"
      fi
    done
  else
    echo "i18n.sh: WARNING — without GNU gettext: msgfmt's format and header checks skipped"
  fi
  run_tool rules "--lang=$LANG_CODE" || status=1
  run_tool pack-rules || status=1
  run_tool check-pot || status=1
  run_tool sync "--lang=$LANG_CODE" || status=1
  return $status
}

status=0
case "$CMD" in
  extract)
    prepare_godot
    run_tool extract "--out=$SRC/locale/pot" || status=1
    ;;
  merge)
    merge_lang || status=1
    ;;
  stats)
    prepare_godot
    if [ -n "$PACK" ]; then run_tool stats "--lang=$LANG_CODE" "--pack=$PACK" || status=1
    else run_tool stats "--lang=$LANG_CODE" || status=1; fi
    ;;
  check)
    prepare_godot
    check_lang || status=1
    ;;
  lint)
    prepare_godot
    run_tool lint "${FILE_ARG[@]}" || status=1
    ;;
  *)
    sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac

if [ $status -eq 0 ]; then echo "i18n.sh: OK"; else echo "i18n.sh: FAILED"; fi
exit $status
