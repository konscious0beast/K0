extends Node3D
## Battle stage (02_TECH §1.6, 03_ART §8.2): arena from EnvKit (zone palette of the encounter), environment + key
## light, slot positions, CharacterRigs for party and enemies (CharacterBuilder), summons, the pseudo-unit train
## (Rattenkönigin, Gleis 9), the active-actor marker and looping status effects at the rigs.
## Private M5 helper (no class_name); presentation only — never touches BattleState.

## Display names of these ids changed (a duplicate enemy type appeared: "Mieterratte" → "Mieterratte A").
signal letters_changed(ids: PackedStringArray)

const StatusFx := preload("res://scenes/battle/status_fx.gd")
const TrainFx := preload("res://scenes/battle/train_fx.gd")

## 03_ART §8.2 (party faces −Z, enemies +Z).
const PARTY_SLOTS: Array[Vector3] = [Vector3(-1.3, 0, 3.0), Vector3(1.3, 0, 3.2), Vector3(-3.4, 0, 3.6),
	Vector3(3.4, 0, 3.8)]
const ENEMY_LAYOUTS: Array = [
	[Vector3(0, 0, -3.0)],
	[Vector3(-1.4, 0, -3.0), Vector3(1.4, 0, -3.0)],
	[Vector3(-2.4, 0, -2.6), Vector3(0, 0, -3.4), Vector3(2.4, 0, -2.6)],
	[Vector3(-3.0, 0, -2.4), Vector3(-1.0, 0, -3.4), Vector3(1.0, 0, -3.4), Vector3(3.0, 0, -2.4)],
]
const BOSS_POS: Vector3 = Vector3(0, 0, -4.5)
## Free slots next to a boss (summons, e.g. the Hausmeister's tenant rat).
const BOSS_SIDE_SLOTS: Array[Vector3] = [Vector3(-2.8, 0, -2.4), Vector3(2.8, 0, -2.4), Vector3(-1.6, 0, -1.8),
	Vector3(1.6, 0, -1.8)]
## Rattenkönigin on her derailed metro car (03_ART §8.2); the party steps back by 1 m. Her feet stand on the roof
## (PropKit wreck: roof top ≈ 3.7 m at x 0); at 3.0 m she stood 0.7 m inside the car and only her head showed above
## it in the command shots (visual pass).
const QUEEN_ID: String = "enm_boss_rattenkoenigin"
const QUEEN_POS: Vector3 = Vector3(0, 3.7, -6.0)
const WRECK_POS: Vector3 = Vector3(0, 0, -6.0)
const QUEEN_PARTY_SHIFT: Vector3 = Vector3(0, 0, 1.0)
const MARKER_PARTY: Color = Color("#22d3ee")
const MARKER_ENEMY: Color = Color("#ff4d4d")

var setup: BattleSetup = null
var quality: StringName = &"high"
var zone_palette: Dictionary = {}
var theme_id: String = "metro"
var arena: Node3D = null
var world_env: WorldEnvironment = null
var sun: DirectionalLight3D = null
var train: Node3D = null

var _rigs: Dictionary = {}          # combatant id → CharacterRig
var _home: Dictionary = {}          # combatant id → Vector3 (stage local)
var _info: Dictionary = {}          # combatant id → {"def_id", "name", "max_hp", "max_mp", "model", "party", "boss"}
var _status_fx: Dictionary = {}     # combatant id → StatusFx node
var _enemy_count: int = 0
var _has_boss: bool = false
var _queen: bool = false
var _marker: MeshInstance3D = null
var _marker_t: float = 0.0
var _marker_w: float = 1.0
var _letters: Dictionary = {}       # combatant id → "A"/"B"… for duplicate enemy types


## Builds the whole stage from the setup (party combatants + initial enemies exactly as BattleState.start creates
## them: party ids from the setup, enemies e0.. in the order of the valid enemy ids).
func build(p_setup: BattleSetup, p_quality: StringName = &"high") -> void:
	setup = p_setup
	quality = p_quality
	theme_id = setup.theme_id if setup.theme_id != "" else "metro"
	zone_palette = encounter_palette(setup)
	_queen = setup.enemy_ids.has(QUEEN_ID)
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = EnvKit.make_environment(theme_id, zone_palette, &"battle", quality)
	add_child(world_env)
	sun = EnvKit.make_zone_sun(theme_id, zone_palette, &"battle", quality)
	add_child(sun)
	arena = EnvKit.build_battle_arena(theme_id, zone_palette, setup.is_boss, setup.seed, quality)
	add_child(arena)
	if _queen:
		var wreck: Node3D = PropKit.build(&"wreck", setup.seed)
		wreck.name = "Wreck"
		var wreck_body: Node = wreck.get_node_or_null("Collision")
		if wreck_body != null:          # the stage has no physics (02_TECH §12.1 "Kampf: keine")
			wreck.remove_child(wreck_body)
			wreck_body.free()
		wreck.position = WRECK_POS
		add_child(wreck)
	_build_marker()
	for c: Combatant in setup.party:
		if c != null:
			_add_party(c)
	var valid: PackedStringArray = []
	for eid: String in setup.enemy_ids:
		if DB.has_id("enemies", eid):
			valid.append(eid)
	_enemy_count = valid.size()
	for i in valid.size():
		if DB.enemy(valid[i]).boss:
			_has_boss = true
	for i in valid.size():
		add_enemy("e%d" % i, valid[i], i, false)
	_assign_letters()


## Zone palette of the encounter's group (layout placement or living stray) merged over the floor palette; boss
## encounters without a placement use the floor palette (BattleSetup.palette).
static func encounter_palette(s: BattleSetup) -> Dictionary:
	var pal: Dictionary = s.palette.duplicate(true)
	var fdef: FloorDef = DB.floor_def(s.floor_index) if s.floor_index > 0 else null
	if fdef == null or fdef.layout.is_empty() or s.group_id == "":
		return pal
	var zone_id: String = ""
	var layout: Dictionary = fdef.layout
	for p: Variant in (layout.get("encounters_placed", []) as Array):
		var pd: Dictionary = p
		if str(pd.get("group_id", "")) == s.group_id:
			var cell: Array = pd.get("cell", [])
			if cell.size() == 2:
				for cv: Variant in (layout.get("cells", []) as Array):
					var cd: Dictionary = cv
					if int(cd.get("x", -1)) == int(cell[0]) and int(cd.get("y", -1)) == int(cell[1]):
						zone_id = str(cd.get("zone", ""))
			break
	if zone_id == "" and Game.state != null and Game.state.floor_run != null:
		var stray: Variant = Game.state.floor_run.strays.get(s.group_id, null)
		if stray is Dictionary:
			zone_id = str((stray as Dictionary).get("zone", ""))
	if zone_id == "":
		return pal
	for zv: Variant in (layout.get("zones", []) as Array):
		var zd: Dictionary = zv
		if str(zd.get("id", "")) == zone_id:
			var zp: Variant = zd.get("palette", {})
			if zp is Dictionary:
				for k: Variant in (zp as Dictionary).keys():
					pal[str(k)] = (zp as Dictionary)[k]
	return pal


func _process(delta: float) -> void:
	_marker_t += delta
	if _marker != null and _marker.visible:
		var s: float = _marker_w * (1.0 + 0.06 * sin(_marker_t * TAU * 1.2))
		_marker.scale = Vector3(s, 0.2, s)
		_marker.rotation.y += delta * 0.8


# --- units ----------------------------------------------------------------------------------------------------------

func _add_party(c: Combatant) -> void:
	var model: Dictionary = c.model.duplicate(true)
	if model.is_empty() and DB.has_id("party", c.def_id):
		model = DB.party_member(c.def_id).model.duplicate(true)
	var rig: CharacterRig = CharacterBuilder.build(model, 0)
	rig.name = "Unit_" + c.id
	rig.battle_stance = true
	rig.death_style = &"fall"
	rig.set_contact_shadow(quality != &"high")
	add_child(rig)
	var pos: Vector3 = PARTY_SLOTS[clampi(c.slot, 0, PARTY_SLOTS.size() - 1)]
	if _queen:
		pos += QUEEN_PARTY_SHIFT
	rig.position = pos
	rig.rotation.y = 0.0
	_rigs[c.id] = rig
	_home[c.id] = pos
	_info[c.id] = {"def_id": c.def_id, "name": c.display_name, "max_hp": c.max_hp(), "max_mp": c.max_mp(),
		"model": model, "party": true, "boss": false}
	if c.hp <= 0:
		rig.set_dead(true)
	_attach_status_fx(c.id, rig)


## Enemy rig at its slot (initial enemies and SUMMON events). `spawned` → appears with a smoke puff.
func add_enemy(id: String, def_id: String, slot: int, spawned: bool = true) -> CharacterRig:
	if not DB.has_id("enemies", def_id):
		push_warning("[BattleStage] unknown enemy '%s'" % def_id)
		return null
	if _rigs.has(id):
		remove_unit(id)
	var def: EnemyDef = DB.enemy(def_id)
	var rig: CharacterRig = CharacterBuilder.build(def.model, 3 + slot)
	rig.name = "Unit_" + id
	rig.death_style = &"dissolve"
	rig.set_contact_shadow(quality != &"high")
	add_child(rig)
	var pos: Vector3 = enemy_slot_position(slot, def.boss, def_id)
	rig.position = pos
	rig.rotation.y = PI
	_rigs[id] = rig
	_home[id] = pos
	var mp: int = int(def.stats.get("mp", 0))
	_info[id] = {"def_id": def_id, "name": def.name, "max_hp": int(def.stats.get("hp", 1)), "max_mp": mp,
		"model": def.model.duplicate(true), "party": false, "boss": def.boss}
	_attach_status_fx(id, rig)
	if spawned:
		Vfx.spawn(&"smoke", self, pos + Vector3(0, 0.4, 0), Color(0, 0, 0, 0), maxf(rig.size_factor(), 0.6))
		rig.scale = Vector3.ONE * 0.2
		var tw: Tween = rig.create_tween()
		tw.tween_property(rig, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_assign_letters()
	return rig


## Pseudo unit (SUMMON with a pu_ def id): the train is staged, not a rig.
func add_pseudo(id: String, def_id: String) -> void:
	var name_text: String = def_id
	if DB.has_id("pseudo_units", def_id):
		name_text = DB.pseudo_unit(def_id).name
	_info[id] = {"def_id": def_id, "name": name_text, "max_hp": 0, "max_mp": 0, "model": {}, "party": false,
		"boss": false, "pseudo": true}
	if train == null:
		train = TrainFx.new()
		train.name = "Train"
		add_child(train)
		train.call("setup", party_line_z(), quality)
	train.call("set_armed", true)


func remove_pseudo(id: String) -> void:
	if train != null and _info.has(id):
		train.call("set_armed", false)


## Slot position: boss center back, summons next to a boss, else the layout of the initial enemy count (slots
## beyond it use the 4-enemy layout). The Rattenkönigin stands on the wreck.
func enemy_slot_position(slot: int, is_boss: bool, def_id: String = "") -> Vector3:
	if def_id == QUEEN_ID:
		return QUEEN_POS
	if is_boss:
		return BOSS_POS
	if _has_boss:
		return BOSS_SIDE_SLOTS[clampi(slot - 1 if slot > 0 else 0, 0, BOSS_SIDE_SLOTS.size() - 1)]
	var n: int = clampi(_enemy_count, 1, 4)
	var layout: Array = ENEMY_LAYOUTS[n - 1]
	if slot >= 0 and slot < layout.size():
		return layout[slot]
	var four: Array = ENEMY_LAYOUTS[3]
	return four[clampi(slot, 0, 3)]


func remove_unit(id: String) -> void:
	var rig: CharacterRig = _rigs.get(id, null)
	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	_rigs.erase(id)
	var fx: Node = _status_fx.get(id, null)
	if fx != null and is_instance_valid(fx):
		fx.queue_free()
	_status_fx.erase(id)


func has_unit(id: String) -> bool:
	return _rigs.has(id) and is_instance_valid(_rigs[id])


func rig(id: String) -> CharacterRig:
	var r: CharacterRig = _rigs.get(id, null)
	return r if r != null and is_instance_valid(r) else null


func unit_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in _rigs.keys():
		out.append(str(k))
	return out


func info(id: String) -> Dictionary:
	return _info.get(id, {})


func home(id: String) -> Vector3:
	return _home.get(id, Vector3.ZERO)


## Display name incl. the letter of duplicate enemy types ("Kanalratte A").
func display_name(id: String) -> String:
	var d: Dictionary = _info.get(id, {})
	var n: String = tr(str(d.get("name", id)))
	var letter: String = str(_letters.get(id, ""))
	return n + (" " + letter if letter != "" else "")


func letter(id: String) -> String:
	return str(_letters.get(id, ""))


## World position of a rig anchor (falls back to home + height).
func anchor_pos(id: String, anchor_name: StringName) -> Vector3:
	var r: CharacterRig = rig(id)
	if r == null:
		return to_global(home(id) + Vector3(0, 1.0, 0)) if is_inside_tree() else home(id) + Vector3(0, 1.0, 0)
	var n: Node3D = r.anchor(anchor_name)
	if n == r:
		var h: float = r.height
		var off: Vector3 = Vector3(0, h * 0.55, 0)
		match anchor_name:
			&"overhead":
				off = Vector3(0, h + 0.25, 0)
			&"head":
				off = Vector3(0, h * 0.85, 0)
			&"feet":
				off = Vector3.ZERO
		return r.global_position + off if r.is_inside_tree() else r.position + off
	return n.global_position if n.is_inside_tree() else r.position + Vector3(0, r.height * 0.5, 0)


func unit_height(id: String) -> float:
	var r: CharacterRig = rig(id)
	return r.height if r != null else 1.0


func party_center() -> Vector3:
	return _center(true)


func enemy_center() -> Vector3:
	return _center(false)


## Z of the party line (train track).
func party_line_z() -> float:
	return PARTY_SLOTS[0].z + (QUEEN_PARTY_SHIFT.z if _queen else 0.0) + 0.1


func _center(party: bool) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for id: Variant in _rigs.keys():
		var d: Dictionary = _info.get(str(id), {})
		if bool(d.get("party", false)) != party:
			continue
		var r: CharacterRig = rig(str(id))
		if r == null or not r.visible:
			continue
		sum += home(str(id))
		n += 1
	if n == 0:
		return Vector3(0, 0, 3.1) if party else Vector3(0, 0, -3.0)
	return sum / float(n)


## Letters of duplicate enemy types in spawn order (ids sorted by their number: e2 before e10). A unit keeps its
## letter for the whole battle; a lone unit gets the first free letter when a second one of its type appears.
## Emits letters_changed with every id whose display name changed (HUD renames plates / CTB badges).
func _assign_letters() -> void:
	var by_def: Dictionary = {}
	var ids: Array = _info.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return id_number(str(a)) < id_number(str(b)))
	for idv: Variant in ids:
		var id: String = str(idv)
		var d: Dictionary = _info[id]
		if bool(d.get("party", false)) or bool(d.get("pseudo", false)):
			continue
		var list: Array = by_def.get(str(d["def_id"]), [])
		list.append(id)
		by_def[str(d["def_id"])] = list
	var changed: PackedStringArray = []
	for k: Variant in by_def.keys():
		var list2: Array = by_def[k]
		if list2.size() < 2:
			continue
		var used: Dictionary = {}
		for idv2: Variant in list2:
			if _letters.has(str(idv2)):
				used[str(_letters[str(idv2)])] = true
		var next: int = 0
		for idv3: Variant in list2:
			var id3: String = str(idv3)
			if _letters.has(id3):
				continue
			while used.has(String.chr(65 + next)):
				next += 1
			_letters[id3] = String.chr(65 + next)
			used[String.chr(65 + next)] = true
			changed.append(id3)
	if not changed.is_empty():
		letters_changed.emit(changed)


## Numeric part of a combatant id ("e12" → 12); sorts ids in spawn order.
static func id_number(id: String) -> int:
	return id.substr(1).to_int() if id.length() > 1 else 0


# --- markers and status loops -----------------------------------------------------------------------------------------

func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "ActiveMarker"
	var ring: TorusMesh = MeshUtil.torus(0.55, 0.68, 24, 3)
	_marker.mesh = ring
	_marker.material_override = Materials.glow(MARKER_PARTY, 2.2)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.scale = Vector3(1, 0.2, 1)
	_marker.visible = false
	add_child(_marker)


## Glowing ring under the actor ("" hides it).
func set_active(id: String) -> void:
	if _marker == null:
		return
	var r: CharacterRig = rig(id)
	if id == "" or r == null:
		_marker.visible = false
		return
	var party: bool = bool(info(id).get("party", false))
	_marker.material_override = Materials.glow(MARKER_PARTY if party else MARKER_ENEMY, 2.2)
	var w: float = clampf(r.size_factor() * 1.1, 0.7, 2.6)
	_marker.position = home(id) + Vector3(0, 0.03, 0)
	_marker_w = w
	_marker.scale = Vector3(w, 0.2, w)
	_marker.visible = true


func _attach_status_fx(id: String, r: CharacterRig) -> void:
	var fx: Node3D = StatusFx.new()
	fx.name = "StatusFx_" + id
	r.add_child(fx)
	fx.call("setup", r)
	_status_fx[id] = fx


func set_status_visual(id: String, status_id: String, on: bool) -> void:
	var fx: Node = _status_fx.get(id, null)
	if fx != null and is_instance_valid(fx):
		fx.call("set_status", status_id, on)


func clear_status_visuals(id: String) -> void:
	var fx: Node = _status_fx.get(id, null)
	if fx != null and is_instance_valid(fx):
		fx.call("clear")
