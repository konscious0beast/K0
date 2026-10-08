extends Camera3D
## FF10-like battle camera (03_ART §8.3): shot(name, ctx) switches between programmed shots — establishing dolly, boss
## intro crane, over-the-shoulder command / target shots, melee side shot following the dash, skill close-up and
## release, enemy turn, stunt orbit, sponsor drop, victory orbit, defeat push-in — with cut or blend (Tween-like
## sine ease of position, look-at point and FOV). Camera trauma: offset 0.25 m × trauma² (18 Hz noise), roll 3° ×
## trauma², decay 1.5/s. Shot time runs with `speed` (battle speed ×2 / autoplay halves every shot).
## Private M5 helper (no class_name); presentation only. Positions are in the battle scene's space (stage at origin).

const TRAUMA_DECAY: float = 1.5
const SHAKE_OFFSET: float = 0.25
const SHAKE_ROLL_DEG: float = 3.0
const SHAKE_HZ: float = 18.0
const EST_FROM: Vector3 = Vector3(6.5, 4.2, 9.0)
const EST_TO: Vector3 = Vector3(4.5, 3.4, 8.0)
const EST_LOOK: Vector3 = Vector3(0, 0.9, -0.5)

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


func _ready() -> void:
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
	_drift = 0.0
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
			# behind the actor on its outer side: the actor stands bottom center, the enemies fill the frame and the
			# other party member stays out of the shot (03_ART §8.3 values for a 1.75 m hero)
			var home: Vector3 = _home(actor)
			var h: float = _height(actor)
			var s: float = -1.0 if home.x <= 0.0 else 1.0
			var hk: float = clampf(h, 0.5, 2.2)
			var cpos: Vector3 = home + Vector3(0.9 * s, 1.5 + 0.35 * hk, 2.6 + 0.4 * hk)
			# small actors (Mopsula) get a lower look point so they sit above the bottom HUD / chat ticker
			var look: Vector3 = _enemy_center().lerp(home, 0.25) + Vector3(0, 0.1 + 0.28 * hk, 0)
			var cfov: float = 48.0
			blend = 0.35
			if p_name == &"target_select" and target != "":
				look = _home(target) + Vector3(0, minf(_height(target) * 0.6, 1.0), 0)
				if target.begins_with("p"):
					look = _home(target) + Vector3(0, 0.6, 0)
				cfov = 44.0
				blend = 0.2
			_program(func(_t1: float) -> Vector3: return cpos, func(_t2: float) -> Vector3: return look,
				func(_t3: float) -> float: return cfov)
			_drift = 0.03
		&"action_side":
			var side: float = -1.0 if _home(actor).x < 0.0 else 1.0
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
		_:
			push_warning("[BattleCamera] unknown shot '%s'" % p_name)
			return
	shot_name = p_name
	_from_pos = _pos
	_from_look = _look
	_from_fov = _fov
	_t = 0.0
	_blend = blend
	_evaluate()


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
