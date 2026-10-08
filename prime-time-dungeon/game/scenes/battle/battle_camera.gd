extends Camera3D
## FF10-like battle camera (03_ART §8.3): shot(name, ctx) switches between programmed shots — establishing dolly, boss
## intro crane, over-the-shoulder command / target shots, melee side shot following the dash, skill close-up and
## release, enemy turn, stunt orbit, sponsor drop, victory orbit, defeat push-in — with cut or blend (Tween-like
## sine ease of position, look-at point and FOV). Camera trauma: offset 0.25 m × trauma² (18 Hz noise), roll 3° ×
## trauma², decay 1.5/s. Shot time runs with `speed` (battle speed ×2 / autoplay halves every shot).
## Occlusion: rigs that are not part of the shot but stand close in front of the lens (the off-turn partner in the
## command shot, enemies between the camera and a melee strike) are culled for this camera for the length of the shot
## (their meshes move to render layer HIDE_LAYER, which the camera's cull mask excludes; GeometryInstance3D
## transparency only works in Forward+, not in the Mobile / Compatibility renderers). Visibility flags, dissolve and
## shadows stay untouched. The melee side shot picks the side with fewer such rigs.
## Private M5 helper (no class_name); presentation only. Positions are in the battle scene's space (stage at origin).

const TRAUMA_DECAY: float = 1.5
const SHAKE_OFFSET: float = 0.25
const SHAKE_ROLL_DEG: float = 3.0
const SHAKE_HZ: float = 18.0
const EST_FROM: Vector3 = Vector3(6.5, 4.2, 9.0)
const EST_TO: Vector3 = Vector3(4.5, 3.4, 8.0)
const EST_LOOK: Vector3 = Vector3(0, 0.9, -0.5)
## Over-the-shoulder command / target shots: narrower than 03_ART's 48 so 0.7 m enemies at ~9 m stay ≥ 48 px tall
## (03_ART §1 pillar 2), the look point close to the enemies.
const COMMAND_FOV: float = 37.0
const TARGET_FOV: float = 35.0
const COMMAND_LOOK_TO_ACTOR: float = 0.1
## The actor's head stays above this fraction of the frame height (bottom HUD band / chat ticker).
const HEAD_MAX_Y: float = 0.82
const FADE_NEAR: float = 6.0           # rigs closer than this to the lens and reaching into the frame fade out
## Render layer (1-based 20) of rigs culled for the current shot; the battle camera never draws it.
const HIDE_LAYER_BIT: int = 1 << 19
const BLOCK_RADIUS: float = 1.2        # rigs this close (ground plane) to the lens → action line block a melee shot
var speed: float = 1.0
var trauma: float = 0.0
var shake_scale: float = 1.0
var stage: Node3D = null              # battle_stage.gd
var shot_name: StringName = &""
## Wide framing for the Rattenkönigin on her wreck (everything is pushed back / up).
var wide: bool = false

var _t: float = 0.0
var _blend: float = 0.0
var _from_pos: Vector3 = EST_TO
var _from_look: Vector3 = EST_LOOK
var _from_fov: float = 50.0
var _pos: Vector3 = EST_TO
var _look: Vector3 = EST_LOOK
var _fov: float = 50.0
var _pos_fn: Callable = Callable()
var _look_fn: Callable = Callable()
var _fov_fn: Callable = Callable()
var _drift: float = 0.0
var _clock: float = 0.0
var _faded: Dictionary = {}            # combatant id → {GeometryInstance3D instance id: original layers}


func _ready() -> void:
	cull_mask = cull_mask & ~HIDE_LAYER_BIT
	near = 0.05
	far = 220.0
	fov = 50.0
	current = true
	_apply(_pos, _look, _fov)


func _process(delta: float) -> void:
	_clock += delta
	_t += delta * maxf(speed, 0.01)
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * delta)
	_evaluate()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Current (unshaken) camera position and look-at point.
func shot_position() -> Vector3:
	return _pos


func shot_look() -> Vector3:
	return _look


## Switches to a programmed shot. ctx keys by shot: "actor"/"target"/"targets" (combatant ids), "area" (bool).
func shot(p_name: StringName, ctx: Dictionary = {}) -> void:
	var actor: String = str(ctx.get("actor", ""))
	var target: String = str(ctx.get("target", ""))
	var blend: float = 0.0
	var fade_ids: PackedStringArray = []
	_drift = 0.0
	_set_faded(PackedStringArray())        # the previous shot's culled rigs are back before this shot is measured
	match p_name:
		&"establishing":
			var a: Vector3 = EST_FROM * (1.3 if wide else 1.0)
			var b: Vector3 = EST_TO * (1.3 if wide else 1.0)
			var lk: Vector3 = EST_LOOK + (Vector3(0, 1.0, -1.0) if wide else Vector3.ZERO)
			_program(func(t: float) -> Vector3: return a.lerp(b, _ease(t / 1.2)),
				func(_t2: float) -> Vector3: return lk, func(_t3: float) -> float: return 50.0)
		&"overview":
			var ov: Vector3 = EST_TO * (1.3 if wide else 1.0)
			var olk: Vector3 = EST_LOOK + (Vector3(0, 1.0, -1.0) if wide else Vector3.ZERO)
			_program(func(_t1: float) -> Vector3: return ov, func(_t2: float) -> Vector3: return olk,
				func(_t3: float) -> float: return 50.0)
			blend = 0.45
		&"boss_intro":
			var head: Vector3 = _anchor(actor, &"head")
			var p0: Vector3 = Vector3(0, 2.0, -12.0) if not wide else Vector3(0, 5.5, -14.0)
			var p2: Vector3 = EST_TO * (1.3 if wide else 1.0)
			var p1: Vector3 = Vector3(7.0, head.y + 2.5, head.z - 1.0)
			var l2: Vector3 = EST_LOOK + (Vector3(0, 1.0, -1.0) if wide else Vector3.ZERO)
			_program(func(t: float) -> Vector3:
					var u: float = _ease(t / 2.5)
					return p0.lerp(p1, u).lerp(p1.lerp(p2, u), u),
				func(t: float) -> Vector3: return head.lerp(l2, _ease(clampf((t - 0.9) / 1.6, 0.0, 1.0))),
				func(t: float) -> float: return lerpf(40.0, 50.0, _ease(t / 2.5)))
		&"command", &"target_select":
			# behind the actor on its outer side: the actor stands bottom center, the enemies fill the frame; the
			# other party member is faded if it still reaches into the frame close to the lens
			var home: Vector3 = _home(actor)
			var h: float = _height(actor)
			var s: float = -1.0 if home.x <= 0.0 else 1.0
			var hk: float = clampf(h, 0.5, 2.2)
			# tall actors: the camera rises with them, so the actor sits in the lower third, under the enemies
			var cpos: Vector3 = home + Vector3(0.9 * s, 1.2 + 0.9 * hk, 2.6 + 0.4 * hk)
			var look: Vector3 = _enemy_center().lerp(home, COMMAND_LOOK_TO_ACTOR) + Vector3(0, 0.1 + 0.28 * hk, 0)
			var cfov: float = COMMAND_FOV
			blend = 0.35
			if p_name == &"target_select" and target != "":
				# turn towards the target, but keep the actor in the frame (half way from the command look point)
				var tp: Vector3 = _home(target) + Vector3(0, minf(_height(target) * 0.6, 1.0), 0)
				if target.begins_with("p"):
					tp = _home(target) + Vector3(0, 0.6, 0)
				look = look.lerp(tp, 0.6)
				cfov = TARGET_FOV
				blend = 0.2
			look = _keep_head_in_frame(cpos, look, cfov, _anchor(actor, &"head"))
			_program(func(_t1: float) -> Vector3: return cpos, func(_t2: float) -> Vector3: return look,
				func(_t3: float) -> float: return cfov)
			_drift = 0.03
			fade_ids = _near_lens(cpos, look, cfov, [actor, target])
		&"action_side":
			# the side with fewer uninvolved rigs between the lens and the strike; ties: the actor's side
			var side: float = -1.0 if _home(actor).x < 0.0 else 1.0
			# the shot follows the dash: test the corridor at its start and at the strike (actor next to the target)
			var th0: Vector3 = _live_or_home(target)
			var ah0: Vector3 = _home(actor)
			var flat: Vector3 = Vector3(ah0.x - th0.x, 0.0, ah0.z - th0.z)
			var strike: Vector3 = th0 + (flat.normalized() if flat.length_squared() > 0.001 else Vector3(0, 0, 1)) * 0.9
			var mids: Array[Vector3] = [(ah0 + th0) * 0.5, (strike + th0) * 0.5]
			var blocked: Array[PackedStringArray] = []
			for sd: float in [side, -side]:
				var ids: PackedStringArray = []
				for m: Vector3 in mids:
					var cam0: Vector3 = Vector3(7.0 * sd + m.x * 0.4, 2.2 + m.y * 0.5, m.z)
					for bid: String in _blockers(cam0, m + Vector3(0, 1.0, 0), [actor, target]):
						if not ids.has(bid):
							ids.append(bid)
				blocked.append(ids)
			if blocked[1].size() < blocked[0].size():
				side = -side
				fade_ids = blocked[1]
			else:
				fade_ids = blocked[0]
			_program(func(_t1: float) -> Vector3:
					var mid: Vector3 = (_live(actor) + _live_or_home(target)) * 0.5
					return Vector3(7.0 * side + mid.x * 0.4, 2.2 + mid.y * 0.5, mid.z),
				func(_t2: float) -> Vector3: return (_live(actor) + _live_or_home(target)) * 0.5 + Vector3(0, 1.0, 0),
				func(_t3: float) -> float: return 45.0)
		&"skill_closeup":
			# in front of the caster at head height, the head centered; distance grows with the figure so small
			# casters (Mopsula 0.6 m) and big ones keep the same framing (03_ART §8.3: FOV 32, push-in 0.2 m)
			var home2: Vector3 = _home(actor)
			var fwd: Vector3 = Vector3(0, 0, -1) if actor.begins_with("p") else Vector3(0, 0, 1)
			var h2: float = clampf(_height(actor), 0.4, 4.0)
			var headp: Vector3 = _anchor(actor, &"head")
			var dist: float = 1.1 + 0.95 * h2
			var base: Vector3 = Vector3(home2.x, headp.y + 0.05 * h2, home2.z) + fwd * dist + Vector3(0.35 * h2, 0, 0)
			var dir: Vector3 = (headp - base).normalized()
			_program(func(t: float) -> Vector3: return base + dir * 0.2 * _ease(t / 0.55),
				func(_t2: float) -> Vector3: return headp + Vector3(0, -0.12 * h2, 0),
				func(_t3: float) -> float: return 32.0)
		&"skill_release":
			var area: bool = bool(ctx.get("area", false))
			if area or target == "":
				var party_side: bool = target.begins_with("p")
				var rp: Vector3 = EST_TO * (1.3 if wide else 1.0)
				var rl: Vector3 = EST_LOOK + (Vector3(0, 1.0, -1.0) if wide else Vector3.ZERO)
				if party_side:
					rp = Vector3(-3.5, 3.2, -2.5)
					rl = _party_center() + Vector3(0, 0.7, 0)
				_program(func(_t1: float) -> Vector3: return rp, func(_t2: float) -> Vector3: return rl,
					func(_t3: float) -> float: return 50.0)
			else:
				# big targets (bosses ~3 m) push the camera back so the whole figure stays in frame
				var th: Vector3 = _home(target)
				var tk: float = clampf(_height(target) / 1.7, 1.0, 1.9)
				var dz: float = 4.5 if not target.begins_with("p") else -4.5
				var rpos: Vector3 = th + Vector3(2.5 * tk, 2.0 * tk, dz * tk)
				var rlook: Vector3 = th + Vector3(0, minf(_height(target) * 0.55, 0.9 * tk), 0)
				_program(func(_t1: float) -> Vector3: return rpos, func(_t2: float) -> Vector3: return rlook,
					func(_t3: float) -> float: return 50.0)
		&"enemy_turn":
			var eh: Vector3 = _home(actor)
			var k: float = clampf(_height(actor) / 1.5, 0.8, 2.0)
			var epos: Vector3 = eh + Vector3(-1.2 * k, 2.0 * k, -2.6 * k)
			var elook: Vector3 = _party_center() + Vector3(0, 0.9, 0)
			_program(func(_t1: float) -> Vector3: return epos, func(_t2: float) -> Vector3: return elook,
				func(_t3: float) -> float: return 50.0)
			blend = 0.3
		&"stunt":
			var sc: Vector3 = _home(actor)
			var sh: float = _height(actor)
			var r: float = 3.0
			var a0: float = deg_to_rad(140.0 if sc.x <= 0.0 else 220.0)
			var a1: float = a0 + deg_to_rad(90.0 if sc.x <= 0.0 else -90.0)
			_program(func(t: float) -> Vector3:
					var a: float = lerpf(a0, a1, _ease(t / 1.2))
					return sc + Vector3(sin(a) * r, 1.5, cos(a) * r),
				func(_t2: float) -> Vector3: return sc + Vector3(0, minf(1.0, sh * 0.6), 0),
				func(_t3: float) -> float: return 40.0)
		&"sponsor_drop":
			_program(func(_t1: float) -> Vector3: return Vector3(3.0, 2.5, 6.0),
				func(t: float) -> Vector3:
					if t < 0.6:
						return Vector3(8, 6, 4).lerp(Vector3(0, 3, 1), _ease(t / 0.6))
					if t < 1.1:
						return Vector3(0, 3, 1).lerp(Vector3(0, 0.6, 0), _ease((t - 0.6) / 0.5))
					return Vector3(0, 0.6, 0),
				func(_t3: float) -> float: return 50.0)
			blend = 0.3
		&"victory":
			var vc: Vector3 = _party_center()
			_program(func(t: float) -> Vector3:
					var a: float = deg_to_rad(lerpf(210.0, 150.0, _ease(t / 3.0)))
					return vc + Vector3(sin(a) * 3.8, 1.3, cos(a) * 3.8),
				func(_t2: float) -> Vector3: return vc + Vector3(0, 0.9, 0),
				func(_t3: float) -> float: return 40.0)
		&"defeat":
			var fig: Vector3 = _home(actor) if actor != "" else _party_center()
			var dstart: Vector3 = fig + Vector3(1.8, 2.4, -2.8)
			var ddir: Vector3 = (fig - dstart).normalized()
			_program(func(t: float) -> Vector3: return dstart + ddir * 0.5 * _ease(t / 1.5),
				func(_t2: float) -> Vector3: return fig + Vector3(0, 0.3, 0), func(_t3: float) -> float: return 45.0)
			blend = 0.5
		&"flee":
			var fc: Vector3 = _party_center()
			_program(func(_t1: float) -> Vector3: return fc + Vector3(2.5, 2.6, -5.5),
				func(_t2: float) -> Vector3: return fc + Vector3(0, 0.8, 1.5), func(_t3: float) -> float: return 50.0)
			blend = 0.3
		&"train":
			var pz: Vector3 = _party_center()
			_program(func(_t1: float) -> Vector3: return pz + Vector3(7.5, 3.6, 7.0),
				func(_t2: float) -> Vector3: return pz + Vector3(-1.0, 1.0, 0), func(_t3: float) -> float: return 55.0)
		&"party_hit":
			# push-in on the party from the enemy side (impact of an attack on the whole party, e.g. the train)
			var pc: Vector3 = _party_center()
			var hs: Vector3 = pc + Vector3(1.6, 2.0, -4.4)
			var hdir: Vector3 = (pc + Vector3(0, 0.7, 0) - hs).normalized()
			_program(func(t: float) -> Vector3: return hs + hdir * 0.6 * _ease(t / 1.2),
				func(_t2: float) -> Vector3: return pc + Vector3(0, 0.7, 0), func(_t3: float) -> float: return 45.0)
		_:
			push_warning("[BattleCamera] unknown shot '%s'" % p_name)
			return
	shot_name = p_name
	_from_pos = _pos
	_from_look = _look
	_from_fov = _fov
	_t = 0.0
	_blend = blend
	_set_faded(fade_ids)
	_evaluate()


## Ids of rigs currently culled for the shot (tests).
func faded_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in _faded.keys():
		out.append(str(k))
	return out


func _exit_tree() -> void:
	_set_faded(PackedStringArray())


# --- occlusion -------------------------------------------------------------------------------------------------------

## Screen position (x, y in pixels of the current viewport) and depth of `p` seen from eye → look with vertical FOV
## `f`; depth <= 0 → behind the lens.
func _project(eye: Vector3, look: Vector3, f: float, p: Vector3) -> Vector3:
	var vs: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var dir: Vector3 = look - eye
	if dir.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	var b: Basis = Basis.looking_at(dir, Vector3.UP)
	var local: Vector3 = b.inverse() * (p - eye)
	var depth: float = -local.z
	if depth <= 0.001:
		return Vector3(0, 0, depth)
	var k: float = 1.0 / tan(deg_to_rad(f) * 0.5)
	var ny: float = local.y / depth * k
	var nx: float = local.x / depth * k * vs.y / maxf(vs.x, 1.0)
	return Vector3((nx * 0.5 + 0.5) * vs.x, (0.5 - ny * 0.5) * vs.y, depth)


## Lowers the look point (camera pitches down) until the actor's head sits above HEAD_MAX_Y of the frame.
func _keep_head_in_frame(eye: Vector3, look: Vector3, f: float, head: Vector3) -> Vector3:
	var vs: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var l: Vector3 = look
	for i in 16:
		var p: Vector3 = _project(eye, l, f, head)
		if p.z <= 0.0 or p.y <= vs.y * HEAD_MAX_Y:
			break
		l.y -= 0.12
	return l


## Rigs (except `skip`) closer than FADE_NEAR to the lens whose body reaches into the frame.
func _near_lens(eye: Vector3, look: Vector3, f: float, skip: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	if stage == null:
		return out
	var vs: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var frame: Rect2 = Rect2(Vector2.ZERO, vs)
	for id: String in stage.call("unit_ids"):
		if skip.has(id):
			continue
		var r: CharacterRig = stage.call("rig", id)
		if not _rig_shown(r):
			continue
		var box: AABB = _rig_aabb(r)
		if box.get_center().distance_to(eye) > FADE_NEAR:
			continue
		# any corner of the rig's bounds (props included: a raised broom reaches far beyond the feet) in frame
		for i in 8:
			var sp: Vector3 = _project(eye, look, f, box.get_endpoint(i))
			if sp.z > 0.0 and frame.grow(-4.0).has_point(Vector2(sp.x, sp.y)):
				out.append(id)
				break
	return out


## Rig drawn at all (not escaped, not dissolved after a KO).
static func _rig_shown(r: CharacterRig) -> bool:
	if r == null or not r.visible:
		return false
	var model: Node3D = r.get_node_or_null("Model") as Node3D
	return model == null or model.visible


## World-space bounds of a rig's meshes (home ± height when it has none in the tree).
static func _rig_aabb(r: CharacterRig) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	if r.is_inside_tree():
		for n: Node in r.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var b: AABB = mi.global_transform * mi.mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
	if first:
		var h: float = maxf(r.height, 0.4)
		var p: Vector3 = r.global_position if r.is_inside_tree() else r.position
		return AABB(p - Vector3(h * 0.3, 0, h * 0.3), Vector3(h * 0.6, h, h * 0.6))
	return out


## Rigs (except `skip`) standing in the corridor between the lens and the action point (ground plane distance: a
## small enemy below the line of sight still fills the bottom of the frame).
func _blockers(eye: Vector3, at: Vector3, skip: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	if stage == null:
		return out
	var e2: Vector2 = Vector2(eye.x, eye.z)
	var seg: Vector2 = Vector2(at.x, at.z) - e2
	var len2: float = maxf(seg.length_squared(), 0.0001)
	for id: String in stage.call("unit_ids"):
		if skip.has(id):
			continue
		var r: CharacterRig = stage.call("rig", id)
		if not _rig_shown(r):
			continue
		var h: Vector3 = _home(id)
		var c: Vector2 = Vector2(h.x, h.z)
		var t: float = clampf((c - e2).dot(seg) / len2, 0.0, 1.0)
		if t < 0.04 or t > 0.92:
			continue
		if (e2 + seg * t).distance_to(c) < BLOCK_RADIUS + 0.35 * r.size_factor():
			out.append(id)
	return out


func _set_faded(ids: PackedStringArray) -> void:
	for k: Variant in _faded.keys():
		if ids.has(str(k)):
			continue
		var saved: Dictionary = _faded[k]
		for iid: Variant in saved.keys():
			var gi: GeometryInstance3D = instance_from_id(int(iid)) as GeometryInstance3D
			if gi != null and is_instance_valid(gi):
				gi.layers = int(saved[iid])
		_faded.erase(k)
	if stage == null or not is_instance_valid(stage):
		return
	for id: String in ids:
		if _faded.has(id):
			continue
		var r: CharacterRig = stage.call("rig", id)
		if r == null:
			continue
		var saved2: Dictionary = {}
		_cull(r, saved2)
		_faded[id] = saved2


static func _cull(n: Node, saved: Dictionary) -> void:
	if n is GeometryInstance3D:
		var gi: GeometryInstance3D = n as GeometryInstance3D
		saved[gi.get_instance_id()] = gi.layers
		gi.layers = HIDE_LAYER_BIT
	for c: Node in n.get_children():
		_cull(c, saved)


func _program(pos_fn: Callable, look_fn: Callable, fov_fn: Callable) -> void:
	_pos_fn = pos_fn
	_look_fn = look_fn
	_fov_fn = fov_fn


func _evaluate() -> void:
	if not _pos_fn.is_valid():
		_apply(_pos, _look, _fov)
		return
	var p: Vector3 = _pos_fn.call(_t)
	var l: Vector3 = _look_fn.call(_t)
	var f: float = _fov_fn.call(_t)
	if _drift > 0.0:
		p += Vector3(sin(_clock * 0.9) * _drift, sin(_clock * 1.3 + 1.0) * _drift * 0.6, 0)
	if _blend > 0.0 and _t < _blend:
		var w: float = _ease(_t / _blend)
		p = _from_pos.lerp(p, w)
		l = _from_look.lerp(l, w)
		f = lerpf(_from_fov, f, w)
	_pos = p
	_look = l
	_fov = f
	_apply(p, l, f)


func _apply(p: Vector3, l: Vector3, f: float) -> void:
	var tr2: float = trauma * trauma * shake_scale
	var off: Vector3 = Vector3.ZERO
	var roll: float = 0.0
	if tr2 > 0.0001:
		var w: float = _clock * SHAKE_HZ
		off = Vector3(sin(w * 1.31) + sin(w * 2.17) * 0.5, sin(w * 1.73 + 1.0) + sin(w * 2.9) * 0.4,
			sin(w * 0.97 + 2.0)) * (SHAKE_OFFSET * tr2 / 1.5)
		roll = deg_to_rad(SHAKE_ROLL_DEG) * tr2 * sin(w * 1.11 + 0.5)
	var eye: Vector3 = p + off
	var dir: Vector3 = l - eye
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, -1)
	var up: Vector3 = Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.98:
		up = Vector3(0, 0, -1)
	var b: Basis = Basis.looking_at(dir, up)
	if roll != 0.0:
		b = b.rotated(b.z.normalized(), roll)
	transform = Transform3D(b, eye)
	fov = clampf(f, 10.0, 100.0)


static func _ease(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return 0.5 - 0.5 * cos(x * PI)


# --- stage queries ---------------------------------------------------------------------------------------------------

func _home(id: String) -> Vector3:
	if stage == null or id == "":
		return Vector3.ZERO
	return stage.call("home", id)


func _height(id: String) -> float:
	if stage == null or id == "":
		return 1.0
	return float(stage.call("unit_height", id))


func _anchor(id: String, a: StringName) -> Vector3:
	if stage == null or id == "":
		return Vector3(0, 1, 0)
	return stage.call("anchor_pos", id, a)


## Live rig position (feet), e.g. during a dash.
func _live(id: String) -> Vector3:
	if stage == null or id == "":
		return Vector3.ZERO
	var r: CharacterRig = stage.call("rig", id)
	if r == null:
		return _home(id)
	return r.global_position if r.is_inside_tree() else r.position


func _live_or_home(id: String) -> Vector3:
	return _live(id) if id != "" else _enemy_center()


func _enemy_center() -> Vector3:
	return stage.call("enemy_center") if stage != null else Vector3(0, 0, -3)


func _party_center() -> Vector3:
	return stage.call("party_center") if stage != null else Vector3(0, 0, 3.1)
