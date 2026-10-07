extends RefCounted
## Private M6 helper (§0.3): the safe room set. Uses EnvKit.build_safe_room / safe_room_anchor (M4); while EnvKit is
## still a stub (empty node) it builds a stand-in interior (12 × 10 m, warm light, couch, vending machine with glowing
## front, save terminal, CRT with M.O.D., door + theme dressing kiosk / pumphouse / signalbox, GDD §10.1).

const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const ANCHORS: Dictionary = {
	&"camera": [Vector3(-1.4, 2.25, 6.3), Vector3(-1.7, 1.05, -1.0)],
	&"player_spot": [Vector3(0.2, 0.0, 0.9), Vector3(0.2, 0.0, 6.0)],
	&"mopsula_spot": [Vector3(1.55, 0.0, 1.25), Vector3(0.0, 0.0, 6.0)],
	&"vending": [Vector3(3.9, 0.0, -2.9), Vector3(3.9, 0.0, 0.0)],
	&"terminal": [Vector3(-2.2, 0.0, -3.9), Vector3(-2.2, 0.0, 0.0)],
	&"couch": [Vector3(1.6, 0.0, -2.9), Vector3(1.6, 0.0, 0.0)],
	&"door": [Vector3(-5.6, 0.0, -1.0), Vector3(0.0, 0.0, -1.0)],
}


## {"room": Node3D, "stand_in": bool}
static func build(seed_value: int, quality: StringName, theme: StringName) -> Dictionary:
	var room: Node3D = EnvKit.build_safe_room(seed_value, quality, theme)
	if room != null and room.get_child_count() > 0:
		return {"room": room, "stand_in": false}
	if room == null:
		room = Node3D.new()
	_build_stand_in(room, theme)
	return {"room": room, "stand_in": true}


## Transform of an anchor (EnvKit when real, own stand-in anchors otherwise).
static func anchor(anchor_name: StringName, stand_in: bool) -> Transform3D:
	if not stand_in:
		return EnvKit.safe_room_anchor(anchor_name)
	var a: Array = ANCHORS.get(anchor_name, [Vector3.ZERO, Vector3(0, 0, 1)])
	var pos: Vector3 = a[0]
	var target: Vector3 = a[1]
	var dir: Vector3 = target - pos
	if dir.length_squared() < 0.0001:
		return Transform3D(Basis.IDENTITY, pos)
	return Transform3D(Basis.looking_at(dir, Vector3.UP), pos)


static func _build_stand_in(room: Node3D, theme: StringName) -> void:
	var floor_c: Color = Color("#4a3a40")
	var wall_c: Color = Color("#6a5a60")
	room.add_child(SceneKit.box(Vector3(12, 0.2, 10), floor_c, Vector3(0, -0.1, 0)))
	for x in 6:
		room.add_child(SceneKit.box(Vector3(0.04, 0.01, 10), Color("#2e242a"), Vector3(-5 + x * 2.0, 0.005, 0)))
	room.add_child(SceneKit.box(Vector3(12, 4, 0.3), wall_c, Vector3(0, 2, -5)))
	room.add_child(SceneKit.box(Vector3(0.3, 4, 10), wall_c.darkened(0.1), Vector3(-6, 2, 0)))
	room.add_child(SceneKit.box(Vector3(0.3, 4, 10), wall_c.darkened(0.1), Vector3(6, 2, 0)))
	room.add_child(SceneKit.box(Vector3(12, 0.25, 0.32), Color("#3a2c30"), Vector3(0, 0.12, -4.84)))
	room.add_child(SceneKit.box(Vector3(12, 0.08, 0.06), Color("#ffc93c"), Vector3(0, 3.2, -4.82), 0.6))
	# Couch.
	room.add_child(SceneKit.box(Vector3(2.6, 0.5, 1.0), Color("#7b2cbf"), Vector3(1.6, 0.35, -2.9)))
	room.add_child(SceneKit.box(Vector3(2.6, 0.8, 0.3), Color("#6a24a8"), Vector3(1.6, 0.8, -3.35)))
	room.add_child(SceneKit.box(Vector3(0.3, 0.7, 1.0), Color("#6a24a8"), Vector3(0.35, 0.55, -2.9)))
	room.add_child(SceneKit.box(Vector3(0.3, 0.7, 1.0), Color("#6a24a8"), Vector3(2.85, 0.55, -2.9)))
	# Vending machine (glowing front #3CE0C0).
	room.add_child(SceneKit.box(Vector3(1.1, 2.2, 0.9), Color("#2a3a4a"), Vector3(3.9, 1.1, -3.9)))
	room.add_child(SceneKit.box(Vector3(0.8, 1.4, 0.05), Color("#3ce0c0"), Vector3(3.8, 1.35, -3.43), 1.4))
	for i in 3:
		room.add_child(SceneKit.box(Vector3(0.12, 0.08, 0.05), Color("#ff2e88"), Vector3(4.3, 1.7 - i * 0.25, -3.43),
			1.6))
	# Save terminal.
	room.add_child(SceneKit.box(Vector3(0.8, 1.2, 0.5), Color("#3a3248"), Vector3(-2.2, 0.6, -4.3)))
	room.add_child(SceneKit.box(Vector3(0.6, 0.4, 0.05), Color("#22d3ee"), Vector3(-2.2, 1.0, -4.03), 1.5))
	# CRT with M.O.D.
	room.add_child(SceneKit.box(Vector3(1.2, 0.9, 0.8), Color("#3a3036"), Vector3(-0.4, 2.4, -4.5)))
	room.add_child(SceneKit.box(Vector3(0.9, 0.62, 0.05), Color("#0b3b4a"), Vector3(-0.4, 2.4, -4.08), 0.8))
	var drone: Node3D = SceneKit.build_drone(0.45)
	drone.name = "TvDrone"
	drone.position = Vector3(-0.4, 2.4, -3.95)
	room.add_child(drone)
	# Door (exit green sign).
	room.add_child(SceneKit.box(Vector3(0.15, 2.4, 1.3), Color("#5a4a3e"), Vector3(-5.8, 1.2, -1.0)))
	room.add_child(SceneKit.box(Vector3(0.1, 0.25, 0.6), Color("#2bd66b"), Vector3(-5.8, 2.7, -1.0), 2.0))
	# Rug.
	room.add_child(SceneKit.cylinder(1.6, 1.6, 0.02, Color("#8a3a5a"), Vector3(0.8, 0.01, 0.6), 0.0, 24))
	match theme:
		&"pumphouse":
			for i in 2:
				room.add_child(SceneKit.cylinder(0.45, 0.5, 2.2, Color("#4a6a6a"), Vector3(-4.2 + i * 1.3, 1.1, -3.6)))
				room.add_child(SceneKit.cylinder(0.15, 0.15, 0.05, Color("#e8f0d8"), Vector3(-4.2 + i * 1.3, 1.6, -3.1),
					0.5))
			room.add_child(SceneKit.box(Vector3(3.2, 0.18, 0.18), Color("#7c8a94"), Vector3(-3.5, 2.9, -3.6)))
		&"signalbox":
			for i in 7:
				room.add_child(SceneKit.box(Vector3(0.08, 0.7, 0.08), Color("#ff3b30") if i % 2 == 0 else Color("#4ade80"),
					Vector3(-4.6 + i * 0.3, 1.25, -3.8), 0.6, Vector3(-20, 0, 0)))
			room.add_child(SceneKit.box(Vector3(2.4, 0.9, 0.6), Color("#3a3036"), Vector3(-3.7, 0.45, -3.8)))
			room.add_child(SceneKit.box(Vector3(2.2, 1.0, 0.04), Color("#22d3ee"), Vector3(-3.7, 2.4, -4.8), 0.9))
		_:
			room.add_child(SceneKit.box(Vector3(2.6, 1.1, 0.7), Color("#8a5a32"), Vector3(-3.8, 0.55, -3.7)))
			room.add_child(SceneKit.box(Vector3(2.7, 0.08, 0.8), Color("#ffc93c"), Vector3(-3.8, 1.12, -3.7), 0.3))
			for i in 4:
				room.add_child(SceneKit.box(Vector3(0.5, 0.06, 0.35), Color("#f5f0e6"), Vector3(-4.6 + i * 0.55, 1.2,
					-3.7), 0.0, Vector3(0, 8.0 * i, 0)))
			room.add_child(SceneKit.box(Vector3(0.9, 1.6, 0.4), Color("#5a4a3e"), Vector3(-5.2, 0.8, -2.4)))
	room.add_child(SceneKit.omni(Color("#ffc98a"), 1.8, 11.0, Vector3(0.5, 3.4, -0.5)))
	room.add_child(SceneKit.omni(Color("#3ce0c0"), 0.9, 4.0, Vector3(3.7, 1.4, -2.8)))
	room.add_child(SceneKit.omni(Color("#22d3ee"), 0.6, 3.0, Vector3(-0.4, 2.4, -3.4)))
	room.add_child(SceneKit.sphere(0.18, Color("#ffe2b8"), Vector3(0.5, 3.75, -0.5), 3.0))
