extends Node3D
## Character gallery (02_TECH §1.5, CI screenshot target §12.4): the floor-1 cast (03_ART §5.5) plus every party
## member / enemy from DB that the cast sheet does not know, lined up on a show stage under battle light.
## `page` (set in the .tscn variants): "cast" (default) | "bases" (all 9 archetypes, floor-2 stubs) |
## "anims" (Kai/Mopsula/rat/Hausmeister frozen in key poses) | "props" (every prop on a humanoid).

const Cast := preload("res://art/gallery/cast.gd")
const Stage := preload("res://art/gallery/gallery_stage.gd")

@export var page: String = "cast"

## Name tags under the figures (review M4: 26 px at 0.005 m/px was unreadable in the CI shots).
const LABEL_SIZE: int = 44

var rigs: Dictionary = {}          # id → CharacterRig
var _params: Dictionary = {}


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Stage.add_world(self, "metro", {}, &"battle")
	match page:
		"bases":
			_build_bases()
		"anims":
			_build_anims()
		"props":
			_build_props()
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


func _place(id: String, model: Dictionary, pos: Vector3, yaw_deg: float, label: String, seed: int = 0) -> CharacterRig:
	var rig: CharacterRig = CharacterBuilder.build(model, seed)
	rig.name = "Rig_" + id
	add_child(rig)
	rig.position = pos
	rig.rotation_degrees = Vector3(0, 180.0 + yaw_deg, 0)
	rig.battle_stance = true
	rigs[id] = rig
	if label != "":
		Stage.label(self, label, pos + Vector3(0, -0.05, 0.55), LABEL_SIZE)
	return rig


func _build_cast() -> void:
	Stage.add_floor(self, 9.0, {})
	var layout: Dictionary = {
		"enm_boss_hausmeister": [Vector3(-3.4, 0, -3.8), 12.0],
		"enm_boss_rattenkoenigin": [Vector3(2.8, 0, -4.4), -55.0],
		"enm_pendler": [Vector3(-5.0, 0, -0.6), 15.0],
		"enm_rattengardist": [Vector3(-3.5, 0, -0.4), 10.0],
		"enm_fahrscheinfresser": [Vector3(-1.9, 0, -0.6), 5.0],
		"enm_rattenschamane": [Vector3(-0.5, 0, -0.2), 0.0],
		"enm_rolltreppenkrabbe": [Vector3(1.2, 0, -0.5), -15.0],
		"enm_spruehgeist": [Vector3(3.1, 0, -0.3), -10.0],
		"enm_kellerspinne": [Vector3(4.8, 0, -0.2), -25.0],
		"enm_taubenschwarm": [Vector3(-4.0, 0, 2.6), 10.0],
		"enm_kanalratte": [Vector3(-2.5, 0, 2.8), 20.0],
		"kai": [Vector3(-1.0, 0, 2.6), 10.0],
		"mopsula": [Vector3(0.3, 0, 2.9), -15.0],
		"enm_kanalschleim": [Vector3(1.7, 0, 2.7), -10.0],
		"enm_kabelsalat": [Vector3(3.1, 0, 2.8), -20.0],
	}
	var known: Dictionary = {}
	for id: String in layout:
		var entry: Array = layout[id]
		var model: Dictionary = Cast.model(id)
		var db_model: Dictionary = _db_model(id)
		if not db_model.is_empty():
			model = db_model
		var rig: CharacterRig = _place(id, model, entry[0] as Vector3, float(entry[1]), str(Cast.CAST[id]["name"]),
			id.length())
		if id.begins_with("enm_"):
			rig.death_style = &"dissolve"
		known[id] = true
	# DB entries the cast sheet does not list (new content from data) appear in an extra front row
	var x: float = -5.0
	for id: String in _db_ids():
		if known.has(id):
			continue
		if x > 5.5:
			break
		_place(id, _db_model(id), Vector3(x, 0, 5.2), 0.0, id, id.length())
		x += 1.6
	var label := Stage.label(self, "PRIME TIME DUNGEON · CAST ETAGE 1", Vector3(0, 5.6, -6.5), 64, Palette.HYPE_GOLD)
	label.pixel_size = 0.006
	Stage.add_camera(self, Vector3(0, 5.2, 12.5), Vector3(0, 1.0, -0.6), 40.0)


func _build_bases() -> void:
	Stage.add_floor(self, 9.0, {})
	var bases: PackedStringArray = CharacterBuilder.supported_bases()
	var x: float = -6.0
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
		"insect": "#2b2b33", "robot": "#2f6fb3", "brute": "#7c8a94", "specter": "#e23e9b", "swarm": "#8c93a6"}
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
