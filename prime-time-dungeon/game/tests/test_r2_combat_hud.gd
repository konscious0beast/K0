extends "res://tests/fixtures/rt_world/world_case.gd"
## The combat in the world with R3's combat HUD (07 §8, §2.13; the R2 ↔ R3 integration): the CombatDirector adds
## combat_hud.tscn for every combat, the HUD binds the running RtSim, sends every input through CombatDirector.submit,
## holds the ticks with pause_for_hint / resume while a hint card stands (the hint ids land in the run log) and gives
## the screen back and frees itself at the end; CombatResults follows Game.end_combat. The tutorial combat of the
## RtKit world with the REAL sim (R1b).

const CELL: Vector2i = Vector2i(3, 6)

var modes: Array[StringName] = []          # Events.overlay_mode_requested


func before_each() -> void:
	super()
	modes.clear()
	Events.overlay_mode_requested.connect(_on_mode)


func after_each() -> void:
	if Events.overlay_mode_requested.is_connected(_on_mode):
		Events.overlay_mode_requested.disconnect(_on_mode)
	await super()


func _on_mode(m: StringName) -> void:
	modes.append(m)


func test_the_tutorial_with_the_combat_hud() -> void:
	await make_kit_world("kai")
	director.use_hud = true
	var tut: Node3D = scene.get_enemy("f1_g0")
	var center: Vector3 = scene.get_layout().cell_to_world(CELL)
	place_player(CELL, tut.global_position - center + Vector3(0.0, 0.0, 1.2), 0.0)
	scene.call("on_enemy_contact", tut)
	assert_not_null(Game.combat, "the tutorial combat starts")
	if Game.combat == null:
		return
	var hud: CanvasLayer = director.hud
	assert_not_null(hud, "the director added R3's combat HUD")
	if hud == null:
		return
	assert_true(hud.is_inside_tree())
	assert_true(bool(hud.call("is_bound")), "bound to the running combat")
	assert_true(hud.get("sim") == Game.combat, "the HUD reads the running sim")
	assert_true(hud.get("director") == director, "and sends through this director")
	assert_true(modes.has(&"combat"), "ShowOverlay in combat mode")
	var hints: Node = hud.get("hints") as Node
	var ctl: String = director.controlled_unit()
	var bar: Dictionary = Game.combat.bar(ctl)
	# the first tutorial card at ct 0: the ticks stand until the player acts (07 §2.13)
	assert_eq(str(hints.call("current")), "target", "the first tutorial card")
	var t0: int = Game.combat.tick()
	director.advance(10)
	assert_eq(Game.combat.tick(), t0, "no tick while a hint card stands")
	hud.call("send", RtCommand.target(0, ctl, "e0"))
	assert_eq(str(hints.call("current")), "bar1", "a target chosen: the slot-1 card")
	director.advance(10)
	assert_eq(Game.combat.tick(), t0, "still no tick")
	hud.call("send", RtCommand.ability(0, ctl, str(bar[1]), ""))
	assert_eq(str(hints.call("current")), "", "slot 1 used: the opening cards are done")
	director.advance(10)
	assert_gt(Game.combat.tick(), t0, "the combat runs again")
	director.present_results = true                  # R3's CombatResults after Game.end_combat (07 §8.9)
	var cards: PackedStringArray = []
	for i in 4000:
		if not director.is_running():
			break
		if bool(hints.call("is_showing")):
			cards.append(str(hints.call("current")))
			hints.call("dismiss")                # "Später" / any-input cards
		if i % 45 == 0:
			hud.call("send", RtCommand.ability(0, ctl, str(bar[1]), ""))
		director.advance(1)
	assert_not_null(director.last_result)
	if director.last_result != null:
		assert_eq(int(director.last_result.outcome), BattleResult.Outcome.VICTORY, "the tutorial is won")
	assert_true(cards.has("show"), "the SHOW card after the first party hit: %s" % str(cards))
	var res: Node = director.get_node_or_null("CombatResults")
	assert_not_null(res, "the director created CombatResults after Game.end_combat")
	if res != null:
		assert_eq(res.get("form"), &"applaus", "a regular win: the \"Applaus!\" lower third")
		assert_true(bool(res.get("shown")))
	var hint_ids: PackedStringArray = []
	var sent_by_hud: int = 0
	for row: Dictionary in Game.run_log.cmds():
		var c: Dictionary = row["c"]
		if str(c.get("t", "")) == "combat_hint":
			hint_ids.append(str(c.get("id", "")))
		elif str(c.get("t", "")) == "ability_use":
			sent_by_hud += 1
	assert_true(hint_ids.has("target") and hint_ids.has("bar1") and hint_ids.has("show"),
		"the hint pauses are recorded (07 §2.13): %s" % str(hint_ids))
	assert_gt(sent_by_hud, 1, "the HUD's commands went through CombatDirector.submit into the run log")
	await seconds(0.6)
	assert_false(is_instance_valid(hud), "the HUD freed itself after its fade")
	assert_eq(modes.back() if not modes.is_empty() else &"", &"explore", "the screen is given back")
	assert_false(Game.in_battle)
