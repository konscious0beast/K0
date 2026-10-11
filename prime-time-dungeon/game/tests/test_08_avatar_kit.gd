extends TestCase
## 08 §6 (K2): the persona look in the procedural kit. Part caps (R18: a hair style ≤ short + 150 tris, a beard ≤ 100,
## glasses = the unchanged prop) and EVERY hair × beard × glasses combination ≤ 3 000 tris in exactly Kai's 7
## MeshInstances (CR-22 as decided: hair, beard and glasses merge into the Head mesh — no new draw call); colours never
## change the geometry; the canon look is exactly today's Kai (2 492 tris, 7 meshes, the cached def meshes); the style
## vocabularies match DataValidator; the mesh cache keys the style; PersonaLook.apply (ids → style / glasses prop /
## colour slots; unknown or foreign ids → canon; only humanoids); data/looks.json (counts, names, glyphs, neutral skin
## names) and the validator rules of validators/looks.gd; DB.party_model mixes the running persona's look only into
## kai; the CTB battle shows the look on the stage and in the HUD portrait while StateHash.of_battle stays the same;
## the look galleries run.

const BATTLE_SCENE: String = "res://scenes/battle/battle.tscn"
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const GALLERIES: PackedStringArray = ["res://art/gallery/look_gallery.tscn", "res://art/gallery/hair_gallery.tscn"]
## 08 §6.2 / R18 and CR-22 (orchestrator decision: <= 3 000 tris, MeshInstances stay at Kai's 7).
const CANON_TRIS: int = 2492
const CANON_MESHES: int = 7
const HAIR_ADD_MAX: int = 150
const BEARD_MAX: int = 100
const GLASSES_TRIS: int = 212
const LOOK_TRIS_MAX: int = 3000
const COUNTS: Dictionary = {"hair": 9, "hair_color": 8, "skin": 8, "beard": 4, "glasses": 2, "outfit": 8}

var _saved_persona: PersonaProfile = null


func before_each() -> void:
	_saved_persona = Game.persona
	Game.persona = null


func after_each() -> void:
	Game.persona = _saved_persona
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false
	Game.timer_running = false
	Engine.time_scale = 1.0
	Router.adopt(null)
	Sfx.music(&"", 0.0)


func _kai() -> Dictionary:
	return DB.data.party_member("kai").model.duplicate(true)


## [tris, MeshInstances, Head-mesh tris] of a rig built from `model` (MeshUtil.tri_count, hull not counted).
func _measure(model: Dictionary) -> Array[int]:
	var rig: CharacterRig = CharacterBuilder.build(model, 0)
	var tris: int = 0
	var meshes: int = 0
	var head: int = 0
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var t: int = MeshUtil.tri_count((n as MeshInstance3D).mesh)
		tris += t
		meshes += 1
		if n.name == "HeadMesh":
			head = t
	rig.free()
	return [tris, meshes, head]


func _styled(hair: String, beard: String, glasses: bool) -> Dictionary:
	var m: Dictionary = _kai()
	m["style"] = {"hair": hair, "beard": beard}
	if glasses:
		var props: Array = Array(m.get("props", []))
		props.append("glasses")
		m["props"] = props
	return m


# --- budgets ----------------------------------------------------------------------------------------------------------

func test_canon_kai_is_todays_kai() -> void:
	var canon: Dictionary = PersonaProfile.canon_look(DB.data)
	var kai: Dictionary = _kai()
	assert_eq(PersonaLook.apply(kai, canon, DB.data), kai, "the canon look leaves the def model exactly as it is")
	assert_eq(PersonaLook.apply(kai, {}, DB.data), kai, "no look = the canon look")
	assert_eq(_measure(kai).slice(0, 2), [CANON_TRIS, CANON_MESHES], "measured base (08 §6.2): 2 492 tris, 7 meshes")
	var a: CharacterRig = CharacterBuilder.build(kai, 0)
	var b: CharacterRig = CharacterBuilder.build(PersonaLook.apply(kai, canon, DB.data), 0)
	var ma: Array[Node] = a.find_children("*", "MeshInstance3D", true, false)
	var mb: Array[Node] = b.find_children("*", "MeshInstance3D", true, false)
	assert_eq(ma.size(), mb.size())
	for i in mini(ma.size(), mb.size()):
		assert_eq(str(ma[i].name), str(mb[i].name))
		assert_true((ma[i] as MeshInstance3D).mesh == (mb[i] as MeshInstance3D).mesh, "the same cached mesh: " + ma[i].name)
	a.free()
	b.free()
	var unstyled: Dictionary = _kai()
	unstyled["style"] = {"hair": "short", "beard": "none"}
	assert_eq(_measure(unstyled), _measure(kai), "an explicit canon style = no style")


func test_part_caps_per_hair_style_and_beard() -> void:
	var base: Array[int] = _measure(_kai())
	for hair: String in CharacterBuilder.supported_hair_styles():
		var r: Array[int] = _measure(_styled(hair, "none", false))
		assert_true(r[0] - base[0] <= HAIR_ADD_MAX, "%s: %+d tris over short (<= +%d)" % [hair, r[0] - base[0],
			HAIR_ADD_MAX])
		assert_eq(r[1], CANON_MESHES, hair + ": no new MeshInstance")
		assert_eq(r[0] - base[0], r[2] - base[2], hair + ": every hair part is in the Head mesh")
	for beard: String in CharacterBuilder.supported_beards():
		var r2: Array[int] = _measure(_styled("short", beard, false))
		assert_true(r2[0] - base[0] <= BEARD_MAX, "%s: %d tris (<= %d)" % [beard, r2[0] - base[0], BEARD_MAX])
		assert_eq(r2[1], CANON_MESHES, beard + ": no new MeshInstance")
		assert_eq(r2[0] - base[0], r2[2] - base[2], beard + ": in the Head mesh")
	var g: Array[int] = _measure(_styled("short", "none", true))
	assert_eq(g[0] - base[0], GLASSES_TRIS, "glasses = the existing prop (08 §6.2: +212)")
	assert_eq([g[1], g[2] - base[2]], [CANON_MESHES, GLASSES_TRIS], "glasses in the Head mesh")
	assert_eq(_measure(_styled("short", "none", false)), base, "short/none = canon")


## Every hair × beard × glasses combination (9 × 4 × 2 = 72): <= 3 000 tris, exactly 7 MeshInstances.
func test_every_combination_within_the_persona_budget() -> void:
	var worst: int = 0
	var worst_of: String = ""
	var n: int = 0
	for hair: String in CharacterBuilder.supported_hair_styles():
		for beard: String in CharacterBuilder.supported_beards():
			for glasses: bool in [false, true]:
				var r: Array[int] = _measure(_styled(hair, beard, glasses))
				var what: String = "%s/%s/%s" % [hair, beard, "glasses" if glasses else "-"]
				assert_true(r[0] <= LOOK_TRIS_MAX, "%s: %d tris <= %d" % [what, r[0], LOOK_TRIS_MAX])
				assert_eq(r[1], CANON_MESHES, what + ": MeshInstances")
				n += 1
				if r[0] > worst:
					worst = r[0]
					worst_of = what
	assert_eq(n, 72)
	print("[test_08_avatar_kit] worst case %d tris (%s), %d MeshInstances" % [worst, worst_of, CANON_MESHES])
	assert_true(worst <= CANON_TRIS + HAIR_ADD_MAX + BEARD_MAX + GLASSES_TRIS, "within the summed part caps")


func test_colours_never_change_the_geometry() -> void:
	var base: Array[int] = _measure(PersonaLook.apply(_kai(), {"hair": "lk_hair_curls"}, DB.data))
	for kind: String in ["hair_color", "skin", "outfit"]:
		for e: Dictionary in DB.data.looks_of(kind):
			var r: Array[int] = _measure(PersonaLook.apply(_kai(), {"hair": "lk_hair_curls", kind: str(e["id"])}, DB.data))
			assert_eq(r, base, "%s %s: only vertex colours change" % [kind, e["id"]])


func test_vocabularies_and_the_mesh_cache() -> void:
	assert_eq(CharacterBuilder.supported_hair_styles(), DataValidator.MODEL_HAIR_STYLES)
	assert_eq(CharacterBuilder.supported_beards(), DataValidator.MODEL_BEARDS)
	var n: Dictionary = CharacterBuilder.normalize(_styled("bun", "full", false))
	assert_eq(n["style"], {"hair": "bun", "beard": "full"})
	assert_eq(CharacterBuilder.normalize({"base": "pug", "style": {"hair": "bun"}})["style"], {}, "humanoid only")
	assert_eq(CharacterBuilder.normalize(_kai())["style"], {"hair": "short", "beard": "none"}, "the canon default")
	var bad: Dictionary = _kai()
	bad["style"] = {"hair": "mohawk", "beard": "goatee"}
	assert_eq(CharacterBuilder.normalize(bad)["style"], {"hair": "short", "beard": "none"}, "unknown → canon")
	var bun1: CharacterRig = CharacterBuilder.build(_styled("bun", "none", false), 0)
	var bun2: CharacterRig = CharacterBuilder.build(_styled("bun", "none", false), 0)
	var curls: CharacterRig = CharacterBuilder.build(_styled("curls", "none", false), 0)
	var h1: Mesh = (bun1.find_child("HeadMesh", true, false) as MeshInstance3D).mesh
	assert_true(h1 == (bun2.find_child("HeadMesh", true, false) as MeshInstance3D).mesh, "same style → cached mesh")
	assert_false(h1 == (curls.find_child("HeadMesh", true, false) as MeshInstance3D).mesh, "the style is in the key")
	var t1: Mesh = (bun1.find_child("TorsoMesh", true, false) as MeshInstance3D).mesh
	var t2: Mesh = (curls.find_child("TorsoMesh", true, false) as MeshInstance3D).mesh
	assert_eq(t1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], t2.surface_get_arrays(0)[Mesh.ARRAY_VERTEX],
		"the other parts keep their geometry")
	for r: CharacterRig in [bun1, bun2, curls]:
		r.free()


# --- PersonaLook ------------------------------------------------------------------------------------------------------

func test_persona_look_apply() -> void:
	var kai: Dictionary = _kai()
	var look: Dictionary = {"hair": "lk_hair_headscarf", "hair_color": "lk_hc_blue", "skin": "lk_skin_7",
		"beard": "lk_beard_stubble", "glasses": "lk_glasses_round", "outfit": "lk_outfit_orange"}
	var m: Dictionary = PersonaLook.apply(kai, look, DB.data)
	assert_eq(m["style"], {"hair": "headscarf", "beard": "stubble"})
	assert_eq(m["colors"], {"primary": "#f28c28", "secondary": "#3a3f4b", "accent": "#3a6fd9", "skin": "#6b4128",
		"eyes": "#1a1420"}, "hair colour → accent, skin, outfit → primary / secondary (eyes stay)")
	assert_eq(Array(m["props"]), ["mop", "glasses"], "glasses = the prop")
	assert_eq(_kai(), kai, "pure: the input model is untouched")
	var foreign: Dictionary = PersonaLook.apply(kai, {"hair": "lk_hc_blue", "skin": "lk_nope"}, DB.data)
	assert_eq(foreign, kai, "an id of another kind or an unknown id counts as canon (08 §2.5)")
	var off: Dictionary = kai.duplicate(true)
	off["props"] = Array(off["props"]) + ["glasses"]
	assert_eq(Array(PersonaLook.apply(off, {"glasses": "lk_glasses_none"}, DB.data)["props"]), ["mop"],
		"\"ohne\" takes the prop off")
	var pug: Dictionary = DB.data.party_member("mopsula").model
	assert_eq(PersonaLook.apply(pug, look, DB.data), pug, "only humanoids wear a look")
	var no_looks: GameData = GameData.new()
	assert_eq(PersonaLook.apply(kai, look, no_looks), kai, "a data set without looks.json: unchanged")
	assert_eq(PersonaLook.ids({"hair": "lk_hair_bun", "skin": "lk_hair_long"}, DB.data),
		{"hair": "lk_hair_bun", "hair_color": "lk_hc_darkbrown", "skin": "lk_skin_3", "beard": "lk_beard_none",
		"glasses": "lk_glasses_none", "outfit": "lk_outfit_petrol"})
	assert_eq(PersonaLook.swatch(DB.data.look("lk_outfit_white")), Color("#E8EEF0"))
	assert_eq(PersonaLook.swatch(DB.data.look("lk_hair_bun")).a, 0.0, "no swatch for styles")


func test_party_model_only_dresses_kai_with_a_persona() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.look = {"hair": "lk_hair_braids", "hair_color": "lk_hc_red", "skin": "lk_skin_5", "beard": "lk_beard_none",
		"glasses": "lk_glasses_none", "outfit": "lk_outfit_green"}
	assert_eq(DB.party_model("kai"), _kai(), "no persona: the def model")
	Game.persona = p
	assert_eq(DB.party_model("kai"), PersonaLook.apply(_kai(), p.look, DB.data))
	assert_eq((DB.party_model("kai")["style"] as Dictionary)["hair"], "braids")
	assert_eq(DB.party_model("mopsula"), DB.data.party_member("mopsula").model, "the Count keeps his fur")
	assert_eq(DB.party_model("nobody"), {})
	var fig: Node3D = SceneKit.party_figure("kai")
	assert_eq(fig.get("model"), DB.party_model("kai"), "safe room / intro figures wear the look")
	fig.free()
	var canon_fig: Node3D = SceneKit.canon_figure("kai")
	assert_eq(canon_fig.get("model"), _kai(), "the hero select of a new game: never the previous game's look")
	canon_fig.free()
	var look_fig: Node3D = SceneKit.look_figure({"hair": "lk_hair_bald"})
	assert_eq(((look_fig.get("model") as Dictionary)["style"] as Dictionary)["hair"], "bald", "the casting preview")
	look_fig.free()
	p.look = PersonaProfile.canon_look(DB.data)
	assert_eq(DB.party_model("kai"), _kai(), "the canon persona (Rest automatisch) = today's Kai")


# --- data and validator -----------------------------------------------------------------------------------------------

func test_looks_data() -> void:
	var data: GameData = real_data()
	var names: Dictionary = {}
	for kind: String in COUNTS:
		var list: Array[Dictionary] = data.looks_of(kind)
		assert_eq(list.size(), int(COUNTS[kind]), "options of " + kind)
		var canons: int = 0
		for e: Dictionary in list:
			canons += 1 if bool(e.get("canon", false)) else 0
			var name: String = str(e["name"])
			assert_true(name.length() <= 16, "%s: short name" % e["id"])
			assert_eq(UiUtil.missing_glyphs(name), "", "%s: every glyph in the UI font" % e["id"])
			assert_false(names.has(kind + name), "%s: name unique in its kind" % e["id"])
			names[kind + name] = true
		assert_eq(canons, 1, "one canon option: " + kind)
	for e: Dictionary in data.looks_of("skin"):
		assert_true(str(e["name"]).begins_with("Ton "), "neutral skin tone names (no attributions): " + str(e["name"]))
	var styles: Array = []
	for e: Dictionary in data.looks_of("hair"):
		styles.append(str(e["style"]))
	assert_eq(PackedStringArray(styles), DataValidator.MODEL_HAIR_STYLES, "every hair style once, in vocabulary order")
	for want: String in ["bald", "short", "long", "curls", "bun", "braids", "headscarf"]:
		assert_has(styles, want, "inclusive set: " + want)
	assert_true(data.look("lk_hair_headscarf").get("name", "") == "Kopftuch")
	var fixture: GameData = GameData.new()
	assert_true(fixture.load_dir("res://tests/fixtures/data_min"), "; ".join(fixture.errors))
	assert_eq(PersonaProfile.canon_look(fixture), PersonaProfile.canon_look(data), "fixtures: the canon look only")


func test_validator_rules() -> void:
	var cases: Array = [
		[{"id": "lk_hair_mohawk", "kind": "hair", "name": "Irokese", "style": "mohawk"}, "not in"],
		[{"id": "lk_hc_neon", "kind": "hair_color", "name": "Neon", "color": "neon"}, "hex color"],
		[{"id": "lk_skin_9", "kind": "skin", "name": "Hell", "color": "#FFEEDD"}, "Ton <n>"],
		[{"id": "lk_skin_10", "kind": "skin", "name": "Ton 10", "color": "#E8B48F"}, "the same color as lk_skin_3"],
		[{"id": "lk_hair_kurz2", "kind": "hair", "name": "Kurz", "style": "buzz"}, "'Kurz' twice"],
		[{"id": "lk_beard_red", "kind": "beard", "name": "Rot", "style": "full", "color": "#FF0000"}, "not a field"],
		[{"id": "lk_outfit_half", "kind": "outfit", "name": "Halb", "colors": {"primary": "#FFFFFF"}}, "secondary"],
		[{"id": "lk_glasses_mono", "kind": "glasses", "name": "Monokel", "style": "monocle"}, "not in"],
		[{"id": "lk_hair_two", "kind": "hair", "name": "Zweiter Kanon", "style": "bald", "canon": true},
			"exactly one canon"],
		[{"id": "lk_hair_x", "kind": "hats", "name": "Hut"}, "kind"],
	]
	var raw: Dictionary = _raw_tables()
	assert_true(GameData.new().load_from_tables(raw.duplicate(true)), "the real data validates")
	for c: Array in cases:
		var r: Dictionary = raw.duplicate(true)
		var entries: Array = (r["looks"] as Dictionary)["entries"]
		if str((c[0] as Dictionary)["id"]) == "lk_hair_two":
			for e: Variant in entries:
				if str((e as Dictionary)["id"]) == "lk_hair_bald":
					entries.erase(e)
					break
		entries.append(c[0])
		var d: GameData = GameData.new()
		assert_false(d.load_from_tables(r), "rejected: " + str(c[0]))
		assert_has("; ".join(d.errors), str(c[1]))
	var no_canon: Dictionary = raw.duplicate(true)
	for e: Variant in ((no_canon["looks"] as Dictionary)["entries"] as Array):
		if str((e as Dictionary)["id"]) == "lk_outfit_petrol":
			(e as Dictionary).erase("canon")
	var nd: GameData = GameData.new()
	assert_false(nd.load_from_tables(no_canon))
	assert_has("; ".join(nd.errors), "exactly one canon option needed (none)")
	var not_kai: Dictionary = raw.duplicate(true)
	for e: Variant in ((not_kai["looks"] as Dictionary)["entries"] as Array):
		var le: Dictionary = e
		if str(le["id"]) == "lk_hc_darkbrown":
			le["color"] = "#3B2A23"
	var kd: GameData = GameData.new()
	assert_false(kd.load_from_tables(not_kai), "the canon look must stay Kai's party.json colours")
	assert_has("; ".join(kd.errors), "not Kai's")


func _raw_tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		raw[t] = JsonUtil.read_file("res://data/%s.json" % t)
	raw["rt_balance"] = JsonUtil.read_file("res://data/" + GameData.RT_BALANCE_FILE)
	return raw


# --- the CTB battle (08 §6.3: Game._persona_battle_look) ------------------------------------------------------------

func test_ctb_battle_shows_the_look_with_the_same_hash() -> void:
	Engine.time_scale = 8.0
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = "Jana"
	p.look = {"hair": "lk_hair_curls", "hair_color": "lk_hc_black", "skin": "lk_skin_7", "beard": "lk_beard_full",
		"glasses": "lk_glasses_round", "outfit": "lk_outfit_blue"}
	Game.new_game(0, "Jana", 4242, &"prime", "kai", p)
	var setup: BattleSetup = Game.make_battle_setup("enc_f1_a2", BattleSetup.Advantage.NORMAL, "")
	assert_not_null(setup)
	var kai: Combatant = null
	for c: Combatant in setup.party:
		if c.def_id == "kai":
			kai = c
	assert_not_null(kai)
	if kai == null:
		return
	assert_eq(kai.model, DB.party_model("kai"), "the kai combatant carries the persona look")
	assert_eq((kai.model["style"] as Dictionary), {"hair": "curls", "beard": "full"})
	var with_look: String = _battle_hash(setup)
	assert_ne(with_look, "")
	kai.model = DB.data.party_member("kai").model.duplicate(true)
	assert_eq(_battle_hash(setup), with_look, "the look is presentation only (StateHash.of_battle unchanged)")
	kai.model = DB.party_model("kai")
	var started: BattleState = BattleState.new(setup, DB.data)
	started.start()
	var input: String = JSON.stringify(StateHash.battle_hash_input(started))
	for word: String in ["curls", "lk_hair", "lk_skin", "#6b4128", "#1f1a1a"]:
		assert_false(input.contains(word), "no look in the hash input: " + word)
	var scene: Node = (load(BATTLE_SCENE) as PackedScene).instantiate()
	scene.call("setup", {"setup": setup, "capture": true, "stay": true, "speed": 4.0})
	add_to_tree(scene)
	await wait_frames(4)
	var stage: Node = scene.get("stage")
	var info: Dictionary = stage.call("info", kai.id)
	assert_eq(info.get("model", {}), kai.model, "the stage builds kai in the look")
	var rig: Node = scene.find_child("Unit_" + kai.id, true, false)
	assert_not_null(rig, "kai's stage rig")
	if rig != null:
		assert_eq((rig.get("model") as Dictionary).get("style", {}), {"hair": "curls", "beard": "full"})
	var hud: Node = scene.get("hud")
	var tex: Texture2D = hud.call("portrait", kai.id)
	assert_not_null(tex, "kai's HUD portrait")
	var portrait_rig: Node = null
	for vp: Node in hud.find_children("Portrait*", "SubViewport", true, false):
		var r: Node = vp.get_node_or_null("Rig")
		if r != null and str((r.get("model") as Dictionary).get("base", "")) == "humanoid":
			portrait_rig = r
	assert_not_null(portrait_rig, "a humanoid portrait")
	if portrait_rig != null:
		assert_eq((portrait_rig.get("model") as Dictionary).get("style", {}), {"hair": "curls", "beard": "full"},
			"the portrait wears the look")
	Game.persona = null
	var plain: BattleSetup = Game.make_battle_setup("enc_f1_a2", BattleSetup.Advantage.NORMAL, "")
	for c: Combatant in plain.party:
		if c.def_id == "kai":
			assert_eq(c.model, DB.data.party_member("kai").model, "no persona: the def model")


## StateHash.of_battle of a started BattleState of `setup` (an unstarted state has an unseeded RNG).
func _battle_hash(setup: BattleSetup) -> String:
	var b: BattleState = BattleState.new(setup, DB.data)
	b.start()
	return StateHash.of_battle(b)


# --- galleries -------------------------------------------------------------------------------------------------------

func test_look_galleries_run() -> void:
	for path: String in GALLERIES:
		var inst: Node = (load(path) as PackedScene).instantiate()
		add_to_tree(inst)
		await wait_frames(4)
		var rigs: Dictionary = inst.get("rigs")
		assert_true(rigs.size() >= 8, "%s: %d figures" % [path, rigs.size()])
		for r: Variant in rigs.values():
			assert_eq(str(((r as Node).get("model") as Dictionary).get("base", "")), "humanoid")
		inst.get_parent().remove_child(inst)
		inst.free()
