extends Control
## Selection overlays of the casting's Steckbrief (08 §1.3, K1; private helper, no class_name), modal and owned by the
## page: mode "origin" = VORLEBEN WÄHLEN (23 tiles + "Anderes …"; a tile with "genauer" chips keeps the overlay open
## for an optional second tap, else one tap chooses and closes), "hobby" = HOBBY / TALENT WÄHLEN (17 tiles +
## "Anderes …"), "traits" = EIGENSCHAFTEN (12 chips, 0–3; a fourth tap replaces the oldest; empty is fine). Tiles are
## framed, >= 180 × 88 px (visible = hit area), 12 px apart (02_TECH §10.2 rule 5), names on up to two lines (the two
## longest on three); the grid shows 6 columns and fewer when the text is larger (130 %) or the screen narrower — then
## it scrolls instead of overlapping.
## Esc / B / "Fertig" close it (traits: the chips as they are).

signal origin_picked(origin: String, occupation: String)
signal hobby_picked(hobby: String)
signal traits_picked(traits: PackedStringArray)
signal custom_requested(kind: String)
signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const CUSTOM: String = "custom"
const ALLROUND: String = "org_allround"
const TILE_W: float = 180.0
const TILE_VISIBLE: float = 64.0
const GAP: int = 12
const MAX_COLUMNS: int = 6
const MAX_TRAITS: int = 3
## Break points of the long words in tile names ("|" → soft hyphen): words of 12+ letters do not fit a tile line at 22
## px in six columns; shorter ones never break (they move to the next line whole).
const HYPHENS: Dictionary = {"Landwirtschaft": "Land|wirt|schaft", "Hausmeisterei": "Haus|meisterei",
	"Selbstständig": "Selbst|ständig", "Neuorientierung": "Neu|orien|tierung", "Fotografieren": "Foto|grafieren",
	"Kartenspiele": "Karten|spiele", "naturverbunden": "natur|verbunden", "genießerisch": "genie|ßerisch",
	"schlagfertig": "schlag|fertig"}

var mode: String = "origin"
var text_scale: float = 1.0
## The current choice: origin / occupation (mode origin), hobby (mode hobby), traits in tap order (mode traits).
var origin: String = ""
var occupation: String = ""
var hobby: String = ""
var traits: PackedStringArray = []
## id → Button of the tiles / chips (tests): origins, hobbies or traits; CUSTOM = "Anderes …".
var tiles: Dictionary = {}
var chips: Dictionary = {}                   # occupation id → Button (mode origin)

var _params: Dictionary = {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _chip_box: HBoxContainer
var _chip_row: HFlowContainer
var _done: Button
var _none: Button
var _closed: bool = false


## {"mode": "origin" | "hobby" | "traits", "origin", "occupation", "hobby", "traits", "text_scale", "custom_text"}.
func setup(params: Dictionary) -> void:
	_params = params
	mode = str(params.get("mode", "origin"))
	origin = str(params.get("origin", ""))
	occupation = str(params.get("occupation", ""))
	hobby = str(params.get("hobby", ""))
	traits = JsonUtil.to_str_array(params.get("traits", []))
	text_scale = clampf(float(params.get("text_scale", 1.0)), 1.0, 1.5)


func _ready() -> void:
	UiUtil.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()
	UiUtil.focus_later(_default_focus())
	_settle_scroll()


## The tiles grow while their wrapped names settle (a few frames): then the focused tile is scrolled into view again.
func _settle_scroll() -> void:
	for i in 4:
		await get_tree().process_frame
	if not is_inside_tree() or _scroll == null:
		return
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null and _scroll.is_ancestor_of(f):
		_scroll.ensure_control_visible(f)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _closed:
		return
	var esc: bool = event is InputEventKey and (event as InputEventKey).pressed \
		and (event as InputEventKey).keycode == KEY_ESCAPE
	var b: bool = event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	if esc or b:
		get_viewport().set_input_as_handled()
		close()


## A tile: the origin (jobs → stay open for the chips), the hobby, a trait chip (toggle) or "Anderes …".
func choose(id: String) -> void:
	if _closed:
		return
	if id == CUSTOM:
		custom_requested.emit(mode)
		return
	match mode:
		"origin":
			var changed: bool = id != origin
			origin = id
			if changed:
				occupation = ""
			_refresh()
			if _jobs(id).is_empty():
				_finish()
			else:
				UiUtil.focus_later(chips.values()[0] as Control)
		"hobby":
			hobby = id
			_finish()
		"traits":
			if traits.has(id):
				traits.remove_at(traits.find(id))
			else:
				traits.append(id)
				if traits.size() > MAX_TRAITS:
					traits.remove_at(0)            # a fourth tap replaces the oldest
			_refresh()


## A "genauer" chip (mode origin): the job — chosen and closed; the same chip again clears it.
func choose_job(occupation_id: String) -> void:
	if _closed:
		return
	occupation = "" if occupation == occupation_id else occupation_id
	_finish()


## No trait (mode traits).
func clear_traits() -> void:
	traits.clear()
	_refresh()


## "Fertig", Esc, B: the current choice counts (origin / hobby only when one is chosen).
func close() -> void:
	if _closed:
		return
	if mode == "traits" or (mode == "origin" and origin != "") or (mode == "hobby" and hobby != ""):
		_finish()
		return
	_closed = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()


func columns() -> int:
	return _grid.columns if _grid != null else 0


## Soft hyphens (U+00AD, drawn as "-" only where a line breaks) in the long words of the catalog's tile names, so a
## tile wraps "Land-/wirtschaft" instead of cutting a word anywhere (display only, the data stays plain).
static func hyphenate(text: String) -> String:
	var out: String = text
	for w: String in HYPHENS.keys():
		if out.contains(w):
			out = out.replace(w, str(HYPHENS[w]).replace("|", "\u00ad"))
	return out


# --- internals --------------------------------------------------------------------------------------------------------

func _finish() -> void:
	_closed = true
	match mode:
		"origin":
			origin_picked.emit(origin, occupation)
		"hobby":
			hobby_picked.emit(hobby)
		"traits":
			traits_picked.emit(traits.duplicate())
	closed.emit()


func _fs(px: int) -> int:
	return roundi(px * text_scale)


func _jobs(origin_id: String) -> Array:
	return DB.data.origin(origin_id).get("jobs", []) as Array if DB.data != null else []


func _default_focus() -> Control:
	var key: String = {"origin": origin, "hobby": hobby}.get(mode, "")
	if key != "" and tiles.has(key):
		return tiles[key]
	if mode == "traits" and not traits.is_empty() and tiles.has(traits[0]):
		return tiles[traits[0]]
	return tiles.values()[0] if not tiles.is_empty() else _done


## Selection state → the tiles' pressed look, the chips row, the "Keine" button.
func _refresh() -> void:
	for id: Variant in tiles.keys():
		var t: Button = tiles[id]
		var on: bool = false
		match mode:
			"origin":
				on = str(id) == origin
			"hobby":
				on = str(id) == hobby
			"traits":
				on = traits.has(str(id))
		t.set_pressed_no_signal(on)
	if mode == "origin":
		_fill_chips()
	if _none != null:
		_none.disabled = traits.is_empty()
	_wire()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.86)
	add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	add_child(safe)
	var panel: PanelContainer = UiUtil.panel(&"PanelMenu")
	panel.name = "Picker"
	safe.add_child(panel)
	var col: VBoxContainer = UiUtil.vbox(GAP)
	panel.add_child(col)
	# head: title + one-line hint on the left, "Schließen" glyph, ("Keine",) "Fertig" on the right — the grid gets the
	# height (4 rows of tiles + the "genauer" chips fit 720 p without scrolling at 100 %)
	var head: HBoxContainer = UiUtil.hbox(14)
	head.name = "Head"
	col.add_child(head)
	var texts: VBoxContainer = UiUtil.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(texts)
	var titles: Dictionary = {"origin": "VORLEBEN WÄHLEN", "hobby": "HOBBY / TALENT WÄHLEN",
		"traits": "EIGENSCHAFTEN (OPTIONAL)"}
	var t: Label = UiUtil.label(str(titles.get(mode, "")), &"LabelHeader", _fs(26))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(t)
	var sub: String = {"origin": "Ein Tipp wählt. Mit „genauer“ dürfen Sie präzisieren — müssen aber nicht.",
		"hobby": "Was machen Sie, wenn keine Kamera läuft?",
		"traits": "Bis zu drei. Ein vierter Tipp ersetzt den ältesten. Keine ist auch eine Antwort."}.get(mode, "")
	var s: Label = UiUtil.label(sub, &"", _fs(18), UiTheme.C_TEXT_DIM)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(s)
	var glyph: Control = InputGlyph.make(&"ui_cancel", "Schließen", _fs(16))
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(glyph)
	if mode == "traits":
		_none = UiUtil.button("Keine", &"")
		_none.name = "None"
		_none.custom_minimum_size = Vector2(180, 0)
		_none.add_theme_font_size_override("font_size", _fs(22))
		_none.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiUtil.touch_pad(_none)
		_none.pressed.connect(clear_traits)
		head.add_child(_none)
	_done = UiUtil.button("Fertig", &"ButtonBig")
	_done.name = "Done"
	_done.custom_minimum_size = Vector2(220, 0)
	_done.add_theme_font_size_override("font_size", _fs(26))
	_done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiUtil.touch_pad(_done, 72.0)
	_done.pressed.connect(close)
	head.add_child(_done)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "Tiles"
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	for e: Dictionary in _entries():
		var tile: Button = _tile(str(e["id"]), str(e["name"]), str(e.get("icon", "")))
		_grid.add_child(tile)
		tiles[str(e["id"])] = tile
	if mode != "traits":
		var custom: Button = _tile(CUSTOM, str(_params.get("custom_text", "")) if str(_params.get("custom_text",
			"")) != "" else "Anderes …", "chat")
		_grid.add_child(custom)
		tiles[CUSTOM] = custom
	if mode == "origin":
		_chip_box = UiUtil.hbox(GAP)
		_chip_box.name = "Genauer"
		col.add_child(_chip_box)
		var gl: Label = UiUtil.label("GENAUER\n(OPTIONAL)", &"", _fs(16), UiTheme.C_ACCENT)
		gl.add_theme_font_override("font", UiTheme.font_bold())
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_chip_box.add_child(gl)
		_chip_row = HFlowContainer.new()
		_chip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_chip_row.add_theme_constant_override("h_separation", GAP)
		_chip_row.add_theme_constant_override("v_separation", GAP)
		_chip_box.add_child(_chip_row)
	resized.connect(_layout_columns)
	_layout_columns.call_deferred()


## Columns that fit the panel width at the current text size (6 at 100 % / 1280 px).
func _layout_columns() -> void:
	if _grid == null or not is_inside_tree():
		return
	var avail: float = maxf(_scroll.size.x, size.x - 120.0) - 24.0
	var want: float = TILE_W * text_scale
	var n: int = clampi(int(floor((avail + GAP) / (want + GAP))), 2, MAX_COLUMNS)
	if n != _grid.columns:
		_grid.columns = n
		var w: float = floorf((avail - GAP * (n - 1)) / n)
		for t: Variant in tiles.values():
			(t as Button).custom_minimum_size.x = maxf(w, TILE_W)
		_wire()


func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match mode:
		"origin":
			for e: Dictionary in DB.data.all_origins():
				if str(e["id"]) != ALLROUND:
					out.append(e)
		"hobby":
			out = DB.data.persona_list("hobbies")
		"traits":
			out = DB.data.persona_list("traits")
	return out


func _tile(id: String, caption: String, icon: String) -> Button:
	var b: Button = UiUtil.button("", &"")         # framed: every tile reads as a touch target
	b.name = "Tile_" + id
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(TILE_W, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = false
	var row: HBoxContainer = UiUtil.hbox(8)
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(row)
	row.offset_left = 10
	row.offset_right = -8
	b.add_child(row)
	if icon != "":
		var ic: Control = UiIcon.make(StringName(icon), UiTheme.C_ACCENT_2, _fs(22))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l: Label = UiUtil.label(hyphenate(UiUtil.glyph_safe(caption)), &"", _fs(22))
	l.name = "Text"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var pressed_sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.35), UiTheme.C_ACCENT, 3, 0.0, 12, 6)
	b.add_theme_stylebox_override("pressed", pressed_sb)
	b.add_theme_stylebox_override("hover_pressed", pressed_sb)
	UiUtil.touch_pad(b, float(UiTheme.TOUCH_HIT))   # the whole 88 px are visible: a two-line name fits the frame
	b.pressed.connect(func() -> void: choose(id))
	# a label wrapping to three lines makes the tile taller instead of overflowing; measured at the label's real width
	# (before the first layout it is 0 and the wrapped text absurdly tall)
	l.resized.connect(func() -> void:
		if l.size.x < 40.0:
			return
		var need: float = maxf(float(UiTheme.TOUCH_HIT), l.get_combined_minimum_size().y + 20.0)
		if absf(need - b.custom_minimum_size.y) > 0.5:
			b.custom_minimum_size.y = need)
	return b


func _fill_chips() -> void:
	for c: Node in _chip_row.get_children():
		_chip_row.remove_child(c)
		c.queue_free()
	chips.clear()
	var jobs: Array = _jobs(origin)
	_chip_box.visible = not jobs.is_empty()
	for j: Variant in jobs:
		var jd: Dictionary = j
		var id: String = str(jd["id"])
		var c: Button = UiUtil.button(UiUtil.glyph_safe(str(jd["n"])), &"")
		c.name = "Chip_" + id
		c.toggle_mode = true
		c.add_theme_font_size_override("font_size", _fs(22))
		c.custom_minimum_size = Vector2(140, 0)
		UiUtil.touch_pad(c, TILE_VISIBLE)
		var pressed_sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.35), UiTheme.C_ACCENT, 3, 0.0, 12, 6)
		c.add_theme_stylebox_override("pressed", pressed_sb)
		c.add_theme_stylebox_override("hover_pressed", pressed_sb)
		c.set_pressed_no_signal(id == occupation)
		c.pressed.connect(func() -> void: choose_job(id))
		_chip_row.add_child(c)
		chips[id] = c


## Grid focus with wrap (left / right in a row, up / down in a column), then the chips and the buttons; Tab follows
## the reading order.
func _wire() -> void:
	if _grid == null:
		return
	var list: Array[Control] = []
	for c: Node in _grid.get_children():
		if c is Button:
			list.append(c as Button)
	var n: int = maxi(1, _grid.columns)
	var after: Array[Control] = []
	for c: Variant in chips.values():
		if is_instance_valid(c) and not (c as Node).is_queued_for_deletion():
			after.append(c as Control)
	if _none != null:
		after.append(_none)
	after.append(_done)
	var rows: int = ceili(float(list.size()) / n)
	for i in list.size():
		var c: Control = list[i]
		var r: int = i / n
		var row_start: int = r * n
		var row_end: int = mini(row_start + n, list.size()) - 1
		c.focus_neighbor_left = c.get_path_to(list[i - 1] if i > row_start else list[row_end])
		c.focus_neighbor_right = c.get_path_to(list[i + 1] if i < row_end else list[row_start])
		var up_i: int = i - n if r > 0 else -1
		c.focus_neighbor_top = c.get_path_to(list[up_i] if up_i >= 0 else after[after.size() - 1])
		var down_i: int = i + n
		if down_i < list.size():
			c.focus_neighbor_bottom = c.get_path_to(list[down_i])
		elif r < rows - 1:
			c.focus_neighbor_bottom = c.get_path_to(list[list.size() - 1])
		else:
			c.focus_neighbor_bottom = c.get_path_to(after[0])
	UiUtil.wire_horizontal(after)
	for c: Control in after:
		c.focus_neighbor_top = c.get_path_to(list[list.size() - 1])
		c.focus_neighbor_bottom = c.get_path_to(list[0])
	var flat: Array[Control] = list.duplicate()
	flat.append_array(after)
	for i in flat.size():
		flat[i].focus_next = flat[i].get_path_to(flat[(i + 1) % flat.size()])
		flat[i].focus_previous = flat[i].get_path_to(flat[posmod(i - 1, flat.size())])
