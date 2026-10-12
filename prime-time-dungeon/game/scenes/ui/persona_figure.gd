extends SubViewportContainer
## Private helper of the casting screens (08 §1.2, §1.4; no class_name): the candidate's 3D figure on a small round
## stage in its own world, turning slowly like the hero select's preview. Casting (08 §6.1, K2): `look` is the look
## to show ({kind: lk id}, {} = canon; null = the running persona's look through DB.party_model); set_look() swaps the
## figure in place — the live preview of the avatar editor (the SubViewport, its world, light and camera stay; only
## the rig is rebuilt from CharacterBuilder's mesh cache). `closeup` frames head and shoulders larger (the editor on
## casting 1/3). Rendered only while visible.

const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const TURN_DEG: float = 24.0
## Framing of the 1.75 m candidate (camera height and look-at height as a share of the figure height, distance).
const FULL: Dictionary = {"cam_h": 1.3, "aim": 0.5, "dist_k": 1.25, "dist_c": 1.7}
const CLOSEUP: Dictionary = {"cam_h": 1.5, "aim": 0.63, "dist_k": 0.65, "dist_c": 1.0}

var accent: Color = Color("#3aa9a0")
var member_id: String = "kai"
var look: Variant = null
var closeup: bool = false
## How many times the figure was swapped by set_look (tests: the preview updates without rebuilding the scene).
var swaps: int = 0

var _world: Node3D = null
var _fig: Node3D = null
var _t: float = 0.0
var _light: OmniLight3D = null             # Recall (06 §3.5): set_accent tints the light and the stage ring
var _ring: MeshInstance3D = null


func _init(p_member: String = "kai", p_accent: Color = Color("#3aa9a0"), p_look: Variant = null,
		p_closeup: bool = false) -> void:
	member_id = p_member
	accent = p_accent
	look = (p_look as Dictionary).duplicate() if p_look is Dictionary else null
	closeup = p_closeup
	name = "Figure"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	_world = Node3D.new()
	_world.name = "World"
	vp.add_child(_world)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = SceneKit.environment(Color("#1b1026"), Color("#6a5a8a"), 0.9, false)
	_world.add_child(we)
	_world.add_child(SceneKit.sun(Color("#fff2e0"), 1.3, Vector3(-40, -30, 0)))
	_light = SceneKit.omni(accent, 2.2, 6.0, Vector3(-1.4, 1.6, 1.2))
	_world.add_child(_light)
	_swap_figure()
	var height: float = maxf(0.6, float(_fig.get("height")) if "height" in _fig else 1.0)
	var r: float = 0.5 + height * 0.35
	_world.add_child(SceneKit.cylinder(r, r, 0.12, Color("#2a1c3a"), Vector3(0, -0.06, 0)))
	_ring = SceneKit.cylinder(r + 0.02, r + 0.02, 0.02, accent.darkened(0.2), Vector3(0, 0.005, 0), 0.6)
	_world.add_child(_ring)
	var f: Dictionary = CLOSEUP if closeup else FULL
	var dist: float = height * float(f["dist_k"]) + float(f["dist_c"])
	_world.add_child(SceneKit.camera(Vector3(0.0, float(f["cam_h"]), dist), Vector3(0.0, height * float(f["aim"]), 0.0),
		40.0))


## Recall (06 §3.5): the stage light and its ring in `col` (the species' colour, 03_ART: the look itself follows) —
## nothing is rebuilt; the shared materials of SceneKit stay untouched (the ring gets the cached one of its colour).
func set_accent(col: Color) -> void:
	accent = col
	if _light != null:
		_light.light_color = col
	if _ring != null:
		_ring.material_override = SceneKit.mat(col.darkened(0.2), 0.6)


## Shows `p_look` ({kind: lk id}) now: the rig is replaced in the running world (no scene rebuild).
func set_look(p_look: Dictionary) -> void:
	look = p_look.duplicate()
	if _world == null:
		return
	_swap_figure()
	swaps += 1


## The current rig (tests).
func figure() -> Node3D:
	return _fig


func _swap_figure() -> void:
	var yaw: float = _fig.rotation.y if _fig != null and is_instance_valid(_fig) else PI
	if _fig != null and is_instance_valid(_fig):
		_world.remove_child(_fig)
		_fig.queue_free()
	if look is Dictionary and member_id == "kai":
		_fig = SceneKit.look_figure(look as Dictionary)
	else:
		_fig = SceneKit.party_figure(member_id)
	_fig.name = "Candidate"
	_fig.rotation.y = yaw                      # rigs look along −Z
	_world.add_child(_fig)
	if _fig.has_method("play"):
		_fig.call("play", &"idle")


func _process(delta: float) -> void:
	_t += delta
	if _fig != null and is_instance_valid(_fig):
		_fig.rotation.y = PI + deg_to_rad(TURN_DEG) * sin(_t * 0.6)
