extends "res://scenes/ui/menu_base.gd"
## Pause tab "Party" (02_TECH §1.6, GDD §14.4): per member level (the round level plaque, 09 §1.2), HP/MP, EXP to the
## next level, all 8 stats (total with equipment and talents), equipment, talents (06 §2.2: picked talents +
## "Talentwahl offen" badge) and the Casting line (species · class, from floor 3). Cards are focusable; pressing one
## jumps to the equipment page (`open_equipment`). Casting (08 §1.7, K1): below the cards the button
## "Kandidatenkarte" (only with a candidate persona) opens the card (scenes/ui/persona_card.tscn) as a modal on its own
## canvas layer. Such buttons stand in a column right of the cards (ST1-D: below them they covered the equipment).
## Staffeln (09 §8.2–8.4, ST1-D): the EXP bar follows the table up to level 50; at the cap of the floor the line says
## so (Überstunden); a gold line for the Aufholjagd, Ausgeruht and the class rank; the talent line counts the rows of
## the talent tree ("7 von 12 Reihen gewählt", the branch, open rows); next to the Kandidatenkarte the button
## "Talentbaum" (where the tree governs) opens scenes/ui/talent_tree.tscn above the menu — re-picks in a safe room.

signal open_equipment(member_id: String)

const TalentText := preload("res://scenes/ui/talent_text.gd")
const LevelBadge := preload("res://scenes/ui/level_badge.gd")   # 09 ST1-A: the level plaque, never "Lv"
const PERSONA_CARD: String = "res://scenes/ui/persona_card.tscn"   # Casting (08 §1.7, K1)
const TALENT_TREE: String = "res://scenes/ui/talent_tree.tscn"     # Staffeln (09 §8.4, ST1-D)
const CARD_LAYER: int = 61                 # above the modal menus (60, 02_TECH §9.4)
const SIDE_W: float = 236.0                # the column of the buttons right of the cards

var _row: HBoxContainer
var _col: VBoxContainer
var _side: VBoxContainer = null            # right of the cards: Kandidatenkarte, Talentbaum (only when there is one)
var card_button: Button = null             # Casting (08 §1.7, K1): "Kandidatenkarte"
var tree_button: Button = null             # Staffeln (09 §8.4, ST1-D): "Talentbaum"
var _card_layer: CanvasLayer = null
var _tree: Node = null


func _ready() -> void:
	page_title = "Party"
	_col = UiUtil.vbox(12)                     # the cards and their side column
	UiUtil.full_rect(_col)
	add_child(_col)
	_row = UiUtil.hbox(18)
	_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(_row)
	refresh()


func refresh() -> void:
	clear(_row)
	var cards: Array[Control] = []
	for m: PartyMember in UiUtil.party():
		var card: Button = _card(m)
		_row.add_child(card)
		cards.append(card)
	if cards.is_empty():
		_row.add_child(empty_note("Keine Party – noch kein Spielstand."))
	UiUtil.wire_horizontal(cards)
	_side = UiUtil.vbox(12)
	_side.name = "Side"
	_side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_row.add_child(_side)
	_persona_button(cards)                     # Casting (08 §1.7, K1)
	_tree_button(cards)                        # Staffeln (09 §8.4, ST1-D)
	_wire_side(cards)


func _card(m: PartyMember) -> Button:
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Card_" + m.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(360, 0)
	var col_c: Color = UiUtil.member_color(m.id)
	var bg: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.55), Color(col_c, 0.6), 2, 0.0, 16, 12)
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", bg)
	b.add_theme_stylebox_override("pressed", bg)
	var mid: String = m.id
	b.pressed.connect(func() -> void: open_equipment.emit(mid))
	var margin: MarginContainer = MarginContainer.new()
	UiUtil.full_rect(margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	b.add_child(margin)
	var season_text: String = season_line(m)
	var col: VBoxContainer = UiUtil.vbox(6 if season_text != "" else 8)   # ST1-D: room for the season line
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(12)
	col.add_child(head)
	var portrait: PanelContainer = PanelContainer.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(col_c, 0.3)
	psb.border_color = col_c
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(28)
	portrait.add_theme_stylebox_override("panel", psb)
	portrait.add_child(UiIcon.make(&"paw" if m.id == "mopsula" else &"person", UiUtil.C_PAPER, 36))
	head.add_child(portrait)
	var names: VBoxContainer = UiUtil.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var n: Label = UiUtil.label(UiUtil.member_name(m), &"", 24)
	n.add_theme_font_override("font", UiTheme.font_bold())
	names.add_child(n)
	names.add_child(UiUtil.label(casting_text(m), &"LabelSmall", 16))
	head.add_child(LevelBadge.make(m.level, 24))         # 09 §1.2 Nr. 1: the number in a plaque, tooltip "Stufe N"
	var mhp: int = UiUtil.max_hp(m)
	var mmp: int = UiUtil.max_mp(m)
	col.add_child(_bar_row("HP", m.hp, mhp, &"BarHp"))
	col.add_child(_bar_row("MP", m.mp, mmp, &"BarMp"))
	var need: int = UiUtil.exp_to_next(m.level)
	if need > 0 and season_capped(m):           # Staffeln (09 §8.2): the band end of the floor
		var cap: Label = UiUtil.label("EXP  Deckel dieser Etage – Überstunden werden Credits", &"LabelSmall", 15)
		cap.name = "ExpCap"
		col.add_child(cap)
	elif need > 0:
		col.add_child(_bar_row("EXP", m.exp, need, &"BarHype"))
	else:
		col.add_child(UiUtil.label("EXP  Maximalstufe erreicht", &"LabelSmall", 15))
	if season_text != "":
		var sll: Label = UiUtil.label(season_text, &"LabelSmall", 15, UiTheme.C_GOLD)
		sll.name = "SeasonLine"
		sll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sll.clip_text = true
		col.add_child(sll)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(grid)
	var stats: Dictionary = UiUtil.member_stats(m)
	for k: String in ["str", "mag", "def", "res", "spd", "lck"]:
		var kl: Label = UiUtil.label(str(UiUtil.STAT_NAMES[k]), &"LabelSmall", 16)
		kl.custom_minimum_size = Vector2(92, 0)
		grid.add_child(kl)
		var vl: Label = UiUtil.label(str(int(stats.get(k, 0))), &"", 18)
		vl.add_theme_font_override("font", UiTheme.font_mono())
		vl.custom_minimum_size = Vector2(44, 0)
		grid.add_child(vl)
	col.add_child(UiUtil.spacer(2))
	for slot: String in UiUtil.EQUIP_SLOTS:
		var r: HBoxContainer = UiUtil.hbox(8)
		var item_id: String = str(m.equipment.get(slot, ""))
		r.add_child(UiIcon.make(TYPE_ICONS[slot] as StringName, item_color(item_id) if item_id != "" else
			UiUtil.C_DISABLED, 18))
		var sl: Label = UiUtil.label(str(UiUtil.SLOT_NAMES[slot]), &"LabelSmall", 15)
		sl.custom_minimum_size = Vector2(96, 0)
		r.add_child(sl)
		r.add_child(UiUtil.label(UiUtil.item_name(item_id), &"", 17))
		col.add_child(r)
	col.add_child(UiUtil.spacer(2))
	col.add_child(_talent_row(m))
	return b


## "Recall auf Etage 3" before the Recall (08 C-16: the floor-3 round of 06 §3 is called "Recall"; the casting is
## the new game's), else "Kachelgolem · Abrissbirne" (species · class).
static func casting_text(m: PartyMember) -> String:
	if m.species_id == "" and m.class_id == "":
		return "Spezies & Klasse: Recall auf Etage 3"
	var parts: PackedStringArray = []
	if m.species_id != "":
		parts.append(UiUtil.tr_text(DB.species_def(m.species_id).name) if DB.has_id("species", m.species_id)
			else m.species_id)
	if m.class_id != "":
		parts.append(UiUtil.tr_text(DB.class_def(m.class_id).name) if DB.has_id("classes", m.class_id) else m.class_id)
	return " · ".join(parts)


## Star + "Talente" + the picked talents ("Wischtechnik II, Bissfest"); without any: "2 Talente offen – im Safe Room
## wählen" while choices wait (polish pass: never "noch keine (ab Stufe 3)" for a member who can already choose), else
## "noch keine (ab Stufe 3)" (09 §1.2: "Stufe", never "Level"). Picked talents and open choices: a gold pill
## "1 Wahl offen" next to the names.
func _talent_row(m: PartyMember) -> HBoxContainer:
	var r: HBoxContainer = UiUtil.hbox(8)
	r.name = "Talents"
	r.add_child(UiIcon.make(&"star", UiTheme.C_GOLD, 18))
	var tl: Label = UiUtil.label("Talente", &"LabelSmall", 15)
	tl.custom_minimum_size = Vector2(96, 0)
	r.add_child(tl)
	var names: PackedStringArray = TalentText.member_talents(m)
	var open: int = Talents.pending_levels(m).size() if Talents.has_choice(Game.state, DB.data, m.id) else 0
	var text: String = ", ".join(names)
	if names.is_empty():
		text = open_text(open) if open > 0 else "noch keine (ab Stufe 3)"
	if Game.state != null and TalentTree.governs(Game.state):   # Staffeln (09 §8.4): the rows of the tree
		var tt: Dictionary = tree_text(m)
		text = str(tt["text"])
		open = int(tt["open"])
		names = PackedStringArray() if int(tt["picked"]) == 0 else PackedStringArray([text])
	var v: Label = UiUtil.label(text, &"", 17, UiTheme.C_GOLD if names.is_empty() and open > 0 else Color(0, 0, 0, 0))
	v.name = "TalentNames"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_child(v)
	if open > 0 and not names.is_empty():
		var pill: PanelContainer = PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb: StyleBoxFlat = UiUtil.box_style(UiTheme.C_GOLD, UiUtil.C_INK, 0, 0.0, 10, 1)
		sb.set_corner_radius_all(12)
		pill.add_theme_stylebox_override("panel", sb)
		var hint_text: String = "1 Wahl offen" if open == 1 else "%d Wahlen offen" % open
		if Game.state != null and TalentTree.governs(Game.state):
			hint_text = "1 Reihe offen" if open == 1 else "%d Reihen offen" % open
		var hint: Label = UiUtil.label(hint_text, &"", 15, UiUtil.C_INK)
		hint.name = "TalentHint"
		hint.add_theme_font_override("font", UiTheme.font_bold())
		hint.add_theme_constant_override("outline_size", 0)
		pill.add_child(hint)
		r.add_child(pill)
	return r


## "1 Talent offen – im Safe Room wählen" / "2 Talente offen – im Safe Room wählen".
static func open_text(open: int) -> String:
	return ("1 Talent offen" if open == 1 else "%d Talente offen" % open) + " – im Safe Room wählen"


# --- Staffeln (09 §8.2–8.4, ST1-D) ----------------------------------------------------------------------------------

## In a season: the member stands at the cap of its floor (below 50) — its EXP become Überstunden.
static func season_capped(m: PartyMember) -> bool:
	if Game.state == null or Game.state.season == null or m == null:
		return false
	return m.level >= LevelBand.cap(Game.state, DB.data) and m.level < LevelBand.SEASON_CAP


## The gold season line: "Aufholjagd: EXP × 2 bis Stufe 10 · Ausgeruht: 120 EXP · Rang II" ("" without a season or
## without news).
static func season_line(m: PartyMember) -> String:
	var parts: PackedStringArray = []
	if Game.state == null or Game.state.season == null or m == null:
		return ""
	var pm: int = LevelBand.catch_up_pm(Game.state, DB.data, m)
	if pm > LevelBand.PM:
		var lo: int = LevelBand.band(DB.data, Game.state.floor_run.index if Game.state.floor_run != null else 1).x
		parts.append("Aufholjagd: EXP × %d bis Stufe %d" % [pm / LevelBand.PM, lo])
	if m.rested > 0:
		parts.append("Ausgeruht: %d EXP" % m.rested)
	var rank: Vector2i = AbilityBook.rank_of(Game.state, DB.data, m)
	if rank.x >= 2:
		parts.append("Rang " + AbilityBook.RANK_NAMES[rank.x])
	return "  ·  ".join(parts)


## The talent line where the tree governs: "7 von 12 Reihen · Bollwerk" ({"text", "open", "picked"}).
static func tree_text(m: PartyMember) -> Dictionary:
	var total: int = TalentTree.rows(DB.data, m).size()
	var picked: int = TalentTree.picked(DB.data, m).size()
	var open: int = TalentTree.open_rows(Game.state, DB.data, m).size()
	var text: String = "%d von %d Reihen" % [picked, total]
	var spec: String = TalentTree.spec_of(DB.data, m)
	if spec != "":
		text += " · " + TalentText.spec_name(spec)
	if picked == 0:
		text = (("1 Reihe offen" if open == 1 else "%d Reihen offen" % open) + " – im Safe Room wählen") if open > 0 \
			else "noch keine (ab Stufe 3)"
	return {"text": text, "open": open, "picked": picked}


## "Talentbaum" below the cards next to the Kandidatenkarte (only where the tree governs).
func _tree_button(cards: Array[Control]) -> void:
	if tree_button != null and is_instance_valid(tree_button):
		tree_button.get_parent().remove_child(tree_button)
		tree_button.queue_free()
		tree_button = null
	if Game.state == null or not TalentTree.governs(Game.state) or cards.is_empty():
		return
	tree_button = UiUtil.button("Talentbaum", &"")
	tree_button.name = "TalentTreeButton"
	tree_button.custom_minimum_size = Vector2(SIDE_W, 0)
	UiUtil.touch_pad(tree_button)
	tree_button.pressed.connect(func() -> void: open_tree())
	_side.add_child(tree_button)


## Focus with the side column: right from the last card to its first button, left back; the buttons up / down among
## themselves; down from a card to the first button. Without a button the column goes.
func _wire_side(cards: Array[Control]) -> void:
	var side: Array[Control] = []
	for c: Node in _side.get_children():
		side.append(c as Control)
	if side.is_empty() or cards.is_empty():
		_row.remove_child(_side)
		_side.queue_free()
		_side = null
		return
	UiUtil.wire_vertical(side, false)
	var last: Control = cards[cards.size() - 1]
	last.focus_neighbor_right = last.get_path_to(side[0])
	for c: Control in cards:
		c.focus_neighbor_bottom = c.get_path_to(side[0])
	for b: Control in side:
		b.focus_neighbor_left = b.get_path_to(last)
		b.focus_neighbor_right = b.get_path_to(cards[0])


## Opens the talent tree above the pause menu (it closes on Esc / B / Start / "Schließen"); `member` first.
func open_tree(member: String = "") -> Node:
	if _tree != null and is_instance_valid(_tree):
		return _tree
	if not ResourceLoader.exists(TALENT_TREE):
		return null
	var t: Node = (load(TALENT_TREE) as PackedScene).instantiate()
	var first: String = member if member != "" else (UiUtil.party()[0].id if not UiUtil.party().is_empty() else "kai")
	t.call("setup", {"member": first})
	t.connect("closed", func() -> void:
		_tree = null
		refresh()
		if is_instance_valid(tree_button):
			UiUtil.focus_later(tree_button))
	add_child(t)
	_tree = t
	return t


func _bar_row(label_text: String, value: int, max_value: int, variation: StringName) -> HBoxContainer:
	var r: HBoxContainer = UiUtil.hbox(8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = UiUtil.label(label_text, &"LabelSmall", 15)
	l.custom_minimum_size = Vector2(40, 0)
	r.add_child(l)
	var bar: ProgressBar = UiUtil.bar(variation, value, maxi(max_value, 1), 10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(bar)
	var v: Label = UiUtil.label("%d / %d" % [value, max_value], &"", 16)
	v.add_theme_font_override("font", UiTheme.font_mono())
	v.custom_minimum_size = Vector2(92, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	return r


# --- Casting (08 §1.7, K1): the candidate card ---------------------------------------------------------------------

## The button below the cards (only with a candidate persona): down from every card, up back to the first.
func _persona_button(cards: Array[Control]) -> void:
	if card_button != null and is_instance_valid(card_button):
		card_button.get_parent().remove_child(card_button)
		card_button.queue_free()
		card_button = null
	if Game.persona == null or Game.mode != &"campaign" or cards.is_empty():
		return
	card_button = UiUtil.button("Kandidatenkarte", &"")
	card_button.name = "CandidateCard"
	card_button.custom_minimum_size = Vector2(SIDE_W, 0)
	UiUtil.touch_pad(card_button)
	card_button.pressed.connect(open_card)
	_side.add_child(card_button)


## Opens the candidate card above the pause menu (own canvas layer; it closes on Esc / B / Start / "Schließen").
func open_card() -> Node:
	if _card_layer != null and is_instance_valid(_card_layer):
		return _card_layer.get_child(0) if _card_layer.get_child_count() > 0 else null
	if not ResourceLoader.exists(PERSONA_CARD):
		return null
	_card_layer = CanvasLayer.new()
	_card_layer.layer = CARD_LAYER
	add_child(_card_layer)
	var card: Node = (load(PERSONA_CARD) as PackedScene).instantiate()
	card.call("setup", {})
	card.connect("closed", func() -> void:
		if is_instance_valid(_card_layer):
			_card_layer.queue_free()
		_card_layer = null
		if is_instance_valid(card_button):
			UiUtil.focus_later(card_button))
	_card_layer.add_child(card)
	return card
