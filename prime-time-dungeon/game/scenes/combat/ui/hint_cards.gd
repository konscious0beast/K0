extends Control
## Hint cards of the real-time combat (07 §2.13, E21/E28/E29): the tutorial steps of RtSetup.tutorial_steps
## ("target" at ct 0 → "bar1" → "show" after the first party hit → "dodge" at the first enemy telegraph; after a pull
## with an ability the person did "target" / "bar1" already, done_by_pull, E37) and the first-time hints
## (RtVocab.HINT_IDS: interrupt, zone, partner_special, finale, flee, enrage, partner_tactic) — each once per save
## (GameState.flags["rt_hints"]), at most ONE first-time card per combat, partner_special never in the tutorial fight,
## none with GameSettings.combat_hints off or in event / league runs (RtSetup.rules "hints" false, 07 §10.7).
## While a card is up the sim does not tick: CombatDirector.pause_for_hint(id) records {"t": "combat_hint", "ct", "id"}
## and holds the ticks, resume() continues (07 §2.13 "Pause ohne Determinismus-Risiko"); inputs during the card carry
## the held ct. The card sits where the M.O.D. subtitle sits (same box, with the key / gesture) and has priority over
## every line. Texts: the M.O.D. line rt_tutorial_<step> / rt_hint_<id> when the data has it (R4), else the wording of
## 07 §2.13. Private R3 script.

signal card_shown(id: String)
signal card_closed(id: String)
signal tactic_requested()

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")

## Close rule per card: &"target" (target_change), &"slot1" (ability from slot 1), &"show" (SHOW / Später), &"any".
const CLOSE: Dictionary = {"target": &"target", "bar1": &"slot1", "show": &"show", "dodge": &"any",
	"interrupt": &"any", "zone": &"any", "partner_special": &"any", "finale": &"any", "flee": &"any", "enrage": &"any",
	"partner_tactic": &"any"}
const MIN_SHOW_SEC: float = 0.35            # an "any input" card ignores input in its first moment (no accidental skip)
const PARTNER_TACTIC_HITS: int = 3

## Presentation context of the HUD: {"touch": bool, "pad": bool, "keys": {slot: "1"…}, "special_key": "R"}.
var ctx: Dictionary = {}
var sim: RtSim = null
var director: Node = null
## Cards may show at all (settings / run rules), decided in begin().
var enabled: bool = true

var _queue: PackedStringArray = []          # tutorial steps still to show, in order
var _current: String = ""
var _shown_ids: PackedStringArray = []      # every card of this combat (tests)
var _first_time_shown: int = 0
var _since: float = 0.0
var _party_hit: bool = false
var _partner_tele_hits: int = 0
var _boss_lost_pending: bool = false
var _panel: PanelContainer
var _title: Label
var _text: Label
var _keys_row: HBoxContainer
var _later: Button

## A lost boss attempt shows partner_tactic at the start of the next boss fight (presentation state of this session).
static var boss_attempt_lost: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PANEL_SOLID, CombatStyle.C_GOLD, 2)
	sb.set_content_margin_all(12.0)
	sb.content_margin_top = 16.0
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_title = CombatStyle.label("M.O.D. · TIPP", 14, CombatStyle.C_GOLD, true)
	col.add_child(_title)
	_text = CombatStyle.label("", 19, CombatStyle.C_TEXT, false)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(540, 0)
	col.add_child(_text)
	_keys_row = HBoxContainer.new()
	_keys_row.add_theme_constant_override("separation", 10)
	_keys_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_keys_row)
	_later = Button.new()
	_later.name = "Later"
	_later.text = "Später"
	_later.focus_mode = Control.FOCUS_NONE
	_later.custom_minimum_size = Vector2(120, 40)
	_later.pressed.connect(dismiss)
	_later.visible = false
	_keys_row.add_child(_later)                 # always a child (freed with the card), shown on the SHOW card only


func _process(delta: float) -> void:
	if _current != "":
		_since += delta


## Starts the cards of a combat (07 §2.13). `p_ctx` see ctx.
func begin(p_sim: RtSim, p_director: Node, p_ctx: Dictionary) -> void:
	sim = p_sim
	director = p_director
	ctx = p_ctx
	_queue = PackedStringArray()
	_current = ""
	_shown_ids = PackedStringArray()
	_first_time_shown = 0
	_party_hit = false
	_partner_tele_hits = 0
	_boss_lost_pending = boss_attempt_lost
	enabled = allowed(sim)
	visible = false
	if not enabled or sim == null or sim.setup == null:
		return
	for step: String in sim.setup.tutorial_steps:
		if RtVocab.TUTORIAL_STEPS.has(step) and not already_shown(step) and not done_by_pull(sim, step):
			_queue.append(step)
	if not _queue.is_empty() and (_queue[0] == "target" or _queue[0] == "bar1"):
		_show(_queue[0])
	elif _queue.is_empty():
		if _boss_lost_pending and sim.setup.is_boss and CombatView.tactic_visible(sim):
			_try_first_time("partner_tactic")
		elif not CombatView.partner_special(sim).is_empty():
			_try_first_time("partner_special")


## Cards allowed at all: the setting, the run rules (07 §10.7 "hints", false in leagues) and the event mode.
static func allowed(p_sim: RtSim) -> bool:
	if Game.settings != null and not Game.settings.combat_hints:
		return false
	if p_sim != null and p_sim.setup != null:
		var r: Dictionary = p_sim.setup.rules
		var c: Variant = r.get("combat", {})
		if r.has("hints") and not bool(r["hints"]):
			return false
		if c is Dictionary and (c as Dictionary).has("hints") and not bool((c as Dictionary)["hints"]):
			return false
	return Game.mode == &"campaign"


## 07 E37 (with E21 / E28): a combat opened by a pull with an ability or an item (RtSetup.rt_opener aimed at the lead)
## needs no "target" card — the person chose the lead before — and no "bar1" card when the opener was the slot-1
## skill; the field strike's opener (kind "strike") keeps both. The opener already set the target and started slot 1:
## a card asking for them again made the person press 1 a second time, which the sim refuses while the opener still
## casts or its GCD runs (a refusal as the first lesson).
static func done_by_pull(p_sim: RtSim, step: String) -> bool:
	if p_sim == null or p_sim.setup == null:
		return false
	var op: Dictionary = p_sim.setup.rt_opener
	var kind: String = str(op.get("kind", ""))
	if kind != "skill" and kind != "item":
		return false
	if step == "target":
		return true
	var u: RtUnit = CombatView.controlled(p_sim)
	return step == "bar1" and kind == "skill" and u != null \
		and str(CombatView.bar_entries(p_sim, u.id).get(1, "")) == str(op.get("skill", ""))


## "Schon gezeigt" survives saving / loading through the recorded combat_hint (GameState.flags["rt_hints"]).
static func already_shown(id: String) -> bool:
	if Game.state == null:
		return false
	var f: Variant = Game.state.flags.get("rt_hints", {})
	return f is Dictionary and bool((f as Dictionary).get(id, false))


func is_showing() -> bool:
	return _current != ""


func current() -> String:
	return _current


func shown_ids() -> PackedStringArray:
	return _shown_ids


## Slot the HUD should highlight for the current card (0 = none).
func focus_slot() -> int:
	match _current:
		"bar1":
			return 1
		"show", "finale":
			return CombatView.SLOT_SHOW
		"interrupt":
			return _interrupt_slot()
	return 0


## Sim events (Events.combat_event): the triggers of 07 §2.13.
func on_event(e: ActionEvent) -> void:
	if not enabled or sim == null:
		return
	match e.type:
		ActionEvent.Type.DAMAGE:
			if not _party_hit and e.actor_id.begins_with("p") and e.target_id.begins_with("e") and e.amount > 0:
				_party_hit = true
				_next_step_if("show")
		ActionEvent.Type.TELEGRAPH_START:
			if e.actor_id.begins_with("e"):
				_next_step_if("dodge")
		ActionEvent.Type.TELEGRAPH_IMPACT:
			var p: RtUnit = CombatView.partner(sim)
			if p != null and e.target_ids.has(p.id):
				_partner_tele_hits += 1
				if _partner_tele_hits >= PARTNER_TACTIC_HITS and CombatView.tactic_visible(sim):
					_try_first_time("partner_tactic")
		ActionEvent.Type.CAST_START:
			if e.actor_id.begins_with("e") and int(e.rt.get("worthy", 0)) == 1 and _interrupter_ready():
				_try_first_time("interrupt")
		ActionEvent.Type.ZONE_START:
			if e.actor_id.begins_with("e"):
				_try_first_time("zone")
		ActionEvent.Type.FLEE_WARNING:
			if e.actor_id == sim.controlled_id():
				_try_first_time("flee")
		ActionEvent.Type.ENRAGE:
			_try_first_time("enrage")
		ActionEvent.Type.BATTLE_END:
			if int(e.value) == int(BattleResult.Outcome.DEFEAT) and sim.setup != null and sim.setup.is_boss:
				boss_attempt_lost = true
			elif int(e.value) == int(BattleResult.Outcome.VICTORY) and sim.setup != null and sim.setup.is_boss:
				boss_attempt_lost = false


## Every frame: the FINALE hint (first time the FINALE is usable — a pure query, 07 §2.13).
func on_frame() -> void:
	if not enabled or sim == null or _current != "" or not _queue.is_empty():
		return
	for s: Dictionary in CombatView.slots(sim):
		if bool(s["finale"]) and str(s["reason"]) == "" and int(s["cd_left"]) <= 0:
			_try_first_time("finale")
			return


## A command the player sent (CombatInput → HUD): closes target / bar1 / show cards.
func on_command(cmd: Dictionary) -> void:
	if _current == "":
		return
	var rule: StringName = CLOSE.get(_current, &"any")
	var t: String = str(cmd.get("t", ""))
	match rule:
		&"target":
			if t == "target_change" and str(cmd.get("target", "")).begins_with("e"):
				_close()
		&"slot1":
			if t == "ability_use" and _slot_of(str(cmd.get("skill", ""))) == 1:
				_close()
		&"show":
			if t == "ability_use" and _slot_of(str(cmd.get("skill", ""))) == CombatView.SLOT_SHOW:
				_close()
		&"any":
			if _since >= MIN_SHOW_SEC:
				_close()


## Any key / button / tap (CombatInput): closes "any input" cards.
func on_any_input() -> void:
	if _current == "" or CLOSE.get(_current, &"any") != &"any" or _since < MIN_SHOW_SEC:
		return
	_close()


## "Später" (show card) or the cancel action: closes the show card without a SHOW.
func dismiss() -> void:
	if _current == "show" or (_current != "" and CLOSE.get(_current, &"any") == &"any"):
		_close()


func _next_step_if(step: String) -> bool:
	if _current != "" or _queue.is_empty() or _queue[0] != step:
		return false
	_show(step)
	return true


func _try_first_time(id: String) -> void:
	if _current != "" or _first_time_shown >= 1 or not _queue.is_empty() or already_shown(id) or _shown_ids.has(id):
		return
	if sim.setup != null and sim.setup.tutorial and (id == "partner_special" or not sim.setup.tutorial_steps.is_empty()):
		return
	_first_time_shown += 1
	_show(id)


func _show(id: String) -> void:
	_current = id
	_since = 0.0
	if _queue.size() > 0 and _queue[0] == id:
		_queue.remove_at(0)
	_shown_ids.append(id)
	_fill(id)
	visible = true
	if director != null and director.has_method("pause_for_hint"):
		director.call("pause_for_hint", id)
	card_shown.emit(id)
	if id == "partner_tactic":
		tactic_requested.emit()


func _close() -> void:
	var id: String = _current
	_current = ""
	visible = false
	_later.visible = false
	if director != null and director.has_method("resume"):
		director.call("resume")
	card_closed.emit(id)
	# the tutorial goes on at once: "bar1" follows "target"
	if not _queue.is_empty() and _queue[0] == "bar1":
		_show("bar1")


# --- texts -----------------------------------------------------------------------------------------------------------

func _fill(id: String) -> void:
	var touch: bool = bool(ctx.get("touch", false))
	var pad: bool = bool(ctx.get("pad", false))
	var tag: String = ("rt_tutorial_" + id) if RtVocab.TUTORIAL_STEPS.has(id) else ("rt_hint_" + id)
	var line: String = _line(tag)
	_text.text = UiUtil.glyph_safe(line if line != "" else default_text(id, touch, pad))
	_title.text = "M.O.D. · TUTORIAL" if RtVocab.TUTORIAL_STEPS.has(id) else "M.O.D. · TIPP"
	for c: Node in _keys_row.get_children():
		if c == _later:
			continue
		_keys_row.remove_child(c)
		c.queue_free()
	for pair: Array in key_hints(id, touch, pad):
		_keys_row.add_child(_cap(str(pair[0])))
		_keys_row.add_child(CombatStyle.label(str(pair[1]), 16, CombatStyle.C_TEXT_DIM, false))
	_keys_row.move_child(_later, -1)
	_later.visible = id == "show"


## M.O.D. data line for the card (R4 block; "" while the data has none).
static func _line(tag: String) -> String:
	if DB.data == null or DB.mod_lines(tag).is_empty():
		return ""
	return UiUtil.mod_line(tag)


## The wording of 07 §2.13 (touch / pad variants), witty but clear.
func default_text(id: String, touch: bool, pad: bool) -> String:
	var partner: RtUnit = CombatView.partner(sim)
	var pname: String = CombatStyle.unit_name(partner) if partner != null else "Dein Partner"
	match id:
		"target":
			return "Wähle ein Ziel — tipp einen Gegner an." if touch else (
				"Wähle ein Ziel — RT." if pad else "Wähle ein Ziel — antippen oder Tab.")
		"bar1":
			return "Tipp den großen Knopf: deine Hauptfähigkeit." if touch else (
				"Drück %s: deine Hauptfähigkeit." % _key(1, "A" if pad else "1"))
		"show":
			return "SHOW: riskant, aber das Publikum liebt es."
		"dodge":
			return "Rote Fläche? Raus da!"
		"interrupt":
			return "Goldener Rand = jetzt unterbrechen! %s" % ("Tipp den goldenen Knopf." if touch else
				"Drück %s." % _key(_interrupt_slot(), str(_interrupt_slot())))
		"zone":
			return "Pfützen bleiben liegen. Nicht drin stehen — die Reinigung kommt erst nach der Sendung."
		"partner_special":
			return "%s hört auf dein Kommando: %s — sofort, ohne Diskussion." % [pname, _special_desc(partner)]
		"finale":
			return "Ziel unter 30 %? Zeit fürs FINALE. Kamera drei, ganz nah ran!"
		"flee":
			return "Raus aus dem Ring heißt Flucht. Zurück ans Set, wenn du bleiben willst!"
		"enrage":
			return "Überstunden! Ab jetzt wird jeder Treffer härter — Tempo!"
		"partner_tactic":
			return "%s steckt zu viel ein? Stell %s auf „Vorsichtig“." % [pname,
				"ihn" if partner == null or partner.def_id != "mopsula" else "den Grafen"]
	return ""


func _special_desc(partner: RtUnit) -> String:
	var sp: Dictionary = CombatView.partner_special(sim)
	var n: String = str(sp.get("name", ""))
	if partner != null and partner.def_id == "mopsula":
		return "%s heilt dich" % (n if n != "" else "Heiliges Schlabbern")
	return "%s zieht alle Blicke auf sich" % (n if n != "" else "Der Spott")


## Key cap + caption rows of a card.
func key_hints(id: String, touch: bool, pad: bool) -> Array:
	if touch:
		match id:
			"target":
				return [["Tipp", "Gegner antippen"]]
			"bar1":
				return [["Tipp", "großer Knopf"]]
			"show":
				return [["Tipp", "SHOW"]]
			"partner_special":
				return [["Tipp", "Knopf am Partner"]]
		return [["Tipp", "weiter"]]
	match id:
		"target":
			return [["RT", "nächstes Ziel"]] if pad else [["Tab", "nächstes Ziel"], ["Klick", "Gegner"]]
		"bar1":
			return [[_key(1, "A" if pad else "1"), "Hauptfähigkeit"]]
		"show":
			return [[_key(CombatView.SLOT_SHOW, "RB" if pad else "5"), "SHOW"]]
		"interrupt":
			return [[_key(_interrupt_slot(), str(_interrupt_slot())), "Unterbrechen"]]
		"partner_special":
			return [[str(ctx.get("special_key", "Links" if pad else "R")), "Partner-Spezial"]]
		"finale":
			return [[_key(CombatView.SLOT_SHOW, "RB" if pad else "5"), "FINALE"]]
		"partner_tactic":
			return [["Rechts" if pad else "G", "Taktik"]]
	return [["Taste", "weiter"]]


func _key(slot: int, fallback: String) -> String:
	var keys: Dictionary = ctx.get("keys", {})
	var k: String = str(keys.get(slot, ""))
	return k if k != "" else fallback


## Slot of the controlled unit's interrupter (a bar skill with rt.interrupt; Kai 3, Mopsula 4), 0 without one.
func _interrupt_slot() -> int:
	if sim == null:
		return 0
	var u: RtUnit = CombatView.controlled(sim)
	if u == null:
		return 0
	var entries: Dictionary = CombatView.bar_entries(sim, u.id)
	for slot: Variant in entries.keys():
		var def: SkillDef = CombatView.skill_of(str(entries[slot]))
		if def == null:
			continue
		if bool(def.rt.get("interrupt", false)) or (not def.rt.has("interrupt") and
				CombatStyle.INTERRUPTERS.has(def.id)):
			return int(slot)
	return 0


## The interrupter is on the bar and off cooldown — the card never asks for a key that cannot work right now (the
## next worthy cast tries again).
func _interrupter_ready() -> bool:
	var slot: int = _interrupt_slot()
	if slot <= 0:
		return false
	var u: RtUnit = CombatView.controlled(sim)
	var id: String = str(CombatView.bar_entries(sim, u.id).get(slot, ""))
	return sim.cooldown_left(u.id, id) <= 0


func _slot_of(skill_id: String) -> int:
	var u: RtUnit = CombatView.controlled(sim)
	if u == null:
		return 0
	var entries: Dictionary = CombatView.bar_entries(sim, u.id)
	for slot: Variant in entries.keys():
		if str(entries[slot]) == skill_id:
			return int(slot)
	return 0


func _cap(text: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = CombatStyle.panel_box(CombatStyle.C_PAPER)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	sb.border_color = Color("#8a7fa6")
	sb.border_width_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(CombatStyle.label(text, 16, CombatStyle.C_INK, true))
	return p


## Places the card into the subtitle slot: PC bottom −130 / 600 wide centred; touch bottom −36, 520 wide, 50 px left
## of the centre (x 330–850 at 1280: between stick and thumb group).
func place(frame_size: Vector2, touch: bool) -> void:
	var w: float = 520.0 if touch else 600.0
	var bottom: float = 36.0 if touch else 130.0
	_text.custom_minimum_size = Vector2(w - 24.0, 0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.reset_size()
	var h: float = _panel.get_combined_minimum_size().y
	var left: float = (frame_size.x - w) * 0.5 - (50.0 if touch else 0.0)
	_panel.position = Vector2(left, frame_size.y - bottom - h)
	_panel.size = Vector2(w, h)


func card_rect() -> Rect2:
	return _panel.get_global_rect() if visible else Rect2()


func text() -> String:
	return _text.text
