class_name CharacterRig extends Node3D
## Standard animation interface of all characters (02_TECH §8.4, 03_ART §5.8).
## Built by CharacterBuilder: Model (scaled by ModelSpec.scale) → named pivots → MeshInstance3Ds (one toon material).
## Animations are procedural keyframe curves on the pivots, evaluated in _process (deterministic, respect
## Engine.time_scale and tree pause). One-shots emit `impact` once at their contact time and end with
## `anim_finished`, then return to idle (or the locomotion loop set by set_locomotion), except `die`.

signal impact                                  # contact moment of attack/cast/stunt/item
signal anim_finished(anim: StringName)

const ANIMS: Array[StringName] = [&"idle", &"walk", &"run", &"attack", &"cast", &"hit", &"die", &"victory", &"defend",
	&"stunt", &"item"]
const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"victory", &"defend"]

## One-shot durations / impact times at speed 1.0 (02_TECH §8.4).
const DURATIONS: Dictionary = {&"attack": 0.55, &"cast": 0.80, &"stunt": 1.20, &"item": 0.60, &"hit": 0.35,
	&"die": 0.70}
const IMPACT_AT: Dictionary = {&"attack": 0.30, &"cast": 0.55, &"stunt": 0.80, &"item": 0.35}
const LOOP_PERIOD: Dictionary = {&"idle": 1.6, &"walk": 0.8, &"run": 0.5, &"victory": 1.0, &"defend": 1.2}
const WALK_STRIDE: float = 1.6     # m per walk cycle (03_ART §10)
const RUN_STRIDE: float = 2.75     # m per run cycle
const ANCHOR_NAMES: Array[StringName] = [&"head", &"center", &"overhead", &"hand_r", &"hand_l", &"feet"]
const DANGER_RIM_AMOUNT: float = 0.6
const DANGER_RIM_MIX: float = 0.6

# --- keyframe curves [t0, v0, t1, v1, …] (seconds at speed 1, degrees / meters at humanoid size) ---
const K_ATK_ARM_R: PackedFloat32Array = [0.0, 0.0, 0.18, -140.0, 0.30, 40.0, 0.36, 40.0, 0.55, 0.0]
const K_ATK_ARM_L: PackedFloat32Array = [0.0, 0.0, 0.18, 25.0, 0.30, -20.0, 0.36, -20.0, 0.55, 0.0]
const K_ATK_LEAN: PackedFloat32Array = [0.0, 0.0, 0.18, -6.0, 0.30, 14.0, 0.36, 14.0, 0.55, 0.0]
const K_ATK_TWIST: PackedFloat32Array = [0.0, 0.0, 0.18, 18.0, 0.30, -14.0, 0.36, -14.0, 0.55, 0.0]
const K_ATK_PZ: PackedFloat32Array = [0.0, 0.0, 0.18, 0.04, 0.30, -0.16, 0.36, -0.16, 0.55, 0.0]
const K_ATK_LEG_L: PackedFloat32Array = [0.0, 0.0, 0.30, 22.0, 0.36, 22.0, 0.55, 0.0]
const K_ATK_LEG_R: PackedFloat32Array = [0.0, 0.0, 0.30, -12.0, 0.36, -12.0, 0.55, 0.0]
const K_ATK_NOD: PackedFloat32Array = [0.0, 0.0, 0.18, -8.0, 0.30, 8.0, 0.55, 0.0]
const K_LUNGE_PZ: PackedFloat32Array = [0.0, 0.0, 0.18, 0.10, 0.30, -0.30, 0.36, -0.30, 0.55, 0.0]
const K_LUNGE_LEAN: PackedFloat32Array = [0.0, 0.0, 0.18, -14.0, 0.30, 12.0, 0.36, 12.0, 0.55, 0.0]
const K_LUNGE_NOD: PackedFloat32Array = [0.0, 0.0, 0.18, -20.0, 0.30, 22.0, 0.36, 22.0, 0.55, 0.0]
const K_LUNGE_HOP: PackedFloat32Array = [0.0, 0.0, 0.18, 0.02, 0.25, 0.10, 0.32, 0.0, 0.55, 0.0]
const K_BLOB_ATK_SQ: PackedFloat32Array = [0.0, 0.0, 0.18, -0.22, 0.30, 0.28, 0.36, 0.28, 0.55, 0.0]
const K_INSECT_ATK_LEAN: PackedFloat32Array = [0.0, 0.0, 0.18, -25.0, 0.30, 12.0, 0.36, 12.0, 0.55, 0.0]
const K_INSECT_ATK_PY: PackedFloat32Array = [0.0, 0.0, 0.18, 0.08, 0.30, 0.0, 0.55, 0.0]
const K_SNAP: PackedFloat32Array = [0.0, 0.0, 0.12, 1.0, 0.26, 1.0, 0.30, 0.0, 0.55, 0.0]
const K_DIVE: PackedFloat32Array = [0.0, 0.0, 0.22, 1.0, 0.36, 1.0, 0.55, 0.0]

const K_CAST_ARMS: PackedFloat32Array = [0.0, 0.0, 0.25, 160.0, 0.55, 160.0, 0.62, 100.0, 0.80, 0.0]
const K_CAST_OUT: PackedFloat32Array = [0.0, 0.0, 0.25, 22.0, 0.55, 22.0, 0.62, 10.0, 0.80, 0.0]
const K_CAST_LEAN: PackedFloat32Array = [0.0, 0.0, 0.25, -8.0, 0.55, -8.0, 0.62, 10.0, 0.80, 0.0]
const K_CAST_NOD: PackedFloat32Array = [0.0, 0.0, 0.25, -15.0, 0.55, -15.0, 0.62, 5.0, 0.80, 0.0]
const K_CAST_PY: PackedFloat32Array = [0.0, 0.0, 0.25, 0.06, 0.55, 0.06, 0.62, 0.0, 0.80, 0.0]
const K_CAST_REAR: PackedFloat32Array = [0.0, 0.0, 0.25, -28.0, 0.55, -28.0, 0.62, 10.0, 0.80, 0.0]
const K_CAST_SQ: PackedFloat32Array = [0.0, 0.0, 0.25, 0.18, 0.55, 0.18, 0.62, -0.15, 0.80, 0.0]
const K_CAST_SPREAD: PackedFloat32Array = [0.0, 0.0, 0.25, 0.25, 0.55, 0.25, 0.62, -0.1, 0.80, 0.0]

const K_ITEM_ARM: PackedFloat32Array = [0.0, 0.0, 0.20, 90.0, 0.45, 90.0, 0.60, 0.0]
const K_ITEM_NOD: PackedFloat32Array = [0.0, 0.0, 0.20, 10.0, 0.45, 10.0, 0.60, 0.0]
const K_ITEM_UP: PackedFloat32Array = [0.0, 0.0, 0.20, -15.0, 0.45, -15.0, 0.60, 0.0]

const K_STUNT_PY: PackedFloat32Array = [0.0, 0.0, 0.15, -0.12, 0.30, 0.9, 0.45, 1.2, 0.60, 1.0, 0.75, 0.0, 0.80, -0.10,
	0.95, 0.0, 1.20, 0.0]
const K_STUNT_FLIP: PackedFloat32Array = [0.0, 0.0, 0.30, 0.0, 0.65, -360.0, 1.20, -360.0]
const K_STUNT_SQ: PackedFloat32Array = [0.0, 0.0, 0.15, -0.15, 0.25, 0.10, 0.30, 0.0, 0.75, 0.0, 0.80, -0.20, 0.95, 0.0,
	1.20, 0.0]
const K_STUNT_ARMS: PackedFloat32Array = [0.0, 0.0, 0.15, -40.0, 0.30, 160.0, 0.65, 160.0, 0.80, 60.0, 1.20, 0.0]
const K_STUNT_LEGS: PackedFloat32Array = [0.0, 0.0, 0.30, 60.0, 0.65, 60.0, 0.80, 0.0]
const K_STUNT_SPIN: PackedFloat32Array = [0.0, 0.0, 0.15, 0.0, 0.75, 720.0, 1.20, 720.0]

const K_HIT_PZ: PackedFloat32Array = [0.0, 0.0, 0.08, 0.15, 0.28, 0.0, 0.35, 0.0]
const K_HIT_LEAN: PackedFloat32Array = [0.0, 0.0, 0.08, -12.0, 0.35, 0.0]
const K_HIT_NOD: PackedFloat32Array = [0.0, 0.0, 0.08, -15.0, 0.35, 0.0]
const K_HIT_OUT: PackedFloat32Array = [0.0, 0.0, 0.08, 25.0, 0.35, 0.0]
const K_HIT_SQ: PackedFloat32Array = [0.0, 0.0, 0.06, -0.08, 0.20, 0.03, 0.35, 0.0]

const K_DIE_SINK: PackedFloat32Array = [0.0, 0.0, 0.70, -0.10]
const K_DIE_OUT: PackedFloat32Array = [0.0, 0.0, 0.30, 50.0, 0.70, 60.0]
const K_DIE_NOD: PackedFloat32Array = [0.0, 0.0, 0.50, -20.0, 0.70, -20.0]
const K_DIE_SPREAD: PackedFloat32Array = [0.0, 0.0, 0.70, 5.0]

var model: Dictionary = {}
var height: float = 1.0                        # top of head in local Y (for UI/number anchors)

# --- art extras (optional; callers may leave the defaults) ---
## Battle idle stance (03_ART §5.8: hips −0.05 m, torso 8° forward, arms raised).
var battle_stance: bool = false
## &"fall" (party: falls over, KO stars) | &"dissolve" (enemies: sink + dissolve).
var death_style: StringName = &"fall"
## Flash color of `cast` (element color) and color of the `item` cube.
var cast_color: Color = Palette.NOVA_CYAN
var item_color: Color = Palette.HEAL
## cast/item/die spawn their own Vfx (magic ring, sparkle, KO stars) into the parent node.
var spawn_effects: bool = true

# --- set up by CharacterBuilder (_setup) ---
var _base: StringName = &""
var _pose: StringName = &"upright"
var _model_root: Node3D = null
var _model_scale: float = 1.0
var _pivots: Dictionary = {}          # String → Node3D
var _rest: Dictionary = {}            # String → Transform3D
var _meshes: Array[MeshInstance3D] = []
var _mesh_opts: Dictionary = {}       # MeshInstance3D → Materials opts
var _pulses: Array[Dictionary] = []   # {"mesh", "mode", "color", "color2", "phase", "amount"}
var _anchors: Dictionary = {}         # StringName → Node3D
var _particles: Array[CPUParticles3D] = []
var _labels: Array[Label3D] = []           # text on the figure (e.g. Rabattschild percent sign), fades with dissolve
var _size_k: float = 1.0
var _center_y: float = 0.9
var _width: float = 0.6
var _arm_out: float = 6.0
var _birds: Array[Node3D] = []

# --- animation state ---
var _anim: StringName = &"idle"
var _speed: float = 1.0
var _t: float = 0.0
var _impact_done: bool = true
var _resume: StringName = &"idle"
var _cycles: float = 0.0
var _rate: float = 1.0 / 1.6
var _resume_rate: float = 1.0 / 1.6
var _clock: float = 0.0
var _dead: bool = false
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _flash_col: Color = Color.WHITE
var _flash_applied: bool = false
var _dissolve: float = 0.0
var _highlight: float = 0.0
var _attack_count: int = 0
var _boss_phase: int = 1
var _steam_t: float = 0.0
var _shield: MeshInstance3D = null
var _item_box: MeshInstance3D = null
var _contact: MeshInstance3D = null
var _fx_done: Dictionary = {}
var _token: int = 0
var _echo_die: bool = false           # play(&"die") on a KO rig: anim_finished(&"die") follows deferred
var _procedural: bool = true          # false for glTF rigs (AnimationPlayer owns the pose)
var _danger_rim: bool = false
var _danger_amount: float = DANGER_RIM_AMOUNT
var _rim_override: Color = Color.WHITE
var _has_rim_override: bool = false


func _ready() -> void:
	if _procedural:
		_apply_pose(_eval())


func play(anim: StringName, speed: float = 1.0) -> void:
	if not ANIMS.has(anim):
		push_warning("CharacterRig.play: unknown anim '%s' → idle" % anim)
		anim = &"idle"
	# Finish an interrupted one-shot (after the new state is set) so awaiting callers return and impact fires
	# exactly once per one-shot (02_TECH §8.4).
	var pending: Dictionary = _take_pending()
	_token += 1
	if anim == &"die" and _dead:
		# already KO: keep the end pose (no stand-up), answer with a deferred anim_finished(&"die")
		_speed = maxf(speed, 0.01)
		_t = float(DURATIONS[&"die"])
		_echo_die = true
		_flush_die_echo.call_deferred()
		_complete_pending(pending)
		return
	_anim = anim
	_speed = maxf(speed, 0.01)
	_t = 0.0
	_fx_done.clear()
	if anim != &"die":
		if _dead:
			_revive()
	if LOOPING.has(anim):
		_impact_done = true
		_rate = 1.0 / float(LOOP_PERIOD[anim])
		_cycles = 0.0
		if anim == &"walk" or anim == &"run" or anim == &"idle":
			_resume = anim
			_resume_rate = _rate
		else:
			_resume = &"idle"
			_resume_rate = 1.0 / float(LOOP_PERIOD[&"idle"])
	else:
		_impact_done = not IMPACT_AT.has(anim)
		match anim:
			&"hit":
				flash(Color.WHITE, 0.12)
			&"attack":
				_attack_count += 1
			&"die":
				if death_style == &"dissolve":
					flash(Palette.DANGER, 0.1)
	_set_shield(anim == &"defend")
	_complete_pending(pending)


## Coroutine; loops return immediately; outside the tree: end pose at once, impact + anim_finished, push_warning.
## `die` on a rig that is already KO returns at once and keeps the KO pose.
func play_and_wait(anim: StringName, speed: float = 1.0) -> void:
	if LOOPING.has(anim):
		play(anim, speed)
		return
	if not ANIMS.has(anim):
		play(anim, speed)
		return
	if anim == &"die" and _dead:
		return
	if not is_inside_tree():
		push_warning("CharacterRig.play_and_wait('%s') outside the tree: finished instantly" % anim)
		_finish_instantly(anim)
		return
	play(anim, speed)
	var tok: int = _token
	while true:
		var finished: StringName = await anim_finished
		if finished == anim or tok != _token:
			break


func current_anim() -> StringName:
	return _anim


## < 0.2 idle, < 5.5 walk (cadence scales), else run
func set_locomotion(speed_mps: float) -> void:
	if _dead:
		return
	var target: StringName = &"idle"
	var rate: float = 1.0 / float(LOOP_PERIOD[&"idle"])
	if speed_mps >= 5.5:
		target = &"run"
		rate = clampf(speed_mps / RUN_STRIDE, 0.8, 3.5)
	elif speed_mps >= 0.2:
		target = &"walk"
		rate = clampf(speed_mps / WALK_STRIDE, 0.4, 3.0)
	_resume = target
	_resume_rate = rate
	if LOOPING.has(_anim):
		if _anim != target:
			_anim = target
			_speed = 1.0
			_set_shield(false)
		_rate = rate


func flash(color: Color = Color.WHITE, duration: float = 0.12) -> void:
	_flash_col = color
	_flash_total = maxf(duration, 0.001)
	_flash_left = _flash_total
	_apply_flash(1.0, color)


func set_highlight(on: bool) -> void:
	_highlight = 1.0 if on else 0.0
	for mi: MeshInstance3D in _meshes:
		mi.set_instance_shader_parameter(&"highlight", _highlight)


func set_dissolve(amount: float) -> void:
	_dissolve = clampf(amount, 0.0, 1.0)
	for mi: MeshInstance3D in _meshes:
		mi.set_instance_shader_parameter(&"dissolve", _dissolve)
	if _model_root != null:
		_model_root.visible = _dissolve < 0.999
	for p: CPUParticles3D in _particles:
		p.emitting = _dissolve < 0.5 and not _dead
	for lb: Label3D in _labels:
		lb.modulate.a = 1.0 - _dissolve
		lb.outline_modulate.a = 1.0 - _dissolve


## Instant KO pose (no anim), for loading/standalone states. A running one-shot is finished first (impact once,
## anim_finished) so awaiting callers return.
func set_dead(dead: bool) -> void:
	var pending: Dictionary = _take_pending()
	_token += 1
	if dead:
		_anim = &"die"
		_t = float(DURATIONS[&"die"])
		_impact_done = true
		_dead = true
		_set_shield(false)
		_fx_done = {"ko": true}
		if _item_box != null:
			_item_box.visible = false
		if death_style == &"dissolve":
			set_dissolve(1.0)
		_apply_pose(_eval())
	else:
		_revive()
		_anim = &"idle"
		_t = 0.0
		_impact_done = true
		_apply_pose(_eval())
	_complete_pending(pending)


## &"head", &"center", &"overhead", &"hand_r", &"hand_l", &"feet"
func anchor(anchor_name: StringName) -> Node3D:
	var n: Node3D = _anchors.get(anchor_name, null)
	return n if n != null else self


func face_towards(world_pos: Vector3) -> void:
	var here: Vector3 = global_position if is_inside_tree() else position
	var d: Vector3 = world_pos - here
	d.y = 0.0
	if d.length_squared() < 0.000001:
		return
	if is_inside_tree():
		look_at(here + d, Vector3.UP)
	else:
		rotation.y = atan2(-d.x, -d.z)


## Rest pose + idle; a running one-shot is finished first (impact once, anim_finished).
func reset_pose() -> void:
	var pending: Dictionary = _take_pending()
	_token += 1
	_revive()
	_anim = &"idle"
	_t = 0.0
	_cycles = 0.0
	_speed = 1.0
	_impact_done = true
	_flash_left = 0.0
	_apply_flash(0.0, Color.WHITE)
	_set_shield(false)
	if _item_box != null:
		_item_box.visible = false
	for pname: String in _pivots:
		(_pivots[pname] as Node3D).transform = _rest[pname]
	if _model_root != null:
		_model_root.transform = Transform3D(Basis.from_scale(Vector3.ONE * _model_scale), Vector3.ZERO)
	_complete_pending(pending)


## Emits impact; called by procedural tweens and AnimationPlayer method tracks.
## During a one-shot whose impact already fired, further calls are ignored (impact exactly once, §8.4).
func emit_impact() -> void:
	if _impact_done and _oneshot_running():
		return
	_impact_done = true
	impact.emit()


# --- art extras -------------------------------------------------------------------------------------------------------

## Boss phase (1..3): Hausmeister P3 glowing eyes + steam, Rattenkönigin P3 crown glow (03_ART §5.5).
func set_boss_phase(phase: int) -> void:
	_boss_phase = phase


## Re-tints the rim light of all toon meshes (zone palette `rim`, 03_ART §3.1).
func set_rim_color(color: Color) -> void:
	_rim_override = color
	_has_rim_override = true
	_apply_rim()


## Art extra (review M4, pillar 2): warm DANGER rim so enemies separate from dirty floors at the gameplay camera.
## CharacterBuilder switches it on for enemy-only bases; callers may toggle it (e.g. humanoid enemies such as Pendler).
func set_danger_rim(on: bool, amount: float = DANGER_RIM_AMOUNT) -> void:
	_danger_rim = on
	_danger_amount = amount
	_apply_rim()


func has_danger_rim() -> bool:
	return _danger_rim


func _apply_rim() -> void:
	for mi: MeshInstance3D in _meshes:
		var opts: Dictionary = (_mesh_opts.get(mi, {}) as Dictionary).duplicate()
		if _has_rim_override:
			opts["rim_color"] = _rim_override
		if _danger_rim:
			var base_rim: Color = Materials.DEFAULT_RIM
			var given: Variant = opts.get("rim_color", null)
			if typeof(given) == TYPE_COLOR:
				base_rim = given
			opts["rim_color"] = base_rim.lerp(Palette.DANGER, DANGER_RIM_MIX)
			opts["rim"] = maxf(float(opts.get("rim", 0.25)), _danger_amount)
		mi.material_override = Materials.toon_vc(opts)


## Contact shadow disc (03_ART §4.3, quality low without realtime shadows).
func set_contact_shadow(on: bool) -> void:
	if on and _contact == null:
		_contact = MeshInstance3D.new()
		_contact.name = "ContactShadow"
		var r: float = maxf(0.6 * _width * 0.5, 0.15)
		_contact.mesh = MeshUtil.cylinder(r, r, 0.01)
		_contact.material_override = Materials.toon(Palette.INK, {"outline": false, "rim": 0.0, "spec": 0.0})
		_contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_contact.position = Vector3(0, 0.01, 0)
		add_child(_contact)
	if _contact != null:
		_contact.visible = on


## Size factor relative to a 1.75 m humanoid (animation offsets and effect scale use it).
func size_factor() -> float:
	return _size_k


# --- internals: setup ----------------------------------------------------------------------------------------------

## Called by CharacterBuilder after the node tree exists. info: {"base", "pose", "model_root", "scale", "pivots",
## "meshes", "mesh_opts", "pulses", "anchors", "particles", "labels", "height", "width", "arm_out"}
func _setup(info: Dictionary) -> void:
	_base = StringName(str(info.get("base", "")))
	_pose = StringName(str(info.get("pose", "upright")))
	_model_root = info.get("model_root", null)
	_model_scale = float(info.get("scale", 1.0))
	_pivots = info.get("pivots", {})
	_rest.clear()
	for pname: String in _pivots:
		_rest[pname] = (_pivots[pname] as Node3D).transform
	_meshes.assign(info.get("meshes", []))
	_mesh_opts = info.get("mesh_opts", {})
	_pulses.assign(info.get("pulses", []))
	_anchors = info.get("anchors", {})
	_particles.assign(info.get("particles", []))
	_labels.assign(info.get("labels", []))
	height = float(info.get("height", 1.0))
	_width = float(info.get("width", 0.6))
	_arm_out = float(info.get("arm_out", 6.0))
	_size_k = clampf(height / 1.75, 0.25, 2.2)
	_center_y = height * 0.5
	_birds.clear()
	for i in 8:
		var b: Node3D = _pivots.get("Bird%d" % i, null)
		if b != null:
			_birds.append(b)
	# deterministic phase offset (from the build seed) so groups do not move in lockstep
	_clock = float(info.get("phase", 0.0))


func _revive() -> void:
	_dead = false
	if _dissolve > 0.0:
		set_dissolve(0.0)
	if _model_root != null:
		_model_root.visible = true


func _finish_instantly(anim: StringName) -> void:
	var pending: Dictionary = _take_pending()
	_token += 1
	_anim = anim
	_t = float(DURATIONS.get(anim, 0.0))
	_fx_done.clear()
	if anim != &"die" and _dead:
		_revive()
	_apply_pose(_eval())
	if anim == &"die":
		_dead = true
		_impact_done = true
		if death_style == &"dissolve":
			set_dissolve(1.0)
	else:
		_impact_done = true
		_anim = _resume
		_rate = _resume_rate
		_t = 0.0
		_apply_pose(_eval())
	_complete_pending(pending)
	if IMPACT_AT.has(anim):
		impact.emit()
	anim_finished.emit(anim)


## True while a one-shot runs whose impact / anim_finished callers may still await (02_TECH §8.4).
func _oneshot_running() -> bool:
	return not LOOPING.has(_anim) and not (_anim == &"die" and _dead)


## Snapshot of what the running one-shot still owes (call before changing the anim state).
func _take_pending() -> Dictionary:
	var out: Dictionary = {"anim": &"", "impact": false, "echo": _echo_die}
	_echo_die = false
	if _oneshot_running():
		out["anim"] = _anim
		out["impact"] = not _impact_done and IMPACT_AT.has(_anim)
	return out


## Emits what an interrupted one-shot owed: its missing impact (once), then anim_finished.
func _complete_pending(p: Dictionary) -> void:
	if bool(p["impact"]):
		impact.emit()
	if StringName(p["anim"]) != &"":
		anim_finished.emit(StringName(p["anim"]))
	if bool(p["echo"]):
		anim_finished.emit(&"die")


## Deferred answer to play(&"die") on a rig that is already KO.
func _flush_die_echo() -> void:
	if _echo_die:
		_echo_die = false
		anim_finished.emit(&"die")


# --- internals: per frame ---------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if LOOPING.has(_anim):
		_cycles += delta * _rate * _speed
	elif not (_anim == &"die" and _dead):
		_t += delta * _speed
		_oneshot_events()
		if not _impact_done and _t >= _impact_time(_anim):
			_impact_done = true
			impact.emit()
		if _t >= _duration(_anim):
			_finish_oneshot()
	_update_flash(delta)
	_update_extras(delta)
	if _procedural:
		_apply_pose(_eval())


func _duration(anim: StringName) -> float:
	return float(DURATIONS.get(anim, 0.5))


func _impact_time(anim: StringName) -> float:
	return float(IMPACT_AT.get(anim, 0.0))


func _finish_oneshot() -> void:
	var done: StringName = _anim
	if not _impact_done and IMPACT_AT.has(done):
		# impact time after the end (glTF clip / .anim.json) or a method track that never fired: still exactly once
		_impact_done = true
		impact.emit()
	_impact_done = true
	if done == &"die":
		_t = _duration(done)
		_dead = true
		if death_style == &"dissolve":
			set_dissolve(1.0)
		for p: CPUParticles3D in _particles:
			p.emitting = false
		anim_finished.emit(done)
		return
	_anim = _resume
	_rate = _resume_rate
	_speed = 1.0
	_t = 0.0
	_cycles = 0.0
	if _item_box != null:
		_item_box.visible = false
	anim_finished.emit(done)


## Effects tied to one-shot moments (cast ring, item cube + sparkle, KO stars, dissolve).
func _oneshot_events() -> void:
	match _anim:
		&"cast":
			if not _fx_done.has("magic"):
				_fx_done["magic"] = true
				_fx(&"magic", _anchor_pos(&"feet") + Vector3(0, 0.05, 0), cast_color)
		&"item":
			var show_box: bool = _t >= 0.12 and _t < 0.48
			_set_item_box(show_box)
			if _t >= 0.35 and not _fx_done.has("sparkle"):
				_fx_done["sparkle"] = true
				_fx(&"sparkle", _anchor_pos(_item_anchor()), item_color)
		&"die":
			if death_style == &"dissolve":
				var u: float = clampf((_t - 0.1) / 0.6, 0.0, 1.0)
				set_dissolve(u * u * (3.0 - 2.0 * u))
			elif _t >= 0.45 and not _fx_done.has("ko"):
				_fx_done["ko"] = true
				_fx(&"ko", _anchor_pos(&"overhead"))


func _update_flash(delta: float) -> void:
	var amt: float = 0.0
	var col: Color = _flash_col
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		amt = _flash_left / _flash_total
	if _anim == &"cast" and _t > 0.08 and _t < 0.6:
		var pulse: float = 0.35 * (0.5 + 0.5 * sin(TAU * 6.0 * _t))
		if pulse > amt:
			amt = pulse
			col = cast_color
	if amt > 0.0 or _flash_applied:
		_apply_flash(amt, col)
	# pulsing parts (bulb, display, boss eyes/crown); a running flash wins
	for pd: Dictionary in _pulses:
		var mi: MeshInstance3D = pd["mesh"]
		var p_amt: float = 0.0
		var p_col: Color = pd.get("color", Color.WHITE)
		match str(pd.get("mode", "")):
			"pulse":
				p_amt = 0.2 + 0.4 * (0.5 + 0.5 * sin(TAU * 1.5 * _clock))
			"flicker":
				var n: float = fposmod(sin(floor(_clock * 12.0) * 12.9898) * 43758.5453, 1.0)
				p_amt = 0.1 + (0.45 if n > 0.82 else 0.0)
			"alt":
				p_col = pd.get("color", Palette.LIVE_RED) if int(floor(_clock)) % 2 == 0 else pd.get("color2", Palette.EXIT_GREEN)
				p_amt = 0.85
			"phase":
				p_amt = float(pd.get("amount", 1.0)) if _boss_phase >= int(pd.get("phase", 3)) else 0.0
		if amt > p_amt:
			p_amt = amt
			p_col = col
		mi.set_instance_shader_parameter(&"flash_amount", p_amt)
		mi.set_instance_shader_parameter(&"flash_color", p_col)


func _apply_flash(amount: float, color: Color) -> void:
	for mi: MeshInstance3D in _meshes:
		mi.set_instance_shader_parameter(&"flash_amount", amount)
		mi.set_instance_shader_parameter(&"flash_color", color)
	_flash_applied = amount > 0.0


func _update_extras(delta: float) -> void:
	if _shield != null and _shield.visible:
		var s: float = 1.0 + 0.04 * sin(TAU * _clock / 1.2)
		_shield.scale = Vector3(s, s, 1.0)
	if _base == &"brute" and _boss_phase >= 3 and not _dead:
		_steam_t -= delta
		if _steam_t <= 0.0:
			_steam_t = 0.8
			var head: Node3D = anchor(&"head")
			if head != self and head.is_inside_tree():
				var side: Vector3 = head.global_transform.basis.x.normalized() * 0.32 * _size_k
				_fx(&"smoke", head.global_position + side, Color(0, 0, 0, 0), 0.5)
				_fx(&"smoke", head.global_position - side, Color(0, 0, 0, 0), 0.5)


func _fx(kind: StringName, at: Vector3, color: Color = Color(0, 0, 0, 0), scale_mul: float = 1.0) -> void:
	if not spawn_effects or not is_inside_tree():
		return
	var host: Node = get_parent()
	if host == null:
		return
	Vfx.spawn(kind, host, at, color, maxf(_size_k, 0.4) * scale_mul)


func _anchor_pos(aname: StringName) -> Vector3:
	var n: Node3D = anchor(aname)
	return n.global_position if n.is_inside_tree() else n.position


func _item_anchor() -> StringName:
	return &"hand_r" if (_pose == &"quadruped" or _base == &"swarm") else &"hand_l"


func _set_item_box(on: bool) -> void:
	if on and _item_box == null:
		var a: Node3D = anchor(_item_anchor())
		_item_box = MeshInstance3D.new()
		_item_box.name = "ItemCube"
		_item_box.mesh = MeshUtil.box(Vector3(0.12, 0.12, 0.12))
		_item_box.position = Vector3(0, -0.05, -0.08) if a != self else Vector3(0, height * 0.6, -0.3)
		a.add_child(_item_box)
	if _item_box != null:
		if on:
			_item_box.material_override = Materials.toon(item_color, {"bands": 3, "rim": 0.45, "outline_width": 0.02})
			_item_box.rotation = Vector3(0.4, _clock * 3.0, 0.2)
		_item_box.visible = on


func _set_shield(on: bool) -> void:
	if on and _shield == null and _model_root != null:
		_shield = MeshInstance3D.new()
		_shield.name = "HexShield"
		var r: float = 0.30 * height / maxf(_model_scale, 0.01)
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = 0.02
		m.radial_segments = 6
		m.rings = 1
		_shield.mesh = m
		_shield.material_override = Materials.hologram(Palette.NOVA_CYAN, 0.3, 1.2, 1.0)
		_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shield.position = Vector3(0, _center_y / maxf(_model_scale, 0.01), -0.55 * _width / maxf(_model_scale, 0.01) - 0.1)
		_shield.rotation_degrees = Vector3(90, 0, 0)
		_model_root.add_child(_shield)
	if _shield != null:
		_shield.visible = on


# --- pose evaluation -------------------------------------------------------------------------------------------------

static func _kf(t: float, k: PackedFloat32Array) -> float:
	var n: int = k.size()
	if n < 2:
		return 0.0
	if t <= k[0]:
		return k[1]
	var i: int = 2
	while i < n:
		if t <= k[i]:
			var t0: float = k[i - 2]
			var t1: float = k[i]
			var u: float = clampf((t - t0) / maxf(t1 - t0, 0.00001), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(k[i - 1], k[i + 1], u)
		i += 2
	return k[n - 1]


static func _bounce_out(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	if x < 1.0 / 2.75:
		return 7.5625 * x * x
	if x < 2.0 / 2.75:
		x -= 1.5 / 2.75
		return 7.5625 * x * x + 0.75
	if x < 2.5 / 2.75:
		x -= 2.25 / 2.75
		return 7.5625 * x * x + 0.9375
	x -= 2.625 / 2.75
	return 7.5625 * x * x + 0.984375


func _family() -> StringName:
	match _base:
		&"humanoid", &"brute", &"specter":
			return &"biped"
		&"rodent":
			return &"biped" if _pose == &"upright" else &"quad"
		&"pug":
			return &"quad"
	return _base


static func _add_ch(c: Dictionary, key: String, v: float) -> void:
	c[key] = float(c.get(key, 0.0)) + v


func _eval() -> Dictionary:
	var c: Dictionary = {}
	var fam: StringName = _family()
	var t: float = _t
	match _anim:
		&"idle":
			var p: float = TAU * _cycles
			_add_ch(c, "breath", 0.5 + 0.5 * sin(p))
			_add_ch(c, "head_tilt", 3.0 * sin(p + 0.7))
			_add_ch(c, "arm_r", 4.0 * sin(p))
			_add_ch(c, "arm_l", -4.0 * sin(p))
			if fam == &"quad":
				_add_ch(c, "head_nod", 4.0 * sin(p * 2.0))
			if battle_stance:
				_add_ch(c, "py", -0.05)
				_add_ch(c, "lean", 8.0)
				_add_ch(c, "arm_r", 25.0)
				_add_ch(c, "arm_l", 25.0)
				_add_ch(c, "leg_l", 10.0)
				_add_ch(c, "leg_r", -6.0)
		&"walk":
			_ch_walk(c, 25.0, 20.0, 0.03, 6.0)
		&"run":
			_ch_walk(c, 35.0, 30.0, 0.05, 12.0)
		&"attack":
			_ch_attack(c, fam, t)
		&"cast":
			_ch_cast(c, fam, t)
		&"item":
			if fam == &"quad" or fam == &"blob" or fam == &"swarm":
				_add_ch(c, "head_nod", _kf(t, K_ITEM_UP))
				_add_ch(c, "lean", _kf(t, K_ITEM_UP) * 0.5)
			else:
				_add_ch(c, "arm_l", _kf(t, K_ITEM_ARM))
				_add_ch(c, "head_nod", _kf(t, K_ITEM_NOD))
				_add_ch(c, "lean", _kf(t, K_ITEM_NOD) * 0.4)
		&"stunt":
			_ch_stunt(c, fam, t)
		&"hit":
			_add_ch(c, "pz", _kf(t, K_HIT_PZ))
			_add_ch(c, "lean", _kf(t, K_HIT_LEAN))
			_add_ch(c, "head_nod", _kf(t, K_HIT_NOD))
			_add_ch(c, "arm_r_out", _kf(t, K_HIT_OUT))
			_add_ch(c, "arm_l_out", _kf(t, K_HIT_OUT))
			_add_ch(c, "sq", _kf(t, K_HIT_SQ))
			_add_ch(c, "spread", _kf(t, K_HIT_SQ) * -3.0)
		&"die":
			_ch_die(c, fam, t)
		&"victory":
			_ch_victory(c, fam)
		&"defend":
			_add_ch(c, "arm_r", 95.0)
			_add_ch(c, "arm_l", 95.0)
			_add_ch(c, "arm_r_out", -28.0)
			_add_ch(c, "arm_l_out", -28.0)
			_add_ch(c, "lean", 6.0)
			_add_ch(c, "head_nod", 6.0)
			_add_ch(c, "sq", -0.05)
			_add_ch(c, "breath", 0.5 + 0.5 * sin(TAU * _cycles))
			if fam == &"quad":
				_add_ch(c, "py", -0.04)
	_ch_extras(c, fam)
	return c


func _ch_walk(c: Dictionary, leg: float, arm: float, bob: float, lean: float) -> void:
	var p: float = TAU * _cycles
	var s: float = sin(p)
	_add_ch(c, "leg_l", leg * s)
	_add_ch(c, "leg_r", -leg * s)
	_add_ch(c, "arm_r", arm * s)
	_add_ch(c, "arm_l", -arm * s)
	_add_ch(c, "py", bob * absf(sin(p)))
	_add_ch(c, "lean", lean)
	_add_ch(c, "twist", 4.0 * s)
	_add_ch(c, "gait", s)
	_add_ch(c, "head_nod", 2.0 * sin(p * 2.0))
	if _family() == &"quad":
		_add_ch(c, "py", bob * 0.8 * absf(sin(p * 2.0)))
		_add_ch(c, "lean", -lean * 0.8 + 4.0 * sin(p * 2.0))


func _ch_attack(c: Dictionary, fam: StringName, t: float) -> void:
	match fam:
		&"biped":
			_add_ch(c, "arm_r", _kf(t, K_ATK_ARM_R))
			_add_ch(c, "arm_l", _kf(t, K_ATK_ARM_L))
			_add_ch(c, "lean", _kf(t, K_ATK_LEAN))
			_add_ch(c, "twist", _kf(t, K_ATK_TWIST))
			_add_ch(c, "pz", _kf(t, K_ATK_PZ))
			_add_ch(c, "leg_l", _kf(t, K_ATK_LEG_L))
			_add_ch(c, "leg_r", _kf(t, K_ATK_LEG_R))
			_add_ch(c, "head_nod", _kf(t, K_ATK_NOD))
		&"quad":
			_add_ch(c, "pz", _kf(t, K_LUNGE_PZ))
			_add_ch(c, "lean", _kf(t, K_LUNGE_LEAN))
			_add_ch(c, "head_nod", _kf(t, K_LUNGE_NOD))
			_add_ch(c, "py", _kf(t, K_LUNGE_HOP))
		&"blob":
			_add_ch(c, "sq", _kf(t, K_BLOB_ATK_SQ))
			_add_ch(c, "pz", _kf(t, K_LUNGE_PZ) * 0.8)
			_add_ch(c, "lean", _kf(t, K_LUNGE_LEAN) * 0.6)
		&"insect":
			_add_ch(c, "lean", _kf(t, K_INSECT_ATK_LEAN))
			_add_ch(c, "pz", _kf(t, K_LUNGE_PZ) * 0.7)
			_add_ch(c, "py", _kf(t, K_INSECT_ATK_PY))
			_add_ch(c, "claw", _kf(t, K_SNAP))
		&"robot":
			_add_ch(c, "jaw", _kf(t, K_SNAP))
			_add_ch(c, "pz", _kf(t, K_ATK_PZ))
			_add_ch(c, "lean", _kf(t, K_ATK_LEAN) * 0.6)
			_add_ch(c, "py", _kf(t, K_LUNGE_HOP))
		&"swarm":
			_add_ch(c, "dive", _kf(t, K_DIVE))


func _ch_cast(c: Dictionary, fam: StringName, t: float) -> void:
	match fam:
		&"biped":
			_add_ch(c, "arm_r", _kf(t, K_CAST_ARMS))
			_add_ch(c, "arm_l", _kf(t, K_CAST_ARMS))
			_add_ch(c, "arm_r_out", _kf(t, K_CAST_OUT))
			_add_ch(c, "arm_l_out", _kf(t, K_CAST_OUT))
			_add_ch(c, "lean", _kf(t, K_CAST_LEAN))
			_add_ch(c, "head_nod", _kf(t, K_CAST_NOD))
			_add_ch(c, "py", _kf(t, K_CAST_PY))
		&"quad", &"insect":
			_add_ch(c, "lean", _kf(t, K_CAST_REAR))
			_add_ch(c, "head_nod", _kf(t, K_CAST_NOD) * 1.3)
			_add_ch(c, "py", _kf(t, K_CAST_PY))
		&"blob":
			_add_ch(c, "sq", _kf(t, K_CAST_SQ))
		&"robot":
			_add_ch(c, "py", _kf(t, K_CAST_PY) * 1.5)
			_add_ch(c, "jaw", _kf(t, K_CAST_PY) * 8.0)
		&"swarm":
			_add_ch(c, "spread", _kf(t, K_CAST_SPREAD))


func _ch_stunt(c: Dictionary, fam: StringName, t: float) -> void:
	if fam == &"quad" or fam == &"swarm" or fam == &"blob":
		_add_ch(c, "ry", _kf(t, K_STUNT_SPIN))
		_add_ch(c, "py", _kf(t, K_STUNT_PY) * 0.6)
		_add_ch(c, "sq", _kf(t, K_STUNT_SQ))
		_add_ch(c, "head_nod", _kf(t, K_CAST_NOD))
		return
	_add_ch(c, "py", _kf(t, K_STUNT_PY))
	_add_ch(c, "flip", _kf(t, K_STUNT_FLIP))
	_add_ch(c, "sq", _kf(t, K_STUNT_SQ))
	_add_ch(c, "arm_r", _kf(t, K_STUNT_ARMS))
	_add_ch(c, "arm_l", _kf(t, K_STUNT_ARMS))
	_add_ch(c, "leg_l", _kf(t, K_STUNT_LEGS))
	_add_ch(c, "leg_r", _kf(t, K_STUNT_LEGS))
	_add_ch(c, "claw", _kf(t, K_SNAP))


func _ch_die(c: Dictionary, fam: StringName, t: float) -> void:
	if death_style == &"dissolve":
		_add_ch(c, "py", _kf(t, K_DIE_SINK))
		_add_ch(c, "spread", _kf(t, K_DIE_SPREAD))
		_add_ch(c, "head_nod", _kf(t, K_DIE_NOD) * -0.5)
		return
	var u: float = _bounce_out(t / 0.55)
	if fam == &"quad" or fam == &"insect":
		_add_ch(c, "rz", 85.0 * u)
		_add_ch(c, "py", 0.05 * u)
	elif fam == &"swarm":
		_add_ch(c, "spread", _kf(t, K_DIE_SPREAD) * 0.2)
		_add_ch(c, "py", -0.7 * u)
	else:
		_add_ch(c, "rx", 85.0 * u)
	_add_ch(c, "arm_r_out", _kf(t, K_DIE_OUT))
	_add_ch(c, "arm_l_out", _kf(t, K_DIE_OUT))
	_add_ch(c, "head_nod", _kf(t, K_DIE_NOD))
	_add_ch(c, "leg_l", 10.0 * u)
	_add_ch(c, "leg_r", -6.0 * u)


func _ch_victory(c: Dictionary, fam: StringName) -> void:
	var loop_time: float = _cycles * float(LOOP_PERIOD[&"victory"])
	var p: float = PI * _cycles * 2.0
	if fam == &"quad":
		if loop_time < 0.5:
			_add_ch(c, "ry", 360.0 * (loop_time / 0.5))
			_add_ch(c, "py", 0.25 * sin(PI * loop_time / 0.5))
		else:
			_add_ch(c, "lean", -20.0)
			_add_ch(c, "head_nod", -12.0 + 6.0 * sin(TAU * 2.0 * loop_time))
			_add_ch(c, "head_tilt", 10.0 * sin(TAU * loop_time))
		return
	_add_ch(c, "py", 0.2 * absf(sin(p * 0.5)))
	_add_ch(c, "arm_r", 170.0 + 10.0 * sin(p))
	_add_ch(c, "arm_r_out", 10.0)
	_add_ch(c, "arm_l", 30.0 + 10.0 * sin(p + 1.0))
	_add_ch(c, "lean", -5.0)
	_add_ch(c, "head_nod", -10.0)
	_add_ch(c, "twist", 8.0 * sin(p))
	_add_ch(c, "spread", 0.2 * absf(sin(p)))
	_add_ch(c, "jaw", 0.5 + 0.5 * sin(p * 2.0))


## Base-specific idle/locomotion extras (03_ART §5.8 "Gegner-Eigenbewegungen").
func _ch_extras(c: Dictionary, fam: StringName) -> void:
	if _dead:
		return   # KO pose is static (fallen or dissolved)
	var tt: float = _clock
	match _base:
		&"rodent":
			_add_ch(c, "tail", 18.0 * sin(TAU * 1.3 * tt))
			if _anim == &"walk" or _anim == &"run":
				_add_ch(c, "py", 0.02 * absf(sin(TAU * 2.0 * _cycles)))
		&"blob":
			_add_ch(c, "sq", 0.08 * sin(TAU * 1.5 * tt))
		&"insect":
			if _anim == &"idle" or _anim == &"victory" or _anim == &"defend":
				_add_ch(c, "gait", 0.3 * sin(TAU * 1.0 * tt))
			var cyc: float = fmod(tt, 1.2)
			_add_ch(c, "claw", 1.0 if cyc < 0.12 else 0.0)
		&"robot":
			if _anim == &"idle":
				var cyc2: float = fmod(tt, 2.6)
				_add_ch(c, "jaw", 1.0 if cyc2 < 0.12 else (1.0 - (cyc2 - 0.12) / 0.15 if cyc2 < 0.27 else 0.0))
		&"specter":
			_add_ch(c, "py", 0.15 * sin(TAU * 0.6 * tt))
			_add_ch(c, "twist", 12.0 * sin(TAU * 0.3 * tt))
			_add_ch(c, "arm_r_out", 8.0 * sin(TAU * 0.6 * tt))
			_add_ch(c, "arm_l_out", 8.0 * sin(TAU * 0.6 * tt + 1.0))
		&"brute":
			_add_ch(c, "jingle", 8.0 * sin(TAU * 6.0 * tt) * (1.0 if _anim != &"idle" else 0.35))
		&"pug":
			if _anim == &"idle":
				_add_ch(c, "head_turn", 10.0 * sin(TAU * 0.25 * tt))
	if _pivots.has("WingL"):
		_add_ch(c, "wing", 50.0 * sin(TAU * 8.0 * tt))


func _apply_pose(c: Dictionary) -> void:
	if _model_root == null or not _procedural:
		return
	var k: float = _size_k
	var pos := Vector3(float(c.get("px", 0.0)), float(c.get("py", 0.0)), float(c.get("pz", 0.0))) * k
	var rot := Vector3(deg_to_rad(float(c.get("rx", 0.0))), deg_to_rad(float(c.get("ry", 0.0))),
		deg_to_rad(float(c.get("rz", 0.0))))
	var sq: float = float(c.get("sq", 0.0))
	var s_vec := Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5) * _model_scale
	var xf := Transform3D(Basis.from_scale(s_vec), Vector3.ZERO)
	var flip: float = float(c.get("flip", 0.0))
	if flip != 0.0:
		var center := Vector3(0, _center_y, 0)
		xf = Transform3D(Basis.IDENTITY, center) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(flip)), Vector3.ZERO) \
			* Transform3D(Basis.IDENTITY, -center) * xf
	xf = Transform3D(Basis.from_euler(rot), pos) * xf
	_model_root.transform = xf
	if _pivots.is_empty():
		return
	var lean: float = float(c.get("lean", 0.0))
	var twist: float = float(c.get("twist", 0.0))
	var roll: float = float(c.get("roll", 0.0))
	var breath: float = float(c.get("breath", 0.0))
	var body_like: bool = _base != &"swarm" and _base != &"blob"
	_pose_pivot("Torso", Vector3(-lean, twist, roll), Vector3.ZERO, Vector3(1, 1.0 + 0.03 * breath, 1))
	if body_like and not _pivots.has("Torso"):
		_pose_pivot("Body", Vector3(-lean, twist, roll), Vector3.ZERO, Vector3(1, 1.0 + 0.03 * breath, 1))
	_pose_pivot("Head", Vector3(-float(c.get("head_nod", 0.0)), float(c.get("head_turn", 0.0)),
		float(c.get("head_tilt", 0.0))), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("ArmR", Vector3(float(c.get("arm_r", 0.0)), 0, float(c.get("arm_r_out", 0.0)) + _arm_out), Vector3.ZERO,
		Vector3.ONE)
	_pose_pivot("ArmL", Vector3(float(c.get("arm_l", 0.0)), 0, -(float(c.get("arm_l_out", 0.0)) + _arm_out)), Vector3.ZERO,
		Vector3.ONE)
	_pose_pivot("LegL", Vector3(float(c.get("leg_l", 0.0)), 0, 0), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("LegR", Vector3(float(c.get("leg_r", 0.0)), 0, 0), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("Tail", Vector3(0, float(c.get("tail", 0.0)), 0), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("JawLower", Vector3(-35.0 * clampf(float(c.get("jaw", 0.0)), 0.0, 1.0), 0, 0), Vector3.ZERO, Vector3.ONE)
	var gait: float = float(c.get("gait", 0.0))
	_pose_pivot("LegsA", Vector3(0, 10.0 * gait, 0), Vector3(0, 0.03 * maxf(gait, 0.0), 0), Vector3.ONE)
	_pose_pivot("LegsB", Vector3(0, -10.0 * gait, 0), Vector3(0, 0.03 * maxf(-gait, 0.0), 0), Vector3.ONE)
	var claw: float = clampf(float(c.get("claw", 0.0)), 0.0, 1.0)
	_pose_pivot("ClawL", Vector3(-25.0 * claw, 10.0 * claw, 0), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("ClawR", Vector3(-25.0 * claw, -10.0 * claw, 0), Vector3.ZERO, Vector3.ONE)
	var wing: float = float(c.get("wing", 0.0))
	_pose_pivot("WingL", Vector3(0, 0, -wing), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("WingR", Vector3(0, 0, wing), Vector3.ZERO, Vector3.ONE)
	_pose_pivot("Keys", Vector3(0, 0, float(c.get("jingle", 0.0))), Vector3.ZERO, Vector3.ONE)
	if not _birds.is_empty():
		_pose_birds(float(c.get("spread", 0.0)), float(c.get("dive", 0.0)))


func _pose_pivot(pname: String, rot_deg: Vector3, off: Vector3, scl: Vector3) -> void:
	var n: Node3D = _pivots.get(pname, null)
	if n == null:
		return
	var rest: Transform3D = _rest[pname]
	var b: Basis = rest.basis * Basis.from_euler(rot_deg * (PI / 180.0))
	if scl != Vector3.ONE:
		b = b * Basis.from_scale(scl)
	n.transform = Transform3D(b, rest.origin + off)


## Taubenschwarm: 5 birds orbit 1.2 rad/s, bob ±0.12 m, flap 8 Hz; attack = one bird dives; die = birds fly apart.
func _pose_birds(spread: float, dive: float) -> void:
	var orbit: float = _clock * 1.2
	var dive_idx: int = _attack_count % maxi(_birds.size(), 1)
	for i in _birds.size():
		var a: float = deg_to_rad(72.0 * float(i)) + orbit
		var r: float = 0.6 * (1.0 + spread * 1.0)
		var y: float = 0.12 * sin(float(i) * 1.3 + _clock * 2.2) + spread * 0.15
		var p := Vector3(cos(a) * r, y, sin(a) * r)
		var yaw: float = -a
		if i == dive_idx and dive > 0.0:
			p = p.lerp(Vector3(0, -0.25, -1.0), dive)
			yaw = lerp_angle(yaw, 0.0, dive)
		var flap: float = sin(TAU * 8.0 * _clock + float(i))
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, deg_to_rad(15.0 * flap)) \
			* Basis.from_scale(Vector3(1, 0.9 + 0.1 * flap, 1))
		_birds[i].transform = Transform3D(b, p)
