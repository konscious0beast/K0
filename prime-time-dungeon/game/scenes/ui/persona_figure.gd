extends SubViewportContainer
## Private helper of the casting screens (08 §1.2, §1.4; no class_name): the candidate's 3D figure on a small round
## stage in its own world, turning slowly like the hero select's preview. K1 always shows the canon look (the avatar
## editor and DB.party_model's look are K2). Rendered only while visible.

const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const TURN_DEG: float = 24.0

var accent: Color = Color("#3aa9a0")
var member_id: String = "kai"

var _fig: Node3D = null
var _t: float = 0.0


func _init(p_member: String = "kai", p_accent: Color = Color("#3aa9a0")) -> void:
	member_id = p_member
	accent = p_accent
	name = "Figure"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var world: Node3D = Node3D.new()
	vp.add_child(world)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = SceneKit.environment(Color("#1b1026"), Color("#6a5a8a"), 0.9, false)
	world.add_child(we)
	world.add_child(SceneKit.sun(Color("#fff2e0"), 1.3, Vector3(-40, -30, 0)))
	world.add_child(SceneKit.omni(accent, 2.2, 6.0, Vector3(-1.4, 1.6, 1.2)))
	_fig = SceneKit.party_figure(member_id)
	_fig.rotation.y = PI                       # rigs look along −Z
	world.add_child(_fig)
	if _fig.has_method("play"):
		_fig.call("play", &"idle")
	var height: float = maxf(0.6, float(_fig.get("height")) if "height" in _fig else 1.0)
	var r: float = 0.5 + height * 0.35
	world.add_child(SceneKit.cylinder(r, r, 0.12, Color("#2a1c3a"), Vector3(0, -0.06, 0)))
	world.add_child(SceneKit.cylinder(r + 0.02, r + 0.02, 0.02, accent.darkened(0.2), Vector3(0, 0.005, 0), 0.6))
	var dist: float = height * 1.25 + 1.7
	world.add_child(SceneKit.camera(Vector3(0.0, 1.3, dist), Vector3(0.0, height * 0.5, 0.0), 40.0))


func _process(delta: float) -> void:
	_t += delta
	if _fig != null and is_instance_valid(_fig):
		_fig.rotation.y = PI + deg_to_rad(TURN_DEG) * sin(_t * 0.6)
