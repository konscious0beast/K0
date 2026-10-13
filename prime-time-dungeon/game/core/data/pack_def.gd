class_name PackDef extends RefCounted
## One content pack as PackLoader.read found it (11 §3.2–§3.3, 11-P1): the fields of its pack.json, its data overlays
## and its art.json — raw (parsed JSON), never changed after reading. Pure RefCounted: no autoloads, no SceneTree.
## Reading never prints; every problem stays in `errors` ("pack[<id>]…: <message>", 11 §3.4). A pack is only data
## (O-2): no scripts, scenes, shaders or binary files. A new pack.json block (e.g. 12 §7.2 "drehbuch", CR-48) comes as a
## key of PackLoader.MANIFEST_KEYS plus a field here — unknown keys are errors until then.

var id: String = ""                       # = the folder name, ^[a-z][a-z0-9_]{2,23}$, never "base"
var root: String = ""                     # the pack folder (res://packs/<id>; tests read from user://)
var pack_schema: int = 0                  # pack.json → pack_schema (PackLoader.PACK_SCHEMA; else compat → pack_engine)
var name: String = ""                     # display name (window title, credits) in source_lang
var version: String = ""                  # SemVer MAJOR.MINOR.PATCH (run-log header, save block)
var engine: Dictionary = {}               # {"min", "max" (may end in ".*"), "commit" ("" or 40 hex)}
var source_lang: String = "de"            # the language of the overlay texts (11 §3.6)
var languages: PackedStringArray = []     # the languages of the build (each but source_lang has locale/<lang>.po)
var default_lang: String = "de"
var licence: Dictionary = {}              # {} = "licence": null (own content); else holder, contract, scope, …
var touches: Dictionary = {}              # table → {"patch": [fields], "add", "disable", "sub": {…}, "top": [keys]}
var art_file: String = ""                 # "art.json" or ""
var tone_exceptions: Array = []           # [{"ref", "list", "reason"}] reviewed false alarms (11 §3.5, F-7)
var manifest: Dictionary = {}             # pack.json as parsed
var overlays: Dictionary = {}             # table (or "rt_balance") → parsed data/<table>.json
var art: Dictionary = {}                  # art.json as parsed ({} without one)
var files: PackedStringArray = []         # every file of the folder (relative paths, sorted)
var pack_hash: String = ""                # PackLoader.content_hash: SHA-256 over pack.json + data/*.json (11 §3.9)
var errors: PackedStringArray = []


func is_valid() -> bool:
	return errors.is_empty()


## A pack with a licence block (11 §3.3): its own texts are exempt from the IP-distance word lists (11 §3.12 layer 2).
func has_licence() -> bool:
	return not licence.is_empty()


## The save block "pack" (11 §3.9): {"id", "version", "hash"}.
func record() -> Dictionary:
	return {"id": id, "version": version, "hash": pack_hash}
