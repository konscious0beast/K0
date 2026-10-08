extends CanvasLayer
## ShowOverlay (02_TECH §1.6, §9.4 layer 40; 03_ART §9.2): the show IS the UI. LIVE badge, viewer counter, followers,
## hype meter (markers 50/75/100), sponsor lower third, chat ticker, gift drop announcement, REC corners and the TV
## scanline/vignette layer. Mode via Events.overlay_mode_requested: &"explore", &"battle", &"safe_room", &"menu"
## (scanlines only), &"hidden", &"game_over" (scanlines only, M6-internal). Reads Show for numbers (never writes state).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const TouchScript := preload("res://scenes/ui/touch_controls.gd")
const BADGE_H: float = 30.0                # LIVE pill 80×30, corner radius = half the height (03_ART §9.2)
const SHADER_LOW: String = "res://art/shaders/ui_tv_overlay.gdshader"
const SHADER_HIGH: String = "res://art/shaders/ui_tv_overlay_aberration.gdshader"
const MODES: Array[StringName] = [&"explore", &"battle", &"safe_room", &"menu", &"hidden", &"game_over"]
const TICKER_SPEED: float = 80.0           # px/s (03_ART §9.2)
const TICKER_GAP: float = 64.0
const TICKER_IDLE_SEC: float = 9.0         # channel ident when the chat is quiet
const LOWER_IN: float = 0.25
const LOWER_HOLD: float = 2.5
const LOWER_OUT: float = 0.2
const GIFT_HOLD: float = 3.0
const VIEWER_FLASH_SEC: float = 0.4
const LOWER_TOP: float = -22.0 - 12.0 - 64.0   # lower third 480×64, left bottom above the ticker (03_ART §9.2)
const LOWER_BOTTOM: float = -22.0 - 12.0
const IDENTS: PackedStringArray = ["NOVA SYNDIKAT präsentiert: DUNGEON PRIME TIME", "Live aus der Unterstadt",
	"Bleiben Sie dran – nach der Werbung wird es gefährlich", "Lootboxen können nicht gekauft werden. Nur verdient."]
const KIND_NAMES: Dictionary = {"chest": "Sponsorkiste", "gold": "Credits-Geschenk", "fan_pack": "Applaus-Paket",
	"sponsor_buff": "Sponsor-Paket", "cheer": "Applaus"}
const TIER_NAMES: Dictionary = {"bronze": "Bronze", "silver": "Silber", "gold": "Gold"}


## Hype meter 320×14: gradient magenta → gold, diamond markers at 50/75/100, gloss sweep on increase.
class HypeBar extends Control:
	const IconMeshB := preload("res://scenes/ui/icon_mesh.gd")
	var value: float = 0.0
	var shown: float = 0.0
	var gloss: float = -1.0                  # 0..1 sweep progress, < 0 = off

	func _process(delta: float) -> void:
		var prev: float = shown
		shown = lerpf(shown, value, 1.0 - exp(-delta * 8.0))
		if absf(shown - value) < 0.05:
			shown = value
		if gloss >= 0.0:
			gloss += delta / 0.3
			if gloss > 1.0:
				gloss = -1.0
		if not is_equal_approx(prev, shown) or gloss >= 0.0:
			queue_redraw()

	func set_value(v: float, animate_gloss: bool) -> void:
		if animate_gloss and v > value + 0.01:
			gloss = 0.0
		value = clampf(v, 0.0, 100.0)
		queue_redraw()

	func _draw() -> void:
		build_mesh().commit(self)

	## Bar, gloss, frame and the three threshold diamonds as ONE triangle array (icon_mesh.gd, 02_TECH §12.1).
	func build_mesh() -> IconMeshB:
		var m: IconMeshB = IconMeshB.new()
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		m.rect(r, Color(0.08, 0.05, 0.11, 0.85))
		var w: float = size.x * clampf(shown / 100.0, 0.0, 1.0)
		if w > 1.0:
			var a: Color = Color("#ff2e88")
			var b: Color = Color("#ff2e88").lerp(Color("#ffc93c"), clampf(shown / 100.0, 0.0, 1.0))
			m.poly_colors(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(0, size.y)]),
				PackedColorArray([a, b, b, a]))
			if gloss >= 0.0:
				var gx: float = w * gloss
				m.rect(Rect2(maxf(gx - 18.0, 0.0), 0, minf(36.0, w - maxf(gx - 18.0, 0.0)), size.y),
					Color(1, 1, 1, 0.35 * (1.0 - gloss)))
		m.rect_outline(r, Color(1, 1, 1, 0.25), 1.0)
		for t: float in [50.0, 75.0, 100.0]:
			var x: float = size.x * t / 100.0
			var reached: bool = shown >= t
			var col: Color = Color("#ffc93c") if reached else Color("#f5f0e6", 0.7)
			var h: float = size.y * 0.5 + 3.0
			var c: Vector2 = Vector2(minf(x, size.x - 2.0), size.y * 0.5)
			m.poly(PackedVector2Array([c + Vector2(0, -h), c + Vector2(5, 0), c + Vector2(0, h), c + Vector2(-5, 0)]),
				Color("#140d1c"))
			m.poly(PackedVector2Array([c + Vector2(0, -h + 2), c + Vector2(3.5, 0), c + Vector2(0, h - 2),
				c + Vector2(-3.5, 0)]), col)
		return m


## Chat ticker (03_ART §9.2): height 22, scrolls 80 px/s, user names in accent colors.
class Ticker extends Control:
	var queue: Array[Dictionary] = []
	var idle: float = 0.0
	var ident_i: int = 0
	var speed: float = 80.0
	var gap: float = 64.0
	var idle_after: float = 9.0
	var idents: PackedStringArray = []

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func post(user: String, text: String, color: Color) -> void:
		queue.append({"user": user, "text": text, "color": color})
		idle = 0.0
		if queue.size() > 8:
			queue.pop_front()

	func item_count() -> int:
		return get_child_count()

	func _process(delta: float) -> void:
		var last_end: float = -INF
		for c: Node in get_children():
			var item: Control = c as Control
			item.position.x -= speed * delta
			last_end = maxf(last_end, item.position.x + item.size.x)
			if item.position.x + item.size.x < -4.0:
				item.queue_free()
		idle += delta
		if queue.is_empty() and idle > idle_after and get_child_count() == 0 and not idents.is_empty():
			queue.append({"user": "", "text": idents[ident_i % idents.size()], "color": Color("#ffc93c")})
			ident_i += 1
			idle = 0.0
		if not queue.is_empty() and (last_end == -INF or last_end < size.x - gap):
			_spawn(queue.pop_front(), maxf(size.x, last_end + gap) if last_end != -INF else size.x)

	func _spawn(msg: Dictionary, x: float) -> void:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var user: String = str(msg.get("user", ""))
		if user != "":
			var u: Label = Label.new()
			u.text = user
			u.add_theme_font_size_override("font_size", 15)
			u.add_theme_color_override("font_color", msg.get("color", Color.WHITE) as Color)
			u.add_theme_constant_override("outline_size", 0)
			row.add_child(u)
		else:
			var star: Control = UiIcon.make(&"star", Color("#ffc93c"), 12)
			star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(star)
		var t: Label = Label.new()
		t.text = str(msg.get("text", ""))
		t.add_theme_font_size_override("font_size", 15)
		t.add_theme_color_override("font_color", Color("#f5f0ff") if user != "" else Color("#ffc93c"))
		t.add_theme_constant_override("outline_size", 0)
		row.add_child(t)
		add_child(row)
		row.position = Vector2(x, 0)
		row.size = row.get_combined_minimum_size()
		row.position.y = (size.y - row.size.y) * 0.5


## REC corners (03_ART §9.2): L-angles 28 px, 2 px PAPER @ 35 %.
class RecCorners extends Control:
	func _draw() -> void:
		var col: Color = Color("#f5f0e6", 0.35)
		var l: float = 28.0
		var i: float = 10.0
		var w: float = size.x
		var h: float = size.y
		for corner: Array in [[Vector2(i, i), Vector2(1, 1)], [Vector2(w - i, i), Vector2(-1, 1)],
				[Vector2(i, h - i), Vector2(1, -1)], [Vector2(w - i, h - i), Vector2(-1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_line(p, p + Vector2(l * d.x, 0), col, 2.0)
			draw_line(p, p + Vector2(0, l * d.y), col, 2.0)


var mode: StringName = &"hidden"

var _params: Dictionary = {}
var _demo: bool = false
var _root: Control
var _tv: ColorRect
var _safe: SafeAreaContainer
var _frame: Control
var _rec: RecCorners
var _top_left: HBoxContainer
var _badge: PanelContainer
var _badge_label: Label
var _badge_dot: Control
var _viewers_label: Label
var _followers_label: Label
var _follow_delta: Label
var _hype_box: VBoxContainer
var _hype_value: Label
var _hype: HypeBar
var _ticker: Ticker
var _ticker_panel: PanelContainer
var _lower: PanelContainer
var _lower_name: Label
var _lower_slogan: Label
var _lower_name_panel: PanelContainer
var _gift: PanelContainer
var _gift_title: Label
var _gift_text: Label
var _gift_icon: Control
var _lower_queue: Array[Dictionary] = []
var _lower_busy: bool = false
var _last_lower: Dictionary = {"id": "", "t": -10.0}
var _gift_tween: Tween = null
var _time: float = 0.0
var _shown_viewers: float = 0.0
var _target_viewers: int = 0
var _viewer_flash: float = 0.0
var _viewer_flash_color: Color = Color.WHITE
var _shown_followers: float = 0.0
var _target_followers: int = 0
var _demo_values: Dictionary = {}
var _lower_lift: float = 0.0
var _touch_shift: bool = false


## Stores params only (screen contract); {"capture": true} → demo still with sample numbers.
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	Events.overlay_mode_requested.connect(set_mode)
	Events.settings_changed.connect(_apply_quality)
	Events.sponsor_gift_triggered.connect(show_lower_third)
	Events.gift_received.connect(_on_gift_received)
	Events.chat_posted.connect(_on_chat_posted)
	Events.mod_said.connect(_on_mod_said)
	Events.followers_changed.connect(_on_followers_changed)
	Events.hype_changed.connect(_on_hype_changed)
	get_viewport().size_changed.connect(_layout_hype)      # display insets move the touch pause/map buttons
	_apply_quality()
	_target_viewers = Show.display_viewers()
	_shown_viewers = float(_target_viewers)
	_target_followers = Show.followers()
	_shown_followers = float(_target_followers)
	_hype.set_value(Show.hype(), false)
	_hype.shown = _hype.value
	set_mode(mode)
	if bool(_params.get("capture", false)):
		_start_demo()


func _process(delta: float) -> void:
	_time += delta
	if _badge_dot != null:
		_badge_dot.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * cos(_time * TAU))
	var target: int = int(_demo_values.get("viewers", -1)) if _demo else Show.display_viewers()
	if target != _target_viewers:
		_viewer_flash = VIEWER_FLASH_SEC
		_viewer_flash_color = UiTheme.C_OK if target > _target_viewers else UiTheme.C_DANGER
		_target_viewers = target
	_shown_viewers = lerpf(_shown_viewers, float(_target_viewers), 1.0 - exp(-delta / 0.15))
	if absf(_shown_viewers - _target_viewers) < 1.0:
		_shown_viewers = float(_target_viewers)
	_viewer_flash = maxf(0.0, _viewer_flash - delta)
	_viewers_label.text = UiUtil.fmt_int(roundi(_shown_viewers))
	_viewers_label.add_theme_color_override("font_color",
		UiTheme.C_TEXT.lerp(_viewer_flash_color, _viewer_flash / VIEWER_FLASH_SEC))
	if not _demo:
		_target_followers = Show.followers()
	_shown_followers = lerpf(_shown_followers, float(_target_followers), 1.0 - exp(-delta / 0.25))
	if absf(_shown_followers - _target_followers) < 1.0:
		_shown_followers = float(_target_followers)
	_followers_label.text = UiUtil.fmt_int(roundi(_shown_followers)) + " Follower"
	if not _demo:
		var h: float = Show.hype()
		if not is_equal_approx(h, _hype.value):
			_hype.set_value(h, h > _hype.value)
	_hype_value.text = str(roundi(_hype.shown))
	_update_lower_lift(delta)
	var touch_on: bool = TouchScript.active != null and is_instance_valid(TouchScript.active)
	if touch_on != _touch_shift:
		_touch_shift = touch_on
		_layout_hype()


# --- public (M6-internal) --------------------------------------------------------------------------------------------

func set_mode(p_mode: StringName) -> void:
	mode = p_mode if MODES.has(p_mode) else &"hidden"
	if _root == null:
		return
	var show_bar: bool = mode == &"explore" or mode == &"battle" or mode == &"safe_room"
	_root.visible = mode != &"hidden"
	_frame.visible = show_bar
	_rec.visible = mode == &"explore"
	_hype_box.visible = mode != &"safe_room"
	_ticker_panel.visible = show_bar
	if mode == &"safe_room":
		_badge_label.text = "WERBEPAUSE"
		_badge.add_theme_stylebox_override("panel", _pill(UiTheme.C_GOLD))
		_badge_label.add_theme_color_override("font_color", UiUtil.C_INK)
		_badge_dot.set("color", UiUtil.C_INK)
	else:
		_badge_label.text = "LIVE"
		_badge.add_theme_stylebox_override("panel", _pill(UiUtil.C_LIVE))
		_badge_label.add_theme_color_override("font_color", UiUtil.C_PAPER)
		_badge_dot.set("color", UiUtil.C_PAPER)
	_layout_hype()


## LIVE / WERBEPAUSE badge: a pill (corner radius = half the height), 03_ART §9.2.
func _pill(col: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = UiUtil.box_style(col, Color(0, 0, 0, 0), 0, 0.0, 14, 2)
	sb.set_corner_radius_all(int(BADGE_H * 0.5))
	sb.corner_detail = 8
	return sb


## Battle: hype meter top center (top right belongs to the battle HUD speed/auto buttons, GDD §14.5). Exploration with
## the touch layer shown: left of the pause button's hit area (TouchControls.right_clearance(), measured against the
## buttons' real position incl. display insets), never under it.
func _layout_hype() -> void:
	if _hype_box == null:
		return
	if mode == &"battle":
		_hype_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_hype_box.offset_left = -160
		_hype_box.offset_right = 160
	else:
		var right: float = 0.0
		if _touch_shift and TouchScript.active != null and is_instance_valid(TouchScript.active):
			right = -float(TouchScript.active.call("right_clearance", _safe))
		_hype_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_hype_box.offset_left = right - 320.0
		_hype_box.offset_right = right
	_hype_box.offset_top = 2
	_hype_box.offset_bottom = 40


func hype_rect() -> Rect2:
	return _hype_box.get_global_rect() if _hype_box.is_visible_in_tree() else Rect2()


## Sponsor lower third (in 0.25 s, holds 2.5 s, out 0.2 s); queued. Same sponsor within 1 s is shown once.
func show_lower_third(sponsor_id: String) -> void:
	if sponsor_id == "":
		return
	if str(_last_lower["id"]) == sponsor_id and _time - float(_last_lower["t"]) < 1.0:
		return
	_last_lower = {"id": sponsor_id, "t": _time}
	var name_text: String = sponsor_id
	var slogan: String = ""
	var col: Color = UiTheme.C_ACCENT
	if DB.has_id("sponsors", sponsor_id):
		var def: SponsorDef = DB.sponsor(sponsor_id)
		name_text = UiUtil.tr_text(def.name)
		slogan = UiUtil.tr_text(def.slogan)
		col = UiUtil.hex(def.color, col)
	_lower_queue.append({"name": name_text, "slogan": slogan, "color": col})
	Sfx.play(&"sponsor")
	if not _lower_busy:
		_next_lower_third()


## Viewer gift announcement (05 §6.12/L12–L13): kind/tier and sender only (anonymous by default), never contents.
func announce_gift(gift: Dictionary) -> void:
	var kind: String = str(gift.get("kind", ""))
	var title: String = "LIEFERUNG EINGETROFFEN"
	var what: String = str(KIND_NAMES.get(kind, "Geschenk"))
	var tier: String = str(gift.get("tier", ""))
	if kind == "chest" and TIER_NAMES.has(tier):
		what += " " + str(TIER_NAMES[tier])
	if kind == "sponsor_buff" and DB.has_id("sponsors", str(gift.get("sponsor_id", ""))):
		what += ": " + UiUtil.tr_text(DB.sponsor(str(gift.get("sponsor_id", ""))).name)
	var sender: Dictionary = gift.get("sender", {}) if typeof(gift.get("sender", {})) == TYPE_DICTIONARY else {}
	var who: String = "einem anonymen Fan"
	if not bool(sender.get("anon", true)) and str(sender.get("display_name", "")) != "":
		who = str(sender.get("display_name", ""))
	_gift_title.text = title
	_gift_text.text = UiUtil.glyph_safe("%s von %s" % [what, who])
	_gift_icon.set("color", UiTheme.C_GOLD if kind == "chest" else UiTheme.C_ACCENT_2)
	_gift.visible = true
	_gift.modulate.a = 1.0
	if _gift_tween != null and _gift_tween.is_valid():
		_gift_tween.kill()
	if is_inside_tree():
		_gift.pivot_offset = _gift.size * 0.5
		_gift.scale = Vector2(0.85, 0.85)
		_gift_tween = create_tween()
		_gift_tween.tween_property(_gift, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_gift_tween.tween_interval(GIFT_HOLD)
		_gift_tween.tween_property(_gift, "modulate:a", 0.0, 0.25)
		_gift_tween.tween_callback(func() -> void: _gift.visible = false)


func post_chat(user: String, text: String, mood: StringName = &"neutral") -> void:
	var col: Color = UiUtil.chat_color(user)
	if mood == &"bored":
		col = col.darkened(0.25)
	_ticker.post(UiUtil.glyph_safe(user), UiUtil.glyph_safe(text), col)


func ticker_items() -> int:
	return _ticker.item_count() + _ticker.queue.size()


func is_lower_third_visible() -> bool:
	return _lower.visible


func is_gift_banner_visible() -> bool:
	return _gift.visible


func gift_text() -> String:
	return _gift_text.text


## Sponsor name currently shown in the lower third ("" while hidden).
func lower_third_text() -> String:
	return _lower_name.text if _lower.visible else ""


func badge_text() -> String:
	return _badge_label.text


func viewers_text() -> String:
	return _viewers_label.text


func hype_value() -> float:
	return _hype.value


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	_tv = ColorRect.new()
	_tv.name = "TvOverlay"
	UiUtil.full_rect(_tv)
	_tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tv.color = Color(1, 1, 1, 1)
	_root.add_child(_tv)
	_rec = RecCorners.new()
	_rec.name = "RecCorners"
	UiUtil.full_rect(_rec)
	_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_rec)
	_safe = SafeAreaContainer.new()
	_safe.extra = 0
	_root.add_child(_safe)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(_frame)
	_build_top_left()
	_build_hype()
	_build_ticker()
	_build_lower_third()
	_build_gift_banner()


func _build_top_left() -> void:
	_top_left = UiUtil.hbox(10)
	_top_left.name = "TopLeft"
	_top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.add_child(_top_left)
	_badge = PanelContainer.new()
	_badge.name = "LiveBadge"
	_badge.custom_minimum_size = Vector2(80, BADGE_H)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_top_left.add_child(_badge)
	var brow: HBoxContainer = UiUtil.hbox(6)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	_badge.add_child(brow)
	_badge_dot = UiIcon.make(&"dot", UiUtil.C_PAPER, 10)
	_badge_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(_badge_dot)
	_badge_label = UiUtil.label("LIVE", &"LabelLive")
	_badge_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	brow.add_child(_badge_label)
	var col: VBoxContainer = UiUtil.vbox(0)
	_top_left.add_child(col)
	var vrow: HBoxContainer = UiUtil.hbox(6)
	col.add_child(vrow)
	var eye: Control = UiIcon.make(&"eye", UiTheme.C_TEXT, 22)
	eye.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vrow.add_child(eye)
	_viewers_label = UiUtil.label("0", &"", 22)
	_viewers_label.name = "Viewers"
	_viewers_label.add_theme_font_override("font", UiTheme.font_mono())
	vrow.add_child(_viewers_label)
	vrow.add_child(UiUtil.label("Zuschauer", &"LabelSmall", 16))
	var frow: HBoxContainer = UiUtil.hbox(6)
	col.add_child(frow)
	var heart: Control = UiIcon.make(&"heart", UiTheme.C_ACCENT, 14)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frow.add_child(heart)
	_followers_label = UiUtil.label("0 Follower", &"LabelSmall", 16)
	_followers_label.name = "Followers"
	frow.add_child(_followers_label)
	_follow_delta = UiUtil.label("", &"", 16, UiTheme.C_OK)
	_follow_delta.modulate.a = 0.0
	frow.add_child(_follow_delta)


func _build_hype() -> void:
	_hype_box = UiUtil.vbox(4)
	_hype_box.name = "Hype"
	_frame.add_child(_hype_box)
	var row: HBoxContainer = UiUtil.hbox(6)
	_hype_box.add_child(row)
	var title: Label = UiUtil.label("HYPE", &"", 16, UiTheme.C_GOLD)
	title.add_theme_font_override("font", UiTheme.font_bold())
	row.add_child(title)
	row.add_child(UiUtil.spacer(0, 0, true))
	_hype_value = UiUtil.label("0", &"", 16)
	_hype_value.add_theme_font_override("font", UiTheme.font_mono())
	row.add_child(_hype_value)
	_hype = HypeBar.new()
	_hype.name = "HypeBar"
	_hype.custom_minimum_size = Vector2(320, 14)
	_hype.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hype_box.add_child(_hype)


func _build_ticker() -> void:
	_ticker_panel = PanelContainer.new()
	_ticker_panel.name = "Ticker"
	_ticker_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ticker_panel.offset_top = -22
	_ticker_panel.offset_bottom = 0
	_ticker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticker_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.7), Color(0, 0, 0, 0),
		0, 0.0, 0, 0))
	_frame.add_child(_ticker_panel)
	var row: HBoxContainer = UiUtil.hbox(0)
	_ticker_panel.add_child(row)
	var tag: PanelContainer = PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_ACCENT, Color(0, 0, 0, 0), 0, 0.21, 12, 0))
	tag.custom_minimum_size = Vector2(0, 22)
	row.add_child(tag)
	var chat_row: HBoxContainer = UiUtil.hbox(4)
	tag.add_child(chat_row)
	var chat_icon: Control = UiIcon.make(&"chat", UiUtil.C_PAPER, 14)
	chat_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chat_row.add_child(chat_icon)
	var tl: Label = UiUtil.label("CHAT", &"", 15, UiUtil.C_PAPER)
	tl.add_theme_font_override("font", UiTheme.font_bold())
	tl.add_theme_constant_override("outline_size", 0)
	chat_row.add_child(tl)
	_ticker = Ticker.new()
	_ticker.name = "Scroller"
	_ticker.speed = TICKER_SPEED
	_ticker.gap = TICKER_GAP
	_ticker.idle_after = TICKER_IDLE_SEC
	_ticker.idents = IDENTS
	_ticker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ticker.custom_minimum_size = Vector2(0, 22)
	row.add_child(_ticker)


func _build_lower_third() -> void:
	_lower = PanelContainer.new()
	_lower.name = "LowerThird"
	_lower.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_lower.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lower.offset_left = 0
	_lower.offset_right = 480
	_lower.offset_top = LOWER_TOP
	_lower.offset_bottom = LOWER_BOTTOM
	_lower.visible = false
	_lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_lower)
	var col: VBoxContainer = UiUtil.vbox(0)
	_lower.add_child(col)
	_lower_name_panel = PanelContainer.new()
	_lower_name_panel.custom_minimum_size = Vector2(0, 38)
	col.add_child(_lower_name_panel)
	var nrow: HBoxContainer = UiUtil.hbox(10)
	_lower_name_panel.add_child(nrow)
	var pres: Label = UiUtil.label("PRÄSENTIERT VON", &"", 15, UiUtil.C_INK)
	pres.add_theme_constant_override("outline_size", 0)
	pres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(pres)
	_lower_name = UiUtil.label("", &"", 24, UiUtil.C_INK)
	_lower_name.add_theme_font_override("font", UiTheme.font_bold())
	_lower_name.add_theme_constant_override("outline_size", 0)
	nrow.add_child(_lower_name)
	var spanel: PanelContainer = PanelContainer.new()
	spanel.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_PANEL, Color(0, 0, 0, 0), 0, 0.21, 16, 3))
	spanel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(spanel)
	_lower_slogan = UiUtil.label("", &"", 15)
	spanel.add_child(_lower_slogan)


func _build_gift_banner() -> void:
	_gift = PanelContainer.new()
	_gift.name = "GiftBanner"
	_gift.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_gift.offset_left = -230
	_gift.offset_right = 230
	# Below the exploration timer + quest line (top center), so a drop never covers the countdown.
	_gift.offset_top = 150
	_gift.offset_bottom = 218
	_gift.visible = false
	_gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gift.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 0.92), UiTheme.C_GOLD, 2, 0.21,
		18, 6))
	_frame.add_child(_gift)
	var row: HBoxContainer = UiUtil.hbox(12)
	_gift.add_child(row)
	_gift_icon = UiIcon.make(&"gift", UiTheme.C_GOLD, 40)
	_gift_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_gift_icon)
	var col: VBoxContainer = UiUtil.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_gift_title = UiUtil.label("LIEFERUNG EINGETROFFEN", &"", 20, UiTheme.C_GOLD)
	_gift_title.add_theme_font_override("font", UiTheme.font_bold())
	col.add_child(_gift_title)
	_gift_text = UiUtil.label("", &"", 16)
	_gift_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_gift_text)


# --- behaviour --------------------------------------------------------------------------------------------------------

func _next_lower_third() -> void:
	if _lower_queue.is_empty():
		_lower_busy = false
		_lower.visible = false
		return
	_lower_busy = true
	var item: Dictionary = _lower_queue.pop_front()
	_lower_name.text = UiUtil.glyph_safe(str(item["name"]).to_upper())
	_lower_slogan.text = UiUtil.glyph_safe("„%s“" % str(item["slogan"])) if str(item["slogan"]) != "" else ""
	_lower_slogan.get_parent().visible = str(item["slogan"]) != ""
	_lower_name_panel.add_theme_stylebox_override("panel", UiUtil.box_style(item["color"] as Color,
		Color(0, 0, 0, 0), 0, 0.21, 16, 4))
	_lower.visible = true
	if not is_inside_tree():
		return
	_lower.modulate.a = 0.0
	var x0: float = _lower.position.x
	_lower.position.x = x0 - 60.0
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lower, "position:x", x0, LOWER_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lower, "modulate:a", 1.0, LOWER_IN)
	tw.chain().tween_interval(LOWER_HOLD)
	tw.chain().tween_property(_lower, "modulate:a", 0.0, LOWER_OUT)
	tw.chain().tween_callback(func() -> void:
		_lower.position.x = x0
		_next_lower_third())


## Lifts the lower third above a visible M.O.D. text box (both sit bottom left/center; the box is on layer 45).
func _update_lower_lift(delta: float) -> void:
	var target: float = 0.0
	var md: Node = get_parent().get_node_or_null("ModDialog") if get_parent() != null else null
	if md == null or not md.has_method("box_rect"):
		md = ModDialogScript.current
	if _lower.visible and md != null and is_instance_valid(md):
		var box: Rect2 = md.call("box_rect")
		if box.size.x > 0.0:
			var r: Rect2 = _lower.get_global_rect()
			r.position.y += _lower_lift
			if r.position.x < box.end.x and box.position.x < r.end.x and r.end.y > box.position.y - 8.0:
				target = r.end.y - (box.position.y - 8.0)
	_lower_lift = target if delta <= 0.0 else lerpf(_lower_lift, target, 1.0 - exp(-delta / 0.08))
	if absf(_lower_lift - target) < 0.5:
		_lower_lift = target
	_lower.offset_top = LOWER_TOP - _lower_lift
	_lower.offset_bottom = LOWER_BOTTOM - _lower_lift


func lower_third_rect() -> Rect2:
	return _lower.get_global_rect() if _lower.visible else Rect2()


## Screen rect of the viewer-gift banner while it is shown, else empty (M5 CR 1).
func gift_banner_rect() -> Rect2:
	return _gift.get_global_rect() if _gift.visible and _gift.modulate.a > 0.01 else Rect2()


func _apply_quality() -> void:
	var high: bool = Game.settings != null and Game.settings.quality == &"high"
	var path: String = SHADER_HIGH if high and ResourceLoader.exists(SHADER_HIGH) else SHADER_LOW
	var keep: Dictionary = {}
	var old: ShaderMaterial = _tv.material as ShaderMaterial
	if old != null:
		for p: String in ["scanline_alpha", "vignette", "test_card"]:
			var v: Variant = old.get_shader_parameter(p)
			if v != null:
				keep[p] = v
	if not ResourceLoader.exists(path):
		_tv.visible = false
		return
	var shader: Shader = load(path) as Shader
	if shader == null:
		_tv.visible = false
		return
	if old != null and old.shader == shader:
		return
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = shader
	for p: String in keep.keys():
		m.set_shader_parameter(p, keep[p])
	_tv.material = m
	_tv.visible = true


func _on_gift_received(gift: Dictionary) -> void:
	if Game.replaying:
		return
	if str(gift.get("source", "")) == "system":
		show_lower_third(str(gift.get("sponsor_id", "")))
	else:
		announce_gift(gift)


func _on_chat_posted(user: String, text: String, mood: StringName) -> void:
	post_chat(user, text, mood)


func _on_mod_said(text: String, voice: StringName, _tag: String, _blocking: bool) -> void:
	if voice == &"chat":
		post_chat("Chat", text, &"neutral")


func _on_followers_changed(followers: int, delta: int) -> void:
	_target_followers = followers
	if delta == 0 or not is_inside_tree():
		return
	_follow_delta.text = UiUtil.fmt_signed(delta)
	_follow_delta.add_theme_color_override("font_color", UiTheme.C_OK if delta > 0 else UiTheme.C_DANGER)
	_follow_delta.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_follow_delta, "modulate:a", 0.0, 0.4)


func _on_hype_changed(hype: float, delta: float, _reason: StringName) -> void:
	_hype.set_value(hype, delta > 0.0)


# --- demo still (capture) ---------------------------------------------------------------------------------------------

func _start_demo() -> void:
	_demo = true
	_demo_values = {"viewers": 7250}
	_target_viewers = 7250
	_shown_viewers = 7250.0
	_target_followers = 1234
	_shown_followers = 1234.0
	_hype.set_value(72.0, true)
	_hype.shown = 72.0
	set_mode(&"explore")
	for msg: Array in [["OmaHilde1953", "DAS IST KINO"], ["mopsfan_88", "GRAF MOPSULA <3"],
			["xX_Gleisgeist_Xx", "clip it clip it clip it"], ["KeinZugMehr", "der graf schaut heute so edel"]]:
		post_chat(str(msg[0]), str(msg[1]), &"hype")
	var sponsors: PackedStringArray = DB.data.ids("sponsors")
	if not sponsors.is_empty():
		_lower_queue.clear()
		_lower_name.text = UiUtil.tr_text(DB.sponsor(sponsors[0]).name).to_upper()
		_lower_slogan.text = "„%s“" % UiUtil.tr_text(DB.sponsor(sponsors[0]).slogan)
		_lower_name_panel.add_theme_stylebox_override("panel", UiUtil.box_style(
			UiUtil.hex(DB.sponsor(sponsors[0]).color, UiTheme.C_ACCENT), Color(0, 0, 0, 0), 0, 0.21, 16, 4))
		_lower.visible = true
	announce_gift({"kind": "chest", "tier": "bronze", "source": "dev", "sender": {"anon": true}})
	if _gift_tween != null and _gift_tween.is_valid():
		_gift_tween.kill()
	_gift.scale = Vector2.ONE
	_gift.modulate.a = 1.0
