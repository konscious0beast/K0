extends CanvasLayer
## Battle results (02_TECH §1.6, §5.7; GDD §3.12/§14.5): EXP per member (bars fill, LEVEL UP banner with stat gains
## and learned skills), credits (+ overkill bonus, refunded / lost credits), items and boss boxes, followers, unlocked
## achievements; "Weiter" (default focus, ButtonBig with an 88 px hit area) continues — also after a defeat. Fled /
## defeat show a short card. Autoplay continues on its own after 1.0 s (auto_continue_sec). Layer 6: above the
## battle HUD, below the show overlay / M.O.D. box; UiTheme is assigned to the root (CanvasLayer children do not
## inherit root.theme). Private M5 script (no class_name).
## 06 package B: a level-up onto an odd level >= 3 adds the chip "TALENT BEREIT · im Safe Room wählen" under the
## member's LEVEL UP line — a hint only, the choice itself waits for the Talent-Show (never an interruption here).

signal closed
signal frame_ticked

const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const PANEL_W: float = 700.0
const TOP_CLEAR: float = 48.0           # below the show overlay's top bar
const BOTTOM_CLEAR: float = 176.0       # above the M.O.D. text box (bottom center) and the chat ticker
## Right of the show overlay's toast column / sponsor lower third (bottom left, up to x ≈ 510 at 1280 × 720): the
## achievement and lootbox toasts arrive exactly at the end of a battle.
const LEFT_CLEAR: float = 470.0
const RIGHT_CLEAR: float = 24.0
const STAT_NAMES: Dictionary = {"hp": "HP", "mp": "MP", "str": "ANG", "mag": "MAG", "def": "VER", "res": "RES",
	"spd": "TEM", "lck": "GLÜ"}

## >= 0: continue automatically after this many seconds (autoplay 1.0); < 0: wait for "Weiter".
var auto_continue_sec: float = -1.0
## member id → {"level": int, "exp": int} before Game.apply_battle_result (set by the controller).
var before: Dictionary = {}
var shown: bool = false
var outcome: int = -1

var continue_button: Button = null
var _root: Control = null
var _panel: PanelContainer = null
var _rows: VBoxContainer = null
var _done: bool = false
var _bars: Array[Dictionary] = []     # {"bar", "from", "to", "levels", "label"}
var _params: Dictionary = {}


## Optional: {"capture": true} → standalone still (02_TECH §11.3) with a sample victory (the scene is otherwise empty
## until the controller calls present()).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 6


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	# Controls under a CanvasLayer do not inherit root.theme (UiUtil.apply_theme note, 4.7.2): assign it explicitly
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	if bool(_params.get("capture", false)) and get_parent() == get_tree().root:
		_present_demo.call_deferred()


## Capture still: a victory over two Kanalratten with a level up-free EXP gain, overkill credits and achievements.
## params {"demo": "talent"} (06 package B): Kai levels up onto L3 — LEVEL UP line + "TALENT BEREIT" chip.
func _present_demo() -> void:
	Game.ensure_state()
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.VICTORY
	r.exp = 24
	r.credits = 14
	r.overkill_credits = 2
	r.kills = 2
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = 24
	rw.credits = 14
	rw.overkill_credits = 2
	rw.followers = 83
	for id: String in ["ach_first_blood", "ach_first_win", "ach_overkill"]:
		if DB.has_id("achievements", id):
			rw.achievements.append(id)
	for m: PartyMember in (Game.state.party if Game.state != null else []):
		if m != null:
			before[m.id] = {"level": m.level, "exp": m.exp}
			m.exp += rw.exp                # ephemeral capture state: the bars fill like after a real battle
	if str(_params.get("demo", "")) == "talent" and Game.state != null:
		var kai: PartyMember = Game.state.member("kai")
		before["kai"] = {"level": 2, "exp": 60}
		kai.level = 3
		kai.exp = 11
		var info: LevelUpInfo = LevelUpInfo.new()
		info.member_id = "kai"
		info.old_level = 2
		info.new_level = 3
		info.stat_gains = {"hp": 9, "mp": 2, "str": 2, "def": 2, "res": 1}
		info.learned = PackedStringArray(["skl_kai_sweep"]) if DB.has_id("skills", "skl_kai_sweep") else []
		rw.level_ups = [info]
	present(r, rw)


## Coroutine: shows the results and returns when the player continues (or after auto_continue_sec).
func present(result: BattleResult, rewards: BattleRewards) -> void:
	if result == null:
		return
	outcome = int(result.outcome)
	_build(result, rewards if rewards != null else BattleRewards.new())
	shown = true
	_done = false
	_root.visible = true
	if is_inside_tree():
		_panel.modulate.a = 0.0
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.94, 0.94)
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
		tw.tween_property(_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_animate_bars()
	if continue_button != null:
		continue_button.grab_focus.call_deferred()
	var wait_sec: float = auto_continue_sec
	if wait_sec >= 0.0 and is_inside_tree():
		var t: float = 0.0
		while t < maxf(0.05, wait_sec) and not _done:
			await frame_ticked
			t += get_process_delta_time()
		_close()
	elif not _done:
		await closed


func _process(_delta: float) -> void:
	frame_ticked.emit()


func _close() -> void:
	if _done:
		return
	_done = true
	shown = false
	if _root != null:
		_root.visible = false
	closed.emit()


func _on_continue() -> void:
	Sfx.play_ui(&"ui_confirm")
	_close()


func _unhandled_input(event: InputEvent) -> void:
	if shown and not _done and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_continue()


func _build(result: BattleResult, rw: BattleRewards) -> void:
	for c: Node in _root.get_children():
		c.queue_free()
	_bars.clear()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = TOP_CLEAR
	center.offset_bottom = -BOTTOM_CLEAR       # above the M.O.D. text box (bottom center, layer 45)
	center.offset_left = LEFT_CLEAR
	center.offset_right = -RIGHT_CLEAR
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, 0)
	var head_col: Color = Color("#ffc93c")
	var title: String = tr("SIEG!")
	var sub: String = tr("Kampfbilanz")
	match result.outcome:
		BattleResult.Outcome.FLED:
			head_col = Color("#ff9a2e")
			title = tr("GEFLOHEN")
			sub = tr("Die Kamera hat alles gesehen.")
		BattleResult.Outcome.DEFEAT:
			head_col = Color("#ff4d4d")
			title = tr("K.O.")
			sub = tr("Sendeschluss")
	_panel.add_theme_stylebox_override("panel", HudStyle.show_box(Color(0.07, 0.045, 0.1, 0.95), head_col, 3, 0.0,
		Vector4(22, 12, 22, 14)))
	center.add_child(_panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	head.add_child(HudStyle.label(title, 40, head_col, true, 6))
	var s: Label = HudStyle.label(sub.to_upper(), 16, Color("#b3a7c9"), true, 2)
	s.size_flags_vertical = Control.SIZE_SHRINK_END
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(s)
	if result.outcome == BattleResult.Outcome.VICTORY and rw.exp > 0:
		var exp_l: Label = HudStyle.mono_label("+%s EXP" % HudStyle.fmt_int(rw.exp), 22, Color("#22d3ee"))
		exp_l.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(exp_l)
	v.add_child(_rule(head_col))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_rows)
	if result.outcome != BattleResult.Outcome.DEFEAT:
		_member_rows(result, rw)
		v.add_child(_rule(Color(1, 1, 1, 0.15)))
		v.add_child(_reward_row(result, rw))
	else:
		var l: Label = HudStyle.label(tr("Die Party ist gefallen. Die Quote war trotzdem gut."), 20, HudStyle.C_PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(PANEL_W - 60.0, 0)
		_rows.add_child(l)
	if not rw.achievements.is_empty():
		v.add_child(_achievement_block(rw.achievements))
	var foot: HBoxContainer = HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 12)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	var hint: Label = HudStyle.label(tr("Die Show geht weiter."), 15, Color("#b3a7c9"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(hint)
	continue_button = Button.new()
	continue_button.name = "Continue"
	continue_button.text = tr("Weiter")
	continue_button.theme_type_variation = &"ButtonBig"
	continue_button.custom_minimum_size = Vector2(190, 64)
	continue_button.focus_mode = Control.FOCUS_ALL
	continue_button.pressed.connect(_on_continue)
	foot.add_child(continue_button)
	UiTheme.ensure_hit_area(continue_button)            # >= 88 px hit area (02_TECH §10.2), visible ButtonBig
	continue_button.focus_neighbor_left = continue_button.get_path_to(continue_button)
	continue_button.focus_neighbor_right = continue_button.get_path_to(continue_button)
	continue_button.focus_neighbor_top = continue_button.get_path_to(continue_button)
	continue_button.focus_neighbor_bottom = continue_button.get_path_to(continue_button)


func _rule(col: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color(col, 0.6)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _member_rows(result: BattleResult, rw: BattleRewards) -> void:
	if Game.state == null:
		return
	for m: PartyMember in Game.state.party:
		if m == null:
			continue
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows.add_child(row)
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(line)
		var nm: Label = HudStyle.label(m.display_name, 22, HudStyle.C_PAPER, true, 3)
		nm.custom_minimum_size = Vector2(130, 0)
		line.add_child(nm)
		var lv: Label = HudStyle.mono_label("Lv %d" % m.level, 20, Color("#ffc93c"))
		lv.custom_minimum_size = Vector2(66, 0)
		line.add_child(lv)
		var bar: HudStyle.Bar = HudStyle.Bar.new(Color("#22d3ee"), 10.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(bar)
		var ko: bool = int(result.party_hp.get(m.id, 1)) <= 0
		var gain: int = 0
		if result.outcome == BattleResult.Outcome.VICTORY:
			gain = rw.exp * BattleBridge.KO_EXP_PCT / 100 if ko else rw.exp
		var gl: Label = HudStyle.mono_label("+%d EXP" % gain, 18, Color("#22d3ee") if gain > 0 else Color("#6a6278"))
		gl.custom_minimum_size = Vector2(104, 0)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(gl)
		var b: Dictionary = before.get(m.id, {"level": m.level, "exp": m.exp})
		var from_ratio: float = _ratio(int(b.get("level", m.level)), int(b.get("exp", m.exp)))
		var to_ratio: float = _ratio(m.level, m.exp)
		var levels: int = maxi(0, m.level - int(b.get("level", m.level)))
		bar.set_ratio(from_ratio, false)
		_bars.append({"bar": bar, "from": from_ratio, "to": to_ratio, "levels": levels, "label": lv,
			"level": m.level})
		var info: LevelUpInfo = null
		for li: LevelUpInfo in rw.level_ups:
			if li != null and li.member_id == m.id:
				info = li
		if info != null:
			var up: HBoxContainer = HBoxContainer.new()
			up.add_theme_constant_override("separation", 10)
			up.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(up)
			up.add_child(HudStyle.label(tr("LEVEL UP!"), 17, Color("#ffc93c"), true, 4))
			var parts: PackedStringArray = []
			for key: String in ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]:
				var g: int = int(info.stat_gains.get(key, 0))
				if g != 0:
					parts.append("%s +%d" % [str(STAT_NAMES[key]), g])
			var gains: Label = HudStyle.label(" · ".join(parts), 15, Color("#d9d0ea"))
			gains.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			up.add_child(gains)
			if not info.learned.is_empty():
				var names: PackedStringArray = []
				for sid: String in info.learned:
					names.append(tr(DB.skill(sid).name) if DB.has_id("skills", sid) else sid)
				var learned: Label = HudStyle.label(tr("Neu: %s") % ", ".join(names), 15, Color("#4ade80"), true)
				learned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				learned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				learned.clip_text = true
				learned.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if gains.text.length() + learned.text.length() > 64:
					learned.custom_minimum_size = Vector2(PANEL_W - 60.0, 0)
					row.add_child(learned)           # long stat line: learned skills on their own line
				else:
					up.add_child(learned)
		elif ko and result.outcome == BattleResult.Outcome.VICTORY:
			row.add_child(HudStyle.label(tr("K.O. – halbe EXP, zurück mit 1 HP"), 15, Color("#ff8080")))
		if info != null and _talent_levels(info) > 0:               # 06 package B
			row.add_child(_talent_chip(_talent_levels(info)))


## Credits | Follower | Beute in one row.
func _reward_row(result: BattleResult, rw: BattleRewards) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if result.outcome == BattleResult.Outcome.VICTORY:
		var cr: String = "+%s Cr" % HudStyle.fmt_int(rw.credits + rw.credits_refunded)
		if rw.overkill_credits > 0:
			cr += " " + tr("(+%d Overkill)") % rw.overkill_credits
		_cell(row, "coin", Color("#ffc93c"), cr, Color("#ffc93c"))
	if rw.credits_lost > 0:
		_cell(row, "coin", Color("#ff4d4d"), "-%s Cr" % HudStyle.fmt_int(rw.credits_lost), Color("#ff8080"))
	var fol_col: Color = Color("#ff5fa2") if rw.followers >= 0 else Color("#ff8080")
	_cell(row, "heart", Color("#ff2e88"), ("+" if rw.followers >= 0 else "") + HudStyle.fmt_int(rw.followers)
		+ " " + tr("Follower"), fol_col)
	var items: Dictionary = {}
	var order: PackedStringArray = []
	for iid: String in rw.items:
		if not items.has(iid):
			order.append(iid)
		items[iid] = int(items.get(iid, 0)) + 1
	var names: PackedStringArray = []
	for iid2: String in order:
		var n: String = tr(DB.item(iid2).name) if DB.has_id("items", iid2) else iid2
		names.append(n + (" ×%d" % int(items[iid2]) if int(items[iid2]) > 1 else ""))
	for bid: String in rw.boxes:
		names.append(tr(DB.lootbox(bid).name) if DB.has_id("lootboxes", bid) else bid)
	if not names.is_empty():
		var loot: HBoxContainer = _cell(row, "box", Color("#4ade80"), ", ".join(names), HudStyle.C_PAPER)
		loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lv: Label = loot.get_node("Value") as Label
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return row


func _cell(row: HBoxContainer, icon: String, icon_col: Color, value: String, value_col: Color) -> HBoxContainer:
	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: HudStyle.Icon = HudStyle.Icon.new(icon, icon_col, 20)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(ic)
	var val: Label = HudStyle.label(value, 19, value_col, true)
	val.name = "Value"
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(val)
	row.add_child(cell)
	return cell


## 06 package B: talent choices earned by this level-up (odd levels >= 3 in old+1..new).
static func _talent_levels(info: LevelUpInfo) -> int:
	var n: int = 0
	for lv in range(info.old_level + 1, info.new_level + 1):
		if Talents.is_talent_level(lv):
			n += 1
	return n


## Gold chip "TALENT BEREIT · im Safe Room wählen" ("2 TALENTE BEREIT" for several choices at once).
func _talent_chip(n: int) -> Control:
	var wrap: HBoxContainer = HBoxContainer.new()
	wrap.name = "TalentChip"
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = HudStyle.show_box(Color(1.0, 0.79, 0.24, 0.18), Color("#ffc93c"), 2, 0.0,
		Vector4(10, 3, 12, 3))
	sb.shadow_size = 0
	chip.add_theme_stylebox_override("panel", sb)
	wrap.add_child(chip)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var star: HudStyle.Icon = HudStyle.Icon.new("star", Color("#ffc93c"), 16)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(star)
	var head: String = tr("TALENT BEREIT") if n <= 1 else tr("%d TALENTE BEREIT") % n
	row.add_child(HudStyle.label(head, 16, Color("#ffc93c"), true, 3))
	row.add_child(HudStyle.label(tr("im Safe Room wählen"), 15, Color("#d9d0ea")))
	return wrap


func _achievement_block(ids: PackedStringArray) -> Control:
	var box: HFlowContainer = HFlowContainer.new()
	box.add_theme_constant_override("h_separation", 8)
	box.add_theme_constant_override("v_separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in ids:
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb: StyleBoxFlat = HudStyle.show_box(Color(1.0, 0.79, 0.24, 0.14), Color("#ffc93c"), 1, 0.0,
			Vector4(8, 3, 10, 3))
		sb.shadow_size = 0
		chip.add_theme_stylebox_override("panel", sb)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(row)
		var star: HudStyle.Icon = HudStyle.Icon.new("star", Color("#ffc93c"), 16)
		star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(star)
		var n: String = tr(DB.achievement(id).name) if DB.has_id("achievements", id) else id
		row.add_child(HudStyle.label(n, 16, HudStyle.C_PAPER, true))
		box.add_child(chip)
	return box


func _ratio(level: int, exp_value: int) -> float:
	var need: int = Progression.exp_to_next(level)
	if need <= 0:
		return 1.0
	return clampf(float(exp_value) / float(need), 0.0, 1.0)


func _animate_bars() -> void:
	for d: Dictionary in _bars:
		var bar: HudStyle.Bar = d["bar"]
		var levels: int = int(d["levels"])
		var tw: Tween = bar.create_tween()
		tw.tween_interval(0.25)
		var lv_label: Label = d["label"]
		var final_level: int = int(d["level"])
		if levels > 0:
			lv_label.text = "Lv %d" % (final_level - levels)
		for i in levels:
			tw.tween_method(func(r: float) -> void: bar.set_ratio(r, false), float(d["from"]) if i == 0 else 0.0, 1.0,
				0.35)
			var shown_level: int = final_level - levels + i + 1
			tw.tween_callback(func() -> void:
				lv_label.text = "Lv %d" % shown_level
				Sfx.play(&"level_up"))
		tw.tween_method(func(r: float) -> void: bar.set_ratio(r, false), 0.0 if levels > 0 else float(d["from"]),
			float(d["to"]), 0.45)
