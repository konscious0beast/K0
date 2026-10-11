extends TestCase
## R3 hint cards (07 §2.13, E21 / E28 / E29, §12.5): the tutorial steps (target → bar1 → show after the first party
## hit → dodge at the first enemy telegraph) and the first-time hints, each through CombatDirector.pause_for_hint /
## resume — no tick while a card shows, the hint recorded at the held ct; once per save (GameState.flags["rt_hints"]),
## at most one first-time card per combat, partner_special never in the tutorial, the interrupter key per hero (Kai 3,
## Graf Mopsula 4), none with combat_hints off, in league / event runs.

const HudRig := preload("res://tests/fixtures/rt_hud/hud_rig.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const FakeSim := preload("res://tests/fixtures/rt_min/fake_rt_sim.gd")
const HintCards := preload("res://scenes/combat/ui/hint_cards.gd")

var _hints_setting: bool = true


func before_each() -> void:
	Game.new_game(0, "Kai", 11)
	_hints_setting = Game.settings.combat_hints
	Game.settings.combat_hints = true
	HintCards.boss_attempt_lost = false


func after_each() -> void:
	Game.settings.combat_hints = _hints_setting
	HintCards.boss_attempt_lost = false


## Game.combat_hint (R2 live, R5a RunSim) marks the card as shown in the save; the director double does the same.
func _record_hints(dir: Node) -> void:
	for h: Dictionary in dir.get("hints") as Array:
		var f: Dictionary = Game.state.flags.get("rt_hints", {}) as Dictionary
		f[str(h["id"])] = true
		Game.state.flags["rt_hints"] = f


func _event(t: ActionEvent.Type, actor: String, target: String = "", amount: int = 0) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(t)
	e.actor_id = actor
	e.target_id = target
	e.amount = amount
	return e


func _cmd(t: String, extra: Dictionary) -> Dictionary:
	var d: Dictionary = {"t": t, "ct": 0, "u": "p0"}
	d.merge(extra, true)
	return d


func test_tutorial_steps_pause_the_sim() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 1, "tutorial": true})
	sim.call("set_tick", 5)
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var hud: Node = r["hud"]
	var dir: Node = r["director"]
	var cards: Node = hud.get("hints")
	assert_eq(cards.call("current"), "target", "the first card: choose a target")
	assert_true(bool(dir.get("paused")), "pause_for_hint")
	assert_eq((dir.get("hints") as Array)[0], {"id": "target", "ct": 5}, "recorded at the held ct")
	assert_eq(int(dir.call("advance", 30)), 0, "no tick while the card shows")
	assert_eq(sim.tick(), 5)
	hud.call("send", RtCommand.target(5, "p0", "e0"))
	assert_eq(cards.call("current"), "bar1", "target chosen → bar1 at once")
	assert_eq(int(dir.get("resumes")), 1, "resume() for the closed card")
	await wait_frames(1)
	var s1: Dictionary = (hud.get("bar") as Control).call("state_of", 1)
	assert_true(bool(s1.get("assist", false)), "slot 1 highlighted for the card")
	hud.call("send", RtCommand.ability(5, "p0", "skl_kai_heavy_swing", "e0"))
	assert_eq(cards.call("current"), "", "slot 1 used → closed")
	assert_eq(int(dir.call("advance", 10)), 10, "the combat runs again")
	hud.call("on_event", _event(ActionEvent.Type.DAMAGE, "p1", "e0", 12))
	assert_eq(cards.call("current"), "show", "after the first party hit: SHOW")
	hud.call("send", RtCommand.ability(15, "p0", "skl_stunt_kai_suplex", "e0"))
	assert_eq(cards.call("current"), "", "SHOW used → closed")
	var tele: ActionEvent = _event(ActionEvent.Type.TELEGRAPH_START, "e1")
	hud.call("on_event", tele)
	assert_eq(cards.call("current"), "dodge", "the first enemy telegraph: dodge")
	hud.call("any_input", null)
	assert_eq(cards.call("current"), "dodge", "not closed by an input in its first moment")
	Engine.time_scale = 8.0
	await wait_until(func() -> bool: return float(cards.get("_since")) >= HintCards.MIN_SHOW_SEC, 600)
	Engine.time_scale = 1.0
	hud.call("any_input", null)
	assert_eq(cards.call("current"), "", "any input closes the dodge card")
	var ids: Array = (dir.get("hints") as Array).map(func(h: Dictionary) -> String: return str(h["id"]))
	assert_eq(ids, ["target", "bar1", "show", "dodge"], "the four tutorial steps in order (E28)")
	assert_eq(int(dir.get("resumes")), 4)


func test_cards_once_per_save() -> void:
	var data: GameData = FakeSim.load_data()
	var r: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 1, "tutorial": true}), data)
	await wait_frames(2)
	_record_hints(r["director"])
	var r2: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 1, "tutorial": true}), data)
	await wait_frames(2)
	assert_eq(((r2["hud"] as Node).get("hints") as Node).call("current"), "bar1",
		"'target' was shown in this save: the second tutorial combat starts with the next step")


func test_one_first_time_card_per_combat() -> void:
	var data: GameData = FakeSim.load_data()
	var sim: RtSim = HudScenarios.build(data, {"level": 4, "enemies": ["enm_rt_test_caster", "enm_kanalratte"]})
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var hud: Node = r["hud"]
	var cards: Node = hud.get("hints")
	assert_eq(cards.call("current"), "partner_special", "first combat with the button: its card")
	hud.call("send", _cmd("partner_special", {"u": "p1"}))
	Engine.time_scale = 8.0
	await wait_frames(30)
	Engine.time_scale = 1.0
	cards.call("dismiss")
	assert_eq(cards.call("current"), "")
	var cast: ActionEvent = _event(ActionEvent.Type.CAST_START, "e0", "p0")
	cast.skill_id = "skl_e_test_hex"
	cast.rt = {"end": 60, "worthy": 1}
	hud.call("on_event", cast)
	assert_eq(cards.call("current"), "", "at most one first-time card per combat")
	_record_hints(r["director"])
	var r2: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 4, "enemies": ["enm_rt_test_caster"]}),
		data)
	await wait_frames(2)
	var cards2: Node = (r2["hud"] as Node).get("hints")
	assert_eq(cards2.call("current"), "", "partner_special already seen")
	(r2["hud"] as Node).call("on_event", cast)
	assert_eq(cards2.call("current"), "interrupt", "the next combat: the interrupt card")
	assert_true(str(cards2.call("text")).contains("3"), "Kai interrupts with 3")
	assert_eq(int(cards2.call("focus_slot")), 3, "slot 3 highlighted")


func test_interrupter_key_per_hero() -> void:
	var data: GameData = real_data()
	Game.state.flags["rt_hints"] = {"partner_special": true}
	var kai: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 4}), data)
	await wait_frames(2)
	assert_eq(int(((kai["hud"] as Node).get("hints") as Node).call("_interrupt_slot")), 3, "Kai: Leinen-Fallstrick 3")
	var mop: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 4, "hero": "mopsula"}), data)
	await wait_frames(2)
	var cards: Node = (mop["hud"] as Node).get("hints")
	assert_eq(int(cards.call("_interrupt_slot")), 4, "Graf Mopsula: Donnerbellen 4")
	var cast: ActionEvent = _event(ActionEvent.Type.CAST_START, "e0", "p1")
	cast.rt = {"worthy": 1}
	(mop["hud"] as Node).call("on_event", cast)
	assert_eq(cards.call("current"), "interrupt")
	assert_true(str(cards.call("text")).contains("4"), "the card names key 4")


func test_interrupt_card_waits_for_a_ready_interrupter() -> void:
	var data: GameData = FakeSim.load_data()
	Game.state.flags["rt_hints"] = {"partner_special": true}
	var sim: RtSim = HudScenarios.build(data, {"level": 4, "enemies": ["enm_rt_test_caster"]})
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 120, 360)
	var r: Dictionary = HudRig.make(self, sim, data)
	await wait_frames(2)
	var cards: Node = (r["hud"] as Node).get("hints")
	var cast: ActionEvent = _event(ActionEvent.Type.CAST_START, "e0", "p0")
	cast.rt = {"worthy": 1}
	(r["hud"] as Node).call("on_event", cast)
	assert_eq(cards.call("current"), "", "slot 3 on cooldown: no card that asks for it")
	sim.call("set_cd", "p0", "skl_kai_leash_trip", 0, 0)
	(r["hud"] as Node).call("on_event", cast)
	assert_eq(cards.call("current"), "interrupt", "the next worthy cast")


func test_partner_special_never_in_the_tutorial() -> void:
	var data: GameData = FakeSim.load_data()
	Game.state.flags["rt_hints"] = {"target": true, "bar1": true, "show": true, "dodge": true}
	var r: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 1, "tutorial": true}), data)
	await wait_frames(2)
	var cards: Node = (r["hud"] as Node).get("hints")
	assert_eq(cards.call("current"), "", "no Partner-Spezial card (no button) in the tutorial fight")
	assert_false((cards.call("shown_ids") as PackedStringArray).has("partner_special"))


func test_no_cards_when_switched_off_or_in_leagues() -> void:
	var data: GameData = FakeSim.load_data()
	Game.settings.combat_hints = false
	var r: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 1, "tutorial": true}), data)
	await wait_frames(2)
	assert_eq(((r["hud"] as Node).get("hints") as Node).call("current"), "", "Kampf-Hinweise aus: no card")
	assert_false(bool((r["director"] as Node).get("paused")), "and no pause")
	Game.settings.combat_hints = true
	var league: RtSim = HudScenarios.build(data, {"level": 1, "tutorial": true})
	league.setup.rules = {"hints": false}
	var r2: Dictionary = HudRig.make(self, league, data)
	await wait_frames(2)
	assert_eq(((r2["hud"] as Node).get("hints") as Node).call("current"), "", "run rule hints false (league)")
	var mode: StringName = Game.mode
	Game.mode = &"event_offline"
	assert_false(HintCards.allowed(HudScenarios.build(data, {"level": 1})), "event runs: no cards")
	Game.mode = mode


func test_partner_tactic_after_a_lost_boss_attempt() -> void:
	var data: GameData = FakeSim.load_data()
	Game.state.flags["rt_hints"] = {"partner_special": true}
	HintCards.boss_attempt_lost = true
	var r: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 3, "boss": true,
		"enemies": ["enm_rt_test_boss"]}), data)
	await wait_frames(2)
	var hud: Node = r["hud"]
	assert_eq((hud.get("hints") as Node).call("current"), "partner_tactic", "E29: after a lost boss attempt")
	assert_true(bool((hud.get("tactic") as Node).call("is_open")), "the tactic panel opens with it")


func test_card_texts_are_german_and_name_the_input() -> void:
	var data: GameData = FakeSim.load_data()
	var r: Dictionary = HudRig.make(self, HudScenarios.build(data, {"level": 1, "tutorial": true}), data)
	await wait_frames(2)
	var cards: Node = (r["hud"] as Node).get("hints")
	assert_eq(cards.call("default_text", "target", false, false), "Wähle ein Ziel — antippen oder Tab.")
	assert_eq(cards.call("default_text", "target", true, false), "Wähle ein Ziel — tipp einen Gegner an.")
	assert_eq(cards.call("default_text", "dodge", false, false), "Rote Fläche? Raus da!")
	assert_true(str(cards.call("default_text", "bar1", false, false)).contains("1"), "keyboard: 1")
	cards.set("ctx", {"pad": true, "keys": {1: "A"}, "special_key": "Links"})
	assert_true(str(cards.call("default_text", "bar1", false, true)).contains("A"), "pad: the key cap of the scheme")
	assert_eq((cards.call("key_hints", "partner_special", false, true) as Array)[0][0], "Links", "D-pad left")
	for id: String in ["target", "bar1", "show", "dodge"] + Array(RtVocab.HINT_IDS):
		assert_ne(str(cards.call("default_text", id, false, false)), "", "text for %s" % id)
		assert_gt((cards.call("key_hints", id, false, false) as Array).size(), 0, "key row for %s" % id)
