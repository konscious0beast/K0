extends CanvasLayer
## Lootbox opening (02_TECH §1.6, GDD §9.4, 03_ART §7.2), modal layer 60 in the safe room: box shelf with counts, the
## published odds of the selected box (per draw, chance of ≥ 1 rare+ / epic for its draw count, guarantee, pity state)
## and the opening: box jumps to centre + M.O.D. `lootbox_open_<tier>`; 3 taps (shake, punch, light tier colour →
## rarity colour of the best draw from tap 2), the lid flips open (−110° in 0.2 s), burst, cards fly out of the box
## in an arc and are revealed one by one (0.4 s, rarity border, "DUPLIKAT",
## "GARANTIE!" + M.O.D. `lootbox_pity`). Buttons "Alle aufdecken" · "Nächste Box" · "Fertig". The roll is
## Game.open_lootbox(box) at the first tap (recorded; no undo afterwards). Footer always: not purchasable.

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const SceneKit := preload("res://scenes/ui/scene_kit.gd")
const MenuBase := preload("res://scenes/ui/menu_base.gd")
const Odds := preload("res://scenes/safe_room/lootbox_odds.gd")
const TAPS: int = 3
const REVEAL_SEC: float = 0.4
const FOOTER: String = "Lootboxen in PRIME TIME DUNGEON können nicht gekauft werden."
const DEMO_BOXES: PackedStringArray = ["box_silver", "box_bronze", "box_bronze", "box_fan"]
const LID_OPEN_DEG: float = -110.0
const LID_SEC: float = 0.2
const ODDS_FONT: int = 16

var state: StringName = &"select"           # &"select" | &"tease" | &"reveal" | &"done"
var selected_box: String = ""
var taps: int = 0
var rewards: Array[LootReward] = []
var revealed: int = 0

var _params: Dictionary = {}
var _demo: bool = false
var _root: Control
var _list: VBoxContainer
var _box_buttons: Array[Control] = []
var _odds_box: VBoxContainer
var _stage_vp: SubViewport
var _box_pivot: Node3D
var _box_node: Node3D
var _light: OmniLight3D
var _tap_button: Button
var _cards: HBoxContainer
var _banner: PanelContainer
var _all_btn: Button
var _next_btn: Button
var _done_btn: Button
var _hint: Label
var _burst: CPUParticles2D
var _stage_view: SubViewportContainer
var _t: float = 0.0
var _closing: bool = false
var _reveal_tween: Tween = null


func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 60


func _ready() -> void:
	Game.ensure_state()
	_demo = bool(_params.get("capture", false))
	_build()
	_refresh_list()
	if _demo:
		_start_demo()
	else:
		_focus_list()
	Sfx.play_ui(&"ui_confirm")


func _process(delta: float) -> void:
	_t += delta
	if _box_pivot != null and state == &"select":
		_box_pivot.rotation.y = sin(_t * 0.6) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		match state:
			&"select":
				close()
			&"reveal":
				reveal_all()
			&"done":
				finish()


## Pending boxes grouped: box id → count (demo list in captures).
func pending() -> Dictionary:
	var out: Dictionary = {}
	var src: PackedStringArray = DEMO_BOXES if _demo else (Game.state.pending_lootboxes if Game.state != null
		else PackedStringArray())
	for id: String in src:
		out[id] = int(out.get(id, 0)) + 1
	return out


func select_box(box_id: String) -> void:
	if state != &"select" and state != &"done":
		return
	selected_box = box_id
	state = &"select"
	_show_box(box_id)
	_show_odds(box_id)


## Moves the selected box to the stage and announces it (state tease).
func start_opening() -> void:
	if selected_box == "" or state != &"select":
		return
	state = &"tease"
	taps = 0
	rewards.clear()
	revealed = 0
	_clear_cards()
	_banner.visible = false
	var def: LootboxDef = DB.lootbox(selected_box) if DB.has_id("lootboxes", selected_box) else null
	if def != null:
		Show.say(def.effective_mod_tag())
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_box_pivot, "position:y", 0.45, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_box_pivot, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_box_pivot.rotation.y = 0.0
	_update_buttons()
	UiUtil.focus_later(_tap_button)


## One tap (3 open the box). The first tap rolls the rewards (Game.open_lootbox).
func tap() -> void:
	if state == &"select":
		start_opening()
		return
	if state != &"tease":
		return
	taps += 1
	if taps == 1:
		rewards = Game.open_lootbox(selected_box) if not _demo else _demo_rewards()
	Sfx.play(&"lootbox_shake", 0.0, 1.0 + taps * 0.08)
	var col: Color = UiUtil.box_color(selected_box)
	if taps >= 2:
		col = UiUtil.rarity_color(best_rarity())
	_light.light_color = col
	_light.light_energy = [1.0, 2.5, 4.0][clampi(taps - 1, 0, 2)]
	if is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(_box_pivot, "rotation:z", deg_to_rad(6.0), 0.05)
		tw.tween_property(_box_pivot, "rotation:z", deg_to_rad(-6.0), 0.05)
		tw.tween_property(_box_pivot, "rotation:z", 0.0, 0.05)
		var tw2: Tween = create_tween()
		tw2.tween_property(_box_pivot, "scale", Vector3.ONE * 1.08, 0.07)
		tw2.tween_property(_box_pivot, "scale", Vector3.ONE, 0.08)
	if taps >= TAPS:
		_explode()


## Reveals every remaining card at once.
func reveal_all() -> void:
	if state != &"reveal":
		return
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	for c: Node in _cards.get_children():
		_flip(c as Control, false)
	revealed = _cards.get_child_count()
	_after_reveal()


## "Nächste Box": back to selection with the next pending box focused.
func next_box() -> void:
	state = &"select"
	_dim_stage(false)
	_refresh_list()
	_clear_cards()
	_banner.visible = false
	var p: Dictionary = pending()
	if p.is_empty():
		finish()
		return
	var id: String = selected_box if p.has(selected_box) else str(p.keys()[0])
	select_box(id)
	_update_buttons()
	_focus_list()


func finish() -> void:
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


func best_rarity() -> String:
	var best: int = 0
	for r: LootReward in rewards:
		if r != null:
			best = maxi(best, UiUtil.RARITY_ORDER.find(r.rarity))
	return UiUtil.RARITY_ORDER[maxi(best, 0)]


func card_count() -> int:
	return _cards.get_child_count()


# --- internals --------------------------------------------------------------------------------------------------------

func _explode() -> void:
	state = &"reveal"
	Sfx.play(&"lootbox_open")
	if best_rarity() == "epic":
		Sfx.play(&"lootbox_rare")
	_burst.color = UiUtil.rarity_color(best_rarity())
	_burst.position = _stage_view.position + _stage_view.size * Vector2(0.5, 0.42)
	var lid: Node3D = _box_node.get_node_or_null("Lid") as Node3D if _box_node != null else null
	_spawn_cards()
	_update_buttons()
	UiUtil.focus_later(_all_btn)
	if not is_inside_tree():
		if lid != null:
			lid.rotation.x = deg_to_rad(LID_OPEN_DEG)
		_dim_stage(true)
		reveal_all()
		return
	# Lid flips open, light bursts out, then the cards fly out in an arc; the box fades only after that.
	var tw: Tween = create_tween()
	if lid != null:
		tw.tween_property(lid, "rotation:x", deg_to_rad(LID_OPEN_DEG), LID_SEC).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_burst.restart()
		_burst.emitting = true
		Vfx.spawn(&"chest_open", _box_pivot, _box_pivot.global_position if _box_pivot.is_inside_tree() else Vector3.ZERO))
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: _dim_stage(true))
	_fly_cards(LID_SEC)
	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(LID_SEC + 0.55)
	for c: Node in _cards.get_children():
		var card: Control = c as Control
		_reveal_tween.tween_callback(func() -> void:
			_flip(card, true)
			revealed += 1)
		_reveal_tween.tween_interval(REVEAL_SEC)
	_reveal_tween.tween_callback(_after_reveal)


func _after_reveal() -> void:
	if state == &"done":
		return
	state = &"done"
	var pity: bool = false
	for r: LootReward in rewards:
		if r != null and r.pity:
			pity = true
	if pity:
		_banner.visible = true
		if not _demo:
			Show.say("lootbox_pity")
	_update_buttons()
	UiUtil.focus_later((_next_btn if _next_btn.visible else _done_btn))
	_refresh_list()
	_show_odds(selected_box)


func _spawn_cards() -> void:
	_clear_cards()
	var list: Array[LootReward] = rewards
	if list.is_empty():
		var empty: LootReward = LootReward.new()
		empty.kind = "nothing"
		empty.rarity = "common"
		list = [empty]
	for r: LootReward in list:
		_cards.add_child(_make_card(r))


## Cards start small at the box (stage centre) and fly to their slot in an arc (staggered), after the lid opened.
func _fly_cards(delay: float) -> void:
	var i: int = 0
	for c: Node in _cards.get_children():
		var card: Control = c as Control
		card.modulate.a = 0.0
		var t: Tween = card.create_tween()
		t.tween_interval(delay + 0.06 * i)
		t.tween_callback(func() -> void:
			card.pivot_offset = card.size * 0.5
			var target: Vector2 = card.position
			var from: Vector2 = Vector2(_cards.size.x * 0.5 - card.size.x * 0.5, -_cards.position.y * 0.35)
			card.position = from
			card.scale = Vector2(0.3, 0.3)
			card.modulate.a = 1.0
			var arc: Tween = card.create_tween().set_parallel(true)
			arc.tween_method(func(k: float) -> void:
				card.position = from.lerp(target, k) + Vector2(0, -120.0 * sin(k * PI)), 0.0, 1.0, 0.38) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			arc.tween_property(card, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		i += 1


func _dim_stage(on: bool) -> void:
	if _stage_view == null:
		return
	if not _stage_view.is_inside_tree():
		_stage_view.modulate.a = 0.3 if on else 1.0
		return
	create_tween().tween_property(_stage_view, "modulate:a", 0.3 if on else 1.0, 0.3)


func _clear_cards() -> void:
	for c: Node in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()


func _make_card(r: LootReward) -> Control:
	var col: Color = UiUtil.rarity_color(r.rarity)
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(170, 214)
	card.add_theme_stylebox_override("panel", UiUtil.box_style(Color("#1a1028"), col, 4, 0.0, 10, 10))
	var face: VBoxContainer = UiUtil.vbox(6)
	face.name = "Face"
	face.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(face)
	var rl: Label = UiUtil.label(UiUtil.rarity_name(r.rarity).to_upper(), &"", 15, col)
	rl.add_theme_font_override("font", UiTheme.font_bold())
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.add_child(rl)
	var icon_kind: StringName = &"coin" if r.kind == "credits" else (&"cross" if r.kind == "nothing" else
		MenuBase.item_icon(r.id))
	var ic: Control = UiIcon.make(icon_kind, UiTheme.C_GOLD if r.kind == "credits" else col.lightened(0.2), 60)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.add_child(ic)
	var title: String = "%s Credits" % UiUtil.fmt_int(r.amount) if r.kind == "credits" else (
		"Nichts" if r.kind == "nothing" else UiUtil.item_name(r.id))
	var tl: Label = UiUtil.label(title, &"", 18)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(150, 0)
	face.add_child(tl)
	if r.kind == "item" and r.amount > 1:
		var al: Label = UiUtil.label("× %d" % r.amount, &"", 18, UiTheme.C_TEXT_DIM)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(al)
	if r.converted_from != "":
		var dl: Label = UiUtil.label("DUPLIKAT: %s" % UiUtil.item_name(r.converted_from), &"", 15, UiTheme.C_GOLD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size = Vector2(150, 0)
		face.add_child(dl)
	if r.pity:
		var pl: Label = UiUtil.label("GARANTIE!", &"", 15, UiTheme.C_ACCENT)
		pl.add_theme_font_override("font", UiTheme.font_bold())
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.add_child(pl)
	var back: Control = UiIcon.make(&"drone", UiTheme.C_ACCENT_2, 72)
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_child(back)
	face.visible = false
	card.set_meta("revealed", false)
	return card


func _flip(card: Control, animate: bool) -> void:
	if card == null or bool(card.get_meta("revealed", false)):
		return
	card.set_meta("revealed", true)
	var face: Control = card.get_node("Face") as Control
	var back: Control = card.get_node("Back") as Control
	if not animate or not card.is_inside_tree():
		face.visible = true
		back.visible = false
		card.scale = Vector2.ONE
		return
	card.pivot_offset = card.size * 0.5
	var tw: Tween = card.create_tween()
	tw.tween_property(card, "scale:x", 0.0, REVEAL_SEC * 0.4)
	tw.tween_callback(func() -> void:
		face.visible = true
		back.visible = false
		Sfx.play_ui(&"coin"))
	tw.tween_property(card, "scale:x", 1.0, REVEAL_SEC * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_buttons() -> void:
	_tap_button.visible = state == &"tease" or state == &"select"
	_tap_button.disabled = selected_box == "" or (state == &"select" and pending().is_empty())
	_tap_button.text = "Öffnen" if state == &"select" else "Antippen  %d / %d" % [taps, TAPS]
	_all_btn.visible = state == &"reveal"
	var more: bool = not pending().is_empty() and not _demo
	_next_btn.visible = state == &"done" and more
	_done_btn.visible = state == &"done" or state == &"select"
	_hint.text = {&"select": "Box wählen, dann dreimal antippen.", &"tease": "Weiter tippen! Das Licht verrät etwas …",
		&"reveal": "Die Karten werden aufgedeckt …", &"done": "Beute liegt im Inventar."}.get(state, "") as String
	var chain: Array[Control] = []
	for b: Button in [_tap_button, _all_btn, _next_btn, _done_btn]:
		if b.visible:
			chain.append(b)
	UiUtil.wire_horizontal(chain)


func _focus_list() -> void:
	for b: Control in _box_buttons:
		if b.get_meta("box_id", "") == selected_box:
			UiUtil.focus_later(b)
			return
	if not _box_buttons.is_empty():
		UiUtil.focus_later(_box_buttons[0])
	else:
		UiUtil.focus_later(_done_btn)


func _refresh_list() -> void:
	MenuBase.clear(_list)
	_box_buttons.clear()
	var p: Dictionary = pending()
	var ids: Array = p.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ta: int = DB.lootbox(str(a)).tier if DB.has_id("lootboxes", str(a)) else 0
		var tb: int = DB.lootbox(str(b)).tier if DB.has_id("lootboxes", str(b)) else 0
		return ta > tb)
	for id: Variant in ids:
		var box_id: String = str(id)
		var name_text: String = UiUtil.tr_text(DB.lootbox(box_id).name) if DB.has_id("lootboxes", box_id) else box_id
		var b: Button = MenuBase.list_button(name_text, &"box", UiUtil.box_color(box_id), "× %d" % int(p[id]))
		b.set_meta("box_id", box_id)
		b.focus_entered.connect(func() -> void: select_box(box_id))
		b.pressed.connect(func() -> void:
			select_box(box_id)
			start_opening())
		_list.add_child(b)
		_box_buttons.append(b)
	if _box_buttons.is_empty():
		_list.add_child(MenuBase.empty_note("Keine Lootboxen. Achievements, Bosse und Follower-Meilensteine bringen welche."))
		if selected_box == "" and DB.has_id("lootboxes", "box_bronze"):
			_show_odds("box_bronze")
	elif state == &"select" and (selected_box == "" or not p.has(selected_box)):
		select_box(str(ids[0]))      # never while "done": the opened box and "Nächste Box" stay until the player moves on
	UiUtil.wire_vertical(_box_buttons)
	_update_buttons()


func _show_box(box_id: String) -> void:
	if _box_node != null:
		_box_node.queue_free()
	_box_node = SceneKit.lootbox_mesh(box_id, UiUtil.box_color(box_id))
	_box_node.scale = Vector3.ONE * 1.6
	_box_pivot.add_child(_box_node)
	_box_pivot.scale = Vector3.ONE
	_box_pivot.position = Vector3.ZERO
	_light.light_color = UiUtil.box_color(box_id)
	_light.light_energy = 1.0


func _show_odds(box_id: String) -> void:
	MenuBase.clear(_odds_box)
	if not DB.has_id("lootboxes", box_id):
		return
	var def: LootboxDef = DB.lootbox(box_id)
	var limits: Dictionary = DB.data.pity_limits()
	var pr: int = Game.state.pity_rare if Game.state != null else 0
	var pe: int = Game.state.pity_epic if Game.state != null else 0
	if _demo:
		pr = 3
		pe = 5
	var odds: Dictionary = Odds.box_odds(def, pr, pe, limits)
	var floor_index: int = Game.state.floor_run.index if Game.state != null and Game.state.floor_run != null else 1
	var head: Label = UiUtil.label("WAHRSCHEINLICHKEITEN · %s" % UiUtil.tr_text(def.name).to_upper(), &"", ODDS_FONT,
		UiTheme.C_ACCENT_2)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_override("font", UiTheme.font_bold())
	_odds_box.add_child(head)
	var draws: String = "%d Ziehungen" % int(odds["rolls"])
	if def.fixed_pool != "":
		draws += " + 1 festes Fan-Item"
	_odds_box.add_child(UiUtil.label(draws + " · pro Ziehung:", &"", ODDS_FONT))
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	_odds_box.add_child(row)
	for r: String in UiUtil.RARITY_ORDER:
		var tag: PanelContainer = PanelContainer.new()
		var c: Color = UiUtil.rarity_color(r)
		tag.add_theme_stylebox_override("panel", UiUtil.box_style(Color(c, 0.2), c, 1, 0.0, 6, 1))
		tag.add_child(UiUtil.label("%s %s" % [UiUtil.rarity_name(r), UiUtil.fmt_pct(float((odds["per_roll"] as
			Dictionary)[r]))], &"", 14, c.lightened(0.2)))
		row.add_child(tag)
	if def.guarantee != "":
		_odds_box.add_child(_small("Garantie: letzte Ziehung mind. %s, falls bis dahin keine." % UiUtil.rarity_name(
			def.guarantee)))
	var at_least: GridContainer = GridContainer.new()
	at_least.columns = 2
	at_least.add_theme_constant_override("h_separation", 12)
	at_least.add_theme_constant_override("v_separation", 0)
	_odds_box.add_child(at_least)
	for pair: Array in [["Mind. 1× Selten oder besser je Box", UiUtil.fmt_pct(float(odds["p_rare_plus"]), 2)],
			["Mind. 1× Episch je Box", UiUtil.fmt_pct(float(odds["p_epic"]), 2)]]:
		var k: Label = UiUtil.label(str(pair[0]), &"", ODDS_FONT, UiTheme.C_TEXT_DIM)
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		at_least.add_child(k)
		var v: Label = UiUtil.label(str(pair[1]), &"", ODDS_FONT, UiTheme.C_TEXT)
		v.add_theme_font_override("font", UiTheme.font_mono())
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		at_least.add_child(v)
	var forced: String = str(odds["forced_first"])
	var pity_text: String = "Pity: Selten nach %d Boxen ohne Selten (jetzt %d), Episch nach %d (jetzt %d)." % [
		int(limits.get("rare", 4)), pr, int(limits.get("epic", 8)), pe]
	_odds_box.add_child(_small(pity_text))
	if forced != "":
		var f: Label = _small("Nächste Box: erste Ziehung garantiert %s!" % UiUtil.rarity_name(forced))
		f.add_theme_color_override("font_color", UiTheme.C_GOLD)
		_odds_box.add_child(f)
	var entries: Array[Dictionary] = Odds.entry_odds(def, DB.data, floor_index)
	if not entries.is_empty():
		_odds_box.add_child(UiUtil.spacer(2))
		var ih: Label = UiUtil.label("INHALT (ETAGE %d) · Chance je Ziehung" % floor_index, &"", ODDS_FONT,
			UiTheme.C_TEXT_DIM)
		ih.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ih.add_theme_font_override("font", UiTheme.font_bold())
		_odds_box.add_child(ih)
		for e: Dictionary in entries:
			var er: HBoxContainer = UiUtil.hbox(6)
			var dot: Control = UiIcon.make(&"diamond", UiUtil.rarity_color(str(e["rarity"])), 9)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			er.add_child(dot)
			var n: String = "%s Credits" % UiUtil.fmt_int(int(e["amount"])) if str(e["kind"]) == "credits" else \
				("%s × %d" % [UiUtil.item_name(str(e["id"])), int(e["amount"])] if int(e["amount"]) > 1 else
				UiUtil.item_name(str(e["id"])))
			var nl: Label = UiUtil.label(n, &"", ODDS_FONT)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			er.add_child(nl)
			var pl: Label = UiUtil.label(UiUtil.fmt_pct(float(e["p"]), 2), &"", ODDS_FONT, UiTheme.C_TEXT_DIM)
			pl.add_theme_font_override("font", UiTheme.font_mono())
			er.add_child(pl)
			_odds_box.add_child(er)
	for e2: Dictionary in Odds.fixed_odds(def, DB.data, floor_index):
		var fr: HBoxContainer = UiUtil.hbox(6)
		fr.add_child(UiUtil.label("Fan-Item: %s" % UiUtil.item_name(str(e2["id"])), &"", ODDS_FONT, Color("#ff5fa2")))
		fr.add_child(UiUtil.spacer(0, 0, true))
		fr.add_child(UiUtil.label(UiUtil.fmt_pct(float(e2["p"])), &"", ODDS_FONT, UiTheme.C_TEXT_DIM))
		_odds_box.add_child(fr)


func _small(text: String) -> Label:
	var l: Label = UiUtil.label(text, &"", ODDS_FONT, UiTheme.C_TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	return l


func _demo_rewards() -> Array[LootReward]:
	var out: Array[LootReward] = []
	for spec: Array in [["item", "itm_bandage", 2, "common", false], ["item", "itm_antidote", 2, "rare", true],
			["credits", "", 300, "epic", false]]:
		var r: LootReward = LootReward.new()
		r.kind = str(spec[0])
		r.id = str(spec[1])
		r.amount = int(spec[2])
		r.rarity = str(spec[3])
		r.pity = bool(spec[4])
		out.append(r)
	return out


func _start_demo() -> void:
	select_box("box_silver")
	start_opening()
	rewards = _demo_rewards()
	taps = TAPS
	state = &"reveal"
	var lid: Node3D = _box_node.get_node_or_null("Lid") as Node3D if _box_node != null else null
	if lid != null:
		lid.rotation.x = deg_to_rad(LID_OPEN_DEG)
	_spawn_cards()
	_stage_view.modulate.a = 0.3
	reveal_all()
	_light.light_color = UiUtil.rarity_color("epic")
	_light.light_energy = 4.0
	_update_buttons()
	UiUtil.focus_later(_done_btn)


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var bg: ColorRect = ColorRect.new()
	UiUtil.full_rect(bg)
	bg.color = Color(0.04, 0.02, 0.07, 0.94)
	_root.add_child(bg)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(10)
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiIcon.make(&"box", Color("#cd7f32"), 36))
	head.add_child(UiUtil.label("LOOTBOXEN", &"LabelTitle", 40))
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(InputGlyph.make(&"ui_accept", "Antippen", 15))
	head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 15))
	var body: HBoxContainer = UiUtil.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left: VBoxContainer = UiUtil.vbox(8)
	left.custom_minimum_size = Vector2(420, 0)
	body.add_child(left)
	left.add_child(UiUtil.label("REGAL", &"", 15, UiTheme.C_ACCENT))
	_list = UiUtil.vbox(12)                 # 12 px between the 88 px hit areas
	left.add_child(_list)
	var odds_panel: PanelContainer = PanelContainer.new()
	odds_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	odds_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.7), Color(UiTheme.C_ACCENT_2,
		0.45), 1, 0.0, 12, 10))
	left.add_child(odds_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "OddsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	odds_panel.add_child(scroll)
	_odds_box = UiUtil.vbox(5)
	_odds_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_odds_box)
	var right: VBoxContainer = UiUtil.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var stage_holder: Control = Control.new()
	stage_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_holder.custom_minimum_size = Vector2(0, 300)
	right.add_child(stage_holder)
	_stage_view = SubViewportContainer.new()
	_stage_view.stretch = true
	UiUtil.full_rect(_stage_view)
	_stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_holder.add_child(_stage_view)
	_stage_vp = SubViewport.new()
	_stage_vp.own_world_3d = true
	_stage_vp.transparent_bg = true
	_stage_view.add_child(_stage_vp)
	_build_stage()
	_cards = UiUtil.hbox(14)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cards.offset_left = -330
	_cards.offset_right = 330
	_cards.offset_top = -224
	_cards.offset_bottom = -6
	stage_holder.add_child(_cards)
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -140
	_banner.offset_right = 140
	_banner.offset_top = 8
	_banner.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_ACCENT, Color(0, 0, 0, 0), 0, 0.21, 18, 4))
	_banner.visible = false
	stage_holder.add_child(_banner)
	var bl: Label = UiUtil.label("GARANTIE!", &"LabelHeader", 28, UiUtil.C_PAPER)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(bl)
	_burst = CPUParticles2D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 64
	_burst.lifetime = 0.9
	_burst.explosiveness = 1.0
	_burst.direction = Vector2(0, -1)
	_burst.spread = 180.0
	_burst.initial_velocity_min = 180.0
	_burst.initial_velocity_max = 420.0
	_burst.gravity = Vector2(0, 520)
	_burst.scale_amount_min = 3.0
	_burst.scale_amount_max = 6.0
	stage_holder.add_child(_burst)
	_hint = UiUtil.label("", &"", 18, UiTheme.C_TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_hint)
	var brow: HBoxContainer = UiUtil.hbox(14)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(brow)
	_tap_button = _btn("Öffnen", tap, brow)
	_tap_button.name = "Tap"
	_all_btn = _btn("Alle aufdecken", reveal_all, brow)
	_next_btn = _btn("Nächste Box", next_box, brow)
	_done_btn = _btn("Fertig", finish, brow)
	var foot: Label = UiUtil.label(FOOTER, &"", 15, UiTheme.C_GOLD)
	foot.name = "Footer"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(foot)


func _btn(text: String, cb: Callable, parent: Node) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.custom_minimum_size = Vector2(220, 0)
	UiUtil.touch_pad(b, 68.0)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_stage() -> void:
	var world: Node3D = Node3D.new()
	_stage_vp.add_child(world)
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = SceneKit.environment(Color(0, 0, 0, 0), Color("#6a5a7a"), 0.7, true)
	env.background_mode = Environment.BG_CLEAR_COLOR
	we.environment = env
	world.add_child(we)
	world.add_child(SceneKit.camera(Vector3(0, 1.6, 3.4), Vector3(0, 0.55, 0), 40.0))
	world.add_child(SceneKit.cylinder(0.9, 1.0, 0.3, Color("#2a1d3d"), Vector3(0, -0.15, 0), 0.0, 32))
	# Emissive rims as thin rings around the top and bottom edge (a full disc would light the whole top up).
	for ring: Array in [[0.9, 0.0], [1.0, -0.3]]:
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = float(ring[0]) - 0.005
		tm.outer_radius = float(ring[0]) + 0.035
		tm.rings = 48
		tm.ring_segments = 6
		world.add_child(SceneKit.mesh_node(tm, SceneKit.mat(Color("#ff2e88"), 1.6), Vector3(0, float(ring[1]), 0)))
	world.add_child(SceneKit.sun(Color("#ffffff"), 0.9, Vector3(-40, 30, 0)))
	world.add_child(SceneKit.omni(Color("#fff0e0"), 0.8, 5.0, Vector3(1.4, 1.8, 2.2)))   # key light → metal highlights
	_light = SceneKit.omni(Color("#cd7f32"), 1.0, 4.0, Vector3(0, 1.3, 0.9))
	world.add_child(_light)
	_box_pivot = Node3D.new()
	world.add_child(_box_pivot)
