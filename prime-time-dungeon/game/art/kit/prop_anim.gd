extends Node3D
## Root script of animated props built by PropKit (private, no class_name): drone rotors + blinking lens, bobbing
## stairs arrow, idle-turning fortune wheel, lever, sliding safe-room door, flickering broken screens.
## play_action() triggers the prop's one action (wheel spin, lever pull, door open/close); idle motion runs in
## _process and therefore only inside the tree.

var mode: String = ""
var parts: Dictionary = {}          # role → Node3D
var _rest: Dictionary = {}          # role → Transform3D
var _t: float = 0.0
var _action: float = 0.0            # 0..1 progress of the current action
var _action_dir: float = 0.0        # +1 running, -1 returning, 0 idle
var _wheel_speed: float = 0.4
var _is_open: bool = false


func _ready() -> void:
	for role: String in parts:
		var n: Node3D = parts[role]
		if n != null:
			_rest[role] = n.transform


## Wheel: fast spin that slows down; lever: pull down and back; door: toggles open/closed.
func play_action() -> void:
	match mode:
		"wheel":
			_wheel_speed = 14.0
		"lever":
			_action = 0.0
			_action_dir = 1.0
		"door":
			_is_open = not _is_open
			_action_dir = 1.0 if _is_open else -1.0


func is_open() -> bool:
	return _is_open


func _process(delta: float) -> void:
	_t += delta
	match mode:
		"drone":
			for i in 4:
				var r: Node3D = parts.get("rotor%d" % i, null)
				if r != null:
					r.rotate_y(40.0 * delta)
			var body: Node3D = parts.get("body", null)
			if body != null and _rest.has("body"):
				body.position = (_rest["body"] as Transform3D).origin + Vector3(0, 0.08 * sin(TAU * 0.7 * _t), 0)
			var lens: Node3D = parts.get("lens", null)
			if lens != null:
				lens.visible = fmod(_t, 1.0) < 0.6
		"stairs":
			var arrow: Node3D = parts.get("arrow", null)
			if arrow != null and _rest.has("arrow"):
				arrow.position = (_rest["arrow"] as Transform3D).origin + Vector3(0, 0.1 * sin(TAU * _t), 0)
				arrow.rotate_y(1.2 * delta)
		"wheel":
			var wheel: Node3D = parts.get("wheel", null)
			if wheel != null:
				wheel.rotate_object_local(Vector3.FORWARD, _wheel_speed * delta)
			_wheel_speed = maxf(0.4, _wheel_speed * pow(0.35, delta))
		"lever":
			var arm: Node3D = parts.get("arm", null)
			if arm != null and _rest.has("arm"):
				if _action_dir > 0.0:
					_action = minf(_action + delta / 0.35, 1.0)
					if _action >= 1.0:
						_action_dir = -1.0
				elif _action_dir < 0.0:
					_action = maxf(_action - delta / 0.8, 0.0)
					if _action <= 0.0:
						_action_dir = 0.0
				var r_t: Transform3D = _rest["arm"]
				arm.transform = Transform3D(r_t.basis * Basis(Vector3.RIGHT, deg_to_rad(-80.0 * _action)), r_t.origin)
		"door":
			if _action_dir != 0.0:
				_action = clampf(_action + _action_dir * delta / 0.5, 0.0, 1.0)
				if _action <= 0.0 or _action >= 1.0:
					_action_dir = 0.0
			for side: String in ["left", "right"]:
				var panel: Node3D = parts.get(side, null)
				if panel != null and _rest.has(side):
					var sx: float = -1.0 if side == "left" else 1.0
					var u: float = _action * _action * (3.0 - 2.0 * _action)
					panel.position = (_rest[side] as Transform3D).origin + Vector3(1.9 * sx * u, 0, 0)
		"flicker":
			var screen: Node3D = parts.get("screen", null)
			if screen != null:
				var n: float = fposmod(sin(floor(_t * 9.0) * 78.233) * 43758.5453, 1.0)
				screen.visible = n > 0.25
