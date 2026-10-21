extends "res://tests/fixtures/rt_world/world_case.gd"
## The pause menu during a real-time fight (binding integration decision, 07 O2 offline): opening it pauses the tree,
## so the sim does not tick; field item use and equipment changes are refused with a short hint ("Im Kampf:
## Gegenstände über das Item-Rad") and record nothing — the party changes only through the recorded combat commands.
## After pause → resume the game state hash, the combat state hash and the run log are unchanged and the fight goes
## on. The RtKit world with the REAL sim (R1b).

const CELL: Vector2i = Vector2i(3, 6)


func after_each() -> void:
	tree.paused = false
	await super()


func test_the_pause_menu_in_a_fight_changes_nothing() -> void:
	await make_kit_world("kai")
	place_player(CELL, Vector3(0.0, 0.0, 1.5), 0.0)
	scene.call("_trigger_encounter", "", "enc_rt_dummy", Rules.NORMAL, "")
	assert_not_null(Game.combat, "a real-time fight runs")
	if Game.combat == null:
		return
	director.auto_tick = true
	var kai: PartyMember = Game.state.member("kai")
	kai.hp = maxi(1, kai.hp - 20)                # a bandage would heal: the refusal is visible in the hash
	await seconds(0.3)
	assert_gt(Game.combat.tick(), 0, "the fight ticks in real time")
	var hud: ExplorationHud = scene.get("_hud") as ExplorationHud
	var pm: Node = hud.open_pause_menu("inventory")
	assert_not_null(pm, "the pause menu opens during a fight")
	if pm == null:
		return
	await wait_frames(2)
	assert_true(tree.paused, "the pause menu pauses the tree")
	var h0: String = StateHash.of(Game.state)
	var sim_h0: String = StateHash.of_rt(Game.combat)
	var cmds0: int = Game.run_log.cmds().size()
	var tick0: int = Game.combat.tick()
	await seconds(0.5)
	assert_eq(Game.combat.tick(), tick0, "the sim stands while the menu is open (07 O2)")
	var said: PackedStringArray = []
	var inv: Control = pm.call("page", "inventory") as Control
	inv.connect("status", func(t: String) -> void: said.append(t))
	assert_false(bool(inv.call("use_on", "itm_bandage", "kai")), "no field item use in a fight")
	inv.call("_activate", "itm_bandage")
	pm.call("show_tab", "equipment")
	var eq: Control = pm.call("page", "equipment") as Control
	eq.connect("status", func(t: String) -> void: said.append(t))
	assert_false(bool(eq.call("equip", "weapon", "")), "no equipment change in a fight")
	assert_true(said.has(Game.RT_LOCK_ITEMS), "the hint names the item wheel: %s" % str(said))
	assert_true(said.has(Game.RT_LOCK_EQUIP), "and the equipment rule")
	assert_false(Game.use_item("itm_bandage", "kai"), "Game refuses field item use itself")
	assert_false(Game.equip("kai", "weapon", ""), "and equipment changes")
	assert_eq(StateHash.of(Game.state), h0, "the game state is unchanged")
	assert_eq(StateHash.of_rt(Game.combat), sim_h0, "the combat state is unchanged")
	assert_eq(Game.run_log.cmds().size(), cmds0, "nothing was recorded")
	pm.call("close")
	await wait_frames(2)
	assert_false(tree.paused, "closed: the tree runs again")
	assert_eq(StateHash.of(Game.state), h0, "pause → resume left the game state as it was")
	await seconds(0.3)
	assert_gt(Game.combat.tick() if Game.combat != null else tick0 + 1, tick0, "the fight goes on")
	director.auto_tick = false
	assert_eq(Game.rt_party_lock(), Game.RT_LOCK_ITEMS, "still locked while the fight runs")
	director.abort()
	assert_eq(Game.rt_party_lock(), "", "after the fight the menu works again")
