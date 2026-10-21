extends TestCase
## 09 ST1-A (Kap. 1.2 Nr. 6): the language rule over every text a player can read — "Etage" for a floor, "Stufe" for
## the level of a figure or an enemy (in tight spots the bare number in the round level plaque, scenes/ui/
## level_badge.gd, tooltip "Stufe 12"), "Kandidat:in" for a participant: never "Level", "Lv" or "Ebene", never
## "Crawler" (plurals and capitals included). Scanned: the string literals of every script under res://scenes,
## res://art, res://autoload and res://core (code and comments are not text), the text properties of every scene file
## and every string value of every data file under res://data (data/stempel too — the M.O.D. lines are data). The
## patterns are case-sensitive whole words, so keys and placeholders ("level", {level}) never match. A script line
## that has to keep such a word carries the comment `# terms-ok: <reason>` (a debug overlay, say). The docs are not
## scanned: they quote the idea of 2026-10-11 word for word. The tiers of the Unterhosen-Liga read "Liga 1" / "Duo-Liga"
## (09 §1.2 Nr. 3), never "Stufe 1 / Stufe 2".
##
## PENDING: findings in files no 09 package may touch (09 §11.4: core/rt/**, scenes/combat/**) — the exact number per
## file, each waiting for its change request to 07; the list only shrinks (a fixed file must leave it). Empty since
## CR-32 (i): the combat HUD says "Stufe" too (plaques in the frames and the credits, "NEUE STUFE!").

const LevelBadge := preload("res://scenes/ui/level_badge.gd")
const BetsMenu := preload("res://scenes/ui/bets_menu.gd")
const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const RESULTS: String = "res://scenes/combat/ui/combat_results.gd"

## Whole words, case-sensitive (09 §1.2 Nr. 6, plus plurals, capitals and "Lvl").
const PATTERN: String = "\\b(Level|Levels|LEVEL|LEVELS|Lv|LV|Lvl|LVL|Ebene|Ebenen|EBENE|Crawler|Crawlern|Crawlers" \
	+ "|CRAWLER)\\b"
const OK_MARK: String = "terms-ok:"
const SCRIPT_ROOTS: PackedStringArray = ["res://scenes", "res://art", "res://autoload", "res://core"]
const SCENE_ROOTS: PackedStringArray = ["res://scenes", "res://art"]
const DATA_ROOT: String = "res://data"
## Text properties of .tscn / .tres files.
const SCENE_TEXT_PROPS: PackedStringArray = ["text", "tooltip_text", "placeholder_text", "title", "dialog_text"]
## file → [findings, change request]: texts in files 09 must not touch (09 §11.4), each with its open change request.
const PENDING: Dictionary = {}

var _re: RegEx = null


func _pattern() -> RegEx:
	if _re == null:
		_re = RegEx.create_from_string(PATTERN)
	return _re


## The forbidden words in `text` (whole words, in order).
func words_in(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for m: RegExMatch in _pattern().search_all(text):
		out.append(m.get_string(1))
	return out


## The string literals of a GDScript source: [{"line": int (where it starts), "text": String, "ok": bool (the line
## carries `# terms-ok:`)}]. Comments are skipped, code is ignored; triple-quoted strings may span lines.
static func literals(source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lines: PackedStringArray = source.split("\n")
	var ok_lines: Dictionary = {}
	var open: Dictionary = {}                 # a triple-quoted string still open: {"q", "line", "text"}
	for n in lines.size():
		var line: String = lines[n]
		var i: int = 0
		var chars: int = line.length()
		while i < chars:
			if not open.is_empty():
				var end: int = line.find(str(open["q"]), i)
				if end < 0:
					open["text"] = str(open["text"]) + line.substr(i)
					i = chars
					continue
				out.append({"line": int(open["line"]), "text": str(open["text"]) + line.substr(i, end - i)})
				open = {}
				i = end + 3
				continue
			var ch: String = line[i]
			if ch == "#":
				if line.substr(i).contains(OK_MARK):
					ok_lines[n + 1] = true
				break
			if ch != "\"" and ch != "'":
				i += 1
				continue
			if line.substr(i, 3) == ch.repeat(3):
				open = {"q": ch.repeat(3), "line": n + 1, "text": ""}
				i += 3
				continue
			var j: int = i + 1
			while j < chars and line[j] != ch:
				j += 2 if line[j] == "\\" else 1
			out.append({"line": n + 1, "text": line.substr(i + 1, mini(j, chars) - i - 1)})
			i = j + 1
		if not open.is_empty():
			open["text"] = str(open["text"]) + "\n"     # the triple-quoted string goes on in the next line
	for e: Dictionary in out:
		e["ok"] = ok_lines.has(int(e["line"]))
	return out


## "file:line: word — text" for every forbidden word in the string literals of a script (lines with terms-ok excepted).
func script_findings(path: String, source: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if _pattern().search(source) == null:        # no forbidden word anywhere in the file: nothing to parse
		return out
	for e: Dictionary in literals(source):
		var found: PackedStringArray = words_in(str(e["text"]))
		if not found.is_empty() and not bool(e["ok"]):
			out.append("%s:%d: %s — \"%s\"" % [path, int(e["line"]), ", ".join(found), str(e["text"])])
	return out


## "file:line: word — text" for the text properties of a scene file.
func scene_findings(path: String, source: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if _pattern().search(source) == null:
		return out
	var lines: PackedStringArray = source.split("\n")
	for n in lines.size():
		for prop: String in SCENE_TEXT_PROPS:
			if lines[n].begins_with(prop + " = \""):
				var found: PackedStringArray = words_in(lines[n].substr(prop.length() + 3))
				if not found.is_empty():
					out.append("%s:%d: %s — %s" % [path, n + 1, ", ".join(found), lines[n].strip_edges()])
	return out


## "file → json path: word — text" for every string value (any depth) of a parsed data file.
func data_findings(path: String, value: Variant, at: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	if value is Dictionary:
		for k: Variant in (value as Dictionary).keys():
			out.append_array(data_findings(path, (value as Dictionary)[k], at + "." + str(k)))
	elif value is Array:
		for i in (value as Array).size():
			out.append_array(data_findings(path, (value as Array)[i], "%s[%d]" % [at, i]))
	elif value is String:
		var found: PackedStringArray = words_in(str(value))
		if not found.is_empty():
			out.append("%s %s: %s — \"%s\"" % [path, at, ", ".join(found), str(value)])
	return out


static func files_under(root: String, ext: String) -> PackedStringArray:
	var out: PackedStringArray = []
	_collect(root, ext, out)
	out.sort()
	return out


static func _collect(dir_path: String, ext: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_collect(dir_path.path_join(sub), ext, out)
	for f: String in d.get_files():
		if f.ends_with(ext):
			out.append(dir_path.path_join(f))


# --- the scanner ------------------------------------------------------------------------------------------------------

func test_patterns_are_whole_words_and_case_sensitive() -> void:
	for s: String in ["Level 3", "ab Lv 7", "LV 12", "LEVEL UP!", "Level-Up", "Ebene 2", "Akzent-Ebene", "Crawler",
			"die Crawlern", "Lvl 3"]:
		assert_false(words_in(s).is_empty(), s)
	for s: String in ["level", "{level}", "level_up", "Levelauswahl", "Stufe 3", "Etage 3", "Kandidat:innen",
			"Dungeon Crawling", "Lvov", "Ebenenwahl"]:
		assert_eq(words_in(s), PackedStringArray(), s)


func test_the_scanner_reads_literals_not_code_or_comments() -> void:
	var src: String = "\n".join(PackedStringArray([
		"var level: int = 3  # Level of the unit (a comment)",
		"var a: String = \"Level %d\" % level",
		"var b: String = 'Lv %d' % level  # terms-ok: debug overlay",
		"var c: String = \"esc \\\"Ebene\\\" inside\"",
		"var d: String = \"\"\"",
		"Crawler in a triple-quoted text",
		"\"\"\"",
		"var e: String = \"#hash is text\" # Crawler in a comment",
	]))
	var lits: Array[Dictionary] = literals(src)
	var texts: PackedStringArray = []
	for e: Dictionary in lits:
		texts.append(str(e["text"]))
	assert_eq(texts, PackedStringArray(["Level %d", "Lv %d", "esc \\\"Ebene\\\" inside",
		"\nCrawler in a triple-quoted text\n", "#hash is text"]))
	var found: PackedStringArray = script_findings("x.gd", src)
	assert_eq(found.size(), 3, "Level (line 2), Ebene (line 4), Crawler (line 5); line 3 is excepted:\n"
		+ "\n".join(found))
	assert_true(found[0].begins_with("x.gd:2: Level"), found[0])
	assert_true(found[1].begins_with("x.gd:4: Ebene"), found[1])
	assert_true(found[2].begins_with("x.gd:5: Crawler"), found[2])


# --- the project ------------------------------------------------------------------------------------------------------

func test_scripts_say_etage_stufe_and_kandidatin() -> void:
	var problems: PackedStringArray = []
	var scanned: int = 0
	for root: String in SCRIPT_ROOTS:
		for path: String in files_under(root, ".gd"):
			scanned += 1
			var found: PackedStringArray = script_findings(path, FileAccess.get_file_as_string(path))
			if PENDING.has(path):
				continue                              # counted in test_pending_change_requests_stay_exact
			problems.append_array(found)
	assert_gt(scanned, 250, "the scripts of scenes / art / autoload / core were scanned")
	assert_eq(problems, PackedStringArray(), "09 §1.2: \"Etage\", \"Stufe\", \"Kandidat:in\" — found:\n"
		+ "\n".join(problems))


func test_scene_files_say_etage_stufe_and_kandidatin() -> void:
	var problems: PackedStringArray = []
	var scanned: int = 0
	for root: String in SCENE_ROOTS:
		for ext: String in [".tscn", ".tres"]:
			for path: String in files_under(root, ext):
				scanned += 1
				problems.append_array(scene_findings(path, FileAccess.get_file_as_string(path)))
	assert_gt(scanned, 10, "scene files scanned")
	assert_eq(problems, PackedStringArray(), "\n".join(problems))


func test_data_texts_say_etage_stufe_and_kandidatin() -> void:
	var problems: PackedStringArray = []
	var files: PackedStringArray = files_under(DATA_ROOT, ".json")
	var stempel: int = 0
	for path: String in files:
		stempel += 1 if path.begins_with(DATA_ROOT + "/stempel/") else 0
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_not_null(parsed, path + " parses")
		problems.append_array(data_findings(path, parsed))
	assert_gt(files.size(), 25, "every data file (GameData.TABLES and the rest)")
	assert_gt(stempel, 3, "the Stempelduell data too (data/stempel)")
	assert_eq(problems, PackedStringArray(), "09 §1.2 — M.O.D. lines, names and descriptions:\n" + "\n".join(problems))


func test_pending_change_requests_stay_exact() -> void:
	for path: String in PENDING.keys():
		var want: int = int((PENDING[path] as Array)[0])
		assert_true(FileAccess.file_exists(path), path)
		var found: PackedStringArray = script_findings(path, FileAccess.get_file_as_string(path))
		assert_true(path.begins_with("res://scenes/combat/") or path.begins_with("res://core/rt/"),
			path + ": only files 09 must not touch (09 §11.4) may wait for a change request")
		assert_eq(found.size(), want, "%s (%s): %d findings expected — fewer: the change request is done, take the "
			% [path, str((PENDING[path] as Array)[1]), want] + "entry out; more: a new text breaks the rule:\n"
			+ "\n".join(found))


# --- the fixed texts --------------------------------------------------------------------------------------------------

func test_level_plaque() -> void:
	assert_eq(LevelBadge.tooltip(12), "Stufe 12")
	var p: PanelContainer = LevelBadge.make(12, 24)
	add_to_tree(p)
	await wait_frames(1)
	assert_eq(p.tooltip_text, "Stufe 12", "the tooltip names the level")
	assert_eq((p.get_node("Number") as Label).text, "12", "the plaque shows the bare number")
	assert_eq(p.size.x, p.size.y, "round: as wide as high (%s)" % str(p.size))
	assert_eq(p.size.x, LevelBadge.diameter(24))
	assert_eq(p.mouse_filter, Control.MOUSE_FILTER_PASS, "the tooltip shows, a click reaches the card underneath")
	# CR-32 (i): two digits keep 2 px to the ring (1.6 × the size alone let "48" touch it from 12 to 18 px)
	var font: Font = UiTheme.font_bold()
	for px: int in [12, 15, 18, 24]:
		var w: float = font.get_string_size("48", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		assert_true(w + 2.0 * (LevelBadge.BORDER_PX + 2.0) <= LevelBadge.diameter(px),
			"%d px: \"48\" (%.0f px) in a %.0f px plaque" % [px, w, LevelBadge.diameter(px)])
	assert_eq(LevelBadge.FRAME_RADIUS, LevelBadge.diameter(12) * 0.5, "the drawn plaques fit two digits of 12 px")


func test_party_menu_and_hud_show_the_plaque() -> void:
	Game.new_game(0, "Kai", 4242)
	var page: Control = (load("res://scenes/ui/party_menu.gd") as GDScript).new() as Control
	add_to_tree(page)
	await wait_frames(2)
	var plaques: Array[Node] = page.find_children("LevelBadge", "PanelContainer", true, false)
	assert_eq(plaques.size(), Game.state.party.size(), "one plaque per member card")
	for n: Node in plaques:
		assert_eq((n as Control).tooltip_text, "Stufe 1")
	for l: Node in page.find_children("*", "Label", true, false):
		assert_eq(words_in((l as Label).text), PackedStringArray(), "party menu: " + (l as Label).text)
	var kai: Node = page.find_child("Card_kai", true, false)
	assert_eq((kai.find_child("TalentNames", true, false) as Label).text, "noch keine (ab Stufe 3)")
	page.queue_free()
	var hud: CanvasLayer = (load("res://scenes/ui/exploration_hud.tscn") as PackedScene).instantiate() as CanvasLayer
	add_to_tree(hud)
	await wait_frames(30)
	for m: PartyMember in Game.state.party:
		var panel: Node = hud.find_child("Member_" + m.id, true, false)
		assert_not_null(panel, "HUD mini status of " + m.id)
		if panel == null:
			continue
		var plaque: Control = panel.find_child("LevelBadge", true, false) as Control
		assert_not_null(plaque, m.id + ": the HUD shows the plaque, not \"Lv\"")
		if plaque != null:
			assert_eq([plaque.tooltip_text, plaque.mouse_filter], ["Stufe 1", Control.MOUSE_FILTER_IGNORE],
				"the HUD never catches the mouse")
		for l: Node in panel.find_children("*", "Label", true, false):
			assert_eq(words_in((l as Label).text), PackedStringArray(), "HUD: " + (l as Label).text)
	hud.queue_free()
	var target: Control = (load("res://scenes/ui/explore_target.gd") as GDScript).new() as Control
	add_to_tree(target)
	target.call("set_model", {"lead": "enm_kanalratte", "count": 2, "slots": []})
	await wait_frames(1)
	var lv: Label = target.get_node("L_level") as Label
	assert_eq(lv.text, str(DB.enemy("enm_kanalratte").level), "the pull target frame: the bare number in its plaque")
	assert_eq(lv.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	target.queue_free()


## CR-32 (i): the combat HUD — the bare number in the plaque of the party and target frames (tooltip "Stufe N" over
## the plaque only), "NEUE STUFE!" and "Kai: Stufe 2" in the second lower third, plaques in the credits' rows.
func test_combat_frames_and_results_show_the_plaque() -> void:
	Game.new_game(0, "Kai", 4242)
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 4, "enemies": ["enm_kanalratte", "enm_kanalratte"]})
	sim.unit("p0").target_id = "e0"
	sim.unit("e0").level = 12
	var rig: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(3)
	var frames: Control = (rig["hud"] as Node).get("frames") as Control
	for spec: Array in [["ctl", "p0"], ["partner", "p1"], ["target", "e0"]]:
		var key: String = str(spec[0])
		var u: RtUnit = sim.unit(str(spec[1]))
		var l: Label = frames.get_node("L_%s_level" % key) as Label
		var pr: Rect2 = frames.call("level_rect", key + "_frame") as Rect2
		assert_eq([l.visible, l.text], [true, str(u.level)], key + ": the bare number, never \"Lv\"")
		assert_almost(l.get_rect().get_center().x, pr.get_center().x, 0.6, key + ": centred in its plaque")
		var hit: Control = frames.get_node("Hit_%s_frame" % key) as Control
		assert_eq(hit.get_tooltip(pr.get_center() - hit.position), "Stufe %d" % u.level, key + ": the plaque's tooltip")
		assert_eq(hit.get_tooltip(Vector2(4.0, 30.0)), "", key + ": the rest of the frame has none")
	for n: Node in frames.find_children("*", "Label", true, false):
		assert_eq(words_in((n as Label).text), PackedStringArray(), "frames: " + (n as Label).text)
	(rig["hud"] as Node).queue_free()
	Game.state.member("kai").level = 2
	var info: LevelUpInfo = LevelUpInfo.new()
	info.member_id = "kai"
	info.old_level = 1
	info.new_level = 2
	var rw: BattleRewards = BattleRewards.new()
	rw.exp = 40
	rw.level_ups = [info]
	var res: CanvasLayer = (load(RESULTS) as GDScript).new() as CanvasLayer
	var holder: Node = Node.new()
	add_to_tree(holder)
	holder.add_child(res)
	var win: BattleResult = BattleResult.new()
	win.outcome = BattleResult.Outcome.VICTORY
	res.call("present", win, rw)
	assert_eq(res.call("lower_texts"), PackedStringArray(["+40 EXP", "Kai: Stufe 2"]), "the second lower third")
	assert_eq(_label_texts(res).count("NEUE STUFE!"), 1, "its title, in the words of the toast \"NEUE STUFE\"")
	var boss: BattleResult = BattleResult.new()
	boss.outcome = BattleResult.Outcome.VICTORY
	boss.is_boss = true
	boss.boss_id = "enm_boss_hausmeister"
	res.set("auto_continue_sec", 0.15)
	var done: Array[bool] = [false]
	var run: Callable = func() -> void:
		await res.call("present", boss, rw)
		done[0] = true
	run.call()
	var plaques: Array[Node] = res.find_children("LevelBadge", "PanelContainer", true, false)
	assert_eq(plaques.size(), Game.state.party.size(), "the credits: a plaque in every member's row")
	for i in mini(plaques.size(), Game.state.party.size()):
		assert_eq((plaques[i] as Control).tooltip_text, "Stufe %d" % Game.state.party[i].level)
	var texts: PackedStringArray = _label_texts(res)
	assert_eq(texts.count("NEUE STUFE!"), 1, "Kai's level-up row")
	for t: String in texts:
		assert_eq(words_in(t), PackedStringArray(), "credits: " + t)
	await wait_until(func() -> bool: return done[0], 600)
	tree.paused = false


static func _label_texts(root: Node) -> PackedStringArray:
	var out: PackedStringArray = []
	for n: Node in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func test_liga_tiers_read_liga_1_and_duo_liga() -> void:
	for v: Dictionary in [{"liga_tier": 1, "rewards": true}, {"liga_tier": 2, "rewards": false}]:
		var text: String = BetsMenu._tier_text(v)
		assert_has(text, "Liga 1")
		assert_has(text, "Duo-Liga")
		assert_false(text.contains("Stufe"), "09 §1.2 Nr. 3: no \"Stufe 1 / Stufe 2\" — " + text)
