extends TestCase
## 11-P1 (docs/11 §3.3–§3.5, §3.8, §3.11; Kap. 5.3, 5.10): the content-pack loader. PackLoader.read (pack.json schema,
## files, overlays, art.json, languages), merge (order disable → patch → add → sub → top → rt_balance, then art.json;
## JSON Merge Patch RFC 7386; protected ids; touches; new ids; the provenance "owned"), content_hash, compat
## (pack_schema, engine range), active_id (feature tags simulated — release and debug — and --pack) and load_data (the
## start-up codes of DB._init), plus every signature of the contract pass 11-P1 by reflection. The packs of the error
## cases are written into user:// at run time (tests/fixtures/packs/pack_kit.gd).

const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const R1A := preload("res://tests/test_r1a_contract.gd")
const ROOT: String = "user://test_11_loader"

## script path → signatures of the contract pass 11-P1 (R1a reflection format; "=" marks a default argument).
const METHODS: Dictionary = {
	"res://core/data/game_data.gd": ["load_dir(String=, PackDef=) -> bool", "pack_fields() -> Dictionary",
		"pack_record() -> Dictionary", "load_from_tables(Dictionary, String=) -> bool"],
	"res://core/data/data_validator.gd": ["validate(Dictionary, bool=, Dictionary=, Dictionary=) -> Dictionary"],
	"res://core/data/validators/ip_words.gd": ["check(DataValidator, Dictionary=) -> void static"],
	"res://core/data/validators/pack.gd": ["check(DataValidator, Dictionary) -> void static",
		"pack_texts(PackDef) -> Array[Dictionary] static", "tone_hit(String) -> String static"],
	"res://core/data/pack_loader.gd": [
		"active_id(PackedStringArray, bool, String=, Callable=) -> Dictionary static",
		"read(String, String) -> PackDef static", "compat(PackDef, String) -> String static",
		"merge(Dictionary, PackDef) -> Dictionary static", "content_hash(PackDef) -> String static",
		"load_data(String, Dictionary, String, String=) -> Dictionary static",
		"provenance(PackDef, Dictionary) -> Dictionary static", "owned_paths(Dictionary, String, String) -> "
		+ "PackedStringArray static", "covers(PackedStringArray, String) -> bool static",
		"debug_save_dir(String, String) -> String static", "hash_element(GameData) -> String static"],
	"res://core/data/pack_def.gd": ["is_valid() -> bool", "has_licence() -> bool", "record() -> Dictionary"],
	"res://autoload/db.gd": ["data_hash() -> String", "data_hash_input() -> PackedStringArray"],
	"res://core/progression/save_codec.gd": ["encode(GameState, String, Dictionary=) -> Dictionary static",
		"decode(Dictionary, GameData) -> GameState static", "pack_status(Dictionary, GameData) -> String static",
		"pack_id_of(Dictionary) -> String static"],
	"res://core/live/run_sim.gd": ["version_status(Dictionary, GameData=) -> String static",
		"version_error(Dictionary, GameData=) -> String static",
		"header_errors(Dictionary, EventDef, Dictionary, GameData=) -> PackedStringArray static",
		"pack_status(Dictionary, GameData) -> String static"],
	"res://core/live/leaderboard.gd": ["version_status(Dictionary, GameData=) -> String static"],
}
## PackDef fields → type.
const FIELDS: Dictionary = {"id": "String", "root": "String", "pack_schema": "int", "name": "String",
	"version": "String", "engine": "Dictionary", "source_lang": "String", "languages": "PackedStringArray",
	"default_lang": "String", "licence": "Dictionary", "touches": "Dictionary", "art_file": "String",
	"tone_exceptions": "Array", "manifest": "Dictionary", "overlays": "Dictionary", "art": "Dictionary",
	"files": "PackedStringArray", "pack_hash": "String", "errors": "PackedStringArray"}

var _hex: RegEx = RegEx.create_from_string("^[0-9a-f]{64}$")


func before_each() -> void:
	Kit.rmrf(ROOT)


func after_each() -> void:
	Kit.rmrf(ROOT)


## The errors of a pack "probe" in ROOT whose pack.json is the default manifest patched with `extra`.
func _manifest_errors(extra: Dictionary, overlays: Dictionary = {}, files: Dictionary = {}) -> PackedStringArray:
	return Kit.write_pack(ROOT, "probe", Kit.manifest("probe", {}, extra), overlays, files).errors


func _expect(errors: PackedStringArray, needle: String, what: String) -> void:
	assert_true(Kit.has_error(errors, needle), "%s: expected an error with '%s', got %s" % [what, needle, str(errors)])


func _merge(touches: Dictionary, overlays: Dictionary, files: Dictionary = {}, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = Kit.manifest("probe", touches, extra)
	var p: PackDef = Kit.write_pack(ROOT, "probe", m, overlays, files)
	assert_eq(p.errors, PackedStringArray(), "the probe pack reads clean")
	return PackLoader.merge(Kit.base_raw(), p)


static func _entry(raw: Dictionary, table: String, id: String, list: String = "entries") -> Dictionary:
	for e: Variant in ((raw[table] as Dictionary).get(list, []) as Array):
		if e is Dictionary and str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


static func _ids(raw: Dictionary, table: String, list: String = "entries") -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Variant in ((raw[table] as Dictionary).get(list, []) as Array):
		out.append(str((e as Dictionary).get("id", "")))
	return out


# --- the contract pass 11-P1 -------------------------------------------------------------------------------------------

func test_contract_pass_signatures() -> void:
	for path: String in METHODS.keys():
		var script: GDScript = load(path) as GDScript
		assert_not_null(script, path)
		if script == null:
			continue
		var have: Dictionary = R1A._own_methods(script)
		for want: String in METHODS[path]:
			var name: String = want.substr(0, want.find("("))
			assert_eq(have.get(name, "<missing>"), want, "%s :: %s" % [path.get_file(), name])
	var props: Dictionary = R1A._props(load("res://core/data/pack_def.gd") as GDScript)
	for f: String in FIELDS.keys():
		assert_eq(props.get(f, "<missing>"), FIELDS[f], "PackDef.%s" % f)
	var gd: Dictionary = R1A._props(load("res://core/data/game_data.gd") as GDScript)
	for f: String in ["pack_id", "pack_version", "pack_hash"]:
		assert_eq(gd.get(f, "<missing>"), "String", "GameData.%s" % f)
	var db: Dictionary = R1A._props(load("res://autoload/db.gd") as GDScript)
	assert_eq([db.get("pack", ""), db.get("pack_via", ""), db.get("pack_error", ""), db.get("pack_messages", "")],
		["PackDef", "String", "String", "PackedStringArray"], "DB.pack, pack_via, pack_error, pack_messages")
	assert_eq([PackLoader.ROOT, PackLoader.PACK_SCHEMA, PackLoader.ID_RE], ["res://packs", 1, "^[a-z][a-z0-9_]{2,23}$"])
	assert_eq([RunSim.OTHER_PACK, RunSim.OTHER_PACK_VERSION, SaveCodec.OTHER_PACK, SaveCodec.OTHER_PACK_VERSION],
		["other_pack", "other_pack_version", "other_pack", "other_pack_version"])
	assert_eq(SaveCodec.VERSION, 2, "the save block is additive: no version bump (11 §3.9)")


# --- read ----------------------------------------------------------------------------------------------------------------

func test_read_testbild() -> void:
	var p: PackDef = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	assert_eq(p.errors, PackedStringArray(), "Testbild reads clean")
	assert_true(p.is_valid())
	assert_eq([p.id, p.name, p.version, p.pack_schema, p.source_lang, p.default_lang, p.art_file],
		["testbild", "Testbild", "1.0.0", 1, "de", "de", "art.json"])
	assert_eq(p.root, "res://packs/testbild")
	assert_eq(p.languages, PackedStringArray(["de"]), "\"en\" comes with locale/en.po (11-L1)")
	assert_eq(p.engine, {"min": "0.3.0", "max": "0.4.*", "commit": ""})
	assert_false(p.has_licence(), "own content: licence null")
	assert_eq(p.files, PackedStringArray(["README.md", "art.json", "data/enemies.json", "data/looks.json",
		"data/mod_lines.json", "pack.json"]))
	var tables: Array = p.overlays.keys()
	tables.sort()
	assert_eq(tables, ["enemies", "looks", "mod_lines"])
	assert_eq(p.touches.keys().size(), 3)
	assert_true((p.art.get("models", {}) as Dictionary).has("mopsula"), "art.json: Mopsula's colours")
	assert_true(_hex.search(p.pack_hash) != null, "pack_hash is a SHA-256")
	assert_eq(p.pack_hash, PackLoader.content_hash(p))
	assert_eq(p.record(), {"id": "testbild", "version": "1.0.0", "hash": p.pack_hash})


func test_read_rejects_bad_manifests() -> void:
	var cases: Array = [
		[{"colour": "rot"}, "pack.json.colour: unknown key"],
		[{"id": "anders"}, "'anders' is not the folder name 'probe'"],
		[{"name": ""}, "pack.json.name"],
		[{"version": "1.0"}, "pack.json.version"],
		[{"engine": {"max": "0.4"}}, "pack.json.engine.max"],
		[{"engine": {"min": null}}, "pack.json.engine.min"],
		[{"engine": {"commit": "abc"}}, "pack.json.engine.commit"],
		[{"engine": {"ziel": 1}}, "pack.json.engine.ziel: unknown key"],
		[{"source_lang": "fr"}, "pack.json.source_lang"],
		[{"languages": ["en"], "default_lang": "en"}, "must contain source_lang 'de'"],
		[{"languages": ["de", "fr"]}, "'fr' unknown or twice"],
		[{"default_lang": "en"}, "pack.json.default_lang"],
		[{"licence": "ja"}, "pack.json.licence: null or a licence block"],
		[{"licence": {"holder": ""}}, "pack.json.licence.holder"],
		[{"licence": {"holder": "X", "scope": ["film"], "valid_until": "2099-12-31", "credits": []}},
			"unknown scope 'film'"],
		[{"licence": {"holder": "X", "scope": ["pitch"], "valid_until": "31.12.2099", "credits": []}},
			"pack.json.licence.valid_until"],
		[{"licence": {"holder": "X", "scope": ["pitch"], "valid_until": "2099-12-31", "credits": [], "foo": 1}},
			"pack.json.licence.foo: unknown key"],
		[{"touches": {"kulissen": {}}}, "pack.json.touches.kulissen: no such table"],
		[{"touches": {"enemies": {"umbenennen": true}}}, "pack.json.touches.enemies.umbenennen: unknown operation"],
		[{"touches": {"enemies": {"top": ["entries"]}}}, "'entries' is no top-level key"],
		[{"touches": {"enemies": {"add": "ja"}}}, "pack.json.touches.enemies.add: true or false"],
		[{"touches": {"enemies": {"sub": {"hobbies": {"add": true}}}}}, "no list with ids of enemies"],
		[{"touches": {"rt_balance": {"add": true}}}, "pack.json.touches.rt_balance.add: unknown operation"],
		[{"art": "figuren.json"}, "pack.json.art"],
		[{"tone_exceptions": [{"ref": "x"}]}, "pack.json.tone_exceptions[0]"],
		[{"pack_schema": "eins"}, "pack.json.pack_schema: missing or not an integer"],
	]
	for c: Array in cases:
		_expect(_manifest_errors(c[0]), str(c[1]), str(c[0]))
	Kit.write_text(ROOT.path_join("liste/pack.json"), "[]")
	_expect(PackLoader.read(ROOT, "liste").errors, "pack[liste].pack.json: must be a JSON object", "not an object")
	assert_eq(_manifest_errors({}), PackedStringArray(), "the default manifest is clean")


func test_read_file_rules() -> void:
	var errs: PackedStringArray = _manifest_errors({}, {}, {"skript.gd": "extends Node", "szene.tscn": "[gd_scene]",
		"bild.png": "x", "shader.gdshader": "x", "notizen.txt": "ok", "docs/LIESMICH.md": "ok", "de.po": "",
		"data/kulissen.json": {"schema": 1}, "data/sub/x.json": {}, "extra.json": {}, "locale/en.po": ""})
	for f: String in ["skript.gd", "szene.tscn", "bild.png", "shader.gdshader"]:
		_expect(errs, "files[%s]: not allowed in a pack" % f, f)
	_expect(errs, "files[de.po]: PO files belong in locale/", "PO outside locale/")
	_expect(errs, "files[data/kulissen.json]: no such table", "unknown table")
	_expect(errs, "files[data/sub/x.json]: unknown JSON file", "nested data file")
	_expect(errs, "files[extra.json]: unknown JSON file", "stray JSON")
	for f: String in ["notizen.txt", "docs/LIESMICH.md", "locale/en.po"]:
		assert_false(Kit.has_error(errs, "files[%s]" % f), "%s is allowed" % f)
	_expect(_manifest_errors({"languages": ["de", "en"]}), "'en' needs locale/en.po", "a language without its PO")
	assert_eq(_manifest_errors({"languages": ["de", "en"]}, {}, {"locale/en.po": ""}), PackedStringArray(),
		"with locale/en.po")


func test_read_overlay_schemas() -> void:
	var cases: Array = [
		[{"enemies": {"schema": 2}}, "pack[probe].enemies.schema: must be 1"],
		[{"enemies": {"umbenennen": {}}}, "enemies.umbenennen: unknown key"],
		[{"enemies": {"patch": []}}, "enemies.patch: an object"],
		[{"enemies": {"patch": {"enm_x": "Name"}}}, "enemies.patch[enm_x]: a merge patch is an object"],
		[{"enemies": {"add": [{"name": "x"}]}}, "enemies.add[0]: a new entry is an object with an \"id\""],
		[{"enemies": {"disable": "enm_x"}}, "enemies.disable: a list of ids"],
		[{"enemies": {"sub": {"hobbies": {}}}}, "enemies.sub.hobbies: no list with ids of enemies"],
		[{"origins": {"sub": {"hobbies": {"umbenennen": []}}}}, "origins.sub.hobbies.umbenennen: unknown operation"],
		[{"lootboxes": {"top": {"entries": []}}}, "lootboxes.top.entries: no top-level key"],
		[{"rt_balance": {"values": {}, "mehr": 1}}, "rt_balance.mehr: unknown key"],
		[{"rt_balance": {"values": 3}}, "rt_balance.values: must be an object"],
	]
	for c: Array in cases:
		var p: PackDef = Kit.write_pack(ROOT, "probe", Kit.manifest("probe", {}), c[0])
		_expect(p.errors, str(c[1]), str(c[0]))
		assert_false(p.overlays.has((c[0] as Dictionary).keys()[0]), "a broken overlay is not kept: %s" % str(c[0]))
	var art: PackDef = Kit.write_pack(ROOT, "probe", Kit.manifest("probe", {}, {"art": "art.json"}), {},
		{"art.json": {"schema": 1, "models": {"mopsula": {"model": {}}}}})
	_expect(art.errors, "art.models[mopsula].model: not an art parameter", "art key")
	assert_true(art.art.is_empty(), "a broken art.json is not kept")
	_expect(_manifest_errors({"art": "art.json"}), "pack[probe].art.json: named in pack.json → art, but missing",
		"missing art.json")
	Kit.write_pack(ROOT, "probe", Kit.manifest("probe", {}))
	Kit.write_text(ROOT.path_join("probe/data/enemies.json"), "{")
	_expect(PackLoader.read(ROOT, "probe").errors, "pack[probe].enemies: JSON parse error", "unparsable overlay")


func test_ids_and_missing_folders() -> void:
	for id: String in ["base", "Ab", "ab", "../x", "a-b", "1abc", "abcdefghijklmnopqrstuvwxy"]:
		assert_false(PackLoader.is_valid_id(id), id)
		_expect(PackLoader.read(ROOT, id).errors, "invalid pack id", id)
	for id: String in ["abc", "testbild", "pack_2", "abcdefghijklmnopqrstuvwx"]:
		assert_true(PackLoader.is_valid_id(id), id)
	_expect(PackLoader.read(ROOT, "fehlt").errors, "pack[fehlt]: no pack folder %s/fehlt" % ROOT, "no folder")


# --- merge -----------------------------------------------------------------------------------------------------------------

## RFC 7386 Appendix A, plus: neither argument changes.
func test_merge_patch_is_rfc7386() -> void:
	var cases: Array = [
		[{"a": "b"}, {"a": "c"}, {"a": "c"}],
		[{"a": "b"}, {"b": "c"}, {"a": "b", "b": "c"}],
		[{"a": "b"}, {"a": null}, {}],
		[{"a": "b", "b": "c"}, {"a": null}, {"b": "c"}],
		[{"a": ["b"]}, {"a": "c"}, {"a": "c"}],
		[{"a": "c"}, {"a": ["b"]}, {"a": ["b"]}],
		[{"a": {"b": "c"}}, {"a": {"b": "d", "c": null}}, {"a": {"b": "d"}}],
		[{"a": [{"b": "c"}]}, {"a": [1]}, {"a": [1]}],
		[["a", "b"], ["c", "d"], ["c", "d"]],
		[{"a": "b"}, ["c"], ["c"]],
		[{"a": "foo"}, null, null],
		[{"a": "foo"}, "bar", "bar"],
		[{"e": null}, {"a": 1}, {"e": null, "a": 1}],
		[[1, 2], {"a": "b", "c": null}, {"a": "b"}],
		[{}, {"a": {"bb": {"ccc": null}}}, {"a": {"bb": {}}}],
	]
	for c: Array in cases:
		assert_eq(PackLoader.merge_patch(c[0], c[1]), c[2], "%s + %s" % [str(c[0]), str(c[1])])
	var target: Dictionary = {"a": {"b": [1, 2]}, "k": "v"}
	var patch: Dictionary = {"a": {"b": [3]}, "k": null}
	var out: Dictionary = PackLoader.merge_patch(target, patch)
	(out["a"] as Dictionary)["b"] = "geändert"
	assert_eq(target, {"a": {"b": [1, 2]}, "k": "v"}, "the target is untouched")
	assert_eq(patch, {"a": {"b": [3]}, "k": null}, "the patch is untouched")
	assert_eq(PackLoader.patch_paths({"name": "x", "rt": {"hp": 1, "bar": [1]}, "desc": null, "leer": {}}),
		PackedStringArray(["desc", "leer", "name", "rt.bar", "rt.hp"]), "field paths: sorted, nested, lists whole")


func test_merge_order_and_error_format() -> void:
	var raw: Dictionary = Kit.base_raw()
	var s0: String = str(((raw["statuses"] as Dictionary)["entries"] as Array)[0]["id"])
	var s1: String = str(((raw["statuses"] as Dictionary)["entries"] as Array)[1]["id"])
	var touches: Dictionary = {"statuses": {"patch": ["name"], "disable": true, "add": true},
		"mod_lines": {"patch": ["text"]}}
	var m: Dictionary = _merge(touches, {
		"mod_lines": {"patch": {"mod_zz_fehlt": {"text": "x"}, "mod_aa_fehlt": {"text": "y"}}},
		"statuses": {"disable": [s0], "patch": {s0: {"name": "X"}, s1: {"name": "Neu"}},
			"add": [{"id": s0, "name": "Wieder da", "kind": "buff"}]}})
	var errs: PackedStringArray = m["errors"]
	var e_patch: String = "pack[probe].statuses[%s]: patch target does not exist" % s0
	var e_add: String = "pack[probe].statuses[%s]: the id exists already — use patch" % s0
	assert_eq(errs, PackedStringArray([e_patch, e_add, "pack[probe].mod_lines[mod_aa_fehlt]: patch target does not "
		+ "exist", "pack[probe].mod_lines[mod_zz_fehlt]: patch target does not exist"]),
		"disable → patch → add; ids sorted; tables in GameData.TABLES order (statuses before mod_lines)")
	var out: Dictionary = m["raw"]
	assert_false(_ids(out, "statuses").has(s0), "disabled")
	assert_eq(str(_entry(out, "statuses", s1).get("name", "")), "Neu", "patched")
	assert_eq(_ids(out, "statuses").size(), _ids(raw, "statuses").size() - 1)
	assert_eq(str(_entry(raw, "statuses", s1).get("name", "")) != "Neu", true, "merge works on a copy")


func test_merge_protected_ids() -> void:
	var m: Dictionary = _merge({"party": {"disable": true}, "lootboxes": {"disable": true}, "floors": {"disable": true}},
		{"party": {"disable": ["kai", "mopsula"]}, "lootboxes": {"disable": ["box_fan", "box_bronze"]},
		"floors": {"disable": ["floor_1", "floor_2"]}})
	var errs: PackedStringArray = m["errors"]
	for at: String in ["party[kai]", "party[mopsula]", "lootboxes[box_fan]", "lootboxes[box_bronze]", "floors[floor_1]"]:
		_expect(errs, "pack[probe].%s: a protected id is never disabled" % at, at)
	assert_eq(errs.size(), 5, str(errs))
	var out: Dictionary = m["raw"]
	assert_true(_ids(out, "party").has("kai") and _ids(out, "party").has("mopsula"))
	assert_true(_ids(out, "floors").has("floor_1"))
	assert_false(_ids(out, "floors").has("floor_2"), "floor 2 may go")
	assert_eq(PackLoader.protected_ids("lootboxes"), DataValidator.REQUIRED_BOXES)


func test_merge_touches() -> void:
	var raw: Dictionary = Kit.base_raw()
	var key: String = str(((raw["rt_balance"] as Dictionary)["values"] as Dictionary).keys()[0])
	var m: Dictionary = _merge({"enemies": {"patch": ["name"]}}, {
		"enemies": {"disable": ["enm_kanalratte"], "patch": {"enm_kanalschleim": {"name": "Schleim", "exp": 1}},
			"add": [{"id": "enm_testpaket", "name": "Neu"}]},
		"lootboxes": {"top": {"pity": {"rare": 5}}},
		"rt_balance": {"values": {key: 1}}})
	var errs: PackedStringArray = m["errors"]
	_expect(errs, "pack[probe].enemies: disable not declared in pack.json → touches", "disable")
	_expect(errs, "pack[probe].enemies[enm_kanalschleim].exp: field not declared in pack.json → touches", "patch field")
	_expect(errs, "pack[probe].enemies: add not declared in pack.json → touches", "add")
	_expect(errs, "pack[probe].lootboxes.pity: top-level patch not declared", "top")
	_expect(errs, "pack[probe].rt_balance.values.%s: value not declared" % key, "rt_balance")
	assert_false(Kit.has_error(errs, "enm_kanalschleim].name"), "name is declared")
	var out: Dictionary = m["raw"]
	assert_true(_ids(out, "enemies").has("enm_kanalratte"), "an undeclared disable changes nothing")
	assert_ne(str(_entry(out, "enemies", "enm_kanalschleim").get("name", "")), "Schleim",
		"a patch with an undeclared field is not applied")
	assert_eq((out["lootboxes"] as Dictionary)["pity"], (raw["lootboxes"] as Dictionary)["pity"])


func test_merge_new_ids_and_model() -> void:
	var m: Dictionary = _merge({"statuses": {"add": true, "patch": ["name", "id"]}, "enemies": {"add": true,
		"patch": ["name", "model"]}}, {
		"statuses": {"add": [{"id": "falsch", "name": "x"}, {"id": "sts_testpaket_a", "name": "A"},
			{"id": "sts_testpaket_b", "name": "B"}, {"id": "sts_testpaket_a", "name": "A2"}],
			"patch": {"sts_poison": {"id": "sts_gift"}}},
		"enemies": {"add": [{"id": "enm_testpaket", "name": "Neu", "model": {"base": "blob"}}],
			"patch": {"enm_kanalratte": {"model": {"scale": 2.0}}}}})
	var errs: PackedStringArray = m["errors"]
	_expect(errs, "pack[probe].statuses[falsch]: a new id follows the pattern ^sts_[a-z0-9_]+$", "pattern")
	_expect(errs, "pack[probe].statuses[sts_testpaket_a]: the id exists already — use patch", "added twice")
	_expect(errs, "pack[probe].statuses[sts_poison].id: the id of an entry is never patched", "id")
	_expect(errs, "pack[probe].enemies[enm_testpaket].model: figures belong in art.json", "add with model")
	_expect(errs, "pack[probe].enemies[enm_kanalratte].model: figures belong in art.json", "patch with model")
	var ids: PackedStringArray = _ids(m["raw"], "statuses")
	assert_eq(ids.slice(ids.size() - 2), PackedStringArray(["sts_testpaket_a", "sts_testpaket_b"]),
		"new entries are appended in file order")
	assert_eq(str(_entry(m["raw"], "statuses", "sts_testpaket_a").get("name", "")), "A", "the first one stays")


func test_merge_sub_top_and_rt_balance() -> void:
	var raw: Dictionary = Kit.base_raw()
	var values: Dictionary = (raw["rt_balance"] as Dictionary)["values"]
	var keys: Array = values.keys()
	keys.sort()
	var key: String = ""
	for k: Variant in keys:
		if JsonUtil.is_integral(values[k]):
			key = str(k)
			break
	var m: Dictionary = _merge({"origins": {"sub": {"hobbies": {"patch": ["name"], "add": true, "disable": true}}},
		"lootboxes": {"top": ["pity"]}, "enemies": {"sub": {"pseudo_units": {"add": true, "patch": ["name"]}}},
		"professions": {"sub": {"recipes": {"patch": ["name"]}}}, "rt_balance": {"patch": [key]}}, {
		"origins": {"sub": {"hobbies": {"disable": ["hob_gaming"], "patch": {"hob_cooking": {"name": "Kochshow"}},
			"add": [{"id": "hob_testpaket", "name": "Testpaket"}]}}},
		"lootboxes": {"top": {"pity": {"rare": 5}}},
		"enemies": {"sub": {"pseudo_units": {"add": [{"id": "pu_testpaket", "name": "Testzug"}]}}},
		"professions": {"sub": {"recipes": {"patch": {"rcp_fehlt": {"name": "x"}}}}},
		"rt_balance": {"values": {key: int(values[key]) + 1}}})
	assert_eq(m["errors"], PackedStringArray(["pack[probe].professions.recipes[rcp_fehlt]: patch target does not exist"]))
	var out: Dictionary = m["raw"]
	var hobbies: PackedStringArray = _ids(out, "origins", "hobbies")
	assert_false(hobbies.has("hob_gaming"), "sub disable")
	assert_eq(hobbies[hobbies.size() - 1], "hob_testpaket", "sub add appends")
	assert_eq(str(_entry(out, "origins", "hob_cooking", "hobbies").get("name", "")), "Kochshow", "sub patch")
	assert_eq((out["lootboxes"] as Dictionary)["pity"], {"rare": 5, "epic": (raw["lootboxes"] as Dictionary)["pity"]["epic"]},
		"top: a merge patch on pity")
	assert_eq(_ids(out, "enemies", "pseudo_units"), PackedStringArray(["pu_testpaket"]),
		"a sub list the base lacks is created by add")
	assert_eq(int(((out["rt_balance"] as Dictionary)["values"] as Dictionary)[key]), int(values[key]) + 1)
	var owned: Dictionary = m["owned"]
	assert_eq(PackLoader.owned_paths(owned, "origins.hobbies", "hob_testpaket"), PackedStringArray([""]))
	assert_eq(PackLoader.owned_paths(owned, "origins.hobbies", "hob_cooking"), PackedStringArray(["name"]))
	assert_eq((owned["lootboxes"] as Dictionary)["top"], ["pity"])
	assert_eq(PackLoader.owned_paths(owned, "rt_balance", "values"), PackedStringArray([key]))


func test_merge_provenance_and_art() -> void:
	var p: PackDef = PackLoader.read(Kit.PACKS, Kit.TESTBILD)
	var m: Dictionary = PackLoader.merge(Kit.base_raw(), p)
	assert_eq(m["errors"], PackedStringArray())
	var owned: Dictionary = m["owned"]
	assert_eq(PackLoader.owned_paths(owned, "enemies", "enm_boss_rattenkoenigin"), PackedStringArray(["name"]))
	assert_eq(PackLoader.owned_paths(owned, "mod_lines", "mod_boss_intro_enm_boss_rattenkoenigin_02"),
		PackedStringArray(["text"]))
	assert_eq(PackLoader.owned_paths(owned, "looks", "lk_outfit_testbild"), PackedStringArray([""]), "added")
	assert_eq(PackLoader.owned_paths(owned, "party", "mopsula"),
		PackedStringArray(["model.colors.primary", "model.colors.secondary"]), "art.json paths under model.")
	assert_eq(PackLoader.owned_paths(owned, "enemies", "enm_kanalratte"), PackedStringArray(), "not the pack's")
	assert_eq(PackLoader.owned_paths({}, "enemies", "x"), PackedStringArray())
	assert_true(PackLoader.covers(PackedStringArray([""]), "lines[0].text"), "a whole entry")
	assert_true(PackLoader.covers(PackedStringArray(["name"]), "name"))
	assert_false(PackLoader.covers(PackedStringArray(["name"]), "names"))
	assert_true(PackLoader.covers(PackedStringArray(["lines"]), "lines[0].text"), "a list is one path")
	assert_true(PackLoader.covers(PackedStringArray(["rt"]), "rt.hp"))
	assert_false(PackLoader.covers(PackedStringArray(["rt.hp"]), "rt"))
	var prov: Dictionary = PackLoader.provenance(p, owned)
	assert_eq([prov["pack"], prov["licensed"], prov["def"] == p], ["testbild", false, true])
	assert_eq(PackLoader.provenance(null, owned), {}, "no pack: no provenance")
	var mop: Dictionary = _entry(m["raw"], "party", "mopsula")
	var base_mop: Dictionary = _entry(Kit.base_raw(), "party", "mopsula")
	assert_eq((mop["model"] as Dictionary)["colors"]["primary"], "#3C6EA5")
	assert_eq((mop["model"] as Dictionary)["colors"]["accent"], (base_mop["model"] as Dictionary)["colors"]["accent"],
		"a merge patch keeps the other colours")
	var art: Dictionary = _merge({}, {}, {"art.json": {"schema": 1, "models": {"enm_kanalratte": {"scale": 1.5},
		"enm_fehlt": {"scale": 1.0}}}}, {"art": "art.json"})
	assert_eq(art["errors"], PackedStringArray(["pack[probe].art.models[enm_fehlt]: no party member or enemy with this "
		+ "id"]))
	assert_eq(float(((_entry(art["raw"], "enemies", "enm_kanalratte")["model"]) as Dictionary)["scale"]), 1.5)


# --- content_hash, compat ----------------------------------------------------------------------------------------------

func test_content_hash_covers_pack_json_and_overlays_only() -> void:
	Kit.copy_pack(Kit.PACKS, Kit.TESTBILD, ROOT)
	var dir: String = ROOT.path_join(Kit.TESTBILD)
	var p: PackDef = PackLoader.read(ROOT, Kit.TESTBILD)
	var parts: PackedStringArray = []
	for f: String in ["data/enemies.json", "data/looks.json", "data/mod_lines.json", "pack.json"]:
		parts.append("%s:%s" % [f, FileAccess.get_sha256(dir.path_join(f))])
	assert_eq(p.pack_hash, "|".join(parts).sha256_text(), "11 §3.9: <path>:<sha256>, sorted, joined by |")
	assert_eq(p.pack_hash, PackLoader.read(Kit.PACKS, Kit.TESTBILD).pack_hash, "the copy hashes like the original")
	Kit.write_text(dir.path_join("README.md"), "anders")
	Kit.write_json(dir.path_join("art.json"), {"schema": 1, "models": {"mopsula": {"colors": {"primary": "#000000"}}}})
	Kit.write_text(dir.path_join("locale/en.po"), "msgid \"\"\nmsgstr \"\"\n")
	assert_eq(PackLoader.read(ROOT, Kit.TESTBILD).pack_hash, p.pack_hash, "README, art.json and PO are not hashed")
	var ov: Dictionary = Kit.read_json(dir.path_join("data/enemies.json"))
	((ov["patch"] as Dictionary)["enm_boss_rattenkoenigin"] as Dictionary)["name"] = "Die Testbild-Königin, neu"
	Kit.write_json(dir.path_join("data/enemies.json"), ov)
	var h2: String = PackLoader.read(ROOT, Kit.TESTBILD).pack_hash
	assert_ne(h2, p.pack_hash, "an overlay change changes the hash")
	var man: Dictionary = Kit.read_json(dir.path_join("pack.json"))
	man["version"] = "1.0.1"
	Kit.write_json(dir.path_join("pack.json"), man)
	assert_ne(PackLoader.read(ROOT, Kit.TESTBILD).pack_hash, h2, "a pack.json change changes the hash")


func test_compat() -> void:
	var p: PackDef = PackDef.new()
	p.id = "probe"
	p.pack_schema = 1
	p.engine = {"min": "0.3.0", "max": "0.4.*", "commit": ""}
	for v: String in ["0.3.0", "0.3.9", "0.4.0", "0.4.12"]:
		assert_eq(PackLoader.compat(p, v), "", v)
	for v: String in ["0.2.9", "0.5.0", "1.0.0", "dev", ""]:
		assert_eq(PackLoader.compat(p, v), "pack_engine", v)
	p.engine = {"min": "0.3.0", "max": "0.*", "commit": ""}
	assert_eq([PackLoader.compat(p, "0.9.9"), PackLoader.compat(p, "1.0.0")], ["", "pack_engine"])
	p.engine = {"min": "0.3.0", "max": "0.3.5", "commit": ""}
	assert_eq([PackLoader.compat(p, "0.3.5"), PackLoader.compat(p, "0.3.6")], ["", "pack_engine"])
	assert_true(PackLoader.compat_message(p, "0.3.6").contains("game version 0.3.6 outside engine 0.3.0 … 0.3.5"))
	assert_eq(PackLoader.compat(null, "0.3.0"), "", "no pack")
	assert_eq(PackLoader.compat(PackLoader.read(Kit.PACKS, Kit.TESTBILD),
		str(ProjectSettings.get_setting("application/config/version", ""))), "", "Testbild fits this engine")
	var future: PackDef = Kit.write_pack(ROOT, "probe", Kit.manifest("probe", {"enemies": {"patch": ["name"]}},
		{"pack_schema": 2}), {"enemies": {"patch": {"enm_kanalratte": {"name": "x"}}}})
	assert_eq([future.pack_schema, future.errors, future.overlays], [2, PackedStringArray(), {}],
		"another pack_schema: reading stops after pack.json")
	assert_eq(PackLoader.compat(future, "0.3.0"), "pack_engine")
	assert_true(PackLoader.compat_message(future, "0.3.0").contains("pack_schema 2, this engine reads 1"))


# --- activation ------------------------------------------------------------------------------------------------------------

func _folders() -> void:
	for d: String in ["alpha", "beta", ".versteckt"]:
		DirAccess.make_dir_recursive_absolute(ROOT.path_join(d))


static func _tags(list: PackedStringArray) -> Callable:
	return func(tag: String) -> bool: return list.has(tag)


func test_active_id_release_reads_feature_tags() -> void:
	_folders()
	assert_eq(PackLoader.folders(ROOT), PackedStringArray(["alpha", "beta"]), "hidden folders left out")
	var none: PackedStringArray = []
	var r: Dictionary = PackLoader.active_id(none, false, ROOT, _tags(none))
	assert_eq([r["id"], r["error"], r["via"]], ["", "", ""], "no tag: the base game")
	r = PackLoader.active_id(none, false, ROOT, _tags(PackedStringArray(["pack_alpha", "mobile"])))
	assert_eq([r["id"], r["error"], r["via"]], ["alpha", "", "feature"], "export tag pack_alpha")
	r = PackLoader.active_id(none, false, ROOT, _tags(PackedStringArray(["pack_alpha", "pack_beta"])))
	assert_eq([r["id"], r["error"], r["ids"]], ["", "pack_ambiguous", PackedStringArray(["alpha", "beta"])])
	r = PackLoader.active_id(PackedStringArray(["--pack=beta"]), false, ROOT, _tags(PackedStringArray(["pack_alpha"])))
	assert_eq([r["id"], r["error"], r["via"]], ["alpha", "", "feature"], "release: --pack is ignored")
	assert_true(str(r["note"]).contains("--pack=beta ignored"), str(r["note"]))
	r = PackLoader.active_id(PackedStringArray(["--pack=alpha"]), false, ROOT, _tags(none))
	assert_eq([r["id"], r["error"]], ["", ""], "release without a tag: the base game, --pack or not")
	r = PackLoader.active_id(PackedStringArray(["--pack=nirgends"]), false, ROOT, _tags(none))
	assert_eq(r["error"], "", "release: no pack_missing for an ignored --pack")


func test_active_id_debug_takes_pack_args() -> void:
	_folders()
	var none: PackedStringArray = []
	var r: Dictionary = PackLoader.active_id(PackedStringArray(["--autoplay", "--pack=alpha"]), true, ROOT, _tags(none))
	assert_eq([r["id"], r["error"], r["via"]], ["alpha", "", "arg"])
	for bad: String in ["nirgends", "../alpha", "base", ""]:
		r = PackLoader.active_id(PackedStringArray(["--pack=" + bad]), true, ROOT, _tags(none))
		assert_eq([r["id"], r["error"]], ["", "pack_missing"], "--pack=" + bad)
	r = PackLoader.active_id(PackedStringArray(["--pack=beta"]), true, ROOT, _tags(PackedStringArray(["pack_alpha"])))
	assert_eq([r["id"], r["error"], r["ids"]], ["", "pack_ambiguous", PackedStringArray(["alpha", "beta"])],
		"a tag and another --pack")
	r = PackLoader.active_id(PackedStringArray(["--pack=alpha"]), true, ROOT, _tags(PackedStringArray(["pack_alpha"])))
	assert_eq([r["id"], r["error"], r["via"]], ["alpha", "", "feature"], "the tag's own pack again")
	r = PackLoader.active_id(PackedStringArray(["--pack=alpha", "--pack=beta"]), true, ROOT, _tags(none))
	assert_eq(r["error"], "pack_ambiguous", "two --pack")
	r = PackLoader.active_id(PackedStringArray(["--pack=alpha", "--pack=alpha"]), true, ROOT, _tags(none))
	assert_eq([r["id"], r["error"]], ["alpha", ""], "the same --pack twice")
	r = PackLoader.active_id(OS.get_cmdline_user_args(), OS.is_debug_build())
	assert_eq([r["id"], r["error"]], ["", ""], "this test run plays the base game (OS.has_feature, the real args)")
	assert_eq([PackLoader.debug_save_dir("alpha", "arg"), PackLoader.debug_save_dir("alpha", "feature"),
		PackLoader.debug_save_dir("", "arg")], ["user://packs/alpha/saves", "", ""])


func test_load_data_codes() -> void:
	var v: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var base: Dictionary = PackLoader.load_data("res://data", {}, v)
	assert_eq([base["error"], base["pack"], (base["data"] as GameData).is_valid(), (base["data"] as GameData).pack_id],
		["", null, true, ""], "no pack")
	var amb: Dictionary = PackLoader.load_data("res://data", {"id": "", "error": "pack_ambiguous",
		"ids": PackedStringArray(["alpha", "beta"])}, v)
	assert_eq([amb["error"], amb["pack"], (amb["data"] as GameData).is_valid()], ["pack_ambiguous", null, true],
		"no pack to read: the base data only so that the autoloads start")
	assert_true(str((amb["messages"] as PackedStringArray)[0]).contains("pack_ambiguous: more than one content pack "
		+ "is activated (alpha, beta"))
	var miss: Dictionary = PackLoader.load_data("res://data", {"id": "", "error": "pack_missing",
		"ids": PackedStringArray(["nirgends"])}, v)
	assert_eq(miss["error"], "pack_missing")
	assert_true(str((miss["messages"] as PackedStringArray)[0]).contains("--pack=nirgends has no pack folder"))
	Kit.write_pack(ROOT, "zukunft", Kit.manifest("zukunft", {}, {"engine": {"min": "9.0.0", "max": "9.*"}}))
	var eng: Dictionary = PackLoader.load_data("res://data", {"id": "zukunft"}, v, ROOT)
	assert_eq([eng["error"], (eng["pack"] as PackDef).id, (eng["data"] as GameData).pack_id],
		["pack_engine", "zukunft", "zukunft"], "the data are the pack's, never silently the base game's")
	assert_true(str((eng["messages"] as PackedStringArray)[0]).contains("pack_engine — game version"))
	Kit.write_pack(ROOT, "kaputt", Kit.manifest("kaputt", {"enemies": {"patch": ["name"]}}),
		{"enemies": {"patch": {"enm_fehlt": {"name": "x"}}}})
	var bad: Dictionary = PackLoader.load_data("res://data", {"id": "kaputt"}, v, ROOT)
	assert_eq(bad["error"], "pack_invalid")
	assert_eq((bad["messages"] as PackedStringArray)[0], "pack[kaputt].enemies[enm_fehlt]: patch target does not exist",
		"the pack's own errors first")
	assert_false((bad["data"] as GameData).is_valid())
	var ok: Dictionary = PackLoader.load_data("res://data", {"id": "testbild", "error": "", "via": "arg"}, v)
	var d: GameData = ok["data"]
	assert_eq([ok["error"], (ok["pack"] as PackDef).id, d.is_valid(), d.pack_id, d.pack_version],
		["", "testbild", true, "testbild", "1.0.0"])
	assert_eq(d.pack_hash, (ok["pack"] as PackDef).pack_hash)
	var lic: PackDef = PackDef.new()
	lic.id = "probe"
	lic.licence = {"valid_until": "2026-01-31"}
	assert_eq(PackLoader.licence_notes(lic, "2026-02-01").size(), 1, "a passed licence date warns at runtime")
	assert_eq(PackLoader.licence_notes(lic, "2026-01-31").size(), 0)
