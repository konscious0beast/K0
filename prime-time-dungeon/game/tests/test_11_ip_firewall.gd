extends TestCase
## 11-P1 (docs/11 §3.12, SP-17, in the F-20 variant): the IP firewall, layers 1 and 2 (layer 3, the HMAC fingerprints, is
## 11-PB's tools/ip_firewall.sh).
## Layer 1 — structure: every folder under game/packs/ is listed in PUBLIC_PACKS or in PRIVATE_PACKS (F-20: a licensed
## pack may live here only while the repository is private); a pack.json carries a licence block only for an id of
## PRIVATE_PACKS or as a test fixture under game/tests/fixtures/packs/ with the holder "TEST – kein Rechteinhaber"; no
## pack.json anywhere else below res://; game/packs/.gitignore whitelists exactly the public files. With
## PTD_REPO_VISIBILITY=public (set by the CI from github.event.repository.private, 11-PB) PRIVATE_PACKS must be empty;
## without the variable the visibility is unknown here and only the structure rules apply.
## Layer 2 — texts: a pack with a licence block owns its texts (PackLoader provenance "owned"): they are exempt from the
## IP-distance lists of ip_words (ALL_WORDS, the Mopsula rule — a figure the licensed pack redesigned is not Graf Mopsula
## any more), never from the tone rules (ORIGIN_WORDS; the tone lists of the pack rules), and never for texts the pack
## does not own. The fixture "lizenztest" on disk is harmless; the variants with listed words are written into user://
## at run time from the lists themselves — no such word is stored in this repository for the test.

const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const IpWords := preload("res://core/data/validators/ip_words.gd")
const PackCheck := preload("res://core/data/validators/pack.gd")
const ROOT: String = "user://test_11_firewall"
const PACKS_DIR: String = "res://packs"
const FIXTURES_DIR: String = "res://tests/fixtures/packs"
const VISIBILITY_ENV: String = "PTD_REPO_VISIBILITY"
## The whitelist lines of game/packs/.gitignore besides one "!/<id>/" per public pack.
const GITIGNORE_LINES: PackedStringArray = ["/*", "!/.gitignore", "!/PUBLIC_PACKS", "!/PRIVATE_PACKS",
	"!/ip_firewall*.json"]
const IP_MARKERS: PackedStringArray = ["(IP distance", "(no royalty motif"]


func before_each() -> void:
	Kit.rmrf(ROOT)


func after_each() -> void:
	Kit.rmrf(ROOT)


## The ids of a list file (one per line; "#" comments and blank lines left out).
static func list_file(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var l: String = line.strip_edges()
		if l != "" and not l.begins_with("#"):
			out.append(l)
	return out


## Every pack.json below `dir` (res:// paths; hidden folders such as .godot left out).
static func pack_jsons(dir: String, out: PackedStringArray) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f == "pack.json":
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			pack_jsons(dir.path_join(d), out)


static func _licence(path: String) -> Variant:
	var raw: Variant = JsonUtil.read_file(path)
	return (raw as Dictionary).get("licence", null) if raw is Dictionary else "unreadable"


## The lizenztest fixture copied to ROOT with `enemy_name` / `title` as its two texts and `licensed` deciding its
## licence block; extra overlays and manifest keys on top. Returns the validation errors of base data + this pack.
func _variant(enemy_name: String, title: String, licensed: bool, extra_manifest: Dictionary = {},
		raw: Dictionary = {}) -> PackedStringArray:
	Kit.copy_pack(FIXTURES_DIR, Kit.LIZENZTEST, ROOT)
	var dir: String = ROOT.path_join(Kit.LIZENZTEST)
	Kit.write_json(dir.path_join("data/enemies.json"), {"schema": 1, "patch": {"enm_kanalratte": {"name": enemy_name}}})
	Kit.write_json(dir.path_join("data/party.json"), {"schema": 1, "patch": {"mopsula": {"title": title}}})
	var m: Dictionary = Kit.read_json(dir.path_join("pack.json"))
	if not licensed:
		m["licence"] = null
	m.merge(extra_manifest, true)
	Kit.write_json(dir.path_join("pack.json"), m)
	var p: PackDef = PackLoader.read(ROOT, Kit.LIZENZTEST)
	assert_eq(p.errors, PackedStringArray(), "the variant reads clean")
	assert_eq(p.has_licence(), licensed)
	var merged: Dictionary = PackLoader.merge(raw if not raw.is_empty() else Kit.base_raw(), p)
	assert_eq(merged["errors"], PackedStringArray())
	var v: DataValidator = DataValidator.new()
	v.validate(merged["raw"], true, {}, PackLoader.provenance(p, merged["owned"]))
	return v.errors


static func _ip_errors(errors: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: String in errors:
		for marker: String in IP_MARKERS:
			if e.contains(marker):
				out.append(e)
	return out


## The first single word of a tone list of data/mod_filter.json, without its wildcards.
static func _tone_word(list: String) -> String:
	var raw: Dictionary = JsonUtil.read_file("res://data/mod_filter.json")
	for e: Variant in ((raw["blocked"] as Dictionary)[list] as Array):
		var w: String = str(e)
		if not w.contains(" "):
			return w.trim_prefix("*").trim_suffix("*")
	return ""


# --- layer 1: structure ----------------------------------------------------------------------------------------------------

func test_every_pack_folder_is_listed() -> void:
	var public: PackedStringArray = list_file(PACKS_DIR.path_join("PUBLIC_PACKS"))
	var private: PackedStringArray = list_file(PACKS_DIR.path_join("PRIVATE_PACKS"))
	assert_has(public, "testbild", "PUBLIC_PACKS lists Testbild")
	assert_true(FileAccess.file_exists(PACKS_DIR.path_join("PRIVATE_PACKS")), "the F-20 list exists (empty today)")
	for id: String in public:
		assert_false(private.has(id), "%s is public or private, never both" % id)
	var folders: PackedStringArray = PackLoader.folders(PACKS_DIR)
	for id: String in folders:
		assert_true(public.has(id) or private.has(id), "game/packs/%s is in neither PUBLIC_PACKS nor PRIVATE_PACKS" % id)
	for id: String in public + private:
		assert_true(folders.has(id), "listed pack %s has no folder (stale list)" % id)


func test_licence_blocks_only_for_private_packs_and_test_fixtures() -> void:
	var private: PackedStringArray = list_file(PACKS_DIR.path_join("PRIVATE_PACKS"))
	var found: PackedStringArray = []
	pack_jsons(PACKS_DIR, found)
	for path: String in found:
		var id: String = path.get_base_dir().get_file()
		var lic: Variant = _licence(path)
		if not private.has(id):
			assert_eq(lic, null, "%s: a public pack carries \"licence\": null (11 §3.12 layer 1)" % path)
	var fixtures: PackedStringArray = []
	pack_jsons(FIXTURES_DIR, fixtures)
	assert_has(fixtures, FIXTURES_DIR.path_join("lizenztest/pack.json"), "the layer-2 fixture")
	for path: String in fixtures:
		var lic: Variant = _licence(path)
		if lic != null:
			assert_true(lic is Dictionary and str((lic as Dictionary).get("holder", "")) == Kit.TEST_HOLDER,
				"%s: a fixture's licence names the holder \"%s\"" % [path, Kit.TEST_HOLDER])


func test_no_pack_json_anywhere_else() -> void:
	var found: PackedStringArray = []
	pack_jsons("res://", found)
	assert_gt(found.size(), 1, "the scan sees Testbild and the fixture")
	var place: RegEx = RegEx.create_from_string("^res://(packs|tests/fixtures/packs)/[a-z][a-z0-9_]{2,23}/pack\\.json$")
	for path: String in found:
		assert_true(place.search(path) != null, "%s: a pack.json lives only in game/packs/<id>/ or in the test fixtures"
			% path)


func test_gitignore_whitelists_the_public_files() -> void:
	var path: String = PACKS_DIR.path_join(".gitignore")
	assert_true(FileAccess.file_exists(path), "game/packs/.gitignore")
	var lines: PackedStringArray = list_file(path)
	var want: PackedStringArray = GITIGNORE_LINES.duplicate()
	for id: String in list_file(PACKS_DIR.path_join("PUBLIC_PACKS")):
		want.append("!/%s/" % id)
	var private: PackedStringArray = list_file(PACKS_DIR.path_join("PRIVATE_PACKS"))
	for l: String in lines:
		var ok: bool = want.has(l) or (l.begins_with("!/") and private.has(l.trim_prefix("!/").trim_suffix("/")))
		assert_true(ok, ".gitignore line '%s' opens more than the whitelist" % l)
	for w: String in want:
		assert_has(lines, w, ".gitignore")
	assert_eq(lines[0], "/*", "everything else is ignored")


## F-20: PRIVATE_PACKS may name packs only while the repository is private. The CI sets PTD_REPO_VISIBILITY
## ("public" | "private", from github.event.repository.private; 11-PB) — here unset means: unknown, structure only.
func test_private_packs_need_a_private_repository() -> void:
	var private: PackedStringArray = list_file(PACKS_DIR.path_join("PRIVATE_PACKS"))
	var visibility: String = OS.get_environment(VISIBILITY_ENV)
	assert_true(["", "public", "private"].has(visibility), "%s is public or private, got '%s'" % [VISIBILITY_ENV,
		visibility])
	if visibility == "public":
		assert_eq(private, PackedStringArray(), "the repository is public: PRIVATE_PACKS must be empty (F-20)")
	elif visibility == "":
		print("[test_11_ip_firewall] %s unset: the visibility rule is checked by the CI (11-PB); PRIVATE_PACKS: %s"
			% [VISIBILITY_ENV, str(private)])


# --- layer 2: texts ----------------------------------------------------------------------------------------------------------

func test_licensed_fixture_reads_and_loads() -> void:
	var p: PackDef = PackLoader.read(FIXTURES_DIR, Kit.LIZENZTEST)
	assert_eq(p.errors, PackedStringArray())
	assert_true(p.has_licence())
	assert_eq(str(p.licence.get("holder", "")), Kit.TEST_HOLDER)
	var d: GameData = Kit.data_with(p)
	assert_eq(d.errors, PackedStringArray(), "base data + the licensed fixture")
	assert_eq([d.enemy("enm_kanalratte").name, d.party_member("mopsula").title], ["Fixture-Ratte", "Fixture-Graf"])


func test_licence_exempts_only_the_ip_distance_lists() -> void:
	var ip_name: String = "Die %s-Bande" % IpWords.ALL_WORDS[3].capitalize()
	var royal: String = IpWords.MOPSULA_WORDS[4].capitalize()
	assert_ne(IpWords.general_word(ip_name), "", "the probe hits ALL_WORDS: " + ip_name)
	assert_ne(IpWords.mopsula_word(royal), "", "the probe hits the Mopsula rule: " + royal)
	var own: PackedStringArray = _ip_errors(_variant(ip_name, royal, false))
	assert_true(Kit.has_error(own, "enemies[") and Kit.has_error(own, "(IP distance"), "no licence: " + str(own))
	assert_true(Kit.has_error(own, "party[") and Kit.has_error(own, "(no royalty motif"), "no licence: " + str(own))
	assert_eq(_ip_errors(_variant(ip_name, royal, true)), PackedStringArray(),
		"licensed: its own texts are exempt from ALL_WORDS and the Mopsula rule (he is redesigned)")


func test_licence_never_exempts_tone() -> void:
	var origin: String = "Ein Gast aus %s" % IpWords.ORIGIN_WORDS[0].capitalize()
	var errs: PackedStringArray = _variant(origin, "Fixture-Graf", true)
	assert_true(Kit.has_error(errs, "(tone: no nationality"), "ORIGIN_WORDS hold for licensed texts: " + str(errs))
	var brand: String = _tone_word("real_brands")
	assert_ne(brand, "")
	errs = _variant("Die %s-Ratte" % brand.capitalize(), "Fixture-Graf", true)
	assert_true(Kit.has_error(errs, "pack[lizenztest].enemies[enm_kanalratte].name: tone list 'real_brands'"),
		"the tone lists are a rule for licensed packs too: " + str(errs))
	var ref: String = "enemies:enm_kanalratte.name"
	errs = _variant("Die %s-Ratte" % brand.capitalize(), "Fixture-Graf", true, {"tone_exceptions":
		[{"ref": ref, "list": "real_brands", "reason": "Review 2026-10-13: Testfall"}]})
	assert_false(Kit.has_error(errs, "tone list"), "a reviewed false alarm (tone_exceptions): " + str(errs))
	errs = _variant("Fixture-Ratte", "Fixture-Graf", true, {"tone_exceptions": [{"ref": ref, "list": "politics",
		"reason": "x"}, {"ref": ref, "list": "real_brands", "reason": ""}, {"ref": "enemies:enm_fehlt.name",
		"list": "real_brands", "reason": "x"}]})
	assert_true(Kit.has_error(errs, "tone_exceptions[0].list: 'politics' never has an exception"), str(errs))
	assert_true(Kit.has_error(errs, "tone_exceptions[1].reason: every exception names its review"), str(errs))
	assert_true(Kit.has_error(errs, "tone_exceptions[2].ref: 'enemies:enm_fehlt.name' is no text of this pack"),
		str(errs))


func test_exemption_covers_only_the_packs_own_texts() -> void:
	var raw: Dictionary = Kit.base_raw()
	var probe: String = "Die %s-Bande" % IpWords.ALL_WORDS[3].capitalize()
	for e: Variant in ((raw["enemies"] as Dictionary)["entries"] as Array):
		if str((e as Dictionary).get("id", "")) == "enm_kanalschleim":
			(e as Dictionary)["name"] = probe              # a base text the pack does not own
	var errs: PackedStringArray = _ip_errors(_variant(probe, "Fixture-Graf", true, {}, raw))
	assert_true(Kit.has_error(errs, "enm_kanalschleim].name"), "the base text is still checked: " + str(errs))
	assert_false(Kit.has_error(errs, "enm_kanalratte].name"), "the pack's own text is exempt: " + str(errs))


func test_pack_rules_need_a_provenance() -> void:
	assert_eq(PackCheck.tone_hit("Die Testbild-Königin von Gleis 9"), "", "Testbild's texts are clean")
	var texts: Array[Dictionary] = PackCheck.pack_texts(PackLoader.read(Kit.PACKS, Kit.TESTBILD))
	var refs: PackedStringArray = []
	for t: Dictionary in texts:
		refs.append(str(t["ref"]))
	assert_eq(refs, PackedStringArray(["pack:name", "enemies:enm_boss_rattenkoenigin.name", "looks:lk_outfit_testbild.name",
		"mod_lines:mod_boss_intro_enm_boss_rattenkoenigin_02.text"]), "every text of Testbild")
	var v: DataValidator = DataValidator.new()
	v.validate(Kit.base_raw())
	assert_eq([v.provenance, v.errors], [{}, PackedStringArray()], "base data: no provenance, no pack rule")
	var lic: PackDef = PackLoader.read(FIXTURES_DIR, Kit.LIZENZTEST)
	var stripped: PackDef = PackDef.new()
	stripped.id = "probe"
	stripped.licence = {"holder": Kit.TEST_HOLDER, "credits": []}
	var v2: DataValidator = DataValidator.new()
	PackCheck.check(v2, {"def": stripped})
	assert_true(Kit.has_error(v2.errors, "pack[probe].licence.credits: a licensed pack names its credits"))
	assert_true(lic.has_licence() and not (lic.licence["credits"] as Array).is_empty(), "the fixture names credits")
