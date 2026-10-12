class_name ExplorationScene extends Node3D
## Exploration screen (02_TECH §7.3, §9.2; GDD §2). Builds the floor of Game.state.floor_run from
## DungeonGenerator.generate(Game.floor_def(), floor_run.seed): rooms (EnvKit via FloorBuilder), closed gates, chests
## (opened ones open), enemy groups (without defeated groups / beaten bosses, living strays), floor events, stairs, safe
## doors, Kai (player.tscn), Mopsula (companion_follower.gd), the orbit camera and the ExplorationHud (M6).
## Reacts to room changes (Game.visit_room, Events.room_entered), interactions, field strikes, pulls and contacts
## (Events.encounter_triggered → the real-time combat in this room: the encounter command, Game.make_rt_setup, the
## CombatDirector; 07 §2), Events.stray_spawn_requested, and the stack protocol of the Router (setup / on_suspend /
## on_resume). The floor timer runs through Game (timer_running).
## Serializable ExploreEvents of what happened are kept in a short log (recent_events(); Brief §6b.2 "events out").
## 06 §1 (package A): the player body is the controlled character (Game.hero(): Kai or Graf Mopsula), the partner
## follows; `action` without a prompt uses the hero's field ability — Kai's field strike or Mopsula's bark (dazes the
## groups in the cone with line of sight, never starts a battle; contact with a dazed group = PREEMPTIVE). A switch in
## the safe room is applied on_resume (refresh_hero).

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const FB := preload("res://scenes/exploration/fallback_art.gd")
const FloorBuilder := preload("res://scenes/exploration/floor_builder.gd")
const CameraRig := preload("res://scenes/exploration/camera_rig.gd")
const Companion := preload("res://scenes/exploration/companion_follower.gd")
const PlayerBody := preload("res://scenes/exploration/player_controller.gd")
const EnemyActor := preload("res://scenes/exploration/enemy_actor.gd")
const Interactable := preload("res://scenes/exploration/interactable.gd")
const ChestInteractable := preload("res://scenes/exploration/chest_interactable.gd")
const GateInteractable := preload("res://scenes/exploration/gate_interactable.gd")
const EventInteractable := preload("res://scenes/exploration/event_interactable.gd")
const StairsInteractable := preload("res://scenes/exploration/stairs_interactable.gd")
const SafeDoorInteractable := preload("res://scenes/exploration/safe_door_interactable.gd")
const SceneryWall := preload("res://scenes/exploration/scenery_wall.gd")         # 06 package A: Kulissenwand
const NoteInteractable := preload("res://scenes/exploration/note_interactable.gd")   # 06 package A: Regie-Notiz
const ChoiceDialog := preload("res://scenes/exploration/choice_dialog.gd")
const PullRules := preload("res://scenes/exploration/pull_rules.gd")   # 07 §2.2, §7: the pull by a person (E34)
const PLAYER_SCENE: PackedScene = preload("res://scenes/exploration/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/exploration/enemy_actor.tscn")
const HUD_SCENE: String = "res://scenes/ui/exploration_hud.tscn"     # M6 scene: loaded at runtime (§13.2 rule 5)
const SAFE_DOOR_STEP: float = 1.2       # on_resume from a safe room: 1.2 m in front of the safe_door anchor
const SPAWN_LIFT: float = 0.05
const FALL_LIMIT_Y: float = -12.0
const LOG_SIZE: int = 64
const ZONE_ENV_SEC: float = 1.2
const NO_CELL: Vector2i = Vector2i(-999, -999)
const CAPTURE_STEP: float = 4.0         # capture mode: Kai starts 4 m towards the first door of the start room
const BOSS_EXTRA_ARM: float = 1.5       # boss rooms: longer arm so the large boss figure stays in the frame
const HITSTOP_SEC: float = 0.07         # field strike hit: 70 ms freeze + flash before the combat starts
const HITSTOP_RETRY_SEC: float = 0.05   # hitstop over while a Router transition runs: decide again after this
const REVEAL_BEAT_SEC: float = 0.25     # pause after an event prop animation before its result is shown
const MARKER_LIFT: float = 0.3          # focus marker above the focused object's visual top
const PROMPT_LIFT: float = 0.35         # HUD prompt anchor above the marker
const ROOM_LIGHT_FADE_SEC: float = 0.4  # quality low: the left room's light fades out, the entered room's fades in
const WALL_REACH_BONUS: float = 0.3     # 06 package A: the strike reaches the panel's face (half its depth + margin)

## Tests may switch this off: encounters then only emit Events.encounter_triggered (no real-time combat starts).
var auto_start_combat: bool = true
## Test hook: false → event outcomes (toast, gate, encounter) follow at once instead of after the prop animation.
var reveal_waits: bool = true
## Freeze + white flash on the struck group before the battle starts (0 = none).
var hitstop_sec: float = HITSTOP_SEC

var _params: Dictionary = {}
var _layout: FloorLayout = null
var _def: FloorDef = null
var _builder: FloorBuilder = null
var _world: Node3D = null
var _rooms_root: Node3D = null
var _props_root: Node3D = null
var _actors_root: Node3D = null
var _env: WorldEnvironment = null
var _env_fallback: bool = false
var _sun: DirectionalLight3D = null
var _player: PlayerBody = null
var _companion: Companion = null
var _camera: CameraRig = null
var _hud: ExplorationHud = null
var _enemies: Dictionary = {}           # group id → EnemyActor
var _interactables: Array[Interactable] = []
var _gates: Dictionary = {}             # gate key → GateInteractable
var _focused: Interactable = null
var _marker: MeshInstance3D = null      # bobbing HYPE_GOLD prism above the focused interactable
var _marker_t: float = 0.0
var _revealing: bool = false
var _dialog: ChoiceDialog = null
var _cur_cell: Vector2i = NO_CELL
var _cur_zone: String = ""
var _zone_set: bool = false             # false until the first room applied its zone palette
var _encounter_pending: bool = false
var _suspended: bool = false
var _built: bool = false
var _log: Array[ExploreEvent] = []
var _last_prompt: String = ""
var _hud_cell: Vector2i = NO_CELL
var _hud_yaw: float = INF
var _visible_cells: Dictionary = {}     # Vector2i → true: rooms drawn right now (current + door-linked)
var _prop_blockers: StaticBody3D = null # "PropBlockers": the permanent blocker boxes of chests and events (one body)
var _room_lights_set: bool = false      # quality low: first room application sets the lights without fading
var _strike_open: bool = false          # 06 package A: a strike is running and not yet reported (field_ability_used)
var _walls: Dictionary = {}             # 06 package A: secret id → SceneryWall (standing Kulissenwände)
var _notes: Dictionary = {}             # 06 package A: secret id → NoteInteractable
var _wall_hints: Dictionary = {}        # 06 package A: one chat hint per Kulissenwand and visit of the floor view


## Stores params only: {"spawn": &"start" | &"<safe room id>", "capture": bool}
func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Game.ensure_state()
	if Game.state == null or Game.state.floor_run == null:
		push_warning("[Exploration] no game state / floor run")
		return
	_def = Game.floor_def()
	if _def == null:
		push_warning("[Exploration] floor %d has no FloorDef" % Game.state.floor_run.index)
		return
	_layout = DungeonGenerator.generate(_def, Game.state.floor_run.seed)
	if _layout == null or _layout.cells.is_empty():
		push_warning("[Exploration] no layout for floor %d" % _def.index)
		return
	var quality: StringName = Game.settings.quality if Game.settings != null else &"high"
	_builder = FloorBuilder.new(_layout, _def, quality)
	_build_world()
	_build_actors()
	_build_hud()
	_build_director()                       # Echtzeitkampf (07, R2)
	var spawn_id: String = _spawn_param()
	_place_at_spawn(spawn_id)
	Events.stray_spawn_requested.connect(_on_stray_spawn_requested)
	Events.quest_progress.connect(_on_quest_progress)
	_built = true
	if Game.state.floor_run.visited.is_empty():
		Events.floor_entered.emit(_def.index)
	_update_room(true)
	Events.overlay_mode_requested.emit(&"explore")
	Sfx.music(StringName(_def.music) if _def.music != "" else &"explore")
	Game.timer_running = true
	_update_quest_hud()
	if _layout.safe_room_info.has(spawn_id) and not bool(_params.get("capture", false)):
		_enter_safe_room_after_load.call_deferred(spawn_id)


# ======================================================================================================================
# Public API (§7.3 / §9.2)
# ======================================================================================================================

## Game.timer_running = false; release pressed move actions.
func on_suspend() -> void:
	_suspended = true
	Game.timer_running = false
	if _player != null:
		_player.release_inputs()
	_set_target("", false)                  # 07 §2.2 (E34): the pull target is a moment of this view
	_set_focus(null)


## {} | {"from_safe_room": "<sr id>"} (a combat ends in this scene: rt_combat_ended, 07 §2.11)
func on_resume(payload: Dictionary) -> void:
	_suspended = false
	_encounter_pending = false
	if not _built:
		return
	# A dialog that is still open (e.g. a debug encounter started behind it) keeps the floor frozen and the timer off.
	_freeze(is_modal())
	if payload.has("from_safe_room"):
		_after_safe_room(str(payload["from_safe_room"]))
	refresh_hero()                          # 06 package A: a switch in the safe room
	_sync_groups()
	_companion.snap_behind()
	for it: Interactable in _interactables:
		if is_instance_valid(it) and it.has_method("refresh"):
			it.call("refresh")
	_last_prompt = "<refresh>"
	Events.overlay_mode_requested.emit(&"explore")
	Sfx.music(StringName(_def.music) if _def.music != "" else &"explore")
	Game.timer_running = not is_modal()
	_update_quest_hud()


## "" → nearest living non-boss group; same path as contact (NORMAL);
## no living group left → first non-boss encounter of the floor with group_id "".
func force_encounter(group_id: String = "") -> void:
	# Never behind a blocking dialog / during an outcome reveal or while suspended (GDD §2.6: dialogs block).
	if not _built or is_modal() or _suspended or _rt_busy():
		return
	if group_id != "":
		var actor: EnemyActor = _actor_at(group_id)
		if actor != null:
			_trigger_encounter(group_id, actor.encounter_id(), Rules.NORMAL)
			return
		var sp: EnemySpawn = _layout.enemy_by_id(group_id)
		if sp != null:
			_trigger_encounter(group_id, sp.encounter_id, Rules.NORMAL)
		else:
			push_warning("[Exploration] force_encounter: unknown group '%s'" % group_id)
		return
	var best: EnemyActor = null
	var best_d: float = INF
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or not is_instance_valid(a) or a.is_boss():
			continue
		var d: float = a.global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best != null:
		_trigger_encounter(best.group_id(), best.encounter_id(), Rules.NORMAL)
		return
	for enc: EncounterDef in _def.encounters:
		if not enc.boss:
			_trigger_encounter("", enc.id, Rules.NORMAL)
			return


func get_layout() -> FloorLayout:
	return _layout


func get_player_position() -> Vector3:
	return _player.global_position if _player != null else Vector3.ZERO


func get_player_cell() -> Vector2i:
	if _layout == null:
		return Vector2i.ZERO
	return _layout.world_to_cell(get_player_position())


# --- additional helpers (debug overlay, tests, autoplay) --------------------------------------------------------------

func get_player() -> PlayerBody:
	return _player


func get_camera_rig() -> CameraRig:
	return _camera


func get_companion() -> Companion:
	return _companion


func get_enemy(group_id: String) -> EnemyActor:
	return _actor_at(group_id)


## Living (placed) group ids, sorted.
func living_groups() -> PackedStringArray:
	var out: PackedStringArray = []
	for gid: Variant in _enemies.keys():
		if _actor_at(gid) != null:
			out.append(str(gid))
	out.sort()
	return out


func get_interactable(interact_id: String) -> Interactable:
	for it: Interactable in _interactables:
		if is_instance_valid(it) and it.interact_id == interact_id:
			return it
	return null


func focused_interactable() -> Interactable:
	return _focused


func active_dialog() -> ChoiceDialog:
	return _dialog if is_instance_valid(_dialog) else null


## A choice dialog is open or an event outcome is still being revealed (prop animation before the result).
func is_modal() -> bool:
	return active_dialog() != null or _revealing


func is_encounter_pending() -> bool:
	return _encounter_pending


## Last ExploreEvents of this scene (oldest first).
func recent_events() -> Array[ExploreEvent]:
	return _log.duplicate()


## Called by the scene itself and by interactables: performs `action` like the player key would (the keyboard's
## meaning: interact or the field ability, never a pull — 07 §7.1).
func perform_action() -> void:
	_do_action(&"key")


## 06 package A: the bodies follow Game.hero() — the player becomes the hero, the follower the partner (spawn and after
## a switch in the safe room). No-op when they already match.
func refresh_hero() -> void:
	if _player == null or _companion == null:
		return
	var hero: String = Game.hero()
	var partner: String = Game.partner()
	_apply_field_talents()                  # talents may have been picked in the safe room, with or without a switch
	if _player.hero_id == hero and _companion.member_id == partner:
		return
	_player.name = "Hero"                   # free the node names before the follower takes "Kai" / "Mopsula"
	_companion.set_member(partner)
	_player.set_hero(hero)
	_player.name = _node_name(hero)
	_companion.snap_behind()
	if _camera != null:
		_camera.set_leader(hero)            # framing per leader (look-at height, distance; the follower in view)
		_camera.snap(_player.rotation.y)
	if _hud != null and _hud.has_method("refresh_hero"):
		_hud.call("refresh_hero")
	_last_prompt = "<refresh>"


static func _node_name(member_id: String) -> String:
	return "Mopsula" if member_id == "mopsula" else "Kai"


## 06 packages A × B: the leader's field talents (HeroRules.field_mods — "Weit ausholen" → Feldschlag reach, "Bellen
## in Stereo" → Bellen reach, "Schwer vermittelbar" → Bellen cooldown) onto the player body. On spawn and on every
## resume (talents are only picked in the safe room); nothing is recorded — the encounter / secret it causes is.
func _apply_field_talents() -> void:
	if _player != null:
		_player.set_field_mods(HeroRules.field_mods(Game.state, DB.data))


# ======================================================================================================================
# Building
# ======================================================================================================================

func _build_world() -> void:
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	var env: Environment = _builder.make_environment()
	_env_fallback = env.has_meta(FB.META_FALLBACK)
	_env.environment = env
	add_child(_env)
	_sun = _builder.make_sun()
	_sun.name = "Sun"
	add_child(_sun)
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_rooms_root = Node3D.new()
	_rooms_root.name = "Rooms"
	_world.add_child(_rooms_root)
	_props_root = Node3D.new()
	_props_root.name = "Interactables"
	_world.add_child(_props_root)
	_actors_root = Node3D.new()
	_actors_root.name = "Actors"
	_world.add_child(_actors_root)
	_builder.build_rooms(_rooms_root, _world)
	_builder.build_door_lintels(_world)
	var fr: FloorRun = Game.state.floor_run
	var k: int = 0
	for g: Dictionary in _layout.gates:
		k += 1
		var key: String = str(g["key"])
		if fr.opened_gates.has(key):
			continue
		if Secrets.is_secret_requirement(str(g["requires"])):     # 06 package A: Kulissenwand instead of a gate
			var wall: SceneryWall = SceneryWall.new()
			wall.transform = _builder.door_transform(g["cell"], int(g["dir"]))
			wall.setup_gate(g, _builder.palette_at(g["cell"]), SeedUtil.derive(_layout.seed, "gate", k))
			_add_interactable(wall)
			_gates[key] = wall
			_walls[wall.secret_id] = wall
			continue
		var gate: GateInteractable = GateInteractable.new()
		gate.transform = _builder.door_transform(g["cell"], int(g["dir"]))
		gate.setup_gate(g, _builder.palette_at(g["cell"]), SeedUtil.derive(_layout.seed, "gate", k))
		_add_interactable(gate)
		_gates[key] = gate
	for ch: ChestSpawn in _layout.chests:
		var chest: ChestInteractable = ChestInteractable.new()
		chest.transform = _placement(ch.cell, ch.offset)
		chest.setup_chest(ch, _builder.palette_at(ch.cell), SeedUtil.derive(_layout.seed, "chest_prop", ch.index()),
			fr.opened_chests.has(ch.id))
		_add_interactable(chest)
	for i in _layout.events.size():
		var ev: EventSpawn = _layout.events[i]
		var evi: EventInteractable = EventInteractable.new()
		evi.transform = _placement(ev.cell, ev.offset)
		_add_interactable(evi)
		evi.setup_event(ev, _builder.palette_at(ev.cell), SeedUtil.derive(_layout.seed, "event_prop", i))
	_build_notes()
	var stairs: StairsInteractable = StairsInteractable.new()
	stairs.transform = _builder.anchor(_layout.stairs, &"stairs")
	stairs.setup_stairs(_def.index + 1)
	_add_interactable(stairs)
	for c: Vector2i in _layout.safe_rooms:
		var sid: String = _layout.safe_room_at(c)
		var info: Dictionary = _layout.safe_room_info.get(sid, {})
		var door: SafeDoorInteractable = SafeDoorInteractable.new()
		door.transform = _builder.anchor(c, &"safe_door")
		door.setup_door(sid, str(info.get("name", "")))
		_add_interactable(door)
	_merge_prop_blockers()


## 06 package A: Regie-Notizen of the floor that were not read yet (a note behind a standing wall stays hidden).
func _build_notes() -> void:
	for s: Dictionary in Secrets.list(_def):
		var sid: String = str(s.get("id", ""))
		if str(s.get("kind", "")) != "note" or Secrets.is_open(Game.state, sid):
			continue
		var note: NoteInteractable = NoteInteractable.new()
		var cell: Vector2i = JsonUtil.arr_to_vec2i(s.get("cell", []), Vector2i.ZERO)
		note.transform = _placement(cell, JsonUtil.arr_to_vec2(s.get("offset", [])))
		var behind: String = str(s.get("behind", ""))
		note.setup_note(s, behind != "" and not Secrets.is_open(Game.state, behind))
		_add_interactable(note)
		_notes[sid] = note


## The permanent blocker boxes of chests and floor events (never removed) move into ONE static body "PropBlockers"
## (layer 1; 02_TECH §12.1 Physik: before, every interactable had its own body). The camera ignores that body like the
## single blockers before. Gates keep their own "Blocker" (freed when the gate opens).
func _merge_prop_blockers() -> void:
	_prop_blockers = StaticBody3D.new()
	_prop_blockers.name = "PropBlockers"
	_prop_blockers.collision_layer = Interactable.LAYER_WORLD
	_prop_blockers.collision_mask = 0
	_world.add_child(_prop_blockers)
	var to_world: Transform3D = _world.global_transform.affine_inverse()
	for it: Interactable in _interactables:
		if it is GateInteractable:
			continue
		var b: StaticBody3D = it.get_node_or_null("Blocker") as StaticBody3D
		if b == null:
			continue
		var xf: Transform3D = to_world * b.global_transform
		for ch: Node in b.get_children():
			var cs: CollisionShape3D = ch as CollisionShape3D
			if cs == null:
				continue
			b.remove_child(cs)
			cs.transform = xf * cs.transform
			_prop_blockers.add_child(cs)
		it.remove_child(b)
		b.free()


## World transform of a placed object: room centre + offset, facing the room centre (or the entrance when centred).
func _placement(cell: Vector2i, offset: Vector2) -> Transform3D:
	var center: Vector3 = _layout.cell_to_world(cell)
	var pos: Vector3 = center + Vector3(offset.x, 0.0, offset.y)
	var yaw: float = _builder.entrance_yaw(cell)
	if offset.length() > 0.5:
		yaw = Rules.yaw_of(Rules.flat_dir(pos, center))
	return Transform3D(Basis(Vector3.UP, yaw), pos)


func _add_interactable(it: Interactable) -> void:
	it.scene = self
	_props_root.add_child(it)
	_interactables.append(it)


func _build_actors() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerBody
	_player.set_hero(Game.hero())           # 06 package A: Kai or Graf Mopsula leads
	_player.name = _node_name(_player.hero_id)
	_apply_field_talents()
	_actors_root.add_child(_player)
	_player.action_requested.connect(_on_player_action)
	_companion = Companion.new()
	_companion.member_id = Game.partner()
	_companion.leader = _player
	_actors_root.add_child(_companion)
	_camera = CameraRig.new()
	_camera.target = _player
	_camera.follower = _companion
	_camera.set_leader(_player.hero_id)
	if _prop_blockers != null:
		_camera.exclude.append(_prop_blockers.get_rid())
	add_child(_camera)
	for e: EnemySpawn in _layout.enemies:
		if not _is_defeated(e):
			_spawn_enemy(e)
	_sync_groups()


func _build_hud() -> void:
	if not ResourceLoader.exists(HUD_SCENE):
		return
	var packed: PackedScene = load(HUD_SCENE) as PackedScene
	if packed == null:
		return
	var node: Node = packed.instantiate()
	_hud = node as ExplorationHud
	if _hud == null:
		node.queue_free()
		return
	add_child(_hud)
	var visited: Array[Vector2i] = []
	visited.assign(Game.state.floor_run.visited)
	_hud.bind_layout(_layout, visited)


func _spawn_param() -> String:
	var sp: Variant = _params.get("spawn", &"start")
	var s: String = str(sp)
	return s if s != "" else "start"


## Kai at the start (anchor player_spawn, looking through the first door) or in front of a safe-room door.
func _place_at_spawn(spawn_id: String) -> void:
	if _layout.safe_room_info.has(spawn_id):
		_place_before_safe_door(spawn_id)
	else:
		var t: Transform3D = _builder.anchor(_layout.start, &"player_spawn")
		var yaw: float = _builder.entrance_yaw(_layout.start)
		var rc: RoomCell = _layout.cell_at(_layout.start)
		if rc != null:
			for b: int in RoomCell.DIR_BITS:
				if rc.has_door(b):
					var off: Vector2i = RoomCell.dir_offset(b)
					yaw = atan2(-float(off.x), -float(off.y))
					break
		var pos: Vector3 = t.origin
		if bool(_params.get("capture", false)):
			# Still image (capture): a few metres towards the first door, so the next room is in the picture.
			pos += Vector3(-sin(yaw), 0.0, -cos(yaw)) * CAPTURE_STEP
		_player.teleport(pos + Vector3(0.0, SPAWN_LIFT, 0.0), yaw)
	_camera.snap(_player.rotation.y)
	_companion.snap_behind()


func _place_before_safe_door(safe_room_id: String) -> void:
	var info: Dictionary = _layout.safe_room_info.get(safe_room_id, {})
	var cell: Vector2i = info.get("cell", _layout.start)
	var t: Transform3D = _builder.anchor(cell, &"safe_door")
	var front: Vector3 = Rules.flat_forward(t.basis)
	var pos: Vector3 = t.origin + front * SAFE_DOOR_STEP
	var center: Vector3 = _layout.cell_to_world(cell)
	var look: Vector3 = Rules.flat_dir(pos, center)
	var yaw: float = Rules.yaw_of(look) if look != Vector3.ZERO else Rules.yaw_of(front)
	_player.teleport(pos + Vector3(0.0, SPAWN_LIFT, 0.0), yaw)
	_camera.snap(yaw)


func _enter_safe_room_after_load(safe_room_id: String) -> void:
	if not is_inside_tree() or _suspended:
		return
	enter_safe_room(safe_room_id)


# ======================================================================================================================
# Enemies
# ======================================================================================================================

## Living actor of a group id (null for unknown / freed / queued-for-deletion nodes; never casts a freed object).
func _actor_at(group_id: Variant) -> EnemyActor:
	var o: Variant = _enemies.get(group_id, null)
	if o == null or not is_instance_valid(o):
		return null
	var a: EnemyActor = o as EnemyActor
	if a == null or a.is_queued_for_deletion():
		return null
	return a


func _is_defeated(e: EnemySpawn) -> bool:
	var fr: FloorRun = Game.state.floor_run
	if fr.defeated_groups.has(e.id):
		return true
	if e.is_stray() and not fr.strays.has(e.id):
		return true
	if e.is_boss:
		var suffix: String = e.id.get_slice("_", 1)
		if suffix == "qb" and fr.quarter_boss_defeated:
			return true
		if suffix == "fb" and fr.floor_boss_defeated:
			return true
		if e.lead_enemy_id != "" and bool(Game.get_flag("defeated_" + e.lead_enemy_id, false)):
			return true
	return false


func _encounter_def(enc_id: String) -> EncounterDef:
	var enc: EncounterDef = _def.encounter(enc_id)
	if enc == null and DB.has_id("encounters", enc_id):
		enc = DB.encounter(enc_id)
	return enc


func _spawn_enemy(e: EnemySpawn) -> EnemyActor:
	var enc: EncounterDef = _encounter_def(e.encounter_id)
	if e.lead_enemy_id == "" and enc != null and not enc.enemies.is_empty():
		e.lead_enemy_id = enc.enemies[0]
	var def: EnemyDef = DB.enemy(e.lead_enemy_id) if DB.has_id("enemies", e.lead_enemy_id) else null
	var center: Vector3 = _layout.cell_to_world(e.cell)
	var home: Vector3 = center + Vector3(e.offset.x, 0.0, e.offset.y)
	if e.is_boss:
		home = _builder.anchor(e.cell, &"boss_spot").origin + Vector3(e.offset.x, 0.0, e.offset.y)
	var actor: EnemyActor = ENEMY_SCENE.instantiate() as EnemyActor
	actor.setup_spawn(e, home + Vector3(0.0, SPAWN_LIFT, 0.0), center, def, enc.enemies.size() if enc != null else 1,
		_player, self)
	if e.is_boss:
		actor.face(_builder.entrance_yaw(e.cell))
	_actors_root.add_child(actor)
	actor.state_changed.connect(_on_enemy_state_changed)
	_enemies[e.id] = actor
	_rt_setup_actor(actor)                  # Echtzeitkampf (07, R2): stairs rule, show-boss frame
	return actor


## Removes defeated / vanished groups, spawns living strays that have no node yet (after load / resume).
func _sync_groups() -> void:
	var fr: FloorRun = Game.state.floor_run
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or not is_instance_valid(a):
			_enemies.erase(gid)
			continue
		if _is_defeated(a.spawn):
			a.queue_free()
			_enemies.erase(gid)
	for gid: Variant in fr.strays.keys():
		if _enemies.has(gid):
			continue
		var info: Dictionary = fr.strays[gid]
		_spawn_stray(str(info.get("zone", "")), str(gid), str(info.get("enc", "")))


func _spawn_stray(zone_id: String, group_id: String, encounter_id: String) -> EnemyActor:
	var cell: Vector2i = stray_cell(zone_id)
	if cell == NO_CELL:
		push_warning("[Exploration] no cell for stray %s in zone '%s'" % [group_id, zone_id])
		return null
	var e: EnemySpawn = EnemySpawn.make(group_id, cell, _encounter_def(encounter_id), Vector2.ZERO, &"PATROL")
	e.encounter_id = encounter_id
	e.is_boss = false
	return _spawn_enemy(e)


## Stray cell (§7.3 + GDD §2.7): cell of the zone (not START/SAFE/boss/stairs, no living group) with ≥ 2 cell changes
## (BFS, current gates) to Kai's cell and the largest such distance; ties: smallest y, then x. Constraints are relaxed
## step by step if the zone has no such cell.
func stray_cell(zone_id: String) -> Vector2i:
	var kai_cell: Vector2i = _cur_cell if _cur_cell != NO_CELL else _layout.start
	var dist: Dictionary = _layout.distances(kai_cell, Game.state.floor_run.opened_gates)
	var occupied: Dictionary = {}
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null and is_instance_valid(a):
			occupied[a.spawn.cell] = true
	for pass_i in 4:
		var best: Vector2i = NO_CELL
		var best_d: int = -1
		for c: Vector2i in _layout.zone_cells(zone_id):
			var rc: RoomCell = _layout.cell_at(c)
			if rc.kind != RoomCell.Kind.NORMAL and rc.kind != RoomCell.Kind.GATE:
				continue
			var d: int = int(dist.get(c, -1))
			if pass_i < 3 and d < 0:
				continue
			if pass_i < 2 and occupied.has(c):
				continue
			if pass_i < 1 and d < 2:
				continue
			if d > best_d:
				best_d = d
				best = c
		if best != NO_CELL:
			return best
	return NO_CELL


func _on_stray_spawn_requested(zone_id: String, group_id: String, encounter_id: String) -> void:
	if not is_inside_tree() or not _built or _enemies.has(group_id):
		return
	_spawn_stray(zone_id, group_id, encounter_id)


func _on_enemy_state_changed(group_id: String, state: StringName) -> void:
	if not is_inside_tree():
		return
	_log_event(ExploreEvent.Type.ENEMY_STATE, {"group_id": group_id, "state": String(state)})
	if state == &"ALERT" and _camera != null:
		_camera.kick_alert()


# ======================================================================================================================
# Frame update
# ======================================================================================================================

func _physics_process(delta: float) -> void:
	if not _built or _suspended:
		return
	_marker_t += delta
	_player.camera_yaw = _camera.yaw
	if _player.global_position.y < FALL_LIMIT_Y:
		var c: Vector2i = _cur_cell if _cur_cell != NO_CELL else _layout.start
		_player.teleport(_layout.cell_to_world(c) + Vector3(0.0, 0.5, 0.0), _player.rotation.y)
		_companion.snap_behind()
	_update_room(false)
	_update_actor_visibility()
	if _rt_busy():                          # Echtzeitkampf (07 §2.4, R2): no interactions, no field ability
		return
	_update_focus()
	_place_marker()
	_check_strike()
	if _strike_open and not _player.is_striking():
		_report_field_ability(&"strike", 0)
	_rt_triggers(delta)                     # Echtzeitkampf (07 §2.2, R2): weapon reach, 4 s chase
	_pull_frame()                           # 07 §2.2, §7 (E34): the target of a pull, its frame and hint
	if _hud != null:
		var yaw: float = _player.rotation.y
		if _cur_cell != _hud_cell or absf(wrapf(yaw - _hud_yaw, -PI, PI)) > 0.02:
			_hud_cell = _cur_cell
			_hud_yaw = yaw
			_hud.set_player(_cur_cell, yaw)


func _update_room(force: bool) -> void:
	var cell: Vector2i = _layout.world_to_cell(_player.global_position)
	var rc: RoomCell = _layout.cell_at(cell)
	if rc == null or (cell == _cur_cell and not force):
		return
	_cur_cell = cell
	var first: bool = Game.visit_room(cell)
	if first and _hud != null:
		_hud.mark_visited(cell)
	Events.room_entered.emit(cell, int(rc.kind), first)
	_log_event(ExploreEvent.Type.ROOM_ENTERED, {"cell": [cell.x, cell.y], "kind": RoomCell.kind_to_string(rc.kind),
		"first_visit": first})
	_hint_wall(cell)
	_zone_environment(cell)
	_apply_room_visibility(cell)
	if _camera != null and not _camera.combat:
		var boss_room: bool = rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS
		_camera.frame_extra_arm = BOSS_EXTRA_ARM if boss_room else 0.0
	_rt_on_room(cell)                       # Echtzeitkampf (07 §8.10, §9.6, R2): prewarm extras, show boss


## Only the current room and the rooms linked to it by a door are drawn: rooms have no ceiling, so the high camera
## would otherwise show wall tops, floors, props and actors of every room around (03_ART §6.1 "darüber
## Fog/Hintergrund"). Visual only — collisions, physics and AI keep running everywhere.
func _apply_room_visibility(cell: Vector2i) -> void:
	_visible_cells.clear()
	_visible_cells[cell] = true
	for n: Vector2i in _layout.linked(cell):
		_visible_cells[n] = true
	for c: Variant in _builder.rooms.keys():
		var room: Node3D = _builder.rooms[c] as Node3D
		if room != null and is_instance_valid(room):
			room.visible = _visible_cells.has(c)
			if _builder.quality != &"high":
				_set_room_light(room, c == cell)
	_room_lights_set = true
	for it: Interactable in _interactables:
		if not is_instance_valid(it):
			continue
		var shown: bool = false
		for c: Vector2i in it.occupied_cells(_layout):
			shown = shown or _visible_cells.has(c)
		it.visible = shown
	_update_actor_visibility()


## Quality low (02_TECH §3.4, §12.1 "OmniLight3D aktiv ≤ 2"): only the current room keeps its omni light; the shown
## neighbour rooms stay in ambient + sun light. On a room change the old light fades out and the new one in.
func _set_room_light(room: Node3D, on: bool) -> void:
	var light: OmniLight3D = room.get_node_or_null("Light") as OmniLight3D
	if light == null:
		return
	if not light.has_meta(&"base_energy"):
		light.set_meta(&"base_energy", light.light_energy)
	var base: float = float(light.get_meta(&"base_energy"))
	var target: float = base if on else 0.0
	if light.has_meta(&"fade_tween"):
		var old_tw: Tween = light.get_meta(&"fade_tween") as Tween
		if old_tw != null and old_tw.is_valid():
			old_tw.kill()
	if not _room_lights_set or not is_inside_tree() or not room.visible:
		light.light_energy = target
		light.visible = on
		return
	light.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(light, "light_energy", target, ROOM_LIGHT_FADE_SEC)
	if not on:
		tw.tween_callback(func() -> void: light.visible = false)
	light.set_meta(&"fade_tween", tw)


func _update_actor_visibility() -> void:
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null:
			a.visible = _visible_cells.has(_layout.world_to_cell(a.global_position)) if _rt_cell == NO_CELL \
				else _rt_actor_shown(str(gid), a)


## Zone palettes override the floor palette (§4.4.7): fog/background and ambient blend to the zone of the room.
func _zone_environment(cell: Vector2i) -> void:
	var rc: RoomCell = _layout.cell_at(cell)
	if rc == null or (_zone_set and rc.zone == _cur_zone) or _env == null or _env.environment == null:
		return
	var first: bool = not _zone_set
	_zone_set = true
	_cur_zone = rc.zone
	var env: Environment = _env.environment
	var pal: Dictionary = _layout.zone_palette(cell, _def.palette)
	var fog: Color = FB.col(pal, "fog", env.fog_light_color)
	var amb: Color = FB.col(pal, "ambient", env.ambient_light_color)
	var bg: Color = FB.background_of(fog)          # 03_ART §4.2: background = fog × 0.6
	if first or not is_inside_tree():
		env.background_color = bg
		env.fog_light_color = fog
		env.ambient_light_color = amb
		return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(env, "background_color", bg, ZONE_ENV_SEC)
	tw.tween_property(env, "fog_light_color", fog, ZONE_ENV_SEC)
	tw.tween_property(env, "ambient_light_color", amb, ZONE_ENV_SEC)


## Focused interactable: within 1.5 m (+ extent) and in the 120° cone in front of Kai, nearest first.
func _update_focus() -> void:
	var best: Interactable = null
	if not is_modal() and not _encounter_pending:
		var pos: Vector3 = _player.global_position
		var fwd: Vector3 = _player.flat_forward()
		var best_d: float = INF
		for it: Interactable in _interactables:
			if not is_instance_valid(it) or not it.can_reach(pos, fwd) or not it.is_available():
				continue
			var d: float = it.reach_distance(pos)
			if d < best_d:
				best_d = d
				best = it
	_set_focus(best)


## Focus = HUD prompt + in-world highlight (cyan outline on the prop, bobbing gold marker above it; GDD §14.3
## "Interaktionsprompt über Objekt" — the HUD prompt itself has no world anchor yet, see ExplorationHud).
func _set_focus(it: Interactable) -> void:
	if it != _focused:
		if _focused != null and is_instance_valid(_focused):
			_focused.set_highlight(false)
		if it != null:
			it.set_highlight(true)
	_focused = it
	_place_marker()
	var prompt: String = it.prompt_text() if it != null else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		if _hud != null:
			_hud.set_prompt(prompt)


func _place_marker() -> void:
	if _marker == null:
		if _world == null:
			return
		_marker = FB.focus_marker()
		_marker.name = "FocusMarker"
		_world.add_child(_marker)
	var it: Interactable = _focused if _focused != null and is_instance_valid(_focused) else null
	_marker.visible = it != null
	if it != null:
		var bob: float = sin(_marker_t * TAU * 1.2) * 0.08
		_marker.global_position = it.marker_position() + Vector3(0.0, MARKER_LIFT + bob, 0.0)
	# HUD prompt above the object (not over it): projected marker top, fixed (no bob) so the panel does not wobble
	if _hud != null:
		var cam: Camera3D = _camera.camera() if _camera != null else null
		var top: Vector3 = it.marker_position() + Vector3(0.0, MARKER_LIFT + PROMPT_LIFT, 0.0) if it != null \
			else Vector3.ZERO
		if it != null and cam != null and cam.is_inside_tree() and not cam.is_position_behind(top):
			_hud.set_prompt_anchor(cam.unproject_position(top))
		else:
			_hud.set_prompt_anchor(Vector2.INF)
		_marker.rotation = Vector3(PI, _marker_t * 2.0, 0.0)


func _on_player_action() -> void:
	_do_action(_player.action_source if _player != null else &"key")


## `action` from `source` (&"key" | &"pad" | &"touch"): interact (priority), the pull of the targeted lead (real time:
## the pad's A with the lead in slot 1's range, the touch button with a lead targeted — 07 §7.2, §7.3), else the
## hero's field ability.
func _do_action(source: StringName) -> void:
	# Router.busy: the fade back in after a battle / safe room (or out to the next screen) is still running — a mashed
	# confirm key (results screen, safe-room menu) must not strike or interact through it.
	if not _built or _suspended or is_modal() or _encounter_pending or Router.busy or _rt_busy():
		return
	_update_focus()
	if _focused != null and is_instance_valid(_focused) and _focused.is_available():
		_focused.interact()
		return
	if _pull_by_action(source):
		return
	if _player.field_ability() == &"bark":     # 06 package A: Graf Mopsula leads
		if _player.start_bark():
			_camera.kick_strike()
			bark_now()
		return
	if _player.start_strike():
		_camera.kick_strike()
		_strike_open = true


## 06 §1.3: dazes every group in the bark cone (Rules.bark_hits with the hero's reach) that the bark can reach (line of
## sight on layer `world`); bosses and groups that perceive nothing only twitch. Never starts a battle. Returns the
## number of dazed groups (Events.field_ability_used, chat line on a hit).
func bark_now() -> int:
	var pos: Vector3 = _player.global_position
	var fwd: Vector3 = _player.flat_forward()
	var hits: int = 0
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or not is_instance_valid(a):
			continue
		if not Rules.bark_hits(pos, fwd, a.global_position, _player.field_range_pm):
			continue
		if not _bark_reaches(pos, a.global_position):
			continue
		if a.daze():
			hits += 1
	_report_field_ability(&"bark", hits)
	if hits > 0:
		Show.chat("chat_bark")
		_target_dazed()                     # 07 E35: the bark picks the target — key 1 / A / the button = Erstschlag
	for sid: Variant in _walls.keys():                 # 06 §2.7: the bark knocks Kulissenwände over, too
		var w: SceneryWall = _walls[sid] as SceneryWall
		if w == null or not is_instance_valid(w) or w.opened:
			continue
		var wp: Vector3 = w.reach_point(pos)
		if Rules.bark_hits(pos, fwd, wp, _player.field_range_pm) and _bark_reaches(pos, wp, w.blocker_rid()):
			knock_wall(str(sid))
	return hits


## The bark is blocked by walls (ray on layer `world` at knee height, like the enemies' line of sight); `also` = one
## more body the ray ignores (the Kulissenwand the bark aims at).
func _bark_reaches(from: Vector3, to: Vector3, also: RID = RID()) -> bool:
	if not is_inside_tree():
		return true
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3(0.0, 0.5, 0.0),
		to + Vector3(0.0, 0.5, 0.0), Interactable.LAYER_WORLD)
	var ex: Array[RID] = []
	if _prop_blockers != null:
		ex.append(_prop_blockers.get_rid())
	if also.is_valid():
		ex.append(also)
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _report_field_ability(ability: StringName, hits: int) -> void:
	if ability == &"strike":
		if not _strike_open:
			return
		_strike_open = false
	Events.field_ability_used.emit(_player.hero_id, ability, hits)


## Field strike: the first group inside the 100° arc of the strike reach (1.8 m × Kai's field_range_pm talents) during
## the hitting part of the swing starts the combat (07 §2.2: the strike is its opener).
func _check_strike() -> void:
	if _encounter_pending or not _player.is_strike_hitting():
		return
	var pos: Vector3 = _player.global_position
	var fwd: Vector3 = _player.flat_forward()
	var hit: EnemyActor = null
	var hit_d: float = INF
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or not is_instance_valid(a):
			continue
		if not Rules.in_arc(pos, fwd, a.global_position, _player.strike_reach(), Rules.STRIKE_ARC_DEG):
			continue
		var d: float = Rules.flat_dist(pos, a.global_position)
		if d < hit_d:
			hit_d = d
			hit = a
	if hit != null:
		var adv: int = Rules.strike_advantage(hit.state, hit.global_position, hit.flat_forward(), pos, hit.is_boss(),
			Balance.BACK_DOT)
		_report_field_ability(&"strike", 1)
		_rt_open = {"kind": "strike", "target": "e0"}       # 07 §2.2: the field strike opens the combat (pull)
		_strike_hit(hit, adv, _opener(hit, adv))
		return
	for sid: Variant in _walls.keys():                 # 06 §2.7: no group in reach → a Kulissenwand?
		var w: SceneryWall = _walls[sid] as SceneryWall
		if w != null and is_instance_valid(w) and not w.opened and Rules.in_arc(pos, fwd, w.reach_point(pos),
				_player.strike_reach() + WALL_REACH_BONUS, Rules.STRIKE_ARC_DEG):
			knock_wall(str(sid))


## Hit confirm: everything freezes for hitstop_sec while the struck group flashes white, then the combat starts.
func _strike_hit(hit: EnemyActor, adv: int, opener: String = "") -> void:
	if hitstop_sec <= 0.0 or not is_inside_tree():
		_trigger_encounter(hit.group_id(), hit.encounter_id(), adv, opener)
		return
	_encounter_pending = true
	_freeze(true)
	# The run clock stops with the hit (not only when the combat starts): an expiring floor timer inside the hitstop
	# would otherwise queue the game over first and start the combat under the Sendeschluss screen.
	Game.timer_running = false
	_set_focus(null)
	FB.flash_rig(hit.rig, hitstop_sec + 0.05)
	Sfx.play(&"hit")
	# process_always = false: the hitstop pauses with the tree (PauseMenu, §9.4) instead of starting the combat under it
	get_tree().create_timer(hitstop_sec, false).timeout.connect(
		_after_hitstop.bind(hit.group_id(), hit.encounter_id(), adv, opener))


func _after_hitstop(group_id: String, encounter_id: String, advantage: int, opener: String = "") -> void:
	if is_inside_tree() and not _suspended and Router.busy:
		# A Router transition is still running (e.g. "Zum Titel" from a pause opened during the hitstop): decide when
		# it is over. A goto frees this screen meanwhile (the timer callback dies with it) — no combat starts under the
		# next screen.
		get_tree().create_timer(HITSTOP_RETRY_SEC, false).timeout.connect(
			_after_hitstop.bind(group_id, encounter_id, advantage, opener))
		return
	_encounter_pending = false
	if not _can_start_encounter():
		# Covered (on_resume restores freeze + timer) or detached: no combat from here.
		_freeze(_suspended or is_modal())
		return
	_trigger_encounter(group_id, encounter_id, advantage, opener)


## Combats start only from the settled, active screen: in the tree, not covered by a pushed screen, the Router's
## current screen and no transition running (a running/queued goto — game over, title, floor summary — would start the
## combat under the NEXT screen; a fade-in finishes first, contacts simply retry the next frame).
func _can_start_encounter() -> bool:
	return is_inside_tree() and not _suspended and not Router.busy and Router.current == self


## Contact ≤ 1.1 m (EnemyActor) or a boss trigger radius — 07 §2.2: contact starts nothing but the combat of the
## sleeping tutorial group and of a boss (_rt_contact).
func on_enemy_contact(actor: EnemyActor) -> void:
	if not _built or _suspended or is_modal() or _encounter_pending or _player.is_hidden():
		return
	_rt_contact(actor)


## 06 integration (A × C, round 4): "bark" when the group's PREEMPTIVE comes from Graf Mopsula's bark (DAZED: caught
## from every side) — no sneaking; sneak-themed bets and the "preemptives" stat do not count it (BattleSetup.opener).
static func _opener(actor: EnemyActor, adv: int) -> String:
	return "bark" if adv == Rules.PREEMPTIVE and actor != null and actor.state == Rules.DAZED else ""


## Events.encounter_triggered → the real-time combat in this room (07 §2, R2: _rt_trigger).
func _trigger_encounter(group_id: String, encounter_id: String, advantage: int, opener: String = "") -> void:
	if _encounter_pending or not _can_start_encounter() or encounter_id == "":
		return
	if not Game.has_state():                # a scene that outlives its run (a test frees the state first): no combat
		_rt_open = {}
		_cancel_encounter()
		return
	_rt_trigger(group_id, encounter_id, advantage, opener)


## Encounter without a combat (tests: auto_start_combat off; no setup): back to exploring with the after-combat grace.
func _cancel_encounter() -> void:
	_encounter_pending = false
	_freeze(false)
	Game.timer_running = not _suspended and not is_modal()
	_player.set_grace(Rules.GRACE_SEC)
	_return_nearby()


## Groups within 6 m of Kai go RETURN (after a battle / flight).
func _return_nearby() -> void:
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null and is_instance_valid(a) and a.global_position.distance_to(_player.global_position) \
				<= Rules.GRACE_RETURN_RADIUS:
			a.force_return()


func _after_safe_room(safe_room_id: String) -> void:
	if _layout.safe_room_info.has(safe_room_id):
		_place_before_safe_door(safe_room_id)
	Game.leave_safe_room()


func _freeze(on: bool) -> void:
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null and is_instance_valid(a):
			a.frozen = on
	if _companion != null:
		_companion.frozen = on
	if _player != null:
		_player.input_enabled = not on
		if on:
			_player.release_inputs()
	if _camera != null:
		_camera.input_enabled = not on


# ======================================================================================================================
# Interactions (called by the interactables)
# ======================================================================================================================

func on_chest_opened(chest: ChestInteractable, rewards: Array[LootReward]) -> void:
	var parts: PackedStringArray = []
	var data: Array = []
	for r: LootReward in rewards:
		if r == null:
			continue
		data.append(r.to_dict())
		if r.kind == "credits":
			parts.append(tr("%d Cr") % r.amount)
		elif r.kind == "item":
			parts.append("%s ×%d" % [Interactable._item_name(r.id), r.amount])
	_log_event(ExploreEvent.Type.CHEST_OPENED, {"chest_id": chest.chest.id, "rewards": data})
	var text: String = tr("Truhe: %s") % ", ".join(parts) if not parts.is_empty() else tr("Truhe geöffnet")
	Events.toast_requested.emit(text, &"chest")


# --- 06 package A: E1 secrets -----------------------------------------------------------------------------------------

## The field strike / bark hit the Kulissenwand `secret_id`: Game.open_secret (recorded) → it falls. false when the
## core refuses (already open, unknown).
func knock_wall(secret_id: String) -> bool:
	var w: SceneryWall = _walls.get(secret_id) as SceneryWall
	if w == null or not is_instance_valid(w) or w.opened:
		return false
	if not Game.open_secret(secret_id):
		return false
	w.set_fall_from(_player.global_position)
	open_secret_visual(secret_id)
	return true


## "Regie-Notiz lesen": Game.open_secret (+15 followers, M.O.D. secret_note:<n>) → the post-it flies off.
func read_note(note: NoteInteractable) -> void:
	if note == null or note.collected or note.hidden_behind:
		return
	if not Game.open_secret(note.secret_id):
		Sfx.play_ui(&"ui_error")
		return
	open_secret_visual(note.secret_id)


## Visuals of an opened secret (state already changed by Game.open_secret): a wall falls (gate_opened, notes behind it
## appear, chat), a note is collected (toast "Regie-Notiz n/total · +15 Follower").
func open_secret_visual(secret_id: String) -> void:
	var w: SceneryWall = _walls.get(secret_id) as SceneryWall
	if w != null and is_instance_valid(w):
		_walls.erase(secret_id)
		w.open_visual(true)
		_camera.kick_strike()
		Events.gate_opened.emit(w.gate["cell"], int(w.gate["dir"]))
		_log_event(ExploreEvent.Type.GATE_OPENED, {"key": w.key, "secret": secret_id})
		for nid: Variant in _notes.keys():
			var n: NoteInteractable = _notes[nid] as NoteInteractable
			if n != null and is_instance_valid(n) and str(n.secret.get("behind", "")) == secret_id:
				n.reveal()
		Show.chat("chat_secret")
		Events.toast_requested.emit(tr("Kulissenwand! Der Weg ist frei."), &"star")
		return
	var note: NoteInteractable = _notes.get(secret_id) as NoteInteractable
	if note != null and is_instance_valid(note):
		note.collect_visual(true)
		var cnt: Vector2i = Game.secret_notes()
		Events.toast_requested.emit(tr("Regie-Notiz %d/%d · +%d Follower") % [cnt.x, cnt.y, Secrets.NOTE_FOLLOWERS],
			&"heart")


## Standing Kulissenwände of the floor (secret ids).
func standing_walls() -> PackedStringArray:
	var out: PackedStringArray = []
	for sid: Variant in _walls.keys():
		var w: SceneryWall = _walls[sid] as SceneryWall
		if w != null and is_instance_valid(w) and not w.opened:
			out.append(str(sid))
	return out


func get_wall(secret_id: String) -> SceneryWall:
	return _walls.get(secret_id) as SceneryWall


## First room next to a standing Kulissenwand: one chat hint per wall ("… ist die aus pappe??"), presentation only.
func _hint_wall(cell: Vector2i) -> void:
	if Game.replaying:
		return
	for sid: Variant in _walls.keys():
		var w: SceneryWall = _walls[sid] as SceneryWall
		if _wall_hints.has(sid) or w == null or not is_instance_valid(w) or w.opened:
			continue
		if w.occupied_cells(_layout).has(cell):
			_wall_hints[sid] = true
			Show.chat("chat_secret_hint")
			return


## Gate visuals + Events.gate_opened (state was changed by Game.open_gate / FloorEvent.apply).
func open_gate_visual(key: String) -> void:
	var g: Dictionary = _layout.gate_by_key(key)
	var gate: GateInteractable = _gates.get(key) as GateInteractable
	if gate != null and is_instance_valid(gate) and not gate.opened:
		gate.open_visual(true)
	if not g.is_empty():
		Events.gate_opened.emit(g["cell"], int(g["dir"]))
	_log_event(ExploreEvent.Type.GATE_OPENED, {"key": key})


func open_event_dialog(ev_it: EventInteractable) -> void:
	if is_modal() or _encounter_pending or ev_it == null:
		return
	_open_dialog(ev_it.title(), ev_it.description(), ev_it.options(), _on_event_choice.bind(ev_it),
		ev_it.default_choice())


func _on_event_choice(choice: String, ev_it: EventInteractable) -> void:
	if choice == "" or not is_instance_valid(ev_it):
		return
	var outcome: Dictionary = Game.apply_floor_event(ev_it.ev.id, choice)
	_log_event(ExploreEvent.Type.EVENT_CHOICE, {"event_id": ev_it.ev.id, "choice": choice,
		"completed": bool(outcome.get("completed", false))})
	var wait: float = ev_it.play_outcome(choice, outcome)
	if wait > 0.0 and reveal_waits and is_inside_tree():
		# Reveal: Kai and the groups stay frozen (timer paused) while the prop plays, then a short beat, then the
		# result toast / gate / encounter.
		_revealing = true
		_set_modal(true)
		# process_always = false: a pause during the reveal also pauses this timer (no toast / gate / encounter under
		# the open PauseMenu, §9.4)
		get_tree().create_timer(wait + REVEAL_BEAT_SEC, false).timeout.connect(
			_finish_event_choice.bind(choice, outcome, ev_it))
		return
	_finish_event_choice(choice, outcome, ev_it)


func is_revealing() -> bool:
	return _revealing


func _finish_event_choice(choice: String, outcome: Dictionary, ev_it: EventInteractable) -> void:
	if _revealing:
		_revealing = false
		if not _suspended:
			_set_modal(false)
	if is_instance_valid(ev_it):
		var text: String = ev_it.outcome_text(choice, outcome)
		if text != "":
			Events.toast_requested.emit(text, &"event")
	var gate_key: String = str(outcome.get("open_gate", ""))
	if gate_key != "":
		open_gate_visual(gate_key)
	var enc_id: String = str(outcome.get("encounter_id", ""))
	if enc_id != "":
		_trigger_encounter("", enc_id, Rules.NORMAL)


func open_stairs_dialog() -> void:
	if is_modal() or _encounter_pending:
		return
	var opts: Array[Dictionary] = [{"id": "descend", "label": tr("Abstieg"), "enabled": true},
		{"id": "stay", "label": tr("Noch nicht"), "enabled": true}]
	_open_dialog(tr("Treppe nach unten"), tr("Etage verlassen? Offene Truhen und der Etagenboss bleiben zurück."),
		opts, _on_stairs_choice, "stay")


func _on_stairs_choice(choice: String) -> void:
	if choice != "descend":
		return
	_suspended = true
	_freeze(true)
	Sfx.play(&"stairs")
	_log_event(ExploreEvent.Type.FLOOR_COMPLETED, {"floor": _def.index})
	Game.complete_floor()


func enter_safe_room(safe_room_id: String) -> void:
	if is_modal() or _encounter_pending or _suspended or _rt_busy():
		return
	_player.release_inputs()
	Sfx.play(&"door")
	Router.enter_safe_room(safe_room_id)


## Modal choice dialog (timer paused, enemies / Kai frozen while it is open); `default_id` = the safe option.
func _open_dialog(title: String, text: String, options: Array[Dictionary], callback: Callable,
		default_id: String = "") -> void:
	var dlg: ChoiceDialog = ChoiceDialog.new()
	_dialog = dlg
	add_child(dlg)
	dlg.open(title, text, options, default_id)
	dlg.chosen.connect(_on_dialog_chosen.bind(callback))
	_set_modal(true)


func _on_dialog_chosen(choice: String, callback: Callable) -> void:
	_dialog = null
	_set_modal(false)
	callback.call(choice)


func _set_modal(on: bool) -> void:
	_freeze(on)
	_set_focus(null)
	if not _suspended:
		Game.timer_running = not on


# ======================================================================================================================
# HUD, log
# ======================================================================================================================

func _on_quest_progress(_progress: float) -> void:
	if is_inside_tree():
		_update_quest_hud()


func _update_quest_hud() -> void:
	if _hud == null:
		return
	if Game.mode == &"event_offline" and Game.quest != null:
		var label: String = str(_def.quest.get("label", ""))
		_hud.set_quest(tr(label) if label != "" else tr("Quest"), Game.quest.progress())
	else:
		_hud.set_quest("", 0.0)


func _log_event(t: ExploreEvent.Type, data: Dictionary) -> void:
	var tick: int = Game.sim.tick() if Game.sim != null else 0
	_log.append(ExploreEvent.make(t, tick, data))
	while _log.size() > LOG_SIZE:
		_log.pop_front()




# ======================================================================================================================
# --- Echtzeitkampf (07, R2) ---
# ======================================================================================================================
# Every run fights in the world (07 §2; the only combat of the campaign since R5b part 2b): the triggers of 07 §2.2
# (pull = field strike / ability / item on a lead, the sleeping tutorial group also by touch; weapon reach of a chasing
# lead; 4 s of chase in the same cell; bosses at 5 m with their intro), the encounter command with its "rt" block
# (07 §10.1), Game.make_rt_setup and the CombatDirector (tick loop, set ring, puppets, telegraphs). The per-frame hooks,
# the pull and the combat start ask Game.has_state(): a scene that outlives its run (a test frees the state first)
# starts nothing.

var _director: CombatDirector = null
var _rt_cell: Vector2i = NO_CELL          # set cell of the running combat (NO_CELL = none)
var _rt_groups: PackedStringArray = []     # participating groups (unit order)
var _rt_waiting: PackedStringArray = []    # groups that wait at the ring (more than MAX_ENEMIES units, 07 §2.3)
var _rt_open: Dictionary = {}              # opening action of the next real-time trigger (07 §2.2, RtSetup.rt_opener)
var _rt_chase: Dictionary = {}             # group id → seconds its lead chases in the player's cell
var _rt_quiet_said: bool = false           # "Ruhe am Set!" at most once per floor (this floor view)
var _rt_spotted: Dictionary = {}           # show-boss encounter id → true (Events.show_boss_spotted once)


func get_director() -> CombatDirector:
	return _director


## Control follows life (07 §2.6): the player body temporarily becomes `member_id` (the living partner) — it takes
## that member's rig, capsule and position, while the follower body takes the fallen member and the player's spot (it
## lies there as a puppet). GameState.hero stays; the director calls it again with Game.hero() at the combat end (the
## figures keep their places, only the roles swap back). The camera frames the new figure (LEADER_FRAMING) and its
## pivot glides there (follow lerp, no cut).
func control_temporarily(member_id: String) -> void:
	if _player == null or _companion == null:
		return
	var clean: String = HeroRules.sanitize(member_id)
	if _player.hero_id == clean:
		return
	var old_hero: String = _player.hero_id
	var p_pos: Vector3 = _player.global_position
	var p_yaw: float = _player.rotation.y
	var c_pos: Vector3 = _companion.global_position
	var c_yaw: float = _companion.rotation.y
	_player.name = "Hero"                   # free the node names before the follower takes "Kai" / "Mopsula"
	_companion.set_member(old_hero)
	_player.set_hero(clean)
	_player.name = _node_name(clean)
	_player.teleport(Vector3(c_pos.x, p_pos.y, c_pos.z), c_yaw)
	_companion.global_position = p_pos
	_companion.rotation.y = p_yaw
	if _camera != null:
		_camera.set_leader(clean)
	_last_prompt = "<refresh>"


## Puppet mode of a group's lead (CombatDirector).
func rt_puppet_actor(actor: Node3D, on: bool) -> void:
	var a: EnemyActor = actor as EnemyActor
	if a != null:
		a.set_puppet(on)


## Puppet mode of the AI partner's body (CombatDirector).
func rt_puppet_companion(on: bool) -> void:
	if _companion != null:
		_companion.set_puppet(on)


## The controlled body in a combat (CombatDirector): input on / off and the run-speed factor (move_pm × combat speed;
## 0 holds it: no_move, drinking, KO, hint card).
func rt_player_drive(input_on: bool, speed_scale: float) -> void:
	if _player == null:
		return
	_player.rt_combat = true
	_player.input_enabled = input_on and not _suspended
	_player.speed_scale = maxf(0.0, speed_scale)
	if not input_on:
		_player.release_inputs()


## The set geometry of `cell` (07 §3.5.4): RtGeo.make_geo with the doors that are passable now (closed gates and
## standing Kulissenwände are walls); while RtGeo is the R1a stub (empty result) the same values from RtBalance.
func rt_geo(cell: Vector2i, closed: bool) -> Dictionary:
	var rc: RoomCell = _layout.cell_at(cell)
	var kind: int = int(rc.kind) if rc != null else int(RoomCell.Kind.NORMAL)
	var doors: int = rt_room_doors(cell)
	var bal: RtBalance = RtBalance.from_data(DB.data)
	var geo: Dictionary = RtGeo.make_geo(kind, doors, closed, bal)
	if not geo.is_empty():
		return geo
	var r: int = RtGeo.set_radius(kind, bal)
	if r <= 0:
		var boss: bool = kind == RoomCell.Kind.QUARTER_BOSS or kind == RoomCell.Kind.FLOOR_BOSS
		r = bal.sub("SET_R_CM", "boss" if boss else "regular")
	return {"r": r, "doors": doors, "closed": closed, "blockers": []}


## Door bits of `cell` that are passable right now (an unopened gate or Kulissenwand blocks its door).
func rt_room_doors(cell: Vector2i) -> int:
	var rc: RoomCell = _layout.cell_at(cell)
	if rc == null:
		return 0
	var out: int = 0
	var fr: FloorRun = Game.state.floor_run if Game.state != null else null
	for bit: int in RoomCell.DIR_BITS:
		if not rc.has_door(bit):
			continue
		var g: Dictionary = _layout.gate_at(cell, bit)
		if not g.is_empty() and (fr == null or not fr.opened_gates.has(str(g["key"]))):
			continue
		out |= bit
	return out


## Pull with an ability or a consumable (07 §2.2; a person's keys 1–5 / pad / touch button come through pull_slot):
## `kind` = "skill" | "item", `id` = skill / item id. Only a non-boss lead in the player's own cell, never in a safe or
## stairs room (E34); the advantage follows the pull table (pull_advantage). false = no pull.
func pull(group_id: String, kind: String, id: String) -> bool:
	if not Game.has_state() or not _built or _rt_busy() or _encounter_pending or is_modal() or _suspended:
		return false
	if kind != "skill" and kind != "item":
		return false
	var a: EnemyActor = _actor_at(group_id)
	if a == null or a.is_boss() or _layout.world_to_cell(a.global_position) != get_player_cell() \
			or not pull_room_allowed(get_player_cell()):
		return false
	var adv: int = pull_advantage(group_id)
	var ctl: String = _rt_unit_of(Game.hero())
	_rt_open = {"kind": kind, "u": ctl, kind: id, "target": "e0"}
	_trigger_encounter(group_id, a.encounter_id(), adv, _opener(a, adv))
	return _rt_busy() or _encounter_pending


## The advantage a pull on `group_id` gets now (07 §2.2 table): PREEMPTIVE for an IDLE / PATROL / DAZED lead or from
## behind it, else NORMAL; the sleeping tutorial group always PREEMPTIVE. NORMAL for unknown groups and bosses.
func pull_advantage(group_id: String) -> int:
	var a: EnemyActor = _actor_at(group_id)
	if a == null or _player == null:
		return Rules.NORMAL
	if a.is_asleep():
		return Rules.PREEMPTIVE                # 07 §2.2: the sleeping tutorial group is always caught first
	return Rules.strike_advantage(a.state, a.global_position, a.flat_forward(), _player.global_position, a.is_boss(),
		Balance.BACK_DOT)


## A pull may start in room `cell`: not in a safe room (a safe place) and not in the stairs room (no set there, 07 §2.4;
## E34).
func pull_room_allowed(cell: Vector2i) -> bool:
	var rc: RoomCell = _layout.cell_at(cell) if _layout != null else null
	return rc != null and rc.kind != RoomCell.Kind.SAFE and rc.kind != RoomCell.Kind.STAIRS


## Leads a pull can target right now (07 §7.4 outside a combat: leads in the player's room with line of sight up to
## 25 m; none in a safe or stairs room), nearest first — the order of pull_target_order is the camera's (Tab).
func pull_candidates() -> PackedStringArray:
	var out: Array[Dictionary] = []
	if not Game.has_state() or _player == null or _rt_busy():
		return PackedStringArray()
	var cell: Vector2i = get_player_cell()
	if not pull_room_allowed(cell):
		return PackedStringArray()
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or a.is_boss() or _layout.world_to_cell(a.global_position) != cell:
			continue
		var d: float = Rules.flat_dist(a.global_position, _player.global_position)
		if d <= PULL_SIGHT_M and _bark_reaches(_player.global_position, a.global_position):
			out.append({"id": str(gid), "d": d})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return float(p["d"]) < float(q["d"]) or (float(p["d"]) == float(q["d"]) and str(p["id"]) < str(q["id"])))
	var ids: PackedStringArray = []
	for e: Dictionary in out:
		ids.append(str(e["id"]))
	return ids


const PULL_SIGHT_M: float = 25.0
const RING_WAIT_GAP: float = 0.6           # a waiting lead stands this far outside the ring


## A real-time combat is being started or runs (the director is not idle).
func _rt_busy() -> bool:
	return _director != null and _director.is_busy() or _rt_cell != NO_CELL


func _build_director() -> void:
	_director = CombatDirector.new()
	_director.scene = self
	add_child(_director)


## Unit id of a party member (07 §5.1: p<battle_slot>).
static func _rt_unit_of(member_id: String) -> String:
	var slot: int = DB.party_member(member_id).battle_slot if DB.has_id("party", member_id) else 0
	return "p%d" % slot


## 07 §2.2: contact starts a combat only for the sleeping tutorial group (always PREEMPTIVE) and for bosses (the 5 m
## trigger, NORMAL, with the intro).
func _rt_contact(actor: EnemyActor) -> void:
	if actor.is_boss():
		_trigger_encounter(actor.group_id(), actor.encounter_id(), Rules.NORMAL)
	elif actor.is_asleep():
		_trigger_encounter(actor.group_id(), actor.encounter_id(), Rules.PREEMPTIVE)


## 07 §2.2 per frame outside a combat: the lead of a chasing group within its weapon reach (reach_cm + both radii) →
## AMBUSH when the figure turns its back to it, else NORMAL; a lead chasing for CHASE_COMBAT_SEC_X10 / 10 s in the
## player's cell → NORMAL ("Die Kamera hat euch!"; a room change resets the count). Seen alone starts nothing.
func _rt_triggers(delta: float) -> void:
	if not Game.has_state() or _encounter_pending or is_modal() or _suspended or _player.is_hidden():
		return
	var pcell: Vector2i = get_player_cell()
	var prc: RoomCell = _layout.cell_at(pcell)
	if prc == null or prc.kind == RoomCell.Kind.STAIRS:
		_rt_chase.clear()
		return
	var bal: RtBalance = RtBalance.from_data(DB.data)
	var chase_sec: float = float(bal.i("CHASE_COMBAT_SEC_X10")) / 10.0
	var pr: int = _rt_party_radius_cm(Game.hero())
	var ppos: Vector3 = _player.global_position
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or a.is_boss() or a.puppet or a.frozen:
			continue
		if a.state != EnemyActor.CHASE:
			_rt_chase.erase(gid)
			continue
		var reach: Dictionary = a.rt_reach()
		var lim_m: float = float(int(reach["reach_cm"]) + int(reach["radius_cm"]) + pr) / 100.0
		if Rules.flat_dist(a.global_position, ppos) <= lim_m:
			var behind: bool = Rules.is_behind(ppos, _player.flat_forward(), a.global_position, Balance.BACK_DOT)
			_rt_chase.clear()
			_trigger_encounter(str(gid), a.encounter_id(), Rules.AMBUSH if behind and a.can_ambush() else Rules.NORMAL)
			return
		var t: float = float(_rt_chase.get(gid, 0.0)) + delta if _layout.world_to_cell(a.global_position) == pcell \
			else 0.0
		_rt_chase[gid] = t
		if t >= chase_sec:
			_rt_chase.clear()
			_trigger_encounter(str(gid), a.encounter_id(), Rules.NORMAL)
			return


## Radius of a party member's body in cm (party.json → rt.radius_cm; 07 §9.6 defaults Kai 40, Graf Mopsula 35).
static func _rt_party_radius_cm(member_id: String) -> int:
	var dflt: int = 35 if member_id == "mopsula" else 40
	if not DB.has_id("party", member_id):
		return dflt
	return int(DB.party_member(member_id).rt.get("radius_cm", dflt))


## Units of an encounter in a real-time combat: encounters[].rt.enemies when set, else its enemies (07 §4.9).
static func _rt_unit_count(enc: EncounterDef) -> int:
	if enc == null:
		return 1
	var ids: Variant = enc.rt.get("enemies", []) if not enc.rt.is_empty() else []
	var n: int = (ids as Array).size() if ids is Array else 0
	return n if n > 0 else maxi(1, enc.enemies.size())


## 07 §2.3 "Mitziehen": the trigger group first, then every other lead standing in the set cell by its distance to the
## room centre (tie: group id) while the sum stays ≤ MAX_ENEMIES; the others wait at the ring.
func _rt_participants(trigger_gid: String, enc: EncounterDef, cell: Vector2i) -> Dictionary:
	var groups: PackedStringArray = []
	var waiting: PackedStringArray = []
	var max_units: int = RtBalance.from_data(DB.data).i("MAX_ENEMIES")
	var units: int = _rt_unit_count(enc)
	if trigger_gid != "" and _actor_at(trigger_gid) != null:
		groups.append(trigger_gid)
	var center: Vector3 = _layout.cell_to_world(cell)
	var cand: Array[Dictionary] = []
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null or str(gid) == trigger_gid or a.is_boss() or _layout.world_to_cell(a.global_position) != cell:
			continue
		cand.append({"id": str(gid), "d": Rules.flat_dist(a.global_position, center)})
	cand.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return float(p["d"]) < float(q["d"]) or (float(p["d"]) == float(q["d"]) and str(p["id"]) < str(q["id"])))
	for c: Dictionary in cand:
		var a2: EnemyActor = _actor_at(c["id"])
		var n: int = _rt_unit_count(_encounter_def(a2.encounter_id()))
		if units + n <= max_units:
			groups.append(str(c["id"]))
			units += n
		else:
			waiting.append(str(c["id"]))
	return {"groups": groups, "waiting": waiting, "units": units}


## Room-local pose [x cm, z cm, yaw u8] of a body (07 §3.2).
func _rt_pose(n: Node3D, origin: Vector3) -> Array:
	return [clampi(roundi((n.global_position.x - origin.x) * 100.0), -RtCommand.POS_MAX_CM, RtCommand.POS_MAX_CM),
		clampi(roundi((n.global_position.z - origin.z) * 100.0), -RtCommand.POS_MAX_CM, RtCommand.POS_MAX_CM),
		posmod(roundi(n.rotation.y * 256.0 / TAU), 256)]


## The recorded encounter command with its "rt" block (07 §10.1).
func rt_encounter_cmd(group_id: String, encounter_id: String, advantage: int, opener: String, cell: Vector2i,
		groups: PackedStringArray, open: Dictionary) -> Dictionary:
	var origin: Vector3 = _layout.cell_to_world(cell)
	var hero: String = Game.hero()
	var partner: String = Game.partner()
	var party: Array = []
	for m: String in [hero, partner]:
		var body: Node3D = _player if m == hero else _companion
		if body != null and DB.has_id("party", m):
			party.append({"u": _rt_unit_of(m), "p": _rt_pose(body, origin)})
	party.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return str(p["u"]) < str(q["u"]))
	var gs: Array = []
	for gid: String in groups:
		var a: EnemyActor = _actor_at(gid)
		if a != null:
			gs.append({"group": gid, "enc": a.encounter_id(), "lead": _rt_pose(a, origin), "state": String(a.state)})
	if group_id == "" and not gs.is_empty():
		# a group-less combat (floor event) that pulls groups of the cell in: the event's own enemies come first, from
		# the anchor of 07 §2.3 (BattleBridge takes it itself only when no group is recorded)
		var enc: EncounterDef = _encounter_def(encounter_id)
		var closed: bool = enc != null and (enc.boss or enc.tutorial or not enc.can_flee)
		var ctl_pose: Array = _rt_pose(_player, origin) if _player != null else [0, 0, 0]
		var anchor: Vector2i = RtGeo.group_anchor(rt_geo(cell, closed), int(ctl_pose[0]), int(ctl_pose[1]))
		gs.push_front({"group": "", "enc": encounter_id,
			"lead": [anchor.x, anchor.y, DetMath.yaw_of(-anchor.x, -anchor.y)], "state": "IDLE"})
	var presets: Dictionary = {}
	if DB.has_id("party", partner):
		presets[_rt_unit_of(partner)] = _rt_preset_of(partner)
	var rt: Dictionary = {"v": RtCommand.RT_BLOCK_VERSION, "cell": [cell.x, cell.y], "ctl": _rt_unit_of(hero),
		"party": party, "groups": gs, "presets": presets,
		"auto": Game.settings.auto_attack_default if Game.settings != null else true,
		"retarget": Game.settings.auto_retarget if Game.settings != null else true,
		"open": open.duplicate(true), "diff": String(Game.state.difficulty) if Game.state != null else "prime"}
	var cmd: Dictionary = {"t": "encounter", "enc": encounter_id, "adv": advantage, "group": group_id, "rt": rt}
	if opener == "bark" and advantage == Rules.PREEMPTIVE:
		cmd["opener"] = "bark"
	return cmd


## {"preset", "tog"} of the AI partner (PartyMember.rt_preset / rt_toggles, else party.json rt.default_preset, else the
## 07 §5.2 defaults: Kai "attack", Graf Mopsula "support"; switches over RtVocab.RT_TOGGLE_DEFAULTS).
func _rt_preset_of(member_id: String) -> Dictionary:
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	var preset: String = m.rt_preset if m != null else ""
	if preset == "" and DB.has_id("party", member_id):
		preset = str(DB.party_member(member_id).rt.get("default_preset", ""))
	if not RtVocab.RT_PRESETS.has(preset):
		preset = "support" if member_id == "mopsula" else "attack"
	var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
	if m != null:
		for k: Variant in m.rt_toggles.keys():
			if RtVocab.RT_TOGGLES.has(str(k)):
				tog[str(k)] = bool(m.rt_toggles[k])
	return {"preset": preset, "tog": tog}


## Starts a real-time combat in the player's cell (07 §2.2–§2.4, §2.8, §2.9): no set in the stairs room; the
## participants (≤ MAX_ENEMIES units, the rest waits at the ring); bosses play their intro first (the RtSim does not
## exist meanwhile); then the encounter command → Game.make_rt_setup → the director runs it. A missing setup (the
## BattleBridge stub before R1b) ends like a cancelled encounter.
func _rt_trigger(group_id: String, encounter_id: String, advantage: int, opener: String) -> void:
	var open: Dictionary = _rt_open
	_rt_open = {}
	if _rt_busy() or _director == null:
		return
	var cell: Vector2i = get_player_cell()
	var rc: RoomCell = _layout.cell_at(cell)
	var enc: EncounterDef = _encounter_def(encounter_id)
	if rc == null or rc.kind == RoomCell.Kind.STAIRS or enc == null:
		return                                # 07 §2.4: the stairs room has no set — no combat starts there
	_encounter_pending = true
	_set_focus(null)
	Game.timer_running = false
	Events.encounter_triggered.emit(group_id, encounter_id, advantage)
	_log_event(ExploreEvent.Type.ENCOUNTER, {"group_id": group_id, "encounter_id": encounter_id,
		"advantage": advantage})
	if not auto_start_combat:
		_freeze(true)
		_cancel_encounter()
		return
	var parts: Dictionary = _rt_participants(group_id, enc, cell)
	var closed: bool = enc.boss or enc.tutorial or not enc.can_flee
	var ctx: Dictionary = {"cell": cell, "origin": _layout.cell_to_world(cell), "room_kind": int(rc.kind),
		"room_doors": rt_room_doors(cell), "geo": rt_geo(cell, closed), "closed": closed, "boss": enc.boss,
		"groups": parts["groups"], "waiting": parts["waiting"], "encounter_id": encounter_id}
	_rt_enter(ctx)
	if enc.boss:
		var boss: EnemyActor = _actor_at(group_id)
		if boss != null:
			boss.set_puppet(true)                 # awake for its intro: no "Z z", no AI (the director binds it later)
		var boss_id: String = enc.enemies[0] if not enc.enemies.is_empty() else ""
		var boss_name: String = tr(DB.enemy(boss_id).name) if DB.has_id("enemies", boss_id) else ""
		_rt_hold_world(true)
		await _director.run_boss_intro(ctx, boss, boss_id, boss_name)
		if not is_inside_tree() or not _built:
			return
		_rt_hold_world(false)
	var cmd: Dictionary = rt_encounter_cmd(group_id, encounter_id, advantage, opener, cell, parts["groups"], open)
	_director.arm(ctx)
	var setup: RtSetup = Game.make_rt_setup(cmd)
	if setup == null:
		_director.cancel()
		_rt_leave(null)
		_cancel_encounter()
		return
	_encounter_pending = false


## The world switches to the combat (07 §2.3, §2.4): the set cell; every other group freezes (the clock stands), the
## waiting ones stand at the ring, visible; the participants become puppets when the director binds them; the minimap
## hides (07 §2.8); the player keeps moving (combat movement, no sneak, no interactions).
func _rt_enter(ctx: Dictionary) -> void:
	_rt_cell = ctx["cell"]
	_rt_groups = ctx["groups"]
	_rt_waiting = ctx["waiting"]
	_rt_chase.clear()
	_set_target("", false)                    # in a combat the target is the sim's (07 §7.4)
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null:
			a.frozen = true
	if not _rt_waiting.is_empty():
		_rt_place_waiting(ctx)
		if not _rt_quiet_said:
			_rt_quiet_said = true
			Show.say("rt_set_quiet")              # 07 §2.3: "Ruhe am Set! Ihr seid später dran." once per floor
	if _companion != null:
		_companion.frozen = true
	if _player != null:
		_player.rt_combat = true
		_player.release_inputs()
		_player.input_enabled = true
	if _camera != null:
		_camera.input_enabled = true
	if _hud != null and _hud.minimap != null:
		_hud.minimap.visible = false
	_update_actor_visibility()


## Bosses: the exploration holds still during the intro (input locked, 07 §2.9 step 1).
func _rt_hold_world(on: bool) -> void:
	if _player != null:
		_player.input_enabled = not on
		if on:
			_player.release_inputs()
	if _camera != null:
		_camera.input_enabled = not on


## Waiting leads (07 §2.3) stand at the ring: one standing inside it is put just outside, facing the centre.
func _rt_place_waiting(ctx: Dictionary) -> void:
	var center: Vector3 = ctx["origin"]
	var r: float = float(int((ctx["geo"] as Dictionary).get("r", 480))) / 100.0 + RING_WAIT_GAP
	for gid: String in _rt_waiting:
		var a: EnemyActor = _actor_at(gid)
		if a == null:
			continue
		var d: Vector3 = Rules.flat_dir(center, a.global_position)
		if d == Vector3.ZERO:
			d = Vector3.BACK
		if Rules.flat_dist(center, a.global_position) < r:
			a.global_position = Vector3(center.x + d.x * r, a.global_position.y, center.z + d.z * r)
		a.face(Rules.yaw_of(-d))


## Called by the director after Game.end_combat (07 §2.5, §2.11): defeated groups vanish (VICTORY), fled-from groups
## reset to their leash points (RETURN, ignoring the figure 2 s), waiting groups go RETURN, the roles of the bodies swap
## back (refresh_hero), the figure gets its after-battle grace, the clock runs again.
func rt_combat_ended(result: BattleResult, _ctx: Dictionary) -> void:
	_rt_leave(result)
	if result != null and result.outcome != BattleResult.Outcome.DEFEAT and _player != null:
		_player.set_grace(Rules.GRACE_SEC)
		_return_nearby()
	_encounter_pending = false
	Game.timer_running = not _suspended and not is_modal()


func _rt_leave(result: BattleResult) -> void:
	var outcome: int = int(result.outcome) if result != null else -1
	if outcome == BattleResult.Outcome.VICTORY:
		var gone: PackedStringArray = result.group_ids if not result.group_ids.is_empty() else _rt_groups
		if result.group_id != "" and not gone.has(result.group_id):
			gone.append(result.group_id)
		for gid: String in gone:
			var dead: EnemyActor = _actor_at(gid)
			if dead != null:
				dead.queue_free()
			_enemies.erase(gid)
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null:
			continue
		if a.puppet:
			a.set_puppet(false)
		a.frozen = false
		if outcome == BattleResult.Outcome.FLED and _rt_groups.has(str(gid)) or _rt_waiting.has(str(gid)):
			a.force_return()
	if _companion != null:
		_companion.set_puppet(false)
		_companion.frozen = false
	if _player != null:
		if _player.hero_id != Game.hero():
			control_temporarily(Game.hero())
		_player.rt_combat = false
		_player.speed_scale = 1.0
		_player.input_enabled = not _suspended and not is_modal()
	refresh_hero()
	_rt_cell = NO_CELL
	_rt_groups = PackedStringArray()
	_rt_waiting = PackedStringArray()
	_rt_chase.clear()
	if _hud != null and _hud.minimap != null:
		_hud.minimap.visible = true
	if _camera != null:
		_camera.input_enabled = true
		_camera.exit_combat()
	if is_inside_tree() and not _suspended:
		Events.overlay_mode_requested.emit(&"explore")
		Sfx.music(StringName(_def.music) if _def.music != "" else &"explore")
	_update_actor_visibility()


## In a combat only the set's actors are drawn: the participants (also while they still walk in), the groups waiting
## at the ring, every group standing in the set cell (07 §2.3: actors of other rooms hidden — the draw-call budget).
func _rt_actor_shown(gid: String, a: EnemyActor) -> bool:
	return _rt_groups.has(gid) or _rt_waiting.has(gid) or _layout.world_to_cell(a.global_position) == _rt_cell


## 07 §2.4 and §9.6 (E26): the stairs rule of every group; a show-boss group wears its golden frame.
func _rt_setup_actor(actor: EnemyActor) -> void:
	actor.blocked_cell = _rt_cell_blocked
	var enc: EncounterDef = _encounter_def(actor.encounter_id())
	if enc != null and not enc.show_boss.is_empty():
		actor.set_show_boss(true)


## 07 §2.4: enemies never enter the stairs room (a chase ends at its door).
func _rt_cell_blocked(pos: Vector3) -> bool:
	var rc: RoomCell = _layout.cell_at(_layout.world_to_cell(pos))
	return rc != null and rc.kind == RoomCell.Kind.STAIRS


## Room entry: the extra rigs of the cell's groups are built invisibly (07 §8.10 rule 5); the first entry into the
## show boss's zone sends Events.show_boss_spotted (06 §2.6, 07 §9.6).
func _rt_on_room(cell: Vector2i) -> void:
	if not Game.has_state() or _director == null:
		return
	var rc: RoomCell = _layout.cell_at(cell)
	var extras: PackedStringArray = []
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a == null:
			continue
		var enc: EncounterDef = _encounter_def(a.encounter_id())
		var acell: Vector2i = _layout.world_to_cell(a.global_position)
		if acell == cell and enc != null:
			var ids: PackedStringArray = JsonUtil.to_str_array(enc.rt.get("enemies", [])) if not enc.rt.is_empty() \
				else PackedStringArray()
			if ids.is_empty():
				ids = enc.enemies
			for i in range(1, ids.size()):
				extras.append(ids[i])
		if enc != null and not enc.show_boss.is_empty() and not _rt_spotted.has(enc.id) and rc != null:
			var arc: RoomCell = _layout.cell_at(acell)
			if arc != null and arc.zone == rc.zone:
				_rt_spotted[enc.id] = true
				Events.show_boss_spotted.emit(enc.id)
	if not extras.is_empty():
		_director.prewarm(extras)


# ======================================================================================================================
# --- Pull by a person (07 §2.2, §7.1–§7.4; E34–E37) ---
# ======================================================================================================================
# Outside a combat a person targets the lead of a group in the own room — Tab / Shift+Tab or a left click on it, RT
# on a pad, a tap on touch (a click / tap on free ground or B on a pad clears it) — and opens the combat with an
# ability of the bar: keys 1–5, the pad's A with the lead in slot 1's range (X / Y: slots 2 / 3), the touch action
# button (slot 1). Interaction prompts keep their priority. The target is presentation only (never recorded; dropped
# at a combat start, a suspend, when the lead is no candidate any more); the pull goes through pull() — the same
# encounter command, run log and replay as the full-run bot's. Graf Mopsula's bark picks the nearest dazed lead
# (E35): bark, then 1 / A / the button = Erstschlag.

const PICK_RADIUS: float = 53.5            # ≥ 107 px click / tap area around a lead's body (03_ART §9.4, 07 §7.3)
const BAR_KEYS: Array[StringName] = [&"bar_1", &"bar_2", &"bar_3", &"bar_4", &"bar_5"]

## Session flag (presentation only, E37): the pull hint shows until the first pull of a person in this session.
static var pull_taught: bool = false

var _target: String = ""                   # targeted lead (group id), "" = none
var _target_auto: bool = false             # picked by the bark (E35): dropped once its daze is over
var _rt_trigger_down: bool = false         # RT held (one target step per press)


## The targeted lead's group id ("" = none).
func pull_target() -> String:
	return _target


## Targets the lead of `group_id` ("" clears); false when it is no candidate right now (pull_candidates).
func set_pull_target(group_id: String) -> bool:
	if group_id == "":
		_set_target("", false)
		return true
	if not pull_candidates().has(group_id):
		return false
	_set_target(group_id, false)
	return true


## Tab / Shift+Tab / RT: the next (previous) lead after the current target in pull_target_order (wraps); "" = none.
func cycle_pull_target(forward: bool) -> String:
	var nxt: String = PullRules.next_in(pull_target_order(), _target, forward)
	if nxt != "":
		_set_target(nxt, false)
	return nxt


## The candidates in Tab order (07 §7.4): within ±60° of the camera's forward first, then by distance.
func pull_target_order() -> PackedStringArray:
	var cands: Array[Dictionary] = []
	for gid: String in pull_candidates():
		cands.append({"id": gid, "pos": _actor_at(gid).global_position})
	return PullRules.tab_order(cands, get_player_position(), _cam_forward())


## The candidate lead whose body (foot to head, projected) lies within PICK_RADIUS px of `screen_pos` — the nearest
## one; "" if none.
func lead_at_screen(screen_pos: Vector2) -> String:
	var cam: Camera3D = _camera.camera() if _camera != null else null
	if cam == null or not cam.is_inside_tree():
		return ""
	var best: String = ""
	var best_d: float = PICK_RADIUS
	for gid: String in pull_candidates():
		var a: EnemyActor = _actor_at(gid)
		var foot: Vector3 = a.global_position
		var head: Vector3 = foot + Vector3(0.0, a.top_m, 0.0)
		if cam.is_position_behind(foot) or cam.is_position_behind(head):
			continue
		var f: Vector2 = cam.unproject_position(foot)
		var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, f, cam.unproject_position(head)) \
			.distance_to(screen_pos)
		if d <= best_d:
			best_d = d
			best = gid
	return best


## A left click / a tap at `screen_pos` (07 §7.1, §7.3): the lead there becomes the target, free ground clears it.
## Returns the new target ("" = none).
func pick_pull_target(screen_pos: Vector2) -> String:
	var gid: String = lead_at_screen(screen_pos)
	_set_target(gid, false)
	return gid


## A tap of the touch layer on the world (ExplorationHud, 07 §7.3): pick_pull_target while a person may act.
func on_world_tap(canvas_pos: Vector2) -> void:
	if _pull_input_ok():
		pick_pull_target(canvas_pos)


## The skill on bar slot `slot` of the controlled figure at its level and loadout ("" = none) — against the sleeping
## tutorial group only slots 1 and 5, like the bar of its combat (07 §2.13, E28).
func pull_slot_skill(slot: int) -> String:
	var hero: String = Game.hero()
	var m: PartyMember = Game.state.member(hero) if Game.state != null else null
	if m == null or not DB.has_id("party", hero):
		return ""
	if slot != 1 and slot != 5 and _target_is_tutorial():
		return ""
	return str(PullRules.bar_slots(m, DB.party_member(hero)).get(slot, ""))


## Why a pull with bar slot `slot` is refused right now ("" = it pulls): no_target, room, not_learned, no_opener,
## range, mp (07 §2.2: only abilities usable as an opener; E34).
func pull_check(slot: int) -> String:
	var a: EnemyActor = _actor_at(_target)
	if _target == "" or a == null or _player == null:
		return "no_target"
	var cell: Vector2i = get_player_cell()
	if not pull_room_allowed(cell) or _layout.world_to_cell(a.global_position) != cell:
		return "room"
	var sid: String = pull_slot_skill(slot)
	var sk: SkillDef = DB.skill(sid) if sid != "" and DB.has_id("skills", sid) else null
	if sk == null:
		return "not_learned"
	var m: PartyMember = Game.state.member(Game.hero())
	return PullRules.refusal(sk, m.mp if m != null else 0, roundi(Rules.flat_dist(a.global_position,
		_player.global_position) * 100.0), _hero_reach_cm(), _lead_radius_cm(a))


## Pull with bar slot `slot` (keys 1–5, the pad's A / X / Y, the touch button): refused → the short text under the
## target frame and false; else pull() with the slot's skill as the opener (07 §2.2, RtSetup.rt_opener) → true.
func pull_slot(slot: int) -> bool:
	if not _pull_input_ok():
		return false
	var why: String = pull_check(slot)
	if why != "":
		if _hud != null:
			_hud.pull_refused(slot, why)
		Sfx.play_ui(&"ui_error")
		return false
	if not pull(_target, "skill", pull_slot_skill(slot)):
		return false
	pull_taught = true
	return true


## The target frame model for the HUD ({} = none): {"group", "lead" (RT lead enemy id), "count", "state", "first" (a
## pull now is a first strike), "dist_m", "foot" / "head" (world points of the lead), "bubble" (its "!" / "?!" shows),
## "auto", "hint" (the pull hint shows, E37), "slots": [{"slot", "id", "reason"}] for the bar slots 1–5 of the figure}.
func pull_frame_model() -> Dictionary:
	var a: EnemyActor = _actor_at(_target)
	if a == null or _player == null:
		return {}
	var slots: Array[Dictionary] = []
	for slot in range(1, PullRules.SLOTS + 1):
		var sid: String = pull_slot_skill(slot)
		if sid != "":
			slots.append({"slot": slot, "id": sid, "reason": pull_check(slot)})
	var enc: EncounterDef = _encounter_def(a.encounter_id())
	return {"group": _target, "lead": _rt_lead_of(a), "count": _rt_unit_count(enc),
		"state": PullRules.state_text(a.state, a.is_asleep()), "first": pull_advantage(_target) == Rules.PREEMPTIVE,
		"dist_m": Rules.flat_dist(a.global_position, _player.global_position), "foot": a.global_position,
		"head": a.global_position + Vector3(0.0, a.top_m, 0.0), "bubble": a.state in [&"ALERT", &"CHASE", &"DAZED"],
		"auto": _target_auto, "hint": _pull_hint_on(), "slots": slots}


## A person may act now: a running game, the settled exploration (no dialog, combat, suspend or transition).
func _pull_input_ok() -> bool:
	return _built and Game.has_state() and not _suspended and not is_modal() and not _encounter_pending \
		and not _rt_busy() and not Router.busy and _player != null and _player.input_enabled


## `action` of the pad / the touch button with a lead targeted (07 §7.2, §7.3): the pull with slot 1 (or its
## refusal) → true — the pad only with the lead in slot 1's range (else its field ability), the touch button always.
func _pull_by_action(source: StringName) -> bool:
	if _target == "" or source == &"key" or not _pull_input_ok():
		return false
	if source == &"pad" and pull_check(1) != "" and pull_check(1) != "mp":
		return false
	pull_slot(1)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.is_action(&"target_next") \
			and not event.is_action_pressed(&"target_next"):
		_rt_trigger_down = false               # RT let go (also during a dialog): the next press steps again
	if _pull_input_ok() and _pull_input(event):
		get_viewport().set_input_as_handled()


## One input event of the pull (07 §7.1–§7.3, E36); true when it was used.
func _pull_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		if (event as InputEventKey).echo:
			return false
		if event.is_action_pressed(&"target_prev", false, true):        # Shift+Tab (exact: it also matches Tab)
			cycle_pull_target(false)
			return true
		if event.is_action_pressed(&"target_next", false, true):
			cycle_pull_target(true)
			return true
		for i in BAR_KEYS.size():
			if event.is_action_pressed(BAR_KEYS[i], false, true):
				pull_slot(i + 1)
				return true
		return false
	if event is InputEventJoypadMotion:
		if not event.is_action(&"target_next"):           # LT (target_prev) stays `sneak` in the exploration (07 §7.2)
			return false
		var down: bool = event.is_action_pressed(&"target_next")
		var step: bool = down and not _rt_trigger_down
		_rt_trigger_down = down
		if step:
			cycle_pull_target(true)
		return step
	if event is InputEventJoypadButton and _target != "":
		if event.is_action_pressed(&"bar_2"):             # X / Y: slots 2 / 3, only with a target (07 §7.2)
			pull_slot(2)
			return true
		if event.is_action_pressed(&"bar_3"):
			pull_slot(3)
			return true
		if event.is_action_pressed(&"ui_cancel"):         # B drops the target (E36)
			_set_target("", false)
			return true
		return false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION:
			var had: String = _target
			return pick_pull_target(mb.position) != "" or had != ""
	return false


## Every physics frame of a run outside a combat: the target stays a candidate (else it is dropped; the bark's target
## once its daze is over) and the HUD gets the frame model (target frame, marker, touch button).
func _pull_frame() -> void:
	if not Game.has_state():
		return
	if _target != "" and (_rt_busy() or not _target_ok()):
		_set_target("", false)
	if _hud != null and _target != "":
		_hud.set_pull_target(pull_frame_model() if not is_modal() else {})


func _target_ok() -> bool:
	var a: EnemyActor = _actor_at(_target)
	if a == null or (_target_auto and not a.is_dazed()):
		return false
	return pull_candidates().has(_target)


func _set_target(group_id: String, auto: bool) -> void:
	var changed: bool = group_id != _target
	_target = group_id
	_target_auto = auto and group_id != ""
	if not changed:
		return
	if group_id != "" and not auto and is_inside_tree():
		Sfx.play_ui(&"ui_move")
	if _hud != null and group_id == "":
		_hud.set_pull_target({})


## 07 E35: after a bark that dazed a group the nearest dazed lead becomes the target — a lead the person targeted
## stays.
func _target_dazed() -> void:
	if not Game.has_state() or (_target != "" and not _target_auto):
		return
	var best: String = ""
	var best_d: float = INF
	for gid: String in pull_candidates():
		var a: EnemyActor = _actor_at(gid)
		var d: float = Rules.flat_dist(a.global_position, _player.global_position)
		if a.is_dazed() and d < best_d:
			best_d = d
			best = gid
	if best != "":
		_set_target(best, true)


## The pull hint "1 · Angriff eröffnen" under the target frame (touch: the action button pulses) shows (E37): a
## campaign with combat hints on, the settled exploration, a lead targeted that slot 1 pulls right now, and no pull of
## a person in this session yet.
func _pull_hint_on() -> bool:
	if pull_taught or _target == "" or Game.mode != &"campaign" or not _pull_input_ok():
		return false
	if Game.settings != null and not Game.settings.combat_hints:
		return false
	return pull_check(1) == ""


func _target_is_tutorial() -> bool:
	var a: EnemyActor = _actor_at(_target)
	var enc: EncounterDef = _encounter_def(a.encounter_id()) if a != null else null
	return enc != null and enc.tutorial


## The lead enemy of the group's combat units: encounters[].rt.enemies[0], else the spawn's lead (07 §4.9).
func _rt_lead_of(a: EnemyActor) -> String:
	var enc: EncounterDef = _encounter_def(a.encounter_id())
	var ids: Array = enc.rt.get("enemies", []) as Array if enc != null and not enc.rt.is_empty() else []
	return str(ids[0]) if not ids.is_empty() else a.spawn.lead_enemy_id


## Radius of the lead's combat unit in cm (enemies.json rt.radius_cm, 07 §4.9 default 30).
func _lead_radius_cm(a: EnemyActor) -> int:
	var id: String = _rt_lead_of(a)
	return int(DB.enemy(id).rt.get("radius_cm", 30)) if DB.has_id("enemies", id) else 30


## Reach of the controlled figure in cm (party.json rt.reach_cm: the range of a skill without its own, 07 §4.8).
func _hero_reach_cm() -> int:
	var hero: String = Game.hero()
	return int(DB.party_member(hero).rt.get("reach_cm", 250)) if DB.has_id("party", hero) else 250


## The camera's flat forward (the figure's when there is no camera yet).
func _cam_forward() -> Vector3:
	var cam: Camera3D = _camera.camera() if _camera != null else null
	if cam != null and cam.is_inside_tree():
		var f: Vector3 = -cam.global_transform.basis.z
		return Vector3(f.x, 0.0, f.z)
	return _player.flat_forward() if _player != null else Vector3.FORWARD
