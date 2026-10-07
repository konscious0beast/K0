extends RefCounted
## Shared helpers of the art galleries (private, no class_name): environment + light rig, camera, floor, labels.


static func add_world(host: Node3D, theme_id: String, palette: Dictionary, mode: StringName,
		quality: StringName = &"high", fog_scale: float = 1.0) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = EnvKit.make_environment(theme_id, palette, mode, quality)
	we.environment.fog_density *= fog_scale
	host.add_child(we)
	host.add_child(EnvKit.make_zone_sun(theme_id, palette, mode, quality))


static func add_camera(host: Node3D, pos: Vector3, target: Vector3, fov: float = 40.0) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = fov
	cam.far = 400.0
	host.add_child(cam)
	cam.position = pos
	if cam.is_inside_tree():
		cam.look_at(target, Vector3.UP)
	else:
		cam.transform = cam.transform.looking_at(target, Vector3.UP)
	cam.current = true
	return cam


static func label(host: Node3D, text: String, pos: Vector3, size: int = 28, color: Color = Palette.PAPER) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 8
	l.modulate = Palette.sign_color(color)
	l.outline_modulate = Palette.INK
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20            # after holograms / transparent props (labels stay readable)
	l.outline_render_priority = 19
	l.position = pos
	host.add_child(l)
	return l


## Round tiled stage floor with a glowing rim (gallery backdrop).
static func add_floor(host: Node3D, radius: float, palette: Dictionary, theme_id: String = "metro") -> void:
	var pal: Dictionary = Palette.resolve(palette, theme_id)
	var parts: Array[Dictionary] = []
	var disc := MeshUtil.cylinder(radius, radius, 0.2)
	disc.radial_segments = 48
	parts.append(MeshUtil.part(disc, Vector3(0, -0.1, 0), pal["floor"]))
	var rim := MeshUtil.cylinder(radius + 0.15, radius + 0.15, 0.08)
	rim.radial_segments = 48
	parts.append(MeshUtil.part(rim, Vector3(0, -0.06, 0), pal["accent"], Vector3.ZERO, Vector3.ONE, 0.6))
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = MeshUtil.merge_no_hull(parts)
	mi.material_override = Materials.env({"shade": pal["shade"], "grout": pal["grout"], "dirt": 0.15})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
