extends RefCounted
## Battle arena and safe-room interiors for EnvKit (02_TECH §8.5, 03_ART §4.3/§6.3/§8.2). Private (no class_name).

const SAFE_W: float = 12.0
const SAFE_D: float = 10.0
const SAFE_H: float = 3.4

## Safe-room anchors (local to build_safe_room's root); identical for all themes.
const SAFE_ANCHORS: Dictionary = {
	&"vending": [Vector3(-4.6, 0, -4.15), 0.0],
	&"terminal": [Vector3(-2.9, 0, -4.4), 0.0],
	&"couch": [Vector3(2.0, 0, -3.95), 0.0],
	&"mopsula_spot": [Vector3(2.45, 0.45, -3.9), 0.0],
	&"player_spot": [Vector3(0.6, 0, -1.6), -15.0],
	&"door": [Vector3(5.15, 0, -2.0), -90.0],
}
## Fixed camera (FOV 50 vertical, 03_ART §8.1). The exit door sits on the right wall toward the back and the camera aims
## slightly right, so the door is in frame at 4:3, 16:9 and 20:9 (review M4; test_m4_env checks the frustum).
const SAFE_CAMERA_POS: Vector3 = Vector3(0.0, 2.9, 6.4)
const SAFE_CAMERA_TARGET: Vector3 = Vector3(0.45, 1.05, -2.0)
const SAFE_CAMERA_FOV: float = 50.0
## Ceiling beams (z), clear of the door (z −4.3 … 0.3).
const BEAM_Z: Array[float] = [-4.4, 0.9, 3.4]


static func safe_anchor(anchor: StringName) -> Transform3D:
	if anchor == &"camera":
		return Transform3D.IDENTITY.looking_at(SAFE_CAMERA_TARGET - SAFE_CAMERA_POS, Vector3.UP).translated(SAFE_CAMERA_POS)
	if not SAFE_ANCHORS.has(anchor):
		push_warning("EnvKit.safe_room_anchor: unknown anchor '%s'" % anchor)
		return Transform3D.IDENTITY
	var a: Array = SAFE_ANCHORS[anchor]
	# yaw 0 = front (−Z local) faces the camera (+Z world)
	return Transform3D(Basis(Vector3.UP, PI + deg_to_rad(float(a[1]))), a[0] as Vector3)


static func _part(mesh: Mesh, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		emission: float = 0.0, metal: float = 0.0) -> Dictionary:
	return MeshUtil.part(mesh, pos, color, rot, scl, emission, metal)


static func _mesh_node(node_name: String, parts: Array, mat: Material, shadows: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var typed: Array[Dictionary] = []
	typed.assign(parts)
	mi.mesh = MeshUtil.merge_no_hull(typed)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _omni(node_name: String, pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = node_name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.light_specular = 0.0
	return l


static func _label(text: String, size: int, color: Color, outline: Color, xf: Transform3D,
		px: float = 0.006) -> Label3D:
	var l := Label3D.new()
	l.name = "Label_" + text.replace(" ", "_").left(16)
	l.text = text
	l.font_size = size
	l.outline_size = 14
	l.pixel_size = px
	l.modulate = Palette.sign_color(color)
	l.outline_modulate = outline
	l.transform = xf
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return l


# --- battle arena (03_ART §8.2: stage r 9 m, party at +Z, enemies at −Z) ----------------------------------------------

const PARTY_ZONE := Vector3(0, 0, 3.1)
const ENEMY_ZONE := Vector3(0, 0, -3.0)

static func build_arena(theme_id: String, palette: Dictionary, is_boss: bool, seed: int, quality: StringName) -> Node3D:
	var pal: Dictionary = Palette.resolve(palette, theme_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("arena") ^ (seed * 2654435761)
	var accent: Color = Palette.DANGER if is_boss else pal["accent"]
	var root := Node3D.new()
	root.name = "BattleArena"
	var geo: Array = []
	var floor_c: Color = pal["floor"]
	var wall_c: Color = pal["wall"]
	# ground around the stage + the stage itself
	geo.append(_part(MeshUtil.box(Vector3(64, 0.2, 64)), Vector3(0, -0.4, 0), Palette.mul(floor_c, 0.7)))
	var stage := MeshUtil.cylinder(9.0, 9.2, 0.32)
	stage.radial_segments = 40
	geo.append(_part(stage, Vector3(0, -0.16, 0), floor_c))
	var led := MeshUtil.torus(9.02, 9.22)
	led.rings = 48
	led.ring_segments = 4
	geo.append(_part(led, Vector3(0, -0.02, 0), accent, Vector3.ZERO, Vector3(1, 0.35, 1), 1.0))
	var skirt := MeshUtil.cylinder(9.25, 9.4, 0.3)
	skirt.radial_segments = 40
	geo.append(_part(skirt, Vector3(0, -0.2, 0), Palette.INK))
	# party / enemy zones + NOVA star in the middle
	for zone: Array in [[Vector3(0, 0.006, 3.1), 2.4, Palette.NOVA_CYAN], [Vector3(0, 0.006, -3.0), 3.4, accent]]:
		var ring := MeshUtil.torus(float(zone[1]), float(zone[1]) + 0.12)
		ring.rings = 32
		ring.ring_segments = 3
		geo.append(_part(ring, zone[0] as Vector3, zone[2] as Color, Vector3.ZERO, Vector3(1, 0.05, 1), 0.6))
	for k in 4:
		geo.append(_part(MeshUtil.box(Vector3(2.4, 0.01, 0.12)), Vector3(0, 0.008, 0), Palette.NOVA_MAGENTA,
			Vector3(0, 45.0 * float(k), 0), Vector3.ONE, 0.5))
	# dungeon backdrop arc behind the enemies (−Z) + side walls
	var seg_n: int = 13
	for i in seg_n:
		var a: float = deg_to_rad(-96.0 + 192.0 * float(i) / float(seg_n - 1))
		var pos := Vector3(sin(a) * 15.5, 2.6, -cos(a) * 15.5)
		var yaw: float = rad_to_deg(-a)
		var h: float = 7.0 + rng.randf_range(-0.6, 0.6)
		geo.append(_part(MeshUtil.box(Vector3(7.8, h, 0.8)), Vector3(pos.x, h * 0.5 - 0.6, pos.z), Palette.mul(wall_c,
			rng.randf_range(0.85, 1.05)), Vector3(0, yaw, 0)))
		if i % 2 == 0:
			geo.append(_part(MeshUtil.box(Vector3(0.9, 8.0, 1.0)), Vector3(sin(a) * 15.0, 3.4, -cos(a) * 15.0),
				Palette.mul(wall_c, 0.7), Vector3(0, yaw, 0)))
			geo.append(_part(MeshUtil.box(Vector3(0.5, 0.25, 0.3)), Vector3(sin(a) * 14.5, 4.2, -cos(a) * 14.5), Palette.SODIUM,
				Vector3(0, yaw, 0), Vector3.ONE, 1.0))
	# giant show screen
	geo.append(_part(MeshUtil.box(Vector3(9.4, 4.4, 0.5)), Vector3(0, 5.6, -14.2), Palette.INK))
	geo.append(_part(MeshUtil.box(Vector3(9.6, 0.15, 0.6)), Vector3(0, 3.4, -14.15), accent, Vector3.ZERO, Vector3.ONE,
		1.0))
	# light towers with lamp heads
	for sx: float in [-1.0, 1.0]:
		for z: float in [-5.0, 5.5]:
			var base := Vector3(11.0 * sx, 0, z)
			for k in 4:
				var off := Vector3(0.35 * (1.0 if k % 2 == 0 else -1.0), 0, 0.35 * (1.0 if k < 2 else -1.0))
				geo.append(PropKit.seg(base + off + Vector3(0, -0.3, 0), base + off + Vector3(0, 7.5, 0), 0.06, 0.06,
					Palette.DARK_METAL, 0.0, 1.0))
			for y: float in [1.5, 3.5, 5.5]:
				geo.append(_part(MeshUtil.box(Vector3(0.8, 0.06, 0.8)), base + Vector3(0, y, 0), Palette.DARK_METAL))
			geo.append(_part(MeshUtil.box(Vector3(0.6, 0.4, 0.5)), base + Vector3(-0.4 * sx, 7.3, 0), Palette.INK,
				Vector3(0, 0, 25 * sx)))
			geo.append(_part(MeshUtil.cylinder(0.18, 0.18, 0.05), base + Vector3(-0.62 * sx, 7.2, 0),
				Palette.NOVA_MAGENTA if sx < 0.0 else Palette.NOVA_CYAN, Vector3(0, 0, 90 + 25 * sx), Vector3.ONE, 1.2))
	# dungeon litter around the stage
	for k in 10:
		var a2: float = rng.randf_range(0.0, TAU)
		var d2: float = rng.randf_range(10.5, 13.5)
		var id: String = ["crate", "barrel", "crate", "pipe"][k % 4]
		var r: Dictionary = PropKit.recipe(id, seed + k, palette)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), Vector3(cos(a2) * d2, -0.3, sin(a2) * d2))
		for p: Variant in (r["parts"] as Array):
			var q: Dictionary = (p as Dictionary).duplicate()
			q["xform"] = xf * ((p as Dictionary)["xform"] as Transform3D)
			geo.append(q)
	var mat: ShaderMaterial = Materials.env({"shade": pal["shade"], "grout": pal["grout"], "tile_size": 2.0, "dirt": 0.2})
	root.add_child(_mesh_node("Geometry", geo, mat))
	# hologram screen content
	var screen := QuadMesh.new()
	screen.size = Vector2(9.0, 4.0)
	var holo := MeshInstance3D.new()
	holo.name = "ShowScreen"
	holo.mesh = screen
	holo.position = Vector3(0, 5.6, -13.9)
	holo.material_override = Materials.hologram(accent if is_boss else Palette.NOVA_MAGENTA, 0.35, 1.2)
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(holo)
	root.add_child(_label("BOSSKAMPF" if is_boss else "DUNGEON PRIME TIME", 150, Palette.PAPER,
		Palette.DANGER if is_boss else Palette.NOVA_MAGENTA,
		Transform3D(Basis.IDENTITY, Vector3(0, 6.3, -13.85)), 0.012))
	# Title and LIVE bug both sit above 4.6 m: the low command shots crop the back wall there, right under the HUD
	# band, so no text is cut in half behind the hype meter (M5 CR 3); wide shots (frame top ~7.2 m) show both.
	root.add_child(_label("LIVE", 110, Palette.PAPER, Palette.LIVE_RED,
		Transform3D(Basis.IDENTITY, Vector3(-3.4, 5.1, -13.85)), 0.01))
	# drones + sponsor billboard (PropKit nodes, animated)
	var d1: Node3D = PropKit.build(&"camera_drone", seed)
	d1.position = Vector3(-6.0, 4.2, 4.5)
	d1.rotation.y = atan2(6.0, -4.5) + PI
	root.add_child(d1)
	var d2n: Node3D = PropKit.build(&"camera_drone", seed + 1)
	d2n.position = Vector3(6.5, 3.4, -2.5)
	d2n.rotation.y = atan2(-6.5, 2.5) + PI
	root.add_child(d2n)
	_face_center(d1)
	_face_center(d2n)
	var bb_pal: Dictionary = {"accent": Palette.NOVA_CYAN.to_html(), "label": str(palette.get("label", "NOVA SYNDIKAT"))}
	var bb: Node3D = PropKit.build(&"billboard", seed, bb_pal)
	bb.position = Vector3(-9.0, -0.3, -9.0)
	root.add_child(bb)
	_face_center(bb)
	# show lighting (no sun: EnvKit.make_sun)
	root.add_child(_omni("FillLight", Vector3(0, 6.0, 6.0), pal["light"], 1.0, 20.0))
	root.add_child(_omni("BackLight", Vector3(0, 4.0, -9.0), accent, 1.6, 14.0))
	if quality == &"high":
		# warm/cool split (review M4): magenta (DANGER for bosses) pools on the enemy zone, cyan on the party zone, so
		# each side stands in its own show light instead of one mixed grey-lavender oval in the middle
		for sx: float in [-1.0, 1.0]:
			var spot := SpotLight3D.new()
			spot.name = "Spot" + ("L" if sx < 0.0 else "R")
			spot.light_color = (Palette.DANGER if is_boss else Palette.NOVA_MAGENTA) if sx < 0.0 else Palette.NOVA_CYAN
			spot.light_energy = 3.0
			spot.spot_range = 14.0
			spot.spot_angle = 22.0
			spot.shadow_enabled = false
			spot.light_specular = 0.0
			root.add_child(spot)
			var from := Vector3(7.0 * sx, 6.0, 2.0)
			var target: Vector3 = ENEMY_ZONE if sx < 0.0 else PARTY_ZONE
			spot.transform = Transform3D.IDENTITY.looking_at(target - from, Vector3.UP).translated(from)
	return root


static func _face_center(n: Node3D) -> void:
	var p: Vector3 = n.position
	var d := Vector3(-p.x, 0, -p.z)
	if d.length_squared() > 0.0001:
		n.rotation.y = atan2(-d.x, -d.z)


# --- safe room (03_ART §6.3) ------------------------------------------------------------------------------------------

## cutaway (galleries/overviews only): no ceiling slab and beams, so the interior reads from above.
static func build_safe(seed: int, quality: StringName, theme: StringName, cutaway: bool = false) -> Node3D:
	var pal: Dictionary = Palette.preset("safe")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("safe") ^ (seed * 2654435761)
	var root := Node3D.new()
	root.name = "SafeRoom"
	var geo: Array = []
	var props: Array = []
	var floor_c: Color = pal["floor"]
	var wall_c: Color = pal["wall"]
	var hw: float = SAFE_W * 0.5
	var hd: float = SAFE_D * 0.5
	geo.append(_part(MeshUtil.box(Vector3(SAFE_W + 1.0, 0.2, SAFE_D + 1.0)), Vector3(0, -0.1, 0), floor_c))
	geo.append(_part(MeshUtil.box(Vector3(SAFE_W + 1.0, SAFE_H, 0.5)), Vector3(0, SAFE_H * 0.5, -hd - 0.25), wall_c))
	for sx: float in [-1.0, 1.0]:
		geo.append(_part(MeshUtil.box(Vector3(0.5, SAFE_H, SAFE_D + 1.0)), Vector3((hw + 0.25) * sx, SAFE_H * 0.5, 0.0),
			wall_c))
	# wainscot, trims, ceiling beams, cut-away front edge
	geo.append(_part(MeshUtil.box(Vector3(SAFE_W, 1.0, 0.06)), Vector3(0, 0.5, -hd + 0.03), Palette.mul(wall_c, 0.72)))
	geo.append(_part(MeshUtil.box(Vector3(SAFE_W, 0.08, 0.1)), Vector3(0, 1.02, -hd + 0.05), Palette.HYPE_GOLD,
		Vector3.ZERO,
		Vector3.ONE, 0.2, 1.0))
	for sx: float in [-1.0, 1.0]:
		geo.append(_part(MeshUtil.box(Vector3(0.06, 1.0, SAFE_D)), Vector3((hw - 0.03) * sx, 0.5, 0),
			Palette.mul(wall_c, 0.72)))
		geo.append(_part(MeshUtil.box(Vector3(0.1, 0.08, SAFE_D)), Vector3((hw - 0.05) * sx, 1.02, 0), Palette.HYPE_GOLD,
			Vector3.ZERO, Vector3.ONE, 0.2, 1.0))
	if not cutaway:
		geo.append(_part(MeshUtil.box(Vector3(SAFE_W + 1.0, 0.2, SAFE_D + 1.0)), Vector3(0, SAFE_H + 0.1, 0),
			Palette.mul(wall_c, 0.5)))
		for bz: float in BEAM_Z:   # no beam over the exit door (its sign would hide behind it)
			geo.append(_part(MeshUtil.box(Vector3(SAFE_W + 1.0, 0.25, 0.3)), Vector3(0, SAFE_H - 0.12, bz),
				Color("#5a3a2a")))
	geo.append(_part(MeshUtil.box(Vector3(SAFE_W + 1.0, 0.25, 0.4)), Vector3(0, 0.0, hd + 0.3), Palette.INK))
	# rug + stripe pattern
	geo.append(_part(MeshUtil.box(Vector3(5.0, 0.02, 3.4)), Vector3(0.6, 0.01, -1.6), Color("#7a3b5a")))
	for k in 3:
		geo.append(_part(MeshUtil.box(Vector3(4.6, 0.022, 0.12)), Vector3(0.6, 0.012, -2.9 + 1.3 * float(k)),
			Palette.HYPE_GOLD,
			Vector3.ZERO, Vector3.ONE, 0.15))
	# lootbox shelf with three boxes (bronze / silver / gold)
	var shelf := Vector3(4.55, 0, -4.55)
	props.append(_part(MeshUtil.box(Vector3(1.6, 1.2, 0.4)), shelf + Vector3(0, 0.6, 0), Color("#5a4a3e")))
	props.append(_part(MeshUtil.box(Vector3(1.6, 0.05, 0.42)), shelf + Vector3(0, 0.62, 0),
		Palette.mul(Color("#5a4a3e"), 0.75)))
	var box_cols: Array[Color] = [Palette.box_color("box_bronze"), Palette.box_color("box_silver"),
		Palette.box_color("box_gold")]
	for k in 3:
		props.append(_part(MeshUtil.box(Vector3(0.36, 0.3, 0.3)), shelf + Vector3(-0.5 + 0.5 * float(k), 1.36, 0.0),
			box_cols[k],
			Vector3(0, rng.randf_range(-12.0, 12.0), 0), Vector3.ONE, 0.25, 1.0))
	# TV wall (screen = own mesh, M6 tints it with flash_color via instance uniform)
	var tv := Vector3(0.6, 2.25, -hd + 0.08)
	props.append(_part(MeshUtil.box(Vector3(1.3, 0.85, 0.12)), tv, Palette.INK))
	# theme dressing
	match theme:
		&"pumphouse":
			for sx: float in [-1.0, 1.0]:
				var pp := Vector3(-0.6 + 1.5 * sx, 0, -4.3)
				props.append(_part(MeshUtil.cylinder(0.6, 0.6, 1.6), pp + Vector3(0, 0.8, 0), Color("#3e6b4a")))
				props.append(_part(MeshUtil.hemisphere(0.6), pp + Vector3(0, 1.6, 0), Palette.mul(Color("#3e6b4a"), 0.8)))
				props.append(_part(MeshUtil.cylinder(0.14, 0.14, 1.8), pp + Vector3(0, 2.4, 0), Color("#8a4b2a")))
				props.append(_part(MeshUtil.cylinder(0.16, 0.16, 0.04), pp + Vector3(0, 1.1, -0.6), Palette.PAPER,
					Vector3(90, 0, 0),
					Vector3.ONE, 0.6))
				props.append(_part(MeshUtil.box(Vector3(0.015, 0.12, 0.01)), pp + Vector3(0.02, 1.12, -0.63), Palette.LIVE_RED,
					Vector3(0, 0, 35 * sx)))
			props.append(PropKit.seg(Vector3(-hw + 0.3, 3.0, -4.3), Vector3(hw - 0.3, 3.0, -4.3), 0.16, 0.16, Color("#8a4b2a")))
		&"signalbox":
			for k in 8:
				var lp := Vector3(-1.9 + 0.32 * float(k), 0, -4.3)
				props.append(_part(MeshUtil.box(Vector3(0.26, 0.9, 0.5)), lp + Vector3(0, 0.45, 0), Palette.DARK_METAL))
				props.append(PropKit.seg(lp + Vector3(0, 0.9, 0), lp + Vector3(0, 1.5, -0.15 * float(k % 2)), 0.025, 0.025,
					Palette.STEEL, 0.0, 1.0))
				props.append(_part(MeshUtil.sphere(0.06), lp + Vector3(0, 1.52, -0.15 * float(k % 2)),
					Palette.LIVE_RED if k % 3 != 1 else Palette.MANA))
			var plan := QuadMesh.new()
			plan.size = Vector2(2.0, 1.0)
			var holo := MeshInstance3D.new()
			holo.name = "TrackPlan"
			holo.mesh = plan
			holo.position = Vector3(-1.0, 2.3, -hd + 0.12)
			holo.material_override = Materials.hologram(Palette.NOVA_CYAN, 0.45, 1.3)
			holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(holo)
		_:
			# Kiosk 24/7: counter + newspaper stand + snack wall
			var counter := Vector3(-5.2, 0, -1.6)
			props.append(_part(MeshUtil.box(Vector3(0.6, 1.0, 2.4)), counter + Vector3(0, 0.5, 0), Color("#c23b22")))
			props.append(_part(MeshUtil.box(Vector3(0.7, 0.06, 2.5)), counter + Vector3(0, 1.03, 0), Palette.PAPER))
			props.append(_part(MeshUtil.box(Vector3(0.62, 0.12, 2.42)), counter + Vector3(0, 0.75, 0), Palette.HYPE_GOLD,
				Vector3.ZERO,
				Vector3.ONE, 0.3))
			var stand := Vector3(-1.2, 0, -4.4)
			props.append(_part(MeshUtil.box(Vector3(1.2, 1.4, 0.35)), stand + Vector3(0, 0.7, 0), Palette.DARK_METAL))
			for k in 6:
				props.append(_part(MeshUtil.box(Vector3(0.34, 0.42, 0.02)), stand + Vector3(-0.38 + 0.38 * float(k % 3),
					0.95 - 0.5 * float(k / 3), 0.19), [Palette.PAPER, Color("#e8455a"), Palette.NOVA_CYAN][k % 3],
					Vector3(12, 0, 0)))
	var mat: ShaderMaterial = Materials.env({"shade": pal["shade"], "grout": pal["grout"], "tile_size": 1.0, "dirt": 0.08,
		"hatch": 0.0})
	root.add_child(_mesh_node("Geometry", geo, mat))
	root.add_child(_mesh_node("Props", props, Materials.env({"shade": pal["shade"], "grout": pal["grout"],
		"grout_width": 0.0, "dirt": 0.05, "hatch": 0.0}), true))
	var screen := MeshInstance3D.new()
	screen.name = "TVScreen"
	screen.mesh = MeshUtil.box(Vector3(1.15, 0.7, 0.02))
	screen.position = tv + Vector3(0, 0, 0.07)
	screen.material_override = Materials.toon(Color("#2a1a3a"), {"outline": false, "rim": 0.0,
		"emission": Palette.NOVA_MAGENTA})
	screen.set_instance_shader_parameter(&"flash_color", Palette.NOVA_MAGENTA)
	screen.set_instance_shader_parameter(&"flash_amount", 0.3)
	root.add_child(screen)
	# interactive furniture at the anchors
	for pair: Array in [[&"vending_machine", &"vending"], [&"save_terminal", &"terminal"], [&"couch", &"couch"],
			[&"safe_door", &"door"]]:
		var n: Node3D = PropKit.build(pair[0] as StringName, seed, {"label": "AUSGANG"} if pair[0] == &"safe_door" else {})
		n.transform = safe_anchor(pair[1] as StringName)
		root.add_child(n)
	var title := _label({&"pumphouse": "PUMPENHAUS", &"signalbox": "STELLWERK"}.get(theme, "KIOSK 24/7") as String, 64,
		Palette.HYPE_GOLD, Palette.INK, Transform3D(Basis.IDENTITY, Vector3(-3.6, 2.9, -hd + 0.06)), 0.006)
	root.add_child(title)
	root.add_child(_omni("WarmLight", Vector3(0.0, 2.9, -1.2), Color("#ffe2b8"), 1.5, 13.0))
	root.add_child(_omni("LampLight", Vector3(2.2, 2.2, -3.2), Palette.HYPE_GOLD, 0.8, 5.0))
	if quality == &"high":
		root.add_child(_omni("TerminalLight", Vector3(-2.9, 1.8, -3.6), Palette.NOVA_CYAN, 1.0, 4.0))
	# warm hanging lamp over the couch (emissive)
	var lamp: Array = [PropKit.seg(Vector3(2.2, SAFE_H, -3.2), Vector3(2.2, 2.6, -3.2), 0.012, 0.012, Palette.INK),
		_part(MeshUtil.hemisphere(0.3), Vector3(2.2, 2.55, -3.2), Color("#c23b22"), Vector3(180, 0, 0)),
		_part(MeshUtil.sphere(0.1), Vector3(2.2, 2.45, -3.2), Color("#ffd27a"), Vector3.ZERO, Vector3.ONE, 1.5)]
	root.add_child(_mesh_node("Lamp", lamp,
		Materials.env({"shade": pal["shade"], "grout_width": 0.0, "dirt": 0.0, "hatch": 0.0})))
	return root
