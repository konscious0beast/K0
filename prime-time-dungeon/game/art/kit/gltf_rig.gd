extends CharacterRig
## glTF character wrapper (02_TECH §8.4, 03_ART §10). Private (no class_name): created by CharacterBuilder when
## ModelSpec.gltf points to an existing scene. Same API as procedural rigs; the AnimationPlayer clips named like
## CharacterRig.ANIMS own the pose, the base class keeps the timing contract (impact once, anim_finished, back to idle).
## Impact time: a method track calling emit_impact() (preferred), else `<model>.anim.json` {"attack": 0.30, …},
## else the procedural defaults. Materials are replaced by Materials.toon_vc(); anchors are nodes named
## `anchor_<name>` (head, center, overhead, hand_r, hand_l, feet).

const Forwarder := preload("res://art/kit/gltf_impact_forwarder.gd")

var _player: AnimationPlayer = null
var _clips: Dictionary = {}            # StringName → clip name
var _impacts: Dictionary = {}          # StringName → seconds
var _track_clips: Dictionary = {}      # StringName → true for clips whose method track calls emit_impact()


func setup_from_scene(inst: Node3D, p_model: Dictionary) -> void:
	_procedural = false
	model = p_model.duplicate(true)
	name = "Rig_gltf"
	var root := Node3D.new()
	root.name = "Model"
	var s: float = clampf(float(model.get("scale", 1.0)), 0.3, 4.0)
	root.scale = Vector3.ONE * s
	add_child(root)
	if inst.get_script() == null:
		inst.set_script(Forwarder)
		inst.set("rig", self)
	root.add_child(inst)
	_player = _find_player(inst)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(inst, meshes)
	var opts: Dictionary = {"bands": 3, "rim": 0.45}
	var mesh_opts: Dictionary = {}
	var pulses: Array[Dictionary] = []
	for mi: MeshInstance3D in meshes:
		mi.material_override = Materials.toon_vc(opts)
		mesh_opts[mi] = opts
		if mi.name.ends_with("_glow"):
			pulses.append({"mesh": mi, "mode": "pulse", "color": Palette.PAPER})
	var anchors: Dictionary = {}
	_collect_anchors(inst, anchors)
	if not anchors.has(&"feet"):
		var feet := Node3D.new()
		feet.name = "Anchor_feet"
		add_child(feet)
		anchors[&"feet"] = feet
	if _player != null:
		for a: StringName in ANIMS:
			if _player.has_animation(a):
				_clips[a] = String(a)
				if _has_impact_track(_player.get_animation(a)):
					_track_clips[a] = true
		_player.animation_finished.connect(_on_clip_finished)
	_load_impacts(str(model.get("gltf", "")))
	var bounds := AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes:
		if mi.mesh == null:
			continue
		var xf: Transform3D = _xform_to_self(mi)
		var b: AABB = xf * mi.mesh.get_aabb()
		bounds = b if first else bounds.merge(b)
		first = false
	var pose: StringName = &"quadruped" if str(model.get("pose", "")) == "quadruped" else &"upright"
	call("_setup", {"base": str(model.get("base", "humanoid")), "pose": pose,
		"model_root": root, "scale": s, "pivots": {}, "meshes": meshes, "mesh_opts": mesh_opts, "pulses": pulses,
		"anchors": anchors, "particles": [], "height": maxf(bounds.end.y, 0.1),
		"width": maxf(bounds.size.x, bounds.size.z), "arm_out": 0.0, "phase": 0.0})


func play(anim: StringName, speed: float = 1.0) -> void:
	var still_dead: bool = anim == &"die" and _dead
	super.play(anim, speed)
	if still_dead:
		return   # KO rig keeps the end frame of the die clip
	if _player != null and _clips.has(_anim):
		_player.speed_scale = 1.0
		_player.play(str(_clips[_anim]), -1.0, maxf(speed, 0.01))


func set_dead(dead: bool) -> void:
	super.set_dead(dead)
	if dead and _player != null and _clips.has(&"die"):
		var clip: String = str(_clips[&"die"])
		_player.play(clip)
		_player.seek(_player.get_animation(clip).length, true)
	else:
		_sync_clip()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_clip()


## Keeps the looping clip in line with the base-class state (back to idle/walk/run after a one-shot, locomotion
## changes) and scales walk/run clips with the cadence set_locomotion() computed.
func _sync_clip() -> void:
	if _player == null or not LOOPING.has(_anim) or not _clips.has(_anim):
		return
	var clip: String = str(_clips[_anim])
	if String(_player.current_animation) != clip:
		_player.play(clip)
	if _anim == &"walk" or _anim == &"run":
		_player.speed_scale = _rate * float(LOOP_PERIOD[_anim]) * _speed
	else:
		_player.speed_scale = _speed


func _duration(anim: StringName) -> float:
	if _player != null and _clips.has(anim):
		return _player.get_animation(str(_clips[anim])).length
	return super._duration(anim)


func _impact_time(anim: StringName) -> float:
	if _track_clips.has(anim):
		return INF   # this clip's method track calls emit_impact() (missed → emitted at the end, base class)
	if _impacts.has(anim):
		return float(_impacts[anim])
	return super._impact_time(anim)


func _on_clip_finished(_clip: StringName) -> void:
	pass   # timing is driven by the base class (_duration), clips only provide the pose


func _load_impacts(gltf_path: String) -> void:
	if gltf_path == "":
		return
	var json_path: String = gltf_path.get_basename() + ".anim.json"
	if not FileAccess.file_exists(json_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("glTF rig: invalid %s" % json_path)
		return
	for k: Variant in (parsed as Dictionary):
		_impacts[StringName(str(k))] = float((parsed as Dictionary)[k])


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c: Node in n.get_children():
		var p: AnimationPlayer = _find_player(c)
		if p != null:
			return p
	return null


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		_collect_meshes(c, out)


static func _collect_anchors(n: Node, out: Dictionary) -> void:
	var nm: String = String(n.name)
	if nm.begins_with("anchor_") and n is Node3D:
		out[StringName(nm.trim_prefix("anchor_"))] = n
	for c: Node in n.get_children():
		_collect_anchors(c, out)


static func _has_impact_track(anim: Animation) -> bool:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_METHOD:
			for k in anim.track_get_key_count(i):
				if str(anim.method_track_get_name(i, k)) == "emit_impact":
					return true
	return false


func _xform_to_self(node: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var cur: Node = node.get_parent()
	while cur != null and cur != self:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
