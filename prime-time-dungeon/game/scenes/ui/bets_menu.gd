extends "res://scenes/ui/menu_base.gd"
## Pause tab "Show" (06 §4.7, package C): M.O.D.'s preferences of the floor with their rule in one sentence and the
## hearts, the Unterhosen-Liga with its rule ("ohne Rüstung & ohne Accessoire"), the tier now and per member what still
## blocks it (a member row opens the equipment page of that member), and the bets won so far. Read-only (Show.
## marotten_view, MarottenRules.liga_blockers) — nothing here changes the game state.

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
	if Game.state != null:
		for m: PartyMember in UiUtil.party():
			_list.add_child(_member_row(m, tier))
	var won: int = int(Game.state.show.stats.get("bets_won", 0)) if Game.state != null else 0
	var total: Label = UiUtil.label("Gewonnene Show-Wetten bisher: %d" % won, &"", 17, UiTheme.C_GOLD)
	_list.add_child(total)
	UiUtil.wire_vertical(_buttons)


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


## A member: "Liga-bereit" or what blocks it; pressing it opens that member's equipment.
func _member_row(m: PartyMember, tier: int) -> Button:
	var blockers: PackedStringArray = MarottenRules.liga_blockers(Game.state, m.id)
	var names: PackedStringArray = []
	for iid: String in blockers:
		names.append(UiUtil.item_name(iid))
	var hero: bool = m.id == MarottenRules.hero_of(Game.state)
	var text: String = "%s%s: %s" % [UiUtil.member_name(m), " (gesteuert)" if hero else "",
		"Liga-bereit" if blockers.is_empty() else "blockiert durch " + ", ".join(names)]
	var b: Button = list_button(text, &"shield", UiTheme.C_OK if blockers.is_empty() else UiTheme.C_TEXT_DIM,
		"Ausrüstung", UiTheme.C_TEXT if blockers.is_empty() else UiTheme.C_TEXT_DIM)
	b.name = "Member_" + m.id
	var mid: String = m.id
	b.pressed.connect(func() -> void: open_equipment.emit(mid))
	b.set_meta(&"liga_tier", tier)
	_buttons.append(b)
	return b


## "Jetzt: Unterhosen-Liga · Stufe 1 (nur die gesteuerte Figur): Hype ×1,2 · Follower ×1,15 · Stufe 2 (Duo-Liga,
## beide): Hype ×1,4 · Follower ×1,35" — event runs without the factors.
static func _tier_text(v: Dictionary) -> String:
	var tier: int = int(v.get("liga_tier", 0))
	var now: String = "Jetzt: " + ["keine Liga", "Unterhosen-Liga", "Duo-Liga"][clampi(tier, 0, 2)]
	if not bool(v.get("rewards", true)):
		return now + " · Stufe 1: die gesteuerte Figur · Stufe 2 (Duo-Liga): beide. In Event-Läufen nur zum Spaß."
	var f: Array = []
	for t: int in [1, 2]:
		f.append(Show.pm_text(MarottenRules.liga_pm(DB.data, t, &"hype")))
		f.append(Show.pm_text(MarottenRules.liga_pm(DB.data, t, &"follower")))
	return now + (" · Stufe 1 (gesteuerte Figur): Hype ×%s, Follower ×%s · Stufe 2 (Duo-Liga, beide): Hype ×%s, "
		+ "Follower ×%s") % f
