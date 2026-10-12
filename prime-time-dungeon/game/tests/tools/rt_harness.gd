extends RefCounted
## Balance harness of the real-time combat (07 §11.4, R4; private test helper, no class_name — loaded with load() by
## tests/tools/rt_harness_main.gd and preload by test_r4_rt_balance): builds for every encounter of floor 1 a GameState
## like the campaign has it at that point — level of the zone (A 1–2, B 3, C 4–5, D 6–7, bosses 5 / 7), the gear of the
## zone purchase plan, the bot's talent picks (first offer, 06 §2.2), the hero (`kai` | `mopsula`) and the
## Unterhosen-Liga tier (1: the hero without armor & accessory, 2: both) — records the encounter command of 07 §10.1 in
## the real room of the group (BattleBridge.make_rt_setup: set radius, doors, the waggon of Gleis 9, show-boss mods,
## talents, liga) and plays it on the real RtSim with RtBotPlayer for the controlled unit (07 §5.7 profiles) and the
## AI partner on its default tactic (or `partner_preset`). No scene, no autoload state; deterministic: fight n uses the
## seeds SeedUtil.derive(SEED, "harness", n) (battle), …"harness_state" (talent offers) and …"harness_bot" (bot).
##
## Regular fights and the show boss run without consumables (07 §11.1 "HP-Verlust ohne Tränke"), bosses with the boss
## kit (3 consumables per combat at most, 07 §3.11). Output per series: losses with a Wilson 95 % interval, duration
## and HP-loss quantiles, potions, KOs, interrupt rates (person / AI) of interrupt-worthy casts, the share of boss
## telegraph impacts that hit a party member that could have dodged (07 §11.1), the bot's GCD use.
##
## Sequence mode (sequence(), `--sequence`): the encounters of the floor in zone order between the safe rooms, the party
## carried over (HP / MP, KOs at 1 HP after a win), the out-of-combat regeneration of 07 §2.7 for the walking time
## between two fights (SEQ_WALK_SEC), the Werbepause (+15 % MP after a win), full heal in the safe rooms; the bot
## drinks from a shared inventory. It reports how many fights in a row the party wins without a potion and the heal
## items per floor (07 §11.1, gate of the regeneration values).

const Bot := preload("res://tests/tools/rt_bot_player.gd")
const FixedMath := preload("res://core/stats/fixed_math.gd")

const SEED: int = 4242
const SR: StringName = &"sr_kiosk"
## encounter → [party level, gear, item kit, advantage] (07 §11.3 / §11.4 plan; gear as the full-run bot buys it).
const PLAN: Dictionary = {
	"enc_f1_a1_tutorial": [1, "start", "none", BattleSetup.Advantage.PREEMPTIVE],
	"enc_f1_a2": [2, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_a3": [2, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_a4": [2, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_a_rare": [2, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_b1": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_b2": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_b3": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_b4": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_evt_pigeons": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_evt_slime": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_e1_showboss": [3, "start", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_c1": [4, "mid", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_c2": [5, "mid", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_c3": [5, "mid", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_boss_hausmeister": [5, "mid", "boss", BattleSetup.Advantage.NORMAL],
	"enc_f1_d1": [6, "late", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_d2": [7, "late", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_d3": [6, "late", "none", BattleSetup.Advantage.NORMAL],
	"enc_f1_boss_rattenkoenigin": [7, "late", "boss", BattleSetup.Advantage.NORMAL],
}
## The order of the floor (zone A → B → C → Hausmeister → D → Königin; tutorial first, show boss in zone B).
const ORDER: PackedStringArray = ["enc_f1_a1_tutorial", "enc_f1_a2", "enc_f1_a3", "enc_f1_a4", "enc_f1_a_rare",
	"enc_f1_b1", "enc_f1_b2", "enc_f1_b3", "enc_f1_b4", "enc_f1_evt_pigeons", "enc_f1_evt_slime", "enc_e1_showboss",
	"enc_f1_c1", "enc_f1_c2", "enc_f1_c3", "enc_f1_boss_hausmeister", "enc_f1_d1", "enc_f1_d2", "enc_f1_d3",
	"enc_f1_boss_rattenkoenigin"]
const BOSSES: PackedStringArray = ["enc_f1_boss_hausmeister", "enc_f1_boss_rattenkoenigin"]
const SHOW_BOSS: String = "enc_e1_showboss"
## The 13 regular encounters the regular bands of 07 §11.1 / §11.3 apply to (the tutorial, the event fights and the
## rarity have their own rhythm).
const REGULAR: PackedStringArray = ["enc_f1_a2", "enc_f1_a3", "enc_f1_a4", "enc_f1_b1", "enc_f1_b2", "enc_f1_b3",
	"enc_f1_b4", "enc_f1_c1", "enc_f1_c2", "enc_f1_c3", "enc_f1_d1", "enc_f1_d2", "enc_f1_d3"]
## The bands of 07 §11.1 for the profile `typical` (band_report): duration median (s) and HP-loss median (%, no
## potions) at Liga 0 — for the regular encounters the HP loss as the median over the 13 encounters (the typical fight;
## single encounters may lie lower, §11.3) —, first-try losses (%) per Liga tier [0, 1, 2] (Liga 0: the harness band of
## §11.1; tiers 1 / 2: 06 §4.10), interrupted interrupt-worthy boss casts (% ≥) and party hits by boss telegraphs (% ≤).
const BANDS: Dictionary = {
	"regular": {"sec": [15.0, 35.0], "hp": [20.0, 35.0]},
	"enc_e1_showboss": {"sec": [20.0, 40.0], "hp": [20.0, 40.0], "loss": [[0.0, 5.0]]},
	"enc_f1_boss_hausmeister": {"sec": [150.0, 210.0], "loss": [[10.0, 30.0], [0.0, 40.0], [0.0, 55.0]], "intr": 60.0,
		"tele": 25.0},
	"enc_f1_boss_rattenkoenigin": {"sec": [180.0, 240.0], "loss": [[25.0, 45.0], [0.0, 55.0], [0.0, 80.0]],
		"intr": 60.0, "tele": 25.0},
}
## Bands across series: the median of the 13 regular medians (s), the step of the first-try boss losses from Liga 0 to
## Liga 1 (points; E31, R5b: 5–15 per hero and boss — measurably harder, not a cliff; the queen's Liga 2 ≤ 80 % above),
## and the floor sequence's medians — heal items per floor, fights a fresh party wins before its first heal item
## (07 §11.1 "2–3 Kämpfe zwischen zwei Safe Rooms ohne Tränke").
const BAND_REGULAR_MEDIAN: Array = [20.0, 25.0]
const BAND_LIGA_STEP: float = 5.0
const BAND_LIGA_STEP_MAX: float = 15.0
const BAND_SEQ_ITEMS: Array = [4.0, 9.0]
const BAND_SEQ_STREAK: Array = [2.0, 3.0]
## Gear per point of the floor (the GEAR of the former CTB balance test: start kit; safe room 1 + metal chests A / B;
## after the Hausmeister: fire axe, key ring, signet collar, gas mask). [weapon, armor, accessory].
const GEAR: Dictionary = {
	"start": {"kai": ["itm_wpn_mop", "itm_arm_hoodie", ""],
		"mopsula": ["itm_wpn_collar_leather", "itm_arm_pug_sweater", ""]},
	"mid": {"kai": ["itm_wpn_pipe_wrench", "itm_arm_safety_vest", ""],
		"mopsula": ["itm_wpn_collar_studded", "itm_arm_velvet_cape", ""]},
	"late": {"kai": ["itm_wpn_fire_axe", "itm_arm_safety_vest", "itm_acc_key_ring"],
		"mopsula": ["itm_wpn_collar_signet", "itm_arm_velvet_cape", "itm_acc_gas_mask"]},
}
const ITEMS: Dictionary = {
	"none": {},
	"boss": {"itm_bandage": 3, "itm_brutzel_burger": 2, "itm_smelling_salts": 2, "itm_antidote": 1},
}
## The room of every encounter's group on floor 1 (floors.json layout; event fights: the room of their event).
const CELLS: Dictionary = {
	"enc_f1_a1_tutorial": [1, 6], "enc_f1_a2": [1, 4], "enc_f1_a3": [2, 4], "enc_f1_a4": [1, 3],
	"enc_f1_a_rare": [0, 5], "enc_f1_b1": [4, 4], "enc_f1_b2": [3, 3], "enc_f1_b3": [5, 3], "enc_f1_b4": [4, 5],
	"enc_f1_evt_pigeons": [3, 5], "enc_f1_evt_slime": [4, 3], "enc_e1_showboss": [5, 4], "enc_f1_c1": [5, 2],
	"enc_f1_c2": [6, 0], "enc_f1_c3": [4, 1], "enc_f1_boss_hausmeister": [5, 0], "enc_f1_d1": [1, 2],
	"enc_f1_d2": [1, 1], "enc_f1_d3": [2, 0], "enc_f1_boss_rattenkoenigin": [0, 0],
}
## Start poses [x, z, yaw] (room-local cm): the group's leader, the controlled figure, the partner. Bosses: the party
## stands where the boss trigger (5 m) leaves it, in front of the only door (Hausmeister W, Königin E).
const POSES: Dictionary = {
	"regular": [[0, -150, 128], [0, 250, 0], [-120, 340, 0]],
	"enc_f1_boss_hausmeister": [[0, 0, 64], [-420, 0, 192], [-470, 120, 192]],
	"enc_f1_boss_rattenkoenigin": [[0, 0, 192], [420, 60, 64], [470, 160, 64]],
}
const MAX_TICKS: int = 18000
## Sequence mode: walking time between two fights (07 §11.4: ≈ 45–60 s of the full-run bot) and the safe-room stops
## (full heal before these encounters: SR1 Kiosk after the tutorial, SR2 Pumpenhaus in zone B, SR3 Stellwerk in D).
const SEQ_WALK_SEC: int = 50
const SEQ_SAFE_BEFORE: PackedStringArray = ["enc_f1_a2", "enc_f1_c1", "enc_f1_boss_hausmeister", "enc_f1_d1",
	"enc_f1_boss_rattenkoenigin"]


# --- one fight -------------------------------------------------------------------------------------------------------

## The GameState of fight `n` of `enc_id`: hero, level, gear (Liga tier strips armor + accessory), first-offer
## talents, HP × 4 (07 §3.9.4), full HP / MP, the item kit of the plan.
static func state_for(data: GameData, enc_id: String, hero: String, liga: int, n: int,
		level_override: int = 0) -> GameState:
	var plan: Array = PLAN[enc_id]
	var level: int = level_override if level_override > 0 else int(plan[0])
	var st: GameState = GameState.create_new(data, 0, "Kai", SeedUtil.derive(SEED, "harness_state", n))
	st.hero = hero
	st.combat_mode = &"realtime"
	st.floor_run = FloorRun.create(data.floor_def(1), st.seed, &"prime")
	st.floor_run.location = SR
	for iid: Variant in st.inventory.counts.keys():
		st.inventory.remove(str(iid), st.inventory.count(str(iid)))
	var kit: Dictionary = ITEMS[str(plan[2])]
	for iid: String in kit:
		st.inventory.add(iid, int(kit[iid]), 9)
	var scale: int = RtBalance.from_data(data).i("HP_SCALE_PM")
	for m: PartyMember in st.party:
		m.hp_scale_pm = scale
		level_to(m, data, level)
		var g: Array = (GEAR[str(plan[1])] as Dictionary)[m.id]
		var strip: bool = liga >= 2 or (liga == 1 and m.id == hero)
		m.equipment = {"weapon": str(g[0]), "armor": "" if strip else str(g[1]), "accessory": "" if strip else str(g[2])}
		pick_talents(st, data, m)
	Progression.full_heal(st, data)
	return st


## Levels `m` up to `level` the way the campaign does (EXP: stats, learnset; the talent choices stay open).
static func level_to(m: PartyMember, data: GameData, level: int) -> void:
	while m.level < level:
		Progression.add_exp(m, maxi(1, Progression.exp_to_next(m.level) - m.exp), data)


## The bot's talent picks (06 §2.2): the first card of every open offer, oldest level first.
static func pick_talents(st: GameState, data: GameData, m: PartyMember) -> void:
	while Talents.has_choice(st, data, m.id):
		if not Talents.pick(st, data, m.id, Talents.current_offer(st, data, m.id)[0]):
			break


## The encounter command of 07 §10.1 in the encounter's room (leader, controlled figure, partner as POSES).
static func command_for(enc_id: String, hero: String, adv: int, partner_preset: String = "") -> Dictionary:
	var poses: Array = POSES.get(enc_id, POSES["regular"])
	var ctl: String = "p0" if hero == "kai" else "p1"
	var other: String = "p1" if ctl == "p0" else "p0"
	var presets: Dictionary = {}
	if partner_preset != "":
		presets[other] = {"preset": partner_preset, "tog": RtVocab.RT_TOGGLE_DEFAULTS.duplicate()}
	var rt: Dictionary = {"v": 1, "cell": (CELLS[enc_id] as Array).duplicate(), "ctl": ctl,
		"party": [{"u": ctl, "p": poses[1]}, {"u": other, "p": poses[2]}],
		"groups": [{"group": "harness", "enc": enc_id, "lead": poses[0], "state": "IDLE"}],
		"presets": presets, "auto": true, "retarget": true, "open": {}, "diff": "prime"}
	return {"t": "encounter", "enc": enc_id, "adv": adv, "group": "harness", "rt": rt}


## Plays fight `n` of `enc_id` to its end: {"outcome", "ticks", "hp_loss_pm", "potions", "kos", "won", …}.
## opts: "profile" (bot), "partner_preset", "level" (override), "autopilot" (the sim plays the hero too; both units
## with the potions switch on — the AI as the yardstick of 07 §11.3 "a perfect person beats the AI" drinks as well).
static func fight(data: GameData, enc_id: String, hero: String, liga: int, n: int, opts: Dictionary = {}) -> Dictionary:
	var st: GameState = state_for(data, enc_id, hero, liga, n, int(opts.get("level", 0)))
	var plan: Array = PLAN[enc_id]
	var cmd: Dictionary = command_for(enc_id, hero, int(plan[3]), str(opts.get("partner_preset", "")))
	if bool(opts.get("autopilot", false)):           # the AI plays both — with the potions switch on, like the person
		for m: PartyMember in st.party:
			var uid: String = "p0" if m.id == "kai" else "p1"
			var pre: Dictionary = (cmd["rt"]["presets"] as Dictionary).get(uid, {})
			var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
			tog["potions"] = true
			(cmd["rt"]["presets"] as Dictionary)[uid] = {"tog": tog, "preset": str(pre.get("preset",
				data.party_member(m.id).rt.get("default_preset", "attack")))}
	var setup: RtSetup = BattleBridge.make_rt_setup(st, data, cmd, SeedUtil.derive(SEED, "harness", n))
	if setup == null:
		return {"outcome": -1, "error": "no setup"}
	return play(RtSim.new(setup, data), str(opts.get("profile", "typical")), SeedUtil.derive(SEED, "harness_bot", n),
		bool(opts.get("autopilot", false)))


## Plays a started or fresh sim to its end with the bot (or the autopilot) and measures it.
static func play(sim: RtSim, profile: String, bot_seed: int, autopilot: bool = false) -> Dictionary:
	var bot: RefCounted = Bot.new(sim, profile, bot_seed)
	var m: Dictionary = {"worthy": 0, "worthy_boss": 0, "intr_person": 0, "intr_ai": 0, "intr_boss": 0,
		"tele_party_hits": 0, "tele_dodges": 0, "boss_tele_hits": 0, "boss_tele_dodges": 0, "train_kills": 0,
		"shapes": 0}
	var events: Array[ActionEvent] = sim.start()
	if autopilot:
		sim.submit(RtCommand.autopilot(0, sim.controlled_id(), true))
	var boss_tele: Dictionary = {}
	while not sim.is_finished() and sim.tick() < MAX_TICKS:
		if not autopilot:
			bot.call("act")
		events = sim.step()
		if not autopilot:
			bot.call("observe", events)
		_measure(sim, events, m, boss_tele)
	return _result(sim, m, bot.get("stats"))


static func _measure(sim: RtSim, events: Array[ActionEvent], m: Dictionary, boss_tele: Dictionary) -> void:
	for e: ActionEvent in events:
		match e.type:
			ActionEvent.Type.CAST_START:
				if int(e.rt.get("worthy", 0)) == 1:
					var a: RtUnit = sim.unit(e.actor_id)
					if a != null and a.side == Combatant.Side.ENEMY:
						m["worthy"] = int(m["worthy"]) + 1
						if a.is_boss:
							m["worthy_boss"] = int(m["worthy_boss"]) + 1
			ActionEvent.Type.CAST_INTERRUPTED:
				var src: RtUnit = sim.unit(e.actor_id)
				var tgt: RtUnit = sim.unit(e.target_id)
				if src != null and src.side == Combatant.Side.PARTY and tgt != null and tgt.side == Combatant.Side.ENEMY:
					m["intr_ai" if e.by_ai else "intr_person"] = int(m["intr_ai" if e.by_ai else "intr_person"]) + 1
					if tgt.is_boss:
						m["intr_boss"] = int(m["intr_boss"]) + 1
			ActionEvent.Type.TELEGRAPH_START:
				var ts: RtUnit = sim.unit(e.actor_id)
				m["shapes"] = int(m["shapes"]) + 1
				if ts != null and ts.is_boss:
					boss_tele[e.value] = true
			ActionEvent.Type.TELEGRAPH_IMPACT:
				var hits: int = 0
				for id: String in e.target_ids:
					var v: RtUnit = sim.unit(id)
					if v != null and v.side == Combatant.Side.PARTY:
						hits += 1
				m["tele_party_hits"] = int(m["tele_party_hits"]) + hits
				if boss_tele.has(e.value):
					m["boss_tele_hits"] = int(m["boss_tele_hits"]) + hits
			ActionEvent.Type.TELEGRAPH_DODGED:
				m["tele_dodges"] = int(m["tele_dodges"]) + 1
				if boss_tele.has(e.value):
					m["boss_tele_dodges"] = int(m["boss_tele_dodges"]) + 1


static func _result(sim: RtSim, m: Dictionary, bot_stats: Dictionary) -> Dictionary:
	var r: BattleResult = sim.result
	var hp: int = 0
	var max_hp: int = 0
	for u: RtUnit in sim.party_ref():
		hp += maxi(0, u.hp)
		max_hp += u.max_hp()
	var out: Dictionary = m.duplicate()
	out["outcome"] = int(r.outcome) if r != null else -1
	out["won"] = r != null and r.outcome == BattleResult.Outcome.VICTORY
	out["ticks"] = sim.tick()
	out["hp_loss_pm"] = 1000 - FixedMath.div_round(hp * 1000, maxi(1, max_hp))
	out["potions"] = int(sim.tally.get("potions_used", 0))
	out["kos"] = int(sim.tally.get("party_kos", 0))
	out["dodges"] = int(sim.tally.get("dodges", 0))
	out["telegraph_hits"] = int(sim.tally.get("telegraph_hits", 0))
	out["train_kills"] = int(sim.tally.get("train_kills", 0))
	out["crits"] = int(sim.tally.get("crits", 0))                  # R5b: the battle_won payload (ach_crit_3, …)
	out["weakness_hits"] = int(sim.tally.get("weakness_hits", 0))
	out["gcd_windows"] = int(bot_stats.get("gcd_windows", 0))
	out["gcd_used"] = int(bot_stats.get("gcd_used", 0))
	out["party_hp"] = []
	for u: RtUnit in sim.party_ref():
		(out["party_hp"] as Array).append([u.hp, u.max_hp(), u.mp, u.max_mp()])
	return out


# --- series ----------------------------------------------------------------------------------------------------------

## `seeds` fights of one encounter → aggregates (see summarize).
static func series(data: GameData, enc_id: String, hero: String, liga: int, seeds: int, opts: Dictionary = {},
		first_seed: int = 0) -> Dictionary:
	var fights: Array = []
	for i in seeds:
		fights.append(fight(data, enc_id, hero, liga, first_seed + i, opts))
	var s: Dictionary = summarize(fights)
	s["enc"] = enc_id
	s["hero"] = hero
	s["liga"] = liga
	s["profile"] = str(opts.get("profile", "typical"))
	s["partner_preset"] = str(opts.get("partner_preset", ""))
	s["seeds"] = [first_seed, first_seed + seeds - 1]
	return s


## Aggregates of a list of fight results: n, losses (DEFEAT or no end), loss rate with its Wilson 95 % interval,
## duration (s) and HP loss (%) as median / P10 / P90 (wins and losses), potions and KOs per fight, interrupt rates.
static func summarize(fights: Array) -> Dictionary:
	var n: int = fights.size()
	var losses: int = 0
	var secs: Array = []
	var loss_pct: Array = []
	var pot: int = 0
	var kos: int = 0
	var sums: Dictionary = {}
	for f: Dictionary in fights:
		if not bool(f.get("won", false)):
			losses += 1
		secs.append(float(int(f.get("ticks", 0))) / 30.0)
		loss_pct.append(float(int(f.get("hp_loss_pm", 0))) / 10.0)
		pot += int(f.get("potions", 0))
		kos += int(f.get("kos", 0))
		for k: String in ["worthy", "worthy_boss", "intr_person", "intr_ai", "intr_boss", "boss_tele_hits",
				"boss_tele_dodges", "tele_party_hits", "tele_dodges", "gcd_windows", "gcd_used", "train_kills"]:
			sums[k] = int(sums.get(k, 0)) + int(f.get(k, 0))
	var ci: Vector2 = wilson(losses, n)
	var out: Dictionary = {"n": n, "losses": losses, "loss_rate": float(losses) / float(maxi(1, n)),
		"loss_ci": [ci.x, ci.y], "sec": quantiles(secs), "hp_loss": quantiles(loss_pct),
		"potions": float(pot) / float(maxi(1, n)), "kos": float(kos) / float(maxi(1, n))}
	var w: int = int(sums.get("worthy", 0))
	out["interrupted"] = float(int(sums["intr_person"]) + int(sums["intr_ai"])) / float(w) if w > 0 else -1.0
	out["intr_person"] = int(sums["intr_person"])
	out["intr_ai"] = int(sums["intr_ai"])
	var wb: int = int(sums.get("worthy_boss", 0))
	out["interrupted_boss"] = float(int(sums["intr_boss"])) / float(wb) if wb > 0 else -1.0
	var bt: int = int(sums["boss_tele_hits"]) + int(sums["boss_tele_dodges"])
	out["boss_tele_hit_rate"] = float(int(sums["boss_tele_hits"])) / float(bt) if bt > 0 else -1.0
	var gw: int = int(sums["gcd_windows"])
	out["gcd_use"] = float(int(sums["gcd_used"])) / float(gw) if gw > 0 else -1.0
	out["train_kills"] = float(int(sums["train_kills"])) / float(maxi(1, n))
	return out


## {"median", "p10", "p90"} of `values` (nearest rank).
static func quantiles(values: Array) -> Dictionary:
	if values.is_empty():
		return {"median": 0.0, "p10": 0.0, "p90": 0.0}
	var v: Array = values.duplicate()
	v.sort()
	return {"median": _q(v, 0.5), "p10": _q(v, 0.1), "p90": _q(v, 0.9)}


static func _q(sorted: Array, q: float) -> float:
	var i: int = clampi(int(ceil(q * float(sorted.size()))) - 1, 0, sorted.size() - 1)
	return float(sorted[i])


## Wilson score interval (95 %) of k successes in n trials.
static func wilson(k: int, n: int) -> Vector2:
	if n <= 0:
		return Vector2(0.0, 1.0)
	var z: float = 1.96
	var p: float = float(k) / float(n)
	var den: float = 1.0 + z * z / float(n)
	var mid: float = (p + z * z / (2.0 * float(n))) / den
	var half: float = z * sqrt(p * (1.0 - p) / float(n) + z * z / (4.0 * float(n) * float(n))) / den
	return Vector2(maxf(0.0, mid - half), minf(1.0, mid + half))


## One table line of a series (stdout).
static func line(s: Dictionary) -> String:
	var sec: Dictionary = s["sec"]
	var hp: Dictionary = s["hp_loss"]
	var ci: Array = s["loss_ci"]
	return "%-28s %-7s L%d %-7s n=%3d loss %5.1f%% [%4.1f–%4.1f] dur %5.1fs [%5.1f–%5.1f] hp %4.1f%% [%4.1f–%4.1f]" % [
		str(s["enc"]), str(s["hero"]), int(s["liga"]), str(s["profile"]), int(s["n"]),
		float(s["loss_rate"]) * 100.0, float(ci[0]) * 100.0, float(ci[1]) * 100.0, float(sec["median"]),
		float(sec["p10"]), float(sec["p90"]), float(hp["median"]), float(hp["p10"]), float(hp["p90"])] \
		+ " pot %.1f ko %.2f intr %s (P%d/A%d) tele %s gcd %s" % [float(s["potions"]), float(s["kos"]),
		_pct(float(s["interrupted"])), int(s["intr_person"]), int(s["intr_ai"]), _pct(float(s["boss_tele_hit_rate"])),
		_pct(float(s["gcd_use"]))]


static func _pct(x: float) -> String:
	return "—" if x < 0.0 else "%.0f%%" % (x * 100.0)


## Verdicts ("ok  …" / "OUT …") of one harness run against BANDS: every `typical` series on the default partner tactic
## (other profiles and presets are yardsticks without a band), the regular median of medians per hero, the Liga step per
## boss and hero, and the `typical` sequences. The nightly run prints them (tools/rt_balance.sh --nightly).
static func band_report(series_list: Array, seqs: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var regular: Dictionary = {}                     # hero → the regular duration medians at Liga 0
	var regular_hp: Dictionary = {}                  # hero → the regular HP-loss medians at Liga 0
	var boss_loss: Dictionary = {}                   # "enc hero" → {liga: loss %}
	for s: Dictionary in series_list:
		if str(s.get("profile", "")) != "typical" or str(s.get("partner_preset", "")) != "":
			continue
		var enc: String = str(s["enc"])
		var liga: int = int(s["liga"])
		var tag: String = "%s %s L%d" % [enc, str(s["hero"]), liga]
		var b: Dictionary = BANDS.get("regular" if REGULAR.has(enc) else enc, {})
		var sec: float = float((s["sec"] as Dictionary)["median"])
		if liga == 0 and b.has("sec"):
			out.append(_verdict(tag, "duration median s", sec, b["sec"]))
		var hp: float = float((s["hp_loss"] as Dictionary)["median"])
		if liga == 0 and b.has("hp") and not REGULAR.has(enc):          # regular: over the encounters, below
			out.append(_verdict(tag, "HP loss median %", hp, b["hp"]))
		var loss: Array = b.get("loss", [])
		if liga < loss.size():
			out.append(_verdict(tag, "first-try losses %", float(s["loss_rate"]) * 100.0, loss[liga]))
		if b.has("intr") and float(s["interrupted_boss"]) >= 0.0:
			out.append(_verdict(tag, "interrupted boss casts %", float(s["interrupted_boss"]) * 100.0,
				[b["intr"], 100.0]))
		if b.has("tele") and float(s["boss_tele_hit_rate"]) >= 0.0:
			out.append(_verdict(tag, "boss telegraph hits %", float(s["boss_tele_hit_rate"]) * 100.0, [0.0, b["tele"]]))
		if REGULAR.has(enc) and liga == 0:
			regular[str(s["hero"])] = (regular.get(str(s["hero"]), []) as Array) + [sec]
			regular_hp[str(s["hero"])] = (regular_hp.get(str(s["hero"]), []) as Array) + [hp]
		if BOSSES.has(enc):
			var key: String = "%s %s" % [enc, str(s["hero"])]
			var by: Dictionary = boss_loss.get(key, {})
			by[liga] = float(s["loss_rate"]) * 100.0
			boss_loss[key] = by
	for hero: String in regular:
		if (regular[hero] as Array).size() == REGULAR.size():
			out.append(_verdict("regular " + hero, "median of the encounter medians s",
				float(quantiles(regular[hero])["median"]), BAND_REGULAR_MEDIAN))
			out.append(_verdict("regular " + hero, "median of the encounter HP-loss medians %",
				float(quantiles(regular_hp[hero])["median"]), (BANDS["regular"] as Dictionary)["hp"]))
	for key: String in boss_loss:
		var by: Dictionary = boss_loss[key]
		if by.has(0) and by.has(1):
			out.append(_verdict(key, "Liga 1 − Liga 0 losses (points)", float(by[1]) - float(by[0]),
				[BAND_LIGA_STEP, BAND_LIGA_STEP_MAX]))
	for q: Dictionary in seqs:
		if str(q.get("profile", "typical")) != "typical":
			continue
		var tag: String = "sequence " + str(q["hero"])
		out.append(_verdict(tag, "heal items per floor", float((q["potions"] as Dictionary)["median"]), BAND_SEQ_ITEMS))
		out.append(_verdict(tag, "fights before the first heal item", float((q["streak"] as Dictionary)["median"]),
			BAND_SEQ_STREAK))
	return out


static func _verdict(tag: String, what: String, v: float, band: Array) -> String:
	var ok: bool = v >= float(band[0]) - 0.001 and v <= float(band[1]) + 0.001
	return "%s %s: %s %.1f [%.0f–%.0f]" % ["ok " if ok else "OUT", tag, what, v, float(band[0]), float(band[1])]


## Tuning probe (`--set=`, never in a gate): overrides one value of the loaded data in memory before the fights —
## "enemy:<id>.<path>=<json>" / "skill:<id>.<path>=<json>" (the rt block; path keys and array indices joined by ".";
## the index one past the end of an array appends) or "bal:<KEY>[.<sub>]=<json>" (rt_balance.json values). "" =
## applied, else the problem.
static func tune(data: GameData, spec: String) -> String:
	var eq: int = spec.find("=")
	var colon: int = spec.find(":")
	if eq < 0 or colon < 0 or colon > eq:
		return "expected <enemy|skill|skilldef|item|bal>:<id>.<path>=<value>"
	var kind: String = spec.substr(0, colon)
	var path: PackedStringArray = spec.substr(colon + 1, eq - colon - 1).split(".", false)
	var value: Variant = JSON.parse_string(spec.substr(eq + 1))
	if value == null or path.is_empty():
		return "bad value or path in '%s'" % spec
	if value is float and is_equal_approx(float(value), roundf(float(value))):
		value = int(value)
	var holder: Object = null                     # GameData freezes its tables: the block is replaced by a copy
	var prop: String = "rt"
	match kind:
		"enemy":
			holder = data.enemy(path[0]) if data.has_id("enemies", path[0]) else null
			path = path.slice(1)
		"skill":
			holder = data.skill(path[0]) if data.has_id("skills", path[0]) else null
			path = path.slice(1)
		"item":
			holder = data.item(path[0]) if data.has_id("items", path[0]) else null
			path = path.slice(1)
		"bal":
			holder = data
			prop = "_rt_balance"
		"skilldef":                                     # a top-level field of the SkillDef (element, power, …)
			var sd: SkillDef = data.skill(path[0]) if data.has_id("skills", path[0]) else null
			if sd == null or path.size() != 2 or not (path[1] in sd):
				return "unknown target in '%s'" % spec
			sd.set(path[1], value)
			return ""
	if holder == null or path.is_empty():
		return "unknown target in '%s'" % spec
	var root: Dictionary = (holder.get(prop) as Dictionary).duplicate(true)
	var node: Variant = root
	for i in path.size() - 1:
		node = node[int(path[i])] if node is Array else (node as Dictionary).get(path[i])
		if not (node is Dictionary or node is Array):
			return "path '%s' not found" % ".".join(path)
	if node is Array:
		var at: int = int(path[path.size() - 1])
		if at == (node as Array).size():                # one past the end appends (a new rule, phase, …)
			(node as Array).append(value)
		elif at >= 0 and at < (node as Array).size():
			node[at] = value
		else:
			return "index %d out of range in '%s'" % [at, spec]
	else:
		(node as Dictionary)[path[path.size() - 1]] = value
	holder.set(prop, root)
	return ""


## The encounter ids of a `--encounters=` value: a comma list of all | regular (no bosses, no show boss) | bosses |
## showboss | encounter ids (floor order, no duplicates).
static func encounter_list(spec: String) -> PackedStringArray:
	var want: Dictionary = {}
	for part: String in spec.split(",", false):
		var p: String = part.strip_edges()
		for e: String in ORDER:
			var hit: bool = p == "all" or p == e or (p == "bosses" and BOSSES.has(e)) \
				or (p == "showboss" and e == SHOW_BOSS) or (p == "regular" and not BOSSES.has(e) and e != SHOW_BOSS)
			if hit:
				want[e] = true
	var out: PackedStringArray = []
	for e: String in ORDER:
		if want.has(e):
			out.append(e)
	return out


# --- floor sequence (07 §11.4 "Etagenfolge-Harness") ------------------------------------------------------------------

## One run of the floor in ORDER with run `n`: the party carries HP / MP between fights, regenerates out of combat for
## SEQ_WALK_SEC between two fights (07 §2.7, REGEN_* of rt_balance.json), gets the Werbepause after every win, heals
## fully in front of SEQ_SAFE_BEFORE; levels and gear follow PLAN. Inventory: the start kit and what the floor's plan
## buys (2 bandages + 1 burger per safe room). → {"fights": [...], "potions", "streak_max": the longest run of won
## fights without a potion, "streaks": [lengths between safe rooms], "losses"}.
static func sequence(data: GameData, hero: String, n: int, profile: String = "typical") -> Dictionary:
	var bal: RtBalance = RtBalance.from_data(data)
	var st: GameState = state_for(data, "enc_f1_a1_tutorial", hero, 0, n)
	st.inventory.add("itm_bandage", 3, 9)
	st.inventory.add("itm_antidote", 1, 9)
	var out: Dictionary = {"fights": [], "potions": 0, "losses": 0, "segments": []}
	var segment: Array = []
	for k in ORDER.size():
		var enc_id: String = ORDER[k]
		if enc_id == SHOW_BOSS:
			continue
		var plan: Array = PLAN[enc_id]
		if SEQ_SAFE_BEFORE.has(enc_id):
			if not segment.is_empty():
				(out["segments"] as Array).append(segment)
			segment = []
			st.inventory.add("itm_bandage", 2, 9)
			st.inventory.add("itm_brutzel_burger", 1, 9)
			_set_level(st, data, int(plan[0]), str(plan[1]))
			Progression.full_heal(st, data)
		elif k > 0:
			_set_level(st, data, int(plan[0]), str(plan[1]))
			_regen(st, data, bal, SEQ_WALK_SEC * 30)
		var cmd: Dictionary = command_for(enc_id, hero, int(plan[3]))
		var setup: RtSetup = BattleBridge.make_rt_setup(st, data, cmd, SeedUtil.derive(SEED, "harness_seq_%d" % k, n))
		var sim: RtSim = RtSim.new(setup, data)
		var f: Dictionary = play(sim, profile, SeedUtil.derive(SEED, "harness_seq_bot_%d" % k, n))
		f["enc"] = enc_id
		(out["fights"] as Array).append(f)
		out["potions"] = int(out["potions"]) + int(f["potions"])
		segment.append(int(f["potions"]))
		if not bool(f["won"]):
			out["losses"] = int(out["losses"]) + 1
		_write_back(st, data, sim, bool(f["won"]), bal)
	if not segment.is_empty():
		(out["segments"] as Array).append(segment)
	return out


## Aggregates of sequence runs: heal items per floor (median / P10 / P90), boss heal items, losses per run, and the
## fights a fresh party (after a safe room) wins before the first heal item — over the segments with ≥ 3 fights.
static func sequence_summary(runs: Array) -> Dictionary:
	var pots: Array = []
	var boss_pots: Array = []
	var streaks: Array = []
	var losses: int = 0
	for r: Dictionary in runs:
		pots.append(float(int(r["potions"])))
		losses += int(r["losses"])
		var bp: int = 0
		for f: Dictionary in r["fights"]:
			if BOSSES.has(str(f["enc"])):
				bp += int(f["potions"])
		boss_pots.append(float(bp))
		for seg: Array in r["segments"]:
			if seg.size() < 3:
				continue
			var k: int = 0
			while k < seg.size() and int(seg[k]) == 0:
				k += 1
			streaks.append(float(k))
	return {"n": runs.size(), "potions": quantiles(pots), "boss_potions": quantiles(boss_pots),
		"streak": quantiles(streaks), "losses_per_run": float(losses) / float(maxi(1, runs.size()))}


static func sequence_line(s: Dictionary) -> String:
	var p: Dictionary = s["potions"]
	var b: Dictionary = s["boss_potions"]
	var k: Dictionary = s["streak"]
	return "%-7s n=%3d heal items/floor %.1f [%.1f–%.1f] (bosses %.1f) fights before the first item %.1f [%.1f–%.1f]" \
		% [str(s["hero"]), int(s["n"]), float(p["median"]), float(p["p10"]), float(p["p90"]), float(b["median"]),
		float(k["median"]), float(k["p10"]), float(k["p90"])] + " losses/run %.2f" % float(s["losses_per_run"])


# --- perf (07 §3.15 with the real data) -------------------------------------------------------------------------------

## µs per RtSim.step() with the real data: 2 party units (the bot and the AI partner), 6 enemies of zone C / D (spider,
## sprayer with zones, rat; two guards, a shaman casting) in one room, telegraphs / zones topped up to 10 and every
## unit's HP kept up (untimed) so all 8 fight for `steps` ticks. → {"steps", "party", "enemies", "shapes" (average),
## "median_us", "mean_us", "p90_us"}.
static func perf(data: GameData, steps: int) -> Dictionary:
	var st: GameState = state_for(data, "enc_f1_d2", "kai", 0, 0)
	var cmd: Dictionary = command_for("enc_f1_c3", "kai", BattleSetup.Advantage.NORMAL)
	(cmd["rt"]["groups"] as Array).append({"group": "harness2", "enc": "enc_f1_d2", "lead": [250, -250, 160],
		"state": "IDLE"})
	var sim: RtSim = RtSim.new(BattleBridge.make_rt_setup(st, data, cmd, SeedUtil.derive(SEED, "harness_perf", 0)), data)
	var bot: RefCounted = Bot.new(sim, "typical", SeedUtil.derive(SEED, "harness_perf_bot", 0))
	sim.start()
	var times: Array = []
	var shapes: int = 0
	var enemies: int = 0
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.ENEMY:
			enemies += 1
	while not sim.is_finished() and times.size() < steps:
		_perf_fill(sim, times.size())
		for u: RtUnit in sim.units():
			u.hp = maxi(u.hp, u.max_hp())
		bot.call("act")
		shapes += sim.telegraphs().size()
		var t0: int = Time.get_ticks_usec()
		var ev: Array[ActionEvent] = sim.step()
		times.append(float(Time.get_ticks_usec() - t0))
		bot.call("observe", ev)
	var q: Dictionary = quantiles(times)
	var sum: float = 0.0
	for t: float in times:
		sum += t
	return {"steps": times.size(), "party": sim.party_ref().size(), "enemies": enemies,
		"shapes": float(shapes) / float(maxi(1, times.size())), "median_us": float(q["median"]),
		"mean_us": sum / float(maxi(1, times.size())), "p90_us": float(q["p90"])}


## Harmless filler shapes up to 10 (no skill: an impact without effect, a zone without status), alternating pending
## telegraphs and zones around the ring (the pattern of test_r1_rt_perf).
static func _perf_fill(sim: RtSim, n: int) -> void:
	var k: int = 0
	while sim.telegraphs().size() < 10:
		var t: RtTelegraph = RtTelegraph.new()
		var f: Vector2i = DetMath.dir((n * 37 + k * 59) % 256)
		t.source_id = "e0"
		t.side = Combatant.Side.PARTY
		t.shape = RtTelegraph.Shape.CIRCLE
		t.x = f.x * 380 / DetMath.ONE
		t.z = f.y * 380 / DetMath.ONE
		t.r = 120
		t.start = sim.tick()
		t.is_zone = (n + k) % 2 == 0
		t.impact_at = -1 if t.is_zone else sim.tick() + 45
		t.ends_at = sim.tick() + 300 if t.is_zone else -1
		t.period = 60 if t.is_zone else 0
		t.next_tick_at = sim.tick() + 60 if t.is_zone else -1
		sim.add_telegraph(t)
		k += 1


static func _set_level(st: GameState, data: GameData, level: int, gear: String) -> void:
	for m: PartyMember in st.party:
		var hp_share: int = 1000
		var mp_share: int = 1000
		var before: StatBlock = Progression.total_stats(m, data)
		if before.values[StatBlock.Stat.HP] > 0:
			hp_share = FixedMath.div_round(m.hp * 1000, before.values[StatBlock.Stat.HP])
			mp_share = FixedMath.div_round(m.mp * 1000, maxi(1, before.values[StatBlock.Stat.MP]))
		var was_ko: bool = m.hp <= 0
		level_to(m, data, level)
		var g: Array = (GEAR[gear] as Dictionary)[m.id]
		m.equipment = {"weapon": str(g[0]), "armor": str(g[1]), "accessory": str(g[2])}
		pick_talents(st, data, m)
		var after: StatBlock = Progression.total_stats(m, data)
		m.hp = 0 if was_ko else 1
		m.hp = maxi(1 if m.hp > 0 else 0, FixedMath.div_round(after.values[StatBlock.Stat.HP] * hp_share, 1000))
		m.mp = FixedMath.div_round(after.values[StatBlock.Stat.MP] * mp_share, 1000)


## Out-of-combat regeneration for `ticks` exploration ticks (07 §2.7: every REGEN_PERIOD_TICKS MP_PM of max MP, HP_PM
## of max HP once REGEN_HP_DELAY_TICKS passed since the last combat).
static func _regen(st: GameState, data: GameData, bal: RtBalance, ticks: int) -> void:
	var period: int = maxi(1, bal.i("REGEN_PERIOD_TICKS"))
	var t: int = 0
	while t + period <= ticks:
		t += period
		for m: PartyMember in st.party:
			if m.hp <= 0:
				continue
			var sb: StatBlock = Progression.total_stats(m, data)
			var mx_hp: int = sb.values[StatBlock.Stat.HP]
			var mx_mp: int = sb.values[StatBlock.Stat.MP]
			m.mp = mini(mx_mp, m.mp + maxi(1, FixedMath.div_round(mx_mp * bal.i("REGEN_MP_PM"), 1000)))
			if t >= bal.i("REGEN_HP_DELAY_TICKS"):
				m.hp = mini(mx_hp, m.hp + maxi(1, FixedMath.div_round(mx_hp * bal.i("REGEN_HP_PM"), 1000)))


## After a fight: HP / MP back into the members (a win stands KO'd members up at 1 HP), the used consumables leave the
## inventory, the Werbepause (+15 % max MP after a win); a loss heals fully (the run goes on from the last save).
static func _write_back(st: GameState, data: GameData, sim: RtSim, won: bool, bal: RtBalance) -> void:
	for u: RtUnit in sim.party_ref():
		var m: PartyMember = st.member(u.def_id)
		if m == null:
			continue
		m.hp = maxi(1, u.hp) if won else u.hp
		m.mp = u.mp
		if won:
			var mx: int = Progression.total_stats(m, data).values[StatBlock.Stat.MP]
			m.mp = mini(mx, m.mp + FixedMath.div_round(mx * 150, 1000))
	var delta: Dictionary = sim.tally.get("item_delta", {})
	for iid: Variant in delta.keys():
		if int(delta[iid]) < 0:
			st.inventory.remove(str(iid), -int(delta[iid]))
	if not won:
		Progression.full_heal(st, data)
