extends "res://scenes/ui/menu_base.gd"
## Pause tab "Show" (06 §4.7, package C): M.O.D.'s preferences of the floor with their rule in one sentence and the
## hearts, the Unterhosen-Liga with its rule ("ohne Rüstung & ohne Accessoire"), the tier now and per member what still
## blocks it (a member card opens the equipment page of that member), and the bets won so far. Read-only (Show.
## marotten_view, MarottenRules.liga_blockers) — nothing here changes the game state.
## Layout (polish pass): the member cards sit side by side in one row (88 px hit areas), so both are on screen without
## scrolling at 1280 × 720 and in the phone layout — no gap between them, no card at the bottom edge.

signal open_equipment(member_id: String)

var _list: VBoxContainer
var _buttons: Array[Control] = []


func _ready() -> void:
	page_title = "Show"
	var col: VBoxContainer = UiUtil.vbox(10)
	UiUtil.full_rect(col)
	add_child(col)
	var sl: Dictionary = scroll_list()
	col.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	refresh()


func refresh() -> void:
	clear(_list)
	_buttons.clear()
	var v: Dictionary = Show.marotten_view() if Game.state != null else {}
	_list.add_child(_header("M.O.D. MAG HEUTE", UiTheme.C_ACCENT))
	var items: Array = v.get("items", []) if v.get("items", []) is Array else []
	if items.is_empty():
		_list.add_child(empty_note("Noch keine Vorliebe angesagt. M.O.D. verrät sie, sobald die Uhr läuft."))
	for item: Variant in items:
		_list.add_child(_bet_row(item as Dictionary))
	_list.add_child(_header("UNTERHOSEN-LIGA", UiTheme.C_GOLD))
	var tier: int = int(v.get("liga_tier", 0))
	var rule: Label = UiUtil.label("Ohne Rüstung & ohne Accessoire kämpfen: schwerer, aber das Publikum liebt Mut. "
		+ "Die Waffe bleibt erlaubt.", &"", 17)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(rule)
	var tiers: Label = UiUtil.label(_tier_text(v), &"LabelSmall", 16)
	tiers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(tiers)
	var cards: Array[Control] = []
	if Game.state != null:
		var row: HBoxContainer = UiUtil.hbox(12)
		row.name = "MemberCards"
		_list.add_child(row)
		for m: PartyMember in UiUtil.party():
			var card: Button = _member_row(m, tier)
			row.add_child(card)
			cards.append(card)
	var won: int = int(Game.state.show.stats.get("bets_won", 0)) if Game.state != null else 0
	var total: Label = UiUtil.label("Gewonnene Show-Wetten bisher: %d" % won, &"", 17, UiTheme.C_GOLD)
	_list.add_child(total)
	UiUtil.wire_vertical(_buttons)
	_wire_cards(cards)


func focus_default() -> void:
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])


## Number of preference rows / member rows (tests).
func row_count() -> int:
	return _buttons.size()


func _header(text: String, col: Color) -> Label:
	var l: Label = UiUtil.label(text, &"", 18, col)
	l.add_theme_font_override("font", UiTheme.font_bold())
	return l


## One preference: name, rule, hearts (or "gewonnen").
func _bet_row(item: Dictionary) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Bet_" + str(item.get("id", ""))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(b, 66.0)
	var row: HBoxContainer = UiUtil.hbox(14)
	UiUtil.full_rect(row)
	row.offset_left = 14
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var won: bool = bool(item.get("won", false))
	var ic: Control = UiIcon.make(&"check" if won else &"heart", UiTheme.C_GOLD if won else UiTheme.C_ACCENT, 28)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var texts: VBoxContainer = UiUtil.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var t: Label = UiUtil.label(UiUtil.glyph_safe(str(item.get("name", ""))), &"", 20,
		UiTheme.C_GOLD if won else UiTheme.C_TEXT)
	t.add_theme_font_override("font", UiTheme.font_bold())
	texts.add_child(t)
	var d: Label = UiUtil.label(UiUtil.glyph_safe(str(item.get("desc", ""))), &"LabelSmall", 15)
	d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(d)
	var goal: int = int(item.get("goal", 3))
	var r: Label = UiUtil.label("gewonnen" if won else "%d / %d" % [int(item.get("hits", 0)), goal], &"", 18,
		UiTheme.C_GOLD if won else UiTheme.C_TEXT_DIM)
	r.name = "Right"
	r.add_theme_font_override("font", UiTheme.font_mono())
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r)
	_buttons.append(b)
	return b


## A member card: name (+ "gesteuert") over "Liga-bereit" or what blocks it; pressing it opens that member's
## equipment. Cards share one row (side by side).
func _member_row(m: PartyMember, tier: int) -> Button:
	var blockers: PackedStringArray = MarottenRules.liga_blockers(Game.state, m.id)
	var names: PackedStringArray = []
	for iid: String in blockers:
		names.append(UiUtil.item_name(iid))
	var hero: bool = m.id == MarottenRules.hero_of(Game.state)
	var liga_ok: bool = blockers.is_empty()
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Member_" + m.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.0
	UiUtil.touch_pad(b, 72.0)
	var row: HBoxContainer = UiUtil.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(row)
	row.offset_left = 14
	row.offset_right = -14
	b.add_child(row)
	var ic: Control = UiIcon.make(&"shield", UiTheme.C_OK if liga_ok else UiTheme.C_TEXT_DIM, 24)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var texts: VBoxContainer = UiUtil.vbox(0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	var who: Label = UiUtil.label(UiUtil.member_name(m) + (" (gesteuert)" if hero else ""), &"", 19,
		UiTheme.C_TEXT)
	who.name = "Text"
	who.add_theme_font_override("font", UiTheme.font_bold())
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(who)
	var st: Label = UiUtil.label(UiUtil.glyph_safe("Liga-bereit" if liga_ok else "blockiert durch " + ", ".join(names)),
		&"", 16, UiTheme.C_OK if liga_ok else UiTheme.C_TEXT_DIM)
	st.name = "Status"
	st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(st)
	var r: Label = UiUtil.label("Ausrüstung", &"", 16, UiTheme.C_TEXT_DIM)
	r.name = "Right"
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_theme_font_override("font", UiTheme.font_mono())
	row.add_child(r)
	var mid: String = m.id
	b.pressed.connect(func() -> void: open_equipment.emit(mid))
	b.set_meta(&"liga_tier", tier)
	_buttons.append(b)
	return b


## The member cards side by side: left / right between them; up / down leave the row like the vertical chain does.
func _wire_cards(cards: Array[Control]) -> void:
	if cards.size() < 2:
		return
	UiUtil.wire_horizontal(cards)
	var first: Control = cards[0]
	var last: Control = cards[cards.size() - 1]
	var above: Node = first.get_node_or_null(first.focus_neighbor_top)
	var below: Node = last.get_node_or_null(last.focus_neighbor_bottom)
	for c: Control in cards:
		if above != null:
			c.focus_neighbor_top = c.get_path_to(above)
		if below != null:
			c.focus_neighbor_bottom = c.get_path_to(below)


## "Jetzt: Unterhosen-Liga · Stufe 1 (gesteuerte Figur): Hype ×1,05, Follower ×1,1 (bis +60 je Etage) · Stufe 2
## (Duo-Liga, beide): Hype ×1,2, Follower ×1,35 (bis +180 je Etage) · Liga-Bonus dieser Etage: noch +60 Follower" —
## the cap parts only with a floor_follower_cap (integration round 4); event runs without the factors.
static func _tier_text(v: Dictionary) -> String:
	var tier: int = int(v.get("liga_tier", 0))
	var now: String = "Jetzt: " + ["keine Liga", "Unterhosen-Liga", "Duo-Liga"][clampi(tier, 0, 2)]
	if not bool(v.get("rewards", true)):
		return now + " · Stufe 1: die gesteuerte Figur · Stufe 2 (Duo-Liga): beide. In Event-Läufen nur zum Spaß."
	var f: Array = []
	for t: int in [1, 2]:
		var cap: int = MarottenRules.liga_floor_cap(DB.data, t)
		f.append(Show.pm_text(MarottenRules.liga_pm(DB.data, t, &"hype")))
		f.append(Show.pm_text(MarottenRules.liga_pm(DB.data, t, &"follower"))
			+ (" (bis +%d je Etage)" % cap if cap >= 0 else ""))
	var text: String = now + (" · Stufe 1 (gesteuerte Figur): Hype ×%s, Follower ×%s · Stufe 2 (Duo-Liga, beide): "
		+ "Hype ×%s, Follower ×%s") % f
	var left: int = int(v.get("liga_followers_left", -1))
	if tier > 0 and left >= 0:
		text += " · Liga-Bonus dieser Etage: noch +%d Follower" % left
	return text
