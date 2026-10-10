extends Control
## Minimap + big map (02_TECH §1.6, GDD §14.3): visited cells only, zone colour, safe rooms green, stairs gold, boss rooms
## red, closed gates as bars, player arrow (yaw). Same drawing for the 136×136 HUD map and the full-screen map.
## Data: FloorLayout (M3) — while the generator is a stub, `layout_from_def()` builds a display copy from FloorDef.layout.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]   # N E S W
const DOOR_BITS: Array[int] = [1, 2, 4, 8]
const MIN_SPAN_SMALL: int = 5           # the HUD map shows at least 5×5 cells around what is known
const MIN_SPAN_BIG: int = 7
const MAX_CELL_SMALL: float = 26.0
const MAX_CELL_BIG: float = 84.0

var layout: FloorLayout = null
var visited: Array[Vector2i] = []
var player_cell: Vector2i = Vector2i(-1, -1)
var player_yaw: float = 0.0
var big: bool = false
var show_unvisited: bool = false        # debug/capture: draw every cell
var swatch_kind: String = ""            # legend swatch: "player" | "start" | "safe" | "stairs" | "boss" | "gate"
var _blink: float = 0.0
## Everything goes out as ONE triangle array (icon_mesh.gd, 02_TECH §12.1: before, every cell, door, marker and gate
## was its own canvas draw call — ~150 with the whole floor visited). The cell layer is cached until the view, the
## visited cells, the opened gates or the size change; only the pulsing player arrow is rebuilt every frame.
var _cells_mesh: IconMesh = null
var _cells_key: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Legend swatch for the big map: one cell drawn exactly like the map draws `p_kind` (same colours + marker).
static func swatch(p_kind: String, p_size: float = 30.0) -> Control:
	var c: Control = (load("res://scenes/ui/minimap.gd") as GDScript).new() as Control
	c.set("swatch_kind", p_kind)
	c.custom_minimum_size = Vector2(p_size, p_size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func bind(p_layout: FloorLayout, p_visited: Array[Vector2i]) -> void:
	layout = p_layout
	visited = p_visited.duplicate()
	_cells_mesh = null
	queue_redraw()


func set_player(cell: Vector2i, yaw_rad: float) -> void:
	if cell == player_cell and is_equal_approx(yaw_rad, player_yaw):
		return
	player_cell = cell
	player_yaw = yaw_rad
	queue_redraw()


func mark_visited(cell: Vector2i) -> void:
	if not visited.has(cell):
		visited.append(cell)
		queue_redraw()


func visited_count() -> int:
	return visited.size()


func _process(delta: float) -> void:
	_blink += delta
	if player_cell.x >= 0:
		queue_redraw()


## Display copy of a hand-built layout (cells, zones, gates, safe rooms, stairs) from FloorDef.layout.
static func layout_from_def(def: FloorDef) -> FloorLayout:
	if def == null or def.layout.is_empty():
		return null
	var fl: FloorLayout = FloorLayout.new()
	fl.floor_index = def.index
	fl.width = int(def.grid.get("w", 8))
	fl.height = int(def.grid.get("h", 8))
	for z: Variant in def.layout.get("zones", []):
		var zd: Dictionary = z
		fl.zones[str(zd.get("id", ""))] = {"name": str(zd.get("name", "")), "palette": zd.get("palette", {})}
	var kinds: Dictionary = {"start": 0, "normal": 1, "safe": 2, "quarter_boss": 3, "floor_boss": 4, "stairs": 5,
		"gate": 6}
	for c: Variant in def.layout.get("cells", []):
		var cd: Dictionary = c
		var rc: RoomCell = RoomCell.new()
		rc.coord = Vector2i(int(cd.get("x", 0)), int(cd.get("y", 0)))
		rc.kind = int(kinds.get(str(cd.get("kind", "normal")), 1)) as RoomCell.Kind
		rc.zone = str(cd.get("zone", ""))
		var doors: int = 0
		var ds: String = str(cd.get("doors", ""))
		for i in 4:
			if ds.contains("NESW"[i]):
				doors |= DOOR_BITS[i]
		rc.doors = doors
		fl.cells[rc.coord] = rc
		if rc.kind == RoomCell.Kind.START:
			fl.start = rc.coord
		elif rc.kind == RoomCell.Kind.STAIRS:
			fl.stairs = rc.coord
	for g: Variant in def.layout.get("gates", []):
		var gd: Dictionary = g
		var cell: Array = gd.get("cell", [0, 0])
		var dir_s: String = str(gd.get("dir", "N"))
		var bit: int = DOOR_BITS["NESW".find(dir_s)] if "NESW".find(dir_s) >= 0 else 1
		fl.gates.append({"cell": Vector2i(int(cell[0]), int(cell[1])), "dir": bit, "requires": str(gd.get("requires", "")),
			"key": "%d,%d,%s" % [int(cell[0]), int(cell[1]), dir_s]})
	for sv: Variant in def.layout.get("secrets", []):          # 06 package A: Kulissenwände (hidden until opened)
		var sd: Dictionary = sv
		if str(sd.get("kind", "")) != "wall":
			continue
		var scell: Array = sd.get("cell", [0, 0])
		var sdir: String = str(sd.get("dir", "N"))
		var sbit: int = DOOR_BITS["NESW".find(sdir)] if "NESW".find(sdir) >= 0 else 1
		fl.gates.append({"cell": Vector2i(int(scell[0]), int(scell[1])), "dir": sbit,
			"requires": Secrets.REQUIRES_PREFIX + str(sd.get("id", "")), "key": Secrets.gate_key_of(sd)})
	for sr: Variant in def.layout.get("safe_rooms", []):
		var sd: Dictionary = sr
		var cell: Array = sd.get("cell", [0, 0])
		var v: Vector2i = Vector2i(int(cell[0]), int(cell[1]))
		fl.safe_rooms.append(v)
		fl.safe_room_ids[v] = str(sd.get("id", ""))
	return fl


func _draw() -> void:
	build_mesh().commit(self)


## The whole map (or legend swatch) as one IconMesh in drawing order. Headless tests use it directly.
func build_mesh() -> IconMesh:
	var m: IconMesh = IconMesh.new()
	if swatch_kind != "":
		_mesh_swatch(m)
		return m
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	m.rect(r, Color(UiTheme.C_PANEL, 0.78 if not big else 0.55))
	m.rect_outline(r, Color(UiTheme.C_ACCENT_2, 0.6 if not big else 0.35), 2.0)
	if layout == null or layout.width <= 0 or layout.height <= 0:
		return m
	var pad: float = 8.0 if not big else 24.0
	var view: Rect2 = view_cells()
	var cs: float = minf((size.x - pad * 2.0) / view.size.x, (size.y - pad * 2.0) / view.size.y)
	cs = minf(cs, MAX_CELL_BIG if big else MAX_CELL_SMALL)
	var origin: Vector2 = size * 0.5 - (view.position + view.size * 0.5) * cs
	var opened: PackedStringArray = []
	if Game.state != null and Game.state.floor_run != null:
		opened = Game.state.floor_run.opened_gates
	var key: String = "%s|%s|%d|%d|%s" % [size, view, visited.size(), opened.size(), show_unvisited]
	if _cells_mesh == null or key != _cells_key:
		_cells_mesh = _mesh_cells(origin, cs, opened)
		_cells_key = key
	m.append(_cells_mesh)
	if player_cell.x >= 0 and layout.cells.has(player_cell):
		var pc: Vector2 = origin + (Vector2(player_cell) + Vector2(0.5, 0.5)) * cs
		var fwd: Vector2 = Vector2(-sin(player_yaw), -cos(player_yaw))
		var side: Vector2 = Vector2(-fwd.y, fwd.x)
		var alen: float = cs * 0.32
		var pulse: float = 0.8 + 0.2 * sin(_blink * TAU * 1.5)
		var pts: PackedVector2Array = [pc + fwd * alen, pc - fwd * alen * 0.6 + side * alen * 0.7,
			pc - fwd * alen * 0.25, pc - fwd * alen * 0.6 - side * alen * 0.7]
		m.circle(pc, alen * 1.25, Color(UiTheme.C_ACCENT_2, 0.25 * pulse), true)
		m.poly(pts, UiTheme.C_ACCENT_2)
		m.polyline(pts, UiUtil.C_INK, 1.5, true)
	return m


## Cells (zone colour + frame), door stubs, kind markers and gate bars.
func _mesh_cells(origin: Vector2, cs: float, opened: PackedStringArray) -> IconMesh:
	var m: IconMesh = IconMesh.new()
	var gap: float = maxf(1.5, cs * 0.14)
	for key: Variant in layout.cells.keys():
		var cell: Vector2i = key
		var rc: RoomCell = layout.cells[key] as RoomCell
		if rc == null or (not show_unvisited and not visited.has(cell)):
			continue
		var cr: Rect2 = Rect2(origin + Vector2(cell) * cs + Vector2(gap, gap), Vector2(cs - gap * 2.0, cs - gap * 2.0))
		m.rect(cr, _cell_color(rc))
		m.rect_outline(cr, Color(1, 1, 1, 0.18), 1.0)
		for i in 4:
			if rc.doors & DOOR_BITS[i] and not _closed_secret(cell, DOOR_BITS[i], opened):
				_mesh_door(m, origin, cs, gap, cell, i, _cell_color(rc))
		_mesh_marker(m, cr, rc)
	for g: Dictionary in layout.gates:
		var gcell: Vector2i = g.get("cell", Vector2i.ZERO)
		if not show_unvisited and not visited.has(gcell):
			continue
		if Secrets.is_secret_requirement(str(g.get("requires", ""))):
			continue                            # a Kulissenwand: wall while it stands, a plain door once it fell
		var key_s: String = str(g.get("key", ""))
		var col: Color = UiTheme.C_DANGER if not opened.has(key_s) else Color(UiTheme.C_OK, 0.6)
		var i: int = DOOR_BITS.find(int(g.get("dir", 1)))
		if i < 0:
			continue
		var center: Vector2 = origin + (Vector2(gcell) + Vector2(0.5, 0.5)) * cs
		var d: Vector2 = Vector2(DIRS[i]) * (cs * 0.5)
		var across: Vector2 = Vector2(-DIRS[i].y, DIRS[i].x) * (cs * 0.28)
		m.line(center + d - across, center + d + across, col, maxf(3.0, cs * 0.14))
	return m


## Cell-space rect that is drawn: bounding box of the shown cells (visited, or all with show_unvisited) and the player,
## grown to a minimum span and centered, so small explored areas are zoomed in instead of hugging a grid corner.
func view_cells() -> Rect2:
	if layout == null:
		return Rect2(0, 0, 1, 1)
	var has_any: bool = false
	var lo: Vector2i = Vector2i.ZERO
	var hi: Vector2i = Vector2i.ZERO
	var pts: Array[Vector2i] = []
	for key: Variant in layout.cells.keys():
		var c: Vector2i = key
		if show_unvisited or visited.has(c):
			pts.append(c)
	if player_cell.x >= 0 and layout.cells.has(player_cell):
		pts.append(player_cell)
	for c2: Vector2i in pts:
		if not has_any:
			lo = c2
			hi = c2
			has_any = true
		else:
			lo = Vector2i(mini(lo.x, c2.x), mini(lo.y, c2.y))
			hi = Vector2i(maxi(hi.x, c2.x), maxi(hi.y, c2.y))
	if not has_any:
		return Rect2(0, 0, float(layout.width), float(layout.height))
	var span: float = float(MIN_SPAN_BIG if big else MIN_SPAN_SMALL)
	var bb: Rect2 = Rect2(Vector2(lo), Vector2(hi - lo) + Vector2.ONE)
	var center: Vector2 = bb.get_center()
	var w: float = maxf(bb.size.x, span)
	var h: float = maxf(bb.size.y, span)
	if not big:
		w = maxf(w, h)      # square HUD map
		h = w
	return Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))


func _mesh_swatch(m: IconMesh) -> void:
	var cs: float = minf(size.x, size.y)
	var gap: float = maxf(1.5, cs * 0.1)
	var cr: Rect2 = Rect2((size - Vector2(cs, cs)) * 0.5 + Vector2(gap, gap), Vector2(cs - gap * 2.0, cs - gap * 2.0))
	var rc: RoomCell = RoomCell.new()
	rc.kind = {"safe": RoomCell.Kind.SAFE, "stairs": RoomCell.Kind.STAIRS, "boss": RoomCell.Kind.QUARTER_BOSS,
		"start": RoomCell.Kind.START}.get(swatch_kind, RoomCell.Kind.NORMAL) as RoomCell.Kind
	m.rect(cr, _cell_color(rc))
	m.rect_outline(cr, Color(1, 1, 1, 0.18), 1.0)
	_mesh_marker(m, cr, rc)
	var c: Vector2 = cr.get_center()
	if swatch_kind == "gate":
		m.line(c + Vector2(cs * 0.5 - 1.0, -cs * 0.28), c + Vector2(cs * 0.5 - 1.0, cs * 0.28), UiTheme.C_DANGER,
			maxf(3.0, cs * 0.14))
	elif swatch_kind == "player":
		var alen: float = cs * 0.32
		var pts: PackedVector2Array = [c + Vector2(0, -alen), c + Vector2(alen * 0.7, alen * 0.6),
			c + Vector2(0, alen * 0.25), c + Vector2(-alen * 0.7, alen * 0.6)]
		m.poly(pts, UiTheme.C_ACCENT_2)
		m.polyline(pts, UiUtil.C_INK, 1.5, true)


func _cell_color(rc: RoomCell) -> Color:
	match rc.kind:
		RoomCell.Kind.SAFE:
			return Color(UiUtil.C_EXIT, 0.85)
		RoomCell.Kind.STAIRS:
			return Color("#6a5a20")
		RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS:
			return Color("#5a1f2a")
	var base: Color = Color("#3a3f5b")
	if layout != null and layout.zones.has(rc.zone):
		var pal: Dictionary = (layout.zones[rc.zone] as Dictionary).get("palette", {})
		var hexs: String = str(pal.get("floor", ""))
		if hexs.is_valid_html_color():
			base = Color.from_string(hexs, base)
	return base.lightened(0.28)


## 06 package A: is the door `bit` of `cell` a Kulissenwand that still stands? (drawn as wall: no door stub)
func _closed_secret(cell: Vector2i, bit: int, opened: PackedStringArray) -> bool:
	var g: Dictionary = layout.gate_at(cell, bit)
	return not g.is_empty() and Secrets.is_secret_requirement(str(g.get("requires", ""))) \
		and not opened.has(str(g.get("key", "")))


func _mesh_door(m: IconMesh, origin: Vector2, cs: float, gap: float, cell: Vector2i, i: int, col: Color) -> void:
	var center: Vector2 = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cs
	var d: Vector2 = Vector2(DIRS[i])
	var w: float = maxf(2.0, cs * 0.26)
	var a: Vector2 = center + d * (cs * 0.5 - gap - 0.5)
	var b: Vector2 = center + d * (cs * 0.5 + 0.5)
	m.line(a, b, col, w)


func _mesh_marker(m: IconMesh, cr: Rect2, rc: RoomCell) -> void:
	var c: Vector2 = cr.get_center()
	var s: float = cr.size.x * 0.28
	match rc.kind:
		RoomCell.Kind.STAIRS:
			for i in 3:
				m.rect(Rect2(c + Vector2(-s + i * s * 0.4, -s * 0.6 + i * s * 0.45), Vector2(s * 2.0 - i * s * 0.8,
					s * 0.38)), UiTheme.C_GOLD)
		RoomCell.Kind.SAFE:
			m.rect(Rect2(c - Vector2(s * 0.25, s * 0.8), Vector2(s * 0.5, s * 1.6)), UiUtil.C_PAPER)
			m.rect(Rect2(c - Vector2(s * 0.8, s * 0.25), Vector2(s * 1.6, s * 0.5)), UiUtil.C_PAPER)
		RoomCell.Kind.QUARTER_BOSS, RoomCell.Kind.FLOOR_BOSS:
			m.circle(c, s * 0.8, UiTheme.C_DANGER, true)
			m.circle(c, s * 0.35, UiUtil.C_INK, true)
		RoomCell.Kind.START:
			m.ring(c, s * 0.45, Color(UiUtil.C_PAPER, 0.7), 2.0, true)
