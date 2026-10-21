extends TestCase
## 08 §1.2, §1.5, §1.7, §6.1 (K2): the look editor on casting 1/3 — six ◀ ▶ selectors (FRISUR, HAARFARBE / TUCHFARBE,
## HAUTTON, BART, BRILLE, OUTFIT) step and wrap through data/looks.json, every colour shows its name and a swatch; the
## live preview swaps the rig inside its running SubViewport (no scene rebuild); "Würfeln" (button and pad X) rolls a
## valid look that counts as set; arrows / pad walk the panel, Enter / pad A / a finger press an arrow; "Rest
## automatisch" keeps a set look and gives the canon look otherwise; the new game's persona and its file carry the six
## look ids only (never recorded, never in the slot file); the edit mode from the candidate card — only in a safe
## room — writes name, word form and look into the running persona and its file (no command, no hash change),
## "Abbrechen" / Esc change nothing, and the safe room's candidate wears the new look; the hero select of a new game
## always shows the canon Kai.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CardScript := preload("res://scenes/ui/persona_card.gd")
const CASTING: String = "res://scenes/title/persona_casting.tscn"
const CARD: String = "res://scenes/ui/persona_card.tscn"
const SCENE_SAFE: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_HERO: String = "res://scenes/title/hero_select.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const ROOT: String = "user://test_08_avatar"
const SAVES: String = "user://test_08_avatar/saves"
const KINDS: PackedStringArray = ["hair", "hair_color", "skin", "beard", "glasses", "outfit"]
const CAPTIONS: Dictionary = {"hair": "FRISUR", "hair_color": "HAARFARBE", "skin": "HAUTTON", "beard": "BART",
	"glasses": "BRILLE", "outfit": "OUTFIT"}
const LOOK: Dictionary = {"hair": "lk_hair_long", "hair_color": "lk_hc_blue", "skin": "lk_skin_6",
	"beard": "lk_beard_none", "glasses": "lk_glasses_round", "outfit": "lk_outfit_orange"}

var _saved_size: Vector2i
var _saved_scheme: int
var _party_changed: int = 0


func before_each() -> void:
	_saved_size = tree.root.size
	_saved_scheme = Game.input_scheme
	tree.root.size = Vector2i(1280, 720)
	tree.paused = false
	Save.save_dir = SAVES
	Save.read_only = false
	_party_changed = 0
	Events.party_changed.connect(_on_party_changed)


func after_each() -> void:
	if Events.party_changed.is_connected(_on_party_changed):
		Events.party_changed.disconnect(_on_party_changed)
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
	Sfx.music(&"", 0.0)
	_rmrf(ROOT)


func _on_party_changed() -> void:
	_party_changed += 1


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


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		tree.root.push_input(ev)


func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.button_index = button
		ev.pressed = pressed
		tree.root.push_input(ev)


## A finger on `c` (the touch event and its emulated click, as Android delivers them).
func _tap(c: Control) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	for pressed: bool in [true, false]:
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


func _row(n: Node, kind: String) -> Dictionary:
	return (n.get("look_rows") as Dictionary)[kind]


func _preview_model(n: Node) -> Dictionary:
	var rig: Node = (n.get("figure") as Node).call("figure")
	return rig.get("model") as Dictionary if rig != null else {}


func _ids(list: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in list:
		out.append(str(e["id"]))
	return out


## A new game in `slot` with the demo persona (Jana: bun, chestnut, Ton 4, round glasses, Kittelweiß) in a safe room.
func _safe_room_game(slot: int) -> PersonaProfile:
	var p: PersonaProfile = CardScript.demo(DB.data)
	Game.new_game(slot, "Jana", 31, &"prime", "kai", p)
	Game.enter_safe_room("sr_kiosk")
	return Game.persona


# --- the selectors ----------------------------------------------------------------------------------------------------

func test_six_selectors_step_and_wrap() -> void:
	var n: Node = await _casting()
	var rows: Dictionary = n.get("look_rows")
	assert_eq(PackedStringArray(rows.keys()), KINDS, "six selectors in the order of 08 §1.2")
	var canon: Dictionary = PersonaProfile.canon_look(DB.data)
	for kind: String in KINDS:
		var row: Dictionary = rows[kind]
		assert_eq(str(n.call("look_id", kind)), str(canon[kind]), kind + ": the canon option first")
		assert_eq((row["caption"] as Label).text, str(CAPTIONS[kind]))
		assert_eq((row["value"] as Label).text, str(DB.data.look(str(canon[kind]))["name"]))
		for b: Button in [row["prev"] as Button, row["next"] as Button]:
			var r: Rect2 = b.get_global_rect()
			assert_true(r.size.x >= UiTheme.TOUCH_HIT - 0.5 and r.size.y >= UiTheme.TOUCH_HIT - 0.5,
				"%s: hit area %s >= 88" % [b.name, str(r.size)])
	assert_false((n.get("set_fields") as PackedStringArray).has("look"), "untouched: the look is not set")
	for kind: String in KINDS:
		var ids: PackedStringArray = _ids(DB.data.looks_of(kind))
		var start: int = ids.find(str(n.call("look_id", kind)))
		var seen: PackedStringArray = []
		for i in ids.size():
			(_row(n, kind)["next"] as Button).pressed.emit()
			var want: String = ids[(start + i + 1) % ids.size()]
			assert_eq(str(n.call("look_id", kind)), want, "%s ▶ %d" % [kind, i + 1])
			assert_eq((_row(n, kind)["value"] as Label).text, str(DB.data.look(want)["name"]), "the row names it")
			seen.append(want)
		assert_eq(seen.size(), ids.size(), kind + ": every option for everyone")
		assert_eq(str(n.call("look_id", kind)), ids[start], kind + ": wraps around")
		(_row(n, kind)["prev"] as Button).pressed.emit()
		assert_eq(str(n.call("look_id", kind)), ids[posmod(start - 1, ids.size())], kind + ": ◀ wraps back")
	assert_true((n.get("set_fields") as PackedStringArray).has("look"), "a step sets the look")
	var model: Dictionary = _preview_model(n)
	assert_eq(model, PersonaLook.apply(DB.data.party_member("kai").model, (n.get("profile") as PersonaProfile).look,
		DB.data), "the preview wears the panel's look")


func test_live_preview_swaps_the_rig_without_rebuilding_the_scene() -> void:
	var n: Node = await _casting()
	var fig: Node = n.get("figure")
	var vp: SubViewport = fig.get_child(0) as SubViewport
	var world: Node = vp.get_node("World")
	var page: Node = n.find_child("Page1", true, false)
	var arrow: Button = _row(n, "hair")["next"] as Button
	var swaps: int = int(fig.get("swaps"))
	n.call("set_look", "hair", "lk_hair_curls")
	n.call("set_look", "skin", "lk_skin_8")
	n.call("set_look", "beard", "lk_beard_full")
	await wait_frames(2)
	assert_eq(int(fig.get("swaps")), swaps + 3, "one swap per change")
	assert_true(n.get("figure") == fig and fig.get_child(0) == vp and vp.get_node("World") == world,
		"the same preview, viewport and world")
	assert_true(n.find_child("Page1", true, false) == page and _row(n, "hair")["next"] == arrow, "the scene stays")
	var rig: Node = fig.call("figure")
	assert_eq(rig.get_parent(), world)
	var rigs: int = 0
	for c: Node in world.get_children():
		rigs += 1 if c is CharacterRig else 0
	assert_eq(rigs, 1, "the old rigs are gone")
	var model: Dictionary = rig.get("model")
	assert_eq(model["style"], {"hair": "curls", "beard": "full"})
	assert_eq((model["colors"] as Dictionary)["skin"], "#4a2c1c")
	n.call("set_look", "hair", "lk_hc_blue")
	n.call("set_look", "glasses", "lk_nope")
	assert_eq(int(fig.get("swaps")), swaps + 3, "a foreign or unknown id changes nothing")
	assert_eq(str(n.call("look_id", "hair")), "lk_hair_curls")


func test_captions_swatches_and_the_headscarf() -> void:
	var n: Node = await _casting()
	for kind: String in ["hair_color", "skin", "outfit"]:
		for e: Dictionary in DB.data.looks_of(kind):
			n.call("set_look", kind, str(e["id"]))
			var sw: Panel = _row(n, kind)["swatch"] as Panel
			assert_true(sw.visible, "%s: a swatch" % e["id"])
			assert_eq((sw.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, PersonaLook.swatch(e))
			assert_eq((_row(n, kind)["value"] as Label).text, str(e["name"]), "every colour has its name")
	for kind: String in ["hair", "beard", "glasses"]:
		assert_false((_row(n, kind)["swatch"] as Panel).visible, kind + ": no swatch")
	var cap: Label = _row(n, "hair_color")["caption"] as Label
	n.call("set_look", "hair", "lk_hair_headscarf")
	assert_eq(cap.text, "TUCHFARBE", "the hair colour colours the headscarf")
	n.call("set_look", "hair", "lk_hair_bun")
	assert_eq(cap.text, "HAARFARBE")
	for kind: String in KINDS:
		for e: Dictionary in DB.data.looks_of(kind):
			assert_eq(UiUtil.glyph_safe(str(e["name"])), str(e["name"]), "%s: shown as written" % e["id"])


# --- dice, rest, start ------------------------------------------------------------------------------------------------

func test_dice_rolls_a_valid_look_that_counts_as_set() -> void:
	var n: Node = await _casting()
	var dice: Button = n.get("dice_button")
	assert_true(dice.visible, "\"Würfeln\" on 1/3 (K2)")
	var looks: Dictionary = {}
	for i in 25:
		if i % 2 == 0:
			dice.pressed.emit()
		else:
			_joy(JOY_BUTTON_X)
		var p: PersonaProfile = n.get("profile")
		assert_eq(PackedStringArray(p.look.keys()), KINDS, "roll %d: every kind" % i)
		for kind: String in KINDS:
			assert_eq(str(DB.data.look(str(p.look[kind])).get("kind", "")), kind, "roll %d: a %s option" % [i, kind])
		for err: String in p.validate(DB.data):            # (1/3: Vorleben and hobby are not chosen yet)
			assert_false(err.begins_with("look"), "roll %d: %s" % [i, err])
		assert_eq(_preview_model(n), PersonaLook.apply(DB.data.party_member("kai").model, p.look, DB.data))
		looks[JSON.stringify(p.look)] = true
	assert_true(looks.size() >= 20, "%d different looks in 25 rolls" % looks.size())
	assert_true((n.get("set_fields") as PackedStringArray).has("look"))
	assert_has(str((n.get("_mod") as Label).text).to_lower(), "gewürfelt", "M.O.D.'s dice line")
	n.call("rest_auto")
	await wait_frames(1)
	var rolled: Dictionary = (n.get("profile") as PersonaProfile).look.duplicate()
	assert_eq((n.get("final") as PersonaProfile).look, rolled, "the rolled look is kept")
	_joy(JOY_BUTTON_X)
	assert_eq((n.get("profile") as PersonaProfile).look, rolled, "3/3: no dice")


func test_rest_automatisch_keeps_a_set_look_and_gives_the_canon_otherwise() -> void:
	var n: Node = await _casting()
	n.call("rest_auto")
	await wait_frames(1)
	var final: PersonaProfile = n.get("final")
	assert_eq(final.look, PersonaProfile.canon_look(DB.data), "nothing set: Kai's look")
	assert_eq(PersonaLook.apply(DB.data.party_member("kai").model, final.look, DB.data),
		DB.data.party_member("kai").model, "… exactly today's Kai")
	n.call("back")
	await wait_frames(1)
	n.call("back")
	await wait_frames(1)
	assert_eq(int(n.get("page")), 1)
	n.call("set_look", "hair", "lk_hair_braids")
	n.call("set_look", "outfit", "lk_outfit_green")
	n.call("rest_auto")
	await wait_frames(1)
	var want: Dictionary = PersonaProfile.canon_look(DB.data)
	want["hair"] = "lk_hair_braids"
	want["outfit"] = "lk_outfit_green"
	assert_eq((n.get("final") as PersonaProfile).look, want, "the set kinds stay, the rest is canon")


func test_the_new_game_carries_the_look_ids_only() -> void:
	var n: Node = await _casting({"slot": 3})
	n.call("set_player_name", "Mika")
	for kind: String in KINDS:
		n.call("set_look", kind, str(LOOK[kind]))
	n.call("rest_auto")
	await wait_frames(1)
	n.call("start_show")
	await wait_frames(1)
	assert_true(bool(n.get("started")))
	assert_not_null(Game.persona)
	if Game.persona == null:
		return
	assert_eq(Game.persona.look, LOOK, "the persona: six ids")
	var model: Dictionary = DB.party_model("kai")
	assert_eq(model["style"], {"hair": "long", "beard": "none"}, "DB.party_model dresses kai")
	assert_has(Array(model["props"]), "glasses")
	var recorded: String = JSON.stringify(Game.run_log.cmds())
	assert_false(recorded.contains("lk_"), "the look is never recorded")
	assert_false(JSON.stringify(StateHash.hash_input(Game.state)).contains("lk_"), "… nor in the state hash")
	assert_eq(Save.save_slot(3), OK)
	var file: Dictionary = JsonUtil.read_file(Save.persona_path(3))
	assert_eq(file.get("look", {}), LOOK, "the persona file stores the ids")
	var text: String = JSON.stringify(file.get("look", {}))
	for word: String in ["#", "style", "colors", "humanoid"]:
		assert_false(text.contains(word), "ids only, never " + word)
	assert_false(FileAccess.get_file_as_string(Save.slot_path(3)).contains("lk_"), "never in the slot file")
	var back: PersonaProfile = Save.load_persona(3)
	assert_eq(back.look, LOOK, "loaded back")


# --- keyboard, pad, touch ---------------------------------------------------------------------------------------------

func test_arrows_pad_and_touch_on_the_look_panel() -> void:
	var n: Node = await _casting()
	var hair_prev: Button = _row(n, "hair")["prev"] as Button
	hair_prev.grab_focus()
	await wait_frames(1)
	var right: Array[Button] = [_row(n, "hair")["next"], _row(n, "hair_color")["prev"], _row(n, "hair_color")["next"],
		hair_prev]
	for b: Button in right:
		_key(KEY_RIGHT)
		await wait_frames(1)
		assert_eq(_focus(), b, "right → " + b.name + " (the row wraps)")
	var down: Array[Control] = [_row(n, "skin")["prev"] as Control, _row(n, "glasses")["prev"] as Control,
		n.get("back_button") as Control]
	for c: Control in down:
		_key(KEY_DOWN)
		await wait_frames(1)
		assert_eq(_focus(), c, "down → " + c.name)
	_key(KEY_UP)
	_key(KEY_RIGHT)
	await wait_frames(1)
	assert_eq(_focus(), _row(n, "glasses")["next"])
	_key(KEY_ENTER)
	await wait_frames(1)
	assert_eq(str(n.call("look_id", "glasses")), "lk_glasses_round", "Enter presses ▶")
	_joy(JOY_BUTTON_A)
	await wait_frames(1)
	assert_eq(str(n.call("look_id", "glasses")), "lk_glasses_none", "pad A presses ▶ (wraps)")
	_tap(_row(n, "beard")["next"] as Control)
	await wait_frames(2)
	assert_eq(Game.input_scheme, Game.InputScheme.TOUCH)
	assert_eq(str(n.call("look_id", "beard")), "lk_beard_stubble", "a finger on ▶")
	_tap(_row(n, "outfit")["prev"] as Control)
	await wait_frames(2)
	assert_eq(str(n.call("look_id", "outfit")), "lk_outfit_midnight", "a finger on ◀ (wraps)")


# --- edit mode in the safe room (08 §1.7) -----------------------------------------------------------------------------

func test_edit_mode_from_the_card_in_the_safe_room() -> void:
	var p: PersonaProfile = _safe_room_game(2)
	var cmds: int = Game.run_log.cmds().size()
	var state_hash: String = StateHash.of(Game.state)
	var card: Control = (load(CARD) as PackedScene).instantiate() as Control
	card.call("setup", {})
	add_to_tree(card)
	await wait_frames(3)
	assert_true(bool(card.call("can_edit")), "in a safe room")
	var eb: Button = card.get("edit_button")
	assert_not_null(eb, "\"Name & Aussehen ändern\"")
	assert_true(eb.get_global_rect().size.y >= UiTheme.TOUCH_HIT - 0.5)
	eb.pressed.emit()
	await wait_frames(3)
	var ed: Node = card.get("editor")
	assert_not_null(ed, "the casting's 1/3 in edit mode")
	if ed == null:
		return
	assert_true(bool(ed.get("edit_mode")))
	assert_eq(str(ed.call("heading")), "IN DER MASKE · NAME & AUSSEHEN")
	assert_false((ed.get("rest_button") as Control).visible, "no \"Rest automatisch\"")
	assert_eq((ed.get("back_button") as Button).text, "◀ Abbrechen")
	assert_eq((ed.get("next_button") as Button).text, "Übernehmen ▶")
	assert_eq((ed.get("name_edit") as LineEdit).text, "Jana", "the running persona")
	assert_eq(str(ed.call("look_id", "hair")), "lk_hair_bun")
	assert_true(ed.is_ancestor_of(_focus()), "the focus is in the editor")
	ed.call("set_player_name", "Janne")
	ed.call("set_form", "n")
	ed.call("set_look", "hair", "lk_hair_curls")
	ed.call("set_look", "glasses", "lk_glasses_none")
	_party_changed = 0
	ed.call("next")
	await wait_frames(3)
	assert_false(is_instance_valid(ed) and ed.is_inside_tree(), "Übernehmen closes the editor")
	assert_null(card.get("editor"))
	assert_true(Game.persona == p, "the running persona, changed in place")
	assert_eq([p.name, p.form], ["Janne", "n"])
	var want: Dictionary = CardScript.DEMO_LOOK.duplicate()
	want["hair"] = "lk_hair_curls"
	want["glasses"] = "lk_glasses_none"
	assert_eq(p.look, want, "only the changed kinds")
	assert_eq([p.origin, p.hobby], ["org_care", "hob_cooking"], "Vertrag ist Vertrag")
	assert_true(_party_changed >= 1, "Events.party_changed")
	var changed: int = _party_changed
	assert_eq(Game.run_log.cmds().size(), cmds, "display only: nothing recorded")
	assert_eq(StateHash.of(Game.state), state_hash, "… and no hash change")
	var saved: PersonaProfile = Save.load_persona(2)
	assert_not_null(saved, "the persona file is written at once")
	if saved != null:
		assert_eq([saved.name, saved.look], ["Janne", want])
	assert_eq((DB.party_model("kai")["style"] as Dictionary)["hair"], "curls")
	await wait_frames(2)
	var texts: String = ""
	for l: Node in card.find_children("*", "Label", true, false):
		texts += (l as Label).text + "\n"
	assert_has(texts, "JANNE · Kandidat:in", "the card shows the new name")
	var fig: Node = card.find_child("Figure", true, false)
	assert_eq(((fig.call("figure") as Node).get("model") as Dictionary).get("style", {}),
		{"hair": "curls", "beard": "none"}, "… and the new look")
	(card.get("edit_button") as Button).pressed.emit()
	await wait_frames(3)
	var ed2: Node = card.get("editor")
	ed2.call("set_look", "hair", "lk_hair_bald")
	ed2.call("set_player_name", "Xaver")
	_key(KEY_ESCAPE)
	await wait_frames(3)
	assert_false(is_instance_valid(ed2) and ed2.is_inside_tree(), "Esc = Abbrechen")
	assert_true(is_instance_valid(card) and card.is_inside_tree(), "the card stays open")
	assert_eq([p.name, str(p.look["hair"])], ["Janne", "lk_hair_curls"], "cancelled: unchanged")
	assert_eq(_party_changed, changed, "cancelled: no party_changed")
	Game.leave_safe_room()
	assert_false(bool(card.call("can_edit")))
	assert_null(card.call("open_editor"), "outside a safe room no editor")
	assert_eq((card.get("_note") as Label).text, "Bitte in die Maske — nur im Safe Room.")


func test_the_safe_room_candidate_wears_the_look() -> void:
	var p: PersonaProfile = _safe_room_game(0)
	var r: Node = (load(SCENE_SAFE) as PackedScene).instantiate()
	r.call("setup", {})
	add_to_tree(r)
	await wait_frames(3)
	var kai3d: Node3D = r.get("_kai") as Node3D
	assert_eq(kai3d.get("model"), DB.party_model("kai"), "the candidate in the persona's look")
	assert_eq((kai3d.get("model") as Dictionary)["style"], {"hair": "bun", "beard": "none"})
	var at: Transform3D = kai3d.transform
	r.call("_after_modal", "")
	assert_true(r.get("_kai") == kai3d, "unchanged: nothing is rebuilt")
	p.look["hair"] = "lk_hair_braids"
	r.call("_after_modal", "")
	var now: Node3D = r.get("_kai") as Node3D
	assert_false(now == kai3d, "a changed look: a new figure")
	assert_eq(((now.get("model") as Dictionary)["style"] as Dictionary)["hair"], "braids")
	assert_true(now.transform.is_equal_approx(at), "on the same spot")
	assert_eq(now.get_parent(), r)


func test_the_hero_select_shows_the_canon_kai() -> void:
	Game.persona = CardScript.demo(DB.data)
	Game.ensure_state()
	var n: Node = (load(SCENE_HERO) as PackedScene).instantiate()
	n.call("setup", {"slot": 2})
	add_to_tree(n)
	await wait_frames(3)
	var models: Array[Dictionary] = []
	for f: Node in n.find_children("Figure", "", true, false):
		if "model" in f:
			models.append(f.get("model") as Dictionary)
	assert_true(models.size() >= 1, "the figures")
	var kai: Dictionary = DB.data.party_member("kai").model
	var found: bool = false
	for m: Dictionary in models:
		if str(m.get("base", "")) == "humanoid":
			found = true
			assert_eq(m, kai, "a new game: never the previous game's look")
	assert_true(found, "Kai's figure")
