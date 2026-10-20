extends TestCase
## 11-A1 (11 §4.10): the art kit's extensions. The cat base (both poses through resolve_pose, both fur lengths, every
## pattern): builds, ≤ 1 600 tris and the enemy budget in its 3 meshes, the sockets head / neck / back / tail_tip, the
## colour slots, ≈ 0.5 m. The six props within their budgets on the bases they are made for (tiara also on the pug's
## and the cat's head, sunglasses also on the cat), merged into existing meshes. The style vocabularies in one place
## (Archetypes.STYLES == CharacterBuilder.supported_styles() == DataValidator.MODEL_STYLES) and the validator's style
## keys per base. The look kind wear (PersonaLook.apply / ids, the persona's worst case ≤ 3 000 tris in 7 meshes,
## looks.json). The contract lists. PTD's rules 1–3 as validator cases and rule 4 (a licensed pack is exempt for its
## own entries, end to end through art.json and a looks overlay). The cat and kit galleries run every view.

const Archetypes := preload("res://art/kit/archetypes.gd")
const LooksCheck := preload("res://core/data/validators/looks.gd")
const ArtKitRules := preload("res://core/data/validators/art_kit.gd")
const SpeciesRules := preload("res://core/data/validators/species.gd")
const Kit := preload("res://tests/fixtures/packs/pack_kit.gd")
const NEW_PROPS: PackedStringArray = ["tiara", "sunglasses", "bathrobe", "sandals", "shorts", "jacket"]
## 11 §4.10: the cat ≤ 1 600 tris and ≤ 3 meshes; every style also within the enemy budget (02_TECH §12.1), since cats
## appear as enemies.
const CAT_TRIS_MAX: int = 1600
const CAT_MESHES_MAX: int = 3
const ENEMY_TRIS_MAX: int = 1500
## 11 §4.10 per prop: the most the prop may add to a figure (tris; the clothing replaces parts of the humanoid).
const PROP_TRIS_MAX: Dictionary = {"tiara": 150, "sunglasses": 220, "bathrobe": 300, "sandals": 120, "shorts": 200,
	"jacket": 300}
## The bases each prop is made for (11 §4.10; tiara also on pug and cat heads, sunglasses also on the cat).
const PROP_BASES: Dictionary = {"tiara": ["humanoid", "pug", "cat"], "sunglasses": ["humanoid", "cat"],
	"bathrobe": ["humanoid"], "sandals": ["humanoid"], "shorts": ["humanoid"], "jacket": ["humanoid"]}
## CR-22 (08 §6, as decided): the persona ≤ 3 000 tris in exactly Kai's 7 MeshInstances.
const PERSONA_TRIS_MAX: int = 3000
const PERSONA_MESHES: int = 7
const GALLERIES: Dictionary = {"res://art/gallery/cat_gallery.tscn": ["", "close", "game", "fur", "sit", "patterns"],
	"res://art/gallery/kit_gallery.tscn": ["", "close", "heads", "persona"]}
const ROOT: String = "user://test_11_art_kit"

var _raw_cache: Dictionary = {}


# --- helpers ---------------------------------------------------------------------------------------------------------

## [tris, MeshInstances] of a rig built from `model` (MeshUtil.tri_count, hull not counted).
func _measure(model: Dictionary) -> Array[int]:
	var rig: CharacterRig = CharacterBuilder.build(model, 0)
	var tris: int = 0
	var meshes: int = 0
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		tris += MeshUtil.tri_count((n as MeshInstance3D).mesh)
		meshes += 1
	rig.free()
	return [tris, meshes]


func _cat(fur: String, pattern: String, pose: String = "auto", colors: Dictionary = {}) -> Dictionary:
	return {"base": "cat", "pose": pose, "colors": colors, "props": [], "style": {"fur": fur, "pattern": pattern}}


## Every vertex colour of the rig's meshes as "rrggbb".
func _vertex_colors(model: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var rig: CharacterRig = CharacterBuilder.build(model, 0)
	for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var am: ArrayMesh = (n as MeshInstance3D).mesh as ArrayMesh
		if am == null:
			continue
		for s in am.get_surface_count():
			for c: Color in (am.surface_get_arrays(s)[Mesh.ARRAY_COLOR] as PackedColorArray):
				out[c.to_html(false)] = true
	rig.free()
	return out


func _blueprint(model: Dictionary) -> Dictionary:
	return Archetypes.blueprint(CharacterBuilder.normalize(model), 0)


## The tris of the parts `prop` adds to `model` (a part = mesh, primitive and transform; a recoloured part — the
## garment's sleeves — is the same part): what the prop costs before the parts it replaces are subtracted.
func _added_tris(model: Dictionary, prop: String) -> int:
	var m: Dictionary = model.duplicate(true)
	var props: Array = Array(m.get("props", []))
	props.append(prop)
	m["props"] = props
	var before: Dictionary = _part_counts(_blueprint(model))
	var after: Dictionary = _part_counts(_blueprint(m))
	var added: int = 0
	for k: String in after:
		var extra: int = int((after[k] as Array)[0]) - int((before.get(k, [0, 0]) as Array)[0])
		added += maxi(extra, 0) * int((after[k] as Array)[1])
	return added


## part key → [count, tris] of a blueprint.
static func _part_counts(bp: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for mn: Variant in (bp["meshes"] as Dictionary):
		for p: Dictionary in ((bp["meshes"][mn] as Dictionary)["parts"] as Array):
			var mesh: Mesh = p["mesh"]
			var prim: String = MeshUtil._prim_key(mesh as PrimitiveMesh) if mesh is PrimitiveMesh else str(mesh)
			var key: String = "%s|%s|%s" % [str(mn), prim, str(p["xform"])]
			if not out.has(key):
				out[key] = [0, MeshUtil.tri_count(mesh)]
			(out[key] as Array)[0] = int((out[key] as Array)[0]) + 1
	return out


## The raw tables of res://data (cached; callers get a deep copy).
func _raw() -> Dictionary:
	if _raw_cache.is_empty():
		_raw_cache = Kit.base_raw()
	return _raw_cache.duplicate(true)


static func _entry(raw: Dictionary, table: String, id: String) -> Dictionary:
	for e: Variant in ((raw[table] as Dictionary)["entries"] as Array):
		if str((e as Dictionary).get("id", "")) == id:
			return e
	return {}


## The validation errors of `raw` (+ a provenance).
static func _errors(raw: Dictionary, provenance: Dictionary = {}) -> PackedStringArray:
	var v: DataValidator = DataValidator.new()
	v.validate(raw, true, {}, provenance)
	return v.errors


static func _art_errors(errors: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: String in errors:
		if e.contains("11 §4.10 rule") or e.contains("no crown motif"):
			out.append(e)
	return out


# --- contract (11 §4.10 "Vertrag") ------------------------------------------------------------------------------------

func test_contract_lists() -> void:
	assert_eq(DataValidator.MODEL_BASES[DataValidator.MODEL_BASES.size() - 1], "cat", "MODEL_BASES += cat (last)")
	for p: String in NEW_PROPS:
		assert_has(DataValidator.MODEL_PROPS, p, "MODEL_PROPS += " + p)
	assert_eq(CharacterBuilder.supported_bases(), DataValidator.MODEL_BASES)
	assert_eq(CharacterBuilder.supported_props(), DataValidator.MODEL_PROPS)
	assert_eq(Archetypes.BASES, DataValidator.MODEL_BASES)
	assert_eq(Archetypes.PROPS, DataValidator.MODEL_PROPS)
	assert_almost(float(Archetypes.NOMINAL_HEIGHT["cat"]), 0.5, 0.0001, "NOMINAL_HEIGHT ≈ 0.5 m")
	for slot: String in ["primary", "secondary", "accent", "eyes"]:
		assert_true(DataValidator.is_hex_color(str((Archetypes.DEFAULT_COLORS["cat"] as Dictionary)[slot])),
			"DEFAULT_COLORS cat." + slot)
	assert_eq(CharacterBuilder.supported_styles(), DataValidator.MODEL_STYLES, "style vocabularies, one per base")
	assert_eq(Archetypes.STYLES, DataValidator.MODEL_STYLES)
	assert_eq((Archetypes.STYLES["cat"] as Dictionary).keys(), ["fur", "pattern"])
	assert_eq(Archetypes.CAT_FURS, DataValidator.MODEL_CAT_FURS)
	assert_eq(Archetypes.CAT_PATTERNS, DataValidator.MODEL_CAT_PATTERNS)
	assert_eq(Archetypes.CAT_FURS, PackedStringArray(["short", "long"]))
	assert_eq(Archetypes.CAT_PATTERNS, PackedStringArray(["solid", "tabby", "tortie", "bicolor", "calico"]))
	assert_eq(Archetypes.CAT_FUR.keys(), Array(Archetypes.CAT_FURS), "a recipe per fur length")
	assert_eq(Archetypes.CAT_MARKINGS.keys(), Array(Archetypes.CAT_PATTERNS), "markings per pattern")
	assert_eq(CharacterBuilder.supported_hair_styles(), (DataValidator.MODEL_STYLES["humanoid"] as Dictionary)["hair"])
	assert_has(PersonaLook.KINDS, "wear", "PersonaLook.KINDS += wear")
	assert_eq(LooksCheck.KINDS, PersonaLook.KINDS, "looks.json kinds == PersonaLook.KINDS")
	assert_eq(LooksCheck.WEAR_STYLES, PackedStringArray([PersonaLook.WEAR_NONE]) + PersonaLook.WEAR_PROPS)
	for w: String in PersonaLook.WEAR_PROPS:
		assert_has(DataValidator.MODEL_PROPS, w, "a wear option is a prop: " + w)
	assert_eq(SpeciesRules.MOPSULA_FORBIDDEN_PROPS, PackedStringArray(["crown", "ticket_crown", "tiara"]), "rule 1")


# --- the cat ---------------------------------------------------------------------------------------------------------

func test_cat_pose_rule() -> void:
	for scale: float in [0.6, 1.0, 2.0]:
		assert_eq(CharacterBuilder.resolve_pose({"base": "cat", "scale": scale}), &"quadruped", "auto stands")
		assert_eq(CharacterBuilder.resolve_pose({"base": "cat", "pose": "quadruped", "scale": scale}), &"quadruped")
		assert_eq(CharacterBuilder.resolve_pose({"base": "cat", "pose": "upright", "scale": scale}), &"upright", "sits")
	assert_eq(CharacterBuilder.resolve_pose({"base": "pug", "pose": "upright"}), &"quadruped", "the pug is unchanged")


func test_every_cat_builds_within_budget() -> void:
	for pose: String in ["auto", "upright"]:
		for fur: String in Archetypes.CAT_FURS:
			for pattern: String in Archetypes.CAT_PATTERNS:
				var what: String = "cat %s %s %s" % [pose, fur, pattern]
				var r: Array[int] = _measure(_cat(fur, pattern, pose))
				assert_true(r[0] <= CAT_TRIS_MAX, "%s: %d tris > %d" % [what, r[0], CAT_TRIS_MAX])
				assert_true(r[0] <= ENEMY_TRIS_MAX, "%s: %d tris > the enemy budget %d" % [what, r[0], ENEMY_TRIS_MAX])
				assert_eq(r[1], CAT_MESHES_MAX, what + ": Body, Head, Tail")
				var rig: CharacterRig = CharacterBuilder.build(_cat(fur, pattern, pose), 0)
				var names: PackedStringArray = []
				for n: Node in rig.find_children("*", "MeshInstance3D", true, false):
					names.append(str(n.name))
				names.sort()
				assert_eq(names, PackedStringArray(["BodyMesh", "HeadMesh", "TailMesh"]), what)
				if pose == "auto":
					assert_between(rig.height, 0.45, 0.55, "%s: ≈ 0.5 m (NOMINAL_HEIGHT ± 10 %%)" % what)
				else:
					assert_between(rig.height, 0.45, 0.6, "%s: sitting up, the head a little higher" % what)
				rig.free()


func test_cat_sockets_and_anchors() -> void:
	for pose: String in ["auto", "upright"]:
		for fur: String in Archetypes.CAT_FURS:
			var bp: Dictionary = _blueprint(_cat(fur, "solid", pose))
			var sockets: Dictionary = bp["sockets"]
			for s: String in ["head", "neck", "back", "tail_tip", "eyes", "chest", "belly", "hip_r", "body", "hand_r",
					"hand_l", "tail"]:
				assert_true(sockets.has(s), "cat %s %s: socket %s" % [pose, fur, s])
			assert_eq(str((sockets["head"] as Dictionary)["pivot"]), "Head")
			assert_eq(str((sockets["eyes"] as Dictionary)["pivot"]), "Head")
			assert_eq(str((sockets["neck"] as Dictionary)["pivot"]), "Body")
			assert_eq(str((sockets["back"] as Dictionary)["pivot"]), "Body")
			assert_eq(str((sockets["tail_tip"] as Dictionary)["pivot"]), "Tail")
			assert_gt(((sockets["tail_tip"] as Dictionary)["pos"] as Vector3).length(), 0.2, "the tip ends the tail")
			assert_eq(bp["pivots"], ["Body", "Head", "Tail"])
	var rig: CharacterRig = CharacterBuilder.build({"base": "cat"}, 0)
	add_to_tree(rig)
	for a: StringName in CharacterRig.ANCHOR_NAMES:
		assert_true(rig.anchor(a) != rig, "cat anchor %s" % a)
	assert_gt(rig.anchor(&"head").global_position.y, rig.anchor(&"center").global_position.y, "head above the body")


func test_cat_colour_slots() -> void:
	var slots: Dictionary = {"primary": "c03030", "secondary": "30c030", "accent": "3030c0", "eyes": "e0e020"}
	var cols: Dictionary = {}
	for k: String in slots:
		cols[k] = "#" + str(slots[k])
	for pose: String in ["auto", "upright"]:
		for fur: String in Archetypes.CAT_FURS:
			var have: Dictionary = {}
			for pattern: String in Archetypes.CAT_PATTERNS:
				have[pattern] = _vertex_colors(_cat(fur, pattern, pose, cols))
			var what: String = "cat %s %s" % [pose, fur]
			for pattern: String in Archetypes.CAT_PATTERNS:
				assert_true((have[pattern] as Dictionary).has(slots["primary"]), "%s %s: the fur" % [what, pattern])
				assert_true((have[pattern] as Dictionary).has(slots["eyes"]), "%s %s: the eyes" % [what, pattern])
			assert_false((have["solid"] as Dictionary).has(slots["secondary"]), what + " solid: no markings")
			for pattern: String in ["tabby", "tortie", "bicolor", "calico"]:
				assert_true((have[pattern] as Dictionary).has(slots["secondary"]), "%s %s: markings" % [what, pattern])
			assert_true((have["calico"] as Dictionary).has(slots["accent"]), what + " calico: the dark patches")
			assert_false((have["tabby"] as Dictionary).has(slots["accent"]), what + " tabby: no accent")
	var nose: String = Archetypes.CAT_NOSE.to_html(false)
	assert_true(_vertex_colors({"base": "cat"}).has(nose), "a pink nose")


func test_cat_styles_shape_the_figure() -> void:
	var short_rig: CharacterRig = CharacterBuilder.build(_cat("short", "solid"), 0)
	var long_rig: CharacterRig = CharacterBuilder.build(_cat("long", "solid"), 0)
	assert_gt(float(long_rig.get("_width")), float(short_rig.get("_width")),
		"long fur: more volume (ruff, plume tail, fluffy haunches)")
	short_rig.free()
	long_rig.free()
	var solid: Array[int] = _measure(_cat("short", "solid"))
	for pattern: String in ["tabby", "tortie", "bicolor", "calico"]:
		assert_gt(_measure(_cat("short", pattern))[0], solid[0], pattern + " adds its markings")
	assert_ne(_measure(_cat("long", "solid"))[0], solid[0], "the fur length changes the recipe")
	# the style keys the mesh cache: a tabby never reuses the solid cat's meshes
	CharacterBuilder.clear_cache()
	var a: CharacterRig = CharacterBuilder.build(_cat("short", "solid"), 0)
	var b: CharacterRig = CharacterBuilder.build(_cat("short", "tabby"), 0)
	var c: CharacterRig = CharacterBuilder.build(_cat("short", "solid"), 0)
	var ma: Mesh = (a.find_child("BodyMesh", true, false) as MeshInstance3D).mesh
	assert_ne(ma, (b.find_child("BodyMesh", true, false) as MeshInstance3D).mesh, "pattern in the cache key")
	assert_eq(ma, (c.find_child("BodyMesh", true, false) as MeshInstance3D).mesh, "same style: the cached meshes")
	for r: CharacterRig in [a, b, c]:
		r.free()


func test_style_normalization() -> void:
	assert_eq(CharacterBuilder.normalize({"base": "cat"})["style"], {"fur": "short", "pattern": "solid"},
		"the first option of each key is the default")
	assert_eq(CharacterBuilder.normalize({"base": "cat", "style": {"fur": "long", "pattern": "calico"}})["style"],
		{"fur": "long", "pattern": "calico"})
	assert_eq(CharacterBuilder.normalize({"base": "cat", "style": {"fur": "curly", "hair": "bun"}})["style"],
		{"fur": "short", "pattern": "solid"}, "unknown option → default, foreign keys dropped")
	assert_eq(CharacterBuilder.normalize({"base": "humanoid"})["style"], {"hair": "short", "beard": "none"},
		"the humanoid's casting style is unchanged (08 §6.2)")
	assert_eq(CharacterBuilder.normalize({"base": "pug", "style": {"fur": "long"}})["style"], {}, "no style for the pug")


func test_cat_animates_like_a_quadruped() -> void:
	for pose: String in ["auto", "upright"]:
		var rig: CharacterRig = CharacterBuilder.build({"base": "cat", "pose": pose}, 0)
		add_to_tree(rig)
		var tail: Node3D = rig.find_child("Tail", true, false) as Node3D
		assert_not_null(tail, "a Tail pivot")
		var rest: Basis = tail.transform.basis
		rig.set_process(false)
		rig.play(&"idle")
		var moved: bool = false
		for i in 30:
			rig.call("_process", 0.05)
			moved = moved or not tail.transform.basis.is_equal_approx(rest)
		assert_true(moved, "cat %s: the tail swishes in idle (one-shots: test_m4_art_kit, every base)" % pose)


# --- the six props (11 §4.10 budgets) --------------------------------------------------------------------------------

func test_new_props_within_budget_on_their_bases() -> void:
	var bases: Dictionary = {
		"humanoid": [DB.data.party_member("kai").model.duplicate(true),
			{"base": "humanoid", "colors": {"primary": "#c95d63", "skin": "#d19a6e"}, "style": {"hair": "curls"}}],
		"pug": [DB.data.party_member("mopsula").model.duplicate(true), {"base": "pug"}],
		"cat": [_cat("short", "solid"), _cat("long", "calico"), _cat("short", "tabby", "upright"),
			_cat("long", "bicolor", "upright")],
	}
	for prop: String in NEW_PROPS:
		for base: String in (PROP_BASES[prop] as Array):
			for m0: Variant in (bases[base] as Array):
				var model: Dictionary = (m0 as Dictionary).duplicate(true)
				var before: Array[int] = _measure(model)
				var props: Array = Array(model.get("props", []))
				props.append(prop)
				model["props"] = props
				var after: Array[int] = _measure(model)
				var what: String = "%s on %s %s" % [prop, base, JSON.stringify(m0)]
				var added: int = _added_tris(m0 as Dictionary, prop)
				assert_true(added <= int(PROP_TRIS_MAX[prop]), "%s: its parts %d tris > %d" % [what, added,
					int(PROP_TRIS_MAX[prop])])
				assert_true(after[0] - before[0] <= added, what + ": costs at most its parts (it may replace some)")
				assert_ne(after[0], before[0], what + " changes the figure")
				assert_eq(after[1], before[1], what + ": merged into the existing meshes (no new draw call)")


func test_clothing_dresses_the_humanoid() -> void:
	var kai: Dictionary = DB.data.party_member("kai").model.duplicate(true)
	var bp0: Dictionary = _blueprint(kai)
	for garment: String in ["jacket", "bathrobe"]:
		var m: Dictionary = kai.duplicate(true)
		m["props"] = ["mop", garment]
		var bp: Dictionary = _blueprint(m)
		var sleeve: Color = ((bp["meshes"]["ArmL"] as Dictionary)["parts"] as Array)[0]["color"]
		assert_ne(sleeve, ((bp0["meshes"]["ArmL"] as Dictionary)["parts"] as Array)[0]["color"],
			garment + ": the sleeves take its colour")
		var names: Array = (bp["mesh_order"] as Array).duplicate()
		var names0: Array = (bp0["mesh_order"] as Array).duplicate()
		names.sort()
		names0.sort()
		assert_eq(names, names0, garment + ": the same meshes")
	var shorts: Dictionary = kai.duplicate(true)
	shorts["props"] = ["mop", "shorts"]
	var skin: Color = Palette.hex(str((kai["colors"] as Dictionary)["skin"]))
	var leg_colors: Array = []
	for p: Dictionary in ((_blueprint(shorts)["meshes"]["LegL"] as Dictionary)["parts"] as Array):
		leg_colors.append(p["color"])
	assert_has(leg_colors, skin, "shorts: the bare shin")
	var sandals: Dictionary = kai.duplicate(true)
	sandals["props"] = ["mop", "sandals"]
	var feet: Array = []
	for p: Dictionary in ((_blueprint(sandals)["meshes"]["LegR"] as Dictionary)["parts"] as Array):
		feet.append(p["color"])
	assert_has(feet, Archetypes.SANDAL_SOLE, "sandals: a sole")
	assert_false(feet.has(Archetypes.BLACK_SHOE), "sandals: instead of the shoe")


func test_tiara_and_sunglasses_sit_on_the_head() -> void:
	for model: Dictionary in [{"base": "humanoid"}, {"base": "pug"}, _cat("short", "solid"),
			_cat("long", "solid", "upright")]:
		for prop: String in ["tiara", "sunglasses"]:
			if not (PROP_BASES[prop] as Array).has(str(model["base"])):
				continue
			var m: Dictionary = model.duplicate(true)
			m["props"] = [prop]
			var bp: Dictionary = _blueprint(m)
			var bp0: Dictionary = _blueprint(model)
			var head: String = str((bp["sockets"]["head"] as Dictionary)["pivot"])
			var mesh_name: String = head if (bp["meshes"] as Dictionary).has(head) else str(bp["mesh_order"][0])
			assert_gt((bp["meshes"][mesh_name]["parts"] as Array).size(),
				(bp0["meshes"][mesh_name]["parts"] as Array).size(), "%s on %s: on the head" % [prop, model["base"]])


# --- the look kind wear (08 §6, 11 §4.10) ----------------------------------------------------------------------------

func test_persona_wear() -> void:
	var kai: Dictionary = DB.data.party_member("kai").model.duplicate(true)
	assert_eq(Array(PersonaLook.apply(kai, {"wear": "lk_wear_jacket"}, DB.data)["props"]), ["mop", "jacket"],
		"Jacke = the jacket prop")
	assert_eq(PersonaLook.apply(kai, {}, DB.data), kai, "no wear id: the canon option (ohne) — Kai unchanged")
	assert_eq(PersonaLook.apply(kai, {"wear": "lk_hair_bun"}, DB.data), kai, "a foreign id counts as canon")
	var dressed: Dictionary = kai.duplicate(true)
	dressed["props"] = ["mop", "jacket", "glasses"]
	assert_eq(Array(PersonaLook.apply(dressed, {"wear": "lk_wear_none", "glasses": "lk_glasses_round"},
		DB.data)["props"]), ["mop", "glasses"], "ohne takes the clothing off, the glasses stay")
	var both: Dictionary = PersonaLook.apply(kai, {"wear": "lk_wear_jacket", "glasses": "lk_glasses_round"}, DB.data)
	assert_eq(Array(both["props"]), ["mop", "glasses", "jacket"], "wear and glasses combine")
	var pug: Dictionary = DB.data.party_member("mopsula").model
	assert_eq(PersonaLook.apply(pug, {"wear": "lk_wear_jacket"}, DB.data), pug, "only humanoids wear a look")
	# ids(): wear is optional — the persona file and the casting carry the six kinds of 08 §6.1
	var six: Dictionary = PersonaLook.ids({"hair": "lk_hair_bun"}, DB.data)
	assert_false(six.has("wear"), "a look without wear lists no wear id")
	assert_eq(six.size(), PersonaLook.KINDS.size() - PersonaLook.OPTIONAL_KINDS.size())
	assert_eq(PersonaLook.ids({"wear": "lk_wear_jacket"}, DB.data)["wear"], "lk_wear_jacket")
	assert_eq(PersonaLook.ids({"wear": "lk_skin_3"}, DB.data)["wear"], "lk_wear_none", "foreign → canon")
	assert_eq(PersonaProfile.canon_look(DB.data).size(), 6, "the persona file keeps its six kinds")


func test_persona_worst_case_with_wear() -> void:
	var kai: Dictionary = DB.data.party_member("kai").model.duplicate(true)
	var worst: int = 0
	var worst_look: String = ""
	for hair: String in CharacterBuilder.supported_hair_styles():
		for beard: String in CharacterBuilder.supported_beards():
			for glasses: bool in [false, true]:
				for wear: String in LooksCheck.WEAR_STYLES:
					var m: Dictionary = kai.duplicate(true)
					m["style"] = {"hair": hair, "beard": beard}
					var props: Array = Array(m["props"])
					if glasses:
						props.append("glasses")
					if wear != PersonaLook.WEAR_NONE:
						props.append(wear)
					m["props"] = props
					var r: Array[int] = _measure(m)
					var what: String = "%s + %s + glasses %s + %s" % [hair, beard, glasses, wear]
					assert_eq(r[1], PERSONA_MESHES, what + ": Kai's 7 MeshInstances")
					if r[0] > worst:
						worst = r[0]
						worst_look = what
	assert_true(worst <= PERSONA_TRIS_MAX, "worst case %s: %d tris > %d (CR-22)" % [worst_look, worst,
		PERSONA_TRIS_MAX])


func test_looks_wear_data() -> void:
	var data: GameData = real_data()
	var wear: Array[Dictionary] = data.looks_of("wear")
	var styles: PackedStringArray = []
	for e: Dictionary in wear:
		styles.append(str(e["style"]))
		assert_true(str(e["name"]).length() <= LooksCheck.NAME_MAX, str(e["id"]))
		assert_false(ArtKitRules.KAI_FORBIDDEN_PROPS.has(str(e["style"])), "rule 3: the persona never wears " +
			str(e["style"]))
	assert_eq(styles, PackedStringArray(["none", "jacket"]), "base data: ohne (canon) and Jacke")
	assert_eq(str(data.look_canon("wear")["id"]), "lk_wear_none", "canon: Kai wears no clothing prop")
	for dir: String in ["res://tests/fixtures/data_min", "res://tests/fixtures/rt_min"]:
		var fixture: GameData = GameData.new()
		assert_true(fixture.load_dir(dir), dir + ": " + "; ".join(fixture.errors))
		assert_eq(str(fixture.look_canon("wear").get("id", "")), "lk_wear_none", dir + ": the wear canon")
	var cases: Array = [
		[{"id": "lk_wear_cape", "kind": "wear", "name": "Umhang", "style": "cape"}, "not in"],
		[{"id": "lk_wear_red", "kind": "wear", "name": "Rot", "style": "jacket", "color": "#FF0000"}, "not a field"],
		[{"id": "lk_wear_two", "kind": "wear", "name": "Zweite", "style": "jacket"}, "the same style as lk_wear_jacket"],
	]
	for c: Array in cases:
		var raw: Dictionary = _raw()
		((raw["looks"] as Dictionary)["entries"] as Array).append(c[0])
		assert_has("; ".join(_errors(raw)), str(c[1]), "rejected: " + str(c[0]))
	var no_wear: Dictionary = _raw()
	var kept: Array = []
	for e: Variant in ((no_wear["looks"] as Dictionary)["entries"] as Array):
		if str((e as Dictionary)["kind"]) != "wear":
			kept.append(e)
	(no_wear["looks"] as Dictionary)["entries"] = kept
	assert_has("; ".join(_errors(no_wear)), "looks[kind=wear]: no option", "every kind needs its canon option")
	var two: Dictionary = _raw()
	_entry(two, "party", "kai")["model"]["props"] = ["mop", "jacket", "shorts"]
	assert_has("; ".join(_errors(two)), "at most one wear prop", "a look sets one wear prop")


# --- validator: style keys per base, PTD's rules 1–4 -----------------------------------------------------------------

func test_validator_style_keys_per_base() -> void:
	var raw: Dictionary = _raw()
	var cases: Dictionary = {
		"enm_kanalratte": [{"base": "cat", "style": {"fur": "long", "pattern": "calico"}}, ""],
		"enm_kanalratte_azubi": [{"base": "cat", "style": {"hair": "bun"}}, "unknown key (fur, pattern)"],
		"enm_taubenschwarm": [{"base": "cat", "style": {"pattern": "plaid"}}, "'plaid' not in [solid, tabby, tortie"],
		"enm_kanalschleim": [{"base": "pug", "style": {"fur": "long"}}, "only for base \"humanoid\" or \"cat\""],
		"enm_pendler": [{"base": "humanoid", "style": {"fur": "long"}}, "unknown key (hair, beard)"],
	}
	for id: String in cases:
		var model: Dictionary = _entry(raw, "enemies", id)["model"]
		model.merge(cases[id][0] as Dictionary, true)
	var errors: PackedStringArray = _errors(raw)
	for id: String in cases:
		var mine: PackedStringArray = []
		for e: String in errors:
			if e.contains("|%s]" % id) and e.contains(".style"):
				mine.append(e)
		var want: String = str(cases[id][1])
		if want == "":
			assert_eq(mine, PackedStringArray(), id + ": a cat's fur and pattern are valid")
		else:
			assert_true(mine.size() == 1 and mine[0].contains(want), "%s: %s (got %s)" % [id, want, str(mine)])


func test_rules_one_to_three() -> void:
	assert_eq(_art_errors(real_data().errors), PackedStringArray(), "the base data keep PTD's rules")
	var raw: Dictionary = _raw()
	var mopsula: Dictionary = _entry(raw, "party", "mopsula")
	mopsula["model"]["base"] = "cat"                                                         # rule 2
	mopsula["model"]["props"] = ["cape", "tiara", "crown", "ticket_crown", "sandals"]        # rules 1, 3
	_entry(raw, "party", "kai")["model"]["props"] = ["mop", "shorts", "bathrobe"]           # rule 3
	_entry(raw, "enemies", "enm_kanalratte")["model"]["props"] = ["sandals"]                 # rule 3
	_entry(raw, "species", "spc_mop_glutmops")["model_hint"]["props_add"] = ["tiara"]        # rule 1
	_entry(raw, "species", "spc_kai_pilzling")["model_hint"]["props_add"] = ["bathrobe"]     # rule 3
	(_entry(raw, "species", "spc_original") as Dictionary)["model_hint"] = {"props_add": ["sandals"]}
	((raw["looks"] as Dictionary)["entries"] as Array).append(
		{"id": "lk_wear_shorts", "kind": "wear", "name": "Kurze Hose", "style": "shorts"})  # rule 3
	var errors: PackedStringArray = _errors(raw)
	for want: String in [
			"party[mopsula].model.base: 'cat': no party member or companion is a cat",
			"party[mopsula].model.props: 'tiara': no crown motif on Graf Mopsula",
			"party[mopsula].model.props: 'crown': no crown motif",
			"party[mopsula].model.props: 'ticket_crown': no crown motif",
			"party[mopsula].model.props: 'sandals': not in the base content",
			"party[kai].model.props: 'shorts': Kai never wears it",
			"party[kai].model.props: 'bathrobe': Kai never wears it",
			"enemies[enm_kanalratte].model.props: 'sandals': not in the base content",
			"spc_mop_glutmops].model_hint.props_add: 'tiara': no crown motif on Graf Mopsula",
			"species[spc_kai_pilzling].model_hint.props_add: 'bathrobe': Kai never wears it",
			"species[spc_original].model_hint.props_add: 'sandals': Kai never wears it",
			"looks[lk_wear_shorts].style: 'shorts': the persona never wears it"]:
		assert_true(Kit.has_error(errors, want), "%s (errors: %s)" % [want, str(_art_errors(errors))])
	var fine: Dictionary = _raw()
	_entry(fine, "enemies", "enm_kanalratte")["model"] = {"base": "cat", "scale": 1.0, "pose": "upright",
		"colors": {"primary": "#f2eee6", "secondary": "#d9822b", "accent": "#2b2522"},
		"props": ["tiara", "sunglasses", "jacket", "bathrobe", "shorts"], "style": {"fur": "long", "pattern": "calico"}}
	_entry(fine, "party", "mopsula")["model"]["props"] = ["cape", "monocle", "sunglasses"]
	_entry(fine, "species", "spc_mop_glutmops")["model_hint"]["props_add"] = ["jacket"]
	assert_eq(_art_errors(_errors(fine)), PackedStringArray(),
		"a cat enemy may wear any prop but sandals; Mopsula sunglasses, a species look for him a jacket")


## Rule 4 end to end: a pack whose art.json turns Graf Mopsula into a cat with a tiara and Kai into shorts, and whose
## looks overlay adds a shorts wear option — exempt with a licence block (it owns those fields and the entry), checked
## like the base data without one.
func test_rule_four_licensed_packs_are_exempt_for_their_own_entries() -> void:
	var art: Dictionary = {"schema": 1, "models": {"mopsula": {"base": "cat", "props": ["tiara"]},
		"enm_kanalratte": {"props": ["sandals"]}}}
	var looks: Dictionary = {"add": [{"id": "lk_wear_shorts", "kind": "wear", "name": "Kurze Hose", "style": "shorts"}]}
	var wants: PackedStringArray = ["party[mopsula].model.base: 'cat'", "party[mopsula].model.props: 'tiara'",
		"enemies[enm_kanalratte].model.props: 'sandals'", "looks[lk_wear_shorts].style: 'shorts'"]
	for licensed: bool in [true, false]:
		var extra: Dictionary = {"art": "art.json"}
		if licensed:
			extra["licence"] = Kit.test_licence()
		var p: PackDef = Kit.write_pack(ROOT, "artkit", Kit.manifest("artkit", {"looks": {"add": true}}, extra),
			{"looks": looks}, {"art.json": art})
		assert_eq(p.errors, PackedStringArray(), "the probe pack reads clean")
		assert_eq(p.has_licence(), licensed)
		var merged: Dictionary = PackLoader.merge(_raw(), p)
		assert_eq(merged["errors"], PackedStringArray())
		var errors: PackedStringArray = _errors(merged["raw"], PackLoader.provenance(p, merged["owned"]))
		for want: String in wants:
			assert_eq(Kit.has_error(errors, want), not licensed, "%s — licensed %s" % [want, licensed])
	Kit.rmrf(ROOT)
	# a licence covers only what the pack owns: the base species look for the Count is still checked
	var raw: Dictionary = _raw()
	_entry(raw, "species", "spc_mop_glutmops")["model_hint"]["props_add"] = ["tiara"]
	var owned: Dictionary = {"party": {"patched": {"mopsula": ["model.props"]}}}
	var prov: Dictionary = {"pack": "probe", "licensed": true, "owned": owned}
	assert_true(Kit.has_error(_errors(raw, prov), "spc_mop_glutmops].model_hint.props_add: 'tiara'"),
		"not the pack's entry: no exemption")
	var colors_only: Dictionary = {"pack": "probe", "licensed": true, "owned": {"party": {"patched":
		{"mopsula": ["model.colors"]}}}}
	var raw2: Dictionary = _raw()
	_entry(raw2, "party", "mopsula")["model"]["props"] = ["cape", "tiara"]
	assert_true(Kit.has_error(_errors(raw2, colors_only), "party[mopsula].model.props: 'tiara'"),
		"the pack set only the colours: the props are still the base's")


# --- galleries --------------------------------------------------------------------------------------------------------

func test_cat_and_kit_galleries_run_every_view() -> void:
	for path: String in GALLERIES:
		for view: String in (GALLERIES[path] as Array):
			var inst: Node = (load(path) as PackedScene).instantiate()
			inst.call("setup", {"view": view} if view != "" else {})
			add_to_tree(inst)
			await wait_frames(3)
			var rigs: Dictionary = inst.get("rigs")
			assert_gt(rigs.size(), 1, "%s %s: figures" % [path, view])
			var cats: int = 0
			for r: Variant in rigs.values():
				cats += 1 if str((r as CharacterRig).model.get("base", "")) == "cat" else 0
			if not (path.ends_with("kit_gallery.tscn") and view in ["close", "persona"]):
				assert_gt(cats, 1, "%s %s: cats" % [path, view])
			inst.get_parent().remove_child(inst)
			inst.free()
	var all: Node = (load("res://art/gallery/cat_gallery.tscn") as PackedScene).instantiate()
	add_to_tree(all)
	await wait_frames(2)
	var seen: Dictionary = {}
	for r: Variant in (all.get("rigs") as Dictionary).values():
		var m: Dictionary = (r as CharacterRig).model
		seen["%s|%s|%s" % [m["style"]["fur"], m["style"]["pattern"], m["pose"]]] = true
	assert_eq(seen.size(), Archetypes.CAT_FURS.size() * Archetypes.CAT_PATTERNS.size() * 2,
		"every pattern, both fur lengths, standing and sitting")
	all.get_parent().remove_child(all)
	all.free()
