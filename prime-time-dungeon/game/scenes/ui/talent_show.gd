extends CanvasLayer
## Talent-Show (06 §2.2, GDD §4.7): opened from the safe-room menu. Every open talent choice of both party members is
## shown one after another — two big cards (talent name, one sentence, the exact effect, and for value talents the
## stat before → after), the member's earlier talents, and "Wahl 1 von 3". Picking a card is Game.pick_talent (the
## recorded command); after the last choice the show closes by itself. "Später" closes it any time — open choices
## wait (badge in the safe-room menu, chip in the battle results, line on the party page). Nothing here interrupts
## a battle or the exploration (06: "nie als Unterbrechung").
## Keyboard / gamepad: ui_left / ui_right between the cards, ui_accept picks, ui_cancel / pause = Später.
## Touch / mouse: the cards are big buttons (>= 88 px hit area), "Später" is a visible close button.
## Modal layer 60 (like the vending machine); signal `closed`. Look: ink panel with the gold show accent.

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const TalentText := preload("res://scenes/ui/talent_text.gd")
const CARD_W: float = 540.0
const CARD_H: float = 286.0
const PICK_PAUSE_SEC: float = 0.45          # the chosen card glows before the next choice appears

var member_id: String = ""                  # member of the choice on screen ("" = nothing open)
var offer: PackedStringArray = []           # the two talent ids on screen
var card_buttons: Array[Button] = []
var close_button: Button
var picked: PackedStringArray = []          # "<member>:<talent>" picked during this visit of the show

var _params: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _who: Label
var _sub: Label
var _progress: Label
var _portrait: PanelContainer
var _cards: HBoxContainer
var _status: Label
var _busy: bool = false
var _closing: bool = false
var _total: int = 0                         # open choices when the show opened (progress "Wahl n von total")


## {"safe_room_id": String} (only for the header; the rules are the Game's).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 60


func _ready() -> void:
	Game.ensure_state()
	_total = Talents.open_choices(Game.state, DB.data)
	_build()
	if Talents.picks_in_party(Game.state) == 0 and _total > 0:
		Show.say("talent_show_open")          # first Talent-Show of the run: the one-sentence rule (06 §0.5)
	show_next()
	UiUtil.slide_in(_panel)
	Sfx.play(&"level_up")


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


## Shows the next open choice (party order, oldest level first) or the "all done" state; returns false if none is open.
func show_next() -> bool:
	member_id = ""
	offer = PackedStringArray()
	for m: PartyMember in UiUtil.party():
		if Talents.has_choice(Game.state, DB.data, m.id):
			member_id = m.id
			offer = Talents.current_offer(Game.state, DB.data, m.id)
			break
	_fill()
	return member_id != ""


## Picks card `index` of the offer (Game.pick_talent). Then the next choice follows (or the show closes).
func pick(index: int) -> bool:
	if _busy or _closing or index < 0 or index >= offer.size() or member_id == "":
		return false
	var mid: String = member_id
	var tid: String = offer[index]
	if not Game.pick_talent(mid, tid):
		Sfx.play_ui(&"ui_error")
		_say("Das geht gerade nicht.", UiTheme.C_DANGER)
		return false
	picked.append("%s:%s" % [mid, tid])
	Sfx.play(&"achievement")
	Show.say("talent_pick:" + mid)
	_say("%s lernt %s." % [_member_name(mid), UiUtil.tr_text(DB.talent(tid).name)], UiTheme.C_OK)
	_glow(index)
	_busy = true
	if is_inside_tree():
		await get_tree().create_timer(PICK_PAUSE_SEC).timeout
	_busy = false
	if _closing:
		return true
	if not show_next():
		close()
	return true


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	closed.emit()
	queue_free()


## Progress text "Wahl 2 von 3" of the choice on screen.
func progress_text() -> String:
	var open_now: int = Talents.open_choices(Game.state, DB.data)
	var total: int = maxi(_total, open_now + picked.size())
	return "Wahl %d von %d" % [picked.size() + 1, maxi(total, 1)]


# --- internals --------------------------------------------------------------------------------------------------------

func _member_name(mid: String) -> String:
	var m: PartyMember = Game.state.member(mid) if Game.state != null else null
	return UiUtil.member_name(m) if m != null else mid


func _say(text: String, col: Color) -> void:
	_status.text = UiUtil.glyph_safe(text)
	_status.add_theme_color_override("font_color", col)


func _fill() -> void:
	for c: Node in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	card_buttons.clear()
	var m: PartyMember = Game.state.member(member_id) if member_id != "" else null
	if m == null:
		_who.text = "Alle Talente gewählt"
		_sub.text = "Neue Wahl ab dem nächsten ungeraden Level (3, 5, 7, 9)."
		_progress.text = ""
		_set_portrait("")
		var done: Label = UiUtil.label("Die Show geht weiter. Die Jury ist zufrieden. Vorerst.", &"", 22,
			UiTheme.C_TEXT_DIM)
		done.custom_minimum_size = Vector2(CARD_W * 2.0, CARD_H)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(done)
		UiUtil.focus_later(close_button)
		return
	var open: PackedInt32Array = Talents.pending_levels(m)
	_who.text = "%s  ·  Level %d" % [_member_name(m.id), open[0] if not open.is_empty() else m.level]
	var had: PackedStringArray = TalentText.member_talents(m)
	_sub.text = "Bisher: " + (", ".join(had) if not had.is_empty() else "noch kein Talent")
	_progress.text = progress_text()
	_set_portrait(m.id)
	for i in offer.size():
		var b: Button = _card(m, DB.talent(offer[i]), i)
		_cards.add_child(b)
		card_buttons.append(b)
	var list: Array[Control] = []
	for b: Button in card_buttons:
		list.append(b)
		b.focus_neighbor_top = b.get_path_to(close_button)
	UiUtil.wire_horizontal(list)
	if not card_buttons.is_empty():
		close_button.focus_neighbor_bottom = close_button.get_path_to(card_buttons[0])
		UiUtil.focus_later(card_buttons[0])


func _set_portrait(mid: String) -> void:
	for c: Node in _portrait.get_children():
		c.queue_free()
	var col: Color = UiUtil.member_color(mid) if mid != "" else UiTheme.C_GOLD
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(col, 0.3)
	psb.border_color = col
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(30)
	_portrait.add_theme_stylebox_override("panel", psb)
	var kind: StringName = &"star" if mid == "" else (&"paw" if mid == "mopsula" else &"person")
	_portrait.add_child(UiIcon.make(kind, UiUtil.C_PAPER, 36))


## One talent card: icon + name + tag, one sentence, the effect, and (value talents) the stats before → after.
func _card(m: PartyMember, def: TalentDef, index: int) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Card_%d" % index
	b.set_meta("talent_id", def.id)
	b.custom_minimum_size = Vector2(CARD_W, CARD_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var accent: Color = TalentText.color_of(def)
	var normal: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.7), Color(accent, 0.55), 2, 0.0, 22, 16)
	normal.set_corner_radius_all(10)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.2, 0.12, 0.3, 0.95)
	hover.border_color = accent
	var focus: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UiTheme.C_ACCENT_2
	focus.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus)
	b.pressed.connect(func() -> void: pick(index))
	var margin: MarginContainer = MarginContainer.new()
	UiUtil.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	for side: String in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	b.add_child(margin)
	var col: VBoxContainer = UiUtil.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(64, 64)
	var bsb: StyleBoxFlat = UiUtil.box_style(Color(accent, 0.18), accent, 2, 0.0, 0, 0)
	bsb.set_corner_radius_all(32)
	badge.add_theme_stylebox_override("panel", bsb)
	var ic: Control = UiIcon.make(TalentText.icon_kind(def.icon), accent, 34)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(ic)
	head.add_child(badge)
	var names: VBoxContainer = UiUtil.vbox(2)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(names)
	var n: Label = UiUtil.label(UiUtil.glyph_safe(UiUtil.tr_text(def.name)), &"", 28)
	n.name = "Name"
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	names.add_child(n)
	var tags: HBoxContainer = UiUtil.hbox(10)
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_child(tags)
	tags.add_child(_pill(TalentText.kind_tag(def), accent))
	var r: int = Talents.rank(m, def.id)
	var rank_text: String = "Neu" if r == 0 else "Stufe %d von %d" % [r + 1, def.max_rank]
	if def.max_rank > 1 and r == 0:
		rank_text = "Neu · bis Stufe %d" % def.max_rank
	tags.add_child(UiUtil.label(rank_text, &"LabelSmall", 16))
	var desc: Label = UiUtil.label(UiUtil.glyph_safe(UiUtil.tr_text(def.desc)), &"", 19, UiTheme.C_TEXT_DIM)
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_W - 60.0, 0)
	col.add_child(desc)
	# the effect is the headline of the card: big, centered in the free space, the real numbers right under it
	col.add_child(UiUtil.spacer(0, 0, true))
	var fx_text: String = TalentText.effects_line(def, m.id)
	if fx_text.length() > 28:
		fx_text = fx_text.replace(": ", ":\n")      # "… Accessoire:" / "Abwehr +5 %" (no orphaned "+5 %")
	var fx: Label = UiUtil.label(UiUtil.glyph_safe(fx_text), &"", 30, accent)
	fx.name = "Effect"
	fx.add_theme_font_override("font", UiTheme.font_bold())
	fx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.custom_minimum_size = Vector2(CARD_W - 60.0, 0)
	col.add_child(fx)
	var preview: String = _preview(m, def)
	var pv: Label = UiUtil.label(UiUtil.glyph_safe(preview), &"", 18, UiTheme.C_TEXT)
	pv.name = "Preview"
	pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.custom_minimum_size = Vector2(CARD_W - 60.0, 0)
	pv.visible = preview != ""
	col.add_child(pv)
	col.add_child(UiUtil.spacer(0, 0, true))
	return b


## Value talents: "Jetzt: Stärke 22 -> 24" (the member's real numbers with this talent). A Liga talent whose rule the
## member does not fulfil right now says so; other behaviour talents say where they work (a field talent: right away
## when the member leads the duo — HeroRules.field_mods —, otherwise once it does).
func _preview(m: PartyMember, def: TalentDef) -> String:
	var before: Dictionary = UiUtil.member_stats(m)
	var probe: PartyMember = PartyMember.from_dict(m.to_dict())
	probe.talents[def.id] = Talents.rank(m, def.id) + 1
	var after: Dictionary = UiUtil.member_stats(probe)
	var parts: PackedStringArray = []
	for k: String in UiUtil.STAT_KEYS:
		if int(after.get(k, 0)) != int(before.get(k, 0)):
			parts.append("%s %d -> %d" % [str(UiUtil.STAT_NAMES[k]), int(before.get(k, 0)), int(after.get(k, 0))])
	if not parts.is_empty():
		return "Jetzt: " + ", ".join(parts)
	for fx: Dictionary in def.effects:
		match str(fx.get("kind", "")):
			"liga_stat_pct":
				return "Ruht gerade: %s trägt Rüstung oder Accessoire." % _member_name(m.id)
			"field_range_pm", "field_cd_pm":     # integration 06 A × B: the leader's own field talents count
				if Game.state != null and Game.state.hero == m.id:
					return "Wirkt sofort: %s führt die Gruppe an." % _member_name(m.id)
				return "Wirkt, wenn %s die Gruppe anführt." % _member_name(m.id)
			"marotte_heart":
				return "M.O.D.s Vorlieben: angesagt zu Beginn jeder Etage."
	return ""


func _pill(text: String, col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = UiUtil.box_style(col, Color(0, 0, 0, 0), 0, 0.0, 10, 1)
	sb.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = UiUtil.label(text, &"", 15, UiUtil.C_INK)
	l.add_theme_font_override("font", UiTheme.font_bold())
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


func _glow(index: int) -> void:
	if index < 0 or index >= card_buttons.size() or not is_inside_tree():
		return
	var b: Button = card_buttons[index]
	var tw: Tween = b.create_tween()
	b.pivot_offset = b.size * 0.5
	tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(b, "scale", Vector2.ONE, 0.2)
	for i in card_buttons.size():
		if i != index:
			card_buttons[i].modulate = Color(1, 1, 1, 0.35)


func _build() -> void:
	_root = Control.new()
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.72)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 8
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 1.0),
		Color(UiTheme.C_GOLD, 0.8), 3, 0.0, 26, 16))
	safe.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(14)
	_panel.add_child(col)
	# header: show pill + one-sentence rule + "Später"
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiIcon.make(&"star", UiTheme.C_GOLD, 40))
	var hc: VBoxContainer = UiUtil.vbox(-2)
	hc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hc)
	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_GOLD, Color(0, 0, 0, 0), 0, 0.21, 14, 0))
	hc.add_child(pill)
	var pl: Label = UiUtil.label("TALENT-SHOW", &"LabelHeader", 28, UiUtil.C_INK)
	pl.add_theme_constant_override("outline_size", 0)
	pill.add_child(pl)
	hc.add_child(UiUtil.label("Pro Wahl eins von zwei Talenten. Das andere bekommt jemand anderes. Nie.", &"LabelSmall",
		16))
	head.add_child(UiUtil.spacer(0, 0, true))
	close_button = UiUtil.close_button("Später")
	close_button.pressed.connect(close)
	head.add_child(close_button)
	# who chooses
	var who: HBoxContainer = UiUtil.hbox(14)
	col.add_child(who)
	_portrait = PanelContainer.new()
	_portrait.custom_minimum_size = Vector2(60, 60)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(_portrait)
	var wc: VBoxContainer = UiUtil.vbox(0)
	wc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(wc)
	_who = UiUtil.label("", &"", 28)
	_who.add_theme_font_override("font", UiTheme.font_bold())
	wc.add_child(_who)
	_sub = UiUtil.label("", &"LabelSmall", 17)
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.clip_text = true
	wc.add_child(_sub)
	_progress = UiUtil.label("", &"", 22, UiTheme.C_GOLD)
	_progress.add_theme_font_override("font", UiTheme.font_bold())
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(_progress)
	# the two cards
	_cards = UiUtil.hbox(24)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_cards)
	# footer: feedback + input hints
	var foot: HBoxContainer = UiUtil.hbox(18)
	col.add_child(foot)
	_status = UiUtil.label("", &"", 18, UiTheme.C_OK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_status)
	foot.add_child(InputGlyph.make(&"ui_accept", "Nehmen", 15))
	foot.add_child(InputGlyph.make(&"ui_cancel", "Später", 15))
