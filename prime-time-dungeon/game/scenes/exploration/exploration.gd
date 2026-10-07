class_name ExplorationScene extends Node3D
## Exploration screen (02_TECH §7.3, §9.2; GDD §2). Builds the floor of Game.state.floor_run from
## DungeonGenerator.generate(Game.floor_def(), floor_run.seed): rooms (EnvKit via FloorBuilder), closed gates, chests
## (opened ones open), enemy groups (without defeated groups / beaten bosses, living strays), floor events, stairs, safe
## doors, Kai (player.tscn), Mopsula (companion_follower.gd), the orbit camera and the ExplorationHud (M6).
## Reacts to room changes (Game.visit_room, Events.room_entered), interactions, field strikes and contacts
## (Events.encounter_triggered → Game.make_battle_setup → Router.start_battle), Events.stray_spawn_requested, and the
## stack protocol of the Router (setup / on_suspend / on_resume). The floor timer runs through Game (timer_running).
## Serializable ExploreEvents of what happened are kept in a short log (recent_events(); Brief §6b.2 "events out").

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
const ChoiceDialog := preload("res://scenes/exploration/choice_dialog.gd")
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
const HITSTOP_SEC: float = 0.07         # field strike hit: 70 ms freeze + flash before the battle transition
const REVEAL_BEAT_SEC: float = 0.25     # pause after an event prop animation before its result is shown
const MARKER_LIFT: float = 0.3          # focus marker above the focused object's visual top

## Tests may switch this off: encounters then only emit Events.encounter_triggered (no Game/Router battle start).
var auto_start_battle: bool = true
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
	_set_focus(null)


## {"battle_result": BattleResult} | {"from_safe_room": "<sr id>"}
func on_resume(payload: Dictionary) -> void:
	_suspended = false
	_encounter_pending = false
	if not _built:
		return
	# A dialog that is still open (e.g. a debug encounter started behind it) keeps the floor frozen and the timer off.
	_freeze(is_modal())
	if payload.has("battle_result"):
		_after_battle(payload["battle_result"] as BattleResult)
	elif payload.has("from_safe_room"):
		_after_safe_room(str(payload["from_safe_room"]))
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
	if not _built or is_modal() or _suspended:
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


## Called by the scene itself and by interactables: performs `action` like the player key would.
func perform_action() -> void:
	_on_player_action()


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
	_builder.build_rooms(_rooms_root)
	_builder.build_door_lintels(_world)
	var fr: FloorRun = Game.state.floor_run
	var k: int = 0
	for g: Dictionary in _layout.gates:
		k += 1
		var key: String = str(g["key"])
		if fr.opened_gates.has(key):
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
	_player.name = "Kai"
	_actors_root.add_child(_player)
	_player.action_requested.connect(_on_player_action)
	_companion = Companion.new()
	_companion.leader = _player
	_actors_root.add_child(_companion)
	_camera = CameraRig.new()
	_camera.target = _player
	for it: Interactable in _interactables:
		var blocker: StaticBody3D = it.get_node_or_null("Blocker") as StaticBody3D
		if blocker != null and not it is GateInteractable:
			_camera.exclude.append(blocker.get_rid())
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
	_update_focus()
	_place_marker()
	_check_strike()
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
	_zone_environment(cell)
	_apply_room_visibility(cell)
	if _camera != null:
		var boss_room: bool = rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS
		_camera.frame_extra_arm = BOSS_EXTRA_ARM if boss_room else 0.0


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
	for it: Interactable in _interactables:
		if not is_instance_valid(it):
			continue
		var shown: bool = false
		for c: Vector2i in it.occupied_cells(_layout):
			shown = shown or _visible_cells.has(c)
		it.visible = shown
	_update_actor_visibility()


func is_cell_shown(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)


func _update_actor_visibility() -> void:
	for gid: Variant in _enemies.keys():
		var a: EnemyActor = _actor_at(gid)
		if a != null:
			a.visible = _visible_cells.has(_layout.world_to_cell(a.global_position))


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
		_marker.rotation = Vector3(PI, _marker_t * 2.0, 0.0)


func _on_player_action() -> void:
	if not _built or _suspended or is_modal() or _encounter_pending:
		return
	_update_focus()
	if _focused != null and is_instance_valid(_focused) and _focused.is_available():
		_focused.interact()
		return
	if _player.start_strike():
		_camera.kick_strike()


## Field strike: the first group inside the 100° / 1.8 m arc during the hitting part of the swing starts the battle.
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
		if not Rules.in_arc(pos, fwd, a.global_position, Rules.STRIKE_RANGE, Rules.STRIKE_ARC_DEG):
			continue
		var d: float = Rules.flat_dist(pos, a.global_position)
		if d < hit_d:
			hit_d = d
			hit = a
	if hit != null:
		var adv: int = Rules.strike_advantage(hit.state, hit.global_position, hit.flat_forward(), pos, hit.is_boss(),
			Balance.BACK_DOT)
		_strike_hit(hit, adv)


## Hit confirm: everything freezes for hitstop_sec while the struck group flashes white, then the battle starts.
func _strike_hit(hit: EnemyActor, adv: int) -> void:
	if hitstop_sec <= 0.0 or not is_inside_tree():
		_trigger_encounter(hit.group_id(), hit.encounter_id(), adv)
		return
	_encounter_pending = true
	_freeze(true)
	_set_focus(null)
	FB.flash_rig(hit.rig, hitstop_sec + 0.05)
	Sfx.play(&"hit")
	get_tree().create_timer(hitstop_sec).timeout.connect(_after_hitstop.bind(hit.group_id(), hit.encounter_id(), adv))


func _after_hitstop(group_id: String, encounter_id: String, advantage: int) -> void:
	_encounter_pending = false
	if not is_inside_tree() or _suspended:
		_freeze(_suspended or is_modal())
		return
	_trigger_encounter(group_id, encounter_id, advantage)


## Contact ≤ 1.1 m (EnemyActor) or a boss trigger radius.
func on_enemy_contact(actor: EnemyActor) -> void:
	if not _built or _suspended or is_modal() or _encounter_pending or _player.is_hidden():
		return
	var adv: int = Rules.contact_advantage(actor.state, actor.global_position, actor.flat_forward(),
		_player.global_position, _player.flat_forward(), actor.is_boss(), actor.can_ambush(), Balance.BACK_DOT)
	_trigger_encounter(actor.group_id(), actor.encounter_id(), adv)


## Events.encounter_triggered → Router.start_battle(Game.make_battle_setup(encounter_id, advantage, group_id)).
func _trigger_encounter(group_id: String, encounter_id: String, advantage: int) -> void:
	if _encounter_pending or not is_inside_tree() or encounter_id == "":
		return
	_encounter_pending = true
	_freeze(true)
	_set_focus(null)
	Events.encounter_triggered.emit(group_id, encounter_id, advantage)
	_log_event(ExploreEvent.Type.ENCOUNTER, {"group_id": group_id, "encounter_id": encounter_id,
		"advantage": advantage})
	if not auto_start_battle:
		_cancel_encounter()
		return
	var setup: BattleSetup = Game.make_battle_setup(encounter_id, advantage, group_id)
	if setup == null:
		push_warning("[Exploration] no BattleSetup for '%s' (BattleBridge not ready?) — battle skipped" % encounter_id)
		_cancel_encounter()
		return
	Router.start_battle(setup)


## Encounter without a battle (tests / missing setup): back to exploring with the after-battle grace.
func _cancel_encounter() -> void:
	_encounter_pending = false
	_freeze(false)
	_player.set_grace(Rules.GRACE_SEC)
	_return_nearby()


func _after_battle(result: BattleResult) -> void:
	if result != null and result.outcome == BattleResult.Outcome.VICTORY and result.group_id != "":
		var a: EnemyActor = _actor_at(result.group_id)
		if a != null and is_instance_valid(a):
			a.queue_free()
		_enemies.erase(result.group_id)
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
		get_tree().create_timer(wait + REVEAL_BEAT_SEC).timeout.connect(
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
	if is_modal() or _encounter_pending or _suspended:
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
