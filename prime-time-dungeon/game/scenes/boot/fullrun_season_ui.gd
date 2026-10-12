extends RefCounted
## The season screens of the full-run bot (09 §11.3 ST1-I; scenes/boot/fullrun.gd, section "Staffeln"): every place
## where the bot touches a season screen or a season facade sits here, so the screens of the season UI (ST1-H: "Sendung
## starten", the Staffel tab, the tempo offer, the season results) and the Recall's screen are wired in one file. Today:
## the start through Game.start_season (the facade the title's start uses; the bot passes a fixed start moment), the
## Recall through Game.choose_casting, the class abilities through Game.apply_loadout (the skills menu's path), the rows
## of the talent tree through the Talent-Show, the logout through the logout dialog (from the pause menu or the safe
## room), the login through the title's "Fortsetzen" and "Während Sie schliefen …", the stairs dialog, the Etagen-Bilanz
## and the end screens. Private helper (no class_name), created by the bot with itself as `bot` (duck-typed: wait_for,
## note, fail, finished).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const DAY: int = 86400
## The Recall of the bot (09 §8.3, 06 §3): species and class per figure — a tank and a healer.
const RECALL: Dictionary = {"kai": ["spc_original", "cls_kai_wrecker"],
	"mopsula": ["spc_original", "cls_mop_physician"]}
const LOGIN_BUDGET: int = 1200
const DIALOG_BUDGET: int = 300
const PICK_BUDGET: int = 1500

var bot: Node = null
## The logins so far: [{"absence", "away", "question", "lines", "sub"}] (the bot's report).
var logins: Array[Dictionary] = []

var _absence: int = -1                     # the absence the next login books (season seconds), -1 = none


func _init(p_bot: Node) -> void:
	bot = p_bot


## A new season like the title's start ("Sendung starten" / "Neue Staffel", 09 §2.2): Game.start_season with the
## bot's fixed start (opts: tempo, mode, now, tz_sec 0, seed, air time) and the exploration of floor 1 — what boot's
## --season does, without the wall clock. false = refused.
func start(slot: int, def_id: String, opts: Dictionary, hero_id: String) -> bool:
	if not Game.start_season(slot, def_id, opts, hero_id):
		return bot.fail("Game.start_season(%s, %s) was refused" % [def_id, JSON.stringify(opts)])
	Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
	return true


## The Recall (09 §0.6: floor 3, a safe room): species and class of both figures through Game.choose_casting (the core
## facade — the Recall screen of 06 §3 will call the same). true when every figure has a class afterwards.
func recall() -> bool:
	for mid: String in ["kai", "mopsula"]:
		var m: PartyMember = Game.state.member(mid)
		if m == null or m.class_id != "":
			continue
		var pick: Array = RECALL[mid]
		if not Game.choose_casting(mid, str(pick[0]), str(pick[1])):
			return bot.fail("Recall: %s cannot become %s / %s (%s)" % [mid, str(pick[0]), str(pick[1]),
				Casting.check(Game.state, DB.data, mid, str(pick[0]), str(pick[1]))])
		bot.note("Recall: %s wird %s (%s)" % [mid, DB.class_def(str(pick[1])).name, str(pick[0])])
	return true


## The class abilities on the bar (09 §8.3, D-9; the skills menu's "Buch" path): per slot the learned class variant
## of the highest level, recorded with Game.apply_loadout (preset and switches stay). The members whose bar changed.
func loadout() -> PackedStringArray:
	var out: PackedStringArray = []
	for m: PartyMember in Game.state.party:
		var best: Dictionary = {}                  # slot → [level, skill]
		for r: Dictionary in AbilityBook.rows_of(Game.state, DB.data, m):
			if str(r["source"]) == AbilityBook.SOURCE_PARTY or str(r["kind"]) != "variant" \
					or not AbilityBook.is_learned(m, r):
				continue
			var slot: String = str(int(r["slot"]))
			if not best.has(slot) or int(r["level"]) > int((best[slot] as Array)[0]):
				best[slot] = [int(r["level"]), str(r["skill"])]
		var bar: Dictionary = m.rt_loadout.duplicate()
		for slot: Variant in best.keys():
			bar[str(slot)] = str((best[slot] as Array)[1])
		if bar == m.rt_loadout:
			continue
		if not Game.apply_loadout(RunRules.loadout_cmd(m.id, bar, m.rt_preset, m.rt_toggles)):
			bot.fail("loadout of %s refused: %s" % [m.id, JSON.stringify(bar)])
			return out
		out.append(m.id)
		bot.note("Fähigkeitenbuch: %s legt %s auf die Leiste" % [m.id, JSON.stringify(bar)])
	return out


## Every open row of the talent tree through the Talent-Show (09 §8.4: the show presents the rows, a pick is
## Game.pick_talent_row; the bot takes the first card). The picks as "<member>@R<row>:<talent>".
func talent_rows(scene: SafeRoomScene) -> PackedStringArray:
	var out: PackedStringArray = []
	if not scene.talent_show_available():
		return out
	var layer: Node = scene.open_talent_show()
	var n: int = 0
	while is_instance_valid(layer) and not layer.is_queued_for_deletion() and not bool(bot.get("finished")):
		var mid: String = str(layer.get("member_id"))
		var offer: PackedStringArray = layer.get("offer")
		if mid == "" or offer.is_empty():
			layer.call("close")
			break
		var row: int = int(layer.get("row"))
		if not bool(await layer.call("pick", 0)):
			bot.fail("Talent-Show: %s cannot pick %s (row %d)" % [mid, offer[0], row])
			return out
		out.append("%s@R%d:%s" % [mid, row, offer[0]])
		n += 1
		if n > PICK_BUDGET:
			bot.fail("the Talent-Show did not finish")
			return out
		await bot.get_tree().process_frame
	if TalentTree.open_total(Game.state, DB.data) > 0:
		bot.fail("%d rows of the talent tree still open after the Talent-Show" % TalentTree.open_total(Game.state,
			DB.data))
	return out


## The logout in a safe room (09 §5.1: "Ausloggen" — sicher, ausgeruht): the menu's "Ausloggen" opens the logout dialog,
## "Hier schlafen" sleeps and goes to the title. false = the run failed.
func logout_safe_room(scene: SafeRoomScene) -> bool:
	var d: Node = scene.open_save()
	if d == null or not d.has_method("confirm"):
		return bot.fail("the safe room offers no logout dialog")
	return await _confirm_logout(d, "careful")


## The logout in the exploration (09 §5.1: Pause → "Ausloggen" → the dialog with the tactic): the pause menu's last tab
## opens the logout dialog. false = the run failed.
func logout_exploration(_ex: ExplorationScene, tactic: String) -> bool:
	UiUtil.tap_action(&"pause", true)
	await bot.get_tree().process_frame
	UiUtil.tap_action(&"pause", false)
	if not await bot.wait_for(func() -> bool: return bot.get_tree().paused, 60, "the pause menu"):
		return false
	var pm: Node = _find(bot.get_tree().root, "ask_to_title")
	if pm == null:
		return bot.fail("no pause menu with a logout")
	var d: Node = pm.call("ask_to_title")
	if d == null or not d.has_method("confirm"):
		return bot.fail("the pause menu's last tab opens no logout dialog")
	return await _confirm_logout(d, tactic)


## The login after `absence` season seconds (09 §5.5): the title's "Fortsetzen" loads the slot and books the night —
## the absence is put into the loaded season's wall clock seen last (offline the login measures the wall clock, the bot
## sets what a person's absence would be); a clock jump over seven days answers "Ja" (09 V-17). Then "Während Sie
## schliefen …" (wake). false = the run failed.
func login(absence: int) -> bool:
	if not await bot.wait_for(func() -> bool: return Router.current is TitleScreen and not Router.busy, LOGIN_BUDGET,
			"the title after the logout"):
		return false
	var title: TitleScreen = Router.current as TitleScreen
	if not title.menu_ids().has("continue"):
		return bot.fail("the title offers no \"Fortsetzen\" for the season")
	_absence = absence
	Events.game_loaded.connect(_on_game_loaded, CONNECT_ONE_SHOT)
	title.activate("continue")
	Game.season_live_clock = false           # the bot's clock again (fullrun: game time, not the wall clock)
	Game.season_speed = 1
	if Events.game_loaded.is_connected(_on_game_loaded):
		Events.game_loaded.disconnect(_on_game_loaded)
		return bot.fail("\"Fortsetzen\" loaded nothing (%s)" % Save.last_error())
	var away: int = -1
	for e: Dictionary in (Game.run_log.cmds() if Game.run_log != null else [] as Array[Dictionary]):
		var c: Dictionary = e["c"]
		if str(c.get("t", "")) == "away":
			away = int(c.get("sec", 0))
	logins.append({"absence": absence, "away": away, "question": Game.season_wake.has("question")})
	return true


## "Während Sie schliefen …" (the screen after a login or an absence): a clock jump over seven days → "Ja"; the lines
## go into the bot's log; "Weiter" (the world, the Sendeschluss screen or the Abspann). false = the run failed.
func wake(screen: Node) -> bool:
	if screen.has_method("answer") and (screen.get("wake") as Dictionary).has("question"):
		bot.note("Uhrsprung-Rückfrage: %d s weg → „Ja“ (7 Tage zählen, der Rest wird Sendepause)" % int(
			(screen.get("wake") as Dictionary)["question"]))
		screen.call("answer", true)
		if not logins.is_empty():
			logins[logins.size() - 1]["question"] = true
	var w: Dictionary = screen.get("wake")
	var lines: PackedStringArray = w.get("lines", PackedStringArray())
	if not logins.is_empty():
		logins[logins.size() - 1]["sub"] = str(w.get("sub", ""))
		logins[logins.size() - 1]["lines"] = lines.size()
		logins[logins.size() - 1]["kinds"] = PackedStringArray(w.get("kinds", PackedStringArray()))
	bot.note("%s · %s" % [str(w.get("title", "")), str(w.get("sub", ""))])
	for l: String in lines:
		bot.note("  • " + l)
	var screen_id: int = screen.get_instance_id()      # the summary is freed on the way: no capture of the node
	screen.call("continue_pressed")
	return await bot.wait_for(func() -> bool: return Router.current != null \
		and Router.current.get_instance_id() != screen_id and not Router.busy, DIALOG_BUDGET,
		"the world after the wake summary")


## The screen is "Während Sie schliefen …".
func is_wake_summary(n: Node) -> bool:
	return n != null and n.scene_file_path == Game.SCENE_WAKE_SUMMARY


## The stairs dialog of a season floor: open stairs → "Abstieg" (the Etagen-Bilanz follows); closed stairs (09 §2.6,
## "Kulissen im Aufbau") → "Noch nicht" — the bot waits (the stairs dialog of ST1-H may say why). Returns "descend" |
## "closed".
func stairs(dlg: Node) -> String:
	var why: String = SeasonRules.stairs_refusal(Game.state, DB.data)
	if why != "":
		dlg.call("choose", "stay")
		return "closed"
	dlg.call("choose", "descend")
	return "descend"


## The Etagen-Bilanz in a season: "Weiter" → the next floor (or the Abspann when the stairs ended the season).
func floor_summary(fs: FloorSummary) -> void:
	fs.continue_pressed()


## The end screens of a season (09 §2.7): the Abspann after the finale / the last collapse ("finish" → title), the
## Sendeschluss of an Ohne-Netz candidate (stays). The season results of ST1-H come here.
func end_screen(cur: Node) -> bool:
	if cur.scene_file_path == Router.SCENE_CREDITS:
		cur.call("finish")
		return await bot.wait_for(func() -> bool: return Router.current is TitleScreen and not Router.busy,
			DIALOG_BUDGET * 4, "the title after the Abspann")
	return true


func _confirm_logout(d: Node, tactic: String) -> bool:
	if not await bot.wait_for(func() -> bool: return d.is_inside_tree(), 30, "the logout dialog"):
		return false
	d.set("tactic", tactic)
	d.call("confirm")
	if not bool(d.get("answered")):
		return bot.fail("\"Hier schlafen\" was refused: %s" % str(d.get("_error").get("text")))
	return await bot.wait_for(func() -> bool: return Router.current is TitleScreen and not Router.busy, LOGIN_BUDGET,
		"the title after the logout")


func _on_game_loaded(_slot: int) -> void:
	if Game.state == null or Game.state.season == null or _absence < 0:
		return
	Game.season_live_clock = true            # the login measures the absence like a person's device (09 §5.5)
	Game.season_speed = 1
	Game.state.season.seen_unix = int(Time.get_unix_time_from_system()) - _absence
	_absence = -1


static func _find(root: Node, method: String) -> Node:
	for c: Node in root.get_children():
		if c.has_method(method):
			return c
		var deeper: Node = _find(c, method)
		if deeper != null:
			return deeper
	return null
