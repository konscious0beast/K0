class_name EnvKit extends RefCounted
## Rooms, arena, safe room, environment, light (02_TECH §8.5, 03_ART §4/§6). Builders are static, deterministic for a
## given seed and return new nodes outside the tree. Room recipes: art/kit/room_builder.gd, arena + safe room:
## art/kit/set_builder.gd (private helpers).

const RoomBuilder := preload("res://art/kit/room_builder.gd")
const SetBuilder := preload("res://art/kit/set_builder.gd")

const ROOM_SIZE: float = 16.0
const WALL_HEIGHT: float = 3.5
const DOOR_WIDTH: float = 4.0
const WALL_THICKNESS: float = 0.5
const CLEAR_RADIUS: float = 5.0
## Inner wall face distance from the room center (ROOM_SIZE / 2 − WALL_THICKNESS).
const WALL_INNER: float = 7.5
## Node name of the room-name sign (Label3D) in build_safe_room(); screens with their own name header may hide it.
const SAFE_TITLE_SIGN: String = SetBuilder.SAFE_TITLE_SIGN
## Explore key light (03_ART §4.3 lists (−55, 35, 0); amended after review M4: side/back key, see make_zone_sun).
const EXPLORE_SUN_ROTATION := Vector3(-50, -110, 0)


## children: "Geometry" (MeshInstance3D, floor+walls merged, cast_shadow OFF), "Props" (MeshInstance3D merged),
## "Collision" (StaticBody3D layer 1: floor box + wall boxes + large prop boxes), optional "Light" (OmniLight3D:
## y 3.0, range 9, energy 1.2, no shadow, distance_fade 24 m / length 6 m), kind-specific set pieces:
## STAIRS → PropKit stairs_down at anchor stairs; SAFE → PropKit safe_door at anchor safe_door.
static func build_room(spec: RoomSpec) -> Node3D:
	if spec == null:
		push_warning("EnvKit.build_room(null)")
		return Node3D.new()
	return RoomBuilder.new(spec).build()


## Room-local: &"player_spawn", &"stairs", &"boss_spot" (center), &"safe_door" (center of the first wall WITHOUT door in
## order N, E, S, W, 0.6 m in front of it, facing room center; room with 4 doors → center, facing +Z). Facing = local
## −Z.
## &"stairs" is rotated so its well (local −Z) descends toward the first wall without door (art detail, origin =
## center).
static func anchor_for(spec: RoomSpec, anchor: StringName) -> Transform3D:
	match anchor:
		&"player_spawn", &"boss_spot":
			return Transform3D.IDENTITY
		&"stairs":
			# center; the well (local −Z) points at the first wall WITHOUT door (N, E, S, W) so the 3 m door corridors
			# stay free (02_TECH §7.3); 4 doors → facing −Z with the compact well (PropKit.STAIRS_STEPS_COMPACT)
			var sdoors: int = spec.doors if spec != null else 0
			for side: int in RoomBuilder.SIDES:
				if (sdoors & side) == 0:
					return Transform3D(RoomBuilder.toward_wall_basis(side), Vector3.ZERO)
			return Transform3D.IDENTITY
		&"safe_door":
			var doors: int = spec.doors if spec != null else 0
			for side: int in RoomBuilder.SIDES:
				if (doors & side) == 0:
					return RoomBuilder.edge_xf(side, 0.0, 0.0, 0.6)
			return Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	push_warning("EnvKit.anchor_for: unknown anchor '%s'" % anchor)
	return Transform3D.IDENTITY


## round stage r = 9 m at origin, backdrop, 2 camera drones, sponsor billboard; no sun (see make_sun)
static func build_battle_arena(theme_id: String, palette: Dictionary, is_boss: bool, seed: int,
		quality: StringName = &"high") -> Node3D:
	return SetBuilder.build_arena(theme_id, palette, is_boss, seed, quality)


## interior 12 × 10 m at origin, incl. vending_machine, save_terminal, couch, door, warm OmniLight;
## theme &"kiosk" | &"pumphouse" | &"signalbox" swaps set dressing (03_ART §6.3), anchors identical for all themes
static func build_safe_room(seed: int, quality: StringName = &"high", theme: StringName = &"kiosk") -> Node3D:
	return SetBuilder.build_safe(seed, quality, theme)


## Local transforms inside build_safe_room(): &"vending", &"terminal", &"couch", &"mopsula_spot", &"player_spot",
## &"door",
## &"camera" (camera transform looking into the room, FOV 50, 03_ART §8.1). Facing = local −Z.
static func safe_room_anchor(anchor: StringName) -> Transform3D:
	return SetBuilder.safe_anchor(anchor)


## mode &"explore" | &"battle" | &"safe"
static func make_environment(theme_id: String, palette: Dictionary, mode: StringName,
		quality: StringName = &"high") -> Environment:
	var pal: Dictionary = Palette.resolve(palette, theme_id)
	if mode == &"safe" and palette.is_empty():
		pal = Palette.preset("safe")
	var env := Environment.new()
	var fog_c: Color = pal["fog"]
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.mul(fog_c, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = pal["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var energy: float = 0.8
	var density: float = 0.03
	var exposure: float = 1.0
	var glow: float = 0.8
	match mode:
		&"battle":
			energy = 0.9
			density = 0.02
			exposure = 1.05
			glow = 1.0
		&"safe":
			energy = 1.1
			density = 0.0
			exposure = 1.1
			glow = 0.6
	var style: StringName = Palette.zone_style(palette, theme_id)
	if mode == &"explore" and style == &"sewer":
		density = 0.05
		env.fog_height = 0.4
		env.fog_height_density = 0.6
	env.ambient_light_energy = energy
	env.tonemap_exposure = exposure
	env.fog_enabled = density > 0.0
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = density
	env.fog_light_color = fog_c
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = quality == &"high"
	if env.glow_enabled:
		for i in 7:
			env.set_glow_level(i, 0.0)
		env.set_glow_level(1, 1.0)
		env.set_glow_level(2, 1.0)
		env.set_glow_level(3, 0.6)
		env.glow_intensity = glow
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	return env


## shadows only on high; directional_shadow_mode ORTHOGONAL on mobile else PSSM 2 splits;
## directional_shadow_max_distance 30 (explore) / 20 (battle). Theme key color (see make_zone_sun for zone moods).
static func make_sun(theme_id: String, mode: StringName, quality: StringName = &"high") -> DirectionalLight3D:
	return make_zone_sun(theme_id, {}, mode, quality)


## Art extra (pending API change request: optional `palette` on make_sun): like make_sun, but the key color comes from
## the zone palette and the explore energy from the zone style (03_ART §4.3: sewer 0.7, cellar 0.9, else 1.1).
## Explore key = side/back light (review M4): it no longer shines along the follow camera's view (pitch −38°, looking
## −Z), so the toon bands model the figures and their shadows fall sideways onto the floor in view.
static func make_zone_sun(theme_id: String, palette: Dictionary, mode: StringName,
		quality: StringName = &"high") -> DirectionalLight3D:
	var pal: Dictionary = Palette.resolve(palette, theme_id) if not palette.is_empty() else Palette.theme_palette(theme_id)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	var key: Color = pal["key"]
	var energy: float = 1.1
	if not palette.is_empty():
		match Palette.zone_style(palette, theme_id):
			&"sewer":
				energy = 0.7
			&"cellar":
				energy = 0.9
	var rot := EXPLORE_SUN_ROTATION
	var max_dist: float = 30.0
	match mode:
		&"battle":
			energy = 1.25
			rot = Vector3(-50, -30, 0)
			max_dist = 20.0
		&"safe":
			key = Color("#ffe2b8")
			energy = 1.2
			rot = Vector3(-60, 20, 0)
			max_dist = 15.0
	sun.light_color = key
	sun.light_energy = energy
	sun.rotation_degrees = rot
	sun.light_specular = 0.0
	sun.shadow_enabled = quality == &"high"
	if sun.shadow_enabled:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if OS.has_feature("mobile") \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = max_dist
		sun.shadow_bias = 0.03
		sun.shadow_normal_bias = 1.0
	return sun
