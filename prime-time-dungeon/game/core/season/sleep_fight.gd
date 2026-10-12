extends RefCounted
## Private helper of SleepResolver (02_TECH §0.3: no class_name; preloaded as SleepFight): the fight of a sleeper's
## encounter (09 §5.3; 07 CR-32 e). RtSim headless with the real combat rules: the patrol strikes first (AMBUSH,
## "Hinterhalt!" — the figures were asleep), both figures on autopilot with the tactic of the logout and their own
## switches, the patrol's enemies on the floor's level (EnemyLevels, in BattleBridge). An aufgebrachte Streife (the
## night's roll, SleepResolver.ANGRY_PM) hits ANGRY_DMG_PM harder; a Helfer:in keeping watch takes half of the damage.
## The resolver only reads the sim: it steps it, keeps the autopilot on the controlled figure (also after "control
## follows life"), and halts it once — the party under 25 % of its summed max HP — for the retreat roll (careful 80 %,
## else 60 %): a success ends the fight without loot (a flight made from what the sim shows: HP, MP, items used, stolen
## credits, the enemies beaten so far); a failure lets it run to its end. A patrol that has not won after MAX_TICKS
## (30 s) — and no failed retreat roll — moves on (the same flight: no loot). Pure: no autoloads, no randomness of its
## own (the seeds come from the night's stream).

const PM: int = 1000
const RETREAT_BELOW_PM: int = 250           # party HP below 25 % of the summed max HP → the retreat roll (09 §5.3)
const RETREAT_PM: Dictionary = {"careful": 800, "support": 600, "attack": 600}
## An aufgebrachte Streife's damage in ‰ (09 ST1-G, G-4): high enough that it brings a band-typical party under the 25 %
## of the retreat (test_09_sleep holds the death rates in their bands); a normal patrol hits as the floor's groups do.
const ANGRY_DMG_PM: int = 8000
## A Helfer:in keeping watch fights along (09 §5.3): until the guest unit p2 exists (07 CR-32 c) the patrol's damage is
## halved instead — she takes half of it — and it is never aufgebracht.
const WATCH_DMG_PM: int = 500
const MAX_TICKS: int = 900                  # 30 s: an undecided patrol moves on
## Where the figures lie in the room (room-local cm, yaw 0–255), by battle slot.
const POSES: Array = [[-80, 60, 128], [90, 120, 128], [0, 200, 128], [180, 40, 128]]
## End of a fight: the sim decided (won, lost, fled — a door lane or the time limit of the sim), the retreat roll
## succeeded, the patrol moved on; none: no set (never for a patrol).
const ENDS: PackedStringArray = ["won", "lost", "fled", "retreat", "moved_on", "none"]


## The fight: `o` = {"enc", "cell" (Vector2i), "tactic", "angry" (bool), "watched" (bool), "seed" (the battle seed),
## "retreat" (0–999: the roll)}. Returns {"result": BattleResult (null without a set), "end" (ENDS), "rolled" (the
## retreat was rolled), "ticks"}.
static func run(state: GameState, data: GameData, o: Dictionary) -> Dictionary:
	var setup: RtSetup = BattleBridge.make_rt_setup(state, data, command(state, data, o), int(o.get("seed", 0)))
	if setup == null:
		return {"result": null, "end": "none", "rolled": false, "ticks": 0}
	setup.enemy_dmg_mult = setup.enemy_dmg_mult * float(damage_pm(o)) / float(PM)
	var sim: RtSim = RtSim.new(setup, data)
	sim.submit(RtCommand.autopilot(0, sim.controlled_id(), true))
	var tactic: String = str(o.get("tactic", "careful"))
	var rolled: bool = false
	var failed: bool = false
	var end: String = ""
	var guard: int = sim.bal.i("MAX_COMBAT_TICKS") + 2
	while not sim.is_finished() and guard > 0:
		guard -= 1
		for e: ActionEvent in sim.step():
			if e.type == ActionEvent.Type.CONTROL_CHANGED and not sim.is_finished():
				sim.submit(RtCommand.autopilot(sim.tick(), sim.controlled_id(), true))
		if sim.is_finished():
			break
		if not rolled and party_pm(sim) < RETREAT_BELOW_PM:
			rolled = true
			if int(o.get("retreat", 0)) < int(RETREAT_PM.get(tactic, 600)):
				end = "retreat"
				break
			failed = true
		if not failed and sim.tick() >= MAX_TICKS:
			end = "moved_on"
			break
	var result: BattleResult = sim.result if end == "" and sim.result != null else flight(sim)
	if end == "":
		match result.outcome:
			BattleResult.Outcome.VICTORY:
				end = "won"
			BattleResult.Outcome.DEFEAT:
				end = "lost"
			_:
				end = "fled"
	return {"result": result, "end": end, "rolled": rolled, "ticks": sim.tick()}


## The patrol's damage in ‰: aufgebracht ANGRY_DMG_PM (never while watched), a watch halves it.
static func damage_pm(o: Dictionary) -> int:
	if bool(o.get("watched", false)):
		return WATCH_DMG_PM
	return ANGRY_DMG_PM if bool(o.get("angry", false)) else PM


## The encounter command of the fight (the shape of a real one, 07 §10.1; never recorded): the patrol `o.enc` in the
## room `o.cell`, AMBUSH, the figures lying in the room (POSES), the group entering through the door farthest from
## them (RtGeo.group_anchor), both figures with the tactic `o.tactic` and their own switches.
static func command(state: GameState, data: GameData, o: Dictionary) -> Dictionary:
	var cell: Vector2i = o.get("cell", Vector2i.ZERO)
	var tactic: String = str(o.get("tactic", "careful"))
	var members: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and data.has_id("party", m.id):
			members.append(m)
	members.sort_custom(func(a: PartyMember, b: PartyMember) -> bool:
		return data.party_member(a.id).battle_slot < data.party_member(b.id).battle_slot)
	var party: Array = []
	var presets: Dictionary = {}
	var ctl: String = ""
	for i in members.size():
		var m: PartyMember = members[i]
		var uid: String = "p%d" % data.party_member(m.id).battle_slot
		if m.id == state.hero:
			ctl = uid
		party.append({"u": uid, "p": (POSES[mini(i, POSES.size() - 1)] as Array).duplicate()})
		var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
		for k: String in RtVocab.RT_TOGGLES:
			if m.rt_toggles.has(k):
				tog[k] = bool(m.rt_toggles[k])
		presets[uid] = {"preset": tactic if RtVocab.RT_PRESETS.has(tactic) else "careful", "tog": tog}
	if ctl == "" and not party.is_empty():
		ctl = str((party[0] as Dictionary)["u"])
	return {"t": "encounter", "enc": str(o.get("enc", "")), "adv": BattleSetup.Advantage.AMBUSH, "group": "",
		"rt": {"v": RtCommand.RT_BLOCK_VERSION, "cell": [cell.x, cell.y], "ctl": ctl, "party": party, "groups": [],
		"presets": presets, "auto": true, "retarget": true, "open": {},
		"diff": "vorabend" if state.difficulty == &"vorabend" else "prime"}}


## The party's HP in ‰ of its summed max HP.
static func party_pm(sim: RtSim) -> int:
	var hp: int = 0
	var top: int = 0
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.PARTY:
			hp += maxi(0, u.hp)
			top += u.max_hp()
	return hp * PM / top if top > 0 else 0


## A flight (FLED) as the sim shows it now — what BattleBridge.apply_result books for one: the party's HP and MP, the
## items used, gift credits, the credits thieves keep, the enemies beaten so far (bestiary, kills), the weaknesses
## found, the party's KOs. No EXP, no loot.
static func flight(sim: RtSim) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = BattleResult.Outcome.FLED
	var setup: RtSetup = sim.setup
	r.encounter_id = setup.encounter_id
	r.group_id = setup.group_id
	r.advantage = int(setup.advantage)
	var t: Dictionary = sim.tally
	for id: Variant in (t.get("killed", []) as Array):
		var e: RtUnit = sim.unit(str(id))
		if e != null:
			r.defeated_ids.append(e.def_id)
	r.kills = (t.get("killed", []) as Array).size()
	var thieves: Dictionary = t.get("thieves", {})
	var keys: Array = thieves.keys()
	keys.sort()
	for k: Variant in keys:
		r.credits_stolen += int((thieves[k] as Dictionary).get("amount", 0))
	r.credits_delta = int(t.get("credits_delta", 0))
	r.item_delta = (t.get("item_delta", {}) as Dictionary).duplicate(true)
	var wf: Dictionary = t.get("weak_found", {})
	var wkeys: Array = wf.keys()
	wkeys.sort()
	for k: Variant in wkeys:
		r.weak_found[str(k)] = PackedStringArray(wf[k])
	r.party_kos = int(t.get("party_kos", 0))
	r.potions_used = int(t.get("potions_used", 0))
	r.items_used = r.potions_used
	r.damage_taken = int(t.get("damage_taken", 0))
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.PARTY:
			r.party_hp[u.def_id] = maxi(0, u.hp)
			r.party_mp[u.def_id] = maxi(0, u.mp)
	r.duration_ticks = sim.tick()
	return r
