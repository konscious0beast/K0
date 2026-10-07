extends Control
## Slot select (02_TECH §1.6, GDD §14.2/§10.1): three slots with name, floor, level, play time, followers, location.
## Modes: "new" (→ name entry; occupied slot asks "Überschreiben?"), "load" (→ Save.load_slot + routing §6.4),
## "save" (safe room; emits slot_chosen after the overwrite question). As Router screen it routes itself; with
## {"embedded": true} it only emits `slot_chosen(slot)` / `cancelled` (host closes it).

signal slot_chosen(slot: int)
signal cancelled()

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const UiIcon := preload("res://scenes/ui/ui_icon.gd")
const Backdrop := preload("res://scenes/ui/broadcast_bg.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const NAME_ENTRY: String = "res://scenes/title/name_entry.tscn"
const CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const TITLES: Dictionary = {"new": "NEUES SPIEL", "load": "SPIEL LADEN", "save": "SPIELSTAND SICHERN"}
const HINTS: Dictionary = {"new": "Wähle einen Slot für deine Sendung.", "load": "Welche Sendung soll weiterlaufen?",
	"save": "Gespeichert wird dieser Safe Room als Startpunkt."}

var mode: String = "new"
var slot_buttons: Array[Button] = []

var _params: Dictionary = {}
var _embedded: bool = false
var _busy: bool = false
var _modal: Node = null
var _back: Button


func setup(params: Dictionary) -> void:
	_params = params
	mode = str(params.get("mode", "new"))
	if not TITLES.has(mode):
		mode = "new"
	_embedded = bool(params.get("embedded", false))


func _ready() -> void:
	UiUtil.full_rect(self)
	if _embedded:
		UiUtil.apply_theme(self)
	else:
		Events.overlay_mode_requested.emit.call_deferred(&"menu")
	_build()
	focus_default()


func focus_default() -> void:
	for b: Button in slot_buttons:
		if not b.disabled:
			UiUtil.focus_later(b)
			return
	UiUtil.focus_later(_back)


func _unhandled_input(event: InputEvent) -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


## {} empty, {"corrupt": true}, else SaveCodec summary.
static func summary_of(slot: int) -> Dictionary:
	if not Save.has_save(slot):
		var s: Dictionary = Save.slot_summary(slot)
		return s if bool(s.get("corrupt", false)) else {}
	return Save.slot_summary(slot)


func choose(slot: int) -> void:
	if _busy or (_modal != null and is_instance_valid(_modal)):
		return
	var info: Dictionary = summary_of(slot)
	var occupied: bool = not info.is_empty()
	match mode:
		"load":
			if not occupied or bool(info.get("corrupt", false)):
				Sfx.play_ui(&"ui_error")
				return
			if _embedded:
				slot_chosen.emit(slot)
				return
			var err: Error = TitleFlow.load_and_route(slot)
			if err == OK:
				_busy = true
			else:
				Sfx.play_ui(&"ui_error")
				Events.toast_requested.emit(TitleFlow.load_error_text(err), &"warning")
		_:
			if occupied:
				_ask_overwrite(slot)
			else:
				_confirmed(slot)


func back() -> void:
	if _busy:
		return
	Sfx.play_ui(&"ui_cancel")
	if _embedded:
		cancelled.emit()
		return
	_busy = true
	Router.goto(Router.SCENE_TITLE)


func _confirmed(slot: int) -> void:
	if mode == "new" and not _embedded:
		_busy = true
		Router.goto(NAME_ENTRY, {"slot": slot})
		return
	slot_chosen.emit(slot)


func _ask_overwrite(slot: int) -> void:
	if not ResourceLoader.exists(CONFIRM):
		_confirmed(slot)
		return
	var d: Node = (load(CONFIRM) as PackedScene).instantiate()
	d.call("setup", {"title": "Überschreiben?", "text": "Slot %d enthält bereits eine Sendung. Überschreiben?" % slot,
		"yes": "Überschreiben", "no": "Abbrechen", "default_no": true, "danger": true})
	if get_tree().paused:
		d.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	d.connect("closed", func(yes: bool) -> void:
		_modal = null
		if yes:
			_confirmed(slot)
		elif slot - 1 < slot_buttons.size():
			UiUtil.focus_later(slot_buttons[slot - 1]))
	add_child(d)
	_modal = d


func _build() -> void:
	if _embedded:
		var dim: ColorRect = ColorRect.new()
		UiUtil.full_rect(dim)
		dim.color = Color(0.03, 0.02, 0.06, 0.82)
		add_child(dim)
	else:
		add_child(Backdrop.new())
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.extra = 24
	add_child(safe)
	var col: VBoxContainer = UiUtil.vbox(12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	safe.add_child(col)
	var head: HBoxContainer = UiUtil.hbox(14)
	col.add_child(head)
	head.add_child(UiUtil.label(str(TITLES[mode]), &"LabelTitle", 48))
	head.add_child(UiUtil.spacer(0, 0, true))
	head.add_child(InputGlyph.make(&"ui_cancel", "Zurück", 16))
	col.add_child(UiUtil.label(str(HINTS[mode]), &"", 20, UiTheme.C_TEXT_DIM))
	col.add_child(UiUtil.spacer(8))
	var list: Array[Control] = []
	for slot in range(1, Save.SLOT_COUNT + 1):
		var b: Button = _slot_card(slot)
		col.add_child(b)
		slot_buttons.append(b)
		list.append(b)
	col.add_child(UiUtil.spacer(4))
	_back = UiUtil.button("Zurück", &"ButtonBig")
	_back.name = "Back"
	_back.custom_minimum_size = Vector2(240, 64)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back.pressed.connect(back)
	col.add_child(_back)
	list.append(_back)
	UiUtil.wire_vertical(list)


func _slot_card(slot: int) -> Button:
	var info: Dictionary = summary_of(slot)
	var occupied: bool = not info.is_empty()
	var corrupt: bool = bool(info.get("corrupt", false))
	var b: Button = UiUtil.button("", &"ButtonBig")
	b.name = "Slot%d" % slot
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = mode == "load" and (not occupied or corrupt)
	b.pressed.connect(func() -> void: choose(slot))
	var row: HBoxContainer = UiUtil.hbox(20)
	UiUtil.full_rect(row)
	row.offset_left = 20
	row.offset_right = -24
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var num: PanelContainer = PanelContainer.new()
	num.custom_minimum_size = Vector2(76, 76)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.add_theme_stylebox_override("panel", UiUtil.box_style(UiTheme.C_ACCENT if occupied and not corrupt else
		Color(UiUtil.C_DISABLED, 0.6), Color(0, 0, 0, 0), 0, 0.21, 0, 0))
	row.add_child(num)
	var nl: Label = UiUtil.label(str(slot), &"LabelTitle", 46, UiUtil.C_PAPER)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_child(nl)
	var texts: VBoxContainer = UiUtil.vbox(2)
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	if corrupt:
		texts.add_child(UiUtil.label("Beschädigter Spielstand", &"", 26, UiTheme.C_DANGER))
		texts.add_child(UiUtil.label("Kann nicht geladen werden – überschreiben ist möglich.", &"LabelSmall", 16))
	elif not occupied:
		texts.add_child(UiUtil.label("Leerer Slot", &"", 26, UiTheme.C_TEXT_DIM))
		texts.add_child(UiUtil.label("Noch keine Sendung aufgezeichnet.", &"LabelSmall", 16))
	else:
		var name_l: Label = UiUtil.label(UiUtil.glyph_safe(str(info.get("player_name", "Kai"))), &"", 28)
		name_l.add_theme_font_override("font", UiTheme.font_bold())
		texts.add_child(name_l)
		var parts: PackedStringArray = ["Etage %d" % int(info.get("floor_index", 1)), "Level %d" % int(info.get("level",
			1)), "Spielzeit %s" % UiUtil.fmt_time(int(info.get("play_time_sec", 0))),
			"%s Follower" % UiUtil.fmt_int(int(info.get("followers", 0)))]
		texts.add_child(UiUtil.label("  ·  ".join(parts), &"", 18, UiTheme.C_TEXT_DIM))
		var loc: String = str(info.get("location", "start"))
		var where: String = "Start der Etage"
		if loc.begins_with("sr_"):
			var sr: Dictionary = UiUtil.safe_room_info(loc)
			where = "Safe Room " + (str(sr.get("name", loc)) if not sr.is_empty() else loc)
		var when: String = ""
		if info.has("saved_at_unix"):
			when = "  ·  " + Time.get_datetime_string_from_unix_time(int(info["saved_at_unix"]), true).replace("T", " ")
		texts.add_child(UiUtil.label(where + when, &"LabelSmall", 15))
	if occupied and not corrupt:
		var ic: Control = UiIcon.make(&"floppy", UiTheme.C_ACCENT_2, 34)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	return b
