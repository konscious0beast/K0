class_name Vfx extends RefCounted
## Effects + damage numbers (02_TECH §8.6, 03_ART §7). Only CPUParticles3D + small helper meshes; no static state:
## the pool lives as meta on the parent (`vfx_pool`: kind → Array[Node3D], max 4 per kind; `dmg_pool`: max 12 Label3D)
## and dies with it (03_ART A12). Pool entries are reused when valid and still children of the parent (oldest first).

const KINDS: Array[StringName] = [&"hit", &"crit", &"slash", &"bite", &"magic", &"fire", &"ice", &"shock", &"toxic",
	&"light", &"dark", &"heal", &"buff", &"debuff", &"ko", &"levelup", &"sponsor", &"confetti", &"smoke", &"sparkle",
	&"stairs_glow", &"chest_open"]
const DURATIONS: Dictionary = {&"hit": 0.30, &"crit": 0.40, &"slash": 0.30, &"bite": 0.30, &"magic": 0.60,
	&"fire": 0.60, &"ice": 0.60, &"shock": 0.30, &"toxic": 1.00, &"light": 0.80, &"dark": 0.80, &"heal": 0.80,
	&"buff": 0.70, &"debuff": 0.70, &"ko": 1.00, &"levelup": 1.50, &"sponsor": 1.50, &"confetti": 1.20, &"smoke": 1.00,
	&"sparkle": 0.50, &"stairs_glow": 1.50, &"chest_open": 0.80}
## Kinds that keep running after spawn (03_ART §7: stairs_glow is the loop variant).
const LOOPING: Array[StringName] = [&"stairs_glow"]
const POOL_PER_KIND: int = 4
const DMG_POOL_SIZE: int = 12
const POOL_META: StringName = &"vfx_pool"
const DMG_META: StringName = &"dmg_pool"
const STYLES: Array[StringName] = [&"damage", &"crit", &"heal", &"mp", &"miss", &"weak", &"resist", &"status"]

const VfxNode := preload("res://art/kit/vfx_node.gd")
const DamageNumber := preload("res://art/kit/damage_number.gd")


## Pooled: 4 instances per kind per parent (03_ART §7); reuses the oldest via restart(); placed at global `at`
## (local when the parent is outside the tree); returns the node; callers NEVER free it (the pool owns it and hides it
## after duration(kind)); color.a == 0 → kind default.
static func spawn(kind: StringName, parent: Node, at: Vector3, color: Color = Color(0, 0, 0, 0),
		scale: float = 1.0) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		push_warning("Vfx.spawn(%s): no parent" % kind)
		return null
	if not KINDS.has(kind):
		push_warning("Vfx.spawn: unknown kind '%s'" % kind)
		return null
	var pool: Dictionary = parent.get_meta(POOL_META, {}) if parent.has_meta(POOL_META) else {}
	var list: Array = pool.get(kind, [])
	var valid: Array = []
	for n: Variant in list:
		if is_instance_valid(n) and (n as Node).get_parent() == parent:
			valid.append(n)
	var node: Node3D
	if valid.size() < POOL_PER_KIND:
		node = VfxNode.new()
		node.call("setup", kind, duration(kind), LOOPING.has(kind))
		parent.add_child(node)
	else:
		node = valid.pop_front()
	valid.append(node)
	pool[kind] = valid
	parent.set_meta(POOL_META, pool)
	if node.is_inside_tree():
		node.global_position = at
	else:
		node.position = at
	node.call("play", color, scale)
	return node


## 0.3 .. 1.5 s
static func duration(kind: StringName) -> float:
	return float(DURATIONS.get(kind, 0.5))


## skill.vfx or element default: physical → &"slash", fire/ice/shock → same, poison → &"toxic", heal → &"heal",
## buff/debuff category → &"buff"/&"debuff"; &"light"/&"dark" are presentation-only kinds
static func for_skill(skill: SkillDef) -> StringName:
	if skill == null:
		return &"hit"
	if skill.vfx != "" and KINDS.has(StringName(skill.vfx)):
		return StringName(skill.vfx)
	if skill.category == "heal" or skill.damage_type == "heal":
		return &"heal"
	if skill.category == "buff":
		return &"buff"
	if skill.category == "debuff":
		return &"debuff"
	match skill.element:
		"physical":
			return &"slash"
		"fire":
			return &"fire"
		"ice":
			return &"ice"
		"shock":
			return &"shock"
		"poison":
			return &"toxic"
	if skill.category == "magic":
		return &"magic"
	return &"hit"


## Label3D billboard, no_depth_test, rises 0.8 m in 0.8 s; style &"damage", &"crit", &"heal", &"mp", &"miss", &"weak",
## &"resist", &"status". Pooled per parent (max 12 Label3D incl. captions, which take their own entry); numbers at the
## same spot stack 0.25 m upwards. With a real renderer each entry draws through its 2D screen twin (damage_number.gd).
static func damage_number(parent: Node, at: Vector3, text: String, style: StringName) -> void:
	if parent == null or not is_instance_valid(parent):
		push_warning("Vfx.damage_number: no parent")
		return
	if not STYLES.has(style):
		push_warning("Vfx.damage_number: unknown style '%s' → damage" % style)
		style = &"damage"
	var pool: Array = parent.get_meta(DMG_META, []) if parent.has_meta(DMG_META) else []
	var valid: Array = []
	for n: Variant in pool:
		if is_instance_valid(n) and (n as Node).get_parent() == parent:
			valid.append(n)
	# local position of `at` in parent space
	var local: Vector3 = at
	if parent is Node3D and (parent as Node3D).is_inside_tree():
		local = (parent as Node3D).global_transform.affine_inverse() * at
	var stacked: int = 0
	for n: Variant in valid:
		var l: Label3D = n
		if bool(l.get("active")) and not bool(l.get("is_caption")) \
				and Vector2(l.position.x - local.x, l.position.z - local.z).length() < 0.3 and float(l.get("_t")) < 0.35:
			stacked += 1
	var pos: Vector3 = local + Vector3(0, 0.25 * float(stacked), 0)
	var caption: String = DamageNumber.caption_for(text, style)
	var cap: Label3D = null
	if caption != "":
		cap = _acquire_number(parent, valid)
	var label: Label3D = _acquire_number(parent, valid, cap)   # the number is the newest pool entry
	if cap != null:
		cap.call("show_caption", caption, style, pos)
	label.call("show_number", text, style, pos)
	parent.set_meta(DMG_META, valid)


## Free (inactive) pool entry, a new one while below DMG_POOL_SIZE, else the oldest (never `keep`); moved to the back.
static func _acquire_number(parent: Node, valid: Array, keep: Label3D = null) -> Label3D:
	var label: Label3D = null
	for n: Variant in valid:
		if n != keep and not bool((n as Label3D).get("active")):
			label = n
			break
	if label == null:
		if valid.size() < DMG_POOL_SIZE:
			label = DamageNumber.new()
			label.name = "DamageNumber%d" % valid.size()
			parent.add_child(label)
		else:
			for n: Variant in valid:
				if n != keep:
					label = n
					break
	valid.erase(label)
	valid.append(label)
	return label


# --- Echtzeitkampf (07, R3): combat text styles (07 §8.6) -------------------------------------------------------------
# rt_dealt (white; a crit gold, 130 % with "!"), rt_taken (red), rt_heal (green), rt_partner (75 %: the partner's auto
# attacks), rt_word (words in the caller's colour: "UNTERBROCHEN!" gold 26 px, "AUSGEWICHEN" cyan, "KNAPP!", "IMMUN",
# "WIDERSTAND", "SCHWACH!"). Same pool and 2D screen twins (CanvasLayer 4) as damage_number, but a fixed screen size
# (× GameSettings.floating_text_scale) and 0.6 s life; at most RT_MAX at once — the oldest makes room. Only ASCII and
# German letters (03_ART F8).

const RT_STYLES: Array[StringName] = [&"rt_dealt", &"rt_taken", &"rt_heal", &"rt_partner", &"rt_word"]
const RT_MAX: int = 10
const RT_LIFE: float = 0.6
## style → [screen px, colour]
const RT_LOOK: Dictionary = {&"rt_dealt": [20, "#ffffff"], &"rt_taken": [20, "#ff4d4d"], &"rt_heal": [20, "#6bff8a"],
	&"rt_partner": [15, "#e6e0f0"], &"rt_word": [22, "#ffc93c"]}
const RT_CRIT_COLOR: String = "#ffd23c"


## Shows one real-time combat text at global `at` (a node in the 3D world; its viewport camera projects the twin).
## `crit` (rt_dealt): gold, 130 %, "!" and a tilt; `color.a > 0` overrides the style colour (rt_word); `px` > 0
## overrides the size (rt_word "UNTERBROCHEN!" 26); `scale_pct` = GameSettings.floating_text_scale (100/125/150).
static func combat_text(parent: Node, at: Vector3, text: String, style: StringName, scale_pct: int = 100,
		crit: bool = false, color: Color = Color(0, 0, 0, 0), px: int = 0) -> void:
	if parent == null or not is_instance_valid(parent):
		push_warning("Vfx.combat_text: no parent")
		return
	if not RT_STYLES.has(style):
		style = &"rt_dealt"
	var look: Array = RT_LOOK[style]
	var size: float = float(px if px > 0 else int(look[0]))
	var col: Color = color if color.a > 0.0 else Palette.hex(str(look[1]))
	var shown: String = text
	var tilt: float = 0.0
	if crit and style == &"rt_dealt":
		size *= 1.3
		col = Palette.hex(RT_CRIT_COLOR)
		shown += "!"
		tilt = 6.0
	size *= clampf(float(scale_pct) / 100.0, 0.5, 2.0)
	var pool: Array = parent.get_meta(DMG_META, []) if parent.has_meta(DMG_META) else []
	var valid: Array = []
	for n: Variant in pool:
		if is_instance_valid(n) and (n as Node).get_parent() == parent:
			valid.append(n)
	var active: Array = []
	for n: Variant in valid:
		if bool((n as Label3D).get("active")):
			active.append(n)
	if active.size() >= RT_MAX:                           # the oldest text gives way (07 §8.6)
		(active[0] as Label3D).set("active", false)
		(active[0] as Label3D).visible = false
		(active[0] as Label3D).call("_update_screen")
	var local: Vector3 = at
	if parent is Node3D and (parent as Node3D).is_inside_tree():
		local = (parent as Node3D).global_transform.affine_inverse() * at
	var stacked: int = 0
	for n: Variant in active:
		var l: Label3D = n
		if bool(l.get("active")) and Vector2(l.position.x - local.x, l.position.z - local.z).length() < 0.3 \
				and float(l.get("_t")) < 0.3:
			stacked += 1
	var label: Label3D = _acquire_number(parent, valid)
	label.call("show_rt", shown, roundi(size), col, RT_LIFE, tilt, local + Vector3(0, 0.22 * float(stacked), 0))
	parent.set_meta(DMG_META, valid)


## Active real-time texts under `parent` (tests).
static func combat_text_count(parent: Node) -> int:
	var n: int = 0
	if parent == null or not parent.has_meta(DMG_META):
		return 0
	for e: Variant in (parent.get_meta(DMG_META) as Array):
		if is_instance_valid(e) and bool((e as Label3D).get("active")):
			n += 1
	return n
