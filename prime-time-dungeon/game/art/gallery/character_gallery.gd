extends Node3D
## Character gallery (02_TECH §1.5, CI screenshot target §12.4): the floor-1 cast (03_ART §5.5) plus every party
## member / enemy from DB that the cast sheet does not know, lined up on a show stage under battle light.
## `page` (set in the .tscn variants): "cast" (default) | "bases" (all 9 archetypes, floor-2 stubs) |
## "anims" (Kai/Mopsula/rat/Hausmeister frozen in key poses) | "props" (every prop on a humanoid) | Casting (08 §6,
## K2): "looks" (eight persona looks from data/looks.json on Kai's model, look_gallery.tscn) | "hair" (close-up of every
## hair style, or with params {"row": "beard"} every beard with and without glasses; {"view": "front" | "back" |
## "side"}, hair_gallery.tscn) | 11-A1 (11 §4.10): "cats" (every pattern, both fur lengths, standing and sitting;
## {"view": "close" | "game" | "fur" | "sit" | "patterns"}, cat_gallery.tscn) | "kit" (each new prop on a fitting base;
## {"view": "close" | "heads" | "persona"}, kit_gallery.tscn). params {"page": …} picks the page of this scene, so every
## page also renders from character_gallery.tscn (check.sh --shot … --params='{"page": "cats"}').

const Cast := preload("res://art/gallery/cast.gd")
const Stage := preload("res://art/gallery/gallery_stage.gd")
const NameTags := preload("res://art/gallery/name_tags.gd")

@export var page: String = "cast"

## Name tags under the figures: screen-space labels (name_tags.gd) in the UI font, nudged apart when they overlap
## (visual pass: the billboard tags overlapped each other and the figures behind them).
const TAG_SIZE: int = 18
const TAG_COLORS: Dictionary = {"hero": Color("#22d3ee"), "enemy": Color("#f5f0ff"), "boss": Color("#ffc93c")}

var rigs: Dictionary = {}          # id → CharacterRig
var tags: CanvasLayer = null       # name_tags.gd
var _params: Dictionary = {}


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	if _params.has("page"):
		page = str(_params["page"])
	Stage.add_world(self, "metro", {}, &"battle")
	tags = NameTags.new()
	tags.name = "NameTags"
	add_child(tags)
	match page:
		"cats":
			_build_cats()
		"kit":
			_build_kit()
		"bases":
			_build_bases()
		"anims":
			_build_anims()
		"props":
			_build_props()
		"looks":
			_build_looks()
		"hair":
			_build_hair()
		"heroes":
			_build_closeup(["kai", "mopsula"], [Vector3(-0.55, 0, 0), Vector3(0.6, 0, 0.1)], Vector3(0, 1.5, 3.6),
				Vector3(0, 0.75, 0))
		"bosses":
			_build_closeup(["enm_boss_hausmeister", "enm_boss_rattenkoenigin"], [Vector3(-2.6, 0, 0), Vector3(2.6, 0, -1.0)],
				Vector3(0, 3.0, 10.5), Vector3(0, 1.5, 0))
		"enemies":
			_build_closeup(["enm_pendler", "enm_rattengardist", "enm_rolltreppenkrabbe", "enm_rattenschamane",
				"enm_spruehgeist", "enm_fahrscheinfresser"], [Vector3(-3.2, 0, 0), Vector3(-1.95, 0, 0), Vector3(-0.55, 0, 0),
				Vector3(0.85, 0, 0), Vector3(2.0, 0, 0), Vector3(3.2, 0, 0)], Vector3(0, 2.4, 7.6), Vector3(0, 0.85, 0))
		_:
			_build_cast()
	var cam: Camera3D = get_node_or_null("Camera") as Camera3D
	tags.set("camera", cam)


func _place(id: String, model: Dictionary, pos: Vector3, yaw_deg: float, label: String, seed: int = 0,
		tag_over_head: bool = false, tag_offset: Vector3 = Vector3(0, 0, 0.5)) -> CharacterRig:
	var rig: CharacterRig = CharacterBuilder.build(model, seed)
	rig.name = "Rig_" + id
	add_child(rig)
	rig.position = pos
	rig.rotation_degrees = Vector3(0, 180.0 + yaw_deg, 0)
	rig.battle_stance = true
	rigs[id] = rig
	if label != "":
		var role: String = str((Cast.CAST.get(id, {}) as Dictionary).get("role", "enemy"))
		var col: Color = TAG_COLORS.get(role, TAG_COLORS["enemy"]) as Color
		if tag_over_head:
			tags.call("add_tag", rig, label, Vector3(0, 0.3, 0), col, TAG_SIZE + 2, false, true)
		else:
			tags.call("add_tag", rig, label, tag_offset, col, TAG_SIZE, true)
	return rig


func _build_cast() -> void:
	Stage.add_floor(self, 9.0, {})
	# three rows: bosses at the back (tags over their heads), seven enemies in the middle (staggered so neighbouring
	# tags never collide), party + small enemies in front, far enough forward and seen from high enough that no tag
	# under the middle row sits on a front-row figure (layout checked with a projection script, visual pass)
	var layout: Dictionary = {
		"enm_boss_hausmeister": [Vector3(-4.2, 0, -4.6), 12.0],
		"enm_boss_rattenkoenigin": [Vector3(2.6, 0, -5.0), -40.0],
		"enm_pendler": [Vector3(-6.3, 0, -0.6), 15.0],
		"enm_rattengardist": [Vector3(-4.2, 0, -1.8), 10.0],
		"enm_fahrscheinfresser": [Vector3(-2.1, 0, -0.6), 5.0],
		"enm_rattenschamane": [Vector3(0.0, 0, -1.8), 0.0],
		"enm_rolltreppenkrabbe": [Vector3(2.1, 0, -0.6), -10.0],
		"enm_spruehgeist": [Vector3(4.2, 0, -1.8), -10.0],
		"enm_kellerspinne": [Vector3(6.3, 0, -0.6), -25.0],
		"enm_taubenschwarm": [Vector3(-5.25, 0, 3.8), 10.0],
		"enm_kanalratte": [Vector3(-3.15, 0, 3.8), 20.0],
		"kai": [Vector3(-1.05, 0, 3.8), 10.0],
		"mopsula": [Vector3(1.05, 0, 3.8), -15.0],
		"enm_kanalschleim": [Vector3(3.15, 0, 3.8), -10.0],
		"enm_kabelsalat": [Vector3(5.25, 0, 3.8), -20.0],
	}
	for id: String in layout:
		var entry: Array = layout[id]
		var model: Dictionary = Cast.model(id)
		var db_model: Dictionary = _db_model(id)
		if not db_model.is_empty():
			model = db_model
		var boss: bool = str(Cast.CAST[id]["role"]) == "boss"
		var rig: CharacterRig = _place(id, model, entry[0] as Vector3, float(entry[1]), str(Cast.CAST[id]["name"]),
			id.length(), boss)
		if id.begins_with("enm_"):
			rig.death_style = &"dissolve"
	# floor-1 enemies / party members of the data the cast sheet does not know (new content) appear centred in an extra
	# front row; floor-2 content and the sheet's floor-2 stubs belong to the "bases" page
	var extra: PackedStringArray = []
	for id: String in _floor1_ids():
		if not Cast.CAST.has(id) and extra.size() < 5:
			extra.append(id)
	for i in extra.size():
		var ex: float = (float(i) - float(extra.size() - 1) * 0.5) * 2.4
		_place(extra[i], _db_model(extra[i]), Vector3(ex, 0, 5.6), 0.0, _db_name(extra[i]), extra[i].length())
	var label := Stage.label(self, "PRIME TIME DUNGEON · CAST ETAGE 1", Vector3(0, 4.9, -7.0), 64, Palette.HYPE_GOLD)
	label.pixel_size = 0.006
	Stage.add_camera(self, Vector3(0, 7.0, 13.0), Vector3(0, 0.9, -0.6), 40.0)


func _build_bases() -> void:
	Stage.add_floor(self, 9.0, {})
	var bases: PackedStringArray = CharacterBuilder.supported_bases()
	var x: float = -float(bases.size() - 1) * 0.75
	for b: String in bases:
		var m: Dictionary = {"base": b, "scale": 1.0, "colors": {}, "props": []}
		m["colors"] = _default_primary(b)
		_place("base_" + b, m, Vector3(x, 0, 0.0), 0.0, b)
		x += 1.5
	var stubs: PackedStringArray = ["enm_schaufensterpuppe", "enm_einkaufswagen", "enm_rabattschild"]
	x = -3.0
	for id: String in stubs:
		_place(id, Cast.model(id), Vector3(x, 0, 3.0), 0.0, str(Cast.CAST[id]["name"]))
		x += 2.5
	var r: CharacterRig = _place("rodent_upright", {"base": "rodent", "scale": 1.0, "colors": {"primary": "#6b5b4e"}},
		Vector3(4.5, 0, 3.0), 0.0, "rodent upright")
	r.battle_stance = false
	Stage.add_camera(self, Vector3(0, 4.0, 11.0), Vector3(0, 0.8, 1.0), 42.0)


func _build_anims() -> void:
	Stage.add_floor(self, 9.0, {})
	var anims: Array[StringName] = [&"idle", &"walk", &"attack", &"cast", &"item", &"stunt", &"hit", &"defend",
		&"victory", &"die"]
	var times: Dictionary = {&"idle": 0.4, &"walk": 0.25, &"attack": 0.24, &"cast": 0.4, &"item": 0.35, &"stunt": 0.5,
		&"hit": 0.08, &"defend": 0.3, &"victory": 0.75, &"die": 0.7}
	# big Hausmeister in the back row so it never hides the small rat (review M4)
	var ids: PackedStringArray = ["enm_boss_hausmeister", "kai", "mopsula", "enm_kanalratte"]
	var row: int = 0
	for id: String in ids:
		var col: int = 0
		for a: StringName in anims:
			var scale_fix: float = 0.4 if id == "enm_boss_hausmeister" else 1.0
			var model: Dictionary = Cast.model(id)
			model["scale"] = float(model.get("scale", 1.0)) * scale_fix
			var front: bool = row == ids.size() - 1      # anim names under the front row (never over a figure)
			var rig: CharacterRig = _place("%s_%s" % [id, a], model, Vector3(-6.3 + 1.4 * float(col), 0,
				-2.0 + 2.4 * float(row)),
				-20.0, String(a) if front else "")
			rig.battle_stance = false
			rig.spawn_effects = false
			_freeze(rig, a, float(times[a]))
			col += 1
		row += 1
	Stage.add_camera(self, Vector3(0, 8.6, 14.6), Vector3(0, 0.4, 1.4), 44.0)


func _build_props() -> void:
	Stage.add_floor(self, 9.0, {})
	var props: PackedStringArray = CharacterBuilder.supported_props()
	var i: int = 0
	for p: String in props:
		var base: String = "humanoid"
		if p in ["escalator_back", "claws"]:
			base = "insect"
		elif p in ["cable_tangle"]:
			base = "blob"
		elif p in ["helmet", "shield", "halberd", "bottlecap_chain"]:
			base = "rodent"
		elif p in ["rat_king_tail", "ticket_crown"]:
			base = "rodent"
		elif p in ["cart"]:
			base = "robot"
		elif p in ["spray_cap"]:
			base = "specter"
		var m: Dictionary = {"base": base, "scale": 1.0, "colors": _default_primary(base), "props": [p]}
		if base == "rodent" and p in ["helmet", "shield", "halberd", "bottlecap_chain"]:
			m["scale"] = 1.4
		var col: int = i % 9
		var row: int = i / 9
		_place("prop_" + p, m, Vector3(-6.4 + 1.6 * float(col), 0, -3.0 + 2.6 * float(row)), 20.0, p)
		i += 1
	Stage.add_camera(self, Vector3(0, 6.0, 12.5), Vector3(0, 0.6, 0.6), 44.0)


# --- Casting (08 §6, K2): persona looks ------------------------------------------------------------------------------

## Nine looks from data/looks.json on Kai's model — every hair style once, all skin tones, beards, glasses and outfits
## mixed (the first is the canon Kai). Keys = look kinds, values = the option suffix after "lk_<kind>_".
const LOOKS: Array[Dictionary] = [
	{"hair": "short", "hair_color": "darkbrown", "skin": "3", "beard": "none", "glasses": "none", "outfit": "petrol"},
	{"hair": "long", "hair_color": "blond", "skin": "2", "beard": "none", "glasses": "round", "outfit": "white"},
	{"hair": "headscarf", "hair_color": "blue", "skin": "6", "beard": "none", "glasses": "none", "outfit": "orange"},
	{"hair": "curls", "hair_color": "black", "skin": "7", "beard": "full", "glasses": "none", "outfit": "blue"},
	{"hair": "bun", "hair_color": "grey", "skin": "4", "beard": "none", "glasses": "round", "outfit": "grey"},
	{"hair": "braids", "hair_color": "red", "skin": "5", "beard": "none", "glasses": "none", "outfit": "green"},
	{"hair": "buzz", "hair_color": "pink", "skin": "8", "beard": "stubble", "glasses": "round", "outfit": "midnight"},
	{"hair": "ponytail", "hair_color": "chestnut", "skin": "1", "beard": "none", "glasses": "none", "outfit": "pink"},
	{"hair": "bald", "hair_color": "darkbrown", "skin": "6", "beard": "moustache", "glasses": "none", "outfit": "petrol"},
]
const LOOK_PREFIX: Dictionary = {"hair": "lk_hair_", "hair_color": "lk_hc_", "skin": "lk_skin_", "beard": "lk_beard_",
	"glasses": "lk_glasses_", "outfit": "lk_outfit_"}


## LOOKS[i] as look ids ({kind: lk id}).
static func look_ids(i: int) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in LOOK_PREFIX:
		out[kind] = str(LOOK_PREFIX[kind]) + str(LOOKS[i][kind])
	return out


func _build_looks() -> void:
	Stage.add_floor(self, 9.0, {})
	var kai: Dictionary = _db_model("kai")
	for i in LOOKS.size():
		var x: float = (float(i) - float(LOOKS.size() - 1) * 0.5) * 1.05
		var z: float = 0.0 if i % 2 == 0 else -0.55
		var look: Dictionary = look_ids(i)
		var name: String = str(DB.data.look(str(look["hair"])).get("name", ""))
		_place("look_%d" % i, PersonaLook.apply(kai, look, DB.data), Vector3(x, 0, z), -8.0 * (float(i) - 4.0), name)
	Stage.add_camera(self, Vector3(0, 2.3, 7.4), Vector3(0, 0.85, -0.2), 40.0)


## Close-up: every hair style (params {"row": "beard"}: every beard without / with glasses); {"view": "front" |
## "back" | "side"} turns the figures; {"hair_color": "<suffix>"} the hair colour (default chestnut).
func _build_hair() -> void:
	Stage.add_floor(self, 9.0, {})
	var kai: Dictionary = _db_model("kai")
	var row: String = str(_params.get("row", "hair"))
	var yaw: float = {"front": 0.0, "back": 180.0, "side": 90.0}.get(str(_params.get("view", "front")), 0.0)
	var hc: String = "lk_hc_" + str(_params.get("hair_color", "chestnut"))
	var looks: Array[Dictionary] = []
	var names: PackedStringArray = []
	if row == "beard":
		for g: String in ["none", "round"]:
			for e: Dictionary in DB.data.looks_of("beard"):
				looks.append({"hair": "lk_hair_short", "hair_color": hc, "beard": str(e["id"]), "glasses": "lk_glasses_" + g})
				names.append(str(e["name"]) + (" + Brille" if g == "round" else ""))
	else:
		for e: Dictionary in DB.data.looks_of("hair"):
			looks.append({"hair": str(e["id"]), "hair_color": hc})
			names.append(str(e["name"]))
	for i in looks.size():
		var x: float = (float(i) - float(looks.size() - 1) * 0.5) * 0.78
		_place("hair_%d" % i, PersonaLook.apply(kai, looks[i], DB.data), Vector3(x, 0, 0), yaw, names[i])
	Stage.add_camera(self, Vector3(0, 1.9, 6.4), Vector3(0, 1.05, 0), 40.0)


# --- 11-A1 (11 §4.10): the cat and the new props ---------------------------------------------------------------------

## Gallery colours per cat pattern: [short fur, long fur] — black / cream, ginger / silver tabby, tortoiseshell,
## tuxedo / blue-and-white, calico (secondary = markings, accent = calico's dark patches).
const CAT_COLORS: Dictionary = {
	"solid": [{"primary": "#34343c", "eyes": "#f2c230"}, {"primary": "#efe1c6", "eyes": "#6fb8e8"}],
	"tabby": [{"primary": "#e0903e", "secondary": "#93491a", "eyes": "#9fd85a"},
		{"primary": "#c4c8ce", "secondary": "#4a4d55", "eyes": "#9fd85a"}],
	"tortie": [{"primary": "#2b2522", "secondary": "#d37a2c", "eyes": "#f2c230"},
		{"primary": "#2b2522", "secondary": "#d37a2c", "eyes": "#e08a3c"}],
	"bicolor": [{"primary": "#26262c", "secondary": "#f2eee6", "eyes": "#9fd85a"},
		{"primary": "#6d7686", "secondary": "#f2eee6", "eyes": "#f2a33c"}],
	"calico": [{"primary": "#f2eee6", "secondary": "#d9822b", "accent": "#2b2522", "eyes": "#9fd85a"},
		{"primary": "#f2eee6", "secondary": "#d9822b", "accent": "#2b2522", "eyes": "#6fb8e8"}],
}
## A humanoid that is not Kai (the clothing props on a stand-in, never Kai's look in Liga style, 06 §0.3).
const KIT_HUMAN: Dictionary = {"base": "humanoid", "scale": 1.0, "colors": {"primary": "#c95d63",
	"secondary": "#3a4a5a", "accent": "#d9b66b", "skin": "#d19a6e", "eyes": "#1a1420"}, "props": [],
	"style": {"hair": "bun", "beard": "none"}}
## Tag offset under the small figures of the cat pages (the default 0.5 m reaches the next row).
const CAT_TAG: Vector3 = Vector3(0, 0, 0.3)


## The gallery cat of `fur` × `pattern` in `pose` ("auto" stands, "upright" sits).
static func cat_model(fur: String, pattern: String, pose: String = "auto") -> Dictionary:
	var cols: Dictionary = (CAT_COLORS[pattern] as Array)[0 if fur == "short" else 1]
	return {"base": "cat", "scale": 1.0, "pose": pose, "colors": cols.duplicate(), "props": [],
		"style": {"fur": fur, "pattern": pattern}}


## The cats. Default: every pattern (columns) in four rows — short fur standing, long fur standing, short fur sitting,
## long fur sitting. {"view": …}: "close" four cats close up (ears, whisker pads, the curled tail), "game" cats beside
## Kai and Graf Mopsula from the exploration camera, "fur" short and long fur side by side, "sit" sitting cats from
## three sides, "patterns" the markings seen from above.
func _build_cats() -> void:
	Stage.add_floor(self, 9.0, {})
	match str(_params.get("view", "")):
		"game":
			_build_cats_game()
		"close":
			_cat_row([["short", "tabby", "auto", Vector3(-0.8, 0, 0.12), -35.0],
				["long", "calico", "upright", Vector3(-0.24, 0, -0.32), 10.0],
				["short", "tortie", "auto", Vector3(0.3, 0, 0.18), 55.0],
				["long", "bicolor", "auto", Vector3(0.84, 0, -0.26), 25.0]], true)
			Stage.add_camera(self, Vector3(0, 0.8, 2.25), Vector3(0, 0.24, -0.05), 36.0)
		"fur":
			_cat_row([["short", "tabby", "auto", Vector3(-1.25, 0, 0), 75.0],
				["long", "tabby", "auto", Vector3(-0.45, 0, 0), 75.0],
				["short", "solid", "auto", Vector3(0.38, 0, 0), 25.0],
				["long", "solid", "auto", Vector3(1.08, 0, 0), 25.0]], true)
			Stage.add_camera(self, Vector3(0, 0.75, 2.6), Vector3(0, 0.24, 0), 40.0)
		"sit":
			_cat_row([["short", "tortie", "upright", Vector3(-0.62, 0, 0), 20.0],
				["long", "bicolor", "upright", Vector3(0.0, 0, -0.1), 70.0],
				["long", "calico", "upright", Vector3(0.62, 0, 0), -35.0]], true)
			Stage.add_camera(self, Vector3(0, 0.62, 1.95), Vector3(0, 0.24, 0), 40.0)
		"patterns":
			var pats: PackedStringArray = CharacterBuilder.supported_styles()["cat"]["pattern"]
			var row: Array = []
			for i in pats.size():
				row.append(["short", pats[i], "auto", Vector3((float(i) - 2.0) * 0.62, 0, 0.0), 60.0])
			_cat_row(row, true)
			Stage.add_camera(self, Vector3(0, 1.75, 2.4), Vector3(0, 0.15, -0.05), 40.0)
		_:
			_build_cats_all()


## Cats of `row` ([fur, pattern, pose, position, yaw]); `tag`: a name tag "fur · pattern" under each.
func _cat_row(row: Array, tag: bool) -> void:
	for c: Array in row:
		var label: String = "%s · %s" % [c[0], c[1]] if tag else ""
		_place("cat_%s_%s_%s" % [c[0], c[1], c[2]], cat_model(str(c[0]), str(c[1]), str(c[2])), c[3] as Vector3,
			float(c[4]), label, 0, false, CAT_TAG)


## Every pattern × fur length × pose: the pattern names under the front row, the rows named at the left.
func _build_cats_all() -> void:
	var patterns: PackedStringArray = CharacterBuilder.supported_styles()["cat"]["pattern"]
	var rows: Array = [["short", "auto", 1.8, "short · stand"], ["long", "auto", 0.6, "long · stand"],
		["short", "upright", -0.6, "short · sit"], ["long", "upright", -1.8, "long · sit"]]
	for r: Array in rows:
		for i in patterns.size():
			var x: float = (float(i) - float(patterns.size() - 1) * 0.5) * 1.0
			# standing cats turned half to the camera (face, legs and the tail curl), sitting ones a little less
			var yaw: float = 40.0 if str(r[1]) == "auto" else 20.0
			_place("cat_%s_%s_%s" % [r[0], patterns[i], r[1]], cat_model(str(r[0]), patterns[i], str(r[1])),
				Vector3(x, 0, float(r[2])), yaw, patterns[i] if float(r[2]) > 1.0 else "", 0, false, CAT_TAG)
		_tag_at(Vector3(-2.75, 0.15, float(r[2])), str(r[3]))
	Stage.add_camera(self, Vector3(0, 3.6, 5.4), Vector3(0, 0.0, -0.1), 40.0)


## Cats beside Kai and Graf Mopsula from the exploration camera (02_TECH §7.3: arm 7 m from a pivot 1.4 m over the
## leader, pitch −38°, FOV 60).
func _build_cats_game() -> void:
	_place("kai", _db_model("kai"), Vector3(-1.2, 0, 0.2), 20.0, "")
	_place("mopsula", _db_model("mopsula"), Vector3(-0.3, 0, 0.6), 10.0, "")
	_cat_row([["short", "tabby", "auto", Vector3(0.6, 0, 0.4), -35.0],
		["long", "calico", "upright", Vector3(1.3, 0, -0.3), 15.0],
		["short", "bicolor", "auto", Vector3(0.4, 0, -0.9), 70.0],
		["short", "solid", "upright", Vector3(-0.8, 0, -1.0), -10.0],
		["long", "tortie", "auto", Vector3(1.6, 0, 0.9), -80.0]], false)
	var pivot := Vector3(0.0, 1.4, 0.0)
	var pitch: float = deg_to_rad(38.0)
	Stage.add_camera(self, pivot + Vector3(0, sin(pitch), cos(pitch)) * 7.0, pivot, 60.0)


## The new props. Default: each on a fitting base — the humanoid stand-in with tiara, sunglasses, jacket, bathrobe
## (+ sandals), shorts and sandals; cats with tiara and sunglasses. {"view": …}: "close" the clothing up close, "heads"
## tiara and sunglasses on the stand-in and on cats, "persona" Kai in the persona option "Jacke" (wear) beside the
## canon and the heaviest persona look (tris in the tags).
func _build_kit() -> void:
	Stage.add_floor(self, 9.0, {})
	match str(_params.get("view", "")):
		"close":
			var clothes: Array = [["jacket"], ["bathrobe", "sandals"], ["shorts"], ["sandals"]]
			for i in clothes.size():
				_kit_human(i, clothes[i] as Array, Vector3((float(i) - 1.5) * 0.85, 0, 0), -12.0 + 8.0 * float(i))
			Stage.add_camera(self, Vector3(0, 1.25, 3.6), Vector3(0, 0.75, 0), 40.0)
		"heads":
			for i in 2:
				var m: Dictionary = KIT_HUMAN.duplicate(true)
				m["props"] = [["tiara"], ["sunglasses"]][i]
				_place("kit_human_%d" % i, m, Vector3(-0.5 + 1.0 * float(i), 0, -1.6), 18.0 - 36.0 * float(i), "")
			_kit_cat("long", "solid", "upright", ["tiara"], Vector3(-0.3, 0, 0.55), 18.0, false)
			_kit_cat("short", "tabby", "upright", ["sunglasses"], Vector3(0.3, 0, 0.55), -18.0, false)
			Stage.add_camera(self, Vector3(0, 0.85, 2.5), Vector3(0, 0.62, -0.4), 40.0)
		"persona":
			var kai: Dictionary = _db_model("kai")
			var looks: Array = [[{}, "Kanon"], [{"wear": "lk_wear_jacket"}, "Jacke"],
				[{"hair": "lk_hair_curls", "beard": "lk_beard_stubble", "glasses": "lk_glasses_round",
				"wear": "lk_wear_jacket"}, "Locken · Bart · Brille · Jacke"]]
			for i in looks.size():
				var rig: CharacterRig = _place("persona_%d" % i, PersonaLook.apply(kai, looks[i][0] as Dictionary, DB.data),
					Vector3((float(i) - 1.0) * 1.1, 0, 0), 12.0 - 12.0 * float(i), "")
				tags.call("add_tag", rig, "%s · %d Tris" % [looks[i][1], MeshUtil.tri_count_tree(rig)], Vector3(0, 0, 0.5),
					TAG_COLORS["hero"], TAG_SIZE, true)
			Stage.add_camera(self, Vector3(0, 1.7, 4.3), Vector3(0, 0.85, 0), 40.0)
		_:
			var human: Array = [["tiara"], ["sunglasses"], ["jacket"], ["bathrobe", "sandals"], ["shorts"], ["sandals"]]
			for i in human.size():
				_kit_human(i, human[i] as Array, Vector3((float(i) - float(human.size() - 1) * 0.5) * 0.95, 0, -0.6),
					-10.0 + 4.0 * float(i))
			_kit_cat("long", "solid", "upright", ["tiara"], Vector3(-0.55, 0, 2.1), 10.0)
			_kit_cat("short", "tabby", "auto", ["sunglasses"], Vector3(0.6, 0, 2.1), -25.0)
			Stage.add_camera(self, Vector3(0, 2.0, 5.6), Vector3(0, 0.62, 0.3), 40.0)


## The humanoid stand-in with `props` (the tag names them).
func _kit_human(i: int, props: Array, pos: Vector3, yaw: float) -> void:
	var m: Dictionary = KIT_HUMAN.duplicate(true)
	m["props"] = props
	_place("kit_human_%d" % i, m, pos, yaw, " + ".join(PackedStringArray(props)))


## A gallery cat with `props` (`tag`: named "cat + <props>").
func _kit_cat(fur: String, pattern: String, pose: String, props: Array, pos: Vector3, yaw: float,
		tag: bool = true) -> void:
	var m: Dictionary = cat_model(fur, pattern, pose)
	m["props"] = props
	var label: String = "cat + " + " + ".join(PackedStringArray(props)) if tag else ""
	_place("kit_cat_" + "_".join(PackedStringArray(props)), m, pos, yaw, label, 0, false, CAT_TAG)


## A name tag at a point of the stage (row names).
func _tag_at(pos: Vector3, text: String) -> void:
	var marker := Node3D.new()
	marker.name = "Tag_" + text.validate_node_name()
	add_child(marker)
	marker.position = pos
	tags.call("add_tag", marker, text, Vector3.ZERO, TAG_COLORS["hero"], TAG_SIZE, false)


func _build_closeup(ids: Array, positions: Array, cam: Vector3, target: Vector3) -> void:
	Stage.add_floor(self, 9.0, {})
	for i in ids.size():
		var id: String = str(ids[i])
		var rig: CharacterRig = _place(id, Cast.model(id), positions[i] as Vector3, -15.0 if i % 2 == 0 else 15.0, "")
		rig.battle_stance = not id.begins_with("enm_")
	Stage.add_camera(self, cam, target, 40.0)


## Stops the rig at time `t` of `anim` (deterministic still for screenshots).
func _freeze(rig: CharacterRig, anim: StringName, t: float) -> void:
	rig.play(anim)
	rig.set_process(false)
	if CharacterRig.LOOPING.has(anim):
		rig.set("_cycles", t / float(CharacterRig.LOOP_PERIOD[anim]))
	else:
		rig.set("_t", t)
	if anim == &"die":
		rig.set("_dead", true)
	rig.call("_apply_pose", rig.call("_eval"))


func _default_primary(base: String) -> Dictionary:
	var defaults: Dictionary = {"humanoid": "#3aa9a0", "pug": "#d8b98a", "rodent": "#6b5b4e", "blob": "#6fbf4a",
		"insect": "#2b2b33", "robot": "#2f6fb3", "brute": "#7c8a94", "specter": "#e23e9b", "swarm": "#8c93a6",
		"cat": "#e08a3c"}
	return {"primary": defaults.get(base, "#888888")}


func _db_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var data: GameData = DB.data
	if data == null:
		return out
	for p: PartyMemberDef in data.all_party():
		out.append(p.id)
	for e: EnemyDef in data.all_enemies():
		out.append(e.id)
	return out


## Party members + every enemy of the floor-1 encounters (DB order, unique).
func _floor1_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var data: GameData = DB.data
	if data == null:
		return out
	for p: PartyMemberDef in data.all_party():
		out.append(p.id)
	var fdef: FloorDef = DB.floor_def(1) if DB.has_id("floors", "floor_1") else null
	if fdef == null:
		return out
	for enc: EncounterDef in fdef.encounters:
		for eid: String in enc.enemies:
			if not out.has(eid):
				out.append(eid)
	return out


func _db_name(id: String) -> String:
	if id.begins_with("enm_") and DB.has_id("enemies", id):
		return tr(DB.data.enemy(id).name)
	if DB.has_id("party", id):
		return tr(DB.data.party_member(id).name)
	return id


func _db_model(id: String) -> Dictionary:
	var data: GameData = DB.data
	if data == null:
		return {}
	if id.begins_with("enm_"):
		if DB.has_id("enemies", id):
			var e: EnemyDef = data.enemy(id)
			return e.model.duplicate(true) if e != null else {}
		return {}
	if DB.has_id("party", id):
		var p: PartyMemberDef = data.party_member(id)
		return p.model.duplicate(true) if p != null else {}
	return {}
