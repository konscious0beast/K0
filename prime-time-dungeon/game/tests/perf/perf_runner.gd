extends Node
## Performance probe runner (02_TECH §12.1/§12.5, docs/PERFORMANCE.md). Loaded by perf_probe.gd after the first frame,
## so autoloads and class_names are available. Sections (all by default, `--only=` picks some):
##   startup    boot scene → interactive title (incl. the fixed 2 s card + fades), DB load, floor build cold/warm, arena
##              and safe-room build times (§12.1 "Aufbauzeit")
##   explore    every cell of floor 1 from 4 camera yaws → per zone the worst view, the worst room with enemies
##   battle     every floor-1 encounter (opening shots) → the largest one and both bosses as full auto battles
##   safe_room  the three safe rooms of floor 1
##   leak       N cycles explore (rebuild) → battle → safe room through the Router, object/memory counts per cycle
## Render metrics need a display (Xvfb); headless runs print "–" for them. Prints Markdown tables and a final
## "PERF: OK" / "PERF: OVER BUDGET (<n>)" line (+ "LEAK: OK" / "LEAK: GROWTH …"); exit code 1 on budget/leak failures.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const VfxNodeScript := preload("res://art/kit/vfx_node.gd")
const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"
const FLOOR_SEED: int = 4242
const YAWS: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
const OMNI_RADIUS: float = 24.0
const MB: float = 1048576.0
const SETTLE_FRAMES: int = 3
const ROOM_SAMPLES: int = 2
const BATTLE_OPENING_SKIP: int = 20
const BATTLE_OPENING_SAMPLES: int = 10
const BATTLE_MAX_FRAMES: int = 2400
const SAFE_ROOM_SAMPLES: int = 30
const BOSS_LEVEL: int = 7                     # GDD §13: Königin with Lv 7, Hausmeister with Lv 5
const FULL_LEVEL: int = 4                     # full non-boss battle: d-zone level, so the fight lasts a few turns
const LEAK_ENCOUNTER: String = "enc_f1_a1_tutorial"
const LEAK_WARMUP: int = 2                    # cycles before the baseline (caches, pools, lazy streams)
const LEAK_WINDOW: int = 5                    # baseline = min over cycles WARMUP..WARMUP+4, end = min over the last 5
const LEAK_OBJECT_SLACK: int = 16             # tolerated object drift of the minima (transient tweens/timers)

## 02_TECH §12.1 (keys: explore / battle / safe_room).
const BUDGET_DC3D: Dictionary = {"explore": 150, "battle": 150, "safe_room": 120}
## UI canvas draw calls (02_TECH §12.1 "DC 2D"): canvas items only batch while texture and command type stay the same
## (measured 4.7.2: every StyleBoxFlat 1 DC, an outlined label 2, a polygon 1) → own ceiling next to the 3D budget.
const BUDGET_DC2D: Dictionary = {"explore": 100, "battle": 180, "safe_room": 100}
const BUDGET_PRIMS: Dictionary = {"explore": 120000, "battle": 120000, "safe_room": 60000}
const BUDGET_OMNI: Dictionary = {"explore": 4, "battle": 2, "safe_room": 3}
const BUDGET_SPOT: Dictionary = {"explore": 0, "battle": 2, "safe_room": 0}     # 03_ART §5: 2 show spots, high only
const BUDGET_OMNI_LOW_EXPLORE: int = 2
## Accent omni lights on top of the budget, quality high only, at most one at a time (02_TECH §12.1): the neon signal
## of a stairs / safe-room cell (03_ART §5) and the train's head lamp while it passes (Königin, ~1 s).
const ACCENT_LIGHTS: Array[StringName] = [&"Neon", &"HeadLamp"]
const BUDGET_LIGHTS_PER_MESH: int = 3
## Battle on quality high: the arena geometry mesh sits in Fill + Back + both show spots (03_ART §5, high only) → 4;
## every figure ≤ 3. Quality low (mobile default) has no spots → ≤ 2 (02_TECH §12.1).
const BUDGET_LIGHTS_PER_MESH_BATTLE_HIGH: int = 4
const BUDGET_MATS: Dictionary = {"explore": 24, "battle": 24, "safe_room": 16}
const MATS_FRAME_LIMIT: int = 24              # frames above this count are reported with a material overrun
const BUDGET_LABEL3D: int = 12
const BUDGET_PARTICLES: int = 400
const BUDGET_EMITTERS: int = 6
const BUDGET_BODIES: int = 40
const BUDGET_RAM_MB: float = 400.0
const BUDGET_BUILD_MS: Dictionary = {"explore": 500.0, "battle": 300.0, "safe_room": 300.0}

var engine_init_ms: int = 0                   # set by perf_probe.gd (process start → this probe's main loop)

var _only: PackedStringArray = []
var _quality: StringName = &"high"
var _cycles: int = 20
var _out_path: String = ""
var _shots_dir: String = ""                   # --shots=<abs dir>: PNG of each row's frame with the most draw calls
var _cells_table: bool = false                # --cells: one line per exploration cell
var _boot_line: String = ""                   # --boot=<BOOT: … line of boot_timer.gd>
var _leak_diff: bool = false                  # --leak-diff: print which node kinds changed between leak cycles
var _mat_dump: bool = false                   # --mat-dump: print the unique materials of each row's peak frame
var _mat_owners: Dictionary = {}              # material instance id → "shader/class @ first owner" (last _audit)
var _mat_keys: Dictionary = {}                # material instance id → Materials cache key (--mat-dump)
var _full_only: PackedStringArray = []        # --full=<enc ids>: battle section runs only these full auto battles
var _rendered: bool = false
var _lines: PackedStringArray = []
var _over: PackedStringArray = []
var _leak_fail: PackedStringArray = []
var _explore: ExplorationScene = null
var _build_rows: Array[Dictionary] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.trim_prefix("--only=").split(",", false)
		elif a.begins_with("--quality="):
			_quality = StringName(a.trim_prefix("--quality="))
		elif a.begins_with("--cycles="):
			_cycles = maxi(LEAK_WARMUP + 1, a.trim_prefix("--cycles=").to_int())
		elif a.begins_with("--out="):
			_out_path = a.trim_prefix("--out=")
		elif a.begins_with("--shots="):
			_shots_dir = a.trim_prefix("--shots=")
		elif a == "--cells":
			_cells_table = true
		elif a == "--leak-diff":
			_leak_diff = true
		elif a == "--mat-dump":
			_mat_dump = true
		elif a.begins_with("--full="):
			_full_only = a.trim_prefix("--full=").split(",", false)
		elif a.begins_with("--boot="):
			_boot_line = a.trim_prefix("--boot=")
	_rendered = DisplayServer.get_name() != "headless"
	_run.call_deferred()


## gl_compatibility (opengl3) or mobile (vulkan): the driver decides (--rendering-driver opengl3 switches the method).
static func _renderer_name() -> String:
	var drv: String = RenderingServer.get_current_rendering_driver_name()
	return "gl_compatibility" if drv.begins_with("opengl") else str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "mobile"))


func _wants(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


func _run() -> void:
	Game.ephemeral = true
	Save.read_only = true
	if Game.settings != null:
		Game.settings.ephemeral = true
		Game.settings.quality = _quality
	_emit("# Perf-Probe — Renderer %s, Treiber %s, Qualität %s, %s, Godot %s" % [
		_renderer_name() if _rendered else "Dummy",
		RenderingServer.get_current_rendering_driver_name() if _rendered else "headless", _quality,
		"%dx%d" % [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
			if _rendered else "headless",
		Engine.get_version_info().get("string", "?")])
	_emit("GPU: %s" % RenderingServer.get_video_adapter_name() if _rendered else "GPU: – (headless)")
	await _section_startup()
	if _wants("explore"):
		await _section_explore()
	if _wants("battle"):
		await _section_battle()
	if _wants("safe_room"):
		await _section_safe_room()
	if _wants("startup"):
		_print_build_table()
	if _wants("leak"):
		await _section_leak()
	_emit("")
	if _over.is_empty():
		_emit("PERF: OK")
	else:
		_emit("PERF: OVER BUDGET (%d): %s" % [_over.size(), "; ".join(_over)])
	if _wants("leak"):
		_emit("LEAK: OK" if _leak_fail.is_empty() else "LEAK: GROWTH " + "; ".join(_leak_fail))
	if _out_path != "":
		var f: FileAccess = FileAccess.open(_out_path, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_lines) + "\n")
			f.close()
	# Leave the screens before quitting (clean exit, no leaked instances).
	await _free_screens()
	get_tree().quit(0 if _over.is_empty() and _leak_fail.is_empty() else 1)


func _emit(line: String) -> void:
	_lines.append(line)
	print(line)


# ======================================================================================================================
# Startup and build times
# ======================================================================================================================

## Boots like the main scene (adds GlobalUi, routes to the title) so later sections see the real UI. Timings of the
## real boot come from tests/perf/boot_timer.gd (perf.sh passes its BOOT line as --boot=…): this runner itself
## compiles every screen class up front, so its own boot would be faster than a real one.
func _section_startup() -> void:
	var root: Window = get_tree().root
	var boot: Node = (load(BOOT_SCENE) as PackedScene).instantiate()
	root.add_child(boot)
	get_tree().current_scene = boot
	var guard: int = 0
	while guard < 3000 and not (Router.current is TitleScreen and not Router.busy):
		await get_tree().process_frame
		guard += 1
	var t_data: int = Time.get_ticks_usec()
	var data: GameData = GameData.new()
	var data_ok: bool = data.load_dir("res://data")
	var data_ms: float = (Time.get_ticks_usec() - t_data) / 1000.0
	if not _wants("startup"):
		return
	_emit("")
	_emit("## Start (echter Boot über tests/perf/boot_timer.gd, Zeiten ab Prozessstart)")
	_emit("")
	_emit("| Messpunkt | Zeit |")
	_emit("|---|---:|")
	var bt: Dictionary = _boot_values()
	if bt.is_empty():
		_emit("| (kein BOOT-Wert übergeben — tools/perf.sh ruft boot_timer.gd auf) | – |")
	else:
		var ms: Callable = func(k: String) -> String: return "%d ms" % int(bt[k]) if int(bt.get(k, -1)) >= 0 else "–"
		_emit("| Engine + Autoload-`_init` (Skripte kompiliert, DB geladen) → Hauptschleife | %s |" % ms.call("init_ms"))
		_emit("| Boot-Szene geladen und `_ready` (GlobalUi, Logo-Karte, Shader-Prewarm) | %s |" % ms.call("boot_ready_ms"))
		_emit("| erstes Bild | %s |" % ms.call("first_frame_ms"))
		_emit("| Titel interaktiv (inkl. fester 2,0 s Logo-Karte + 0,5 s Blende) | %s |" % ms.call("title_ms"))
		_emit("| davon variabel (ohne die festen 2,5 s) | %d ms |" % maxi(0, int(bt.get("title_ms", 0)) - 2500))
		_emit("| Titel → „Neues Spiel“ → Erkundung interaktiv (0,5 s Blende, erstes Kompilieren der Erkundung, Bau) | %s |"
			% ms.call("explore_cost_ms"))
	_emit("| DB erneut laden (`GameData.load_dir`, warm, %s) | %.0f ms |" % ["ok" if data_ok else "FEHLER", data_ms])


func _boot_values() -> Dictionary:
	var out: Dictionary = {}
	if _boot_line == "":
		return out
	for part: String in _boot_line.trim_prefix("BOOT:").strip_edges().split(" ", false):
		var kv: PackedStringArray = part.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1].to_int()
	return out


func _print_build_table() -> void:
	if _build_rows.is_empty():
		return
	_emit("")
	_emit("## Aufbauzeiten (§12.1)")
	_emit("")
	_emit("| Aufbau | kalt | warm | Budget PC | Status |")
	_emit("|---|---:|---:|---:|---|")
	for r: Dictionary in _build_rows:
		var budget: float = float(r["budget"])
		var warm: float = float(r["warm"])
		var ok: bool = budget <= 0.0 or warm <= budget
		_emit("| %s | %.0f ms | %.0f ms | %s | %s |" % [r["name"], float(r["cold"]), warm,
			"%.0f ms" % budget if budget > 0.0 else "–", "OK" if ok else "ÜBER"])
		if not ok:
			_over.append("build %s %.0f ms > %.0f ms" % [r["name"], warm, budget])


func _add_build(build_name: String, cold_ms: float, warm_ms: float, budget_ms: float) -> void:
	_build_rows.append({"name": build_name, "cold": cold_ms, "warm": warm_ms, "budget": budget_ms})


## Builds the exploration screen directly (timed _ready = layout + world + actors + HUD) and adopts it.
func _build_exploration() -> float:
	var root: Window = get_tree().root
	var old: Node = Router.current
	if old != null and is_instance_valid(old):
		old.queue_free()
	if _explore != null and is_instance_valid(_explore):
		_explore.queue_free()
	await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	var node: ExplorationScene = (load(Router.SCENE_EXPLORATION) as PackedScene).instantiate() as ExplorationScene
	node.setup({"spawn": &"start"})
	root.add_child(node)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	get_tree().current_scene = node
	Router.adopt(node)
	_explore = node
	return ms


func _ensure_exploration() -> void:
	if _explore != null and is_instance_valid(_explore) and _explore.is_inside_tree():
		return
	Game.new_game(0, "Kai", FLOOR_SEED)
	var cold: float = await _build_exploration()
	var warm: float = await _build_exploration()
	var t_gen: int = Time.get_ticks_usec()
	var layout: FloorLayout = DungeonGenerator.generate(Game.floor_def(), Game.state.floor_run.seed)
	var gen1_ms: float = (Time.get_ticks_usec() - t_gen) / 1000.0
	var gen2_ms: float = -1.0
	var f2: FloorDef = DB.floor_def(2)
	if f2 != null:
		var t2: int = Time.get_ticks_usec()
		DungeonGenerator.generate(f2, 777)
		gen2_ms = (Time.get_ticks_usec() - t2) / 1000.0
	_add_build("Etage 1 (Layout + Räume + Akteure + HUD, `ExplorationScene._ready`)", cold, warm,
		float(BUDGET_BUILD_MS["explore"]))
	_add_build("davon Layout Etage 1 (`DungeonGenerator.generate`, feste Daten, %d Zellen)" % (
		layout.cells.size() if layout != null else 0), gen1_ms, gen1_ms, 0.0)
	if gen2_ms >= 0.0:
		_add_build("Layout Etage 2 (prozedural, Seed 777)", gen2_ms, gen2_ms, 0.0)
	_explore.auto_start_battle = false


# ======================================================================================================================
# Sampling
# ======================================================================================================================

func _new_acc() -> Dictionary:
	return {"n": 0, "dc": 0, "dc_sum": 0, "prims": 0, "objs": 0, "dc3d": 0, "dcsh": 0, "dccv": 0, "omni": 0,
		"omni_near": 0, "neon": 0, "omni_room": 0, "spot": 0, "lpm": 0, "dirl": 0, "shadow": 0, "mats": 0, "l3d": 0,
		"emit": 0, "parts": 0, "static": 0, "kinematic": 0, "areas": 0, "rigid": 0, "meshes": 0, "ram": 0.0, "vram": 0.0,
		"nodes": 0, "objects": 0, "mats_over": 0}


## Waits `frames` drawn frames and folds the monitors + scene audit of each into `acc` (max; dc also summed).
func _sample(frames: int, acc: Dictionary) -> void:
	for i in frames:
		if _rendered:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		_take(acc)


func _take(acc: Dictionary) -> void:
	acc["n"] = int(acc["n"]) + 1
	var vp: RID = get_viewport().get_viewport_rid()
	var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	acc["dc_sum"] = int(acc["dc_sum"]) + dc
	var vals: Dictionary = {
		"dc": dc,
		"prims": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objs": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"dc3d": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"dcsh": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"dccv": RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
	}
	if _rendered and _shots_dir != "" and dc > int(acc["dc"]):
		acc["shot"] = get_viewport().get_texture().get_image()
	var audit: Dictionary = _audit()
	if int(audit["mats"]) > MATS_FRAME_LIMIT:
		acc["mats_over"] = int(acc["mats_over"]) + 1
	if _mat_dump and int(audit["mats"]) > int(acc["mats"]):
		acc["mat_list"] = _mat_owners.values()
	for k: String in audit.keys():
		vals[k] = audit[k]
	for k: String in vals.keys():
		acc[k] = maxi(int(acc[k]), int(vals[k]))
	acc["ram"] = maxf(float(acc["ram"]), Performance.get_monitor(Performance.MEMORY_STATIC) / MB)
	acc["vram"] = maxf(float(acc["vram"]), Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB)


## Scene audit of the main viewport (SubViewports are skipped): active omni/spot lights within 24 m of the camera,
## lights per mesh (light_cull_mask vs layers, omni as sphere, spot as cone), unique materials, Label3D, particles,
## physics bodies (static / kinematic+rigid / areas).
func _audit() -> Dictionary:
	var out: Dictionary = {"omni": 0, "omni_near": 0, "neon": 0, "spot": 0, "lpm": 0, "dirl": 0, "shadow": 0, "mats": 0,
		"l3d": 0, "emit": 0,
		"parts": 0, "static": 0, "kinematic": 0, "areas": 0, "rigid": 0, "meshes": 0}
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var planes: Array[Plane] = cam.get_frustum() if cam != null else ([] as Array[Plane])
	var mats: Dictionary = {}
	_mat_owners.clear()
	if _mat_dump:
		_mat_keys.clear()
		for key: Variant in Materials._cache.keys():
			_mat_keys[(Materials._cache[key] as Material).get_instance_id()] = str(key)
	var lights: Array[Light3D] = []             # active omni/spot lights (not faded out)
	var geos: Array[GeometryInstance3D] = []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is SubViewport:
			continue
		for c: Node in n.get_children():
			stack.append(c)
		if n is Light3D:
			var l: Light3D = n as Light3D
			if not l.is_visible_in_tree() or l.light_energy <= 0.0:
				continue
			if l.shadow_enabled:
				out["shadow"] = int(out["shadow"]) + 1
			if l is DirectionalLight3D:
				out["dirl"] = int(out["dirl"]) + 1
				continue
			var d: float = l.global_position.distance_to(cam_pos)
			if l.distance_fade_enabled and d >= l.distance_fade_begin + l.distance_fade_length:
				continue
			lights.append(l)
			# "aktiv" (§12.1): within 24 m AND its range sphere reaches the view frustum — lights outside the frustum
			# are culled by the renderer and cost nothing that frame. "omni_near" counts every one within 24 m.
			if d <= OMNI_RADIUS:
				var key: String = "omni" if l is OmniLight3D else "spot"
				if l is OmniLight3D:
					out["omni_near"] = int(out["omni_near"]) + 1
				var rng: float = (l as OmniLight3D).omni_range if l is OmniLight3D else (l as SpotLight3D).spot_range
				if planes.is_empty() or _sphere_in_frustum(l.global_position, rng, planes):
					out[key] = int(out[key]) + 1
					if l is OmniLight3D and ACCENT_LIGHTS.has(l.name):
						out["neon"] = int(out["neon"]) + 1
		elif n is GeometryInstance3D:
			var g: GeometryInstance3D = n as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			out["meshes"] = int(out["meshes"]) + 1
			geos.append(g)
			_collect_materials(g, mats)
			if g is Label3D:
				out["l3d"] = int(out["l3d"]) + 1
			elif g is CPUParticles3D and (g as CPUParticles3D).emitting:
				out["emit"] = int(out["emit"]) + 1
				out["parts"] = int(out["parts"]) + (g as CPUParticles3D).amount
		elif n is CollisionObject3D:
			var key2: String = "areas"
			if n is StaticBody3D:
				key2 = "static"
			elif n is RigidBody3D:
				key2 = "rigid"
			elif n is PhysicsBody3D:
				key2 = "kinematic"
			out[key2] = int(out[key2]) + 1
	out["mats"] = mats.size()
	out["omni_room"] = int(out["omni"]) - int(out["neon"])
	var lpm: int = 0
	for g: GeometryInstance3D in geos:
		if g is Label3D or g is CPUParticles3D or g is Sprite3D:
			continue
		var box: AABB = g.global_transform * g.get_aabb()
		var k: int = 0
		for l: Light3D in lights:
			if (l.light_cull_mask & g.layers) != 0 and _lights_box(l, box):
				k += 1
		lpm = maxi(lpm, k)
	out["lpm"] = lpm
	return out


## Conservative sphere-vs-frustum test (Camera3D.get_frustum() planes point outwards).
static func _sphere_in_frustum(center: Vector3, radius: float, planes: Array[Plane]) -> bool:
	for p: Plane in planes:
		if p.distance_to(center) > radius:
			return false
	return true


## Omni: sphere (position, range) touches the box. Spot: some box sample point (closest point, centre, corners) lies
## inside the cone (range, angle).
static func _lights_box(l: Light3D, box: AABB) -> bool:
	var p: Vector3 = l.global_position
	if l is OmniLight3D:
		return p.distance_to(p.clamp(box.position, box.end)) <= (l as OmniLight3D).omni_range
	var sp: SpotLight3D = l as SpotLight3D
	var axis: Vector3 = -l.global_transform.basis.z.normalized()
	var cos_a: float = cos(deg_to_rad(sp.spot_angle))
	var pts: Array[Vector3] = [p.clamp(box.position, box.end), box.get_center()]
	for i in 8:
		pts.append(box.get_endpoint(i))
	for q: Vector3 in pts:
		var v: Vector3 = q - p
		var dist: float = v.length()
		if dist <= sp.spot_range and (dist < 0.001 or v.dot(axis) / dist >= cos_a):
			return true
	return false


func _collect_materials(g: GeometryInstance3D, mats: Dictionary) -> void:
	var list: Array[Material] = []
	if g.material_override != null:
		list.append(g.material_override)
	else:
		var mesh: Mesh = null
		if g is MeshInstance3D:
			mesh = (g as MeshInstance3D).mesh
			if mesh != null:
				for s in mesh.get_surface_count():
					var m: Material = (g as MeshInstance3D).get_active_material(s)
					if m != null:
						list.append(m)
				mesh = null
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
			mesh = (g as MultiMeshInstance3D).multimesh.mesh
		elif g is CPUParticles3D:
			mesh = (g as CPUParticles3D).mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var m2: Material = mesh.surface_get_material(s)
				if m2 != null:
					list.append(m2)
	if g.material_overlay != null:
		list.append(g.material_overlay)
	for m3: Material in list:
		var cur: Material = m3
		var guard: int = 0
		while cur != null and guard < 8:
			mats[cur.get_instance_id()] = true
			if _mat_dump and not _mat_owners.has(cur.get_instance_id()):
				var sh: Shader = (cur as ShaderMaterial).shader if cur is ShaderMaterial else null
				_mat_owners[cur.get_instance_id()] = "%s @ %s [%s]" % [sh.resource_path.get_file() if sh != null else
					cur.get_class(), str(get_tree().root.get_path_to(g)).right(70),
					_mat_keys.get(cur.get_instance_id(), "not cached")]
			cur = cur.next_pass
			guard += 1


# ======================================================================================================================
# Tables
# ======================================================================================================================

func _table_head(title: String) -> void:
	_emit("")
	_emit("## " + title)
	_emit("")
	_emit("| Ansicht | DC gesamt max (Ø) | DC 3D + Schatten | DC 2D (UI) | Primitive max | Omni aktiv (≤ 24 m) / Spot | " +
		"Lichter/Mesh | Materialien | Label3D | Partikel (Emitter) | Bodies stat./kin. (Areas) | Nodes | RAM MB | " +
		"VRAM MB | Status |")
	_emit("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|")


func _row(view: String, ctx: String, acc: Dictionary) -> void:
	var issues: PackedStringArray = _check(ctx, acc)
	if acc.get("shot") is Image:
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		var file: String = "%s_%s.png" % [ctx, view.validate_filename().replace(" ", "_").left(48)]
		(acc["shot"] as Image).save_png(_shots_dir.path_join(file))
	var n: int = maxi(1, int(acc["n"]))
	var dc_txt: String = "–"
	var d3_txt: String = "–"
	var d2_txt: String = "–"
	var prim_txt: String = "–"
	if _rendered:
		dc_txt = "%d (%d)" % [int(acc["dc"]), roundi(float(acc["dc_sum"]) / float(n))]
		d3_txt = "%d + %d" % [int(acc["dc3d"]), int(acc["dcsh"])]
		d2_txt = str(int(acc["dccv"]))
		prim_txt = _fmt_int(int(acc["prims"]))
	_emit("| %s | %s | %s | %s | %s | %d (%d) / %d | %d | %d | %d | %d (%d) | %d / %d (%d) | %d | %.0f | %.0f | %s |" % [
		view, dc_txt, d3_txt, d2_txt, prim_txt, int(acc["omni"]), int(acc["omni_near"]), int(acc["spot"]), int(acc["lpm"]),
		int(acc["mats"]),
		int(acc["l3d"]), int(acc["parts"]), int(acc["emit"]), int(acc["static"]), int(acc["kinematic"]) +
		int(acc["rigid"]), int(acc["areas"]), int(acc["nodes"]), float(acc["ram"]), float(acc["vram"]),
		"OK" if issues.is_empty() else "ÜBER: " + ", ".join(issues)])
	for s: String in issues:
		_over.append("%s/%s: %s" % [ctx, view, s])
	if _mat_dump and acc.get("mat_list") is Array:
		for desc: Variant in acc["mat_list"]:
			print("MATDUMP %s/%s: %s" % [ctx, view, str(desc)])


func _check(ctx: String, acc: Dictionary) -> PackedStringArray:
	var issues: PackedStringArray = []
	if _rendered:
		var d3: int = int(acc["dc3d"]) + int(acc["dcsh"])
		if d3 > int(BUDGET_DC3D[ctx]):
			issues.append("DC 3D %d > %d" % [d3, int(BUDGET_DC3D[ctx])])
		if int(acc["dccv"]) > int(BUDGET_DC2D[ctx]):
			issues.append("DC 2D %d > %d" % [int(acc["dccv"]), int(BUDGET_DC2D[ctx])])
		if int(acc["prims"]) > int(BUDGET_PRIMS[ctx]):
			issues.append("Prims %d > %d" % [int(acc["prims"]), int(BUDGET_PRIMS[ctx])])
	var omni_budget: int = int(BUDGET_OMNI[ctx])
	if ctx == "explore" and _quality == &"low":
		omni_budget = BUDGET_OMNI_LOW_EXPLORE
	# ACCENT_LIGHTS: at most ONE on top of the budget, only on high.
	var accent_max: int = 1 if _quality == &"high" else 0
	if int(acc["omni_room"]) > omni_budget or int(acc["neon"]) > accent_max:
		issues.append("Omni %d (+%d Akzent) > %d" % [int(acc["omni_room"]), int(acc["neon"]), omni_budget])
	var spot_budget: int = int(BUDGET_SPOT[ctx]) if _quality == &"high" else 0
	if int(acc["spot"]) > spot_budget:
		issues.append("Spot %d > %d" % [int(acc["spot"]), spot_budget])
	var lpm_budget: int = BUDGET_LIGHTS_PER_MESH
	if ctx == "battle" and _quality == &"high":
		lpm_budget = BUDGET_LIGHTS_PER_MESH_BATTLE_HIGH + mini(int(acc["neon"]), 1)   # + head lamp while passing
	if int(acc["lpm"]) > lpm_budget:
		issues.append("Lichter/Mesh %d > %d" % [int(acc["lpm"]), lpm_budget])
	if int(acc["dirl"]) > 1:
		issues.append("DirectionalLight %d > 1" % int(acc["dirl"]))
	if int(acc["mats"]) > int(BUDGET_MATS[ctx]):
		issues.append("Mat %d > %d%s" % [int(acc["mats"]), int(BUDGET_MATS[ctx]), " (%d von %d Frames)" % [
			int(acc["mats_over"]), int(acc["n"])] if int(BUDGET_MATS[ctx]) == MATS_FRAME_LIMIT else ""])
	if int(acc["l3d"]) > BUDGET_LABEL3D:
		issues.append("Label3D %d > %d" % [int(acc["l3d"]), BUDGET_LABEL3D])
	if int(acc["parts"]) > BUDGET_PARTICLES or int(acc["emit"]) > BUDGET_EMITTERS:
		issues.append("Partikel %d/%d" % [int(acc["parts"]), int(acc["emit"])])
	var bodies: int = int(acc["static"]) + int(acc["kinematic"]) + int(acc["rigid"])
	var body_budget: int = BUDGET_BODIES if ctx == "explore" else 0
	if bodies > body_budget:
		issues.append("Bodies %d > %d" % [bodies, body_budget])
	if int(acc["rigid"]) > 0:
		issues.append("RigidBody %d" % int(acc["rigid"]))
	if float(acc["ram"]) > BUDGET_RAM_MB:
		issues.append("RAM %.0f MB" % float(acc["ram"]))
	return issues


static func _fmt_int(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


# ======================================================================================================================
# Exploration
# ======================================================================================================================

func _section_explore() -> void:
	await _ensure_exploration()
	var scene: ExplorationScene = _explore
	var layout: FloorLayout = scene.get_layout()
	var zones: Dictionary = {}               # zone id → {"acc" (max over its cells), "cell", "kind", "enemies", "cells"}
	var all: Dictionary = _new_acc()
	var all_cell: Dictionary = {}
	var cell_rows: PackedStringArray = []
	for c: Vector2i in layout.sorted_cells():
		var rc: RoomCell = layout.cell_at(c)
		var acc: Dictionary = _new_acc()
		var enemies: int = 0
		for yaw: float in YAWS:
			scene.get_player().teleport(layout.cell_to_world(c) + Vector3(0.0, 0.05, 0.0), yaw)
			scene.get_camera_rig().snap(yaw)
			for i in SETTLE_FRAMES:
				await get_tree().physics_frame
			await _sample(ROOM_SAMPLES, acc)
			enemies = maxi(enemies, _visible_enemies(scene))
		cell_rows.append("| %s | %s | %s | %d | %d / %d | %d (%d) | %d | %d |" % [_cell_txt(c),
			RoomCell.kind_to_string(rc.kind), rc.zone, int(acc["dc"]), int(acc["dc3d"]) + int(acc["dcsh"]), int(acc["dccv"]),
			int(acc["omni"]), int(acc["omni_near"]), int(acc["lpm"]), enemies])
		var z: String = rc.zone
		if not zones.has(z):
			zones[z] = {"acc": _new_acc(), "cell": c, "kind": RoomCell.kind_to_string(rc.kind), "enemies": enemies,
				"dc": -1, "cells": 0}
		var ze: Dictionary = zones[z]
		ze["cells"] = int(ze["cells"]) + 1
		if _worse(acc, {"dc": int(ze["dc"]), "prims": 0, "meshes": int(ze["dc"])}):
			ze["cell"] = c
			ze["kind"] = RoomCell.kind_to_string(rc.kind)
			ze["enemies"] = enemies
			ze["dc"] = int(acc["dc"]) if _rendered else int(acc["meshes"])
		_merge(ze["acc"] as Dictionary, acc)
		if all_cell.is_empty() or _worse(acc, all_cell["acc"] as Dictionary):
			all_cell = {"acc": acc, "cell": c, "kind": RoomCell.kind_to_string(rc.kind), "enemies": enemies}
		_merge(all, acc)
	_table_head("Erkundung Etage 1 (je Zone: Maximum jeder Größe über alle Zellen × 4 Kamerarichtungen)")
	var names: Array = zones.keys()
	names.sort()
	for zn: Variant in names:
		var e: Dictionary = zones[zn]
		_row("%s (%d Zellen; meiste DC: %s %s, %d Gegner)" % [zn, int(e["cells"]), _cell_txt(e["cell"]), e["kind"],
			int(e["enemies"])], "explore", e["acc"] as Dictionary)
	if not all_cell.is_empty():
		_row("**Schlechteste Einzelansicht** %s (%s, %d Gegner)" % [_cell_txt(all_cell["cell"]), all_cell["kind"],
			int(all_cell["enemies"])], "explore", all_cell["acc"] as Dictionary)
	_row("**Etage gesamt (Maximum je Größe)**", "explore", all)
	if _cells_table:
		_emit("")
		_emit("| Zelle | Art | Zone | DC max | 3D / 2D | Omni aktiv (≤ 24 m) | Lichter/Mesh | Gegner |")
		_emit("|---|---|---|---:|---:|---:|---:|---:|")
		for line: String in cell_rows:
			_emit(line)


## Folds `acc` into `into`: maximum of every size, sums of the averages.
func _merge(into: Dictionary, acc: Dictionary) -> void:
	for k: String in acc.keys():
		if k == "shot" or k == "mat_list":
			var by: String = "dc" if k == "shot" else "mats"
			if int(acc[by]) >= int(into[by]):
				into[k] = acc[k]
			continue
		if k == "n" or k == "dc_sum" or k == "mats_over":
			into[k] = int(into[k]) + int(acc[k])
		elif k == "ram" or k == "vram":
			into[k] = maxf(float(into[k]), float(acc[k]))
		else:
			into[k] = maxi(int(into.get(k, 0)), int(acc[k]))


func _worse(a: Dictionary, b: Dictionary) -> bool:
	if _rendered:
		return int(a["dc"]) > int(b["dc"]) or (int(a["dc"]) == int(b["dc"]) and int(a["prims"]) > int(b["prims"]))
	return int(a["meshes"]) > int(b["meshes"])


func _visible_enemies(scene: ExplorationScene) -> int:
	var n: int = 0
	for gid: String in scene.living_groups():
		var a: Node3D = scene.get_enemy(gid)
		if a != null and a.is_visible_in_tree():
			n += 1
	return n


static func _cell_txt(c: Vector2i) -> String:
	return "(%d, %d)" % [c.x, c.y]


# ======================================================================================================================
# Battle
# ======================================================================================================================

func _section_battle() -> void:
	await _ensure_exploration()
	var def: FloorDef = Game.floor_def()
	if not _full_only.is_empty():
		_table_head("Kampf — kompletter Auto-Kampf (alle Frames bis Kampfende)")
		for only_id: String in _full_only:
			var r0: Dictionary = await _battle(only_id, true)
			_row("%s (%d Frames, %s)" % [only_id, int((r0["acc"] as Dictionary)["n"]), r0["outcome"]], "battle",
				r0["acc"] as Dictionary)
		return
	var opening: Dictionary = {}             # enc id → acc
	var cold_ms: float = -1.0
	var max_build: float = 0.0
	var largest: String = ""
	var largest_key: Vector2i = Vector2i(-1, -1)
	for enc: EncounterDef in def.encounters:
		if enc.boss:
			continue
		var r: Dictionary = await _battle(enc.id, false)
		opening[enc.id] = r["acc"]
		if cold_ms < 0.0:
			cold_ms = float(r["build_ms"])
		else:
			max_build = maxf(max_build, float(r["build_ms"]))
		var acc: Dictionary = r["acc"]
		var key: Vector2i = Vector2i(enc.enemies.size(), int(acc["dc"]) if _rendered else int(acc["meshes"]))
		if key.x > largest_key.x or (key.x == largest_key.x and key.y > largest_key.y):
			largest_key = key
			largest = enc.id
	_table_head("Kampf — Eröffnung je Begegnung (Etage 1, Frames %d–%d nach Szenenstart)" % [BATTLE_OPENING_SKIP,
		BATTLE_OPENING_SKIP + BATTLE_OPENING_SAMPLES])
	for enc_id: Variant in opening.keys():
		_row(str(enc_id), "battle", opening[enc_id] as Dictionary)
	_table_head("Kampf — kompletter Auto-Kampf (alle Frames bis Kampfende)")
	var boss_build: float = 0.0
	for enc_id: String in [largest, def.quarter_boss, def.floor_boss]:
		if enc_id == "":
			continue
		var is_boss: bool = enc_id != largest
		var r2: Dictionary = await _battle(enc_id, true)
		if is_boss:
			boss_build = maxf(boss_build, float(r2["build_ms"]))
		var label: String = "%s (%s, %d Frames, %s)" % [enc_id, "Boss" if is_boss else "größte Begegnung",
			int((r2["acc"] as Dictionary)["n"]), r2["outcome"]]
		_row(label, "battle", r2["acc"] as Dictionary)
	_add_build("Kampf-Arena + Rigs + HUD (`BattleScene._ready`, normale Begegnung)", cold_ms, max_build,
		float(BUDGET_BUILD_MS["battle"]))
	if boss_build > 0.0:
		_add_build("Kampf-Arena Boss (`BattleScene._ready`)", boss_build, boss_build,
			float(BUDGET_BUILD_MS["battle"]))


## Runs one battle scene next to the (detached) exploration: opening shots only or a full auto battle.
func _battle(enc_id: String, full: bool) -> Dictionary:
	var root: Window = get_tree().root
	var enc: EncounterDef = _encounter(enc_id)
	if full:
		_level_party(BOSS_LEVEL if enc != null and enc.boss else FULL_LEVEL)
	Progression.full_heal(Game.state, DB.data)
	Game.auto_battle = true
	var setup: BattleSetup = Game.make_battle_setup(enc_id, 0, "")
	var acc: Dictionary = _new_acc()
	if setup == null:
		return {"acc": acc, "build_ms": 0.0, "outcome": "kein Setup"}
	_explore.on_suspend()
	root.remove_child(_explore)
	var t0: int = Time.get_ticks_usec()
	var battle: BattleScene = (load(Router.SCENE_BATTLE) as PackedScene).instantiate() as BattleScene
	battle.setup({"setup": setup, "stay": true, "speed": 4.0, "results_auto_sec": 0.2})
	root.add_child(battle)
	var build_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	Router.adopt(battle)
	var outcome: String = "–"
	if full:
		var old_scale: float = Engine.time_scale
		Engine.time_scale = 4.0
		var frames: int = 0
		while frames < BATTLE_MAX_FRAMES and not battle.controller.done:
			await _sample(1, acc)
			frames += 1
		Engine.time_scale = old_scale
		if battle.controller.result != null:
			outcome = BattleResult.Outcome.keys()[battle.controller.result.outcome]
		else:
			outcome = "Abbruch nach %d Frames" % frames
	else:
		for i in BATTLE_OPENING_SKIP:
			await get_tree().process_frame
		await _sample(BATTLE_OPENING_SAMPLES, acc)
	root.remove_child(battle)
	battle.queue_free()
	Game.in_battle = false
	root.add_child(_explore)
	get_tree().current_scene = _explore
	Router.adopt(_explore)
	_explore.on_resume({})
	await get_tree().process_frame
	return {"acc": acc, "build_ms": build_ms, "outcome": outcome}


func _encounter(enc_id: String) -> EncounterDef:
	for enc: EncounterDef in Game.floor_def().encounters:
		if enc.id == enc_id:
			return enc
	return null


func _level_party(level: int) -> void:
	for m: PartyMember in Game.state.party:
		var guard: int = 0
		while m.level < level and guard < 20:
			Progression.add_exp(m, Progression.exp_to_next(m.level), DB.data)
			guard += 1


# ======================================================================================================================
# Safe room
# ======================================================================================================================

func _section_safe_room() -> void:
	await _ensure_exploration()
	var root: Window = get_tree().root
	_table_head("Safe Room (Etage 1, %d Frames je Raum)" % SAFE_ROOM_SAMPLES)
	var cold_ms: float = -1.0
	var warm_ms: float = 0.0
	for sr: Dictionary in UiUtil.floor_safe_rooms(Game.floor_def()):
		_explore.on_suspend()
		root.remove_child(_explore)
		var t0: int = Time.get_ticks_usec()
		var node: SafeRoomScene = (load(Router.SCENE_SAFE_ROOM) as PackedScene).instantiate() as SafeRoomScene
		node.setup({"safe_room_id": str(sr["id"])})
		root.add_child(node)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		if cold_ms < 0.0:
			cold_ms = ms
		else:
			warm_ms = maxf(warm_ms, ms)
		Router.adopt(node)
		var acc: Dictionary = _new_acc()
		await _sample(SAFE_ROOM_SAMPLES, acc)
		_row("%s (%s)" % [sr["id"], sr["theme"]], "safe_room", acc)
		root.remove_child(node)
		node.queue_free()
		root.add_child(_explore)
		get_tree().current_scene = _explore
		Router.adopt(_explore)
		_explore.on_resume({"from_safe_room": str(sr["id"])})
		await get_tree().process_frame
	_add_build("Safe Room (`SafeRoomScene._ready`)", cold_ms, warm_ms, float(BUDGET_BUILD_MS["safe_room"]))


# ======================================================================================================================
# Leak loop (Router transitions)
# ======================================================================================================================

func _section_leak() -> void:
	if _explore == null or not is_instance_valid(_explore):
		Game.new_game(0, "Kai", FLOOR_SEED)
	var root: Window = get_tree().root
	if _explore != null and is_instance_valid(_explore) and not _explore.is_inside_tree():
		root.add_child(_explore)
		Router.adopt(_explore)
	Game.autoplay = true                    # BattleScene speed 4, results continue after 1 s (§11.4)
	Game.fast_text = true
	Game.auto_battle = true
	var old_scale: float = Engine.time_scale
	Engine.time_scale = 8.0
	var sr_list: Array[Dictionary] = UiUtil.floor_safe_rooms(Game.floor_def())
	var sr_id: String = str(sr_list[0]["id"]) if not sr_list.is_empty() else ""
	_emit("")
	_emit("## Router-Zyklen (je Zyklus: Erkundung neu aufbauen → Kampf → Safe Room → zurück)")
	_emit("")
	_emit("| Zyklus | Objekte | davon in Caches | Nodes | Ressourcen | verwaiste Nodes | RAM MB | Frames |")
	_emit("|---:|---:|---:|---:|---:|---:|---:|---:|")
	var snaps: Array[Dictionary] = []
	var prev_hist: Dictionary = {}
	for cycle in _cycles:
		var frames: int = 0
		# Every cycle builds the same floor: the stray spawners (RunSim, 90 s explore time per zone) are held back —
		# a stray is game state (≤ 1 per zone, ≈ 21 nodes each), not a leak; measured: +2 strays in cycle 12 of a
		# rendered run lifted the node minima by 43 and then stayed flat.
		if Game.state != null and Game.state.floor_run != null:
			Game.state.floor_run.spawner_ticks.clear()
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"}, Router.Transition.NONE)
		frames += await _wait_screen("ExplorationScene", 600)
		(Router.current as ExplorationScene).auto_start_battle = true
		Progression.full_heal(Game.state, DB.data)
		var setup: BattleSetup = Game.make_battle_setup(LEAK_ENCOUNTER, 0, "")
		Router.start_battle(setup)
		frames += await _wait_screen("BattleScene", 600)
		frames += await _wait_screen("ExplorationScene", 6000)
		if sr_id != "":
			Router.enter_safe_room(sr_id)
			frames += await _wait_screen("SafeRoomScene", 600)
			Router.exit_safe_room()
			frames += await _wait_screen("ExplorationScene", 600)
		for i in 4:
			await get_tree().process_frame
		var snap: Dictionary = _counts()
		snap["frames"] = frames
		snap["cached"] = cache_objects()
		snap["objects_net"] = int(snap["objects"]) - int(snap["cached"])
		snaps.append(snap)
		if _leak_diff:
			var hist: Dictionary = node_histogram(root)
			if not prev_hist.is_empty():
				for line: String in histogram_diff(prev_hist, hist):
					print("LEAKDIFF cycle %d: %s" % [cycle + 1, line])
			prev_hist = hist
		_emit("| %d | %d | %d | %d | %d | %d | %.1f | %d |" % [cycle + 1, int(snap["objects"]), int(snap["cached"]),
			int(snap["nodes"]), int(snap["resources"]), int(snap["orphans"]), float(snap["ram"]), frames])
		if not (Router.current is ExplorationScene):
			_leak_fail.append("cycle %d ended on %s" % [cycle + 1, Router.current])
			break
	Engine.time_scale = old_scale
	Game.autoplay = false
	for k: String in leak_growth(snaps, LEAK_WARMUP, LEAK_WINDOW, LEAK_OBJECT_SLACK):
		_leak_fail.append(k)
	if snaps.size() >= LEAK_WARMUP + 2 * LEAK_WINDOW - 1:
		var a: Dictionary = _window_min(snaps, LEAK_WARMUP - 1, LEAK_WINDOW)
		var b: Dictionary = _window_min(snaps, snaps.size() - LEAK_WINDOW, LEAK_WINDOW)
		_emit("")
		_emit(("Minimum Zyklen %d–%d → %d–%d: Objekte %+d (ohne Cache-Einträge %+d), Nodes %+d, Ressourcen %+d, " +
			"verwaiste Nodes max %d, RAM %+.1f MB") % [LEAK_WARMUP, LEAK_WARMUP + LEAK_WINDOW - 1,
			snaps.size() - LEAK_WINDOW + 1, snaps.size(), int(b["objects"]) - int(a["objects"]),
			int(b["objects_net"]) - int(a["objects_net"]), int(b["nodes"]) - int(a["nodes"]),
			int(b["resources"]) - int(a["resources"]), int(b["orphans"]), float(b["ram"]) - float(a["ram"])])


## Leak verdict of a series of _counts() snapshots (one per cycle): the minima of a window after the warm-up and of
## the last window must not grow (nodes, resources: 0; objects: `slack`), and no orphan nodes. Transient nodes
## (toasts, damage numbers, chat lines) only lift single cycles, a leak lifts every later cycle → compare minima.
## Objects are judged without the entries of the bounded art caches ("objects_net" when present, cache_objects()):
## a battle with an effect colour / enemy model not seen before fills them once, a leak grows outside them.
## Also used by tests/test_perf_router_cycles.gd.
static func leak_growth(snaps: Array[Dictionary], warmup: int, window: int, slack: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if snaps.size() < warmup + 2 * window - 1:
		out.append("too few cycles (%d)" % snaps.size())
		return out
	var a: Dictionary = _window_min(snaps, warmup - 1, window)
	var b: Dictionary = _window_min(snaps, snaps.size() - window, window)
	if int(b["nodes"]) > int(a["nodes"]):
		out.append("nodes %+d" % (int(b["nodes"]) - int(a["nodes"])))
	if int(b["resources"]) > int(a["resources"]):
		out.append("resources %+d" % (int(b["resources"]) - int(a["resources"])))
	var okey: String = "objects_net" if a.has("objects_net") and b.has("objects_net") else "objects"
	if int(b[okey]) - int(a[okey]) > slack:
		out.append("objects %+d" % (int(b[okey]) - int(a[okey])))
	if int(b["orphans"]) > 0:
		out.append("orphan nodes %d" % int(b["orphans"]))
	return out


static func _window_min(snaps: Array[Dictionary], from: int, count: int) -> Dictionary:
	var out: Dictionary = {}
	for i in range(from, mini(from + count, snaps.size())):
		for k: String in ["objects", "objects_net", "nodes", "resources", "orphans", "ram"]:
			if snaps[i].has(k):
				out[k] = snaps[i][k] if not out.has(k) else minf(float(out[k]), float(snaps[i][k]))
	return out


## Objects held by the bounded art caches (Materials incl. next_pass, CharacterBuilder meshes ≤ 96 models, tinted VFX
## quads ≤ 64): they fill once per new colour / model and are no leak (leak_growth "objects_net").
static func cache_objects() -> int:
	var ids: Dictionary = {}
	for m: Variant in Materials._cache.values():
		var cur: Material = m as Material
		while cur != null and not ids.has(cur.get_instance_id()):
			ids[cur.get_instance_id()] = true
			cur = cur.next_pass
	_collect_objects(CharacterBuilder._mesh_cache, ids, 0)
	_collect_objects(VfxNodeScript._quad_meshes, ids, 0)
	return ids.size()


static func _collect_objects(v: Variant, ids: Dictionary, depth: int) -> void:
	if depth > 6:
		return
	if v is Object:
		ids[(v as Object).get_instance_id()] = true
	elif v is Dictionary:
		for e: Variant in (v as Dictionary).values():
			_collect_objects(e, ids, depth + 1)
	elif v is Array:
		for e: Variant in v:
			_collect_objects(e, ids, depth + 1)


## Node count per "kind" (path below `root` with digits and auto-generated @names folded, + class): two histograms
## of consecutive leak cycles show which part of the tree grew (--leak-diff).
static func node_histogram(root: Node) -> Dictionary:
	var out: Dictionary = {}
	var digits: RegEx = RegEx.create_from_string("[0-9]+")
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children(true):
			stack.append(c)
		var key: String = digits.sub(str(root.get_path_to(n)), "#", true) + " (" + n.get_class() + ")"
		out[key] = int(out.get(key, 0)) + 1
	return out


static func histogram_diff(a: Dictionary, b: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Dictionary = a.duplicate()
	keys.merge(b)
	for k: Variant in keys.keys():
		var d: int = int(b.get(k, 0)) - int(a.get(k, 0))
		if d != 0:
			out.append("%+d %s" % [d, str(k)])
	out.sort()
	return out


func _counts() -> Dictionary:
	return {"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"ram": Performance.get_monitor(Performance.MEMORY_STATIC) / MB}


## Waits until Router.current is the named screen class and the Router is idle; returns the frames waited.
func _wait_screen(cls_name: String, max_frames: int) -> int:
	var n: int = 0
	while n < max_frames:
		await get_tree().process_frame
		n += 1
		var cur: Node = Router.current
		if cur != null and not Router.busy and _is_screen(cur, cls_name):
			return n
	_leak_fail.append("timeout waiting for %s (current %s)" % [cls_name, Router.current])
	return n


static func _is_screen(node: Node, cls_name: String) -> bool:
	match cls_name:
		"ExplorationScene":
			return node is ExplorationScene
		"BattleScene":
			return node is BattleScene
		"SafeRoomScene":
			return node is SafeRoomScene
	return false


func _free_screens() -> void:
	var root: Window = get_tree().root
	if _explore != null and is_instance_valid(_explore) and not _explore.is_inside_tree():
		_explore.free()
	for c: Node in root.get_children():
		if c is ExplorationScene or c is BattleScene or c is SafeRoomScene or c is TitleScreen:
			c.queue_free()
	Sfx.music(&"", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
