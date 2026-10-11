extends TestCase
## 06 §1.4 (package A): "Partner automatisch" — GameSettings.partner_auto (default off, persisted as
## game/partner_auto), the settings row (options only, one help line, no tutorial), and the battle: with the option the
## partner's turns come from AutoPolicy (recorded "auto": true) while the hero's turns wait in the command menu — for
## Kai and for Graf Mopsula as hero; without it both are commanded; the full auto battle still wins. Party panels mark
## the hero ("DU") and the automatic partner ("AUTO").

const SCENE: String = "res://scenes/battle/battle.tscn"
const SETTINGS: String = "res://scenes/ui/settings_menu.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const BattleController := preload("res://scenes/battle/battle_controller.gd")
const MAX_FRAMES: int = 900
const SPEED: float = 8.0

var _saved_auto: bool = false
var _saved_partner: bool = false


func before_each() -> void:
	Engine.time_scale = 8.0
	_saved_auto = Game.auto_battle
	_saved_partner = Game.settings.partner_auto


func after_each() -> void:
	Engine.time_scale = 1.0
	Game.auto_battle = _saved_auto
	Game.settings.partner_auto = _saved_partner
	Game.in_battle = false
	if Router.stack_size() > 1 or Router.busy:
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		await wait_until(func() -> bool: return not Router.busy, 600)
		var cur: Node = Router.current
		if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Sfx.music(&"", 0.0)
	# leave no run behind: later files (e.g. test_m0_autoloads) check the state-less Game
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


func _battle(hero: String) -> BattleScene:
	Game.new_game(0, "Kai", 4242, &"prime", hero)
	var s: BattleSetup = Game.make_battle_setup("enc_f1_a2", BattleSetup.Advantage.NORMAL, "")
	var scene: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	scene.setup({"setup": s, "speed": SPEED, "stay": true, "results_auto_sec": 0.05})
	add_to_tree(scene)
	return scene


func _wait_menu(scene: BattleScene) -> bool:
	return await wait_until(func() -> bool: return scene.hud != null and scene.hud.awaiting, MAX_FRAMES)


func _def_of(scene: BattleScene, combatant_id: String) -> String:
	var c: Combatant = scene.controller.state.get_combatant(combatant_id)
	return c.def_id if c != null else ""


## Hands the rest of the battle to the full auto battle (the HUD's toggle, like the player would).
func _finish(scene: BattleScene) -> void:
	if not Game.auto_battle:
		scene.hud.toggle_auto()
	await wait_until(func() -> bool: return scene.controller != null and scene.controller.done, MAX_FRAMES)


# --- settings ---------------------------------------------------------------------------------------------------------

func test_setting_defaults_off_and_round_trips() -> void:
	var s: GameSettings = GameSettings.new()
	assert_false(s.partner_auto, "default off (06 §1.4)")
	s.partner_auto = true
	assert_true(bool(s.to_dict()["partner_auto"]))
	s.reset_defaults()
	assert_false(s.partner_auto)
	var path: String = GameSettings.PATH
	var had: bool = FileAccess.file_exists(path)
	var backup: String = FileAccess.get_file_as_string(path) if had else ""
	var w: GameSettings = GameSettings.new()
	w.ephemeral = false
	w.partner_auto = true
	assert_eq(w.save_to_disk(), OK)
	var r: GameSettings = GameSettings.new()
	r.ephemeral = false
	r.load_from_disk()
	assert_true(r.partner_auto, "persisted as game/partner_auto")
	if had:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(path)


func test_settings_row_toggles_the_option() -> void:
	Game.ensure_state()
	Game.settings.partner_auto = false
	var m: Control = (load(SETTINGS) as PackedScene).instantiate() as Control
	m.call("setup", {"framed": true})
	add_to_tree(m)
	await wait_frames(3)
	var rows: Dictionary = m.get("rows")
	assert_true(rows.has("partner_auto"), "row 'Partner automatisch'")
	if not rows.has("partner_auto"):
		return
	var c: Button = rows["partner_auto"] as Button
	assert_eq(c.text.strip_edges(), "‹  Aus  ›")
	c.call("step", 1)
	assert_true(Game.settings.partner_auto, "cycling switches it on")
	var hint: Label = c.get_parent().find_child("Hint", true, false) as Label
	assert_not_null(hint, "one help line under the label")
	if hint != null:
		assert_eq(hint.text, "Dein:e Partner:in kämpft von selbst.")
	c.call("step", 1)
	assert_false(Game.settings.partner_auto)


# --- battle -----------------------------------------------------------------------------------------------------------

func test_partner_plays_itself_and_the_hero_gets_the_menu() -> void:
	for hero: String in ["kai", "mopsula"]:
		Game.auto_battle = false
		Game.settings.partner_auto = true
		var scene: BattleScene = _battle(hero)
		assert_true(await _wait_menu(scene), "a command menu appears (%s)" % hero)
		var actor: Combatant = scene.controller.state.current_actor()
		assert_eq(actor.def_id, hero, "the menu is only for the hero (%s)" % hero)
		for c: Dictionary in scene.controller.commands:
			var who: String = _def_of(scene, str((c["cmd"] as Dictionary)["actor"]))
			if who == Game.partner():
				assert_true(bool(c["auto"]), "partner turns are AutoPolicy (recorded auto)")
		var panels: Dictionary = scene.hud.panels
		for cid: Variant in panels.keys():
			var role: String = str((panels[cid] as Object).get("role"))
			var def_id: String = _def_of(scene, str(cid))
			assert_eq(role, "lead" if def_id == hero else "auto", "panel role of %s" % def_id)
		await _finish(scene)
		assert_true(scene.controller.done, "the battle ends (%s)" % hero)
		for c: Dictionary in scene.controller.commands:
			var who2: String = _def_of(scene, str((c["cmd"] as Dictionary)["actor"]))
			if who2 == Game.partner():
				assert_true(bool(c["auto"]))
		scene.queue_free()
		await wait_frames(2)


func test_without_the_option_both_are_commanded() -> void:
	Game.auto_battle = false
	Game.settings.partner_auto = false
	assert_false(BattleController.is_partner_auto("mopsula"))
	var scene: BattleScene = _battle("kai")
	assert_true(await _wait_menu(scene))
	var actor: Combatant = scene.controller.state.current_actor()
	assert_true(actor.is_party(), "the first party actor gets the menu, whoever it is")
	for c: Dictionary in scene.controller.commands:
		var who: String = _def_of(scene, str((c["cmd"] as Dictionary)["actor"]))
		assert_ne(who, "mopsula", "no automatic partner turn before the menu")
	var panels: Dictionary = scene.hud.panels
	for cid: Variant in panels.keys():
		var role: String = str((panels[cid] as Object).get("role"))
		assert_eq(role, "lead" if _def_of(scene, str(cid)) == "kai" else "", "only the hero is marked")
	await _finish(scene)


func test_partner_auto_rule() -> void:
	Game.new_game(0, "Kai", 5)
	Game.settings.partner_auto = true
	assert_true(BattleController.is_partner_auto("mopsula"), "Kai leads → Mopsula is the partner")
	assert_false(BattleController.is_partner_auto("kai"), "never the hero")
	Game.state.hero = "mopsula"
	assert_true(BattleController.is_partner_auto("kai"))
	assert_false(BattleController.is_partner_auto("mopsula"))
	Game.settings.partner_auto = false
	assert_false(BattleController.is_partner_auto("kai"))
