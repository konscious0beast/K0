extends TestCase
## 08 §1 (K1): the casting scene. Default focus per page; a pure keyboard path (typing, Tab, arrows, Enter, Esc,
## Backspace, Ctrl+Enter) from 1/3 to the show; "Rest automatisch" with Esc or Start in two inputs (nothing set → the
## canon Kai); "Würfeln" gives a valid persona; "+ Eigenschaften" (<= 3, a fourth tap replaces the oldest, empty is
## fine); a rejected free text with its reason and a tile suggestion; touch targets >= 88 px 12 px apart, fonts >= 22 /
## 16 px, theme contrast >= 4.5 : 1, nothing overlaps at 1280×720 / 1680×720 / 1280×960, also with 130 % text; the
## on-screen keyboard's accent layer, touch / pad A on the name field; the back chain to the hero select; neutral
## headings when Graf Mopsula leads; every new game starts with an empty casting.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CASTING: String = "res://scenes/title/persona_casting.tscn"
const SCENE_HERO: String = "res://scenes/title/hero_select.tscn"
const SCENE_INTRO: String = "res://scenes/title/intro.tscn"
const SCENE_PAUSE: String = "res://scenes/ui/pause_menu.tscn"
const CardScript := preload("res://scenes/ui/persona_card.gd")
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const ROOT: String = "user://test_08_casting"
const SAVES: String = "user://test_08_casting/saves"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1680, 720), Vector2i(1280, 960)]
const WAIT: int = 900
const MOPSULA_TITLES: PackedStringArray = ["CASTING 1/3 · WER BEGLEITET DEN GRAFEN?", "CASTING 2/3 · STECKBRIEF",
	"CASTING 3/3 · KANDIDATENKARTE"]

var _saved_size: Vector2i
var _saved_scheme: int


func before_each() -> void:
	_saved_size = tree.root.size
	_saved_scheme = Game.input_scheme
	tree.root.size = Vector2i(1280, 720)
	tree.paused = false
	Save.save_dir = SAVES
	Save.read_only = false


func after_each() -> void:
	await _settle_router()
	tree.root.size = _saved_size
	tree.paused = false
	Game.set_input_scheme(_saved_scheme)
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.persona = null
	Game.timer_running = false
	Save.save_dir = "user://saves"
	_rmrf(ROOT)


static func _rmrf(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for sub: String in DirAccess.get_directories_at(path):
		_rmrf(path.path_join(sub))
	DirAccess.remove_absolute(path)


func _settle_router() -> void:
	for i in 600:
		if not Router.busy:
			break
		await tree.process_frame
	var cur: Node = Router.current
	if cur != null and is_instance_valid(cur) and not _nodes.has(cur):
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		for j in 240:
			if not Router.busy:
				break
			await tree.process_frame
		cur = Router.current
		if cur != null and is_instance_valid(cur):
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Game.timer_running = false


func _casting(params: Dictionary = {}) -> Node:
	var n: Node = (load(CASTING) as PackedScene).instantiate()
	var p: Dictionary = {"slot": 3, "seed": 77}
	p.merge(params, true)
	n.call("setup", p)
	add_to_tree(n)
	await wait_frames(3)
	return n


func _focus() -> Control:
	return tree.root.gui_get_focus_owner()


func _key(code: Key, ctrl: bool = false) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		tree.root.push_input(ev)


func _type(text: String) -> void:
	for ch: String in text:
		for pressed: bool in [true, false]:
			var ev: InputEventKey = InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(ch.to_upper())
			ev.unicode = ch.unicode_at(0)
			ev.pressed = pressed
			tree.root.push_input(ev)


func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		tree.root.push_input(ev)


func _wait_screen(path: String) -> bool:
	return await wait_until(func() -> bool:
		return Router.current != null and is_instance_valid(Router.current) \
			and Router.current.scene_file_path == path and not Router.busy, WAIT)


# --- flow ---------------------------------------------------------------------------------------------------------

func test_default_focus_per_page() -> void:
	var n: Node = await _casting()
	assert_eq(_focus(), n.get("name_edit"), "1/3: the name field")
	assert_eq(str(n.call("heading")), "CASTING 1/3 · WER SIND SIE?")
	assert_eq((n.get("name_edit") as LineEdit).text, "", "an empty field: Kai unless typed")
	n.call("next")
	await wait_frames(2)
	assert_eq(_focus(), n.get("origin_button"), "2/3: Vorleben")
	assert_eq(str(n.call("heading")), "CASTING 2/3 · STECKBRIEF")
	n.call("next")
	await wait_frames(2)
	assert_eq(_focus(), n.get("start_button"), "3/3: Sendung starten")
	assert_eq(str(n.call("heading")), "CASTING 3/3 · IHRE KANDIDATENKARTE")
	assert_false((n.get("rest_button") as Control).visible, "no \"Rest automatisch\" on 3/3")


func test_keyboard_only_path_to_the_show() -> void:
	var n: Node = await _casting()
	_type("Jana")
	await wait_frames(1)
	assert_eq((n.get("profile") as PersonaProfile).name, "Jana", "typing goes into the name field")
	_key(KEY_TAB)
	await wait_frames(1)
	assert_eq(_focus(), n.get("keyboard_button"), "Tab: the keyboard button")
	_key(KEY_RIGHT)
	await wait_frames(1)
	var forms: Dictionary = n.get("form_buttons")
	assert_eq(_focus(), forms["f"], "right: the word forms (K2: in the name row)")
	_key(KEY_ENTER)
	await wait_frames(1)
	assert_eq((n.get("profile") as PersonaProfile).form, "f", "Enter chooses \"Kandidatin\"")
	_key(KEY_DOWN)
	await wait_frames(1)
	var rows: Dictionary = n.get("look_rows")
	assert_eq(_focus(), rows["hair_color"]["prev"], "down: the look panel (K2)")
	_key(KEY_ENTER)
	await wait_frames(1)
	assert_eq(str(n.call("look_id", "hair_color")), "lk_hc_black", "◀ the previous hair colour")
	for i in 3:
		_key(KEY_DOWN)
	await wait_frames(1)
	assert_eq(_focus(), n.get("next_button"))
	_key(KEY_ENTER)
	await wait_frames(2)
	assert_eq(int(n.get("page")), 2)
	assert_eq(_focus(), n.get("origin_button"))
	_key(KEY_ENTER)
	await wait_frames(2)
	var picker: Control = n.get("overlay")
	assert_eq(str(picker.get("mode")), "origin", "Enter opens VORLEBEN WÄHLEN")
	var tiles: Dictionary = picker.get("tiles")
	assert_eq(_focus(), tiles["org_animals"], "the first tile has the focus")
	_key(KEY_RIGHT)
	await wait_frames(1)
	assert_eq(_focus(), tiles["org_care"])
	_key(KEY_ENTER)
	await wait_frames(2)
	assert_eq(n.get("overlay"), picker, "a tile with \"genauer\" chips keeps the overlay open")
	var chips: Dictionary = picker.get("chips")
	assert_eq(_focus(), chips.values()[0], "the focus moves to the chips")
	_key(KEY_RIGHT)
	await wait_frames(1)
	_key(KEY_ENTER)
	await wait_frames(2)
	assert_null(n.get("overlay"), "a chip chooses and closes")
	var prof: PersonaProfile = n.get("profile")
	assert_eq([prof.origin, prof.occupation], ["org_care", str(chips.keys()[1])])
	assert_eq(_focus(), n.get("hobby_button"), "after a choice the focus moves on")
	_key(KEY_ENTER)
	await wait_frames(2)
	_key(KEY_ENTER)
	await wait_frames(2)
	assert_eq(prof.hobby, "hob_cooking", "one tap chooses the hobby")
	assert_eq(_focus(), n.get("traits_button"))
	_key(KEY_ENTER)
	await wait_frames(2)
	_key(KEY_ENTER)
	_key(KEY_RIGHT)
	await wait_frames(1)
	_key(KEY_ENTER)
	_key(KEY_ESCAPE)
	await wait_frames(2)
	assert_null(n.get("overlay"), "Esc closes the traits overlay with its chips")
	var traits: Array[Dictionary] = DB.data.persona_list("traits")
	assert_eq(prof.traits, PackedStringArray([str(traits[0]["id"]), str(traits[1]["id"])]))
	assert_eq(_focus(), n.get("next_button"))
	_key(KEY_BACKSPACE)
	await wait_frames(2)
	assert_eq(int(n.get("page")), 1, "Backspace = back")
	assert_eq((n.get("name_edit") as LineEdit).text, "Jana", "nothing is lost")
	_key(KEY_BACKSPACE)
	await wait_frames(1)
	assert_eq(int(n.get("page")), 1, "in the name field Backspace deletes")
	assert_eq(prof.name, "Jan")
	_type("a")
	_key(KEY_ENTER, true)
	await wait_frames(2)
	_key(KEY_ENTER, true)
	await wait_frames(2)
	assert_eq(int(n.get("page")), 3, "Ctrl+Enter = Weiter")
	assert_eq(_focus(), n.get("start_button"))
	var final: PersonaProfile = n.get("final")
	assert_eq([final.name, final.form, final.origin, final.hobby], ["Jana", "f", "org_care", "hob_cooking"])
	_key(KEY_ENTER)
	await wait_frames(1)
	assert_true(bool(n.get("started")), "Enter starts the show")
	assert_not_null(Game.persona)
	assert_eq(Game.persona.to_dict(), final.to_dict(), "the new game has the card's persona")
	assert_eq(Game.state.player_name, "Jana")
	assert_true(await _wait_screen(SCENE_INTRO), "→ the intro")


func test_rest_automatisch_in_two_inputs() -> void:
	var n: Node = await _casting()
	assert_eq(_focus(), n.get("name_edit"), "the name field has the focus (and eats a first Esc by itself)")
	_key(KEY_ESCAPE)
	await wait_frames(2)
	assert_eq(int(n.get("page")), 3, "Esc: Rest automatisch → 3/3")
	var final: PersonaProfile = n.get("final")
	assert_true(final.is_canon(DB.data), "nothing set = the canon Kai")
	assert_eq([final.name, final.origin, final.hobby, final.traits], ["Kai", "org_animals", "hob_animals",
		PackedStringArray()])
	assert_eq(_focus(), n.get("start_button"))
	_key(KEY_ENTER)
	await wait_frames(1)
	assert_true(bool(n.get("started")), "the second input starts the show")
	assert_true(Game.persona.is_canon(DB.data))
	assert_eq(Game.run_log.cmds().back()["c"], {"t": "persona", "v": 2, "prof": "", "recipe": "rcp_cooking_hobby",
		"bias": []}, "09 ST0: persona v2 — the canon Kai picks his profession freely, Tiere gives the cooking recipe")
	await _settle_router()
	var g: Node = await _casting()
	_joy(JOY_BUTTON_START)
	await wait_frames(2)
	assert_eq(int(g.get("page")), 3, "gamepad Start: Rest automatisch")
	_joy(JOY_BUTTON_START)
	await wait_frames(1)
	assert_true(bool(g.get("started")), "Start again: Sendung starten")
	await _settle_router()
	var part: Node = await _casting()
	part.call("set_player_name", "Mika")
	part.call("set_form", "m")
	part.call("rest_auto")
	await wait_frames(1)
	var p: PersonaProfile = part.get("final")
	assert_eq([p.name, p.form, p.origin, p.hobby], ["Mika", "m", "org_animals", "hob_animals"],
		"only the unset fields get the canon")


func test_dice_gives_a_valid_persona() -> void:
	var n: Node = await _casting()
	n.call("next")
	await wait_frames(1)
	for i in 25:
		n.call("dice")
		var p: PersonaProfile = n.get("profile")
		assert_eq(p.validate(DB.data), PackedStringArray(), "roll %d: valid" % i)
		assert_true(p.traits.size() <= 2)
		for f: String in ["origin", "hobby", "traits"]:
			assert_true((n.get("set_fields") as PackedStringArray).has(f), f + " counts as set")
	n.call("next")
	var final: PersonaProfile = n.get("final")
	assert_eq(final.validate(DB.data), PackedStringArray())
	assert_ne(str((n.get("_card_mod") as Label).text), "", "M.O.D. comments the card")


func test_traits_overlay_up_to_three_and_empty() -> void:
	var n: Node = await _casting()
	n.call("next")
	n.call("open_picker", "traits")
	await wait_frames(2)
	var t: Control = n.get("overlay")
	var ids: Array[String] = []
	for d: Dictionary in DB.data.persona_list("traits"):
		ids.append(str(d["id"]))
	for i in 4:
		t.call("choose", ids[i])
	assert_eq(t.get("traits"), PackedStringArray([ids[1], ids[2], ids[3]]), "a fourth tap replaces the oldest")
	t.call("choose", ids[2])
	assert_eq(t.get("traits"), PackedStringArray([ids[1], ids[3]]), "a second tap removes")
	t.call("clear_traits")
	assert_eq((t.get("traits") as PackedStringArray).size(), 0)
	assert_true((t.find_child("None", true, false) as Button).disabled, "\"Keine\" is done")
	t.call("close")
	await wait_frames(1)
	assert_eq((n.get("profile") as PersonaProfile).traits, PackedStringArray(), "empty is a choice")
	n.call("next")
	assert_eq((n.get("final") as PersonaProfile).traits.size(), 0)


func test_a_rejected_free_text_has_a_reason_and_a_tile() -> void:
	var n: Node = await _casting()
	n.call("next")
	n.call("open_picker", "origin")
	await wait_frames(2)
	var picker: Control = n.get("overlay")
	picker.call("choose", "custom")
	await wait_frames(2)
	var k: Control = n.get("overlay")
	assert_ne(k, picker, "\"Anderes …\" opens the keyboard")
	assert_false(picker.visible, "over the picker")
	k.call("insert", "Politikerin")
	k.call("submit")
	await wait_frames(1)
	assert_eq(str(k.call("error_text")), "Politik sendet M.O.D. nicht.", "the reason")
	var sug: Button = k.find_child("Suggestion", true, false) as Button
	assert_true(sug.visible)
	assert_eq(sug.text, "Stattdessen: Büro, Finanzen & Verwaltung", "the nearest tile")
	sug.pressed.emit()
	await wait_frames(2)
	assert_null(n.get("overlay"), "keyboard and picker are closed")
	var p: PersonaProfile = n.get("profile")
	assert_eq([p.origin, p.job_text], ["org_office", ""], "the tile, never the rejected text")
	assert_eq(_focus(), n.get("hobby_button"))
	n.call("open_keyboard", "hobby")
	var k2: Control = n.get("overlay")
	k2.call("insert", "0151 2345678")
	k2.call("submit")
	assert_eq(str(k2.call("error_text")), "Bitte keine Kontaktdaten, Adressen oder Nummern.")
	assert_false((k2.find_child("Suggestion", true, false) as Button).visible, "no tile for hobbies")
	k2.call("cancel")
	await wait_frames(1)
	assert_null(n.get("overlay"))
	assert_eq(p.hobby_text, "", "nothing was kept")
	assert_eq(str(n.call("set_custom", "origin", "Imkerin")), "", "an accepted free text")
	n.call("next")
	var card: Dictionary = PersonaText.card(n.get("final") as PersonaProfile, DB.data)
	assert_eq(str(card["free"]), "Vorleben: „Imkerin“", "the free text only on the card")


# --- the on-screen keyboard ---------------------------------------------------------------------------------------

func test_keyboard_accent_layer_and_name_rules() -> void:
	var n: Node = await _casting()
	n.call("open_keyboard", "name")
	await wait_frames(2)
	var k: Control = n.get("overlay")
	var chars: PackedStringArray = []
	for b: Button in k.call("key_buttons"):
		chars.append(str(b.get_meta("char")))
	for c: String in ["Q", "Z", "Ü", "Ö", "Ä", "ß"]:
		assert_has(chars, c, "QWERTZ with umlauts: " + c)
	assert_eq(_focus(), (k.call("key_buttons") as Array)[0], "the focus is on the first key")
	k.call("type_char", "Z")
	k.call("type_char", "O")
	k.call("toggle_accents")
	await wait_frames(1)
	var accents: Dictionary = {}
	for b: Button in k.call("key_buttons"):
		accents[str(b.get_meta("char"))] = b
	assert_true(accents.size() >= 20, "the accent layer (%d keys)" % accents.size())
	for c: String in ["É", "Ñ", "Ç", "Ø"]:
		assert_true(accents.has(c), "accent key " + c)
	(accents["É"] as Button).pressed.emit()
	var edit: LineEdit = k.get("edit")
	assert_eq(edit.text, "Zoé", "shift only for the first letter, accents typed")
	for i in 12:
		k.call("insert", "x")
	assert_eq(edit.text.length(), 12, "at most 12 characters")
	_joy(JOY_BUTTON_X)
	assert_eq(edit.text.length(), 11, "pad X deletes")
	edit.text = "Zoé"
	_joy(JOY_BUTTON_START)
	await wait_frames(2)
	assert_null(n.get("overlay"), "pad Start = Fertig")
	assert_eq((n.get("profile") as PersonaProfile).name, "Zoé")
	assert_eq((n.find_child("LowerThird", true, false).get_child(0) as Label).text, "ZOÉ · Kandidat:in")
	assert_eq(_focus(), (n.get("form_buttons") as Dictionary)["n"], "after the name: the word form")
	n.call("open_keyboard", "name")
	await wait_frames(1)
	var k2: Control = n.get("overlay")
	(k2.get("edit") as LineEdit).text = "Tel 0151234"
	k2.call("submit")
	assert_has(str(k2.call("error_text")), "nicht sendefähig", "a rejected name keeps the keyboard open")
	_joy(JOY_BUTTON_B)
	await wait_frames(1)
	assert_null(n.get("overlay"), "pad B = cancel")
	assert_eq((n.get("profile") as PersonaProfile).name, "Zoé", "unchanged")


func test_touch_and_pad_a_open_the_keyboard() -> void:
	var n: Node = await _casting()
	var edit: LineEdit = n.get("name_edit")
	edit.grab_focus()
	_joy(JOY_BUTTON_A)
	await wait_frames(1)
	assert_not_null(n.get("overlay"), "pad A on the name field")
	(n.get("overlay") as Control).call("cancel")
	await wait_frames(1)
	var at: Vector2 = edit.get_global_rect().get_center()
	for pressed: bool in [true, false]:                    # a finger: the touch event (and its emulated click)
		var ev: InputEventScreenTouch = InputEventScreenTouch.new()
		ev.position = at
		ev.pressed = pressed
		tree.root.push_input(ev)
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.device = InputEvent.DEVICE_ID_EMULATION
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		tree.root.push_input(click)
	await wait_frames(1)
	assert_eq(Game.input_scheme, Game.InputScheme.TOUCH)
	assert_not_null(n.get("overlay"), "a tap on the name field (touch)")
	assert_eq(str(n.get("_overlay_kind")), "keyboard")


func test_back_chain_and_the_counts_headings() -> void:
	var n: Node = await _casting({"slot": 2, "hero": "mopsula"})
	var said: Array[String] = []
	for i in 3:
		said.append(str(n.call("heading")))
		if i < 2:
			n.call("next")
			await wait_frames(1)
	assert_eq(PackedStringArray(said), MOPSULA_TITLES, "neutral headings (08 §1.8)")
	for h: String in said:
		assert_false(h.contains("UNSER") or h.contains("WIR"), "no royal plural: " + h)
	n.call("back")
	await wait_frames(1)
	assert_eq(int(n.get("page")), 2)
	_joy(JOY_BUTTON_B)
	await wait_frames(1)
	assert_eq(int(n.get("page")), 1, "pad B = back")
	assert_has(str((n.get("_mod") as Label).text), "Der Graf führt heute das Casting", "persona_casting_open:mopsula")
	n.call("back")
	assert_true(await _wait_screen(SCENE_HERO), "1/3 → the hero select")
	assert_eq(int(Router.current.get("slot")), 2)
	await wait_frames(2)
	assert_eq(_focus(), (Router.current.get("cards") as Dictionary)["mopsula"], "the Count's card again")


func test_every_new_game_starts_with_an_empty_casting() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = "Jana"
	p.origin = "org_care"
	Game.persona = p
	var n: Node = await _casting()
	assert_eq((n.get("name_edit") as LineEdit).text, "", "no \"last card\" (08 C-2)")
	assert_eq((n.get("set_fields") as PackedStringArray).size(), 0)
	n.call("rest_auto")
	assert_true((n.get("final") as PersonaProfile).is_canon(DB.data))


# --- the card in the pause menu (08 §1.7) -------------------------------------------------------------------------

func test_the_candidate_card_in_the_pause_menu() -> void:
	Game.new_game(0, "Jana", 5, &"prime", "kai", CardScript.demo(DB.data))
	var pm: Node = (load(SCENE_PAUSE) as PackedScene).instantiate()
	pm.call("setup", {"tab": "party"})
	add_to_tree(pm)
	await wait_frames(3)
	var party: Control = pm.call("page", "party")
	var b: Button = party.get("card_button")
	assert_not_null(b, "\"Kandidatenkarte\" below the party cards")
	assert_true(b.get_global_rect().size.y >= UiTheme.TOUCH_HIT)
	b.pressed.emit()
	await wait_frames(3)
	var card: Node = party.call("open_card")
	assert_not_null(card)
	var texts: String = ""
	for l: Node in card.find_children("*", "Label", true, false):
		texts += (l as Label).text + "\n"
	for want: String in ["KANDIDATENKARTE", "STAFFEL 1 · FOLGE 1", "JANA · Kandidatin", "Hebamme · Hobby: Kochen & Backen",
			"chaotisch · fürsorglich", "Rival:in", "Sponsor"]:
		assert_has(texts, want, "card text " + want)
	assert_false(texts.contains("Startnummer"), "never a start number (C-17)")
	assert_true(card.is_ancestor_of(_focus()), "the focus is in the card")
	_key(KEY_DOWN)
	await wait_frames(1)
	assert_true(card.is_ancestor_of(_focus()), "modal: the focus stays in the card")
	_key(KEY_ESCAPE)
	await wait_frames(2)
	assert_false(is_instance_valid(card) and card.is_inside_tree(), "Esc closes the card")
	assert_true(pm.is_inside_tree() and not bool(pm.get("_closing")), "the pause menu stays open")
	assert_eq(_focus(), b, "back on the button")
	Game.persona = null
	party.call("refresh")
	assert_null(party.get("card_button"), "no persona, no button")
	assert_eq(party.call("casting_text", Game.state.member("kai")), "Spezies & Klasse: Recall auf Etage 3",
		"the floor-3 round is the Recall (08 C-16)")


# --- layout -------------------------------------------------------------------------------------------------------

## Hit areas, gaps, fonts and overlaps of every page and overlay at three sizes, with 100 % and 130 % text.
func test_layout_touch_targets_fonts_and_overlaps() -> void:
	for res: Vector2i in SIZES:
		for scale: float in [1.0, 1.3]:
			tree.root.size = res
			await wait_frames(1)
			var n: Node = await _casting({"text_scale": scale, "demo": true})
			var what: String = "%s @ %d %%" % [str(res), roundi(scale * 100)]
			for page: int in [1, 2, 3]:
				n.call("go_page", page)
				await wait_frames(3)
				_check_screen(n, "page %d %s" % [page, what])
			n.call("go_page", 2)
			for kind: String in ["origin", "hobby", "traits"]:
				n.call("open_picker", kind)
				await wait_frames(4)
				var o: Control = n.get("overlay")
				if kind == "origin":
					(o.get("tiles") as Dictionary)["org_care"].pressed.emit()   # the "genauer" chips row
					await wait_frames(3)
					assert_true(int(o.call("columns")) >= 2 and int(o.call("columns")) <= 6, "columns " + what)
					if res == Vector2i(1280, 720) and is_equal_approx(scale, 1.0):
						assert_eq(int(o.call("columns")), 6, "six columns at 1280 × 720")
				_check_screen(o, "%s overlay %s" % [kind, what])
				o.call("close")
				await wait_frames(2)
			n.call("open_keyboard", "name")
			await wait_frames(3)
			_check_screen(n.get("overlay") as Control, "keyboard " + what)
			(n.get("overlay") as Control).call("cancel")
			await wait_frames(1)
			n.queue_free()
			await wait_frames(1)


func test_theme_contrast() -> void:
	var bg: Color = UiTheme.C_BG
	var panel: Color = _over(UiTheme.C_PANEL, bg)
	var card: Color = Color("#1e1430")
	var pairs: Array[Array] = [
		[UiTheme.C_TEXT, bg, "text"], [UiTheme.C_TEXT, panel, "text on a panel"],
		[UiTheme.C_TEXT_DIM, bg, "dim text"], [UiTheme.C_TEXT_DIM, panel, "dim text on a panel"],
		[UiTheme.C_ACCENT, panel, "captions"], [UiTheme.C_ACCENT_2, bg, "M.O.D. line"],
		[UiTheme.C_ACCENT_2, card, "job on the card"], [UiTheme.C_GOLD, card, "free text on the card"],
		[UiTheme.C_DANGER, panel, "a rejection"], [UiUtil.C_INK, UiTheme.C_GOLD, "the stamp"],
		[UiTheme.C_TEXT, _over(Color(UiTheme.C_ACCENT, 0.35), panel), "a chosen tile"],
		[UiUtil.C_PAPER, UiTheme.C_ACCENT.darkened(0.35), "the lower third"],
	]
	for p: Array in pairs:
		var r: float = _contrast(p[0] as Color, p[1] as Color)
		assert_true(r >= 4.5, "%s: %.2f : 1 >= 4.5" % [p[2], r])


func _check_screen(root: Control, what: String) -> void:
	var vp: Rect2 = root.get_viewport().get_visible_rect()
	var hits: Array[Control] = []
	var leaves: Array[Control] = []
	_collect(root, hits, leaves)
	assert_true(hits.size() >= 2, "%s: controls found" % what)
	for c: Control in hits:
		var r: Rect2 = c.get_global_rect()
		assert_true(r.size.x >= UiTheme.TOUCH_HIT - 0.5 and r.size.y >= UiTheme.TOUCH_HIT - 0.5,
			"%s: %s hit area %s >= 88" % [what, c.name, str(r.size)])
		assert_true(vp.grow(0.5).encloses(r), "%s: %s %s on screen %s" % [what, c.name, str(r), str(vp.size)])
		var fs: int = c.get_theme_font_size("font_size")
		assert_true(fs >= UiTheme.FONT_SIZE, "%s: %s font %d >= 22" % [what, c.name, fs])
	for i in hits.size():
		for j in range(i + 1, hits.size()):
			var a: Rect2 = hits[i].get_global_rect()
			var b: Rect2 = hits[j].get_global_rect()
			var gap: float = maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x),
				maxf(b.position.y - a.end.y, a.position.y - b.end.y))
			assert_true(gap >= 12.0 - 0.5, "%s: %s / %s %.1f px apart (>= 12)" % [what, hits[i].name, hits[j].name, gap])
	for l: Control in leaves:
		var fs: int = l.get_theme_font_size("font_size")
		assert_true(fs >= UiTheme.FONT_SIZE_SMALL, "%s: %s font %d >= 16" % [what, l.name, fs])
		assert_true(vp.grow(0.5).encloses(l.get_global_rect()), "%s: %s on screen" % [what, l.name])
	var all: Array[Control] = hits.duplicate()
	all.append_array(leaves)
	for i in all.size():
		for j in range(i + 1, all.size()):
			var inter: Rect2 = all[i].get_global_rect().intersection(all[j].get_global_rect())
			assert_true(inter.size.x < 1.0 or inter.size.y < 1.0, "%s: %s overlaps %s" % [what, all[i].name,
				all[j].name])


## Visible buttons / line edits (hits) and visible labels with text outside them (leaves); nothing below a button,
## the card panel or a hidden overlay. Inside a ScrollContainer only what is fully in its view counts (the rest is
## reachable by scrolling, never under another control).
func _collect(n: Node, hits: Array[Control], leaves: Array[Control], clip: Rect2 = Rect2()) -> void:
	for c: Node in n.get_children():
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		var leaf: bool = c is BaseButton or c is LineEdit or (c is Label and (c as Label).text != "") \
			or c.name == "Card" or c is SubViewportContainer
		if leaf and clip.has_area() and not clip.grow(0.5).encloses(r):
			continue
		if c is BaseButton or c is LineEdit:
			hits.append(c as Control)
		elif leaf:
			leaves.append(c as Control)
		else:
			var sub: Rect2 = clip
			if c is ScrollContainer:
				sub = r if not clip.has_area() else clip.intersection(r)
			_collect(c, hits, leaves, sub)


static func _over(top: Color, below: Color) -> Color:
	return Color(lerpf(below.r, top.r, top.a), lerpf(below.g, top.g, top.a), lerpf(below.b, top.b, top.a), 1.0)


static func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v: float in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
