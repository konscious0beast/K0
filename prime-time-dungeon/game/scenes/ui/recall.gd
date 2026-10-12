extends CanvasLayer
## Recall (06 §3.5; 08 F-7 named the floor-3 round of 06 §3 so — the code keeps Casting / casting): the show segment in
## the safe rooms from floor 3 on where M.O.D. sits on the jury and every party member chooses a species ("Wer bist
## du?", 06 §3.2) and a class ("Was kannst du?", the four classes of the figure, 06 §3.3). 09 §1.2 keeps the words
## apart: "Klasse" is this choice, the "Vorleben" is the job from the casting, "Berufe" are crafts.
## Opened by the safe room (safe_room.gd: by itself on the first visit of a room while a first choice is open, else
## from its RECALL button) for the members Casting.open_members names — the controlled hero first, then the partner
## (06 §3.5 step 5). Per member:
##   1 species cards — the passive in one sentence (passive_text: what the real-time combat, the Show and the
##     exploration really do with it, 07 §9.6), the stats before -> after as +/− bars, the species' colour on the
##     turning figure (its look follows with 03_ART), "Passt gut zu" its classes;
##   2 class cards — the role in one sentence, EMPFOHLEN for the species' classes (06 §3.1), PASST ZU IHREM VORLEBEN
##     for the candidate's class tip (08 C-9, with M.O.D.'s line persona_spec_hint:<cls>), the stats and the first
##     abilities of the class bar from the ability book (AbilityBook, 09 §8.3);
##   3 confirm — the whole change, where the signature goes, the re-spec rules (06 §3.6) → Game.choose_casting (the
##     recorded "casting") and in a season Game.apply_loadout with the signature (Casting.signature_loadout, recorded
##     "loadout"); then M.O.D. judges the pair (casting_combo:<spc>:<cls> → casting_combo:<spc> → casting_combo).
## The Umschulung (06 §3.6: a later floor's first safe room) skips step 1 — the species stays. Nothing is recorded
## before "Bestätigen"; "Später" closes at any time and open first choices wait in every safe room of the floor. The
## end page sums up both roles, the rules, the floor's level cap and — after the device's first class choice — "Ohne
## Netz" (09 §2.2). M.O.D.'s jury lines stand in the screen's own box (presentation, UiUtil.mod_line; never recorded).
## Input: keyboard / gamepad — ui_up / ui_down through the cards (the detail follows the focus), ui_accept chooses and
## goes on, ui_cancel / pause one step back (on the first step: Später). Touch — a tap shows a card in the detail, a
## second tap or WEITER chooses it. Mouse — hover shows, a click chooses. Cards and buttons: >= 88 px hit areas
## (02_TECH §10.2). Modal layer 60 like the Talent-Show; signal `closed`.

signal closed()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const LevelBadge := preload("res://scenes/ui/level_badge.gd")
const Figure := preload("res://scenes/ui/persona_figure.gd")
const RtView := preload("res://scenes/combat/ui/combat_view.gd")
const TALENT_TREE: String = "res://scenes/ui/talent_tree.tscn"   # 06 §3.6 row 3: the talents, re-picked for free

const STEP_SPECIES: int = 1
const STEP_CLASS: int = 2
const STEP_CONFIRM: int = 3
const STEP_JUDGED: int = 4                  # the choice is made, M.O.D. comments, the next member waits
const STEP_DONE: int = 5
const STEP_NAMES: Dictionary = {STEP_SPECIES: "Wer bist du?", STEP_CLASS: "Was kannst du?", STEP_CONFIRM: "Bestätigen"}
const SPECIES_VIS_H: float = 80.0           # a species card: name + passive (hit area UiTheme.TOUCH_HIT)
const CLASS_VIS_H: float = 100.0            # a class card: name + badges + role
const LIST_GAP: int = 12                    # 02_TECH §10.2 rule 5: 12 px between the hit areas
const LIST_W_MIN: float = 420.0
const LIST_W_MAX: float = 560.0
const LIST_PCT: float = 0.34                # the cards' share of the width; the detail takes the rest (every class
                                            # fits 720 px: test_the_recall_fits_a_720p_screen)
const FIGURE_SIZE: Vector2 = Vector2(196.0, 268.0)
const BAR_W: float = 56.0                   # the +/− bar of a stat (StatBar: ±30 % from its middle)
const PREVIEW_ROWS: int = 3                 # the class bar's first abilities in the detail
const C_JURY: Color = Color("#ff2e88")      # M.O.D. (NOVA magenta, 03_ART §2.4)
const C_SPECIES: Color = Color("#22d3ee")   # species cards
const C_CLASS: Color = Color("#ffc93c")     # class cards
const C_UP: Color = Color("#4ade80")
const C_DOWN: Color = Color("#ff6b6b")

var member_id: String = ""                  # whose turn it is ("" on the end page)
var step: int = STEP_SPECIES
var turn_mode: String = ""                  # Casting.mode when the turn began: first | redo | retrain
var species_id: String = ""                 # the turn's choice so far
var class_id: String = ""
var preview_id: String = ""                 # the option the detail shows (the focused, hovered or tapped card)
var options: PackedStringArray = []         # the ids of the cards on screen
var card_buttons: Array[Button] = []
var queue: PackedStringArray = []           # members still to come after member_id
var judged: Array[Dictionary] = []          # this screen's confirmed turns: {member, species, class, changed, sig}
var close_button: Button
var next_button: Button                     # WEITER / BESTÄTIGEN / Weiter: <name> / FERTIG
var back_button: Button
var tree_button: Button                     # the end page: "Talentbaum" (09 §8.4, where the tree governs)

var _params: Dictionary = {}
var _root: Control
var _panel: PanelContainer
var _list: VBoxContainer
var _portrait: PanelContainer
var _who: Label
var _badge: Control = null
var _step_l: Label
var _count_l: Label
var _sub_l: Label                          # "Etage 3 · Höchststufe 13"
var _top: HBoxContainer
var _figure: SubViewportContainer = null
var _figure_member: String = ""
var _info: VBoxContainer
var _d_title: Label
var _d_pills: HBoxContainer
var _d_effect: Label
var _d_desc: Label
var _d_stats: GridContainer
var _d_extra: VBoxContainer
var _jury: Label
var _status: Label
var _armed: String = ""                     # touch: the card tapped once (a second tap chooses it)
var _lines: int = 0                         # M.O.D. lines shown (varies the pick; presentation only)
var _hint_said: bool = false                # persona_spec_hint once per screen (08 §4.3 H8)
var _no_net_before: bool = true             # the career had Ohne Netz before this screen
var _closing: bool = false


## {"safe_room_id": String} (only for the record; the rules are the Game's).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	layer = 60


func _ready() -> void:
	Game.ensure_state()
	queue = Casting.open_members(Game.state, DB.data)
	_no_net_before = bool(Save.career().get("no_net", false))
	_build()
	_say(_open_tag())
	_next_member(false)
	UiUtil.slide_in(_panel)
	Sfx.play(&"sponsor")


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		back()


# --- public flow (buttons, keys and tests) ----------------------------------------------------------------------------

## Chooses card `index` of the step on screen and goes on: species → classes (the species' recommendations marked),
## class → confirm. false if there is no such card or it is locked.
func choose(index: int) -> bool:
	if _closing or index < 0 or index >= options.size() or card_buttons[index].disabled:
		return false
	var id: String = options[index]
	match step:
		STEP_SPECIES:
			species_id = id
			if class_id != "" and Casting.check(Game.state, DB.data, member_id, species_id, class_id) != "":
				class_id = ""
			show_step(STEP_CLASS)
		STEP_CLASS:
			class_id = id
			show_step(STEP_CONFIRM)
		_:
			return false
	return true


## Bestätigen: records the turn (Game.choose_casting; in a season the signature on its slot via Game.apply_loadout),
## then M.O.D. judges the pair. An unchanged pair records nothing. false when the core refuses.
func confirm() -> bool:
	if _closing or step != STEP_CONFIRM or member_id == "" or class_id == "":
		return false
	var m: PartyMember = _member()
	var changed: bool = species_id != m.species_id or class_id != m.class_id
	var sig: bool = false
	if changed:
		if not Game.choose_casting(member_id, species_id, class_id):
			Sfx.play_ui(&"ui_error")
			_set_status("Das geht hier gerade nicht.", UiTheme.C_DANGER)
			return false
		var lo: Dictionary = Casting.signature_loadout(Game.state, DB.data, member_id)
		sig = not lo.is_empty() and Game.apply_loadout(lo)
	judged.append({"member": member_id, "species": species_id, "class": class_id, "changed": changed, "sig": sig})
	Sfx.play(&"achievement")
	_say("casting_combo:%s:%s" % [species_id, class_id])
	show_step(STEP_JUDGED)
	_set_status("%s: %s." % [_member_name(member_id), pair_text(species_id, class_id)], UiTheme.C_OK)
	return true


## One step back (ui_cancel, "Zurück"): confirm → class → species; from the first step of a turn, the judged pair and
## the end page: closes (Später).
func back() -> void:
	match step:
		STEP_CONFIRM:
			show_step(STEP_CLASS, false)
		STEP_CLASS:
			if turn_mode == "retrain":
				close()
			else:
				show_step(STEP_SPECIES, false)
		_:
			close()


## Later / done: closes the screen. A first choice still open → M.O.D. says where it waits (in the room behind).
func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play_ui(&"ui_cancel")
	if Game.state != null:
		for mid: String in Casting.open_members(Game.state, DB.data):
			if Casting.mode(Game.state, DB.data, mid) == "first":
				Show.say("casting_later")
				break
	closed.emit()
	queue_free()


## Shows step `s` of the turn on screen (fills the list, the detail and the buttons); `say` = M.O.D.'s line for it.
func show_step(s: int, say: bool = true) -> void:
	step = s
	_armed = ""
	close_button.visible = s != STEP_DONE          # the end page closes with FERTIG
	tree_button.visible = false
	_set_status("", UiTheme.C_OK)
	match s:
		STEP_SPECIES:
			_fill_cards(Casting.options(Game.state, DB.data, member_id)["species"], species_id)
		STEP_CLASS:
			_fill_cards(Casting.options(Game.state, DB.data, member_id)["classes"], class_id)
		STEP_CONFIRM:
			_fill_summary()
		STEP_JUDGED:
			_fill_summary()
		STEP_DONE:
			_fill_done()
	_fill_header()
	if (s == STEP_SPECIES or s == STEP_CLASS) and Game.input_scheme == Game.InputScheme.TOUCH:
		_set_status("Antippen zeigt die Karte – nochmal antippen oder WEITER wählt sie.", UiTheme.C_TEXT_DIM)
	if say:
		_say_step()


## M.O.D.'s line in the jury box right now.
func jury_text() -> String:
	return _jury.text


## "Kachelgolem · Abrissbirne" (species · class; "" parts left out).
static func pair_text(spc: String, cls: String) -> String:
	var parts: PackedStringArray = []
	if spc != "" and DB.has_id("species", spc):
		parts.append(UiUtil.tr_text(DB.species_def(spc).name))
	if cls != "" and DB.has_id("classes", cls):
		parts.append(UiUtil.tr_text(DB.class_def(cls).name))
	return " · ".join(parts)


## The species passive in one sentence — what really acts (07 §9.6): the Show (Original), the combat (first hit,
## crit, poison and Sporenkur, items, fire, Turbo) and the exploration (the bark).
static func passive_text(sp: SpeciesDef) -> String:
	if sp == null:
		return ""
	var p: Dictionary = sp.passive.get("params", {}) as Dictionary if sp.passive.get("params", {}) is Dictionary else {}
	match str(sp.passive.get("id", "")):
		"pas_authentic":
			return "Follower aus Kämpfen +%d %%." % _pct_up(p, "follower_pm")
		"pas_grout", "pas_see_through":
			return "Erster erlittener Treffer je Kampf −%d %%." % ((1000 - _pm(p, "first_hit_taken_pm")) / 10)
		"pas_lightdrunk":
			return "Krit +%d %% bei Kampfbeginn ab Hype %d." % [_pm(p, "crit_add_pm", 0) / 10, _pm(p, "min_hype", 0)]
		"pas_spores":
			var tick: String = ""
			if DB.has_id("statuses", "sts_spores"):
				var st: StatusDef = DB.data.status("sts_spores")
				tick = "; im Kampf +%d %% HP alle %d s" % [int(st.rt.get("tick_pct", 0)),
					int(st.rt.get("period_ms", 0)) / 1000]
			return "Giftimmun%s." % tick
		"pas_coin_slot":
			return "Verbrauchsgegenstände wirken %d %% stärker." % _pct_up(p, "consumable_pm")
		"pas_ember":
			return "Feuer-Fähigkeiten wirken %d %% stärker." % _pct_up(p, "fire_skill_pm")
		"pas_court_flight":
			var haste: String = UiUtil.tr_text(DB.data.status("sts_haste").name) if DB.has_id("statuses",
				"sts_haste") else "Tempo"
			return "%s zum Kampfstart; Bellen reicht %d %% weiter." % [haste, _pct_up(p, "bark_range_pm")]
	return ""


## The colour of a species (its look hint's primary colour; Original: the member's colour).
static func species_color(spc: String, mid: String) -> Color:
	if spc != "" and DB.has_id("species", spc):
		var colors: Variant = DB.species_def(spc).model_hint.get("colors", {})
		if colors is Dictionary and (colors as Dictionary).has("primary"):
			return UiUtil.hex(str((colors as Dictionary)["primary"]), C_SPECIES)
	return UiUtil.member_color(mid)


## The candidate's class tip (08 C-9): the spec_hint of the persona's Vorleben for Kai, "" otherwise / without one.
static func vorleben_class(mid: String) -> String:
	if mid != "kai" or Game.persona == null or Game.persona.origin == "":
		return ""
	return str(DB.data.origin(Game.persona.origin).get("spec_hint", ""))


# --- the turn ---------------------------------------------------------------------------------------------------------

## The next member of the queue (or the end page); `say` = M.O.D. introduces it (not for the very first one: the
## opening line stands).
func _next_member(say: bool = true) -> void:
	while not queue.is_empty():
		var mid: String = queue[0]
		queue.remove_at(0)
		var mode: String = Casting.mode(Game.state, DB.data, mid)
		if mode == "":
			continue
		member_id = mid
		turn_mode = mode
		var m: PartyMember = _member()
		species_id = m.species_id if m.species_id != "" else SpeciesDef.ORIGINAL
		class_id = m.class_id
		_set_figure(mid)
		if mode == "retrain":
			show_step(STEP_CLASS, say)
		else:
			show_step(STEP_SPECIES, false)
			if say:
				_say("casting_species:" + mid)
		return
	member_id = ""
	show_step(STEP_DONE)


func _member() -> PartyMember:
	return Game.state.member(member_id) if Game.state != null and member_id != "" else null


func _member_name(mid: String) -> String:
	var m: PartyMember = Game.state.member(mid) if Game.state != null else null
	return UiUtil.member_name(m) if m != null else mid


## The opening line: the Recall's one sentence (06 §0.5) when someone chooses for the first time, else the re-spec rule.
func _open_tag() -> String:
	var modes: PackedStringArray = []
	for mid: String in queue:
		modes.append(Casting.mode(Game.state, DB.data, mid))
	if modes.has("first") or modes.is_empty():
		return "casting_open"
	return "casting_retrain" if modes.has("retrain") else "casting_redo"


func _say_step() -> void:
	match step:
		STEP_CLASS:
			var hint: String = vorleben_class(member_id)
			if hint != "" and not _hint_said and DB.mod_lines("persona_spec_hint:" + hint).size() > 0:
				_hint_said = true
				_say("persona_spec_hint:" + hint)
			else:
				_say("casting_class:" + member_id)
		STEP_CONFIRM:
			_say("casting_confirm")
		STEP_DONE:
			_say("casting_done")


func _say(tag: String, ctx: Dictionary = {}) -> void:
	var t: String = UiUtil.mod_line(tag, ctx, _lines)
	_lines += 1
	if t != "" and _jury != null:
		_jury.text = t


func _set_status(text: String, col: Color) -> void:
	if _status == null:
		return
	_status.text = UiUtil.glyph_safe(text)
	_status.add_theme_color_override("font_color", col)


# --- cards ------------------------------------------------------------------------------------------------------------

func _fill_cards(ids: PackedStringArray, focus_id: String) -> void:
	_clear(_list)
	card_buttons.clear()
	options = ids
	var first_ok: Button = null
	var focus: Button = null
	for i in ids.size():
		var b: Button = _card(ids[i], i)
		_list.add_child(b)
		card_buttons.append(b)
		if first_ok == null and not b.disabled:
			first_ok = b
		if ids[i] == focus_id and not b.disabled:
			focus = b
	if focus == null:
		focus = first_ok
	var chain: Array[Control] = []
	for b: Button in card_buttons:
		chain.append(b)
	UiUtil.wire_vertical(chain)
	for b: Button in card_buttons:
		b.focus_neighbor_right = b.get_path_to(next_button)
		b.focus_neighbor_left = b.get_path_to(b)
	next_button.visible = true
	back_button.visible = step == STEP_CLASS and turn_mode != "retrain"
	_set_next_text("WEITER")
	_wire_actions(focus)
	_set_preview(options[card_buttons.find(focus)] if focus != null else "")
	if focus != null:
		UiUtil.focus_later(focus)


## One option card: a species (name, passive) or a class (name, badges, role).
func _card(id: String, index: int) -> Button:
	var is_species: bool = step == STEP_SPECIES
	var accent: Color = species_color(id, member_id) if is_species else C_CLASS
	var b: Button = UiUtil.button("", &"ButtonFlat")
	b.name = "Card_%d" % index
	b.set_meta("option_id", id)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vis: float = SPECIES_VIS_H if is_species else CLASS_VIS_H
	b.custom_minimum_size = Vector2(0, vis)
	var normal: StyleBoxFlat = UiUtil.box_style(Color(UiUtil.C_INK, 0.72), Color(accent, 0.5), 2, 0.0, 16, 8)
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
	b.add_theme_stylebox_override("disabled", normal)
	UiUtil.touch_pad(b, vis)
	var row: HBoxContainer = UiUtil.hbox(14)
	UiUtil.full_rect(row)
	row.offset_left = 16
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dot: PanelContainer = PanelContainer.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(40, 40)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dsb: StyleBoxFlat = UiUtil.box_style(Color(accent, 0.22), accent, 2, 0.0, 0, 0)
	dsb.set_corner_radius_all(20)
	dot.add_theme_stylebox_override("panel", dsb)
	var icon: StringName = (&"paw" if member_id == "mopsula" else &"person") if is_species else &"star"
	var ic: Control = UiIcon.make(icon, accent, 22)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_child(ic)
	row.add_child(dot)
	var col: VBoxContainer = UiUtil.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var n: Label = UiUtil.label(UiUtil.glyph_safe(pair_text(id, "") if is_species else pair_text("", id)), &"", 22)
	n.name = "Name"
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var pills: HBoxContainer = UiUtil.hbox(6)
	pills.name = "Pills"
	pills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pill: Array in _card_pills(id, is_species):
		pills.add_child(_pill(str(pill[0]), pill[1] as Color))
	if is_species:
		head.add_child(pills)
	else:
		col.add_child(pills)
	var line: String = passive_text(DB.species_def(id)) if is_species else UiUtil.tr_text(DB.class_def(id).desc)
	var l: Label = UiUtil.label(UiUtil.glyph_safe(line), &"", 16 if is_species else 15, UiTheme.C_TEXT_DIM)
	l.name = "Line"
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_species:
		l.clip_text = true
	else:                                       # the role may take two lines (a class card is taller)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 1 if pills.get_child_count() > 0 else 2
	col.add_child(l)
	var why: String = Casting.check(Game.state, DB.data, member_id, id if is_species else species_id,
		(class_id if class_id != "" else _any_class(id)) if is_species else id)
	if why != "":
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
		b.tooltip_text = "Vertrag ist Vertrag: nach diesem Safe Room fest." if why == "locked" else ""
	b.pressed.connect(func() -> void: _on_card(index))
	b.focus_entered.connect(func() -> void: _set_preview(id))
	b.mouse_entered.connect(func() -> void:          # hover = focus: the detail and ui_accept mean the same card
		if not b.disabled and not b.has_focus():
			b.grab_focus())
	return b


## A class the species could go with right now (the check of a species card in the first turn, no class yet).
func _any_class(spc: String) -> String:
	for c: String in Casting.options(Game.state, DB.data, member_id)["classes"]:
		if Casting.check(Game.state, DB.data, member_id, spc, c) == "":
			return c
	var all: PackedStringArray = Casting.options(Game.state, DB.data, member_id)["classes"]
	return all[0] if not all.is_empty() else ""


## The pills of a card: AKTUELL (the member's choice so far), EMPFOHLEN (a class the chosen species recommends),
## PASST ZU IHREM VORLEBEN (the candidate's class tip, 08 C-9).
func _card_pills(id: String, is_species: bool) -> Array:
	var out: Array = []
	var m: PartyMember = _member()
	if m != null and m.class_id != "" and (id == m.species_id if is_species else id == m.class_id):
		out.append(["AKTUELL", UiTheme.C_TEXT_DIM])
	if not is_species:
		if DB.has_id("species", species_id) and DB.species_def(species_id).recommended_classes.has(id):
			out.append(["EMPFOHLEN", UiTheme.C_OK])
		if vorleben_class(member_id) == id:
			out.append(["PASST ZU IHREM VORLEBEN", UiTheme.C_GOLD])
	return out


## A card pressed: touch shows it first (the detail is the touch player's hover) and chooses on the second tap; every
## other input chooses at once (the focus or the hover showed it already).
func _on_card(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	var id: String = options[index]
	if Game.input_scheme == Game.InputScheme.TOUCH and _armed != id:
		_armed = id
		_set_preview(id)
		_set_next_text("WEITER")
		return
	choose(index)


# --- the detail -------------------------------------------------------------------------------------------------------

## The detail of option `id` of the step on screen: name, badges, the effect in one sentence, the flavour, the stats
## before -> after, recommendations (species) or the first class abilities (class).
func _set_preview(id: String) -> void:
	preview_id = id
	if id == "" or member_id == "":
		return
	var is_species: bool = step == STEP_SPECIES
	var spc: String = id if is_species else species_id
	var cls: String = class_id if is_species else id     # a species: with the class chosen so far (none at first)
	_figure_accent(species_color(spc, member_id))
	_d_title.text = UiUtil.glyph_safe(pair_text(id, "") if is_species else pair_text("", id))
	_clear(_d_pills)                           # the card carries its badges (the detail keeps its width)
	if is_species:
		var sp: SpeciesDef = DB.species_def(id)
		_d_effect.text = UiUtil.glyph_safe(passive_text(sp))
		_d_effect.add_theme_color_override("font_color", species_color(id, member_id).lightened(0.15))
		_d_desc.text = UiUtil.glyph_safe(UiUtil.tr_text(sp.desc))
	else:
		_d_effect.text = UiUtil.glyph_safe(UiUtil.tr_text(DB.class_def(id).desc))
		_d_effect.add_theme_color_override("font_color", C_CLASS)
		_d_desc.text = ""
	_d_desc.visible = _d_desc.text != ""
	_fill_stats(spc, cls)
	_clear(_d_extra)
	if is_species:
		var rec: PackedStringArray = []
		for c: String in DB.species_def(id).recommended_classes:
			if DB.has_id("classes", c):
				rec.append(UiUtil.tr_text(DB.class_def(c).name))
		if not rec.is_empty():
			_extra_line("Passt gut zu: " + ", ".join(rec), UiTheme.C_TEXT)
	else:
		_ability_rows(id)
	if _armed != "" and _armed == id:
		_set_next_text("WEITER")


## Stats now -> with (spc, cls): eight cells (short name, "616 -> 708", a +/− bar of the change).
func _fill_stats(spc: String, cls: String) -> void:
	_clear(_d_stats)
	var m: PartyMember = _member()
	if m == null:
		return
	var before: Dictionary = UiUtil.member_stats(m)
	var probe: PartyMember = PartyMember.from_dict(m.to_dict())
	probe.species_id = spc
	probe.class_id = cls
	var after: Dictionary = UiUtil.member_stats(probe)
	for k: String in UiUtil.STAT_KEYS:
		var a: int = int(before.get(k, 0))
		var z: int = int(after.get(k, 0))
		var cell: HBoxContainer = UiUtil.hbox(5)
		cell.name = "Stat_" + k
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kl: Label = UiUtil.label(str(UiUtil.STAT_SHORT[k]), &"LabelSmall", 15)
		kl.custom_minimum_size = Vector2(38, 0)
		cell.add_child(kl)
		var nums: HBoxContainer = UiUtil.hbox(3)    # "328 ▸ 445": the arrow is drawn (no "→" glyph)
		nums.name = "Value"
		nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nums.custom_minimum_size = Vector2(108, 0)
		cell.add_child(nums)
		nums.add_child(_num(a, UiTheme.C_TEXT if a == z else UiTheme.C_TEXT_DIM))
		if a != z:
			var arrow: Control = UiIcon.make(&"arrow_right", UiTheme.C_TEXT_DIM, 11)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nums.add_child(arrow)
			nums.add_child(_num(z, C_UP if z > a else C_DOWN))
		var bar: StatBar = StatBar.new()
		bar.pct = 0 if a == 0 else ((z - a) * 100 + (a / 2 if z >= a else -a / 2)) / a
		bar.custom_minimum_size = Vector2(BAR_W, 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(bar)
		_d_stats.add_child(cell)


## A stat number in the mono font (16 px).
static func _num(v: int, col: Color) -> Label:
	var l: Label = UiUtil.label(str(v), &"", 16, col)
	l.add_theme_font_override("font", UiTheme.font_mono())
	return l


## The class bar's first abilities (AbilityBook): the signature at the Recall with its sentence, the next ones in one
## flowing line ("Schnellbeton ab Stufe 12"), the rest in words — compact, so the screen fits 720 px with any class.
func _ability_rows(cls: String) -> void:
	var rows: Array[Dictionary] = []
	for r: Dictionary in AbilityBook.rows(DB.data, member_id, cls):
		if str(r["source"]) == cls:
			rows.append(r)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["level"]) < int(b["level"]) or (int(a["level"]) == int(b["level"]) and int(a["slot"]) <
			int(b["slot"])))
	if rows.is_empty():
		return
	var flow: HFlowContainer = HFlowContainer.new()     # the abilities after the signature, wrapped when needed
	flow.name = "Later"
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 2)
	for i in mini(PREVIEW_ROWS, rows.size()):
		var r: Dictionary = rows[i]
		var sd: SkillDef = UiUtil.skill_def(str(r["skill"]))
		var sig: bool = int(r["level"]) <= 1
		var line: HBoxContainer = UiUtil.hbox(8)
		line.name = "Ability_%d" % i
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sig:
			line.add_child(_pill("SIGNATUR", C_CLASS))
		else:
			var dot: Control = UiIcon.make(&"dot", UiTheme.C_TEXT_DIM, 14)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(dot)
		var nl: Label = UiUtil.label(UiUtil.glyph_safe(UiUtil.tr_text(sd.name) if sd != null else str(r["skill"])),
			&"", 17 if sig else 16)
		nl.add_theme_font_override("font", UiTheme.font_bold())
		line.add_child(nl)
		if sig:
			var slot: String = "SHOW" if int(r["slot"]) == RtView.SLOT_SHOW else "Slot %d" % int(r["slot"])
			line.add_child(UiUtil.label("%s · beim Recall" % slot, &"LabelSmall", 15))
			_d_extra.add_child(line)
			if sd != null:
				_extra_line(RtView.skill_text(sd).get_slice("\n", 0), UiTheme.C_TEXT_DIM)
		else:
			line.add_child(UiUtil.label("ab Stufe %d" % int(r["level"]), &"LabelSmall", 15))
			flow.add_child(line)
	if flow.get_child_count() > 0:
		_d_extra.add_child(flow)
	else:
		flow.free()
	var later: PackedStringArray = []
	for i in range(PREVIEW_ROWS, rows.size()):
		later.append(str(int(rows[i]["level"])))
	var more: PackedStringArray = []
	if not later.is_empty():
		more.append("dann Stufe " + ", ".join(later))
	var ranks: Array = DB.class_def(cls).rt.get("ranks", []) as Array
	if not ranks.is_empty():
		more.append("Ränge ab %d" % int((ranks[0] as Dictionary).get("level", 0)))
	more.append("Klassenreihen ab %d" % TalentDef.CLASS_ROWS[0])
	_extra_line(_upper_first(" · ".join(more)), UiTheme.C_TEXT_DIM)


static func _upper_first(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1) if s != "" else s


## One wrapped line under the detail (the column's width; 15 px, 03_ART §9.3).
func _extra_line(text: String, col: Color) -> Label:
	var l: Label = UiUtil.label(UiUtil.glyph_safe(text), &"", 15, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_extra.add_child(l)
	return l


# --- confirm, judged, end ---------------------------------------------------------------------------------------------

## Confirm (and the judged pair): the left column sums up the turn; the detail shows the pair's stats, where the
## signature goes and the re-spec rules (06 §3.6).
func _fill_summary() -> void:
	_clear(_list)
	card_buttons.clear()
	options = PackedStringArray()
	var done: bool = step == STEP_JUDGED
	_list.add_child(_summary_card(member_id, species_id, class_id, done))
	var sig_card: PanelContainer = _signature_card(member_id, class_id)
	if sig_card != null:
		_list.add_child(sig_card)
	var m: PartyMember = _member()
	_figure_accent(species_color(species_id, member_id))
	_d_title.text = UiUtil.glyph_safe(pair_text(species_id, class_id))
	_clear(_d_pills)
	if done:
		_d_pills.add_child(_pill("ENTSCHIEDEN", UiTheme.C_OK))
	_d_effect.text = UiUtil.glyph_safe(passive_text(DB.species_def(species_id)))
	_d_effect.add_theme_color_override("font_color", species_color(species_id, member_id).lightened(0.15))
	_d_desc.text = UiUtil.glyph_safe(UiUtil.tr_text(DB.class_def(class_id).desc))
	_d_desc.visible = true
	_fill_stats(species_id, class_id)            # judged: the new values (no change left to show)
	_clear(_d_extra)
	var sig: Dictionary = Casting.signature(DB.data, member_id, class_id)
	if not sig.is_empty() and Game.state.season != null:   # its name and sentence: the SIGNATUR card on the left
		var own: bool = str(m.rt_loadout.get(str(int(sig["slot"])), "")) == str(sig["skill"])
		if done and own:
			_extra_line("Signatur auf Slot %d — tauschen im Fähigkeitenbuch." % int(sig["slot"]), C_CLASS)
		elif done or not _signature_fits(sig):
			_extra_line("Signatur im Fähigkeitenbuch bereit (Pausemenü, „Fähigkeiten“).", C_CLASS)
		else:
			_extra_line("Signatur kommt auf Slot %d — tauschen im Fähigkeitenbuch." % int(sig["slot"]), C_CLASS)
	if not done:                                       # 06 §3.6 in one line each (the end page says it in full)
		if turn_mode == "retrain":
			_extra_line("Umschulung: einmal je Etage im ersten Safe Room. Die Spezies bleibt.", UiTheme.C_TEXT_DIM)
		else:
			_extra_line("Spezies: frei, bis Sie den Safe Room verlassen; dann fest.", UiTheme.C_TEXT_DIM)
			_extra_line("Klasse: Umschulung einmal je Etage im ersten Safe Room.", UiTheme.C_TEXT_DIM)
	next_button.visible = true
	back_button.visible = not done
	if done:
		var ahead: String = _next_ahead()
		_set_next_text("WEITER: %s" % _member_name(ahead) if ahead != "" else "FERTIG")
	else:
		_set_next_text("BESTÄTIGEN")
	_wire_actions(null)
	UiUtil.focus_later(next_button)


## The member who comes next (its mode is checked when it begins); "" = none.
func _next_ahead() -> String:
	for mid: String in queue:
		if Casting.mode(Game.state, DB.data, mid) != "":
			return mid
	return ""


## Would the signature go on its slot (Casting.signature_loadout's rule: never over the player's own party variant)?
func _signature_fits(sig: Dictionary) -> bool:
	var held: String = str(_member().rt_loadout.get(str(int(sig["slot"])), ""))
	return held == "" or AbilityBook.class_skills(DB.data, _member().class_id).has(held) or \
		AbilityBook.class_skills(DB.data, class_id).has(held)


## The end page: both roles, the rules of 06 §3.6, the floor's level cap and — new on this device — Ohne Netz.
func _fill_done() -> void:
	_clear(_list)
	card_buttons.clear()
	options = PackedStringArray()
	for m: PartyMember in UiUtil.party():
		_list.add_child(_summary_card(m.id, m.species_id, m.class_id, m.class_id != ""))
	_set_figure(Game.hero())
	var hero: PartyMember = Game.state.member(Game.hero())
	_figure_accent(species_color(hero.species_id if hero != null else "", Game.hero()))
	_d_title.text = "Recall abgeschlossen" if not judged.is_empty() else "Nichts zu wählen"
	_clear(_d_pills)
	_d_effect.text = "Die Jury hat entschieden." if not judged.is_empty() else "Hier ist gerade kein Recall offen."
	_d_effect.add_theme_color_override("font_color", UiTheme.C_TEXT)
	_d_desc.text = ""
	_d_desc.visible = false
	_clear(_d_stats)
	_clear(_d_extra)
	_extra_line("Spezies: fest, sobald Sie diesen Safe Room verlassen („Vertrag ist Vertrag“).", UiTheme.C_TEXT)
	_extra_line("Klasse: Umschulung einmal je Etage, kostenlos, im ersten Safe Room der Etage.", UiTheme.C_TEXT)
	if TalentTree.governs(Game.state):
		_extra_line("Talente: im Safe Room jederzeit kostenlos umwählen (Knopf „Talentbaum“).", UiTheme.C_TEXT)
	if Game.state.season != null:
		_extra_line("Höchststufe auf dieser Etage: %d." % LevelBand.cap(Game.state, DB.data), C_CLASS)
	if not _no_net_before and bool(Save.career().get("no_net", false)):
		_d_pills.add_child(_pill("NEU: OHNE NETZ", UiTheme.C_GOLD))
		_extra_line(UiUtil.mod_line("casting_no_net"), UiTheme.C_GOLD)
	next_button.visible = true
	back_button.visible = false
	tree_button.visible = TalentTree.governs(Game.state) and not judged.is_empty()
	_set_next_text("FERTIG")
	_wire_actions(null)
	UiUtil.focus_later(next_button)


## 06 §3.6 row 3 ("Talente: beim Casting einmal kostenlos zurücksetzbar"): in a season the talent tree re-picks every
## row for free in any safe room (09 §8.4) — the end page opens it right here. null without the tree.
func open_tree() -> Node:
	if Game.state == null or not TalentTree.governs(Game.state):
		return null
	var t: Node = (load(TALENT_TREE) as PackedScene).instantiate()
	t.call("setup", {"member": Game.hero()})
	add_child(t)
	t.connect("closed", func() -> void:
		if is_inside_tree() and tree_button.visible:
			UiUtil.focus_later(tree_button))
	return t


## The class signature as a card (09 §8.3: learned with the class at the Recall): name, slot, its sentence. null
## outside a season or without one.
func _signature_card(mid: String, cls: String) -> PanelContainer:
	var sig: Dictionary = Casting.signature(DB.data, mid, cls)
	var sd: SkillDef = UiUtil.skill_def(str(sig.get("skill", ""))) if not sig.is_empty() else null
	if sd == null or Game.state == null or Game.state.season == null:
		return null
	var p: PanelContainer = PanelContainer.new()
	p.name = "Signature"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.72), Color(C_CLASS, 0.6), 2, 0.0,
		16, 10))
	var col: VBoxContainer = UiUtil.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(_pill("SIGNATUR", C_CLASS))
	var n: Label = UiUtil.label(UiUtil.glyph_safe(UiUtil.tr_text(sd.name)), &"", 20)
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var slot: String = "SHOW" if int(sig["slot"]) == RtView.SLOT_SHOW else "Slot %d" % int(sig["slot"])
	head.add_child(UiUtil.label("%s · beim Recall" % slot, &"LabelSmall", 15))
	var d: Label = UiUtil.label(UiUtil.glyph_safe(RtView.skill_text(sd).get_slice("\n", 0)), &"", 15,
		UiTheme.C_TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	return p


## A summary of a member's (chosen) pair: portrait, name, plaque, species · class and both effects in one line each.
func _summary_card(mid: String, spc: String, cls: String, done: bool) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.name = "Summary_" + mid
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col_c: Color = species_color(spc, mid)
	p.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.72), Color(col_c, 0.7), 2, 0.0,
		16, 12))
	var col: VBoxContainer = UiUtil.vbox(6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiIcon.make(&"check" if done else (&"paw" if mid == "mopsula" else &"person"),
		UiTheme.C_OK if done else UiUtil.member_color(mid), 24))
	var n: Label = UiUtil.label(_member_name(mid), &"", 22)
	n.add_theme_font_override("font", UiTheme.font_bold())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var m: PartyMember = Game.state.member(mid)
	if m != null:
		head.add_child(LevelBadge.make(m.level, 18))
	var pair: String = pair_text(spc, cls)
	var pl: Label = UiUtil.label(UiUtil.glyph_safe(pair if pair != "" else "noch keine Wahl"), &"", 20, col_c.lightened(
		0.2) if pair != "" else UiTheme.C_TEXT_DIM)
	pl.name = "Pair"
	col.add_child(pl)
	for line: String in [passive_text(DB.species_def(spc)) if DB.has_id("species", spc) else "",
			UiUtil.tr_text(DB.class_def(cls).desc) if DB.has_id("classes", cls) else ""]:
		if line == "":
			continue
		var l: Label = UiUtil.label(UiUtil.glyph_safe(line), &"", 15, UiTheme.C_TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(maxf(_list.size.x - 40.0, 300.0), 0)
		col.add_child(l)
	return p


# --- header, figure, buttons ------------------------------------------------------------------------------------------

func _fill_header() -> void:
	var m: PartyMember = _member()
	var col: Color = UiUtil.member_color(member_id) if m != null else UiTheme.C_GOLD
	var psb: StyleBoxFlat = StyleBoxFlat.new()
	psb.bg_color = Color(col, 0.3)
	psb.border_color = col
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(26)
	_portrait.add_theme_stylebox_override("panel", psb)
	_clear(_portrait)
	_portrait.add_child(UiIcon.make(&"star" if m == null else (&"paw" if member_id == "mopsula" else &"person"),
		UiUtil.C_PAPER, 30))
	_who.text = _member_name(member_id) if m != null else "Die Party"
	if _badge != null and is_instance_valid(_badge):
		_badge.queue_free()
		_badge = null
	if m != null:
		_badge = LevelBadge.make(m.level, 18)
		(_who.get_parent() as Control).add_child(_badge)
	var total: int = 2 if turn_mode == "retrain" else 3
	var at: int = step - (1 if turn_mode == "retrain" else 0)
	match step:
		STEP_SPECIES, STEP_CLASS, STEP_CONFIRM:
			var what: String = "Umschulung · " if turn_mode == "retrain" else ""
			_step_l.text = "%sSchritt %d von %d · %s" % [what, at, total, str(STEP_NAMES[step])]
		STEP_JUDGED:
			_step_l.text = "Entschieden · %s" % pair_text(species_id, class_id)
		_:
			_step_l.text = "Spezies & Klasse der Party"
	var at_member: int = judged.size() + (1 if step <= STEP_CONFIRM else 0)    # judged: that member is counted
	var members: int = at_member + _ahead_count()
	_count_l.text = "Figur %d von %d" % [at_member, members] if step < STEP_DONE and members > 1 else ""


func _ahead_count() -> int:
	var n: int = 0
	for mid: String in queue:
		if Casting.mode(Game.state, DB.data, mid) != "":
			n += 1
	return n


## The turning figure of `mid` (rebuilt only when the member changes).
func _set_figure(mid: String) -> void:
	if _figure != null and is_instance_valid(_figure) and _figure_member == mid:
		return
	if _figure != null and is_instance_valid(_figure):
		_figure.queue_free()
	_figure = Figure.new(mid, species_color("", mid)) as SubViewportContainer
	_figure.custom_minimum_size = FIGURE_SIZE
	_figure.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_figure_member = mid
	_top.add_child(_figure)
	_top.move_child(_figure, 0)


func _figure_accent(col: Color) -> void:
	if _figure != null and is_instance_valid(_figure):
		_figure.call("set_accent", col)


func _set_next_text(text: String) -> void:
	var l: Label = next_button.find_child("Text", true, false) as Label
	if l != null:
		l.text = UiUtil.glyph_safe(text)


## The action buttons in the focus chain: Zurück ↔ WEITER, up to Später; the cards reach WEITER with ui_right.
func _wire_actions(card: Button) -> void:
	var target: Control = card if card != null else next_button
	var left: Control = back_button if back_button.visible else (tree_button if tree_button.visible else target)
	next_button.focus_neighbor_left = next_button.get_path_to(left)
	tree_button.focus_neighbor_right = tree_button.get_path_to(next_button)
	tree_button.focus_neighbor_left = tree_button.get_path_to(tree_button)
	next_button.focus_neighbor_top = next_button.get_path_to(close_button if close_button.visible else next_button)
	next_button.focus_neighbor_bottom = next_button.get_path_to(next_button)
	next_button.focus_neighbor_right = next_button.get_path_to(next_button)
	back_button.focus_neighbor_right = back_button.get_path_to(next_button)
	back_button.focus_neighbor_left = back_button.get_path_to(target)
	back_button.focus_neighbor_top = back_button.get_path_to(close_button)
	close_button.focus_neighbor_bottom = close_button.get_path_to(target)
	close_button.focus_neighbor_left = close_button.get_path_to(target)


func _pill(text: String, col: Color) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb: StyleBoxFlat = UiUtil.box_style(col, Color(0, 0, 0, 0), 0, 0.0, 9, 1)
	sb.set_corner_radius_all(11)
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = UiUtil.label(text, &"", 15, UiUtil.C_INK)
	l.add_theme_font_override("font", UiTheme.font_bold())
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


static func _clear(n: Node) -> void:
	for c: Node in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func _pm(p: Dictionary, key: String, default: int = 1000) -> int:
	return JsonUtil.to_int(p.get(key, default), default)


## +x % of a factor in per mille (1250 → 25).
static func _pct_up(p: Dictionary, key: String) -> int:
	return (_pm(p, key) - 1000) / 10


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	UiUtil.full_rect(_root)
	UiUtil.apply_theme(_root)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	UiUtil.full_rect(dim)
	dim.color = Color(0.03, 0.02, 0.06, 0.78)
	_root.add_child(dim)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 0
	safe.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(safe)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiTheme.C_PANEL, 1.0), Color(C_JURY, 0.8), 3,
		0.0, 20, 12))
	safe.add_child(_panel)
	var col: VBoxContainer = UiUtil.vbox(10)
	_panel.add_child(col)
	col.add_child(_build_head())
	var body: HBoxContainer = UiUtil.hbox(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_list = UiUtil.vbox(LIST_GAP)
	_list.name = "Cards"
	var vw: float = _root.get_viewport_rect().size.x if _root.is_inside_tree() else 1280.0
	_list.custom_minimum_size = Vector2(clampf(vw * LIST_PCT, LIST_W_MIN, LIST_W_MAX), 0)
	body.add_child(_list)
	body.add_child(_build_detail())
	var foot: HBoxContainer = UiUtil.hbox(18)
	col.add_child(foot)
	_status = UiUtil.label("", &"", 17, UiTheme.C_OK)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	foot.add_child(_status)
	foot.add_child(InputGlyph.make(&"ui_accept", "Wählen", 15))
	foot.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 15))


func _build_head() -> HBoxContainer:
	var head: HBoxContainer = UiUtil.hbox(14)
	head.custom_minimum_size.y = UiTheme.TOUCH_HIT     # the same height with or without "Später"
	head.add_child(UiIcon.make(&"mic", C_JURY, 38))
	var hc: VBoxContainer = UiUtil.vbox(0)
	hc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hc)
	var pill: PanelContainer = PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", UiUtil.box_style(C_JURY, Color(0, 0, 0, 0), 0, 0.21, 14, 0))
	hc.add_child(pill)
	var pl: Label = UiUtil.label("RECALL", &"LabelHeader", 28, UiUtil.C_PAPER)
	pl.add_theme_constant_override("outline_size", 0)
	pill.add_child(pl)
	_sub_l = UiUtil.label(_sub_text(), &"LabelSmall", 15)
	hc.add_child(_sub_l)
	head.add_child(UiUtil.spacer(0, 10))
	_portrait = PanelContainer.new()
	_portrait.custom_minimum_size = Vector2(52, 52)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_portrait)
	var wc: VBoxContainer = UiUtil.vbox(0)
	wc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(wc)
	var wr: HBoxContainer = UiUtil.hbox(10)
	wc.add_child(wr)
	_who = UiUtil.label("", &"", 26)
	_who.add_theme_font_override("font", UiTheme.font_bold())
	wr.add_child(_who)
	_step_l = UiUtil.label("", &"LabelSmall", 16)
	_step_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_step_l.clip_text = true
	wc.add_child(_step_l)
	_count_l = UiUtil.label("", &"", 20, UiTheme.C_GOLD)
	_count_l.add_theme_font_override("font", UiTheme.font_bold())
	_count_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_count_l)
	close_button = UiUtil.close_button("Später")
	close_button.pressed.connect(close)
	head.add_child(close_button)
	return head


## "Etage 3 · Höchststufe 13" (06 §0.6: the cap rises with floor 3 — in a season the band end, 09 §8.2).
func _sub_text() -> String:
	var fr: FloorRun = Game.state.floor_run if Game.state != null else null
	var floor_index: int = fr.index if fr != null else 1
	var cap: int = LevelBand.cap(Game.state, DB.data) if Game.state != null and Game.state.season != null else \
		Balance.LEVEL_CAP
	return "Etage %d · Höchststufe %d" % [floor_index, cap]


func _build_detail() -> VBoxContainer:
	var right: VBoxContainer = UiUtil.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top = UiUtil.hbox(16)
	_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_top)
	_info = UiUtil.vbox(6)
	_info.name = "Detail"
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top.add_child(_info)
	var tr: HBoxContainer = UiUtil.hbox(10)
	_info.add_child(tr)
	_d_title = UiUtil.label("", &"", 28)
	_d_title.name = "Title"
	_d_title.add_theme_font_override("font", UiTheme.font_bold())
	tr.add_child(_d_title)
	_d_pills = UiUtil.hbox(6)
	_d_pills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.add_child(_d_pills)
	_d_effect = UiUtil.label("", &"", 20)
	_d_effect.name = "Effect"
	_d_effect.add_theme_font_override("font", UiTheme.font_bold())
	_d_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(_d_effect)
	_d_desc = UiUtil.label("", &"", 16, UiTheme.C_TEXT_DIM)
	_d_desc.name = "Desc"
	_d_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_child(_d_desc)
	_d_stats = GridContainer.new()
	_d_stats.name = "Stats"
	_d_stats.columns = 2
	_d_stats.add_theme_constant_override("h_separation", 18)
	_d_stats.add_theme_constant_override("v_separation", 2)
	_info.add_child(_d_stats)
	_d_extra = UiUtil.vbox(3)
	_d_extra.name = "Extra"
	_info.add_child(_d_extra)
	var jury: PanelContainer = PanelContainer.new()
	jury.name = "Jury"
	jury.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.85), Color(C_JURY, 0.9), 2,
		0.0, 14, 8))
	right.add_child(jury)
	var jr: HBoxContainer = UiUtil.hbox(12)
	jury.add_child(jr)
	var tag: PanelContainer = PanelContainer.new()
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", UiUtil.box_style(C_JURY, Color(0, 0, 0, 0), 0, 0.21, 10, 2))
	jr.add_child(tag)
	var tl: Label = UiUtil.label("JURY · M.O.D.", &"", 15, UiUtil.C_PAPER)
	tl.add_theme_font_override("font", UiTheme.font_bold())
	tl.add_theme_constant_override("outline_size", 0)
	tag.add_child(tl)
	_jury = UiUtil.label("", &"", 18)
	_jury.name = "JuryLine"
	_jury.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_jury.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jury.custom_minimum_size = Vector2(300, 46)
	_jury.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jr.add_child(_jury)
	var actions: HBoxContainer = UiUtil.hbox(LIST_GAP)
	right.add_child(actions)
	back_button = _action_button("Zurück", false)
	back_button.name = "Back"
	back_button.pressed.connect(back)
	actions.add_child(back_button)
	tree_button = _action_button("Talentbaum", false)
	tree_button.name = "Tree"
	tree_button.pressed.connect(func() -> void: open_tree())
	tree_button.visible = false
	actions.add_child(tree_button)
	actions.add_child(UiUtil.spacer(0, 0, true))
	next_button = _action_button("WEITER", true)
	next_button.name = "Next"
	next_button.pressed.connect(_on_next)
	actions.add_child(next_button)
	return right


func _action_button(text: String, main: bool) -> Button:
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.custom_minimum_size = Vector2(320 if main else 200, 0)
	if main:
		var normal: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_PANEL, 0.95), UiTheme.C_GOLD, 3, 0.0, 16, 8)
		normal.set_corner_radius_all(8)
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.25, 0.17, 0.08, 0.95)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
	var row: HBoxContainer = UiUtil.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	UiUtil.full_rect(row)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if main:
		row.add_child(UiIcon.make(&"arrow_right", UiTheme.C_GOLD, 22))
	var l: Label = UiUtil.label(text, &"", 22, UiTheme.C_GOLD if main else UiTheme.C_TEXT)
	l.name = "Text"
	l.add_theme_font_override("font", UiTheme.font_bold())
	row.add_child(l)
	UiUtil.touch_pad(b, 72.0)
	return b


func _on_next() -> void:
	match step:
		STEP_SPECIES, STEP_CLASS:
			choose(options.find(preview_id))
		STEP_CONFIRM:
			confirm()
		STEP_JUDGED:
			_next_member()
		_:
			close()


## The +/− bar of a stat change (06 §3.5 "Werte-Balken mit +/−"): a track, a middle tick and the change from the
## middle — green to the right, red to the left, ±SPAN_PCT % at the ends.
class StatBar extends Control:
	const SPAN_PCT: int = 30                # a change of ±30 % fills a half
	const UP: Color = Color("#4ade80")
	const DOWN: Color = Color("#ff6b6b")
	var pct: int = 0                        # the change in whole percent (rounded)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.1))
		var mid: float = size.x * 0.5
		var w: float = mid * clampf(float(absi(pct)) / float(SPAN_PCT), 0.0, 1.0)
		if pct > 0:
			draw_rect(Rect2(mid, 0.0, w, size.y), UP)
		elif pct < 0:
			draw_rect(Rect2(mid - w, 0.0, w, size.y), DOWN)
		draw_rect(Rect2(mid - 1.0, -2.0, 2.0, size.y + 4.0), Color(1, 1, 1, 0.55))
