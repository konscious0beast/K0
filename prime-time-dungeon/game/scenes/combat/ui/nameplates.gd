extends Control
## Enemy name plates of the real-time HUD (07 §8.5): 2D, projected with Camera3D.unproject_position to head height +
## 0.4 m for every enemy in the combat: HP bar 64 × 6, cast bar 64 × 4 only while casting (tier colours of 07 §6.2), up
## to 3 status dots in status colour and — after the player's first own taunt — a target dot on the left in the colour
## of the attacked party member (party.json portrait_color). The name only for the current target, elites and bosses;
## the current target gets a cyan frame and a marker. Hidden behind the camera, outside the picture and beyond 20 m.
## Plates of a melee pile stack upwards instead of covering each other (stack()).
## Draw calls (07 §8.5, measured: 8 plates = 2): every bar / dot = ONE triangle array + at most 8 outline-free labels.
## World positions come from the CombatDirector (unit_position, interpolated). Private R3 script.

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")

const BAR: Vector2 = Vector2(64, 6)
const CAST_H: float = 4.0
const HEAD_LIFT: float = 0.4
const MAX_DIST: float = 20.0
const MAX_LABELS: int = 8
const PICK_RADIUS: float = 53.5             # ≥ 107 px tap / click area (03_ART §9.4)

var sim: RtSim = null
var director: Node = null
var camera: Camera3D = null
var threat_revealed: bool = false
## Canvas rect of the top-centre frames (boss / target): a plate that would sit under them moves just below (a tall
## boss close to the camera projects its plate into the frames). Rect2() = none.
var blocked: Rect2 = Rect2()
## unit id → screen info {"head": Vector2, "foot": Vector2, "rect": Rect2} of the last frame (picking, tests).
var plates: Dictionary = {}

var _labels: Array[Label] = []
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_LABELS:
		var l: Label = CombatStyle.label("", 13, CombatStyle.C_TEXT, true)
		l.name = "Name%d" % i
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.visible = false
		add_child(l)
		_labels.append(l)


## Head height of a unit in metres: the director's own value when it offers one (unit_height), else from the radius
## (rat 30 cm ≈ 1.0 m, boss 90 cm ≈ 2.9 m).
func head_height(u: RtUnit) -> float:
	if director != null and director.has_method("unit_height"):
		return float(director.call("unit_height", u.id))
	return clampf(float(u.radius) * 0.032, 0.8, 3.4)


func world_position(id: String) -> Vector3:
	if director != null and director.has_method("unit_position"):
		return director.call("unit_position", id) as Vector3
	return Vector3.ZERO


func _process(delta: float) -> void:
	_t += delta


## Recomputes the plates (called by the HUD every frame after the frames).
func refresh() -> void:
	plates.clear()
	for l: Label in _labels:
		l.visible = false
	if sim == null or camera == null or not is_instance_valid(camera):
		queue_redraw()
		return
	var ctl: RtUnit = CombatView.controlled(sim)
	var target: String = ctl.target_id if ctl != null else ""
	var vp: Rect2 = get_viewport_rect()
	var cam_pos: Vector3 = camera.global_position
	var shown: Array[Dictionary] = []
	for e: RtUnit in CombatView.enemies(sim):
		var foot: Vector3 = world_position(e.id)
		var head: Vector3 = foot + Vector3(0.0, head_height(e) + HEAD_LIFT, 0.0)
		if camera.is_position_behind(head) or cam_pos.distance_to(head) > MAX_DIST:
			continue
		var sp: Vector2 = camera.unproject_position(head)
		if not vp.grow(40.0).has_point(sp):
			continue
		var fp: Vector2 = camera.unproject_position(foot) if not camera.is_position_behind(foot) else sp
		shown.append({"id": e.id, "head": sp, "foot": fp, "target": e.id == target,
			"named": (e.id == target and not e.is_boss) or _elite(e)})
	stack(shown)
	for p: Dictionary in shown:
		var sp: Vector2 = p["head"]
		var reach: Rect2 = Rect2(sp - Vector2(90.0, 30.0), Vector2(180.0, 42.0))   # plate + name above it
		if blocked.size.x > 0.0 and reach.intersects(blocked):
			sp.y = blocked.end.y + 30.0
		var rect: Rect2 = Rect2(sp - Vector2(BAR.x * 0.5, BAR.y * 0.5), BAR).grow(6.0)
		plates[p["id"]] = {"head": sp, "foot": p["foot"], "rect": rect, "target": p["target"]}
	var li: int = 0
	for id: Variant in plates.keys():
		var u: RtUnit = sim.unit(str(id))
		var info: Dictionary = plates[id]
		var named: bool = (bool(info["target"]) and not u.is_boss) or _elite(u)   # bosses: the boss frame names them
		if not named or li >= MAX_LABELS:
			continue
		var l: Label = _labels[li]
		li += 1
		l.text = UiUtilRef.glyph_safe(CombatStyle.unit_name(u, sim.units()))
		l.add_theme_color_override("font_color", CombatStyle.C_CYAN.lightened(0.4) if bool(info["target"])
			else CombatStyle.C_TEXT)
		l.size = Vector2(180, 18)
		l.position = (info["head"] as Vector2) + Vector2(-90.0, -24.0)
		l.visible = true
	queue_redraw()


## Screen box of a plate at head point `sp`: threat dot left, status dots right, cast bar below, name + marker above a
## named plate.
static func plate_box(sp: Vector2, named: bool) -> Rect2:
	var top: float = sp.y - (32.0 if named else 5.0)
	return Rect2(sp.x - BAR.x * 0.5 - 14.0, top, BAR.x + 40.0, sp.y + 11.0 - top)


## Stacks close plates (enemies in a melee pile): from the bottom of the screen up, a plate that would overlap one
## placed before moves up just above it. `shown`: [{"head": Vector2, "named": bool, …}], head changed in place.
static func stack(shown: Array[Dictionary]) -> void:
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["head"] as Vector2).y > (b["head"] as Vector2).y)
	var placed: Array[Rect2] = []
	for p: Dictionary in shown:
		var sp: Vector2 = p["head"]
		for _i in 8:
			var box: Rect2 = plate_box(sp, bool(p["named"]))
			var hit: bool = false
			for q: Rect2 in placed:
				if box.intersects(q):
					sp.y -= box.end.y - q.position.y + 2.0
					hit = true
					break
			if not hit:
				break
		p["head"] = sp
		placed.append(plate_box(sp, bool(p["named"])))


static func _elite(u: RtUnit) -> bool:
	return CombatStyle.gd().has_id("enemies", u.def_id) and CombatStyle.gd().enemy(u.def_id).tags.has("elite")


## The enemy under a screen point (plate or projected foot point within 107 px), "" if none — nearest wins (07 §7.4).
func pick(screen_pos: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: Variant in plates.keys():
		var info: Dictionary = plates[id]
		var d: float = INF
		if (info["rect"] as Rect2).has_point(screen_pos):
			d = 0.0
		else:
			d = minf((info["foot"] as Vector2).distance_to(screen_pos), (info["head"] as Vector2).distance_to(screen_pos))
			if d > PICK_RADIUS:
				continue
		if d < best_d:
			best_d = d
			best = str(id)
	return best


func _draw() -> void:
	if plates.is_empty():
		return
	var m: IconMesh = IconMesh.new()
	for id: Variant in plates.keys():
		var u: RtUnit = sim.unit(str(id))
		if u == null:
			continue
		var info: Dictionary = plates[id]
		var c: Vector2 = info["head"]
		var bar: Rect2 = Rect2(c - BAR * 0.5, BAR)
		var tgt: bool = bool(info["target"])
		m.rect(bar.grow(1.0), Color(CombatStyle.C_INK, 0.85))
		var ratio: float = clampf(float(u.hp) / float(maxi(1, u.max_hp())), 0.0, 1.0)
		m.rect(Rect2(bar.position, Vector2(BAR.x * ratio, BAR.y)), CombatStyle.C_ENEMY)
		if tgt:
			m.rect_outline(bar.grow(2.5), CombatStyle.C_CYAN, 2.0)
			var bob: float = 2.0 * sin(_t * 5.0)
			m.poly(PackedVector2Array([c + Vector2(-6, -30 + bob), c + Vector2(6, -30 + bob), c + Vector2(0, -22 + bob)]),
				CombatStyle.C_CYAN)
		var cs: Dictionary = CombatView.cast(sim, u)
		if not cs.is_empty():
			var cr: Rect2 = Rect2(bar.position + Vector2(0, BAR.y + 3.0), Vector2(BAR.x, CAST_H))
			var fill: Color = Color("#b9b0c8")
			var border: Color = CombatStyle.C_GREY
			if cs["tier"] == &"worthy":
				fill = CombatStyle.C_GOLD
				border = CombatStyle.C_GOLD
			elif cs["tier"] == &"open":
				fill = CombatStyle.C_PAPER
				border = CombatStyle.C_PAPER
			m.rect(cr.grow(1.0), border)
			m.rect(cr, Color(0, 0, 0, 0.8))
			m.rect(Rect2(cr.position, Vector2(BAR.x * float(cs["ratio"]), CAST_H)), fill)
		var sts: Array[Dictionary] = CombatView.statuses(sim, u)
		for i in mini(sts.size(), 3):
			m.circle(Vector2(bar.end.x + 6.0 + 8.0 * i, c.y), 3.0, sts[i]["color"] as Color, true)
		if threat_revealed:
			var tc: Color = CombatView.threat_color(sim, u)
			if tc.a > 0.0:
				m.circle(Vector2(bar.position.x - 8.0, c.y), 4.5, Color(CombatStyle.C_INK, 0.9), true)
				m.circle(Vector2(bar.position.x - 8.0, c.y), 3.5, tc, true)
	m.commit(self)


const UiUtilRef := preload("res://scenes/ui/ui_util.gd")
