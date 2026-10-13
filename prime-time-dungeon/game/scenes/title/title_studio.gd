extends Node3D
## Private M6 3D set of the title screen (GDD §14.1): TV studio with a round stage, neon ring, curved backdrop with
## magenta/cyan strips, light cones and the rotating M.O.D. drone (03_ART §5.6). StandardMaterial3D only.

const SceneKit := preload("res://scenes/ui/scene_kit.gd")

var drone: Node3D
var _beams: Array[Node3D] = []
var _cams: Array[Node3D] = []
var _t: float = 0.0
var _drone_base: Vector3 = Vector3(1.55, 1.75, 0.0)


func _ready() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = SceneKit.environment(Color("#120a1c"), Color("#6a4a9a"), 0.55, true, Color("#1a1030"), 0.035)
	add_child(we)
	add_child(SceneKit.sun(Color("#c9b8ff"), 0.35, Vector3(-50, 30, 0)))
	var cam: Camera3D = SceneKit.camera(Vector3(0.0, 1.75, 7.4), Vector3(0.7, 1.45, 0.0), 48.0)
	add_child(cam)
	# Stage.
	add_child(SceneKit.cylinder(4.2, 4.4, 0.3, Color("#24183a"), Vector3(0, -0.15, 0), 0.0, 32))
	add_child(SceneKit.cylinder(4.45, 4.45, 0.05, Color("#ff2e88"), Vector3(0, 0.01, 0), 1.8, 40))
	add_child(SceneKit.cylinder(4.3, 4.3, 0.06, Color("#24183a"), Vector3(0, 0.02, 0), 0.0, 40))
	add_child(SceneKit.cylinder(1.4, 1.4, 0.04, Color("#22d3ee"), Vector3(1.55, 0.05, 0), 1.2, 32))
	add_child(SceneKit.cylinder(1.3, 1.3, 0.06, Color("#1a1030"), Vector3(1.55, 0.06, 0), 0.0, 32))
	var floor_m: MeshInstance3D = SceneKit.box(Vector3(40, 0.1, 40), Color("#0e0816"), Vector3(0, -0.36, 0))
	add_child(floor_m)
	# Curved backdrop panels with neon strips.
	for i in 13:
		var a: float = deg_to_rad(-70.0 + i * (140.0 / 12.0))
		var r: float = 7.5
		var pos: Vector3 = Vector3(sin(a) * r, 2.2, -cos(a) * r + 1.0)
		var panel: Node3D = Node3D.new()
		panel.position = pos
		panel.rotation.y = -a
		add_child(panel)
		panel.add_child(SceneKit.box(Vector3(1.6, 4.8, 0.2), Color("#1d1430") if i % 2 == 0 else Color("#241a3a")))
		var col: Color = Color("#ff2e88") if i % 3 == 0 else (Color("#22d3ee") if i % 3 == 1 else Color("#7b2cbf"))
		panel.add_child(SceneKit.box(Vector3(0.08, 4.4, 0.06), col, Vector3(0.78, 0, 0.12), 2.2))
		if i % 2 == 1:
			for k in 3:
				panel.add_child(SceneKit.box(Vector3(1.1, 0.08, 0.05), Color("#ffc93c"), Vector3(0, -1.2 + k * 0.6,
					0.12), 0.8 + 0.4 * k))
	# Big screen behind the stage.
	var screen: MeshInstance3D = SceneKit.box(Vector3(4.6, 2.4, 0.1), Color("#2a0f3a"), Vector3(1.4, 3.3, -5.6), 0.6)
	add_child(screen)
	add_child(SceneKit.box(Vector3(4.8, 0.08, 0.12), Color("#22d3ee"), Vector3(1.4, 4.55, -5.55), 2.0))
	add_child(SceneKit.box(Vector3(4.8, 0.08, 0.12), Color("#22d3ee"), Vector3(1.4, 2.05, -5.55), 2.0))
	# Light cones (additive, slow sweep).
	for i in 4:
		var beam_root: Node3D = Node3D.new()
		beam_root.position = Vector3(-3.0 + i * 2.6, 6.2, -1.5)
		add_child(beam_root)
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.12
		cone.bottom_radius = 1.4
		cone.height = 7.0
		cone.radial_segments = 16
		var col_b: Color = Color("#ff2e88") if i % 2 == 0 else Color("#22d3ee")
		var mi: MeshInstance3D = SceneKit.mesh_node(cone, SceneKit.mat(col_b, 0.0, true, 0.07, true), Vector3(0, -3.5, 0))
		beam_root.add_child(mi)
		beam_root.add_child(SceneKit.box(Vector3(0.5, 0.35, 0.5), Color("#3a3248"), Vector3.ZERO))
		_beams.append(beam_root)
	# Small camera drones hovering around the stage.
	for i in 2:
		var c: Node3D = Node3D.new()
		c.add_child(SceneKit.box(Vector3(0.36, 0.22, 0.28), Color("#3a3248")))
		c.add_child(SceneKit.sphere(0.05, Color("#ff3b30"), Vector3(0, 0.0, -0.16), 3.0))
		c.add_child(SceneKit.box(Vector3(0.7, 0.03, 0.06), Color("#5a5266"), Vector3(0, 0.14, 0)))
		add_child(c)
		_cams.append(c)
	drone = SceneKit.build_drone(1.9)
	drone.position = _drone_base
	add_child(drone)
	add_child(SceneKit.omni(Color("#22d3ee"), 2.2, 6.0, _drone_base + Vector3(0, 0.2, 1.2)))
	add_child(SceneKit.omni(Color("#ff2e88"), 1.6, 9.0, Vector3(-3.0, 3.0, 2.0)))
	add_child(SceneKit.omni(Color("#ffc93c"), 0.8, 8.0, Vector3(3.5, 2.5, 3.0)))


func _process(delta: float) -> void:
	_t += delta
	SceneKit.animate_drone(drone, _t, _drone_base.y)
	for i in _beams.size():
		_beams[i].rotation = Vector3(0.0, 0.0, sin(_t * 0.4 + i * 1.3) * 0.35)
	for i in _cams.size():
		var a: float = _t * (0.35 + 0.1 * i) + i * PI
		_cams[i].position = Vector3(1.55 + cos(a) * (2.6 + i * 0.6), 2.4 + sin(_t * 0.8 + i) * 0.25, sin(a) * 1.6)
		_cams[i].rotation.y = -a + PI * 0.5
