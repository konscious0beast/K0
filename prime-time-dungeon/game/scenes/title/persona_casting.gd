extends Control
## Casting (08 §1, K1): three pages in one scene between the hero select and the intro — 1/3 "Wer sind Sie?" (name,
## how M.O.D. calls you), 2/3 "Steckbrief" (Vorleben, Hobby / Talent, optional "+ Eigenschaften"), 3/3 the
## candidate card (+ Sendeformat). "Rest automatisch" (button, Esc, gamepad Start) on 1/3 and 2/3 gives every field the
## player did not set its canon value — without any input the candidate is the canon Kai — and jumps to 3/3 with the
## focus on "Sendung starten": two inputs to the show. "Sendung starten" → TitleFlow.start_new_game(…, profile)
## (Game.new_game records floor → hero → persona). Every new game starts empty (no "last card", 08 C-2).
## Input (08 §1.6): Tab / arrows / Enter, Esc = Rest automatisch (3/3: nothing; overlays close themselves first),
## Backspace (outside the name field) and gamepad B = back, gamepad Start = Rest automatisch (3/3: start), X = dice,
## Ctrl+Enter = next / start. Esc and the gamepad buttons are read in _input (measured 4.7.2: a focused LineEdit is
## in editing mode and eats the first Esc); everything that types stays with the LineEdit. Touch / gamepad A on the
## name field open the on-screen keyboard. Touch targets 88 px, fonts >= 22 / 16 px, every font size × text_scale
## (130 % layout check). Params {"slot", "hero", "seed" (bot / tests), "capture", "page", "open" ("origin" | "hobby" |
## "traits" | "keyboard"), "demo" (a filled sample persona), "text_scale"}.
## K2 (08 §1.2, §6.1): 1/3 carries the look editor — one compact panel of six ◀ ▶ selectors (hair style, hair colour,
## skin tone, beard, glasses, outfit; every option for everyone, every colour with its name) next to the live 3D
## preview (persona_figure.set_look swaps the rig, the scene stays); "Würfeln" (button, gamepad X) on 1/3 rolls a look.
## The name and the word form share one row; a rejected name shows its reason in M.O.D.'s line. Edit mode (params
## {"edit": true}, from the candidate card in the safe room, 08 §1.7): only 1/3, "Übernehmen" writes name, word form and
## look into Game.persona (display only, never recorded) and the persona file, "Abbrechen" / Esc / B leave unchanged.

## K2 edit mode: the editor closed (`applied` = "Übernehmen"); the scene frees itself right after.
signal edit_finished(applied: bool)

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const Figure := preload("res://scenes/ui/persona_figure.gd")
const PickerScript := preload("res://scenes/ui/persona_picker.gd")
const OskScript := preload("res://scenes/ui/osk_keyboard.gd")
const CardScript := preload("res://scenes/ui/persona_card.gd")
const HERO_SELECT: String = "res://scenes/title/hero_select.tscn"
const NAME_MAX: int = 12
const FREE_MAX: int = 24
const FORMS: Array[Array] = [["f", "Kandidatin"], ["m", "Kandidat"], ["n", "Kandidat:in"]]
const MODES: Array[Dictionary] = [
	{"id": &"prime", "title": "Prime Time", "text": "Die echte Sendung: Etagen-Timer 20:00, volle Härte."},
	{"id": &"vorabend", "title": "Vorabendprogramm", "text": "Timer × 1,5, weniger Schaden, mehr EXP. Später nur " +
		"absenkbar, nie anhebbar."},
]
const PAGE_TITLES: Array[String] = ["CASTING 1/3 · WER SIND SIE?", "CASTING 2/3 · STECKBRIEF",
	"CASTING 3/3 · IHRE KANDIDATENKARTE"]
## 08 §1.8: with Graf Mopsula as hero the headings stay neutral (no "UNSER:E", R20).
const PAGE_TITLES_MOPSULA: Array[String] = ["CASTING 1/3 · WER BEGLEITET DEN GRAFEN?", "CASTING 2/3 · STECKBRIEF",
	"CASTING 3/3 · KANDIDATENKARTE"]
const ROW_LABEL_W: float = 250.0
## K2: the look selectors (08 §6.1, tab order of 08 §1.2) — kind → caption; the hair colour also colours a headscarf.
const LOOK_KINDS: PackedStringArray = ["hair", "hair_color", "skin", "beard", "glasses", "outfit"]
const LOOK_CAPTIONS: Dictionary = {"hair": "FRISUR", "hair_color": "HAARFARBE", "skin": "HAUTTON", "beard": "BART",
	"glasses": "BRILLE", "outfit": "OUTFIT"}
const SCARF_COLOR_CAPTION: String = "TUCHFARBE"
const HEADSCARF: String = "headscarf"
const EDIT_TITLE: String = "IN DER MASKE · NAME & AUSSEHEN"
const FIGURE_W: float = 360.0

var slot: int = 1
var hero: String = "kai"
var page: int = 1
var difficulty: StringName = &"prime"
var text_scale: float = 1.0
## What the player entered (only the fields of set_fields count); page 3 shows `final` (+ canon rest + beats).
var profile: PersonaProfile = PersonaProfile.new()
var set_fields: PackedStringArray = []
var final: PersonaProfile = null
var started: bool = false

var name_edit: LineEdit
var keyboard_button: Button
var form_buttons: Dictionary = {}           # "f" | "m" | "n" → Button
var origin_button: Button
var hobby_button: Button
var traits_button: Button
var rest_button: Button
var dice_button: Button
var back_button: Button
var next_button: Button
var start_button: Button
var mode_buttons: Dictionary = {}           # &"prime" | &"vorabend" → Button
var overlay: Control = null                 # the open picker or keyboard
## K2: look kind → {"prev": Button, "next": Button, "caption": Label, "value": Label, "swatch": Panel}.
var look_rows: Dictionary = {}
var figure: SubViewportContainer = null     # persona_figure.gd: the live preview on 1/3
var edit_mode: bool = false                 # K2: name & look in the safe room (08 §1.7)
var edited: bool = false                    # edit mode: "Übernehmen" was pressed

var _params: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()    # presentation only (dice, rival, line pick)
var _title: Label
var _mod: Label
var _pages: Array[Control] = []
var _name_hint: Label
var _lower_third: Label
var _card_host: HBoxContainer
var _card_mod: Label
var _mode_text: Label
var _canon_hint: Label
var _hint: Label
var _overlay_kind: String = ""
var _picked: bool = false                   # the open overlay made a choice (the focus moves on to the next row)
var _busy: bool = false
var _scroll_wait: int = 0                   # K2: frames until the shown page scrolls back to its top


func setup(params: Dictionary) -> void:
	_params = params
	slot = int(params.get("slot", 1))
	hero = HeroRules.sanitize(str(params.get("hero", HeroRules.DEFAULT_HERO)))
	text_scale = clampf(float(params.get("text_scale", 1.0)), 1.0, 1.5)
	edit_mode = bool(params.get("edit", false))


func _ready() -> void:
	UiUtil.full_rect(self)
	_rng.randomize()
	Events.overlay_mode_requested.emit.call_deferred(&"menu")
	Events.input_scheme_changed.connect(_on_scheme_changed)
	if bool(_params.get("demo", false)):
		_fill_demo()
	if edit_mode:
		_fill_edit()
	profile.look = PersonaProfile.clean_look(profile.look, DB.data)
	_build()
	go_page(1 if edit_mode else clampi(int(_params.get("page", 1)), 1, 3))
	match str(_params.get("open", "")):
		"origin", "hobby", "traits":
			open_picker(str(_params["open"]))
		"keyboard":
			open_keyboard("name")


# --- input ------------------------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _busy or overlay != null or not is_visible_in_tree():
		return
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_START:
				_handled()
				if edit_mode:
					next()
				elif page < 3:
					rest_auto()
				else:
					start_show()
			JOY_BUTTON_B:
				_handled()
				back()
			JOY_BUTTON_X:
				if page <= 2:                       # 1/3: a random look (K2), 2/3: Vorleben & hobby (K1)
					_handled()
					dice()
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or (event as InputEventKey).echo:
		return
	var k: InputEventKey = event
	if k.keycode == KEY_ESCAPE:
		_handled()
		if edit_mode:
			back()                                  # K2 edit mode: Esc leaves without changes
		elif page < 3:
			rest_auto()
	elif (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER) and k.ctrl_pressed:
		_handled()
		next()


func _unhandled_input(event: InputEvent) -> void:
	if _busy or overlay != null:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		back()


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _on_scheme_changed(_scheme: int) -> void:
	if _hint != null:
		_hint.text = _hint_text()


## The foot's key hint; empty on touch (the buttons say it, there is no Esc / Start) — the label stays as the spacer
## between "Zurück" and "Weiter".
func _hint_text() -> String:
	if Game.input_scheme == Game.InputScheme.TOUCH:
		return ""
	if edit_mode:
		return "Esc: Abbrechen · Start: Übernehmen"
	return "Esc / Start: Rest automatisch" if page < 3 else "Enter / Start: Sendung starten"


# --- flow -------------------------------------------------------------------------------------------------------------

## Shows page `n` (1..3) with its heading, M.O.D. line, buttons and default focus (1/3 name, 2/3 Vorleben, 3/3
## "Sendung starten").
func go_page(n: int) -> void:
	page = clampi(n, 1, 3)
	if page == 3 and final == null:
		_make_final()
	for i in _pages.size():
		(_pages[i].get_parent() as Control).visible = i == page - 1
	_title.text = (PAGE_TITLES_MOPSULA if hero == "mopsula" else PAGE_TITLES)[page - 1]
	if edit_mode:
		_title.text = EDIT_TITLE
	rest_button.visible = page < 3 and not edit_mode
	dice_button.visible = page <= 2                 # K2: 1/3 rolls a look, 2/3 Vorleben & hobby
	next_button.visible = page < 3
	start_button.visible = page == 3
	_hint.text = _hint_text()
	_show_name_hint(page == 1 and _name_hint.text != "")
	match page:
		1:
			if edit_mode:
				_say("persona_casting_edit")
			else:
				_say("persona_casting_open" + (":mopsula" if hero == "mopsula" else ""))
		2:
			_say("persona_casting_brief")
			_refresh_page2()
		3:
			_refresh_card()
	_wire()
	UiUtil.focus_later(default_focus())
	_scroll_to_top()


## K2: a page that scrolls (130 % text: the name row wraps over the look panel) opens at its top — follow_focus ran
## while the wrapped layout was still settling and could leave the name field above the view. Two frames later (a
## process_frame connection: freed with the scene, no dangling coroutine).
func _scroll_to_top() -> void:
	_scroll_wait = 2
	if is_inside_tree() and not get_tree().process_frame.is_connected(_on_scroll_frame):
		get_tree().process_frame.connect(_on_scroll_frame)


func _on_scroll_frame() -> void:
	_scroll_wait -= 1
	if _scroll_wait > 0:
		return
	get_tree().process_frame.disconnect(_on_scroll_frame)
	if page >= 1 and page <= _pages.size() and is_instance_valid(_pages[page - 1]):
		var sc: ScrollContainer = _pages[page - 1].get_parent() as ScrollContainer
		if sc != null:
			sc.scroll_vertical = 0


func default_focus() -> Control:
	match page:
		1:
			return name_edit
		2:
			return origin_button
	return start_button


## Weiter: 1/3 checks the name, 2/3 builds the card, 3/3 starts. Edit mode (K2): 1/3 "Übernehmen".
func next() -> void:
	if _busy or overlay != null:
		return
	match page:
		1:
			if _name_ok():
				Sfx.play_ui(&"ui_confirm")
				if edit_mode:
					apply_edit()
				else:
					go_page(2)
		2:
			final = null
			Sfx.play_ui(&"ui_confirm")
			go_page(3)
		3:
			start_show()


## ◀ Zurück: 3/3 → 2/3 → 1/3 → the hero select. Edit mode (K2): "Abbrechen" — back to the safe room, unchanged.
func back() -> void:
	if _busy or overlay != null:
		return
	Sfx.play_ui(&"ui_cancel")
	if edit_mode:
		_leave_edit()
		return
	if page > 1:
		final = null if page == 3 else final
		go_page(page - 1)
		return
	_busy = true
	Router.goto(HERO_SELECT, {"slot": slot, "hero": hero})


## "Rest automatisch" (08 §1.5): every unset field → canon; 3/3 with the focus on "Sendung starten".
func rest_auto() -> void:
	if _busy or overlay != null or page == 3:
		return
	if not _name_ok():
		go_page(1)
		return
	Sfx.play_ui(&"ui_confirm")
	final = null
	go_page(3)


## "Würfeln" (2/3): a random Vorleben (maybe with a job), hobby and 0–2 traits — presentation RNG, never recorded;
## the rolled fields count as set. 1/3 (K2, 08 §1.5): a random look (every kind; set).
func dice() -> void:
	if _busy or overlay != null or page > 2:
		return
	if page == 1:
		dice_look()
		return
	var tiles: Array[Dictionary] = []
	for e: Dictionary in DB.data.all_origins():
		if str(e["id"]) != PersonaProfile.ALLROUND:
			tiles.append(e)
	var o: Dictionary = tiles[_rng.randi_range(0, tiles.size() - 1)]
	var jobs: Array = o.get("jobs", []) as Array
	var occ: String = str((jobs[_rng.randi_range(0, jobs.size() - 1)] as Dictionary)["id"]) \
		if not jobs.is_empty() and _rng.randf() < 0.6 else ""
	pick_origin(str(o["id"]), occ)
	var hobbies: Array[Dictionary] = DB.data.persona_list("hobbies")
	pick_hobby(str(hobbies[_rng.randi_range(0, hobbies.size() - 1)]["id"]))
	var traits: PackedStringArray = []
	var all: Array[Dictionary] = DB.data.persona_list("traits")
	for i in _rng.randi_range(0, 2):
		var t: String = str(all[_rng.randi_range(0, all.size() - 1)]["id"])
		if not traits.has(t):
			traits.append(t)
	set_traits(traits)
	Sfx.play_ui(&"lootbox_shake")
	_say("persona_casting_dice")


## "Sendung starten": the new game with this candidate (the single new-game path, TitleFlow.start_new_game).
func start_show() -> void:
	if _busy or started or overlay != null:
		return
	if page != 3:
		rest_auto()
		return
	_busy = true
	started = true
	Sfx.play_ui(&"stunt_success")
	var seed: int = int(_params.get("seed", -1))
	if not TitleFlow.start_new_game(slot, final.name, false, seed, difficulty, hero, final):
		_busy = false
		started = false
		Events.toast_requested.emit("Neues Spiel konnte nicht gestartet werden.", &"warning")


# --- the player's input (tests and the full-run bot use these like the buttons) ---------------------------------------

## The name field (TitleFlow.clean_name rules: <= 12, glyphs the font has); "" = not set (canon "Kai").
func set_player_name(text: String) -> void:
	if name_edit.text != text:
		name_edit.text = text
	var clean: String = text.strip_edges()
	if clean == "":
		_unset("name")
		profile.name = GameState.DEFAULT_NAME
	else:
		profile.name = TitleFlow.clean_name(clean)
		_mark("name")
	_name_hint.text = ""                           # K2: only a rejection shows (in M.O.D.'s line)
	_show_name_hint(false)
	_update_lower_third()


func set_form(form: String) -> void:
	if not PersonaProfile.FORMS.has(form):
		return
	profile.form = form
	_mark("form")
	for f: Variant in form_buttons.keys():
		(form_buttons[f] as Button).set_pressed_no_signal(str(f) == form)
	_update_lower_third()


func pick_origin(origin_id: String, occupation_id: String = "") -> void:
	if DB.data.origin(origin_id).is_empty():
		return
	profile.origin = origin_id
	profile.occupation = occupation_id
	profile.job_text = ""
	_mark("origin")
	_picked = overlay != null
	_refresh_page2()


func pick_hobby(hobby_id: String) -> void:
	if DB.data.hobby(hobby_id).is_empty():
		return
	profile.hobby = hobby_id
	profile.hobby_text = ""
	_mark("hobby")
	_picked = overlay != null
	_refresh_page2()


func set_traits(trait_ids: PackedStringArray) -> void:
	var clean: PackedStringArray = []
	for t: String in trait_ids:
		if not DB.data.trait_def(t).is_empty() and not clean.has(t) and clean.size() < PersonaProfile.MAX_TRAITS:
			clean.append(t)
	profile.traits = clean
	_mark("traits")
	_picked = overlay != null
	_refresh_page2()


## "Anderes …" (08 §1.3, §3.7): "" if accepted (mapped offline: Vorleben → the hit or org_allround, hobby → the hit or
## none; the text only on the card), else the reason sentence (nothing changes).
func set_custom(kind: String, text: String) -> String:
	var t: String = text.strip_edges()
	var reason: String = PersonaText.check_free_text(t, FREE_MAX)
	if t == "":
		reason = "Bitte etwas eintippen — oder eine Kachel wählen."
	if reason != "":
		return reason
	if kind == "origin":
		var id: String = PersonaRules.map_text(DB.data, t, &"job")
		profile.origin = id if id != "" else PersonaProfile.ALLROUND
		profile.occupation = ""
		profile.job_text = t
		_mark("origin")
	else:
		profile.hobby = PersonaRules.map_text(DB.data, t, &"hobby")
		profile.hobby_text = t
		_mark("hobby")
	_picked = overlay != null
	_refresh_page2()
	return ""


# --- K2: the look (08 §1.2, §6.1) -------------------------------------------------------------------------------------

## The look option `look_id` (an lk id of data/looks.json) for `kind`: the row and the 3D preview follow at once; the
## look counts as set ("Rest automatisch" keeps it).
func set_look(kind: String, look_id: String) -> void:
	var e: Dictionary = DB.data.look(look_id)
	if not LOOK_KINDS.has(kind) or e.is_empty() or str(e.get("kind", "")) != kind:
		return
	profile.look[kind] = look_id
	_mark("look")
	_refresh_look()


## ◀ (`dir` −1) / ▶ (+1): the previous / next option of `kind` in data order (wraps around).
func step_look(kind: String, dir: int) -> void:
	var opts: Array[Dictionary] = DB.data.looks_of(kind)
	if opts.is_empty() or _busy or overlay != null:
		return
	var cur: String = look_id(kind)
	var i: int = 0
	for j in opts.size():
		if str(opts[j]["id"]) == cur:
			i = j
	Sfx.play_ui(&"ui_move")
	set_look(kind, str(opts[posmod(i + dir, opts.size())]["id"]))


## "Würfeln" on 1/3 (08 §1.5, K2): one random option per kind (presentation RNG, never recorded; the look counts as
## set) and M.O.D.'s dice line.
func dice_look() -> void:
	for kind: String in LOOK_KINDS:
		var opts: Array[Dictionary] = DB.data.looks_of(kind)
		if not opts.is_empty():
			profile.look[kind] = str(opts[_rng.randi_range(0, opts.size() - 1)]["id"])
	_mark("look")
	_refresh_look()
	Sfx.play_ui(&"lootbox_shake")
	_say("persona_casting_dice")


## The option of `kind` the editor shows (the canon option while the look is unset).
func look_id(kind: String) -> String:
	return str(PersonaProfile.clean_look(profile.look, DB.data).get(kind, ""))


## Edit mode (08 §1.7): name, word form and look go into the running persona — display only (P-2: never recorded,
## never in the slot file); the persona file is written at once. Emits edit_finished(true) and closes.
func apply_edit() -> void:
	var p: PersonaProfile = Game.persona
	if p != null:
		p.name = profile.name
		p.form = profile.form
		p.look = PersonaProfile.clean_look(profile.look, DB.data)
		var c: PersonaProfile = PersonaProfile.canon(DB.data)
		if p.source == "canon" and (p.name != c.name or p.form != c.form or p.look != c.look):
			p.source = "offline"
		if Game.state != null:
			PersonaPrivacy.restore_display(Game.state, p)
			Save.save_persona(Game.state.slot, p)
		Events.party_changed.emit()
	edited = true
	_leave_edit()


func open_picker(kind: String) -> void:
	if overlay != null or _busy:
		return
	var p: Control = PickerScript.new()
	p.name = "Picker"
	var custom: String = ""
	if kind == "origin" and profile.job_text != "" and set_fields.has("origin"):
		custom = "Anderes: " + profile.job_text
	elif kind == "hobby" and profile.hobby_text != "" and set_fields.has("hobby"):
		custom = "Anderes: " + profile.hobby_text
	p.call("setup", {"mode": kind, "origin": profile.origin if set_fields.has("origin") else "",
		"occupation": profile.occupation, "hobby": profile.hobby if set_fields.has("hobby") else "",
		"traits": profile.traits, "text_scale": text_scale, "custom_text": custom})
	p.connect("origin_picked", func(o: String, occ: String) -> void: pick_origin(o, occ))
	p.connect("hobby_picked", func(h: String) -> void: pick_hobby(h))
	p.connect("traits_picked", func(t: PackedStringArray) -> void: set_traits(t))
	p.connect("custom_requested", func(k: String) -> void: open_keyboard(k))
	p.connect("closed", func() -> void: _close_overlay(p))
	_open_overlay(p, kind)


## The on-screen keyboard for "name", "origin" ("Anderes …" Vorleben) or "hobby" ("Anderes …" hobby).
func open_keyboard(kind: String) -> void:
	var under: Control = overlay
	if under != null and _overlay_kind == "keyboard":
		return
	var k: Control = OskScript.new()
	k.name = "Keyboard"
	var titles: Dictionary = {"name": "IHR NAME", "origin": "VORLEBEN · ANDERES …", "hobby": "HOBBY · ANDERES …"}
	var hints: Dictionary = {"name": "Höchstens 12 Zeichen. Leer bleibt „Kai“.",
		"origin": "Höchstens 24 Zeichen. Steht nur auf Ihrer Karte. Keine Namen, Adressen oder Nummern.",
		"hobby": "Höchstens 24 Zeichen. Steht nur auf Ihrer Karte."}
	var text: String = name_edit.text if kind == "name" else (profile.job_text if kind == "origin" else profile.hobby_text)
	k.call("setup", {"title": titles.get(kind, ""), "text": text, "max_len": NAME_MAX if kind == "name" else FREE_MAX,
		"placeholder": "Kai" if kind == "name" else "", "hint": hints.get(kind, ""), "text_scale": text_scale})
	k.connect("submitted", func(t: String) -> void: _keyboard_done(k, under, kind, t))
	k.connect("cancelled", func() -> void: _close_keyboard(k, under, kind))
	k.connect("suggestion_chosen", func(id: String) -> void:
		pick_origin(id, "")
		_drop(under)
		_close_keyboard(k, null, "origin"))
	if under != null:
		under.visible = false
	add_child(k)
	overlay = k
	_overlay_kind = "keyboard"


func form() -> String:
	return profile.form


## The page heading (tests).
func heading() -> String:
	return _title.text


# --- internals --------------------------------------------------------------------------------------------------------

func _fs(px: int) -> int:
	return roundi(px * text_scale)


func _mark(field: String) -> void:
	if not set_fields.has(field):
		set_fields.append(field)
	final = null


func _unset(field: String) -> void:
	var i: int = set_fields.find(field)
	if i >= 0:
		set_fields.remove_at(i)
	final = null


func _name_ok() -> bool:
	if not set_fields.has("name"):
		return true
	var reason: String = PersonaText.check_name(profile.name)
	if reason == "":
		return true
	_name_hint.text = reason
	_name_hint.add_theme_color_override("font_color", UiTheme.C_DANGER)
	_show_name_hint(true)
	Sfx.play_ui(&"ui_error")
	UiUtil.focus_later(name_edit)
	return false


## K2: a rejected name's reason takes M.O.D.'s line (the name and the look editor share 1/3; no extra row).
func _show_name_hint(on: bool) -> void:
	if _name_hint == null:
		return
	_name_hint.visible = on
	_mod.visible = not on and _mod.text != "" and page != 3


## K2 edit mode: the running persona — every field counts as set (nothing falls back to the canon).
func _fill_edit() -> void:
	if Game.persona == null:
		return
	profile = Game.persona.copy()
	set_fields = PackedStringArray(PersonaProfile.FIELDS)


## K2 edit mode: closes the editor (edit_finished; the caller's card refreshes) — the scene frees itself.
func _leave_edit() -> void:
	if _busy:
		return
	_busy = true
	edit_finished.emit(edited)
	queue_free()


## K2: the six rows (caption, value, colour swatch) and the live preview show profile.look.
func _refresh_look() -> void:
	var ids: Dictionary = PersonaProfile.clean_look(profile.look, DB.data)
	for kind: String in LOOK_KINDS:
		var row: Dictionary = look_rows.get(kind, {})
		if row.is_empty():
			continue
		var e: Dictionary = DB.data.look(str(ids.get(kind, "")))
		(row["value"] as Label).text = UiUtil.glyph_safe(str(e.get("name", "")))
		var sw: Color = PersonaLook.swatch(e)
		(row["swatch"] as Control).visible = sw.a > 0.0
		var sb: StyleBoxFlat = UiUtil.box_style(sw, UiTheme.C_TEXT_DIM, 2, 0.0, 0, 0)
		(row["swatch"] as Panel).add_theme_stylebox_override("panel", sb)
	var scarf: bool = str(DB.data.look(str(ids.get("hair", ""))).get("style", "")) == HEADSCARF
	if look_rows.has("hair_color"):
		(look_rows["hair_color"]["caption"] as Label).text = SCARF_COLOR_CAPTION if scarf else LOOK_CAPTIONS["hair_color"]
	if figure != null and is_instance_valid(figure):
		figure.call("set_look", ids)


## Input + canon rest + beats (the rival from the presentation RNG).
func _make_final() -> void:
	final = profile.copy()
	final.fill_unset(DB.data, set_fields)
	final.make_beats(DB.data, _rng)


func _fill_demo() -> void:
	var d: PersonaProfile = CardScript.demo(DB.data)
	profile = d.copy()
	set_fields = PackedStringArray(["name", "form", "origin", "hobby", "traits", "look"])


func _say(tag: String) -> void:
	if edit_mode and page == 1:                   # K2: the mask (no M.O.D. line of its own): what can change here
		_mod.text = "Name, Wortform und Aussehen ändern. Vorleben, Hobby und Eigenschaften bleiben: Vertrag ist Vertrag."
		_mod.visible = not (_name_hint != null and _name_hint.visible)
		return
	var ctx: Dictionary = {}
	var p: PersonaProfile = final if final != null else profile
	ctx.merge(PersonaText.ctx(p, DB.data, null), true)
	ctx["name"] = p.name
	var line: String = UiUtil.mod_line(tag, ctx, _rng.randi_range(0, 99))
	_mod.text = "M.O.D.: „%s“" % line if line != "" else ""
	_mod.visible = _mod.text != "" and not (_name_hint != null and _name_hint.visible)


func _open_overlay(o: Control, kind: String) -> void:
	add_child(o)
	overlay = o
	_overlay_kind = kind


## A picker closed (closed signal): after a choice the focus moves to the next row, else it stays on the row.
func _close_overlay(o: Control) -> void:
	var kind: String = str(o.get("mode")) if is_instance_valid(o) else _overlay_kind
	_drop(o)
	_refresh_page2()
	UiUtil.focus_later(_focus_after_overlay(kind))
	_picked = false


## Frees an overlay (picker or keyboard) without moving the focus.
func _drop(o: Control) -> void:
	if o != null and is_instance_valid(o):
		o.queue_free()
	if overlay == o:
		overlay = null
		_overlay_kind = ""


## The keyboard closes: back to the picker under it (cancel of "Anderes …") or to the page.
func _close_keyboard(k: Control, under: Control, kind: String) -> void:
	_drop(k)
	if under != null and is_instance_valid(under) and not under.is_queued_for_deletion():
		under.visible = true
		overlay = under
		_overlay_kind = str(under.get("mode"))
		UiUtil.focus_later(under.call("_default_focus") as Control)
		return
	overlay = null
	_overlay_kind = ""
	UiUtil.focus_later(_focus_after_overlay(kind))
	_picked = false


func _keyboard_done(k: Control, under: Control, kind: String, text: String) -> void:
	if kind == "name":
		var reason: String = PersonaText.check_name(TitleFlow.clean_name(text)) if text != "" else ""
		if reason != "":
			k.call("show_error", reason)
			return
		set_player_name(text)
		_picked = true
		_close_keyboard(k, under, kind)
		return
	var why: String = set_custom(kind, text)
	if why != "":
		var near: String = PersonaText.nearest_tile(DB.data, text, why) if kind == "origin" else ""
		k.call("show_error", why, str(DB.data.origin(near).get("name", "")) if near != "" else "", near)
		return
	_drop(under)                               # "Anderes …" chose: the picker under the keyboard closes too
	_close_keyboard(k, null, kind)


## Where the focus goes when an overlay of `kind` closed: after a choice the next row (name → the word form, Vorleben →
## hobby → traits → "Weiter"), else the row that opened it.
func _focus_after_overlay(kind: String) -> Control:
	if page == 1:
		return form_buttons.get(profile.form, name_edit) as Control if kind == "name" and _picked else name_edit
	if page == 2:
		match kind:
			"origin":
				return hobby_button if _picked else origin_button
			"hobby":
				return traits_button if _picked else hobby_button
			"traits":
				return next_button
		return origin_button
	return start_button


func _update_lower_third() -> void:
	if _lower_third != null:
		_lower_third.text = UiUtil.glyph_safe("%s · %s" % [profile.name.to_upper(), PersonaText.cand(profile.form)])


## Page 2: the three rows show the choice (or, dimmed, the canon value they would get).
func _refresh_page2() -> void:
	if origin_button == null:
		return
	var o: Dictionary = DB.data.origin(profile.origin)
	var origin_text: String = "Offen — sonst: Tierpflege"
	if set_fields.has("origin"):
		if profile.job_text != "":
			origin_text = "Anderes: %s" % profile.job_text
		else:
			origin_text = str(o.get("name", ""))
			if profile.occupation != "":
				origin_text += " · " + PersonaText.job(profile, DB.data)
	_row_value(origin_button, origin_text, set_fields.has("origin"), str(o.get("icon", "")) if set_fields.has(
		"origin") else "paw")
	var hobby_text: String = "Offen — sonst: Tiere"
	if set_fields.has("hobby"):
		hobby_text = "Anderes: %s" % profile.hobby_text if profile.hobby_text != "" \
			else str(DB.data.hobby(profile.hobby).get("name", ""))
	_row_value(hobby_button, hobby_text, set_fields.has("hobby"),
		str(DB.data.hobby(profile.hobby).get("icon", "")) if set_fields.has("hobby") else "paw")
	var names: PackedStringArray = []
	for t: String in profile.traits:
		names.append(str(DB.data.trait_def(t).get("name", "")))
	var traits_text: String = "+ Eigenschaften (optional)" if names.is_empty() else " · ".join(names)
	_row_value(traits_button, traits_text, not names.is_empty(), "star")


func _row_value(b: Button, text: String, is_set: bool, icon: String) -> void:
	var l: Label = b.find_child("Value", true, false) as Label
	if l != null:
		l.text = UiUtil.glyph_safe(text)
		l.add_theme_color_override("font_color", UiTheme.C_TEXT if is_set else UiTheme.C_TEXT_DIM)
	var holder: Control = b.find_child("IconHolder", true, false) as Control
	if holder != null:
		for c: Node in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
		if icon != "":
			holder.add_child(UiIcon.make(StringName(icon), UiTheme.C_ACCENT_2 if is_set else UiTheme.C_TEXT_DIM,
				_fs(26)))


func _refresh_card() -> void:
	for c: Node in _card_host.get_children():
		if c.name == "Card":
			_card_host.remove_child(c)
			c.queue_free()
	var card: PanelContainer = CardScript.card_panel(final, DB.data, text_scale, 1)
	card.custom_minimum_size.x = minf(CardScript.CARD_W, 600.0 * text_scale)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_host.add_child(card)
	_card_host.move_child(card, 0)
	var ctx: Dictionary = PersonaText.ctx(final, DB.data, null)
	ctx["name"] = final.name
	var line: String = UiUtil.mod_line("persona_card:" + final.origin, ctx, _rng.randi_range(0, 99))
	_card_mod.text = "M.O.D.: „%s“" % line if line != "" else ""
	_mod.text = ""
	_mod.visible = false                         # 3/3: M.O.D. speaks next to the card


func _set_difficulty(d: StringName) -> void:
	difficulty = d
	for id: Variant in mode_buttons.keys():
		(mode_buttons[id] as Button).set_pressed_no_signal(StringName(str(id)) == d)
	for m: Dictionary in MODES:
		if m["id"] == d and _mode_text != null:
			_mode_text.text = str(m["text"])


# --- build ------------------------------------------------------------------------------------------------------------

func _build() -> void:
	add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 22                            # K2: 1/3's look panel needs 388 px + 12 px to the foot at 1280 × 720
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(10)
	col.name = "Column"
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	head.name = "Head"
	col.add_child(head)
	_title = UiUtil.label("", &"LabelTitle", _fs(38))
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_title)
	dice_button = _head_button("Würfeln", "Dice", dice)
	head.add_child(dice_button)
	rest_button = _head_button("Rest automatisch »", "Rest", rest_auto)
	head.add_child(rest_button)
	_mod = UiUtil.label("", &"", _fs(22), UiTheme.C_ACCENT_2)
	_mod.name = "ModLine"
	_mod.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_mod)
	_name_hint = UiUtil.label("", &"", _fs(22), UiTheme.C_DANGER)   # K2: a rejected name, in M.O.D.'s place
	_name_hint.name = "NameHint"
	_name_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_hint.visible = false
	col.add_child(_name_hint)
	var host: Control = Control.new()
	host.name = "Pages"
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(host)
	_pages = [_build_page1(), _build_page2(), _build_page3()]
	for p: Control in _pages:                   # a page that is taller than the screen (130 % text, a phone's
		var sc: ScrollContainer = ScrollContainer.new()   # safe area) scrolls instead of running under the foot
		sc.name = "Scroll" + p.name
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true
		UiUtil.full_rect(sc)
		host.add_child(sc)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(p)
	var foot_margin: MarginContainer = MarginContainer.new()   # K2: page content flush with the page bottom (1/3's
	foot_margin.add_theme_constant_override("margin_top", 2)  # look panel) still keeps 12 px to the foot's buttons
	col.add_child(foot_margin)
	var foot: HBoxContainer = UiUtil.hbox(16)
	foot.name = "Foot"
	foot_margin.add_child(foot)
	back_button = UiUtil.button("◀ Zurück", &"")
	back_button.name = "Back"
	back_button.custom_minimum_size = Vector2(220, 0)
	back_button.add_theme_font_size_override("font_size", _fs(22))
	UiUtil.touch_pad(back_button)
	back_button.pressed.connect(back)
	foot.add_child(back_button)
	_hint = UiUtil.label("", &"LabelSmall", _fs(16), UiTheme.C_TEXT_DIM)
	_hint.name = "Hint"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_hint)
	next_button = UiUtil.button("Weiter ▶", &"ButtonBig")
	next_button.name = "Next"
	next_button.custom_minimum_size = Vector2(260, 0)
	next_button.add_theme_font_size_override("font_size", _fs(26))
	UiUtil.touch_pad(next_button, 72.0)
	next_button.pressed.connect(next)
	foot.add_child(next_button)
	start_button = UiUtil.button("Sendung starten ▶", &"ButtonBig")
	start_button.name = "Start"
	start_button.custom_minimum_size = Vector2(320, 0)
	start_button.add_theme_font_size_override("font_size", _fs(26))
	UiUtil.touch_pad(start_button, 72.0)
	start_button.pressed.connect(start_show)
	foot.add_child(start_button)
	if edit_mode:                                # K2 (08 §1.7): the mask in the safe room
		back_button.text = "◀ Abbrechen"
		next_button.text = "Übernehmen ▶"


func _head_button(caption: String, node_name: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(caption, &"")
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 0)
	b.add_theme_font_size_override("font_size", _fs(22))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiUtil.touch_pad(b)
	b.pressed.connect(cb)
	return b


## 1/3 (K2 layout, 08 §1.2): row 1 = name (+ "Tastatur") and "M.O.D. nennt Sie" (they wrap onto two lines when the
## text is large); row 2 = the live 3D figure with the lower third and the look panel (six ◀ ▶ selectors, two columns).
## At 1280 × 720 everything fits without scrolling: 88 + 12 + 3 × 88 + 2 × 12 = 388 px.
func _build_page1() -> Control:
	var page_box: VBoxContainer = UiUtil.vbox(12)
	page_box.name = "Page1"
	var top: HFlowContainer = HFlowContainer.new()
	top.name = "NameRow"
	top.add_theme_constant_override("h_separation", 24)
	top.add_theme_constant_override("v_separation", 12)
	page_box.add_child(top)
	var row: HBoxContainer = UiUtil.hbox(12)
	row.name = "NameGroup"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(row)
	var name_cap: Label = _caption("NAME")
	name_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_cap)
	name_edit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.max_length = NAME_MAX
	name_edit.placeholder_text = "Kai"
	name_edit.virtual_keyboard_enabled = false
	name_edit.custom_minimum_size = Vector2(0, UiTheme.TOUCH_HIT)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", _fs(32))
	name_edit.focus_mode = Control.FOCUS_ALL
	name_edit.text_changed.connect(func(t: String) -> void:
		var clean: String = UiUtil.glyph_safe(t).replace("?", "") if not t.contains("?") else t
		if clean != t:
			name_edit.text = clean
			name_edit.caret_column = clean.length()
		set_player_name(name_edit.text))
	name_edit.text_submitted.connect(func(_t: String) -> void: UiUtil.focus_later(next_button))
	name_edit.gui_input.connect(_on_name_gui_input)
	row.add_child(name_edit)
	name_edit.custom_minimum_size.x = 200.0 * text_scale
	keyboard_button = UiUtil.button("Tastatur", &"")
	keyboard_button.name = "Keyboard"
	keyboard_button.custom_minimum_size = Vector2(160, 0)
	keyboard_button.add_theme_font_size_override("font_size", _fs(22))
	UiUtil.touch_pad(keyboard_button)
	keyboard_button.pressed.connect(func() -> void: open_keyboard("name"))
	row.add_child(keyboard_button)
	var forms: HBoxContainer = UiUtil.hbox(12)
	forms.name = "Forms"
	top.add_child(forms)
	var forms_cap: Label = _caption("M.O.D. NENNT SIE")
	forms_cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	forms.add_child(forms_cap)
	for f: Array in FORMS:
		var b: Button = UiUtil.button(str(f[1]), &"")
		b.name = "Form_" + str(f[0])
		b.toggle_mode = true
		b.custom_minimum_size.x = 130.0
		b.add_theme_font_size_override("font_size", _fs(22))
		_toggle_style(b)
		UiUtil.touch_pad(b)
		var fid: String = str(f[0])
		b.pressed.connect(func() -> void: set_form(fid))
		forms.add_child(b)
		form_buttons[fid] = b
	var stage: HBoxContainer = UiUtil.hbox(28)
	stage.name = "LookRow"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_child(stage)
	var left: VBoxContainer = UiUtil.vbox(0)
	left.custom_minimum_size = Vector2(FIGURE_W, 0)
	stage.add_child(left)
	figure = Figure.new("kai", UiUtil.member_color("kai"), PersonaProfile.clean_look(profile.look, DB.data), true)
	figure.custom_minimum_size = Vector2(FIGURE_W, 230.0)
	figure.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(figure)
	var lt: PanelContainer = PanelContainer.new()
	lt.name = "LowerThird"
	lt.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_ACCENT.darkened(0.35), Color(0, 0, 0, 0), 0, 0.21,
		18, 6))                                # paper on dark magenta: 6.3 : 1
	left.add_child(lt)
	_lower_third = UiUtil.label("", &"", _fs(24), UiUtil.C_PAPER)
	_lower_third.add_theme_font_override("font", UiTheme.font_bold())
	_lower_third.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lt.add_child(_lower_third)
	stage.add_child(_build_look_panel())
	name_edit.text = profile.name if set_fields.has("name") else ""
	for f: Variant in form_buttons.keys():
		(form_buttons[f] as Button).set_pressed_no_signal(str(f) == profile.form)
	_update_lower_third()
	_refresh_look()
	return page_box


## K2: the look panel — two columns of three selectors: ◀ | caption over value (+ colour swatch) | ▶ (88 px hit areas,
## 64 px visible, 12+ px apart). Order = 08 §1.2: Frisur, Haarfarbe / Hautton, Bart / Brille, Outfit.
func _build_look_panel() -> Control:
	var grid: GridContainer = GridContainer.new()
	grid.name = "LookPanel"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	for kind: String in LOOK_KINDS:
		var cell: HBoxContainer = UiUtil.hbox(12)
		cell.name = "Look_" + kind
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		var prev: Button = _look_arrow("◀", "Prev_" + kind, kind, -1)
		cell.add_child(prev)
		var mid: VBoxContainer = UiUtil.vbox(2)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mid.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(mid)
		var crow: HBoxContainer = UiUtil.hbox(8)     # [swatch] CAPTION — the value below fills the cell
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		mid.add_child(crow)
		var sw: Panel = Panel.new()
		sw.name = "Swatch"
		sw.custom_minimum_size = Vector2(_fs(16), _fs(16))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crow.add_child(sw)
		var cap: Label = _caption(str(LOOK_CAPTIONS[kind]))
		cap.name = "Caption"
		crow.add_child(cap)
		var v: Label = UiUtil.label("", &"", _fs(22), UiTheme.C_TEXT)
		v.name = "Value"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.custom_minimum_size.x = 40.0
		mid.add_child(v)
		var nxt: Button = _look_arrow("▶", "Next_" + kind, kind, 1)
		cell.add_child(nxt)
		look_rows[kind] = {"prev": prev, "next": nxt, "caption": cap, "value": v, "swatch": sw}
	return grid


## A ◀ / ▶ look button: 88 × 88 hit area, a 64 × 64 visible box (touch_pad + horizontal insets).
func _look_arrow(glyph: String, node_name: String, kind: String, dir: int) -> Button:
	var b: Button = UiUtil.button(glyph, &"")
	b.name = node_name
	b.custom_minimum_size = Vector2(UiTheme.TOUCH_HIT, UiTheme.TOUCH_HIT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", _fs(22))
	UiUtil.touch_pad(b)
	var inset: float = (float(UiTheme.TOUCH_HIT) - float(UiTheme.MIN_TOUCH)) * 0.5
	for st: String in UiUtil.BUTTON_STATES:
		var sb: StyleBox = b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var d: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			d.expand_margin_left -= inset
			d.expand_margin_right -= inset
			b.add_theme_stylebox_override(st, d)
	b.pressed.connect(func() -> void: step_look(kind, dir))
	return b


func _build_page2() -> Control:
	var page_box: VBoxContainer = UiUtil.vbox(14)
	page_box.name = "Page2"
	origin_button = _choice_row(page_box, "VORLEBEN", "Origin", func() -> void: open_picker("origin"))
	hobby_button = _choice_row(page_box, "HOBBY / TALENT", "Hobby", func() -> void: open_picker("hobby"))
	traits_button = _choice_row(page_box, "EIGENSCHAFTEN", "Traits", func() -> void: open_picker("traits"))
	_canon_hint = UiUtil.label("Nichts gewählt? Dann gilt der Kanon: Tierpflege, Hobby Tiere — Sie spielen Kai.",
		&"LabelSmall", _fs(16), UiTheme.C_TEXT_DIM)
	_canon_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_box.add_child(_canon_hint)
	return page_box


func _choice_row(parent: VBoxContainer, caption: String, node_name: String, cb: Callable) -> Button:
	var row: HBoxContainer = UiUtil.hbox(16)
	parent.add_child(row)
	var l: Label = _caption(caption)
	l.custom_minimum_size = Vector2(ROW_LABEL_W * minf(text_scale, 1.15), 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var b: Button = UiUtil.button("", &"")      # a framed field: tappable at a glance (touch)
	b.name = node_name
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(b, 72.0)
	var inner: HBoxContainer = UiUtil.hbox(12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.full_rect(inner)
	inner.offset_left = 18
	inner.offset_right = -18
	b.add_child(inner)
	var holder: CenterContainer = CenterContainer.new()
	holder.name = "IconHolder"
	holder.custom_minimum_size = Vector2(_fs(30), 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(holder)
	var v: Label = UiUtil.label("", &"", _fs(24))
	v.name = "Value"
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(v)
	var arrow: Control = UiIcon.make(&"arrow_right", UiTheme.C_ACCENT_2, _fs(22))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(arrow)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


func _build_page3() -> Control:
	var page_box: VBoxContainer = UiUtil.vbox(12)
	page_box.name = "Page3"
	_card_host = UiUtil.hbox(24)
	_card_host.name = "CardRow"
	_card_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_box.add_child(_card_host)
	var mod_panel: PanelContainer = PanelContainer.new()
	mod_panel.name = "ModComment"
	mod_panel.custom_minimum_size = Vector2(320, 0)
	mod_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mod_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mod_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.85), UiTheme.C_ACCENT_2, 2,
		0.0, 20, 14))
	_card_host.add_child(mod_panel)
	_card_mod = UiUtil.label("", &"", _fs(22), UiTheme.C_ACCENT_2)
	_card_mod.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mod_panel.add_child(_card_mod)
	var mrow: HBoxContainer = UiUtil.hbox(12)
	mrow.name = "Modes"
	page_box.add_child(mrow)
	var ml: Label = _caption("SENDEFORMAT")
	ml.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mrow.add_child(ml)
	for m: Dictionary in MODES:
		var b: Button = UiUtil.button(str(m["title"]), &"")
		b.name = "Mode_" + str(m["id"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(250, 0)
		b.add_theme_font_size_override("font_size", _fs(22))
		_toggle_style(b)
		UiUtil.touch_pad(b)
		var mid: StringName = m["id"]
		b.pressed.connect(func() -> void: _set_difficulty(mid))
		mrow.add_child(b)
		mode_buttons[m["id"]] = b
	_mode_text = UiUtil.label("", &"LabelSmall", _fs(16), UiTheme.C_TEXT_DIM)
	_mode_text.name = "ModeText"
	_mode_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_box.add_child(_mode_text)
	_set_difficulty(&"prime")
	return page_box


func _caption(text: String) -> Label:
	var l: Label = UiUtil.label(text, &"", _fs(16), UiTheme.C_ACCENT)
	l.add_theme_font_override("font", UiTheme.font_bold())
	return l


func _toggle_style(b: Button) -> void:
	var sb: StyleBoxFlat = UiUtil.box_style(Color(UiTheme.C_ACCENT, 0.35), UiTheme.C_ACCENT, 3, 0.0, 16, 8)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover_pressed", sb)


## Touch tap or gamepad A on the name field → the on-screen keyboard (08 §1.6).
func _on_name_gui_input(event: InputEvent) -> void:
	var touch: bool = Game.input_scheme == Game.InputScheme.TOUCH and ((event is InputEventScreenTouch
		and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed))
	var pad_a: bool = event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed \
		and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A
	if touch or pad_a:
		name_edit.accept_event()
		open_keyboard("name")


## Focus per page: up / down through the rows with wrap, left / right inside a row; Tab in reading order.
func _wire() -> void:
	var order: Array[Control] = []
	match page:
		1:
			order = _wire_page1()
		2:
			UiUtil.wire_horizontal([dice_button, rest_button] as Array[Control])
			UiUtil.wire_horizontal([back_button, next_button] as Array[Control])
			_vertical([rest_button, origin_button, hobby_button, traits_button, next_button] as Array[Control])
			dice_button.focus_neighbor_bottom = dice_button.get_path_to(origin_button)
			dice_button.focus_neighbor_top = dice_button.get_path_to(next_button)
			back_button.focus_neighbor_top = back_button.get_path_to(traits_button)
			back_button.focus_neighbor_bottom = back_button.get_path_to(rest_button)
			order = [origin_button, hobby_button, traits_button, back_button, next_button, dice_button,
				rest_button] as Array[Control]
		3:
			var modes: Array[Control] = []
			for m: Dictionary in MODES:
				modes.append(mode_buttons[m["id"]] as Control)
			UiUtil.wire_horizontal(modes)
			UiUtil.wire_horizontal([back_button, start_button] as Array[Control])
			for b: Control in modes:
				b.focus_neighbor_top = b.get_path_to(start_button)
				b.focus_neighbor_bottom = b.get_path_to(start_button)
			for b: Control in [back_button, start_button] as Array[Control]:
				b.focus_neighbor_top = b.get_path_to(modes[0])
				b.focus_neighbor_bottom = b.get_path_to(modes[0])
			order = modes.duplicate()
			order.append_array([back_button, start_button] as Array[Control])
	for i in order.size():
		order[i].focus_next = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_previous = order[i].get_path_to(order[posmod(i - 1, order.size())])


## 1/3 (K2): the name row (name ↔ Tastatur ↔ the three word forms), the look grid (three rows ◀ ▶ ◀ ▶), the foot
## and the head buttons; up / down keep the column (the name over the left look column, the word forms over the
## right one), every row wraps left / right. Returns the Tab order.
func _wire_page1() -> Array[Control]:
	var forms: Array[Control] = []
	for f: Array in FORMS:
		forms.append(form_buttons[str(f[0])] as Control)
	var top: Array[Control] = [name_edit, keyboard_button]
	top.append_array(forms)
	UiUtil.wire_horizontal(top)
	var grid: Array = []                       # rows of [◀ left, ▶ left, ◀ right, ▶ right]
	for r in 3:
		var left: Dictionary = look_rows[LOOK_KINDS[r * 2]]
		var right: Dictionary = look_rows[LOOK_KINDS[r * 2 + 1]]
		var line: Array[Control] = [left["prev"] as Control, left["next"] as Control, right["prev"] as Control,
			right["next"] as Control]
		UiUtil.wire_horizontal(line)
		grid.append(line)
	var head: Array[Control] = [dice_button]
	if not edit_mode:
		head.append(rest_button)
	UiUtil.wire_horizontal(head)
	UiUtil.wire_horizontal([back_button, next_button] as Array[Control])
	var sel: Control = form_buttons.get(profile.form, forms[2]) as Control
	var above: Array[Control] = [name_edit, keyboard_button, sel, sel]     # over the grid's four columns
	var below: Array[Control] = [back_button, back_button, next_button, next_button]
	for c in 4:
		var col: Array[Control] = [above[c]]
		for r in 3:
			col.append((grid[r] as Array)[c] as Control)
		col.append(below[c])
		for i in range(1, col.size() - 1):
			col[i].focus_neighbor_top = col[i].get_path_to(col[i - 1])
			col[i].focus_neighbor_bottom = col[i].get_path_to(col[i + 1])
	var first: Array = grid[0]
	var last: Array = grid[2]
	for c: Control in top:
		var target: Control = first[0] as Control if c == name_edit else (first[1] as Control if c == keyboard_button
			else first[2] as Control)
		c.focus_neighbor_bottom = c.get_path_to(target)
		c.focus_neighbor_top = c.get_path_to(head[head.size() - 1])
	back_button.focus_neighbor_top = back_button.get_path_to(last[0] as Control)
	next_button.focus_neighbor_top = next_button.get_path_to(last[3] as Control)
	for c: Control in [back_button, next_button] as Array[Control]:
		c.focus_neighbor_bottom = c.get_path_to(head[head.size() - 1])
	for c: Control in head:
		c.focus_neighbor_bottom = c.get_path_to(name_edit)
		c.focus_neighbor_top = c.get_path_to(next_button)
	var order: Array[Control] = top.duplicate()
	for line: Variant in grid:
		order.append_array(line as Array[Control])
	order.append_array([back_button, next_button] as Array[Control])
	order.append_array(head)
	return order


func _vertical(list: Array[Control]) -> void:
	for i in list.size():
		list[i].focus_neighbor_top = list[i].get_path_to(list[posmod(i - 1, list.size())])
		list[i].focus_neighbor_bottom = list[i].get_path_to(list[(i + 1) % list.size()])
