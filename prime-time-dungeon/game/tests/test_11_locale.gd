extends TestCase
## 11-L1 (11 §1.9, §1.12; SP-3, SP-5): the language of a run — the setting (auto / de / en with the system language
## simulated), --lang, German for ephemeral runs, a pack narrowing the choice; apply() swaps ONE catalog in at the
## TranslationServer and Tx (tr() keeps working), a pack PO over the base PO, German without PO files; the boot order (a
## child Godot with --lang=en: the language stands in the main loop's first callback, before any scene); the automatic
## translation is off everywhere (SP-3 — the [zu prüfen] of windows and popups, measured here on 4.7.2); the settings
## key and the options row "Sprache / Language" (changeable on the title only; a switch rebuilds the title).

const FIX: String = "res://tests/fixtures/locale"
const BOOT_PROBE: String = "res://tests/fixtures/locale/boot_probe.gd"
const SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const TITLE: String = "res://scenes/title/title.tscn"
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const CHILD_TIMEOUT_MS: int = 90000

var _lang_was: String = "de"
var _setting_was: String = "auto"
var _pack_was: PackDef = null


func before_each() -> void:
	_lang_was = Tx.lang()
	_setting_was = Game.settings.language
	_pack_was = DB.pack


func after_each() -> void:
	DB.pack = _pack_was
	Game.settings.language = _setting_was
	LocaleLoader.apply(_lang_was)                  # German again for every following test
	tree.paused = false


# --- the choice (11 §1.9) ---------------------------------------------------------------------------------------------

func test_resolve_setting_os_args_and_pack() -> void:
	var none: PackedStringArray = []
	assert_eq(LocaleLoader.codes(), PackedStringArray(["de", "en"]), "locale/languages.json")
	assert_eq(LocaleLoader.setting_values(), PackedStringArray(["auto", "de", "en"]))
	assert_eq([LocaleLoader.source_lang(), LocaleLoader.language_name("de"), LocaleLoader.language_name("en")],
		["de", "Deutsch", "English"])
	assert_eq(LocaleLoader.resolve("auto", none, false, "de"), "de", "Automatisch on a German system: German")
	assert_eq(LocaleLoader.resolve("auto", none, false, "fr"), "en", "any other system language: English")
	assert_eq(LocaleLoader.resolve("auto", none, false, "en"), "en")
	assert_eq(LocaleLoader.resolve("de", none, false, "en"), "de", "an explicit setting wins over the system")
	assert_eq(LocaleLoader.resolve("en", none, false, "de"), "en")
	assert_eq(LocaleLoader.resolve("xx", none, false, "de"), "de", "an unknown setting reads as auto")
	assert_eq(LocaleLoader.resolve("en", none, true, "en"), "de", "ephemeral runs (tests, capture) play German")
	assert_eq(LocaleLoader.resolve("auto", PackedStringArray(["--lang=en"]), true, "de"), "en", "--lang wins")
	assert_eq(LocaleLoader.resolve("en", PackedStringArray(["--seed=3", "--lang=de"]), false, "en"), "de")
	assert_eq(LocaleLoader.resolve("auto", PackedStringArray(["--lang=EN"]), true, "de"), "en", "case-insensitive")
	assert_eq(LocaleLoader.arg_language(PackedStringArray(["--autoplay", "--lang=en"])), "en")
	assert_eq(LocaleLoader.arg_language(none), "")
	assert_eq(LocaleLoader.resolve("de", none, false, "de", PackedStringArray(["en"]), "en"), "en",
		"a pack narrows the languages (11 §3.6): outside them its default_lang")
	assert_eq(LocaleLoader.resolve("auto", none, false, "fr", PackedStringArray(["de"]), ""), "de",
		"without a default_lang: the first allowed language")
	assert_eq(LocaleLoader.resolve("en", none, false, "de", PackedStringArray(["de", "en"]), "de"), "en")


func test_unknown_lang_argument_stays_german() -> void:
	assert_eq(LocaleLoader.resolve("auto", PackedStringArray(["--lang=xx"]), true, "de"), "de", "(a warning)")
	assert_eq(str(LocaleLoader.apply("xx").get("lang")), "de")
	assert_eq(Tx.lang(), "de")


# --- apply: one catalog, registered (11 §1.2) -------------------------------------------------------------------------

func test_apply_registers_one_catalog() -> void:
	var res: Dictionary = LocaleLoader.apply("en", "", FIX + "/root")
	assert_eq([res["lang"], Tx.lang(), TranslationServer.get_locale()], ["en", "en", "en"])
	LocaleLoader.apply("en", "", FIX + "/root")
	assert_eq(TranslationServer.find_translations("en", true).size(), 1, "applied twice: still ONE catalog")
	assert_eq([Tx.t("Gift"), Tx.t("Gift", "items"), Tx.data("statuses", "sts_taunt", "Provoziert"),
		Tx.data("statuses", "sts_taunted", "Provoziert"), Tx.t("Neuer Text"), Tx.t("Unbekannt")],
		["Poison", "Poison flask", "Taunting", "Taunted", "Neuer Text", "Unbekannt"],
		"msgstr, contexts, homonyms; fuzzy and unknown: the msgid")
	assert_eq([Tx.n("{count} Kampf", "{count} Kämpfe", 1), Tx.n("{count} Kampf", "{count} Kämpfe", 2),
		Tx.n("{count} Truhe", "{count} Truhen", 2), Tx.n("{count} Truhe", "{count} Truhen", 1)],
		["{count} fight", "{count} fights", "{count} Truhen", "{count} chest"], "Tx picks the plural form itself")
	assert_eq([TranslationServer.translate("Gift"), TranslationServer.translate("Provoziert", "statuses:sts_taunted"),
		UiUtil.tr_text("Gift"), RefCounted.new().tr("Gift")], ["Poison", "Taunted", "Poison", "Poison"],
		"tr(), tr_text() and TranslationServer.translate() keep working while L2 moves the code to Tx")
	assert_eq([Tx.fmt_int(12345), UiUtil.fmt_int(12345)], ["12,345", "12,345"], "English formats")
	var pack: Dictionary = LocaleLoader.apply("en", FIX + "/pack", FIX + "/root")
	assert_eq([Tx.t("Gift"), Tx.t("Testbild"), Tx.t("Gift", "items")], ["Venom", "Test Card", "Poison flask"],
		"the pack PO over the base PO (11 §3.6)")
	assert_eq((pack["files"] as PackedStringArray).size(), 5)
	LocaleLoader.apply("de")
	assert_eq([Tx.lang(), Tx.t("Gift"), TranslationServer.translate("Gift"), Tx.fmt_int(12345)],
		["de", "Gift", "Gift", "12.345"], "back to German: no catalog left behind")
	assert_eq(TranslationServer.find_translations("en", true).size(), 0)
	LocaleLoader.apply("de", FIX + "/pack")
	assert_eq([Tx.t("Graf Mopsula"), Tx.t("Gift")], ["Graf Testbild", "Gift"], "a pack's de.po in German")


func test_missing_po_files_stay_german() -> void:
	var res: Dictionary = LocaleLoader.apply("en", "", FIX + "/nowhere")
	assert_eq([res["lang"], Tx.lang(), Tx.fmt_int(1000)], ["de", "de", "1.000"], "no PO file: German (a warning)")


func test_real_english_po_files_exist_and_load() -> void:
	var res: Dictionary = LocaleLoader.apply("en")
	assert_eq(res["lang"], "en")
	assert_eq(res["missing"], PackedStringArray(), "locale/en/{ui,data,mod_lines,stempel}.po")
	assert_eq(res["errors"], PackedStringArray(), "they parse")
	assert_eq(Tx.lang(), "en")


# --- the active content pack (11 §3.6; 11-P1: DB.pack) ---------------------------------------------------------------

func test_pack_hook_reads_the_pack_def() -> void:
	assert_eq([LocaleLoader.pack_dir(null), LocaleLoader.pack_languages(null), LocaleLoader.pack_default_lang(null)],
		["", PackedStringArray(), ""], "no pack: the base game")
	var p: PackDef = PackLoader.read("res://packs", "testbild")
	assert_eq([LocaleLoader.pack_dir(p), LocaleLoader.pack_languages(p), LocaleLoader.pack_default_lang(p)],
		["res://packs/testbild", PackedStringArray(["de", "en"]), "de"], "PackDef.root and pack.json's fields")
	assert_eq(LocaleLoader.setting_values(p.languages), PackedStringArray(["auto", "de", "en"]))
	assert_eq(LocaleLoader.setting_values(PackedStringArray(["de"])), PackedStringArray(["auto", "de"]),
		"a German-only pack: the row offers Automatisch and Deutsch")
	assert_eq(DB.pack, null, "the test run plays the base game")
	assert_eq(Game.apply_language(), "de", "Game.apply_language without a pack: German (ephemeral)")


func test_the_row_shows_only_the_languages_of_the_pack() -> void:
	var p: PackDef = PackDef.new()
	p.id = "only_de"
	p.languages = PackedStringArray(["de"])
	DB.pack = p
	var sm: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	sm.call("setup", {"framed": true, "language": true})
	add_to_tree(sm)
	await wait_frames(2)
	var c: Button = (sm.get("rows") as Dictionary)["language"] as Button
	assert_eq(c.get("options"), PackedStringArray(["Automatisch", "Deutsch"]), "pack.json → languages (11 §3.6)")
	sm.queue_free()


# --- the boot order (11 §1.9) -----------------------------------------------------------------------------------------

func test_the_language_stands_before_the_first_screen() -> void:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", BOOT_PROBE,
		"--", "--lang=en"]
	var proc: Dictionary = OS.execute_with_pipe(OS.get_executable_path(), args)
	if proc.is_empty():
		fail("cannot start a child Godot process")
		return
	var pid: int = int(proc["pid"])
	var deadline: int = Time.get_ticks_msec() + CHILD_TIMEOUT_MS
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
		fail("the child did not finish within %d ms" % CHILD_TIMEOUT_MS)
		return
	var out: String = (proc["stdio"] as FileAccess).get_as_text()
	(proc["stderr"] as FileAccess).get_as_text()
	assert_eq(OS.get_process_exit_code(pid), 0)
	assert_has(out, "BOOT_LANG: game=true tx=en locale=en root_auto=%d" % Node.AUTO_TRANSLATE_MODE_DISABLED,
		"Game._init applied --lang=en before the first callback; the root translates nothing automatically")
	assert_has(out, "BOOT_LANG_READY: root_auto=%d" % Node.AUTO_TRANSLATE_MODE_DISABLED)


# --- SP-3: no automatic translation anywhere --------------------------------------------------------------------------

func test_automatic_translation_is_off_in_every_window() -> void:
	assert_false(bool(ProjectSettings.get_setting("internationalization/rendering/root_node_auto_translate", true)),
		"project.godot: the root starts with automatic translation off")
	assert_eq(tree.root.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "Game._ready keeps it off")
	LocaleLoader.apply("en", "", FIX + "/root")      # "Gift" → "Poison": an English "Gift" must stay "Gift"
	var host: Control = Control.new()
	add_to_tree(host)
	var layer: CanvasLayer = CanvasLayer.new()
	host.add_child(layer)
	var in_layer: Label = Label.new()
	layer.add_child(in_layer)
	var svc: SubViewportContainer = SubViewportContainer.new()
	host.add_child(svc)
	var sv: SubViewport = SubViewport.new()
	svc.add_child(sv)
	var in_viewport: Label = Label.new()
	sv.add_child(in_viewport)
	var win: Window = Window.new()
	win.visible = false
	host.add_child(win)
	var in_window: Label = Label.new()
	win.add_child(in_window)
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.dialog_text = "Gift"
	host.add_child(dialog)
	var option: OptionButton = OptionButton.new()
	option.add_item("Gift")
	host.add_child(option)
	var popup_panel: PopupPanel = PopupPanel.new()
	host.add_child(popup_panel)
	var in_popup: Label = Label.new()
	popup_panel.add_child(in_popup)
	var tabs: TabContainer = TabContainer.new()
	host.add_child(tabs)
	var outside: Button = Button.new()               # text set before it enters the tree
	outside.text = "Gift"
	host.add_child(outside)
	await wait_frames(2)
	var nodes: Dictionary = {"label in a CanvasLayer": in_layer, "label in a SubViewport": in_viewport,
		"Window": win, "label in a Window": in_window, "AcceptDialog": dialog, "its label": dialog.get_label(),
		"its OK button": dialog.get_ok_button(), "OptionButton": option, "its PopupMenu": option.get_popup(),
		"PopupPanel (the tooltip's kind of window)": popup_panel, "label in it": in_popup,
		"TabContainer's TabBar": tabs.get_tab_bar(), "a button filled outside the tree": outside}
	for k: String in nodes:
		var n: Node = nodes[k]
		assert_false(n.can_auto_translate(), k + ": inherits the root's DISABLED")
		assert_eq(n.atr("Gift"), "Gift", k + ": no second translation")
	var ref: Button = Button.new()
	ref.text = "Gift"
	host.add_child(ref)
	await wait_frames(1)
	assert_eq(outside.get_minimum_size(), ref.get_minimum_size(), "the drawn text is the msgid, not 'Poison'")
	assert_eq(option.get_popup().get_item_auto_translate_mode(0), Node.AUTO_TRANSLATE_MODE_INHERIT)


# --- the setting and the options row ----------------------------------------------------------------------------------

func test_settings_key_round_trip() -> void:
	var s: GameSettings = GameSettings.new()
	s.ephemeral = true
	assert_eq(s.language, "auto", "default: Automatisch")
	assert_true(s.to_dict().has("language"))
	assert_eq(GameSettings.FILE_VERSION, 2, "a missing key reads as auto; the file version stays")
	var path: String = GameSettings.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: String = FileAccess.get_file_as_string(path) if had else ""
	var w: GameSettings = GameSettings.new()
	w.ephemeral = false
	w.language = "en"
	assert_eq(w.save_to_disk(), OK)
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(path), OK)
	assert_eq(str(cfg.get_value("game", "language", "")), "en", "[game] language")
	var r: GameSettings = GameSettings.new()
	r.ephemeral = false
	r.load_from_disk()
	assert_eq(r.language, "en")
	cfg.set_value("game", "language", "klingonisch")
	cfg.save(path)
	r.load_from_disk()
	assert_eq(r.language, "auto", "an unknown value reads as auto")
	cfg.erase_section_key("game", "language")
	cfg.save(path)
	var fresh: GameSettings = GameSettings.new()
	fresh.ephemeral = false
	fresh.load_from_disk()
	assert_eq(fresh.language, "auto", "a file without the key (before 11-L1): auto")
	if had:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(path)


func test_the_row_is_locked_outside_the_title() -> void:
	var sm: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	sm.call("setup", {"framed": true})
	add_to_tree(sm)
	await wait_frames(2)
	var c: Button = (sm.get("rows") as Dictionary)["language"] as Button
	assert_true(c.disabled, "the pause menu and every other host: locked")
	assert_eq(c.text, "Automatisch", "the value without the cycle arrows")
	var row: Node = c.get_parent()
	assert_eq(_texts(row), PackedStringArray(["Sprache / Language", "Im Titelmenü änderbar"]),
		"the bilingual label and the hint")
	c.call("step", 1)
	assert_eq(Game.settings.language, "auto", "a locked row does not change")


func test_the_title_row_switches_and_rebuilds() -> void:
	var sm: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	sm.call("setup", {"framed": true, "language": true})
	add_to_tree(sm)
	await wait_frames(2)
	var c: Button = (sm.get("rows") as Dictionary)["language"] as Button
	assert_false(c.disabled, "the title's options: changeable")
	assert_eq(c.get("options"), PackedStringArray(["Automatisch", "Deutsch", "English"]), "own names (languages.json)")
	assert_eq(_texts(c.get_parent()), PackedStringArray(["Sprache / Language"]), "no hint on the title")
	var got: Array[String] = []
	sm.connect("language_changed", func(code: String) -> void: got.append(code))
	c.call("step", 1)
	assert_eq([Game.settings.language, Tx.lang(), got], ["de", "de", [] as Array[String]],
		"Deutsch: the run already plays German — no rebuild")
	c.call("step", 1)
	assert_eq([Game.settings.language, Tx.lang(), got], ["en", "en", ["en"] as Array[String]],
		"English: applied (setting wins over the ephemeral default) and announced")
	sm.queue_free()


func test_a_switch_on_the_title_rebuilds_it_and_reopens_the_options() -> void:
	var t: Node = (load(TITLE) as PackedScene).instantiate()
	add_to_tree(t)
	await wait_frames(3)
	t.call("activate", "options")
	await wait_frames(3)
	var menu: Node = _settings_in(t)
	assert_not_null(menu, "the options open over the title")
	if menu == null:
		return
	var c: Button = (menu.get("rows") as Dictionary)["language"] as Button
	assert_false(c.disabled, "the title passes language: true")
	var first_id: int = t.get_instance_id()
	c.call("step", 2)                                 # Automatisch → English
	assert_eq(Tx.lang(), "en")
	var ok: bool = await wait_until(func() -> bool:
		return Router.current != null and is_instance_valid(Router.current) \
			and Router.current.get_instance_id() != first_id and Router.current.scene_file_path == TITLE \
			and not Router.busy, 1500)
	assert_true(ok, "Router.goto(SCENE_TITLE): the title rebuilt itself")
	if not ok:
		return
	await wait_frames(3)
	var t2: Node = Router.current
	var menu2: Node = _settings_in(t2)
	assert_not_null(menu2, "the options are open again")
	if menu2 != null:
		var row: Control = (menu2.get("rows") as Dictionary)["language"] as Control
		assert_eq(tree.root.gui_get_focus_owner(), row, "on the language row")
		assert_eq((row as Button).text, "‹  English  ›")
	t2.queue_free()
	await wait_frames(2)


func _settings_in(host: Node) -> Node:
	for n: Node in host.find_children("*", "Control", true, false):
		if n.has_signal("language_changed") and n.get("rows") != null:
			return n
	return null


static func _texts(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


## 11 §5.4 Nr. 6 [zu prüfen] — measured on 4.7.2 (an --export-pack of the Linux preset): with export_filter
## "all_resources" Godot exports locale/*.json (JSON resources) and locale/<lang>/*.po (Translation resources of its
## own PO loader) as the original text files, readable with FileAccess; the .pot templates (no resource type) stay out.
## So the presets need no include_filter for locale/ — this test keeps that true.
func test_the_exports_carry_the_locale_files() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	var presets: int = 0
	for section: String in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		presets += 1
		var name: String = str(cfg.get_value(section, "name", section))
		var exported: bool = str(cfg.get_value(section, "export_filter", "")) == "all_resources" \
			or str(cfg.get_value(section, "include_filter", "")).contains("locale/")
		assert_true(exported, name + ": locale/*.json and locale/*.po reach the build")
		assert_false(str(cfg.get_value(section, "exclude_filter", "")).contains("locale"), name + ": not excluded")
	assert_gt(presets, 0)
	assert_eq(ResourceLoader.get_recognized_extensions_for_type("Translation").has("po"), true,
		"the engine knows .po as a resource (that is why all_resources exports it)")
	assert_eq(ResourceLoader.get_recognized_extensions_for_type("Translation").has("pot"), false,
		"the templates are no resources: they stay out of the builds")
