class_name PackLoader extends RefCounted
## Content packs (11 §3, 11-P1): which pack a run plays (active_id), reading a pack folder into a PackDef (read), the
## engine check (compat), mixing its overlays into the raw tables before GameData._load (merge, with the provenance
## `owned`), its content hash and the start-up orchestration of DB._init (load_data). Pure: no autoloads, no SceneTree,
## no clock (OS only for active_id's default feature check). Nothing here runs without a pack: the base game loads,
## hashes, records and replays exactly as before.
##
## Overlay order (merge; tables in GameData.TABLES order, independent of the files on disk; 11 §3.4): 1 disable (by
## id; never kai, mopsula, the required boxes or floor_1) → 2 patch (a JSON Merge Patch, RFC 7386, per id in sorted id
## order: objects merge recursively, lists and values are replaced, null deletes the key; the target must exist) →
## 3 add (file order; new ids that follow the table's id pattern, 02_TECH §4.2) → 4 sub (the same three on the lists
## with ids: origins hobbies … plans, professions recipes / materials / nodes, enemies pseudo_units) → 5 top (a merge
## patch on the other top-level keys: party start / exp_table, lootboxes pools / pity, origins canon, cast names) →
## 6 data/rt_balance.json (a merge patch on "values"). Last art.json: a merge patch per party / enemy id on the raw
## "model" (11 §3.7) — validated with all model rules like everything else. Overlays never set "model", and every
## operation must be declared in pack.json → touches. Errors read "pack[<id>].<table>[<entry>].<field>: <message>".

const ROOT: String = "res://packs"
const PACK_SCHEMA: int = 1
const ID_RE: String = "^[a-z][a-z0-9_]{2,23}$"
const OVERLAY_SCHEMA: int = 1
const ART_SCHEMA: int = 1
const RT_BALANCE: String = "rt_balance"
## Debug runs with --pack keep their user data below user://packs/<id>/ (11 §3.8 Nr. 6).
const USER_ROOT: String = "user://packs"
## Codes of a pack that cannot start (11 §3.9); DB.pack_error, the boot error card.
const PACK_AMBIGUOUS: String = "pack_ambiguous"
const PACK_MISSING: String = "pack_missing"
const PACK_ENGINE: String = "pack_engine"
const PACK_INVALID: String = "pack_invalid"
## Allowed file types of a pack folder (11 §3.2, §3.10): data, texts and notes only.
const ALLOWED_EXT: PackedStringArray = ["json", "po", "md", "txt"]
## The languages a pack may name — until 11-L1 brings locale/languages.json (11 §1.9).
const LANGUAGES: PackedStringArray = ["de", "en"]
const MANIFEST_KEYS: PackedStringArray = ["pack_schema", "id", "name", "version", "engine", "source_lang", "languages",
	"default_lang", "licence", "touches", "art", "tone_exceptions"]
const LICENCE_KEYS: PackedStringArray = ["holder", "contract", "scope", "valid_until", "credits", "notice"]
const LICENCE_SCOPES: PackedStringArray = ["pitch", "demo", "release"]
const TOUCH_KEYS: PackedStringArray = ["patch", "add", "disable", "sub", "top"]
const OVERLAY_KEYS: PackedStringArray = ["schema", "disable", "patch", "add", "sub", "top"]
const OPS: PackedStringArray = ["disable", "patch", "add"]
## The lists with ids below the entries of a table (step 4, sub). cast has none: its "names" carry no ids (top).
const SUB_LISTS: Dictionary = {"origins": ["hobbies", "traits", "rivals", "brands", "gags", "greetings", "plans"],
	"professions": ["recipes", "materials", "nodes"], "enemies": ["pseudo_units"]}
## The other top-level keys a pack may patch (step 5, top).
const TOP_KEYS: Dictionary = {"party": ["start", "exp_table"], "lootboxes": ["pools", "pity"], "origins": ["canon"],
	"cast": ["names"]}
## The keys of an art.json model patch (11 §3.7).
const ART_KEYS: PackedStringArray = ["base", "props", "colors", "scale", "pose", "style", "gltf"]
const NAME_MAX: int = 40


# ======================================================================================================================
# Activation (11 §3.8)
# ======================================================================================================================

## Which pack this run plays (O-4): {"id": "" | <id>, "error": "" | "pack_ambiguous" | "pack_missing", "via": "" |
## "feature" | "arg", "ids": PackedStringArray (every pack asked for), "note": String (a warning for the log)}. Feature
## tags first: every folder of `root` whose tag pack_<id> the build carries (`features`: `func(tag: String) -> bool`,
## default OS.has_feature — tests simulate an export tag with it); --pack=<id> of the user args counts in debug builds
## only (`debug` = OS.is_debug_build(); a release build ignores it with a note). Two different packs (two tags, a tag
## and another --pack, two --pack) → pack_ambiguous; --pack without its folder → pack_missing; none → the base game.
static func active_id(user_args: PackedStringArray, debug: bool, root: String = ROOT,
		features: Callable = Callable()) -> Dictionary:
	var out: Dictionary = {"id": "", "error": "", "via": "", "ids": PackedStringArray(), "note": ""}
	var has: Callable = features if features.is_valid() else Callable(OS, "has_feature")
	var tagged: PackedStringArray = []
	for id: String in folders(root):
		if bool(has.call("pack_" + id)):
			tagged.append(id)
	var wanted: PackedStringArray = []
	for a: String in user_args:
		if a.begins_with("--pack=") and not wanted.has(a.trim_prefix("--pack=")):
			wanted.append(a.trim_prefix("--pack="))
	if not debug and not wanted.is_empty():
		out["note"] = "--pack=%s ignored: a release build plays the pack of its feature tag only (11 §3.8)" \
			% ",".join(wanted)
		wanted = PackedStringArray()
	var asked: PackedStringArray = tagged.duplicate()
	for w: String in wanted:
		if not asked.has(w):
			asked.append(w)
	out["ids"] = asked
	if asked.size() > 1:
		out["error"] = PACK_AMBIGUOUS
		return out
	if asked.is_empty():
		return out
	var id: String = asked[0]
	if tagged.has(id):
		out["id"] = id
		out["via"] = "feature"
	elif is_valid_id(id) and DirAccess.dir_exists_absolute(root.path_join(id)):
		out["id"] = id
		out["via"] = "arg"
	else:
		out["error"] = PACK_MISSING
	return out


## The folders below `root` (sorted, hidden ones left out) — the packs a build could activate.
static func folders(root: String = ROOT) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(root):
		return out
	for d: String in DirAccess.get_directories_at(root):
		if not d.begins_with("."):
			out.append(d)
	out.sort()
	return out


## ^[a-z][a-z0-9_]{2,23}$ and not "base" (11 §3.3).
static func is_valid_id(id: String) -> bool:
	return id != "base" and RegEx.create_from_string(ID_RE).search(id) != null


## Save.save_dir of a debug run whose pack came from --pack (11 §3.8 Nr. 6): user://packs/<id>/saves — leaderboards,
## replays, persona, career and the Stempel collection live below the parent of save_dir and follow. "" = keep the
## default (no pack; a pack export activated by its feature tag has a user folder of its own).
static func debug_save_dir(id: String, via: String) -> String:
	if id == "" or via != "arg":
		return ""
	return USER_ROOT.path_join(id).path_join("saves")


# ======================================================================================================================
# Reading (11 §3.3, §3.5 Nr. 1)
# ======================================================================================================================

## Reads the pack folder root/<id>: pack.json (schema), the file list (allowed types and places), the overlays
## data/<table>.json (schema), art.json and the languages (locale/<lang>.po for every language but source_lang). The
## problems stay in PackDef.errors. A pack_schema other than PACK_SCHEMA stops after pack.json (compat → pack_engine).
## PackDef.pack_hash is the content_hash.
static func read(root: String, id: String) -> PackDef:
	var p: PackDef = PackDef.new()
	p.id = id
	p.root = root.path_join(id)
	if not is_valid_id(id):
		_fail(p, "", "invalid pack id (pattern %s, never \"base\")" % ID_RE)
		return p
	if not DirAccess.dir_exists_absolute(p.root):
		_fail(p, "", "no pack folder %s" % p.root)
		return p
	_list_files(p.root, "", p.files)
	p.files.sort()
	p.pack_hash = content_hash(p)
	var raw: Variant = JsonUtil.read_file(p.root.path_join("pack.json"))
	if not (raw is Dictionary):
		var why: String = JsonUtil.last_error() if raw == null else "must be a JSON object"
		_fail(p, "pack.json", why)
		return p
	p.manifest = raw
	if not JsonUtil.is_integral(p.manifest.get("pack_schema", null)):
		_fail(p, "pack.json.pack_schema", "missing or not an integer (this engine reads %d)" % PACK_SCHEMA)
		return p
	p.pack_schema = int(p.manifest["pack_schema"])
	if p.pack_schema != PACK_SCHEMA:
		return p
	_read_manifest(p)
	_check_files(p)
	_read_overlays(p)
	_read_art(p)
	for lang: String in p.languages:
		if lang != p.source_lang and not p.files.has("locale/%s.po" % lang):
			_fail(p, "pack.json.languages", "'%s' needs locale/%s.po (11 §3.5 Nr. 1)" % [lang, lang])
	return p


## SHA-256 over pack.json and data/*.json of the pack ("<path>:<sha256>", sorted, joined by "|"; 11 §3.9) — never
## art.json or the PO files (presentation). The pack_hash of the records and of the data_hash element.
static func content_hash(pack: PackDef) -> String:
	var parts: PackedStringArray = []
	for f: String in pack.files:
		if f == "pack.json" or _is_overlay_path(f):
			parts.append("%s:%s" % [f, FileAccess.get_sha256(pack.root.path_join(f))])
	parts.sort()
	return "|".join(parts).sha256_text()


## "" or "pack_engine" (11 §3.11): pack_schema must be PACK_SCHEMA and the game version (application/config/version)
## must lie within engine.min … engine.max (max may end in ".*").
static func compat(pack: PackDef, game_version: String) -> String:
	if pack == null:
		return ""
	if pack.pack_schema != PACK_SCHEMA:
		return PACK_ENGINE
	var v: PackedInt32Array = _semver(game_version)
	var lo: PackedInt32Array = _semver(str(pack.engine.get("min", "")))
	if v.is_empty() or lo.is_empty() or _cmp(v, lo) < 0 or not _within_max(v, str(pack.engine.get("max", ""))):
		return PACK_ENGINE
	return ""


## The message of a pack_engine (compat ≠ "").
static func compat_message(pack: PackDef, game_version: String) -> String:
	if pack.pack_schema != PACK_SCHEMA:
		return "pack[%s]: %s — pack_schema %d, this engine reads %d (11 §3.11)" % [pack.id, PACK_ENGINE,
			pack.pack_schema, PACK_SCHEMA]
	return "pack[%s]: %s — game version %s outside engine %s … %s (11 §3.11)" % [pack.id, PACK_ENGINE, game_version,
		str(pack.engine.get("min", "")), str(pack.engine.get("max", ""))]


## Warnings of a licence block at runtime (11 §3.5 Nr. 4): valid_until before `today` ("YYYY-MM-DD"). The export
## refuses such a pack (11-PB); a running build only warns.
static func licence_notes(pack: PackDef, today: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if pack != null and pack.has_licence() and str(pack.licence.get("valid_until", "")) < today:
		out.append("pack[%s].licence.valid_until: %s has passed (11 §3.5 Nr. 4)" % [pack.id,
			str(pack.licence.get("valid_until", ""))])
	return out


# ======================================================================================================================
# Mixing (11 §3.4, §3.5 Nr. 2)
# ======================================================================================================================

## Mixes `pack` into a deep copy of `raw` (GameData.load_dir's file objects: table → {"schema", "entries", …}, plus
## "rt_balance") → {"raw": Dictionary, "owned": Dictionary, "errors": PackedStringArray}. `owned` is the provenance of
## 11 §3.4: per table (sub lists as "<table>.<list>") {"added": [ids], "patched": {id: [field paths]}, "top": [keys]} —
## the field paths a merge patch set ("name", "rt.hp"; a list is one path), art.json's under "model.…".
static func merge(raw: Dictionary, pack: PackDef) -> Dictionary:
	var out: Dictionary = raw.duplicate(true)
	var owned: Dictionary = {}
	var errors: PackedStringArray = []
	if pack == null:
		return {"raw": out, "owned": owned, "errors": errors}
	for t: String in GameData.TABLES:
		if pack.overlays.has(t):
			_merge_table(out, t, pack.overlays[t], pack, owned, errors)
	if pack.overlays.has(RT_BALANCE):
		_merge_rt_balance(out, pack.overlays[RT_BALANCE], pack, owned, errors)
	_merge_art(out, pack, owned, errors)
	return {"raw": out, "owned": owned, "errors": errors}


## The provenance DataValidator.validate passes on (11 §3.5 Nr. 3, §3.12 layer 2): {"pack": id, "licensed": bool,
## "owned": merge → owned, "def": PackDef}; {} without a pack — the base data are checked exactly as before.
static func provenance(pack: PackDef, owned: Dictionary) -> Dictionary:
	if pack == null:
		return {}
	return {"pack": pack.id, "licensed": pack.has_licence(), "owned": owned, "def": pack}


## The field paths of one entry the pack owns: [""] = the whole entry (the pack added it), else the paths its patches
## set; [] = none of the pack's.
static func owned_paths(owned: Dictionary, table: String, id: String) -> PackedStringArray:
	var own: Variant = owned.get(table, null)
	if not (own is Dictionary):
		return PackedStringArray()
	if ((own as Dictionary).get("added", []) as Array).has(id):
		return PackedStringArray([""])
	var paths: Variant = ((own as Dictionary).get("patched", {}) as Dictionary).get(id, null)
	return PackedStringArray(paths as Array) if paths is Array else PackedStringArray()


## Is the field `path` of an entry ("name", "lines[0].text") inside one of `paths` (owned_paths)?
static func covers(paths: PackedStringArray, path: String) -> bool:
	for q: String in paths:
		if q == "" or path == q or path.begins_with(q + ".") or path.begins_with(q + "["):
			return true
	return false


## A JSON Merge Patch (RFC 7386): objects merge recursively, everything else (lists included) replaces, null deletes
## the key. Neither argument is changed (deep copies).
static func merge_patch(target: Variant, patch: Variant) -> Variant:
	if not (patch is Dictionary):
		return (patch as Array).duplicate(true) if patch is Array else patch
	var out: Dictionary = (target as Dictionary).duplicate(true) if target is Dictionary else {}
	var p: Dictionary = patch
	for k: Variant in p.keys():
		if p[k] == null:
			out.erase(k)
		else:
			out[k] = merge_patch(out.get(k, null), p[k])
	return out


## The field paths a merge patch sets (sorted keys; nested objects as "a.b"; a list, a value or null is one path).
static func patch_paths(patch: Dictionary, prefix: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Array = patch.keys()
	keys.sort()
	for k: Variant in keys:
		var v: Variant = patch[k]
		if v is Dictionary and not (v as Dictionary).is_empty():
			out.append_array(patch_paths(v, prefix + str(k) + "."))
		else:
			out.append(prefix + str(k))
	return out


## Ids a pack never disables (11 §3.4): the members the code names (HeroRules.HEROES, DB.LOOK_MEMBER), the required
## boxes (DataValidator.REQUIRED_BOXES) and floor 1.
static func protected_ids(table: String) -> PackedStringArray:
	match table:
		"party":
			return PackedStringArray(["kai", "mopsula"])
		"lootboxes":
			return DataValidator.REQUIRED_BOXES.duplicate()
		"floors":
			return PackedStringArray(["floor_1"])
	return PackedStringArray()


# ======================================================================================================================
# Start-up (DB._init, 11 §3.5 Nr. 5, §3.8 Nr. 3)
# ======================================================================================================================

## The game data of the activation `act` (active_id) → {"data": GameData, "pack": PackDef (null: the base game, or an
## ambiguous / missing pack), "error": "" | pack_ambiguous | pack_missing | pack_engine | pack_invalid, "messages":
## PackedStringArray (why, most important first — the boot card shows five)}. A broken pack never falls back to the
## base data silently: the error is set (DB.ok false; the boot card stays). The data are the pack's wherever a pack
## folder was read; an ambiguous or missing pack loads the base data only so that the autoloads can start.
static func load_data(data_dir: String, act: Dictionary, game_version: String, root: String = ROOT) -> Dictionary:
	var data: GameData = GameData.new()
	var error: String = str(act.get("error", ""))
	var id: String = str(act.get("id", ""))
	var asked: PackedStringArray = JsonUtil.to_str_array(act.get("ids", []))
	var msgs: PackedStringArray = []
	var pack: PackDef = null
	if error == PACK_AMBIGUOUS:
		msgs.append("%s: more than one content pack is activated (%s; 11 §3.8)" % [error, ", ".join(asked)])
	elif error == PACK_MISSING:
		msgs.append("%s: --pack=%s has no pack folder in %s (11 §3.8)" % [error, ", ".join(asked), root])
	if error != "" or id == "":
		data.load_dir(data_dir)
	else:
		pack = read(root, id)
		if compat(pack, game_version) != "":
			error = PACK_ENGINE
			msgs.append(compat_message(pack, game_version))
		data.load_dir(data_dir, pack)
		if not data.errors.is_empty():
			error = PACK_INVALID if error == "" else error
			msgs.append_array(data.errors)
	return {"data": data, "pack": pack, "error": error, "messages": msgs}


## The element of DB.data_hash() for the pack of `data` (11 §3.9): "pack:<id>:<pack_hash>"; "" without a pack.
static func hash_element(data: GameData) -> String:
	if data == null or data.pack_id == "":
		return ""
	return "pack:%s:%s" % [data.pack_id, data.pack_hash]


# ======================================================================================================================
# Internals
# ======================================================================================================================

static func _fail(p: PackDef, where: String, msg: String) -> void:
	p.errors.append("pack[%s]%s: %s" % [p.id, "." + where if where != "" else "", msg])


static func _merr(errors: PackedStringArray, pack: PackDef, where: String, msg: String) -> void:
	errors.append("pack[%s].%s: %s" % [pack.id, where, msg])


static func _list_files(dir: String, rel: String, out: PackedStringArray) -> void:
	for f: String in DirAccess.get_files_at(dir):
		out.append(rel + f)
	for d: String in DirAccess.get_directories_at(dir):
		_list_files(dir.path_join(d), rel + d + "/", out)


## data/<name>.json directly in data/.
static func _is_overlay_path(f: String) -> bool:
	return f.begins_with("data/") and f.count("/") == 1 and f.get_extension() == "json"


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


static func _is_str_array(v: Variant) -> bool:
	if not (v is Array):
		return false
	for e: Variant in (v as Array):
		if not (e is String):
			return false
	return true


## [MAJOR, MINOR, PATCH] or [] if `s` is not "N.N.N".
static func _semver(s: String) -> PackedInt32Array:
	var parts: PackedStringArray = s.split(".")
	var out: PackedInt32Array = []
	if parts.size() != 3:
		return out
	for part: String in parts:
		if part == "" or not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return PackedInt32Array()
		out.append(part.to_int())
	return out


static func _cmp(a: PackedInt32Array, b: PackedInt32Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return -1 if a[i] < b[i] else 1
	return 0


## "N.N.N", "N.N.*" or "N.*".
static func _is_max(s: String) -> bool:
	if not s.ends_with(".*"):
		return not _semver(s).is_empty()
	var pre: PackedStringArray = s.trim_suffix(".*").split(".")
	if pre.size() < 1 or pre.size() > 2:
		return false
	for part: String in pre:
		if part == "" or not part.is_valid_int() or part.begins_with("-") or part.begins_with("+"):
			return false
	return true


static func _within_max(v: PackedInt32Array, max_s: String) -> bool:
	if not _is_max(max_s):
		return false
	if not max_s.ends_with(".*"):
		return _cmp(v, _semver(max_s)) <= 0
	var pre: PackedStringArray = max_s.trim_suffix(".*").split(".")
	for i in pre.size():
		if v[i] != pre[i].to_int():
			return v[i] < pre[i].to_int()
	return true


static func _read_manifest(p: PackDef) -> void:
	var m: Dictionary = p.manifest
	for k: Variant in m.keys():
		if not MANIFEST_KEYS.has(str(k)):
			_fail(p, "pack.json." + str(k), "unknown key")
	if str(m.get("id", "")) != p.id:
		_fail(p, "pack.json.id", "'%s' is not the folder name '%s'" % [str(m.get("id", "")), p.id])
	p.name = str(m.get("name", "")) if m.get("name", null) is String else ""
	if p.name.strip_edges() == "" or p.name.length() > NAME_MAX:
		_fail(p, "pack.json.name", "a display name of 1–%d characters" % NAME_MAX)
	p.version = str(m.get("version", "")) if m.get("version", null) is String else ""
	if _semver(p.version).is_empty():
		_fail(p, "pack.json.version", "'%s' is no SemVer MAJOR.MINOR.PATCH" % p.version)
	var eng: Dictionary = _dict(m.get("engine", null))
	p.engine = eng
	if eng.is_empty():
		_fail(p, "pack.json.engine", "missing ({\"min\", \"max\", \"commit\"})")
	else:
		for k: Variant in eng.keys():
			if not ["min", "max", "commit"].has(str(k)):
				_fail(p, "pack.json.engine." + str(k), "unknown key")
		if _semver(str(eng.get("min", ""))).is_empty():
			_fail(p, "pack.json.engine.min", "'%s' is no version N.N.N" % str(eng.get("min", "")))
		if not _is_max(str(eng.get("max", ""))):
			_fail(p, "pack.json.engine.max", "'%s' is no version N.N.N / N.N.* / N.*" % str(eng.get("max", "")))
		var commit: String = str(eng.get("commit", ""))
		if not (eng.get("commit", "") is String) or (commit != "" and (commit.length() != 40
				or not commit.is_valid_hex_number(false))):
			_fail(p, "pack.json.engine.commit", "\"\" or the 40 hex digits of the public engine commit")
	p.source_lang = str(m.get("source_lang", ""))
	if not LANGUAGES.has(p.source_lang):
		_fail(p, "pack.json.source_lang", "'%s' is none of %s" % [p.source_lang, ", ".join(LANGUAGES)])
	var langs: Variant = m.get("languages", null)
	if not _is_str_array(langs) or (langs as Array).is_empty():
		_fail(p, "pack.json.languages", "a non-empty list of language codes")
	else:
		for l: Variant in (langs as Array):
			if not LANGUAGES.has(str(l)) or p.languages.has(str(l)):
				_fail(p, "pack.json.languages", "'%s' unknown or twice (%s)" % [str(l), ", ".join(LANGUAGES)])
			else:
				p.languages.append(str(l))
		if not p.languages.has(p.source_lang):
			_fail(p, "pack.json.languages", "must contain source_lang '%s'" % p.source_lang)
	p.default_lang = str(m.get("default_lang", ""))
	if not p.languages.has(p.default_lang):
		_fail(p, "pack.json.default_lang", "'%s' is not one of languages" % p.default_lang)
	_read_licence(p, m.get("licence", null))
	_read_touches(p, m.get("touches", null))
	var art: Variant = m.get("art", "")
	if not (art is String) or not ["", "art.json"].has(str(art)):
		_fail(p, "pack.json.art", "\"art.json\" or \"\"")
	else:
		p.art_file = str(art)
	var tex: Variant = m.get("tone_exceptions", [])
	if not (tex is Array):
		_fail(p, "pack.json.tone_exceptions", "must be a list")
		return
	for i in (tex as Array).size():
		var e: Variant = (tex as Array)[i]
		if not (e is Dictionary) or not ((e as Dictionary).get("ref", null) is String) \
				or not ((e as Dictionary).get("list", null) is String) \
				or not ((e as Dictionary).get("reason", null) is String) or (e as Dictionary).size() != 3:
			_fail(p, "pack.json.tone_exceptions[%d]" % i, "{\"ref\": \"<table>:<id>.<field>\", \"list\", \"reason\"}")
		else:
			p.tone_exceptions.append((e as Dictionary).duplicate())


## null = own content; else the block of 11 §3.3 (its content rules: validators/pack.gd).
static func _read_licence(p: PackDef, lic: Variant) -> void:
	if lic == null:
		return
	if not (lic is Dictionary):
		_fail(p, "pack.json.licence", "null or a licence block")
		return
	var d: Dictionary = lic
	for k: Variant in d.keys():
		if not LICENCE_KEYS.has(str(k)):
			_fail(p, "pack.json.licence." + str(k), "unknown key")
	if not (d.get("holder", null) is String) or str(d.get("holder", "")).strip_edges() == "":
		_fail(p, "pack.json.licence.holder", "the rights holder (a text)")
	for k: String in ["contract", "notice"]:
		if d.has(k) and not (d[k] is String):
			_fail(p, "pack.json.licence." + k, "must be a text")
	var scope: Variant = d.get("scope", null)
	if not _is_str_array(scope) or (scope as Array).is_empty():
		_fail(p, "pack.json.licence.scope", "a non-empty list of %s" % ", ".join(LICENCE_SCOPES))
	else:
		for s: Variant in (scope as Array):
			if not LICENCE_SCOPES.has(str(s)):
				_fail(p, "pack.json.licence.scope", "unknown scope '%s'" % str(s))
	var until: String = str(d.get("valid_until", ""))
	if not (d.get("valid_until", null) is String) \
			or RegEx.create_from_string("^[0-9]{4}-[0-9]{2}-[0-9]{2}$").search(until) == null:
		_fail(p, "pack.json.licence.valid_until", "a date YYYY-MM-DD")
	if not _is_str_array(d.get("credits", null)):
		_fail(p, "pack.json.licence.credits", "a list of credit lines")
	p.licence = d.duplicate(true)


static func _read_touches(p: PackDef, raw: Variant) -> void:
	if not (raw is Dictionary):
		_fail(p, "pack.json.touches", "an object: table → the operations the pack uses (11 §3.3)")
		return
	var d: Dictionary = raw
	for t: Variant in d.keys():
		var table: String = str(t)
		var at: String = "pack.json.touches." + table
		if not (GameData.TABLES.has(table) or table == RT_BALANCE):
			_fail(p, at, "no such table (GameData.TABLES or rt_balance)")
			continue
		if not (d[t] is Dictionary):
			_fail(p, at, "must be an object")
			continue
		var op: Dictionary = d[t]
		for k: Variant in op.keys():
			var key: String = str(k)
			var ok: bool = TOUCH_KEYS.has(key) if table != RT_BALANCE else key == "patch"
			if not ok:
				_fail(p, at + "." + key, "unknown operation")
			elif key == "patch" or key == "top":
				if not _is_str_array(op[k]):
					_fail(p, at + "." + key, "a list of field names")
				elif key == "top":
					for name: Variant in (op[k] as Array):
						if not (TOP_KEYS.get(table, []) as Array).has(str(name)):
							_fail(p, at + ".top", "'%s' is no top-level key a pack may patch" % str(name))
			elif key == "add" or key == "disable":
				if not (op[k] is bool):
					_fail(p, at + "." + key, "true or false")
			elif key == "sub":
				_read_sub_touches(p, table, at + ".sub", op[k])
		p.touches[table] = op.duplicate(true)


static func _read_sub_touches(p: PackDef, table: String, at: String, raw: Variant) -> void:
	if not (raw is Dictionary):
		_fail(p, at, "an object: list → operations")
		return
	for list: Variant in (raw as Dictionary).keys():
		if not (SUB_LISTS.get(table, []) as Array).has(str(list)):
			_fail(p, "%s.%s" % [at, str(list)], "no list with ids of %s (%s)" % [table, str(SUB_LISTS.get(table, []))])
			continue
		var op: Variant = (raw as Dictionary)[list]
		if not (op is Dictionary):
			_fail(p, "%s.%s" % [at, str(list)], "must be an object")
			continue
		for k: Variant in (op as Dictionary).keys():
			var v: Variant = (op as Dictionary)[k]
			var bad: bool = (str(k) == "patch" and not _is_str_array(v)) \
				or ((str(k) == "add" or str(k) == "disable") and not (v is bool)) or not OPS.has(str(k))
			if bad:
				_fail(p, "%s.%s.%s" % [at, str(list), str(k)], "patch: a list of field names; add / disable: a bool")


static func _check_files(p: PackDef) -> void:
	for f: String in p.files:
		var at: String = "files[%s]" % f
		var ext: String = f.get_extension()
		if not ALLOWED_EXT.has(ext):
			_fail(p, at, "not allowed in a pack: data, texts and notes only (.json, .po, .md, .txt; 11 §3.10)")
		elif ext == "po" and not f.begins_with("locale/"):
			_fail(p, at, "PO files belong in locale/ (11 §3.2)")
		elif ext == "json" and f != "pack.json" and f != p.art_file and not f.begins_with("locale/"):
			if not _is_overlay_path(f):
				_fail(p, at, "unknown JSON file (pack.json, art.json, data/<table>.json, locale/…; 11 §3.2)")
			elif not (GameData.TABLES.has(f.get_file().get_basename()) or f.get_file().get_basename() == RT_BALANCE):
				_fail(p, at, "no such table: overlays exist for GameData.TABLES and rt_balance only (11 §3.10)")


static func _read_overlays(p: PackDef) -> void:
	for f: String in p.files:
		var t: String = f.get_file().get_basename()
		if not _is_overlay_path(f) or not (GameData.TABLES.has(t) or t == RT_BALANCE):
			continue
		var raw: Variant = JsonUtil.read_file(p.root.path_join(f))
		if not (raw is Dictionary):
			_fail(p, t, "%s (%s)" % [JsonUtil.last_error() if raw == null else "must be a JSON object", f])
			continue
		var before: int = p.errors.size()
		var ov: Dictionary = raw
		if not JsonUtil.is_integral(ov.get("schema", null)) or int(ov["schema"]) != OVERLAY_SCHEMA:
			_fail(p, t + ".schema", "must be %d" % OVERLAY_SCHEMA)
		if t == RT_BALANCE:
			for k: Variant in ov.keys():
				if str(k) != "schema" and str(k) != "values":
					_fail(p, t + "." + str(k), "unknown key ({\"schema\": 1, \"values\": {…}})")
			if not (ov.get("values", null) is Dictionary):
				_fail(p, t + ".values", "must be an object")
		else:
			for k: Variant in ov.keys():
				if not OVERLAY_KEYS.has(str(k)):
					_fail(p, t + "." + str(k), "unknown key (%s)" % ", ".join(OVERLAY_KEYS))
			_check_ops(p, t, ov)
			var sub: Variant = ov.get("sub", {})
			if not (sub is Dictionary):
				_fail(p, t + ".sub", "must be an object: list → {disable, patch, add}")
			else:
				for list: Variant in (sub as Dictionary).keys():
					var at: String = "%s.sub.%s" % [t, str(list)]
					if not (SUB_LISTS.get(t, []) as Array).has(str(list)):
						_fail(p, at, "no list with ids of %s" % t)
					elif not ((sub as Dictionary)[list] is Dictionary):
						_fail(p, at, "must be an object {disable, patch, add}")
					else:
						for k: Variant in ((sub as Dictionary)[list] as Dictionary).keys():
							if not OPS.has(str(k)):
								_fail(p, at + "." + str(k), "unknown operation")
						_check_ops(p, at, (sub as Dictionary)[list])
			var top: Variant = ov.get("top", {})
			if not (top is Dictionary):
				_fail(p, t + ".top", "must be an object")
			else:
				for k: Variant in (top as Dictionary).keys():
					if not (TOP_KEYS.get(t, []) as Array).has(str(k)):
						_fail(p, "%s.top.%s" % [t, str(k)], "no top-level key a pack may patch (%s)"
							% str(TOP_KEYS.get(t, [])))
		if p.errors.size() == before:
			p.overlays[t] = ov


## The shapes of disable / patch / add.
static func _check_ops(p: PackDef, at: String, ops: Dictionary) -> void:
	if ops.has("disable") and not _is_str_array(ops["disable"]):
		_fail(p, at + ".disable", "a list of ids")
	var patch: Variant = ops.get("patch", {})
	if not (patch is Dictionary):
		_fail(p, at + ".patch", "an object: id → merge patch")
	else:
		for id: Variant in (patch as Dictionary).keys():
			if not ((patch as Dictionary)[id] is Dictionary):
				_fail(p, "%s.patch[%s]" % [at, str(id)], "a merge patch is an object")
	var add: Variant = ops.get("add", [])
	if not (add is Array):
		_fail(p, at + ".add", "a list of new entries")
	else:
		for i in (add as Array).size():
			var e: Variant = (add as Array)[i]
			if not (e is Dictionary) or not ((e as Dictionary).get("id", null) is String):
				_fail(p, "%s.add[%d]" % [at, i], "a new entry is an object with an \"id\"")


static func _read_art(p: PackDef) -> void:
	if p.art_file == "":
		return
	if not p.files.has(p.art_file):
		_fail(p, p.art_file, "named in pack.json → art, but missing")
		return
	var raw: Variant = JsonUtil.read_file(p.root.path_join(p.art_file))
	if not (raw is Dictionary):
		_fail(p, p.art_file, JsonUtil.last_error() if raw == null else "must be a JSON object")
		return
	var before: int = p.errors.size()
	var d: Dictionary = raw
	for k: Variant in d.keys():
		if str(k) != "schema" and str(k) != "models":
			_fail(p, "art.%s" % str(k), "unknown key ({\"schema\": 1, \"models\": {…}})")
	if not JsonUtil.is_integral(d.get("schema", null)) or int(d["schema"]) != ART_SCHEMA:
		_fail(p, "art.schema", "must be %d" % ART_SCHEMA)
	var models: Variant = d.get("models", {})
	if not (models is Dictionary):
		_fail(p, "art.models", "an object: party / enemy id → model patch")
	else:
		for id: Variant in (models as Dictionary).keys():
			var mp: Variant = (models as Dictionary)[id]
			if not (mp is Dictionary):
				_fail(p, "art.models[%s]" % str(id), "a model patch is an object")
				continue
			for k: Variant in (mp as Dictionary).keys():
				if not ART_KEYS.has(str(k)):
					_fail(p, "art.models[%s].%s" % [str(id), str(k)], "not an art parameter (%s)" % ", ".join(ART_KEYS))
	if p.errors.size() == before:
		p.art = d


static func _owned_of(owned: Dictionary, key: String) -> Dictionary:
	if not owned.has(key):
		owned[key] = {"added": [], "patched": {}, "top": []}
	return owned[key]


static func _own_patch(own: Dictionary, id: String, paths: PackedStringArray) -> void:
	var patched: Dictionary = own["patched"]
	var list: Array = patched.get(id, [])
	for q: String in paths:
		if not list.has(q):
			list.append(q)
	patched[id] = list


static func _index_of(entries: Array, id: String) -> int:
	for i in entries.size():
		if entries[i] is Dictionary and str((entries[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


static func _merge_table(out: Dictionary, t: String, ov: Dictionary, pack: PackDef, owned: Dictionary,
		errors: PackedStringArray) -> void:
	var file: Variant = out.get(t, null)
	if not (file is Dictionary) or not ((file as Dictionary).get("entries", null) is Array):
		_merr(errors, pack, t, "the base table is missing or has no entries")
		return
	var f: Dictionary = file
	var touch: Dictionary = _dict(pack.touches.get(t, {}))
	_apply_ops(f["entries"], ov, t, t, touch, protected_ids(t), pack, _owned_of(owned, t), errors)
	var sub: Dictionary = _dict(ov.get("sub", {}))
	var sub_touch: Dictionary = _dict(touch.get("sub", {}))
	var lists: Array = sub.keys()
	lists.sort()
	for lv: Variant in lists:
		var list: String = str(lv)
		var entries: Array = _arr(f.get(list, null))
		_apply_ops(entries, sub[lv], "%s.%s" % [t, list], list, _dict(sub_touch.get(list, {})), PackedStringArray(),
			pack, _owned_of(owned, "%s.%s" % [t, list]), errors)
		if f.has(list) or not entries.is_empty():
			f[list] = entries
	var top: Dictionary = _dict(ov.get("top", {}))
	var allowed: Array = _arr(touch.get("top", []))
	var keys: Array = top.keys()
	keys.sort()
	for k: Variant in keys:
		if not allowed.has(str(k)):
			_merr(errors, pack, "%s.%s" % [t, str(k)], "top-level patch not declared in pack.json → touches")
			continue
		f[k] = merge_patch(f.get(k, null), top[k])
		(_owned_of(owned, t)["top"] as Array).append(str(k))


## disable → patch → add on one list of entries (the table's or a sub list).
static func _apply_ops(entries: Array, ops: Dictionary, where: String, kind: String, touch: Dictionary,
		protected: PackedStringArray, pack: PackDef, own: Dictionary, errors: PackedStringArray) -> void:
	var before: Dictionary = {}
	for e: Variant in entries:
		if e is Dictionary:
			before[str((e as Dictionary).get("id", ""))] = true
	var disable: Array = _arr(ops.get("disable", []))
	if not disable.is_empty() and not bool(touch.get("disable", false)):
		_merr(errors, pack, where, "disable not declared in pack.json → touches")
	else:
		for idv: Variant in disable:
			var id: String = str(idv)
			if protected.has(id):
				_merr(errors, pack, "%s[%s]" % [where, id], "a protected id is never disabled (11 §3.4)")
			elif _index_of(entries, id) < 0:
				_merr(errors, pack, "%s[%s]" % [where, id], "disable target does not exist")
			else:
				while _index_of(entries, id) >= 0:
					entries.remove_at(_index_of(entries, id))
	var patch: Dictionary = _dict(ops.get("patch", {}))
	var allowed: Array = _arr(touch.get("patch", []))
	var ids: Array = patch.keys()
	ids.sort()
	for idv: Variant in ids:
		var id: String = str(idv)
		var pv: Dictionary = patch[idv]
		var ok: bool = true
		for k: Variant in pv.keys():
			var at: String = "%s[%s].%s" % [where, id, str(k)]
			if str(k) == "id":
				_merr(errors, pack, at, "the id of an entry is never patched")
				ok = false
			elif str(k) == "model":
				_merr(errors, pack, at, "figures belong in art.json (11 §3.7)")
				ok = false
			elif not allowed.has(str(k)):
				_merr(errors, pack, at, "field not declared in pack.json → touches")
				ok = false
		var i: int = _index_of(entries, id)
		if ok and i < 0:
			_merr(errors, pack, "%s[%s]" % [where, id], "patch target does not exist")
		elif ok:
			entries[i] = merge_patch(entries[i], pv)
			_own_patch(own, id, patch_paths(pv))
	var add: Array = _arr(ops.get("add", []))
	if not add.is_empty() and not bool(touch.get("add", false)):
		_merr(errors, pack, where, "add not declared in pack.json → touches")
		return
	var pattern: String = str(DataValidator.ID_PATTERNS.get(kind, ""))
	var re: RegEx = RegEx.create_from_string(pattern) if pattern != "" else null
	for ev: Variant in add:
		var e: Dictionary = ev
		var id: String = str(e.get("id", ""))
		var at: String = "%s[%s]" % [where, id]
		if e.has("model"):
			_merr(errors, pack, at + ".model", "figures belong in art.json (11 §3.7)")
		elif re != null and re.search(id) == null:
			_merr(errors, pack, at, "a new id follows the pattern %s (02_TECH §4.2)" % pattern)
		elif before.has(id) or _index_of(entries, id) >= 0:
			_merr(errors, pack, at, "the id exists already — use patch")
		else:
			entries.append(e.duplicate(true))
			(own["added"] as Array).append(id)


static func _merge_rt_balance(out: Dictionary, ov: Dictionary, pack: PackDef, owned: Dictionary,
		errors: PackedStringArray) -> void:
	var allowed: Array = _arr(_dict(pack.touches.get(RT_BALANCE, {})).get("patch", []))
	var values: Dictionary = _dict(ov.get("values", {}))
	var keep: Dictionary = {}
	var keys: Array = values.keys()
	keys.sort()
	for k: Variant in keys:
		if allowed.has(str(k)):
			keep[k] = values[k]
		else:
			_merr(errors, pack, "%s.values.%s" % [RT_BALANCE, str(k)], "value not declared in pack.json → touches")
	if keep.is_empty():
		return
	var base: Dictionary = _dict(out.get(RT_BALANCE, null)).duplicate(true)
	if base.is_empty():
		base = {"schema": 1, "values": {}}
	base["values"] = merge_patch(base.get("values", {}), keep)
	out[RT_BALANCE] = base
	_own_patch(_owned_of(owned, RT_BALANCE), "values", patch_paths(keep))


static func _merge_art(out: Dictionary, pack: PackDef, owned: Dictionary, errors: PackedStringArray) -> void:
	var models: Dictionary = _dict(pack.art.get("models", {}))
	var ids: Array = models.keys()
	ids.sort()
	for idv: Variant in ids:
		var id: String = str(idv)
		var done: bool = false
		for t: String in ["party", "enemies"]:
			var entries: Array = _arr(_dict(out.get(t, null)).get("entries", null))
			var i: int = _index_of(entries, id)
			if i < 0:
				continue
			var e: Dictionary = entries[i]
			e["model"] = merge_patch(e.get("model", null), models[idv])
			var paths: PackedStringArray = []
			for q: String in patch_paths(models[idv]):
				paths.append("model." + q)
			_own_patch(_owned_of(owned, t), id, paths)
			done = true
			break
		if not done:
			_merr(errors, pack, "art.models[%s]" % id, "no party member or enemy with this id")
