extends TestCase
## M4 characters (02_TECH §8.4, §11.5, §12.1; 03_ART §5/§10): every base × prop builds, tri/mesh budgets of the cast and
## the DB models, heights, the CharacterRig animation contract (play_and_wait ends, impact exactly once, outside the tree
## instantly), locomotion, flash/highlight/dissolve, KO state, facing, glTF wrapper, deterministic caching.

const Cast := preload("res://art/gallery/cast.gd")
const Archetypes := preload("res://art/kit/archetypes.gd")
const ONE_SHOTS: Array[StringName] = [&"attack", &"cast", &"stunt", &"item", &"hit", &"die"]
const WITH_IMPACT: Array[StringName] = [&"attack", &"cast", &"stunt", &"item"]
const GLTF_PATH: String = "user://test_m4_gltf_rig.tscn"


## Captures engine log lines containing one of `needles` (e.g. "different indices", 02_TECH §11.5 M4).
class _LogSpy extends Logger:
	var needles: PackedStringArray = []
	var hits: PackedStringArray = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_check(code + " " + rationale)

	func _log_message(message: String, _error: bool) -> void:
		_check(message)

	func _check(text: String) -> void:
		for n: String in needles:
			if text.contains(n):
				_mutex.lock()
				hits.append(text.strip_edges())
				_mutex.unlock()

	func found() -> PackedStringArray:
		_mutex.lock()
		var out: PackedStringArray = hits.duplicate()
		_mutex.unlock()
		return out


func after_each() -> void:
	Engine.time_scale = 1.0


# --- helpers ---------------------------------------------------------------------------------------------------------

func _rig(model: Dictionary, seed: int = 0) -> CharacterRig:
	var rig: CharacterRig = CharacterBuilder.build(model, seed)
	add_to_tree(rig)
	return rig


func _drop(n: Node) -> void:
	if is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.free()


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		stack.append_array(n.get_children())
	return out


func _kai() -> Dictionary:
	return Cast.model("kai")


## Steps a rig manually (its own _process disabled) and records when impact / anim_finished happen.
func _step_record(rig: CharacterRig, anim: StringName, dt: float, max_t: float) -> Dictionary:
	var rec: Dictionary = {"impacts": [], "finished": -1.0, "finished_anim": &""}
	var t: Array[float] = [0.0]
	var on_impact: Callable = func() -> void: (rec["impacts"] as Array).append(t[0])
	var on_finished: Callable = func(a: StringName) -> void:
		if float(rec["finished"]) < 0.0:
			rec["finished"] = t[0]
			rec["finished_anim"] = a
	rig.impact.connect(on_impact)
	rig.anim_finished.connect(on_finished)
	rig.set_process(false)
	rig.play(anim)
	while t[0] < max_t:
		t[0] += dt
		rig.call("_process", dt)
	rig.impact.disconnect(on_impact)
	rig.anim_finished.disconnect(on_finished)
	return rec


## Starts rig.play_and_wait(anim, speed) as a coroutine; returns [done_flag_array].
func _start_wait(rig: CharacterRig, anim: StringName, speed: float) -> Array[bool]:
	var done: Array[bool] = [false]
	var runner: Callable = func() -> void:
		await rig.play_and_wait(anim, speed)
		done[0] = true
	runner.call()
	return done


# --- vocabulary --------------------------------------------------------------------------------------------------------

func test_vocabulary_matches_validator() -> void:
	assert_eq(CharacterBuilder.supported_bases(), DataValidator.MODEL_BASES)
	assert_eq(CharacterBuilder.supported_props(), DataValidator.MODEL_PROPS)
	assert_eq(Vfx.KINDS.size(), DataValidator.VFX_KINDS.size())
	for k: StringName in Vfx.KINDS:
		assert_has(DataValidator.VFX_KINDS, String(k))


func test_resolve_pose_rule() -> void:
	assert_eq(CharacterBuilder.resolve_pose({"base": "rodent", "scale": 0.8, "pose": "auto"}), &"quadruped")
	assert_eq(CharacterBuilder.resolve_pose({"base": "rodent", "scale": 1.0, "pose": "auto"}), &"upright")
	assert_eq(CharacterBuilder.resolve_pose({"base": "rodent", "scale": 1.3}), &"upright", "pose defaults to auto")
	assert_eq(CharacterBuilder.resolve_pose({"base": "rodent", "scale": 4.0, "pose": "quadruped"}), &"quadruped")
	assert_eq(CharacterBuilder.resolve_pose({"base": "rodent", "scale": 0.5, "pose": "upright"}), &"upright")
	assert_eq(CharacterBuilder.resolve_pose({"base": "pug"}), &"quadruped")
	assert_eq(CharacterBuilder.resolve_pose({"base": "insect", "pose": "upright"}), &"quadruped", "fixed natural pose")
	assert_eq(CharacterBuilder.resolve_pose({"base": "humanoid", "pose": "quadruped"}), &"upright")


func test_normalize_defaults_and_unknowns() -> void:
	var n: Dictionary = CharacterBuilder.normalize({"base": "dragon", "scale": 9.0, "props": ["mop", "mop", "laser"],
		"colors": {"primary": "#ff0000", "eyes": Color.BLUE}})
	assert_eq(n["base"], "humanoid", "unknown base → humanoid")
	assert_almost(float(n["scale"]), 4.0, 0.0001, "scale clamped to 0.3..4.0")
	assert_eq(n["props"], PackedStringArray(["mop"]), "known, unique props")
	var cols: Dictionary = n["colors"]
	assert_eq((cols["primary"] as Color).to_html(false), "ff0000")
	assert_eq(cols["eyes"], Color.BLUE)
	for slot: String in ["primary", "secondary", "accent", "skin", "eyes"]:
		assert_eq(typeof(cols[slot]), TYPE_COLOR, "slot " + slot)
	var pug: Dictionary = CharacterBuilder.normalize({"base": "pug", "colors": {"primary": "#123456"}})
	assert_eq((pug["colors"]["skin"] as Color).to_html(false), "123456", "non-human skin follows primary")
	var rat: Dictionary = CharacterBuilder.normalize({"base": "rodent", "scale": 0.8})
	assert_eq(rat["pose"], &"quadruped")


# --- every base × prop -----------------------------------------------------------------------------------------------

func test_every_base_and_every_prop_builds() -> void:
	var spy := _LogSpy.new()
	spy.needles = PackedStringArray(["different indices"])
	OS.add_logger(spy)
	for base: String in CharacterBuilder.supported_bases():
		var plain: CharacterRig = _rig({"base": base})
		var base_tris: int = MeshUtil.tri_count_tree(plain)
		assert_gt(base_tris, 0, base)
		assert_not_null(plain.get_node_or_null("Model"), base + " has a Model node")
		for a: StringName in CharacterRig.ANCHOR_NAMES:
			assert_true(plain.anchor(a) != plain, "%s anchor %s exists" % [base, a])
		_drop(plain)
		for prop: String in CharacterBuilder.supported_props():
			var rig: CharacterRig = _rig({"base": base, "props": [prop]}, 7)
			assert_true(rig is CharacterRig, "%s + %s" % [base, prop])
			var tris: int = MeshUtil.tri_count_tree(rig)
			assert_ne(tris, base_tris, "%s + %s changes the figure (adds or replaces parts)" % [base, prop])
			assert_gt(rig.height, 0.1, "%s + %s height" % [base, prop])
			for mi: MeshInstance3D in _meshes(rig):
				if mi.name == "ContactShadow":
					continue
				assert_gt(MeshUtil.tri_count(mi.mesh), 0, "%s + %s: %s not empty" % [base, prop, mi.name])
				assert_not_null(mi.material_override, "%s + %s: %s material" % [base, prop, mi.name])
			_drop(rig)
	OS.remove_logger(spy)
	assert_eq(spy.found(), PackedStringArray(), "no 'different indices' in the log")


func test_all_props_at_once_on_every_base() -> void:
	for base: String in CharacterBuilder.supported_bases():
		var rig: CharacterRig = _rig({"base": base, "props": Array(CharacterBuilder.supported_props())})
		assert_gt(MeshUtil.tri_count_tree(rig), 0, base + " with all props")
		_drop(rig)


# --- budgets (02_TECH §12.1, measured with MeshUtil.tri_count, hull not counted) ---------------------------------------

func _check_budget(id: String, model: Dictionary, role: String) -> void:
	var limits: Array = Cast.BUDGETS[role]
	var rig: CharacterRig = _rig(model)
	var tris: int = MeshUtil.tri_count_tree(rig)
	var count: int = _meshes(rig).size()
	assert_true(tris <= int(limits[0]), "%s (%s): %d tris > %d" % [id, role, tris, int(limits[0])])
	assert_true(count <= int(limits[1]), "%s (%s): %d MeshInstances > %d" % [id, role, count, int(limits[1])])
	_drop(rig)


func test_cast_budgets() -> void:
	for id: String in Cast.ids():
		var entry: Dictionary = Cast.CAST[id]
		_check_budget(id, Cast.model(id), str(entry["role"]))


func test_db_model_budgets() -> void:
	var data: GameData = real_data()
	for p: PartyMemberDef in data.all_party():
		_check_budget(p.id, p.model, "hero")
	for e: EnemyDef in data.all_enemies():
		_check_budget(e.id, e.model, "boss" if e.boss else "enemy")


func test_wreck_budget() -> void:
	var wreck: Node3D = PropKit.build(&"wreck", 1)
	add_to_tree(wreck)
	var tris: int = MeshUtil.tri_count_tree(wreck)
	assert_gt(tris, 0)
	assert_true(tris <= 600, "wreck %d tris > 600" % tris)


# --- size ------------------------------------------------------------------------------------------------------------

func test_heights_follow_nominal_and_scale() -> void:
	for base: String in CharacterBuilder.supported_bases():
		var nominal: float = float(Archetypes.NOMINAL_HEIGHT[base])
		var rig: CharacterRig = _rig({"base": base, "scale": 1.0})
		assert_between(rig.height, nominal * 0.6, nominal * 1.45, "%s height %.2f vs %.2f" % [base, rig.height, nominal])
		var h1: float = rig.height
		_drop(rig)
		var big: CharacterRig = _rig({"base": base, "scale": 2.0, "pose": "upright" if base == "rodent" else "auto"})
		var small_ref: CharacterRig = _rig({"base": base, "scale": 1.0, "pose": "upright" if base == "rodent" else "auto"})
		if base != "brute":     # brute below 1.0 uses the compact recipe; 1.0 and 2.0 share the full one
			assert_almost(big.height, small_ref.height * 2.0, 0.02 * big.height, base + ": height scales linearly")
		assert_almost(big.size_factor(), clampf(big.height / 1.75, 0.25, 2.2), 0.0001)
		_drop(big)
		_drop(small_ref)
		assert_gt(h1, 0.0)
	var kai: CharacterRig = _rig(_kai())
	assert_between(kai.height, 1.6, 1.95, "Kai ≈ 1.75 m")
	var mops: CharacterRig = _rig(Cast.model("mopsula"))
	assert_between(mops.height, 0.5, 0.75, "Mopsula ≈ 0.6 m")
	assert_lt(mops.height, kai.height * 0.5, "pug clearly smaller than the hero")


# --- determinism / cache ---------------------------------------------------------------------------------------------

func test_builds_are_cached_and_deterministic() -> void:
	CharacterBuilder.clear_cache()
	var a: CharacterRig = _rig(_kai())
	var b: CharacterRig = _rig(_kai())
	var ma: Array[MeshInstance3D] = _meshes(a)
	var mb: Array[MeshInstance3D] = _meshes(b)
	assert_eq(ma.size(), mb.size())
	for i in mini(ma.size(), mb.size()):
		assert_true(ma[i].mesh == mb[i].mesh, "same ModelSpec → shared cached mesh " + str(ma[i].name))
		assert_true(ma[i].material_override == mb[i].material_override, "shared cached material")
	CharacterBuilder.clear_cache()
	var c: CharacterRig = _rig(_kai())
	var mc: Array[MeshInstance3D] = _meshes(c)
	assert_true(mc[0].mesh != ma[0].mesh, "clear_cache → rebuilt")
	assert_eq(MeshUtil.tri_count_tree(c), MeshUtil.tri_count_tree(a), "rebuild is identical")
	var t1: CharacterRig = _rig({"base": "blob", "props": ["cable_tangle"]}, 1)
	var t2: CharacterRig = _rig({"base": "blob", "props": ["cable_tangle"]}, 1)
	var t3: CharacterRig = _rig({"base": "blob", "props": ["cable_tangle"]}, 99)
	assert_eq(MeshUtil.tri_count_tree(t1), MeshUtil.tri_count_tree(t2))
	var differs: bool = false
	var m1: Array[MeshInstance3D] = _meshes(t1)
	var m3: Array[MeshInstance3D] = _meshes(t3)
	for i in mini(m1.size(), m3.size()):
		if not m1[i].mesh.get_aabb().is_equal_approx(m3[i].mesh.get_aabb()):
			differs = true
	assert_true(differs, "cable_tangle varies with the seed")
	var r1: CharacterRig = _rig({"base": "brute", "scale": 0.8})
	var r2: CharacterRig = _rig({"base": "brute", "scale": 1.36})
	assert_lt(MeshUtil.tri_count_tree(r1), MeshUtil.tri_count_tree(r2), "compact brute is cached separately")


func test_death_style_and_vertex_data() -> void:
	for base: String in ["blob", "swarm", "insect", "robot"]:
		var r: CharacterRig = _rig({"base": base})
		assert_eq(r.death_style, &"dissolve", base)
		_drop(r)
	var kai: CharacterRig = _rig(_kai())
	assert_eq(kai.death_style, &"fall")
	for mi: MeshInstance3D in _meshes(kai):
		var mesh: ArrayMesh = mi.mesh as ArrayMesh
		assert_not_null(mesh, str(mi.name))
		if mesh == null:
			continue
		var fmt: int = mesh.surface_get_format(0)
		assert_true((fmt & Mesh.ARRAY_FORMAT_COLOR) != 0, "vertex colors " + str(mi.name))
		assert_true((fmt & Mesh.ARRAY_FORMAT_TEX_UV2) != 0, "UV2 masks " + str(mi.name))
		assert_true((fmt & Mesh.ARRAY_FORMAT_CUSTOM0) != 0, "CUSTOM0 hull normals " + str(mi.name))
		var mat: ShaderMaterial = mi.material_override as ShaderMaterial
		assert_not_null(mat)
		if mat != null:
			assert_eq(mat.shader.resource_path, "res://art/shaders/toon.gdshader")
			assert_not_null(mat.next_pass, "outline next_pass")


# --- animation contract ----------------------------------------------------------------------------------------------

func test_play_and_wait_every_one_shot_on_every_base() -> void:
	Engine.time_scale = 4.0
	for base: String in CharacterBuilder.supported_bases():
		var rig: CharacterRig = _rig({"base": base, "props": ["staff"] if base == "rodent" else []})
		var impacts: Array[int] = [0]
		rig.impact.connect(func() -> void: impacts[0] += 1)
		for anim: StringName in ONE_SHOTS:
			impacts[0] = 0
			var done: Array[bool] = _start_wait(rig, anim, 2.0)
			var ok: bool = await wait_until(func() -> bool: return done[0], 3000)
			assert_true(ok, "%s: play_and_wait(%s) returned" % [base, anim])
			assert_eq(impacts[0], 1 if WITH_IMPACT.has(anim) else 0, "%s: impact count for %s" % [base, anim])
			if anim == &"die":
				assert_eq(rig.current_anim(), &"die", base + " stays KO")
				rig.play(&"idle")
			else:
				assert_eq(rig.current_anim(), &"idle", "%s: back to idle after %s" % [base, anim])
		_drop(rig)


func test_impact_and_end_timing() -> void:
	var rig: CharacterRig = _rig(_kai())
	await wait_frames(1)
	var dt: float = 0.01
	for anim: StringName in ONE_SHOTS:
		var rec: Dictionary = _step_record(rig, anim, dt, float(CharacterRig.DURATIONS[anim]) + 0.2)
		var imps: Array = rec["impacts"]
		if WITH_IMPACT.has(anim):
			assert_eq(imps.size(), 1, "%s: impact exactly once" % anim)
			if imps.size() == 1:
				assert_almost(float(imps[0]), float(CharacterRig.IMPACT_AT[anim]), dt * 1.5, "%s impact time" % anim)
		else:
			assert_eq(imps.size(), 0, "%s: no impact" % anim)
		assert_almost(float(rec["finished"]), float(CharacterRig.DURATIONS[anim]), dt * 1.5, "%s duration" % anim)
		assert_eq(rec["finished_anim"], anim)
		rig.reset_pose()
	# speed scales the timing
	rig.set_process(false)
	var rec2: Dictionary = {"t": -1.0}
	var acc: Array[float] = [0.0]
	var cb: Callable = func(_a: StringName) -> void:
		if float(rec2["t"]) < 0.0:
			rec2["t"] = acc[0]
	rig.anim_finished.connect(cb)
	rig.play(&"attack", 2.0)
	while acc[0] < 0.5:
		acc[0] += dt
		rig.call("_process", dt)
	rig.anim_finished.disconnect(cb)
	assert_almost(float(rec2["t"]), 0.275, dt * 1.5, "speed 2 halves the duration")


func test_outside_tree_finishes_instantly() -> void:
	var rig: CharacterRig = CharacterBuilder.build(_kai())
	var impacts: Array[int] = [0]
	var finished: Array[StringName] = []
	rig.impact.connect(func() -> void: impacts[0] += 1)
	rig.anim_finished.connect(func(a: StringName) -> void: finished.append(a))
	for anim: StringName in [&"attack", &"cast", &"stunt", &"item", &"hit"]:
		await rig.play_and_wait(anim)
	assert_eq(impacts[0], 4, "impact once per attack/cast/stunt/item")
	assert_eq(finished, [&"attack", &"cast", &"stunt", &"item", &"hit"] as Array[StringName])
	assert_eq(rig.current_anim(), &"idle")
	await rig.play_and_wait(&"die")
	assert_eq(rig.current_anim(), &"die")
	await rig.play_and_wait(&"walk")
	assert_eq(rig.current_anim(), &"walk", "loops return immediately")
	rig.free()


func test_interrupted_one_shot_still_completes_contract() -> void:
	var rig: CharacterRig = _rig(_kai())
	var impacts: Array[int] = [0]
	rig.impact.connect(func() -> void: impacts[0] += 1)
	var done: Array[bool] = _start_wait(rig, &"attack", 0.25)
	await wait_frames(2)
	assert_false(done[0], "slow attack still running")
	rig.play(&"hit")
	var ok: bool = await wait_until(func() -> bool: return done[0], 60)
	assert_true(ok, "play_and_wait(attack) returns when interrupted")
	assert_eq(impacts[0], 1, "interrupted attack still emits impact once")
	assert_eq(rig.current_anim(), &"hit")
	await wait_until(func() -> bool: return rig.current_anim() == &"idle", 3000)
	assert_eq(impacts[0], 1, "no second impact")


func test_locomotion_states() -> void:
	var rig: CharacterRig = _rig(_kai())
	rig.set_locomotion(0.0)
	assert_eq(rig.current_anim(), &"idle")
	rig.set_locomotion(2.0)
	assert_eq(rig.current_anim(), &"walk")
	rig.set_locomotion(5.4)
	assert_eq(rig.current_anim(), &"walk")
	rig.set_locomotion(6.0)
	assert_eq(rig.current_anim(), &"run")
	rig.set_locomotion(0.1)
	assert_eq(rig.current_anim(), &"idle")
	# a one-shot returns to the current locomotion state
	rig.set_locomotion(3.0)
	rig.set_process(false)
	rig.play(&"hit")
	assert_eq(rig.current_anim(), &"hit")
	rig.set_locomotion(3.0)
	assert_eq(rig.current_anim(), &"hit", "locomotion does not cut a one-shot")
	for i in 50:
		rig.call("_process", 0.02)
	assert_eq(rig.current_anim(), &"walk", "back to walk after the one-shot")
	# walking moves the legs
	var leg: Node3D = rig.get_node("Model/Hips/LegL") as Node3D
	var r0: float = leg.rotation.x
	for i in 10:
		rig.call("_process", 0.02)
	assert_ne(snappedf(leg.rotation.x, 0.0001), snappedf(r0, 0.0001), "legs swing while walking")
	rig.set_dead(true)
	rig.set_locomotion(6.0)
	assert_eq(rig.current_anim(), &"die", "KO ignores locomotion")


func test_flash_highlight_dissolve() -> void:
	var rig: CharacterRig = _rig(_kai())
	rig.set_process(false)
	var meshes: Array[MeshInstance3D] = _meshes(rig)
	assert_gt(meshes.size(), 0)
	rig.set_highlight(true)
	for mi: MeshInstance3D in meshes:
		assert_almost(float(mi.get_instance_shader_parameter(&"highlight")), 1.0, 0.0001, str(mi.name))
	rig.set_highlight(false)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"highlight")), 0.0)
	rig.flash(Color.RED, 0.2)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"flash_amount")), 1.0)
	assert_eq(meshes[0].get_instance_shader_parameter(&"flash_color"), Color.RED)
	rig.call("_process", 0.1)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"flash_amount")), 0.5, 0.01, "fades linearly")
	rig.call("_process", 0.2)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"flash_amount")), 0.0)
	rig.set_dissolve(0.5)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"dissolve")), 0.5)
	assert_true((rig.get_node("Model") as Node3D).visible)
	rig.set_dissolve(2.0)
	assert_almost(float(meshes[0].get_instance_shader_parameter(&"dissolve")), 1.0, 0.0001, "clamped")
	assert_false((rig.get_node("Model") as Node3D).visible, "fully dissolved → hidden")
	rig.set_dissolve(0.0)
	assert_true((rig.get_node("Model") as Node3D).visible)
	rig.set_rim_color(Palette.NOVA_CYAN)
	var mat: ShaderMaterial = meshes[0].material_override as ShaderMaterial
	assert_eq((mat.get_shader_parameter(&"rim_color") as Color).to_html(false), Palette.NOVA_CYAN.to_html(false))


func test_set_dead_and_reset() -> void:
	var kai: CharacterRig = _rig(_kai())
	kai.set_process(false)
	kai.reset_pose()
	var head: Node3D = kai.get_node("Model/Hips/Torso/Head") as Node3D
	var rest: Transform3D = head.global_transform
	kai.set_dead(true)
	assert_eq(kai.current_anim(), &"die")
	assert_false(head.global_transform.is_equal_approx(rest), "KO pose differs from rest")
	assert_lt(head.global_position.y, rest.origin.y - 0.3, "fallen over")
	kai.set_dead(false)
	assert_eq(kai.current_anim(), &"idle")
	kai.play(&"attack")
	kai.call("_process", 0.2)
	kai.reset_pose()
	assert_true(head.global_transform.is_equal_approx(rest), "reset_pose restores the rest pose")
	assert_eq(kai.current_anim(), &"idle")
	var blob: CharacterRig = _rig({"base": "blob"})
	var blob_meshes: Array[MeshInstance3D] = _meshes(blob)
	blob.set_dead(true)
	assert_almost(float(blob_meshes[0].get_instance_shader_parameter(&"dissolve")), 1.0, 0.0001, "dissolve death")
	assert_false((blob.get_node("Model") as Node3D).visible)
	blob.play(&"idle")
	assert_true((blob.get_node("Model") as Node3D).visible, "any other anim revives")
	assert_almost(float(blob_meshes[0].get_instance_shader_parameter(&"dissolve")), 0.0)


func test_face_towards_and_anchors() -> void:
	var rig: CharacterRig = _rig(_kai())
	rig.position = Vector3(1, 0, 1)
	rig.face_towards(Vector3(6, 3, 1))
	var fwd: Vector3 = -rig.global_transform.basis.z.normalized()
	assert_true(fwd.is_equal_approx(Vector3(1, 0, 0)), "faces +X (front = −Z), got %s" % fwd)
	rig.face_towards(Vector3(1, 0, -4))
	fwd = -rig.global_transform.basis.z.normalized()
	assert_true(fwd.is_equal_approx(Vector3(0, 0, -1)))
	rig.face_towards(rig.global_position)
	assert_true((-rig.global_transform.basis.z).normalized().is_equal_approx(Vector3(0, 0, -1)), "same spot: no change")
	var head_y: float = rig.anchor(&"head").global_position.y
	var center_y: float = rig.anchor(&"center").global_position.y
	var over_y: float = rig.anchor(&"overhead").global_position.y
	var feet_y: float = rig.anchor(&"feet").global_position.y
	assert_gt(over_y, head_y)
	assert_gt(head_y, center_y)
	assert_gt(center_y, feet_y)
	assert_almost(feet_y, 0.0, 0.01)
	assert_gt(over_y, rig.height * 0.9, "overhead above the head")
	assert_true(rig.anchor(&"nonsense") == rig, "unknown anchor → rig itself")
	var outside: CharacterRig = CharacterBuilder.build(_kai())
	outside.face_towards(Vector3(-5, 0, 0))
	var f2: Vector3 = -outside.transform.basis.z.normalized()
	assert_true(f2.is_equal_approx(Vector3(-1, 0, 0)), "outside the tree uses the local position")
	outside.free()


func test_boss_phase_glow_and_effects() -> void:
	var boss: CharacterRig = _rig(Cast.model("enm_boss_hausmeister"))
	var eyes: MeshInstance3D = boss.get_node_or_null("Model/Torso/Head/EyesMesh") as MeshInstance3D
	assert_not_null(eyes, "Hausmeister eyes are their own mesh (P3 glow)")
	if eyes == null:
		return
	boss.set_process(false)
	boss.call("_process", 0.016)
	assert_almost(float(eyes.get_instance_shader_parameter(&"flash_amount")), 0.0, 0.0001, "phase 1: no glow")
	boss.set_boss_phase(3)
	boss.call("_process", 0.016)
	assert_gt(float(eyes.get_instance_shader_parameter(&"flash_amount")), 0.5, "phase 3: glowing eyes")
	# effects spawn into the rig's parent (Vfx pool), never as children of the rig
	var host := Node3D.new()
	add_to_tree(host)
	var caster: CharacterRig = CharacterBuilder.build(_kai())
	host.add_child(caster)
	caster.set_process(false)
	caster.play(&"cast")
	caster.call("_process", 0.05)
	assert_true(host.has_meta(Vfx.POOL_META), "cast spawns a magic circle into the parent")
	caster.spawn_effects = false
	var host2 := Node3D.new()
	add_to_tree(host2)
	var quiet: CharacterRig = CharacterBuilder.build(_kai())
	quiet.spawn_effects = false
	host2.add_child(quiet)
	quiet.set_process(false)
	quiet.play(&"cast")
	quiet.call("_process", 0.05)
	assert_false(host2.has_meta(Vfx.POOL_META), "spawn_effects = false → no Vfx")


func test_unknown_anim_and_contact_shadow() -> void:
	var rig: CharacterRig = _rig(_kai())
	rig.play(&"breakdance")
	assert_eq(rig.current_anim(), &"idle", "unknown anim → idle")
	rig.set_contact_shadow(true)
	var disc: MeshInstance3D = rig.get_node_or_null("ContactShadow") as MeshInstance3D
	assert_not_null(disc)
	if disc != null:
		assert_true(disc.visible)
		rig.set_contact_shadow(false)
		assert_false(disc.visible)


# --- glTF wrapper (03_ART §10) ---------------------------------------------------------------------------------------

func _make_gltf_scene() -> PackedScene:
	var root := Node3D.new()
	root.name = "Dummy"
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = MeshUtil.merge([MeshUtil.part(MeshUtil.box(Vector3(0.6, 1.6, 0.4)), Vector3(0, 0.8, 0), Color.WHITE)]
		as Array[Dictionary])
	root.add_child(mi)
	mi.owner = root
	var head := Node3D.new()
	head.name = "anchor_head"
	head.position = Vector3(0, 1.5, 0)
	root.add_child(head)
	head.owner = root
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	root.add_child(player)
	player.owner = root
	var lib := AnimationLibrary.new()
	var attack := Animation.new()
	attack.length = 0.5
	var mt: int = attack.add_track(Animation.TYPE_METHOD)
	attack.track_set_path(mt, NodePath("."))
	attack.track_insert_key(mt, 0.25, {"method": &"emit_impact", "args": []})
	var vt: int = attack.add_track(Animation.TYPE_VALUE)
	attack.track_set_path(vt, NodePath("Body:position"))
	attack.track_insert_key(vt, 0.0, Vector3.ZERO)
	attack.track_insert_key(vt, 0.25, Vector3(0, 0, -0.3))
	attack.track_insert_key(vt, 0.5, Vector3.ZERO)
	lib.add_animation(&"attack", attack)
	var idle := Animation.new()
	idle.length = 1.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var it: int = idle.add_track(Animation.TYPE_VALUE)
	idle.track_set_path(it, NodePath("Body:position"))
	idle.track_insert_key(it, 0.0, Vector3.ZERO)
	idle.track_insert_key(it, 0.5, Vector3(0, 0.05, 0))
	lib.add_animation(&"idle", idle)
	player.add_animation_library(&"", lib)
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func test_gltf_wrapper_contract() -> void:
	var packed: PackedScene = _make_gltf_scene()
	var err: Error = ResourceSaver.save(packed, GLTF_PATH)
	assert_eq(err, OK, "save runtime test scene")
	if err != OK:
		return
	var rig: CharacterRig = _rig({"base": "humanoid", "scale": 1.0, "gltf": GLTF_PATH})
	assert_true(rig.get_script() != CharacterRig, "glTF → wrapper subclass")
	assert_almost(rig.height, 1.6, 0.01, "height from the imported meshes")
	assert_eq(rig.anchor(&"head").name, &"anchor_head")
	var mi: MeshInstance3D = rig.find_child("Body", true, false) as MeshInstance3D
	assert_not_null(mi)
	if mi != null:
		assert_eq((mi.material_override as ShaderMaterial).shader.resource_path, "res://art/shaders/toon.gdshader",
			"imported materials replaced by the toon material")
	var impacts: Array[int] = [0]
	rig.impact.connect(func() -> void: impacts[0] += 1)
	var done: Array[bool] = _start_wait(rig, &"attack", 1.0)
	var ok: bool = await wait_until(func() -> bool: return done[0], 3000)
	assert_true(ok, "play_and_wait on the glTF clip returns")
	assert_eq(impacts[0], 1, "method track impact forwarded exactly once")
	assert_eq(rig.current_anim(), &"idle")
	var player: AnimationPlayer = rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player)
	if player != null:
		await wait_frames(1)
		assert_eq(String(player.current_animation), "idle", "idle clip resumes after the one-shot")
	# clip without a glTF counterpart (cast) still keeps the timing contract via the procedural defaults
	impacts[0] = 0
	var done2: Array[bool] = _start_wait(rig, &"cast", 2.0)
	ok = await wait_until(func() -> bool: return done2[0], 3000)
	assert_true(ok)
	assert_eq(impacts[0], 1, "cast impact from the default table")
	_drop(rig)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLTF_PATH))
	var fallback: CharacterRig = _rig({"base": "pug", "gltf": "res://art/models/does_not_exist.glb"})
	assert_eq(fallback.get_script(), CharacterRig, "missing glTF → procedural rig")
