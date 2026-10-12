extends TestCase
## Integration 06 package A × B (hero choice × talents). Talents belong to the party member, never to the controlled
## character: offers, picks and their effects are the same whoever leads, the Talent-Show works for both choices and the
## AI partner of a real-time combat (07 §5) fights with its own talents (its unit is built from the talent-modified
## combatant). The leader's own field talents drive the field ability — Kai: "Weit ausholen" → Feldschlag reach; Graf
## Mopsula: "Bellen in Stereo" → Bellen reach, "Schwer vermittelbar" → Bellen cooldown (HeroRules.field_mods →
## PlayerController, integer per-mille via EncounterRules.scale_pm) — and move with "Figur wechseln". One integration
## test per hero (recorded run with real-time combats → Talent-Show in the safe room → switch → Game.replay_log ≡ live
## → a real-time combat whose AI partner carries its talents), the field geometry in the exploration scene for both
## heroes, and the safe-room layout for desktop (1280×720) and the phone touch layout (1600×720): every hit area
## >= 88 px, 12 px apart, "Weiter" on screen, the TALENT-SHOW button clear of the menu, the banners and the M.O.D. box.

const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const M3 := preload("res://tests/test_m3_exploration_scene.gd")
const Harness := preload("res://tests/tools/rt_harness.gd")
const RtLive := preload("res://tests/fixtures/rt_live/rt_live.gd")
const ModDialogScript := preload("res://scenes/ui/mod_dialog.gd")
const SCENE_EXPLORE: String = "res://scenes/exploration/exploration.tscn"
const SCENE_SAFE: String = "res://scenes/safe_room/safe_room.tscn"
const SCENE_SHOW: String = "res://scenes/ui/talent_show.tscn"
const ROUTER_FIXTURE: String = "res://tests/fixtures/router/router_screen.tscn"
const MAX_FRAMES: int = 600
const MAX_COMBAT_TICKS: int = 18000
const RUN_SEED: int = 5150                   # reaches L3 for both members within LEVEL_ENCS (as test_06b_talents)
const LEVEL_ENCS: PackedStringArray = ["enc_f1_a1_tutorial", "enc_f1_a2", "enc_f1_a3", "enc_f1_a_rare", "enc_f1_a4",
	"enc_f1_b1"]
## Damage talents of the AI partner (counterfactual check): Kai +2 STR and the preemptive first strike,
## Graf Mopsula +2 MAG.
const PARTNER_TALENTS: Dictionary = {"kai": {"tal_kai_wischtechnik": 2, "tal_kai_erster_eindruck": 1},
	"mopsula": {"tal_mop_mitternachtsformel": 2}}

var _spy: Array[Array] = []
var _saved_data: GameData = null

static var _fixture: GameData = null


func before_each() -> void:
	Engine.time_scale = 8.0
	tree.paused = false
	_spy.clear()
	_saved_data = DB.data
	Events.encounter_triggered.connect(_on_encounter)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Events.encounter_triggered.disconnect(_on_encounter)
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak", &"action"]:
		Input.action_release(a)
	if Game.combat != null:
		Game.end_combat()
	Game.clear_blocking_dialogs()
	if Router.stack_size() > 1 or Router.busy:
		Router.goto(ROUTER_FIXTURE, {}, Router.Transition.NONE)
		await wait_until(func() -> bool: return not Router.busy, MAX_FRAMES)
		var cur: Node = Router.current
		if cur != null and is_instance_valid(cur) and cur.scene_file_path == ROUTER_FIXTURE:
			if cur.get_parent() != null:
				cur.get_parent().remove_child(cur)
			cur.free()
	Router.adopt(null)
	Game.timer_running = false
	Sfx.stop_all()
	if _saved_data != null:
		DB.data = _saved_data
	# leave no run behind: later files (e.g. test_m0_autoloads) check the state-less Game
	Game.state = null
	Game.run_log = null
	Game.sim = null
	Game.in_battle = false


func _on_encounter(group_id: String, encounter_id: String, advantage: int) -> void:
	_spy.append([group_id, encounter_id, advantage])


# --- pure rules -------------------------------------------------------------------------------------------------------

func test_field_talent_factors_are_integer_per_mille() -> void:
	assert_eq(Rules.strike_reach(), Rules.STRIKE_RANGE, "1000 ‰ = neutral: the 06 §1.3 values stay bit for bit")
	assert_eq(Rules.bark_reach(), Rules.BARK_RANGE)
	assert_eq(Rules.field_cooldown(&"strike"), Rules.STRIKE_COOLDOWN)
	assert_eq(Rules.field_cooldown(&"bark"), Rules.BARK_COOLDOWN)
	assert_eq(Rules.strike_reach(1250), 2.25, "Weit ausholen: 1800 mm × 1250 ‰ = 2250 mm")
	assert_eq(Rules.bark_reach(1250), 5.0, "Bellen in Stereo: 4000 mm × 1250 ‰ = 5000 mm")
	assert_eq(Rules.field_cooldown(&"bark", 700), 2.1, "Schwer vermittelbar: 3000 ms × 700 ‰ = 2100 ms")
	assert_eq(Rules.field_cooldown(&"strike", 700), 0.42)
	assert_eq(Rules.scale_pm(1.8, 1234), 2.221, "(1800 · 1234 + 500) / 1000 = 2221 mm")
	assert_eq(Rules.scale_pm(0.001, 1500), 0.002, "1.5 mm rounds half up to 2 mm (06 §8.0 Nr. 4)")
	assert_eq(Rules.scale_pm(0.001, 1499), 0.001)
	assert_eq(Rules.scale_pm(1.8, -5), 0.0, "never negative")
	var o: Vector3 = Vector3.ZERO
	var fwd: Vector3 = Vector3(0, 0, -1)
	assert_true(Rules.bark_hits(o, fwd, Vector3(0, 0, -4.99), 1250), "the bark cone uses the same reach")
	assert_false(Rules.bark_hits(o, fwd, Vector3(0, 0, -5.01), 1250))


func test_field_mods_follow_the_leader() -> void:
	var data: GameData = real_data()
	var st: GameState = GameState.create_new(data, 0, "Kai", 7, &"prime")
	var neutral: Dictionary = {"range_pm": 1000, "cd_pm": 1000}
	assert_eq(HeroRules.field_mods(st, data), neutral, "no talents: neutral")
	st.member("kai").talents = {"tal_kai_weit_ausholen": 1}
	st.member("mopsula").talents = {"tal_mop_stereo": 1, "tal_mop_schwer_vermittelbar": 1}
	assert_eq(HeroRules.field_mods(st, data), {"range_pm": 1250, "cd_pm": 1000}, "Kai leads: his Weit ausholen only")
	st.hero = "mopsula"
	assert_eq(HeroRules.field_mods(st, data), {"range_pm": 1250, "cd_pm": 700}, "the Count leads: his two talents")
	st.member("mopsula").talents = {}
	assert_eq(HeroRules.field_mods(st, data), neutral, "Kai's talent rests while he follows")
	assert_eq(HeroRules.field_mods(null, data), neutral, "no run: neutral")


func test_talent_show_names_where_a_field_talent_works() -> void:
	Game.new_game(0, "Kai", 3, &"prime", "kai")
	for m: PartyMember in Game.state.party:
		m.level = 3
	Game.state.floor_run.location = &"sr_kiosk"
	var ts: Node = (load(SCENE_SHOW) as PackedScene).instantiate()
	add_to_tree(ts)
	await wait_frames(2)
	var kai: PartyMember = Game.state.member("kai")
	var mop: PartyMember = Game.state.member("mopsula")
	assert_eq(str(ts.call("_preview", kai, DB.talent("tal_kai_weit_ausholen"))), "Wirkt sofort: Kai führt die Gruppe an.")
	assert_eq(str(ts.call("_preview", mop, DB.talent("tal_mop_stereo"))),
		"Wirkt, wenn Graf Mopsula die Gruppe anführt.")
	Game.state.hero = "mopsula"
	assert_eq(str(ts.call("_preview", mop, DB.talent("tal_mop_schwer_vermittelbar"))),
		"Wirkt sofort: Graf Mopsula führt die Gruppe an.")
	assert_eq(str(ts.call("_preview", kai, DB.talent("tal_kai_weit_ausholen"))), "Wirkt, wenn Kai die Gruppe anführt.")


# --- exploration: the leader's field talents --------------------------------------------------------------------------

## The M3 fixture floor with `hero` leading and `talents` ({member: {talent: rank}}) set before the scene is built.
func _make_scene(hero: String, talents: Dictionary) -> ExplorationScene:
	if _fixture == null:
		_fixture = M3.fixture_game_data()
	if _fixture != null:
		DB.data = _fixture
	Game.new_game(0, "Kai", 4242, &"prime", hero)
	for mid: Variant in talents.keys():
		Game.state.member(str(mid)).talents = (talents[mid] as Dictionary).duplicate()
	var scene: ExplorationScene = (load(SCENE_EXPLORE) as PackedScene).instantiate() as ExplorationScene
	scene.auto_start_battle = false
	add_to_tree(scene)
	await wait_frames(6)
	return scene


## The player `dist` m in front of the sleeping tutorial group f1_g0, looking at it (as test_06a_bark).
func _in_front_of_tutorial(scene: ExplorationScene, dist: float) -> Node3D:
	var actor: Node3D = scene.get_enemy("f1_g0")
	var fwd: Vector3 = actor.call("flat_forward")
	scene.get_player().teleport(actor.global_position + fwd * dist + Vector3(0.0, 0.05, 0.0), Rules.yaw_of(-fwd))
	return actor


func _dispose(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await wait_frames(3)


func test_kai_strikes_farther_with_weit_ausholen() -> void:
	# without the talent the sleeping tutorial group 2.05 m ahead is out of the 1.8 m reach …
	var scene: ExplorationScene = await _make_scene("kai", {"mopsula": {"tal_mop_stereo": 1}})
	assert_eq(scene.get_player().call("strike_reach"), Rules.STRIKE_RANGE, "the Count's Stereo is not Kai's")
	_in_front_of_tutorial(scene, 2.05)
	await wait_frames(3)
	scene.perform_action()
	await wait_frames(40)
	assert_eq(_spy.size(), 0, "1.8 m: the swing misses")
	await _dispose(scene)
	# … with "Weit ausholen" (1250 ‰ → 2.25 m) the same swing hits: preemptive
	var scene2: ExplorationScene = await _make_scene("kai", {"kai": {"tal_kai_weit_ausholen": 1}})
	var body: Node = scene2.get_player()
	assert_eq(body.get("field_range_pm"), 1250)
	assert_eq(body.call("strike_reach"), 2.25)
	_in_front_of_tutorial(scene2, 2.05)
	await wait_frames(3)
	scene2.perform_action()
	assert_almost(float(body.call("cooldown_left")), Rules.STRIKE_COOLDOWN, 0.0001, "the cooldown stays 0.6 s")
	var ok: bool = await wait_until(func() -> bool: return not _spy.is_empty(), MAX_FRAMES)
	assert_true(ok, "2.25 m: the strike starts the battle")
	if ok:
		assert_eq(_spy[0][0], "f1_g0")
		assert_eq(_spy[0][2], Rules.PREEMPTIVE, "sleeping group struck: preemptive")


func test_mopsula_barks_farther_and_sooner_with_her_talents() -> void:
	# Kai's Weit ausholen never widens the Count's bark: 4.5 m is out of the 4 m cone
	var scene: ExplorationScene = await _make_scene("mopsula", {"kai": {"tal_kai_weit_ausholen": 1}})
	assert_eq(scene.get_player().call("bark_reach"), Rules.BARK_RANGE)
	var actor: Node3D = _in_front_of_tutorial(scene, 4.5)
	await wait_frames(3)
	scene.perform_action()
	assert_ne(actor.get("state"), Rules.DAZED, "4.5 m: out of the 4 m bark")
	assert_eq(float(scene.get_player().call("cooldown_left")), Rules.BARK_COOLDOWN, "3 s cooldown")
	await _dispose(scene)
	# Bellen in Stereo (5 m) + Schwer vermittelbar (2.1 s)
	var scene2: ExplorationScene = await _make_scene("mopsula",
		{"mopsula": {"tal_mop_stereo": 1, "tal_mop_schwer_vermittelbar": 1}})
	var body: Node = scene2.get_player()
	assert_eq([body.get("field_range_pm"), body.get("field_cd_pm")], [1250, 700])
	assert_eq(body.call("bark_reach"), 5.0)
	var actor2: Node3D = _in_front_of_tutorial(scene2, 4.5)
	await wait_frames(3)
	scene2.perform_action()
	assert_eq(actor2.get("state"), Rules.DAZED, "4.5 m: inside the 5 m Stereo bark")
	assert_eq(float(body.call("cooldown_left")), 2.1, "Schwer vermittelbar: 3 s × 700 ‰")
	await wait_frames(6)
	assert_eq(_spy.size(), 0, "the bark still never starts a battle")


func test_figur_wechseln_hands_the_field_talents_to_the_new_leader() -> void:
	var scene: ExplorationScene = await _make_scene("kai",
		{"kai": {"tal_kai_weit_ausholen": 1}, "mopsula": {"tal_mop_schwer_vermittelbar": 1}})
	assert_eq(scene.get_player().call("strike_reach"), 2.25)
	assert_eq(scene.get_player().get("field_cd_pm"), 1000)
	Game.state.floor_run.stats["time_used_ticks"] = 30   # the run has started: only check_set applies
	Game.enter_safe_room("sr_t_kiosk")
	assert_true(Game.set_hero("mopsula"), "Figur wechseln in the safe room")
	Game.leave_safe_room()
	scene.on_resume({})
	await wait_frames(3)
	var body: Node = scene.get_player()
	assert_eq(body.get("hero_id"), "mopsula")
	assert_eq([body.get("field_range_pm"), body.get("field_cd_pm")], [1000, 700],
		"the Count's Schwer vermittelbar; Kai's Weit ausholen rests while he follows")
	# a talent picked in a safe room without a switch counts right after the visit
	Game.state.member("mopsula").talents["tal_mop_stereo"] = 1
	scene.on_resume({})
	await wait_frames(2)
	assert_eq(scene.get_player().call("bark_reach"), 5.0, "refreshed on resume")


# --- one integration test per hero ------------------------------------------------------------------------------------

func test_kai_leads_talent_show_switch_replay_and_ai_partner() -> void:
	await _hero_integration("kai")


func test_mopsula_leads_talent_show_switch_replay_and_ai_partner() -> void:
	await _hero_integration("mopsula")


## Recorded run as `hero` → L3 through real-time combats (Game facade, like test_06b_talents) → Talent-Show in the real
## safe room (one choice per member) → "Figur wechseln" → Game.replay_log ≡ live → the AI partner's talents.
func _hero_integration(hero: String) -> void:
	Game.new_game(0, "Kai", RUN_SEED, &"prime", hero)
	assert_eq(Game.hero(), hero)
	assert_true(Game.is_realtime(), "a new game fights in real time")
	var partner: String = Game.partner()
	for enc: String in LEVEL_ENCS:
		if Game.state.member("kai").level >= 3 and Game.state.member("mopsula").level >= 3:
			break
		Game.rest_full_heal()
		assert_eq(_rt_battle(enc), BattleResult.Outcome.VICTORY, "%s won (the AI plays both)" % enc)
	assert_true(Game.state.member("kai").level >= 3 and Game.state.member("mopsula").level >= 3, "both reached L3")
	var sr: String = str(((DB.floor_def(1).layout.get("safe_rooms", []) as Array)[0] as Dictionary)["id"])
	var room: Node = (load(SCENE_SAFE) as PackedScene).instantiate()
	room.call("setup", {"safe_room_id": sr})
	add_to_tree(room)
	await wait_frames(3)
	assert_true(bool(room.call("talent_show_available")), "TALENT-SHOW offered (%s leads)" % hero)
	# the offers do not depend on who leads (seeded by member and level only)
	var offers: Dictionary = {}
	var twin: GameState = GameState.from_dict(Game.state.to_dict())
	twin.hero = partner
	for m: PartyMember in Game.state.party:
		offers[m.id] = Talents.current_offer(Game.state, DB.data, m.id)
		assert_eq(Talents.current_offer(twin, DB.data, m.id), offers[m.id], "offer of %s with either leader" % m.id)
	var n0: int = Game.run_log.cmds().size()
	var ts: Node = room.call("open_talent_show")
	await wait_frames(3)
	assert_eq(str(ts.get("member_id")), "kai", "Kai first (party order), whoever leads")
	var guard: int = 0
	while is_instance_valid(ts) and not ts.is_queued_for_deletion() and guard < 8:
		guard += 1
		await ts.call("pick", 0)
	assert_eq(Talents.open_choices(Game.state, DB.data), 0, "every choice made (%s leads)" % hero)
	var picked: Dictionary = {}
	for c: Dictionary in Game.run_log.cmds().slice(n0):
		var cmd: Dictionary = c["c"]
		if str(cmd["t"]) != "talent":
			continue
		var mid: String = str(cmd["member"])
		var tid: String = str(cmd["id"])
		picked[mid] = tid
		assert_eq(tid, (offers[mid] as PackedStringArray)[0], "%s got the card picked" % mid)
		assert_true(DB.talent(tid).for_members.has(mid), "%s is from the pool of %s" % [tid, mid])
		assert_eq(Talents.rank(Game.state.member(mid), tid), 1, "the talent landed on %s" % mid)
		var other: String = "mopsula" if mid == "kai" else "kai"
		assert_eq(Talents.rank(Game.state.member(other), tid), 0, "… and not on %s" % other)
	assert_eq(picked.keys().size(), 2, "one pick per member, recorded as talent commands")
	# Figur wechseln in the same visit: the field talents follow the new leader
	room.call("activate", "hero")
	assert_eq(Game.hero(), partner, "switched")
	var lead: PartyMember = Game.state.member(partner)
	assert_eq(HeroRules.field_mods(Game.state, DB.data),
		{"range_pm": Talents.field_range_pm(lead, DB.data), "cd_pm": Talents.field_cd_pm(lead, DB.data)})
	await _dispose(room)
	Game.leave_safe_room()
	var live: String = StateHash.of(Game.state)
	var rep: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick())
	assert_eq(rep["final_hash"], live, "Game.replay_log ≡ live: hero choice, talent picks, switch (%s)" % hero)
	assert_eq(rep["mismatch_at"], -1)
	assert_eq(Array(rep["errors"]), [], "no refused command")
	assert_eq(Game.hero(), partner, "the live context is back after the replay")
	_ai_partner(Game.partner())


## One real-time combat of `enc` through the Game facade like the CombatDirector (RtLive.fight: the recorded encounter
## command in the encounter's room, rt_harness poses; the autopilot on for the controlled unit — the AI plays both;
## boundary → inputs → step per tick; Game.end_combat books the result). The outcome, -1 without a combat.
func _rt_battle(enc: String) -> int:
	var cmd: Dictionary = Harness.command_for(enc, Game.hero(), BattleSetup.Advantage.PREEMPTIVE)
	var r: Dictionary = RtLive.fight(cmd, [RtCommand.autopilot(0, str((cmd["rt"] as Dictionary)["ctl"]), true)],
		MAX_COMBAT_TICKS)
	var res: BattleResult = r.get("result", null)
	return res.outcome if res != null else -1


## The AI partner (07 §5: in real time the partner is always the sim's AI) with talents: its unit is built from the
## member WITH its talents (Progression.to_combatant: stats, crit, element, talent_mods; opener_pm from the preemptive
## talent, 07 §9.6) and its first hit deals more than in the same combat without them (counterfactual: same command,
## seed and inputs — none: the controlled unit stands and auto-attacks — on a twin state whose partner has no talents).
func _ai_partner(partner: String) -> void:
	var member: PartyMember = Game.state.member(partner)
	member.talents = (PARTNER_TALENTS[partner] as Dictionary).duplicate()     # test-only: a measurable effect
	Game.rest_full_heal()
	var cmd: Dictionary = Harness.command_for("enc_f1_a2", Game.hero(), BattleSetup.Advantage.PREEMPTIVE)
	var with_t: RtSetup = BattleBridge.make_rt_setup(Game.state, DB.data, cmd, 77)
	var bare: GameState = GameState.from_dict(Game.state.to_dict())
	bare.member(partner).talents = {}
	var without_t: RtSetup = BattleBridge.make_rt_setup(bare, DB.data, cmd, 77)
	assert_not_null(with_t, "a real-time combat")
	if with_t == null or without_t == null:
		return
	var unit: RtUnit = null
	for u: RtUnit in with_t.units:
		if u.side == Combatant.Side.PARTY and u.def_id == partner:
			unit = u
	assert_not_null(unit, "partner unit")
	if unit == null:
		return
	assert_ne(unit.id, with_t.controlled_id, "the partner is not the controlled unit")
	var want: Combatant = Progression.to_combatant(member, DB.data, unit.id, unit.slot)
	for s in StatBlock.Stat.size():
		assert_eq(unit.stats.values[s], want.stats.values[s], "%s stat %d with its talents" % [partner, s])
	assert_eq(unit.talent_mods, Talents.battle_mods(member, DB.data), "talent_mods of the AI partner")
	assert_eq(unit.crit_bonus, want.crit_bonus)
	assert_eq(unit.opener_pm, Talents.preemptive_dmg_pm(member, DB.data), "the preemptive talent (07 §9.6)")
	var dmg_with: int = _first_damage(with_t, unit.id)
	var dmg_without: int = _first_damage(without_t, unit.id)
	assert_gt(dmg_without, 0, "the partner's first hit deals damage")
	assert_gt(dmg_with, dmg_without, "%s's AI hit carries its talents (%d vs %d)" % [partner, dmg_with, dmg_without])


## Steps a fresh RtSim of `setup` without inputs until `actor_id` deals damage; that damage (0 if it never does).
func _first_damage(setup: RtSetup, actor_id: String) -> int:
	var sim: RtSim = RtSim.new(setup, DB.data)
	var events: Array[ActionEvent] = sim.start()
	while true:
		for e: ActionEvent in events:
			if e.type == ActionEvent.Type.DAMAGE and e.actor_id == actor_id and e.amount > 0:
				return e.amount
		if sim.is_finished() or sim.tick() >= MAX_COMBAT_TICKS:
			return 0
		events = sim.step()
	return 0


# --- safe room: desktop and phone touch layout ------------------------------------------------------------------------

## 1280×720 (desktop, 16:9 phones) and 1600×720 (20:9 phones, check.sh --shot 2400x1080 --touch): every menu entry
## and the TALENT-SHOW button have hit areas >= 88 px, 12 px apart, inside the screen and above the chat ticker;
## nothing overlaps the banners or the right-aligned M.O.D. box.
func test_safe_room_layout_fits_desktop_and_phone_touch() -> void:
	var saved: Vector2i = tree.root.size
	var saved_scheme: int = Game.input_scheme
	for res: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		tree.root.size = res
		Game.set_input_scheme(Game.InputScheme.TOUCH if res.x == 1600 else saved_scheme)
		await wait_frames(1)
		Game.new_game(0, "Kai", 78)
		for m: PartyMember in Game.state.party:
			m.level = 3
		var r: Node = (load(SCENE_SAFE) as PackedScene).instantiate()
		r.call("setup", {})
		add_to_tree(r)
		await wait_frames(4)
		var vp: Vector2 = r.get_viewport().get_visible_rect().size
		var buttons: Dictionary = r.get("menu_buttons")
		var rects: Array[Rect2] = []
		var names: PackedStringArray = []
		for id: String in r.call("menu_ids"):
			rects.append((buttons[id] as Control).get_global_rect())
			names.append(id)
		var cta: Control = buttons["talents"] as Control
		assert_true(cta.visible, "TALENT-SHOW shown @ %s" % str(res))
		rects.append(cta.get_global_rect())
		names.append("talents")
		for i in rects.size():
			var a: Rect2 = rects[i]
			assert_true(a.size.y >= UiTheme.TOUCH_HIT and a.size.x >= UiTheme.TOUCH_HIT,
				"%s hit area %s >= 88 @ %s" % [names[i], str(a.size), str(res)])
			assert_true(a.position.x >= 24.0 - 0.5 and a.end.x <= vp.x - 24.0 + 0.5 and a.position.y >= 24.0 - 0.5,
				"%s inside the safe frame @ %s" % [names[i], str(res)])
			assert_lt(a.end.y, vp.y - 24.0 - 20.0, "%s above the chat ticker @ %s" % [names[i], str(res)])
			for j in range(i + 1, rects.size()):
				var b: Rect2 = rects[j]
				var gap: float = maxf(maxf(b.position.x - a.end.x, a.position.x - b.end.x),
					maxf(b.position.y - a.end.y, a.position.y - b.end.y))
				assert_true(gap >= 12.0 - 0.01, "%s / %s are %.1f px apart (>= 12) @ %s" % [names[i], names[j], gap,
					str(res)])
		var leave: Rect2 = (buttons["leave"] as Control).get_global_rect()
		assert_true(leave.end.y <= vp.y and leave.end.x <= vp.x, "Weiter on screen without scrolling @ %s" % str(res))
		var c_rect: Rect2 = cta.get_global_rect()
		var mod_top: float = vp.y - 24.0 - ModDialogScript.BOX_BOTTOM - 2.0 * ModDialogScript.BOX_SIZE.y
		assert_lt(c_rect.end.y, mod_top, "TALENT-SHOW clear of the M.O.D. box @ %s" % str(res))
		var heal: Control = r.get("_heal_banner") as Control
		assert_false(heal.get_global_rect().intersects(c_rect), "heal banner and TALENT-SHOW apart @ %s" % str(res))
		var banner: Control = r.get("_status_panel") as Control
		r.call("_set_status", "Jetzt führt: Graf Mopsula.", UiTheme.C_GOLD)
		await wait_frames(2)
		assert_false(banner.get_global_rect().intersects(c_rect), "status banner and TALENT-SHOW apart @ %s" % str(res))
		for k in rects.size() - 1:
			assert_false(banner.get_global_rect().intersects(rects[k]), "banner off the menu @ %s" % str(res))
		r.queue_free()
		await wait_frames(2)
	Game.set_input_scheme(saved_scheme)
	tree.root.size = saved
	await wait_frames(1)
