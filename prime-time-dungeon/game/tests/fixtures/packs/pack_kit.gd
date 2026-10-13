extends RefCounted
## Test kit of the content-pack tests (11-P1; test_11_pack_loader, test_11_pack_testbild, test_11_pack_records,
## test_11_ip_firewall): the base data with "Testbild" (cached), packs written into user:// (the loader's error
## cases and the variants of the layer-2 fixture are built at run time — no forbidden word is ever stored in a file),
## folder copies and clean-up. No class_name (tests/fixtures, 02_TECH §0.3).

const PACKS: String = "res://packs"
const FIXTURES: String = "res://tests/fixtures/packs"
const TESTBILD: String = "testbild"
const LIZENZTEST: String = "lizenztest"
## The fixed holder of the test fixtures' licence block (11 §3.12 layer 1).
const TEST_HOLDER: String = "TEST – kein Rechteinhaber"

static var _testbild: GameData = null


## GameData of res://data with the pack "testbild" (cached; defs are read-only like every loaded GameData).
static func testbild_data() -> GameData:
	if _testbild == null:
		_testbild = GameData.new()
		_testbild.load_dir("res://data", PackLoader.read(PACKS, TESTBILD))
	return _testbild


## GameData of res://data with `pack` (not cached).
static func data_with(pack: PackDef) -> GameData:
	var d: GameData = GameData.new()
	d.load_dir("res://data", pack)
	return d


## The raw tables as GameData.load_dir reads them (table → parsed file, "rt_balance").
static func base_raw() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/rt_balance.json")
	return raw


## A complete pack.json of an own-content pack (licence null) for `id`; `extra` overrides keys (null deletes).
static func manifest(id: String, touches: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var m: Dictionary = {"pack_schema": 1, "id": id, "name": id.capitalize(), "version": "1.0.0",
		"engine": {"min": "0.3.0", "max": "0.4.*", "commit": ""}, "source_lang": "de", "languages": ["de"],
		"default_lang": "de", "licence": null, "touches": touches, "art": ""}
	return PackLoader.merge_patch(m, extra) if not extra.is_empty() else m


## A licence block with the test holder (11 §3.12 layer 1).
static func test_licence() -> Dictionary:
	return {"holder": TEST_HOLDER, "contract": "TEST-0", "scope": ["pitch"], "valid_until": "2099-12-31",
		"credits": ["Testdaten, kein Werk"], "notice": "Nur für Tests."}


## Writes root/<id>/pack.json, data/<table>.json for every overlay (table → overlay dict, "schema" added when missing)
## and `files` (relative path → Dictionary (JSON) or String (text)); returns PackLoader.read(root, id).
static func write_pack(root: String, id: String, p_manifest: Dictionary, overlays: Dictionary = {},
		files: Dictionary = {}) -> PackDef:
	var dir: String = root.path_join(id)
	rmrf(dir)
	write_json(dir.path_join("pack.json"), p_manifest)
	for t: Variant in overlays.keys():
		var ov: Dictionary = (overlays[t] as Dictionary).duplicate(true)
		if not ov.has("schema"):
			ov["schema"] = 1
		write_json(dir.path_join("data/%s.json" % str(t)), ov)
	for f: Variant in files.keys():
		if files[f] is String:
			write_text(dir.path_join(str(f)), str(files[f]))
		else:
			write_json(dir.path_join(str(f)), files[f])
	return PackLoader.read(root, id)


## Copies the folder src/<id> to dst/<id> (files and sub folders).
static func copy_pack(src: String, id: String, dst: String) -> void:
	rmrf(dst.path_join(id))
	_copy(src.path_join(id), dst.path_join(id))


static func write_json(path: String, d: Variant) -> void:
	write_text(path, JSON.stringify(d, "\t"))


static func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func read_json(path: String) -> Dictionary:
	var v: Variant = JsonUtil.read_file(path)
	return v if v is Dictionary else {}


static func rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


## True if some message of `errors` contains `needle`.
static func has_error(errors: PackedStringArray, needle: String) -> bool:
	for e: String in errors:
		if e.contains(needle):
			return true
	return false


static func _copy(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f: String in DirAccess.get_files_at(src):
		DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	for sub: String in DirAccess.get_directories_at(src):
		_copy(src.path_join(sub), dst.path_join(sub))
