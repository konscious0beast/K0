extends RefCounted
## Scenario builders of the R3 HUD tests and captures: an RtSetup and a HudSim with party and enemies from a GameData
## (the rt_min fixture data in tests, the real DB in captures), built through public APIs only (GameState.create_new,
## Progression.to_combatant, Combatant.create_enemy, RtUnit.from_snapshot, RtBalance.from_data). The bars follow
## 07 §4.1–4.3 (the bar grows with the level; tutorial: slot 1 + SHOW only). Private fixture (no class_name).

const HudSim := preload("res://tests/fixtures/rt_hud/hud_sim.gd")

## Slot → (skill, unlock level) of 07 §4.2 / §4.3 (base skills; variants are a loadout choice).
const BARS: Dictionary = {
	"kai": {1: ["skl_kai_heavy_swing", 1], 2: ["skl_kai_taunt", 2], 3: ["skl_kai_leash_trip", 3],
		4: ["skl_kai_sweep", 4], 5: ["skl_stunt_kai_suplex", 1]},
	"mopsula": {1: ["skl_mop_noble_flame", 1], 2: ["skl_mop_holy_lick", 1], 3: ["skl_mop_frost_sneeze", 2],
		4: ["skl_mop_thunder_bark", 3], 5: ["skl_stunt_mop_entrance", 1]},
}
## Partner-Spezial (07 §4.1): Kai as partner from level 2, Graf Mopsula from level 1.
const SPECIALS: Dictionary = {"kai": ["skl_kai_taunt", 2], "mopsula": ["skl_mop_holy_lick", 1]}
const TUTORIAL_STEPS: PackedStringArray = ["target", "bar1", "show", "dodge"]
const POTION: String = "itm_bandage"


## opts: {"hero": "kai" | "mopsula" (controlled), "level": int (both), "enemies": [EnemyDef ids], "boss": bool,
## "tutorial": bool, "encounter": String, "items": {item: count} (default bandages; {} = no slot 6), "advantage": int}.
static func build(data: GameData, opts: Dictionary = {}) -> HudSim:
	var hero: String = str(opts.get("hero", "kai"))
	var level: int = int(opts.get("level", 1))
	var tutorial: bool = bool(opts.get("tutorial", false))
	var bal: RtBalance = RtBalance.from_data(data)
	var st: GameState = GameState.create_new(data, 0, GameState.DEFAULT_NAME, 4242)
	st.hero = hero
	var s: RtSetup = RtSetup.new()
	s.encounter_id = str(opts.get("encounter", "enc_hud_test"))
	s.group_id = "hud_g1"
	s.seed = 77
	s.is_boss = bool(opts.get("boss", false))
	s.can_flee = not s.is_boss and not tutorial
	s.tutorial = tutorial
	s.floor_index = 1
	s.advantage = int(opts.get("advantage", 0)) as BattleSetup.Advantage
	s.balance = bal
	s.items = (opts.get("items", {POTION: 3}) as Dictionary).duplicate() if not tutorial else {}
	s.tutorial_steps = TUTORIAL_STEPS.duplicate() if tutorial else PackedStringArray()
	s.cell = Vector2i(2, 1)
	s.geo = {"r": 480, "doors": 0, "closed": s.is_boss, "blockers": []}
	var party: Array[Combatant] = []
	for i in st.party.size():
		var m: PartyMember = st.party[i]
		m.level = level
		var c: Combatant = Progression.to_combatant(m, data, "p%d" % i, i)
		if c == null:
			continue
		var u: RtUnit = RtUnit.from_snapshot(c.to_dict(), data)
		u.hp = c.max_hp()
		u.mp = c.max_mp()
		u.level = level
		u.driver = RtUnit.Driver.PLAYER if m.id == hero else RtUnit.Driver.AI
		u.x = -150 * i
		u.z = 300 + 100 * i
		u.bar = bar_for(m.id, level, tutorial, not s.items.is_empty())
		if m.id == hero:
			s.controlled_id = u.id
		party.append(u)
		s.units.append(u)
	s.party = party
	var ids: Array = opts.get("enemies", ["enm_kanalratte", "enm_kanalratte"]) as Array
	s.enemy_ids = PackedStringArray(ids)
	for i in ids.size():
		var edef: EnemyDef = data.enemy(str(ids[i]))
		var u2: RtUnit = RtUnit.from_snapshot(Combatant.create_enemy(edef, "e%d" % i, i).to_dict(), data)
		u2.hp = u2.max_hp()
		u2.x = -250 + 250 * i
		u2.z = -300
		u2.driver = RtUnit.Driver.AI
		s.units.append(u2)
	s.presets = {}
	for u3: RtUnit in s.units:
		if u3.side == Combatant.Side.PARTY and u3.id != s.controlled_id:
			s.presets[u3.id] = {"preset": "support" if u3.def_id == "mopsula" else "attack",
				"tog": RtVocab.RT_TOGGLE_DEFAULTS.duplicate()}
	var sim: HudSim = HudSim.new(s, data)
	if not tutorial:
		for u4: RtUnit in sim.units():
			if u4.side == Combatant.Side.PARTY and u4.id != s.controlled_id:
				var sp: Array = SPECIALS.get(u4.def_id, ["", 99]) as Array
				if level >= int(sp[1]):
					sim.specials[u4.id] = str(sp[0])
	return sim


## The bar of 07 §4.1 for `def_id` at `level`: unlocked slots only; tutorial: slot 1 + SHOW; slot 6 with a potion.
static func bar_for(def_id: String, level: int, tutorial: bool, potion: bool) -> Dictionary:
	var out: Dictionary = {}
	var b: Dictionary = BARS.get(def_id, {}) as Dictionary
	for slot: int in b.keys():
		var e: Array = b[slot]
		if level < int(e[1]):
			continue
		if tutorial and slot != 1 and slot != 5:
			continue
		out[slot] = str(e[0])
	if potion and not tutorial:
		out[6] = POTION
	return out


## Gives `u` a status `sid` with `left` of `total` ticks (-1 = until the end) and `stacks`.
static func add_status(sim: RtSim, data: GameData, u: RtUnit, sid: String, left: int, total: int,
		stacks: int = 1) -> void:
	if u == null or not data.has_id("statuses", sid):
		return
	var now: int = sim.tick()
	var st: RtStatus = RtStatus.new(data.status(sid), now + left if left >= 0 else -1, "")
	st.applied_at = now + left - total if left >= 0 else now
	st.stacks = stacks
	u.statuses.append(st)
