extends TestCase
## M6 scene contract (02_TECH §11.3, §11.5, §10.2–10.4; 03_ART §9.2 F8): every UI scene instantiates standalone with
## setup({"capture": true}); menus own a focused control after _ready, overlays never take focus; PauseMenu and every
## page/dialog opened from it run WHEN_PAUSED; touch hit areas >= 88 px; SafeAreaContainer margins >= 24 px; the name
## entry is limited to 12 characters; every static Label/Button/RichTextLabel/Label3D text of the UI scenes and every
## Label3D text built by PropKit/Vfx only uses glyphs of ThemeDB.fallback_font.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const FOCUS_FRAMES: int = 900
const SCENE_TITLE: String = "res://scenes/title/title.tscn"
const SCENE_SLOTS: String = "res://scenes/title/slot_select.tscn"
const SCENE_NAME: String = "res://scenes/title/name_entry.tscn"
const SCENE_INTRO: String = "res://scenes/title/intro.tscn"
const SCENE_GAME_OVER: String = "res://scenes/title/game_over.tscn"
const SCENE_CREDITS: String = "res://scenes/title/credits.tscn"
const SCENE_SAFE_ROOM: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_VENDING: String = "res://scenes/safe_room/vending_menu.tscn"
const SCENE_LOOTBOX: String = "res://scenes/safe_room/lootbox_opening.tscn"
const SCENE_PAUSE: String = "res://scenes/ui/pause_menu.tscn"
const SCENE_SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const SCENE_CONFIRM: String = "res://scenes/ui/confirm_dialog.tscn"
const SCENE_LOBBY: String = "res://scenes/ui/event_lobby.tscn"
const SCENE_RESULT: String = "res://scenes/ui/run_result.tscn"
const SCENE_SUMMARY: String = "res://scenes/ui/floor_summary.tscn"
const SCENE_HUD: String = "res://scenes/ui/exploration_hud.tscn"
const SCENE_OVERLAY: String = "res://scenes/ui/show_overlay.tscn"
const SCENE_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const SCENE_TOUCH: String = "res://scenes/ui/touch_controls.tscn"
const SCENE_GLOBAL: String = "res://scenes/ui/global_ui.tscn"
const DAMAGE_STYLES: Array[StringName] = [&"damage", &"crit", &"heal", &"mp", &"miss", &"weak", &"resist", &"status"]
const PAUSE_PAGES: Array[String] = ["party", "inventory", "equipment", "skills", "achievements", "bestiary", "settings"]


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	Game.ensure_state()


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	await _settle_router()


# --- menus: instantiate + default focus + glyphs --------------------------------------------------------------------

func test_title_screen() -> void:
	await _check_menu(SCENE_TITLE)


func test_slot_select() -> void:
	await _check_menu(SCENE_SLOTS)


func test_name_entry() -> void:
	var n: Node = await _check_menu(SCENE_NAME)
	if n == null:
		return
	var edit: LineEdit = n.get("name_edit") as LineEdit
	assert_not_null(edit, "name_entry.name_edit")
	if edit != null:
		assert_eq(edit.max_length, 12, "name_entry max_length")
	for key: Node in n.find_children("*", "Button", true, false):
		var b: Button = key as Button
		if b.text.length() == 1:
			assert_true(b.size.x >= UiTheme.MIN_TOUCH and b.size.y >= UiTheme.MIN_TOUCH,
				"on-screen key '%s' is %s, needs >= %d px" % [b.text, str(b.size), UiTheme.MIN_TOUCH])


func test_intro() -> void:
	await _check_menu(SCENE_INTRO)


func test_game_over() -> void:
	await _check_menu(SCENE_GAME_OVER)


func test_credits() -> void:
	await _check_menu(SCENE_CREDITS)


func test_safe_room() -> void:
	await _check_menu(SCENE_SAFE_ROOM)


func test_vending_menu() -> void:
	await _check_menu(SCENE_VENDING)


func test_lootbox_opening() -> void:
	await _check_menu(SCENE_LOOTBOX)


func test_pause_menu() -> void:
	await _check_menu(SCENE_PAUSE)


func test_settings_menu() -> void:
	await _check_menu(SCENE_SETTINGS)


func test_confirm_dialog() -> void:
	await _check_menu(SCENE_CONFIRM)


func test_event_lobby() -> void:
	await _check_menu(SCENE_LOBBY)


func test_run_result() -> void:
	await _check_menu(SCENE_RESULT)


func test_floor_summary() -> void:
	await _check_menu(SCENE_SUMMARY)


# --- overlays: instantiate, never steal focus, glyphs ----------------------------------------------------------------

func test_overlays_instantiate_without_taking_focus() -> void:
	for path: String in [SCENE_HUD, SCENE_OVERLAY, SCENE_DIALOG, SCENE_TOUCH, SCENE_GLOBAL]:
		var n: Node = _instance(path)
		if n == null:
			continue
		add_to_tree(n)
		await wait_frames(12)
		var owner: Control = tree.root.gui_get_focus_owner()
		assert_true(owner == null or not n.is_ancestor_of(owner), "%s must not take focus" % path)
		assert_eq(_bad_glyphs(n), PackedStringArray(), "%s: glyphs" % path)
		_dispose(n)


# --- pause menu process modes ----------------------------------------------------------------------------------------

func test_pause_menu_and_every_page_run_when_paused() -> void:
	var pm: Node = _instance(SCENE_PAUSE)
	if pm == null:
		return
	add_to_tree(pm)
	await wait_frames(3)
	assert_eq(pm.process_mode, Node.PROCESS_MODE_WHEN_PAUSED, "PauseMenu.process_mode")
	assert_true(tree.paused, "opening the pause menu pauses the tree")
	assert_true(pm.can_process(), "pause menu processes while paused")
	var tab_ids: Array[String] = []
	for t: Dictionary in _const_of(pm, "TABS") as Array:
		tab_ids.append(str(t["id"]))
	assert_eq(tab_ids, PAUSE_PAGES + ["title"] as Array[String], "pause tabs (GDD §14.4)")
	for tab: String in PAUSE_PAGES:
		pm.call("show_tab", tab)
		await wait_frames(2)
		var page: Control = pm.call("page", tab) as Control
		assert_not_null(page, "page '%s' exists" % tab)
		if page == null:
			continue
		assert_eq(page.process_mode, Node.PROCESS_MODE_WHEN_PAUSED, "page '%s' process_mode" % tab)
		assert_true(page.can_process(), "page '%s' processes while paused" % tab)
		assert_true(page.visible, "page '%s' visible after show_tab" % tab)
		assert_eq(_bad_glyphs(page), PackedStringArray(), "page '%s' glyphs" % tab)
	var dlg: Node = pm.call("ask_to_title") as Node
	assert_not_null(dlg, "Zum Titel opens a confirm dialog")
	if dlg != null:
		assert_eq(dlg.process_mode, Node.PROCESS_MODE_WHEN_PAUSED, "confirm dialog from the pause menu")
		await wait_frames(2)
		assert_true(dlg.can_process(), "dialog processes while paused")
		var no_btn: Button = dlg.call("no_button") as Button
		assert_true(no_btn != null and no_btn.has_focus(), "'Weiterspielen' is the default (default_no)")
		dlg.call("answer", false)
		await wait_frames(2)
	assert_true(tree.paused, "declining keeps the game paused")
	pm.call("close")
	await wait_frames(2)
	assert_false(tree.paused, "closing the pause menu unpauses")


func test_pause_menu_tab_from_params_focuses_page() -> void:
	var pm: Node = _instance(SCENE_PAUSE, {"tab": "inventory", "context": "explore"})
	if pm == null:
		return
	add_to_tree(pm)
	var page: Control = null
	var ok: bool = await _wait_focus_in(pm)
	page = pm.call("page", "inventory") as Control
	assert_true(ok, "focus inside the pause menu")
	assert_eq(str(pm.get("current_tab")), "inventory")
	var owner: Control = tree.root.gui_get_focus_owner()
	assert_true(page != null and owner != null and page.is_ancestor_of(owner), "focus starts inside the inventory page")


# --- touch / safe area -------------------------------------------------------------------------------------------------

func test_touch_hit_areas_at_least_88() -> void:
	var t: Node = _instance(SCENE_TOUCH, {"force_visible": true})
	if t == null:
		return
	add_to_tree(t)
	await wait_frames(3)
	assert_true(bool(t.call("is_shown")), "force_visible shows the touch layer")
	var buttons: Dictionary = t.get("buttons")
	assert_eq(buttons.size(), 3, "action, map, pause")
	for a: Variant in [&"action", &"map", &"pause"]:
		assert_true(buttons.has(a), "touch button %s" % str(a))
	var rects: Array[Rect2] = []
	for a2: Variant in buttons.keys():
		var b: Button = buttons[a2] as Button
		var r: Rect2 = b.get_global_rect()
		rects.append(r)
		assert_true(r.size.x >= UiTheme.TOUCH_HIT and r.size.y >= UiTheme.TOUCH_HIT,
			"%s hit area %s >= %d" % [str(a2), str(r.size), UiTheme.TOUCH_HIT])
		var visual: Control = b.get_node_or_null("HitVisual") as Control
		assert_not_null(visual, "%s has a visible part" % str(a2))
		if visual != null:
			assert_true(visual.size.x >= UiTheme.MIN_TOUCH - 0.5, "%s visible >= %d" % [str(a2), UiTheme.MIN_TOUCH])
		assert_eq(b.focus_mode, Control.FOCUS_NONE, "touch buttons never take focus")
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var gap: float = maxf(maxf(rects[j].position.x - rects[i].end.x, rects[i].position.x - rects[j].end.x),
				maxf(rects[j].position.y - rects[i].end.y, rects[i].position.y - rects[j].end.y))
			assert_true(gap >= 12.0 - 0.01, "hit areas %d/%d are %.1f px apart (>= 12)" % [i, j, gap])
	var joy: Node = t.get("joystick") as Node
	assert_not_null(joy, "virtual joystick")
	if joy != null:
		assert_eq(int(_const_of(joy, "RADIUS")), 90, "joystick radius 90")
		assert_almost(float(_const_of(joy, "DEADZONE")), 0.15, 0.0001, "deadzone 0.15")
		assert_almost(float(_const_of(joy, "SNEAK_MAX")), 0.6, 0.0001, "sneak up to 0.6 deflection")


func test_touch_layer_visibility_follows_settings() -> void:
	var saved: StringName = Game.settings.touch_controls
	var t: Node = _instance(SCENE_TOUCH, {})
	if t == null:
		return
	add_to_tree(t)
	await wait_frames(2)
	Game.settings.touch_controls = &"off"
	Events.settings_changed.emit()
	assert_false(bool(t.call("is_shown")), "off hides")
	Game.settings.touch_controls = &"on"
	Events.settings_changed.emit()
	assert_true(bool(t.call("is_shown")), "on shows")
	Game.settings.touch_controls = saved
	Events.settings_changed.emit()


func test_safe_area_margins_at_least_24() -> void:
	var probe: SafeAreaContainer = SafeAreaContainer.new()
	probe.extra = -50
	add_to_tree(probe)
	await wait_frames(1)
	for side: String in ["left", "top", "right", "bottom"]:
		assert_true(int(probe.compute_margins()[side]) >= 24, "compute_margins %s >= 24" % side)
		assert_true(probe.get_theme_constant("margin_" + side) >= 24, "margin_%s >= 24" % side)
	# Every SafeAreaContainer inside the UI scenes.
	for path: String in [SCENE_HUD, SCENE_OVERLAY, SCENE_DIALOG, SCENE_PAUSE, SCENE_VENDING, SCENE_LOOTBOX, SCENE_TITLE,
			SCENE_LOBBY, SCENE_SUMMARY]:
		var n: Node = _instance(path)
		if n == null:
			continue
		add_to_tree(n)
		await wait_frames(2)
		var found: int = 0
		for c: Node in n.find_children("*", "MarginContainer", true, false):
			if c is SafeAreaContainer:
				found += 1
				for side2: String in ["left", "top", "right", "bottom"]:
					assert_true((c as SafeAreaContainer).get_theme_constant("margin_" + side2) >= 24,
						"%s: %s margin_%s >= 24" % [path.get_file(), c.name, side2])
		assert_gt(found, 0, "%s uses a SafeAreaContainer root" % path.get_file())
		_dispose(n)
		tree.paused = false


# --- glyphs of 3D labels ------------------------------------------------------------------------------------------------

func test_label3d_texts_of_propkit_and_vfx_use_available_glyphs() -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "GlyphProbe"
	add_to_tree(holder)
	for id: String in PropKit.IDS:
		var p: Node3D = PropKit.build(StringName(id), 1)
		if p != null:
			if p.get_parent() == null:
				holder.add_child(p)
	for k: StringName in Vfx.KINDS:
		Vfx.spawn(k, holder, Vector3.ZERO)          # pooled under `holder`; callers never free it (§8.6)
	for style: StringName in DAMAGE_STYLES:
		Vfx.damage_number(holder, Vector3.ZERO, "1.234", style)
	await wait_frames(1)
	assert_eq(_bad_glyphs(holder), PackedStringArray(), "Label3D texts of PropKit / Vfx")


func test_glyph_helpers() -> void:
	assert_eq(UiUtil.missing_glyphs("Grüße – „Lootbox“ … 12 € × 3 %!"), "", "umlauts, quotes, dash, euro, times")
	var unsafe: String = "LIVE " + String.chr(0x25CF) + " " + String.chr(0x2665) + " " + String.chr(0x2192)
	assert_ne(UiUtil.missing_glyphs(unsafe), "", "● ♥ → are missing in the fallback font")
	assert_eq(UiUtil.missing_glyphs(UiUtil.glyph_safe(unsafe)), "", "glyph_safe replaces every missing glyph")


# --- helpers -------------------------------------------------------------------------------------------------------------

func _instance(path: String, params: Dictionary = {"capture": true}) -> Node:
	assert_true(ResourceLoader.exists(path), "%s exists" % path)
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path) as PackedScene
	assert_not_null(packed, "%s is a scene" % path)
	if packed == null:
		return null
	var n: Node = packed.instantiate()
	assert_not_null(n, "%s instantiates" % path)
	if n != null and n.has_method("setup"):
		n.call("setup", params)
	return n


## Instantiates with {"capture": true}, waits for a focused control inside the scene, checks the glyphs.
func _check_menu(path: String) -> Node:
	var n: Node = _instance(path)
	if n == null:
		return null
	add_to_tree(n)
	var ok: bool = await _wait_focus_in(n)
	assert_true(ok, "%s: a control inside the scene has focus after _ready (§10.2)" % path.get_file())
	if ok:
		var owner: Control = tree.root.gui_get_focus_owner()
		assert_true(owner.focus_mode != Control.FOCUS_NONE, "%s: focus owner is focusable" % path.get_file())
		assert_true(owner.is_visible_in_tree(), "%s: focus owner %s is visible" % [path.get_file(), owner.name])
	assert_eq(_bad_glyphs(n), PackedStringArray(), "%s: texts use available glyphs (F8)" % path.get_file())
	return n


func _wait_focus_in(n: Node) -> bool:
	for i in FOCUS_FRAMES:
		if not is_instance_valid(n):
			return false
		var owner: Control = tree.root.gui_get_focus_owner()
		if owner != null and n.is_ancestor_of(owner):
			return true
		await tree.process_frame
	return false


## "<node>: '<text>' (<missing>)" for every text with glyphs the fallback font lacks.
func _bad_glyphs(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	var font: Font = ThemeDB.fallback_font
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		elif n is RichTextLabel:
			text = (n as RichTextLabel).get_parsed_text()
		elif n is LineEdit:
			text = (n as LineEdit).text + (n as LineEdit).placeholder_text
		elif n is Label3D:
			text = (n as Label3D).text
		var missing: String = ""
		for i in text.length():
			var code: int = text.unicode_at(i)
			if code >= 32 and not font.has_char(code) and not missing.contains(text[i]):
				missing += text[i]
		if missing != "":
			out.append("%s: '%s' (%s)" % [n.name, text, missing])
	return out


func _dispose(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	var was_current: bool = Router.current == n
	_nodes.erase(n)
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()
	if was_current or not is_instance_valid(Router.current):
		Router.adopt(null)


func _const_of(n: Object, const_name: String) -> Variant:
	var script: Script = n.get_script() as Script
	return script.get_script_constant_map().get(const_name) if script != null else null


## Lets a transition started by a screen finish, frees screens the Router created, leaves the Router empty.
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
