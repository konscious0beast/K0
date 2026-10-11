extends TestCase
## M4 effects (02_TECH §8.6, §12.1; 03_ART §7): every Vfx kind spawns (CPUParticles only, emitter/particle budget),
## hides after its duration, per-parent pool of 4 (oldest reused), outside the tree, unknown kinds, for_skill mapping,
## damage numbers (styles, texts, pool of 12, stacking, rise + fade).


func _host() -> Node3D:
	var h := Node3D.new()
	add_to_tree(h)
	return h


func _children_of_kind(parent: Node, kind: StringName) -> int:
	var n: int = 0
	for c: Node in parent.get_children():
		if c.get("kind") == kind:
			n += 1
	return n


func _emitters(n: Node, out: Array[CPUParticles3D]) -> void:
	if n is CPUParticles3D:
		out.append(n as CPUParticles3D)
	for c: Node in n.get_children():
		_emitters(c, out)


func _count(root: Node, cls: String) -> int:
	var k: int = 1 if root.is_class(cls) else 0
	for c: Node in root.get_children():
		k += _count(c, cls)
	return k


func _skill(fields: Dictionary) -> SkillDef:
	var s := SkillDef.new()
	for k: String in fields:
		s.set(k, fields[k])
	return s


# --- kinds ------------------------------------------------------------------------------------------------------------

func test_durations_cover_every_kind() -> void:
	assert_eq(Vfx.KINDS.size(), 22)
	for kind: StringName in Vfx.KINDS:
		assert_true(Vfx.DURATIONS.has(kind), String(kind))
		assert_between(Vfx.duration(kind), 0.3, 1.5, String(kind))
	assert_almost(Vfx.duration(&"hit"), 0.30)
	assert_almost(Vfx.duration(&"levelup"), 1.50)
	assert_eq(Vfx.DURATIONS.size(), Vfx.KINDS.size())


func test_spawn_every_kind() -> void:
	var host: Node3D = _host()
	host.position = Vector3(10, 0, -4)
	var total_particles: int = 0
	for kind: StringName in Vfx.KINDS:
		var at := Vector3(11, 0.5, -3)
		var n: Node3D = Vfx.spawn(kind, host, at)
		assert_not_null(n, String(kind))
		if n == null:
			continue
		assert_true(n.get_parent() == host, "%s lives under the parent" % kind)
		assert_true(n.global_position.is_equal_approx(at), "%s placed at global `at`" % kind)
		assert_true(n.visible, String(kind))
		assert_eq(_count(n, "GPUParticles3D"), 0, "%s: CPUParticles3D only" % kind)
		var em: Array[CPUParticles3D] = []
		_emitters(n, em)
		assert_true(em.size() <= 6, "%s: %d emitters > 6" % [kind, em.size()])
		var amount: int = 0
		for p: CPUParticles3D in em:
			amount += p.amount
			assert_not_null(p.mesh, "%s: emitter mesh" % kind)
		total_particles += amount
		assert_true(amount <= 400, "%s: %d particles > 400" % [kind, amount])
	assert_gt(total_particles, 0)


func test_effects_hide_after_duration_and_loops_keep_running() -> void:
	var host: Node3D = _host()
	var hit: Node3D = Vfx.spawn(&"hit", host, Vector3.ZERO)
	var glow: Node3D = Vfx.spawn(&"stairs_glow", host, Vector3.ZERO)
	assert_true(bool(hit.get("active")))
	hit.set_process(false)
	glow.set_process(false)
	hit.call("_process", 0.25)
	assert_true(hit.visible, "still playing at 0.25 s")
	hit.call("_process", 0.1)
	assert_false(hit.visible, "hit hides itself after %.2f s" % Vfx.duration(&"hit"))
	assert_false(bool(hit.get("active")))
	assert_true(is_instance_valid(hit), "pool keeps the node")
	for i in 100:
		glow.call("_process", 0.05)
	assert_true(glow.visible and bool(glow.get("active")), "stairs_glow loops (5 s later still running)")
	glow.call("stop")
	assert_false(glow.visible)


func test_pool_reuses_oldest_per_parent() -> void:
	var host: Node3D = _host()
	var first: Array[Node3D] = []
	for i in 4:
		first.append(Vfx.spawn(&"fire", host, Vector3(float(i), 0, 0)))
	assert_eq(_children_of_kind(host, &"fire"), 4)
	var fifth: Node3D = Vfx.spawn(&"fire", host, Vector3(9, 0, 0))
	assert_true(fifth == first[0], "5th spawn reuses the oldest instance")
	assert_true(fifth.global_position.is_equal_approx(Vector3(9, 0, 0)), "reused instance moved")
	var sixth: Node3D = Vfx.spawn(&"fire", host, Vector3.ZERO)
	assert_true(sixth == first[1], "then the next oldest")
	assert_eq(_children_of_kind(host, &"fire"), 4, "never more than 4 per kind and parent")
	for i in 3:
		Vfx.spawn(&"ice", host, Vector3.ZERO)
	assert_eq(_children_of_kind(host, &"ice"), 3, "pools are per kind")
	var other: Node3D = _host()
	var o: Node3D = Vfx.spawn(&"fire", other, Vector3.ZERO)
	assert_true(o.get_parent() == other, "own pool per parent")
	assert_eq(_children_of_kind(other, &"fire"), 1)
	# a pooled node freed by its owner is replaced, never reused
	first[2].free()
	var replacement: Node3D = Vfx.spawn(&"fire", host, Vector3.ZERO)
	assert_true(is_instance_valid(replacement))
	assert_eq(_children_of_kind(host, &"fire"), 4)
	# a pool entry moved to another parent is not reused for this parent
	var moved: Node3D = first[3]
	host.remove_child(moved)
	other.add_child(moved)
	for i in 4:
		var n: Node3D = Vfx.spawn(&"fire", host, Vector3.ZERO)
		assert_true(n != moved, "foreign node not reused")


func test_spawn_outside_tree_and_invalid_input() -> void:
	var loose := Node3D.new()
	var n: Node3D = Vfx.spawn(&"magic", loose, Vector3(1, 2, 3))
	assert_not_null(n)
	if n != null:
		assert_true(n.position.is_equal_approx(Vector3(1, 2, 3)), "outside the tree: local position")
	assert_null(Vfx.spawn(&"explosion", loose, Vector3.ZERO), "unknown kind → null")
	assert_eq(loose.get_child_count(), 1, "unknown kind adds nothing")
	assert_null(Vfx.spawn(&"hit", null, Vector3.ZERO), "null parent → null")
	loose.free()


func test_spawn_color_and_scale() -> void:
	var host: Node3D = _host()
	var n: Node3D = Vfx.spawn(&"magic", host, Vector3.ZERO, Palette.DANGER, 2.0)
	assert_true(n.scale.is_equal_approx(Vector3.ONE * 2.0), "uniform scale")
	var em: Array[CPUParticles3D] = []
	_emitters(n, em)
	var tinted: bool = false
	for p: CPUParticles3D in em:
		if p.color.is_equal_approx(Palette.DANGER):
			tinted = true
	assert_true(tinted, "color tints the effect")
	var d: Node3D = Vfx.spawn(&"magic", host, Vector3.ZERO)
	var em2: Array[CPUParticles3D] = []
	_emitters(d, em2)
	var all_default: bool = true
	for p: CPUParticles3D in em2:
		if p.color.is_equal_approx(Palette.DANGER):
			all_default = false
	assert_true(all_default, "Color(0,0,0,0) → kind default")


func test_for_skill_mapping() -> void:
	assert_eq(Vfx.for_skill(null), &"hit")
	assert_eq(Vfx.for_skill(_skill({"vfx": "ice", "element": "fire"})), &"ice", "explicit vfx wins")
	assert_eq(Vfx.for_skill(_skill({"vfx": "laser", "element": "fire"})), &"fire", "unknown vfx → element")
	assert_eq(Vfx.for_skill(_skill({"category": "heal", "damage_type": "heal"})), &"heal")
	assert_eq(Vfx.for_skill(_skill({"category": "buff"})), &"buff")
	assert_eq(Vfx.for_skill(_skill({"category": "debuff", "element": "poison"})), &"debuff")
	assert_eq(Vfx.for_skill(_skill({"element": "physical"})), &"slash")
	assert_eq(Vfx.for_skill(_skill({"element": "shock"})), &"shock")
	assert_eq(Vfx.for_skill(_skill({"element": "poison"})), &"toxic")
	assert_eq(Vfx.for_skill(_skill({"category": "magic", "element": "none"})), &"magic")
	assert_eq(Vfx.for_skill(_skill({"category": "attack", "element": "none"})), &"hit")
	for s: SkillDef in real_data().all_skills():
		assert_has(Vfx.KINDS, Vfx.for_skill(s), "skill %s maps to a kind" % s.id)


# --- damage numbers ------------------------------------------------------------------------------------------------

func _labels(host: Node) -> Array[Label3D]:
	var out: Array[Label3D] = []
	for c: Node in host.get_children():
		if c is Label3D:
			out.append(c as Label3D)
	return out


## Number entries only (captions are own pool entries since the review fix).
func _numbers(host: Node) -> Array[Label3D]:
	var out: Array[Label3D] = []
	for l: Label3D in _labels(host):
		if not bool(l.get("is_caption")):
			out.append(l)
	return out


func _last_shown(host: Node) -> Label3D:
	var pool: Array = host.get_meta(Vfx.DMG_META, [])
	return pool.back() as Label3D if not pool.is_empty() else null


func test_damage_number_styles_and_texts() -> void:
	var host: Node3D = _host()
	var expect: Dictionary = {&"damage": ["127", "127"], &"crit": ["348", "348"], &"heal": ["45", "+45"],
		&"mp": ["12", "+12 MP"], &"miss": ["", "DANEBEN"], &"weak": ["96", "96"], &"resist": ["8", "8"],
		&"status": ["Gift", "Gift"]}
	var x: float = 0.0
	for style: StringName in Vfx.STYLES:
		Vfx.damage_number(host, Vector3(x, 1, 0), str(expect[style][0]), style)
		x += 2.0
		var l: Label3D = _last_shown(host)
		assert_not_null(l, String(style))
		if l == null:
			continue
		assert_eq(l.text, str(expect[style][1]), "%s text" % style)
		assert_true(l.no_depth_test, "drawn on top")
		assert_eq(l.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
		assert_true(l.visible)
		for i in l.text.length():
			assert_true(ThemeDB.fallback_font.has_char(l.text.unicode_at(i)), "glyph %s" % l.text[i])
	var weak: Label3D = _numbers(host)[5]
	var captions: Array[Label3D] = []
	for l: Label3D in _labels(host):
		if bool(l.get("is_caption")):
			captions.append(l)
	assert_eq(captions.size(), 2, "weak + resist captions are own pool entries (Label3D budget §12.1)")
	if captions.size() == 2:
		assert_eq(captions[0].text, "SCHWACHSTELLE!")
		assert_true(captions[0].visible)
		assert_eq(captions[0].font_size, 40)
		assert_almost(captions[0].position.y - weak.position.y, 0.22, 0.001, "caption above the number")
		assert_eq(captions[1].text, "RESISTENT")
		assert_eq(captions[1].modulate.to_html(false), Palette.PAPER.to_html(false))
	assert_eq(weak.get_child_count(), 0, "no child caption Label3D")
	var crit: Label3D = _numbers(host)[1]
	var dmg: Label3D = _numbers(host)[0]
	assert_gt(crit.font_size, dmg.font_size, "crit bigger than damage")
	assert_ne(crit.modulate, dmg.modulate)
	var heal: Label3D = _numbers(host)[2]
	assert_gt(heal.modulate.g, heal.modulate.r, "heal is green")
	var status: Label3D = _numbers(host)[7]
	assert_eq(status.modulate.to_html(false), Palette.status_color("sts_poison").to_html(false), "status word → color")
	var before: int = _labels(host).size()
	Vfx.damage_number(host, Vector3(20, 1, 0), "0", &"resist")
	assert_eq(_last_shown(host).text, "IMMUN", "resist 0 → IMMUN")
	assert_eq(_labels(host).size(), before + 1, "IMMUN has no caption entry")
	Vfx.damage_number(host, Vector3(22, 1, 0), "5", &"wobble")
	assert_eq(_last_shown(host).text, "5", "unknown style → damage")


func test_damage_number_pool_and_stacking() -> void:
	var host: Node3D = _host()
	for i in 15:
		Vfx.damage_number(host, Vector3(float(i) * 3.0, 1, 0), str(i), &"damage")
	assert_eq(_labels(host).size(), Vfx.DMG_POOL_SIZE, "max 12 Label3D per parent (budget §12.1)")
	for i in 10:
		Vfx.damage_number(host, Vector3(float(i) * 3.0, 1, 2), str(i), &"weak")
	assert_eq(_labels(host).size(), Vfx.DMG_POOL_SIZE, "captions count against the pool too")
	var all_labels: int = 0
	var stack: Array[Node] = [host]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D:
			all_labels += 1
		stack.append_array(n.get_children())
	assert_eq(all_labels, Vfx.DMG_POOL_SIZE, "no hidden child Label3D (≤ 12 Label3D at once)")
	var other: Node3D = _host()
	Vfx.damage_number(other, Vector3.ZERO, "1", &"damage")
	Vfx.damage_number(other, Vector3.ZERO, "2", &"damage")
	var ls: Array[Label3D] = _labels(other)
	assert_eq(ls.size(), 2)
	assert_almost(ls[1].position.y - ls[0].position.y, 0.25, 0.001, "same spot → stacks 0.25 m up")
	var loose := Node3D.new()
	Vfx.damage_number(loose, Vector3(1, 2, 3), "7", &"damage")
	assert_eq(_labels(loose).size(), 1, "works outside the tree")
	assert_true(_labels(loose)[0].position.is_equal_approx(Vector3(1, 2, 3)))
	loose.free()
	Vfx.damage_number(null, Vector3.ZERO, "1", &"damage")


func test_damage_number_rises_and_fades() -> void:
	var host: Node3D = _host()
	host.position = Vector3(0, 0, 5)
	Vfx.damage_number(host, Vector3(0, 1, 5), "42", &"damage")
	var l: Label3D = _labels(host)[0]
	assert_true(l.position.is_equal_approx(Vector3(0, 1, 0)), "global `at` → parent-local")
	l.set_process(false)
	l.call("_process", 0.04)
	assert_gt(l.scale.x, 0.4, "pops")
	l.call("_process", 0.36)
	assert_between(l.position.y, 1.5, 1.8, "rises (ease out)")
	assert_almost(l.modulate.a, 1.0, 0.01, "opaque before the fade")
	l.call("_process", 0.3)
	assert_lt(l.modulate.a, 0.5, "fades in the last 0.25 s")
	l.call("_process", 0.2)
	assert_false(l.visible, "hidden after 0.8 s")
	assert_almost(l.position.y, 1.8, 0.001, "rose 0.8 m")
	assert_false(bool(l.get("active")))
	Vfx.damage_number(host, Vector3(0, 1, 5), "43", &"damage")
	assert_eq(_labels(host).size(), 1, "inactive label reused first")
