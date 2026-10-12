extends CanvasLayer
## Results of a real-time combat (07 §8.9, R3): successor of the CTB results screen (gone since R5b part 2b) with the 06
## docking points — results_shown + show_slot (06 §8.0 Nr. 12: package C hangs its show-bet effect onto the slot), the
## chip "TALENT BEREIT · im Safe Room wählen" on a talent level (06 B, never a choice here), present(); autoplay
## continues after 1.0 s (auto_continue_sec). Forms:
## - regular win: lower third "Applaus!" bottom left (380 × 64, 3.0 s): "+36 EXP · +12 Cr · Werbepflaster"; level-ups
##   and the talent chip as a second lower third. Not blocking: present() returns at once, the exploration goes on.
## - boss win: credits panel (layer 60, tree paused) with EXP bars, boss loot, achievements, talent chip, show_slot and
##   "Weiter"; present() returns when it closes (R2 opens the doors afterwards, 07 §2.9).
## - flight: lower third "Taktischer Rückzug" (the hype loss shows in the meter).
## - defeat: nothing here — the existing Sendeschluss / game over flow (07 §8.9).
## R2 creates it (load("res://scenes/combat/ui/combat_results.gd").new(), add_child) and calls present(result,
## rewards) after Game.end_combat(). Private script (no class_name).

signal results_shown(result: BattleResult)

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const TouchScript := preload("res://scenes/ui/touch_controls.gd")
const JoystickScript := preload("res://scenes/ui/virtual_joystick.gd")

const LOWER_W: float = 380.0
const LOWER_HOLD: float = 3.0
const LOWER_IN: float = 0.25
const LOWER_OUT: float = 0.25
const TICKER_CLEAR: float = 34.0            # chat ticker 22 + gap 12 (like the sponsor lower third, 03_ART §9.2)
const PANEL_W: float = 680.0
const LAYER_LOWER: int = 6
const LAYER_PANEL: int = 60
const STAT_NAMES: Dictionary = {"hp": "HP", "mp": "MP", "str": "ANG", "mag": "MAG", "def": "VER", "res": "RES",
	"spd": "TEM", "lck": "GLÜ"}

## Slot for the show-bet effect of package C (hearts flying into the show chip): an empty Control inside the shown
## lower third / panel; null before present() and for a defeat.
var show_slot: Control = null
## >= 0: continue automatically after this many seconds (autoplay 1.0); < 0: wait for the player (boss panel).
var auto_continue_sec: float = -1.0
## The form shown last: &"applaus" | &"boss" | &"flee" | &"defeat" | &"" (tests).
var form: StringName = &""
var shown: bool = false

var _root: Control = null
var _lowers: Array[Control] = []
var _panel: PanelContainer = null
var _continue: Button = null
var _done: bool = true
var _params: Dictionary = {}


## Optional {"capture": true, "demo": "regular" | "boss" | "flee" | "talent"}: a standalone still.
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = LAYER_LOWER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_ensure_root()
	if bool(_params.get("capture", false)) and get_parent() == get_tree().root:
		_present_demo.call_deferred()


func _ensure_root() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)


## Shows the result of `result` with the applied `rewards` (07 §8.9). A coroutine for the boss panel (returns when it
## closes); the lower thirds return at once.
func present(result: BattleResult, rewards: BattleRewards) -> void:
	if result == null:
		return
	_ensure_root()
	var rw: BattleRewards = rewards if rewards != null else BattleRewards.new()
	_clear()
	shown = true
	match result.outcome:
		BattleResult.Outcome.VICTORY:
			if result.is_boss:
				form = &"boss"
				_build_boss(result, rw)
			else:
				form = &"applaus"
				_build_applaus(result, rw)
		BattleResult.Outcome.FLED:
			form = &"flee"
			_build_flee()
		_:
			form = &"defeat"
			shown = false
	results_shown.emit(result)
	if form == &"boss":
		await _wait_boss()


func _clear() -> void:
	for c: Node in _root.get_children():
		_root.remove_child(c)
		c.queue_free()
	_lowers.clear()
	_panel = null
	_continue = null
	show_slot = null
	layer = LAYER_LOWER


# --- lower thirds (regular win, flight) ------------------------------------------------------------------------------

## "+36 EXP · +12 Cr · Werbepflaster" (07 §8.9).
static func applaus_line(result: BattleResult, rw: BattleRewards) -> String:
	var parts: PackedStringArray = []
	var exp_v: int = rw.exp if rw.exp > 0 else result.exp
	if exp_v > 0:
		parts.append("+%s EXP" % UiUtil.fmt_int(exp_v))
	var cr: int = rw.credits + rw.credits_refunded
	if cr <= 0:
		cr = result.credits + result.credits_refunded
	if cr > 0:
		parts.append("+%s Cr" % UiUtil.fmt_int(cr))
	var counts: Dictionary = {}
	var order: PackedStringArray = []
	var items: PackedStringArray = rw.items if not rw.items.is_empty() else result.drops
	for iid: String in items:
		if not counts.has(iid):
			order.append(iid)
		counts[iid] = int(counts.get(iid, 0)) + 1
	for iid2: String in order:
		var n: String = TranslationServer.translate(DB.item(iid2).name) if DB.has_id("items", iid2) else iid2
		parts.append(n + (" ×%d" % int(counts[iid2]) if int(counts[iid2]) > 1 else ""))
	for bid: String in rw.boxes:
		parts.append(TranslationServer.translate(DB.lootbox(bid).name) if DB.has_id("lootboxes", bid) else bid)
	return " · ".join(parts) if not parts.is_empty() else "Die Show geht weiter."


## Level-up line of the second lower third ("Kai: Level 4 · Graf Mopsula: Level 4"), "" without one.
static func level_line(rw: BattleRewards) -> String:
	var parts: PackedStringArray = []
	for li: LevelUpInfo in rw.level_ups:
		if li == null:
			continue
		var m: PartyMember = Game.state.member(li.member_id) if Game.state != null else null
		var who: String = UiUtil.member_name(m) if m != null else li.member_id
		parts.append("%s: Level %d" % [who, li.new_level])
	return " · ".join(parts)


## Talent choices earned by the level-ups (odd levels ≥ 3, 06 B).
static func talent_count(rw: BattleRewards) -> int:
	var n: int = 0
	for li: LevelUpInfo in rw.level_ups:
		if li == null:
			continue
		for lv in range(li.old_level + 1, li.new_level + 1):
			if Talents.is_talent_level(lv):
				n += 1
	return n


static func talent_text(n: int) -> String:
	return "TALENT BEREIT · im Safe Room wählen" if n == 1 else "%d TALENTE BEREIT · im Safe Room wählen" % n


func _build_applaus(result: BattleResult, rw: BattleRewards) -> void:
	var first: Control = _lower("APPLAUS!", applaus_line(result, rw), CombatStyle.C_GOLD)
	show_slot = first.get_node("Slot") as Control
	var lv: String = level_line(rw)
	var tc: int = talent_count(rw)
	if lv != "" or tc > 0:
		var second: Control = _lower("LEVEL UP!", lv if lv != "" else "Neue Stufe!", CombatStyle.C_CYAN)
		if tc > 0:
			var chip: Label = CombatStyle.label(talent_text(tc), 15, CombatStyle.C_GOLD, true)
			chip.name = "TalentChip"
			(second.get_node("Body/Col") as VBoxContainer).add_child(chip)
	_animate_lowers()


func _build_flee() -> void:
	var l: Control = _lower("TAKTISCHER RÜCKZUG", "Die Kamera hat alles gesehen. Das Publikum eher weniger begeistert.",
		Color("#ff9a2e"))
	show_slot = l.get_node("Slot") as Control
	_animate_lowers()


## A skewed broadcast lower third: title tab on the accent colour, text on ink (03_ART §9.2).
func _lower(title: String, text: String, col: Color) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Lower%d" % _lowers.size()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var tab: PanelContainer = PanelContainer.new()
	tab.name = "Title"
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb: StyleBoxFlat = CombatStyle.panel_box(col, Color(0, 0, 0, 0), 0, 0.21)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	tab.add_theme_stylebox_override("panel", sb)
	box.add_child(tab)
	var trow: HBoxContainer = HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(trow)
	var star: Control = UiIcon.make(&"star", CombatStyle.C_INK, 18)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(star)
	trow.add_child(CombatStyle.label(title, 22, CombatStyle.C_INK, true))
	var body: PanelContainer = PanelContainer.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.custom_minimum_size = Vector2(LOWER_W, 0)
	var bsb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PANEL_SOLID, Color(0, 0, 0, 0), 0, 0.21)
	bsb.content_margin_left = 16.0
	bsb.content_margin_right = 16.0
	bsb.content_margin_top = 4.0
	bsb.content_margin_bottom = 6.0
	body.add_theme_stylebox_override("panel", bsb)
	box.add_child(body)
	var col_box: VBoxContainer = VBoxContainer.new()
	col_box.name = "Col"
	col_box.add_theme_constant_override("separation", 2)
	col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(col_box)
	var l: Label = CombatStyle.label(UiUtil.glyph_safe(text), 17, CombatStyle.C_TEXT, false)
	l.name = "Text"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(LOWER_W - 40.0, 0)
	col_box.add_child(l)
	var slot: Control = Control.new()
	slot.name = "Slot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(1, 1)
	box.add_child(slot)
	_lowers.append(box)
	return box


## Texts of the shown lower thirds (tests).
func lower_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for c: Control in _lowers:
		var l: Label = c.get_node_or_null("Body/Col/Text") as Label
		if l != null:
			out.append(l.text)
	return out


func _layout_lowers() -> void:
	var in_tree: bool = _root.is_inside_tree()
	var vp: Vector2 = _root.get_viewport_rect().size if in_tree else Vector2(1280, 720)
	var ins: Dictionary = SafeAreaContainer.device_insets(_root.get_viewport() if in_tree else null)
	var bottom: float = vp.y - float(SafeAreaContainer.EDGE) - float(ins["bottom"]) - TICKER_CLEAR
	var left: float = float(SafeAreaContainer.EDGE + int(ins["left"]))
	var md: Node = ModDialogScript.current
	if md != null and is_instance_valid(md):
		var box: Rect2 = md.call("box_rect")
		if box.size.x > 0.0 and box.position.x < left + LOWER_W:
			bottom = minf(bottom, box.position.y - 10.0)
	bottom = minf(bottom, _stick_top() - 12.0)
	for c: Control in _lowers:
		c.reset_size()
		var h: float = c.get_combined_minimum_size().y
		bottom -= h
		c.position = Vector2(left, bottom)
		bottom -= 8.0


## Touch: top of the stick's rest ring (bottom left) — the lower thirds sit above it, never under the stick or the
## thumb on it. INF without the touch layer.
func _stick_top() -> float:
	var tc: Node = TouchScript.active
	if tc == null or not is_instance_valid(tc) or not bool(tc.call("is_shown")):
		return INF
	var js: Control = tc.get("joystick") as Control
	if js == null or not js.is_visible_in_tree():
		return INF
	return js.get_global_rect().position.y + (js.call("rest_position") as Vector2).y - JoystickScript.RADIUS


func _animate_lowers() -> void:
	_layout_lowers()
	_done = false
	if not is_inside_tree():
		return
	for i in _lowers.size():
		var c: Control = _lowers[i]
		var x0: float = c.position.x
		c.modulate.a = 0.0
		c.position.x = x0 - 40.0
		var tw: Tween = create_tween()
		tw.tween_interval(0.15 * float(i))
		tw.tween_property(c, "position:x", x0, LOWER_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "modulate:a", 1.0, LOWER_IN)
		tw.tween_interval(LOWER_HOLD)
		tw.tween_property(c, "modulate:a", 0.0, LOWER_OUT)
		if i == _lowers.size() - 1:
			tw.tween_callback(func() -> void:
				_done = true
				shown = false)


# --- boss credits panel ----------------------------------------------------------------------------------------------

func _build_boss(result: BattleResult, rw: BattleRewards) -> void:
	layer = LAYER_PANEL
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.6)
	UiUtil.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	UiUtil.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "Credits"
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var sb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PANEL_SOLID, CombatStyle.C_GOLD, 3)
	sb.set_content_margin_all(18.0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(CombatStyle.label("ABSPANN", 38, CombatStyle.C_GOLD, true))
	var boss_name: String = result.boss_id
	if DB.has_id("enemies", result.boss_id):
		boss_name = TranslationServer.translate(DB.enemy(result.boss_id).name)
	var sub: Label = CombatStyle.label(UiUtil.glyph_safe("%s ist besiegt. Großer Applaus!" % boss_name), 18,
		CombatStyle.C_TEXT_DIM, false)
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sub)
	v.add_child(_rule(CombatStyle.C_GOLD))
	_member_rows(v, result, rw)
	v.add_child(_rule(Color(1, 1, 1, 0.15)))
	var line: Label = CombatStyle.label(UiUtil.glyph_safe(applaus_line(result, rw)), 18, CombatStyle.C_GOLD, true)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(PANEL_W - 40.0, 0)
	v.add_child(line)
	if rw.followers != 0:
		v.add_child(CombatStyle.label("%s%s Follower" % ["+" if rw.followers >= 0 else "", UiUtil.fmt_int(rw.followers)],
			17, Color("#ff5fa2"), true))
	if not rw.achievements.is_empty():
		var names: PackedStringArray = []
		for id: String in rw.achievements:
			names.append(TranslationServer.translate(DB.achievement(id).name) if DB.has_id("achievements", id) else id)
		var ach: Label = CombatStyle.label(UiUtil.glyph_safe("Erfolge: " + ", ".join(names)), 16, CombatStyle.C_PAPER,
			false)
		ach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ach.custom_minimum_size = Vector2(PANEL_W - 40.0, 0)
		v.add_child(ach)
	show_slot = Control.new()
	show_slot.name = "ShowSlot"
	show_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_slot.custom_minimum_size = Vector2(PANEL_W - 40.0, 1)
	v.add_child(show_slot)
	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	var hint: Label = CombatStyle.label("Gleich gehen die Türen auf.", 15, CombatStyle.C_TEXT_DIM, false)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	_continue = Button.new()
	_continue.name = "Continue"
	_continue.text = "Weiter"
	_continue.theme_type_variation = &"ButtonBig"
	_continue.custom_minimum_size = Vector2(190, 64)
	_continue.focus_mode = Control.FOCUS_ALL
	_continue.pressed.connect(close)
	foot.add_child(_continue)
	UiTheme.ensure_hit_area(_continue)
	_done = false
	if is_inside_tree():
		get_tree().paused = true
		UiUtil.focus_later(_continue)
		_panel.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _member_rows(v: VBoxContainer, result: BattleResult, rw: BattleRewards) -> void:
	if Game.state == null:
		return
	for m: PartyMember in Game.state.party:
		if m == null:
			continue
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		var nm: Label = CombatStyle.label(UiUtil.glyph_safe(UiUtil.member_name(m)), 20, CombatStyle.C_PAPER, true)
		nm.custom_minimum_size = Vector2(170, 0)
		row.add_child(nm)
		row.add_child(CombatStyle.label("Lv %d" % m.level, 18, CombatStyle.C_GOLD, true))
		var bar: ProgressBar = ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = _ratio(m.level, m.exp)
		bar.add_theme_stylebox_override("fill", CombatStyle.panel_box(CombatStyle.C_CYAN))
		bar.add_theme_stylebox_override("background", CombatStyle.panel_box(Color(0, 0, 0, 0.55)))
		row.add_child(bar)
		var ko: bool = int(result.party_hp.get(m.id, 1)) <= 0
		var gain: int = rw.exp * BattleBridge.KO_EXP_PCT / 100 if ko else rw.exp
		row.add_child(CombatStyle.label("+%d EXP" % gain, 17, CombatStyle.C_CYAN, true))
		for li: LevelUpInfo in rw.level_ups:
			if li == null or li.member_id != m.id:
				continue
			var up: HBoxContainer = HBoxContainer.new()
			up.add_theme_constant_override("separation", 10)
			v.add_child(up)
			up.add_child(CombatStyle.label("LEVEL UP!", 16, CombatStyle.C_GOLD, true))
			var gains: PackedStringArray = []
			for key: String in ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]:
				var g: int = int(li.stat_gains.get(key, 0))
				if g != 0:
					gains.append("%s +%d" % [str(STAT_NAMES[key]), g])
			up.add_child(CombatStyle.label(" · ".join(gains), 15, CombatStyle.C_TEXT_DIM, false))
			var n: int = 0
			for lv in range(li.old_level + 1, li.new_level + 1):
				if Talents.is_talent_level(lv):
					n += 1
			if n > 0:
				var chip: Label = CombatStyle.label(talent_text(n), 15, CombatStyle.C_GOLD, true)
				chip.name = "TalentChip"
				v.add_child(chip)


static func _ratio(level: int, exp_value: int) -> float:
	var need: int = Progression.exp_to_next(level)
	return 1.0 if need <= 0 else clampf(float(exp_value) / float(need), 0.0, 1.0)


func _rule(col: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(col, 0.6)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _wait_boss() -> void:
	if not is_inside_tree():
		return
	var t: float = 0.0
	while not _done:
		await get_tree().process_frame
		t += get_process_delta_time()
		if auto_continue_sec >= 0.0 and t >= maxf(0.05, auto_continue_sec):
			close()


## Closes the boss panel ("Weiter", ui_cancel, autoplay) and unpauses the tree.
func close() -> void:
	if _done:
		return
	_done = true
	shown = false
	Sfx.play_ui(&"ui_confirm")
	if is_inside_tree() and form == &"boss":
		get_tree().paused = false
	_clear()


func is_done() -> bool:
	return _done


func _unhandled_input(event: InputEvent) -> void:
	if form == &"boss" and not _done and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# --- capture still ---------------------------------------------------------------------------------------------------

func _present_demo() -> void:
	Game.ensure_state()
	var kind: String = str(_params.get("demo", "regular"))
	var r: BattleResult = BattleResult.new()
	var rw: BattleRewards = BattleRewards.new()
	r.outcome = BattleResult.Outcome.FLED if kind == "flee" else BattleResult.Outcome.VICTORY
	r.exp = 36
	r.credits = 12
	rw.exp = 36
	rw.credits = 12
	rw.followers = 64
	if DB.has_id("items", "itm_bandage"):
		rw.items = PackedStringArray(["itm_bandage"])
	if kind == "boss":
		r.is_boss = true
		r.boss_id = "enm_boss_hausmeister"
		rw.exp = 740
		rw.credits = 120
		if DB.has_id("lootboxes", "box_gold"):
			rw.boxes = PackedStringArray(["box_gold"])
	if kind == "talent" and Game.state != null:
		var info: LevelUpInfo = LevelUpInfo.new()
		info.member_id = "kai"
		info.old_level = 2
		info.new_level = 3
		info.stat_gains = {"hp": 9, "mp": 2, "str": 2}
		rw.level_ups = [info]
	present(r, rw)
