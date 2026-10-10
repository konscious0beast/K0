extends TestCase
## M7 show balance (01_GDD §7/§13, 02_TECH §6.2): Floor 1 as one show season with the REAL Show autoload in the loop —
## the regular groups, one event fight and both bosses in map order (GDD §1.3) at the GDD §13 levels and gear of
## test_m7_balance (PLAN/GEAR/ITEMS), auto battles (AutoPolicy; policy "stunts" = every stunt as soon as it is off
## cooldown, else AutoPolicy — the show-minded player the bot does not model), sponsor gifts delivered at the turn
## boundary like BattleController._play (Show.take_pending_gift → BattleState.apply_gift → Show.on_battle_event),
## the exploration between two steps as hype decay (ShowModel.decay_step every ShowModel.HYPE_DECAY_TICKS ticks, like
## RunSim) at a pace (seconds of countdown per step, measured with tools/fullrun.sh: --pace=human ≈ 18 s, fast ≈ 6.5 s),
## chests / floor events / vending purchases through Events (→ Show hype, stats, achievements), level-ups (Show.trigger
## level_up) and the lootboxes opened in the safe rooms. Measures followers, peak viewers, sponsor gifts, achievements,
## lootboxes and the hype at the start / end of each regular fight; the boss tests measure the loss rates at the GDD
## levels with the gifts as they occur (boss fight starting at the exploration floor with the bot's loadout).

const M7 := preload("res://tests/test_m7_balance.gd")
const STUNTS: String = "stunts"
const AUTO: String = "auto"
## Seconds of running countdown per season step (chest / event / fight), from the full-run bot (thorough, 10 seeds):
## --pace=human ≈ 700 s / ~40 steps, fast ≈ 260 s / ~40 steps.
const PACE_HUMAN: float = 18.0
const PACE_FAST: float = 6.5
## Floor 1 in map order (GDD §1.3) as the thorough bot plays it: "b:<encounter>[:ambush]" fight (the bot is ambushed by
## a patrol in every run), "c:<chest>" chest, "e:<event>:<choice>" floor event, "sr:<credits spent at the vending
## machine>" safe room (lootboxes opened, one purchase). The tutorial runs before the countdown.
const SEASON: PackedStringArray = [
	"b:enc_f1_a1_tutorial", "c:f1_c0", "e:fev_photo_drone:pose", "b:enc_f1_a_rare", "c:f1_c1", "b:enc_f1_a2", "c:f1_c2",
	"b:enc_f1_a3", "e:fev_lost_candidate:give", "b:enc_f1_a4", "c:f1_c3", "sr:220",
	"c:f1_c4", "b:enc_f1_b1", "c:f1_c5", "e:fev_wheel:spin", "c:f1_c6", "b:enc_f1_b4", "c:f1_c7", "b:enc_f1_b2:ambush",
	"e:fev_lever:pull", "b:enc_f1_evt_slime", "b:enc_f1_b3", "c:f1_c8", "sr:220",
	"c:f1_c9", "b:enc_f1_c1", "c:f1_c10", "e:fev_broken_vending:kick", "b:enc_f1_c2", "c:f1_c11", "b:enc_f1_c3",
	"b:enc_f1_boss_hausmeister", "sr:150",
	"c:f1_c12", "b:enc_f1_d1", "c:f1_c13", "b:enc_f1_d2", "b:enc_f1_d3", "c:f1_c14", "c:f1_c15", "sr:0",
	"b:enc_f1_boss_rattenkoenigin",
]
## Event extras the floor event itself applies (GDD §2.6 params; Game.apply_floor_event), beyond Show's +5 completion.
const EVENT_HYPE: Dictionary = {"fev_photo_drone": 15}
const EVENT_FOLLOWERS: Dictionary = {"fev_photo_drone": 20, "fev_lost_candidate": 40}
## GDD §13 bands (medians over SEASON_SEEDS seasons, AUTO, PACE_HUMAN). Hype start/end: the dramaturgy of GDD §7.3 (a
## fight starts near the exploration floor, 25–45, and a routine fight ends around 45–65, below the first sponsor
## threshold).
const SEASON_SEEDS: int = 8
const BAND_FOLLOWERS: Vector2 = Vector2(1200, 1500)
const BAND_VIEWERS: Vector2 = Vector2(3000, 5500)
const BAND_GIFTS: Vector2 = Vector2(4, 7)
const BAND_ACHIEVEMENTS: Vector2 = Vector2(12, 16)
const BAND_BOXES: Vector2 = Vector2(15, 20)
const BAND_HYPE_START: Vector2 = Vector2(25, 45)
const BAND_HYPE_END: Vector2 = Vector2(45, 65)
const MIN_HYPE_GAIN: float = 12.0
## Upper bounds for the stunt-at-every-chance player and the fast pace (2× and 1.4× the GDD maxima).
const EXTREME_SEEDS: int = 4
const EXTREME_MAX_FOLLOWERS: float = 3000.0
const EXTREME_MAX_VIEWERS: float = 7500.0
## Win rate band with gifts as they occur = 1 − GDD loss rate ±10 points (Hausmeister ~20 %, Königin ~35 %), with the
## loadout the full-run bot brings (most common equipment and median battle items at the boss over 30 human-pace runs:
## the stat-sum accessory is the lucky ticket — nobody equips the gas mask — and the bag is fuller than the PLAN kit).
const BOSS_SEEDS: int = 100
const BOSS_HYPE_START: float = ShowModel.HYPE_EXPLORE_FLOOR
const BOSS_LOADOUT: Dictionary = {
	"enc_f1_boss_hausmeister": {
		"gear": {"kai": ["itm_wpn_pipe_wrench", "itm_arm_safety_vest", "itm_acc_lucky_ticket"],
			"mopsula": ["itm_wpn_collar_studded", "itm_arm_velvet_cape", "itm_acc_lucky_ticket"]},
		"items": {"itm_bandage": 8, "itm_antidote": 7, "itm_brutzel_burger": 2, "itm_smelling_salts": 3,
			"itm_elixir": 1, "itm_energy_krawumm": 3},
	},
	"enc_f1_boss_rattenkoenigin": {
		"gear": {"kai": ["itm_wpn_fire_axe", "itm_arm_sewer_suit", "itm_acc_lucky_ticket"],
			"mopsula": ["itm_wpn_collar_signet", "itm_arm_velvet_cape", "itm_acc_lucky_ticket"]},
		"items": {"itm_bandage": 9, "itm_antidote": 8, "itm_brutzel_burger": 4, "itm_smelling_salts": 4,
			"itm_elixir": 1, "itm_energy_krawumm": 5},
	},
}
const BOSS_WIN_BAND: Dictionary = {
	"enc_f1_boss_hausmeister": Vector2(0.70, 0.90),
	"enc_f1_boss_rattenkoenigin": Vector2(0.55, 0.75),
}

var _m7: Object = null
var _boxes: int = 0
var _prev_data: GameData = null


func before_each() -> void:
	_m7 = M7.new()
	_prev_data = DB.data
	DB.data = real_data()


func after_each() -> void:
	Game.in_battle = false
	if Game.state != null:
		Show.end_battle(null)
	Game.state = null
	if _prev_data != null:
		DB.data = _prev_data
	_prev_data = null


# --- season ---------------------------------------------------------------------------------------------------------

## One Floor-1 season → {"followers", "viewers_max", "gifts", "achievements", "boxes", "hype_start": Array[int],
## "hype_end": Array[int], "boss": {encounter: won}, "boss_hype_start": {encounter: int}}.
## `skip`: encounters left out (a player who fights fewer groups).
func run_season(seed: int, policy: String, pace_sec: float, skip: PackedStringArray = []) -> Dictionary:
	var d: GameData = real_data()
	Game.state = GameState.create_new(d, 0, "Kai", seed)
	Game.in_battle = false
	Show.start_floor(1)
	_boxes = 0
	var on_box: Callable = func(_id: String) -> void: _boxes += 1
	Events.lootbox_earned.connect(on_box)
	var out: Dictionary = {"hype_start": [] as Array[int], "hype_end": [] as Array[int], "boss": {},
		"boss_hype_start": {}, "boss_followers": {}, "battles": 0}
	var level: int = 1
	var countdown: bool = false
	var decay_ticks: int = 0
	var i: int = 0
	for step: String in SEASON:
		var parts: PackedStringArray = step.split(":")
		if parts[0] == "b" and skip.has(parts[1]):
			continue
		if countdown and parts[0] != "sr":
			decay_ticks = _explore(pace_sec, decay_ticks)
		match parts[0]:
			"c":
				Events.chest_opened.emit(parts[1], [])
			"e":
				Events.event_completed.emit({"event_id": parts[1], "choice": parts[2]})
				if EVENT_HYPE.has(parts[1]):
					Show.add_hype(float(EVENT_HYPE[parts[1]]), &"event")
				if EVENT_FOLLOWERS.has(parts[1]):
					Show.add_followers(int(EVENT_FOLLOWERS[parts[1]]), &"event")
			"sr":
				for box_id: String in Game.state.pending_lootboxes:
					Events.lootbox_opened.emit(box_id, [])
				Game.state.pending_lootboxes.clear()
				if int(parts[1]) > 0:
					Events.item_bought.emit({"item_id": "itm_bandage", "qty": 1, "cost": int(parts[1]),
						"safe_room_id": "sr_kiosk"})
			"b":
				var p: Array = M7.PLAN[parts[1]]
				while level < int(p[0]):
					level += 1
					for member: String in ["kai", "mopsula"]:
						Show.trigger("level_up", {"member": member, "level": level})
				var enc: EncounterDef = d.encounter(parts[1])
				var h0: int = roundi(Show.hype())
				var adv: BattleSetup.Advantage = BattleSetup.Advantage.AMBUSH if parts.size() > 2 \
					else BattleSetup.Advantage.NORMAL
				var r: Dictionary = show_battle(parts[1], level, str(p[1]), str(p[2]),
					SeedUtil.derive(seed, "m7_season", i), policy, true, adv)
				out["battles"] = int(out["battles"]) + 1
				out["followers_battles"] = int(out.get("followers_battles", 0)) + int(r["followers"])
				if enc.boss:
					(out["boss_followers"] as Dictionary)[parts[1]] = int(r["followers"])
					(out["boss"] as Dictionary)[parts[1]] = bool(r["win"])
					(out["boss_hype_start"] as Dictionary)[parts[1]] = h0
				elif not enc.tutorial:
					(out["hype_start"] as Array[int]).append(h0)
					(out["hype_end"] as Array[int]).append(int(r["hype_end"]))
				if enc.tutorial:
					countdown = true
		i += 1
	Events.lootbox_earned.disconnect(on_box)
	var show: ShowState = Game.state.show
	out["followers"] = show.followers
	out["viewers_max"] = int(show.stats.get("viewers_max", 0))
	out["gifts"] = int(show.stats.get("sponsor_gifts", 0))
	out["achievements"] = show.achievements.size()
	out["boxes"] = _boxes
	Game.state = null
	return out


## Exploration: pace_sec of running countdown → hype decay like RunSim._tick_once (one step per HYPE_DECAY_TICKS).
func _explore(pace_sec: float, decay_ticks: int) -> int:
	var ticks: int = decay_ticks + roundi(pace_sec * FloorRun.TICKS_PER_SEC)
	while ticks >= ShowModel.HYPE_DECAY_TICKS:
		ticks -= ShowModel.HYPE_DECAY_TICKS
		Game.state.show.hype = ShowModel.decay_step(Game.state.show.hype)
	Show.sync_from_state()
	return ticks


## One battle with the Show in the loop (BattleController order) → {"win", "hype_end", "gifts", "turns", "followers"}.
## Boss lootboxes go to pending_lootboxes like BattleBridge.apply_result.
## `loadout` {"gear": {member: [weapon, armor, accessory]}, "items": {item: n}} replaces the PLAN gear/items when given.
func show_battle(enc_id: String, level: int, gear: String, items: String, seed: int, policy: String,
		gifts_on: bool = true, advantage: BattleSetup.Advantage = BattleSetup.Advantage.NORMAL,
		loadout: Dictionary = {}) -> Dictionary:
	var d: GameData = real_data()
	var enc: EncounterDef = d.encounter(enc_id)
	var setup: BattleSetup = BattleSetup.new()
	setup.encounter_id = enc_id
	setup.enemy_ids = enc.enemies.duplicate()
	setup.seed = seed
	setup.is_boss = enc.boss
	setup.advantage = BattleSetup.Advantage.NORMAL if enc.boss else advantage
	setup.can_flee = enc.can_flee and not enc.tutorial
	setup.tutorial = enc.tutorial
	setup.enemy_dmg_mult = Balance.TUTORIAL_ENEMY_DMG if enc.tutorial else 1.0
	setup.items = (loadout.get("items", M7.ITEMS[items]) as Dictionary).duplicate()
	var gear_set: Dictionary = loadout.get("gear", M7.GEAR[gear])
	setup.credits_available = 200
	setup.auto_battle = true
	setup.floor_index = 1
	var party: Array[Combatant] = []
	var slot: int = 0
	for def: PartyMemberDef in d.all_party():
		party.append(_m7.call("_make_member", d, def, slot, level, gear_set[def.id]))
		slot += 1
	setup.party = party
	Game.in_battle = true
	Show.begin_battle(setup)
	var st: BattleState = BattleState.new(setup, d)
	var gifts: int = 0
	var events: Array[ActionEvent] = st.start()
	var submits: int = 0
	while true:
		for e: ActionEvent in events:
			Show.on_battle_event(e)
		if st.is_finished() or submits >= M7.MAX_SUBMITS:
			break
		var g: Dictionary = Show.take_pending_gift(st) if gifts_on else {}
		if not g.is_empty():
			gifts += 1
			for e: ActionEvent in st.apply_gift(g):
				Show.on_battle_event(e)
		events = st.submit(_command(st, policy))
		submits += 1
	Game.in_battle = false
	var win: bool = st.result != null and st.result.outcome == BattleResult.Outcome.VICTORY
	if st.result == null:
		Show.end_battle(null)
		return {"win": false, "hype_end": roundi(Show.hype()), "gifts": gifts, "turns": 0, "followers": 0}
	if win:
		for br: Dictionary in st.result.boss_rewards:
			if str(br.get("kind", "")) == "box":
				Game.state.pending_lootboxes.append(str(br.get("id", "")))
				Events.lootbox_earned.emit(str(br.get("id", "")))
	var f: int = Show.end_battle(st.result)
	return {"win": win, "hype_end": roundi(Show.hype()), "gifts": gifts, "turns": st.result.party_turns, "followers": f}


## AUTO: AutoPolicy (BattleState.choose_ai_command); STUNTS: the actor's stunt on the weakest enemy whenever valid.
static func _command(st: BattleState, policy: String) -> BattleCommand:
	var actor: Combatant = st.current_actor()
	if policy == STUNTS and actor != null and actor.is_party() and not actor.stunts.is_empty():
		var target: Combatant = BattleState.lowest_hp(st.living(Combatant.Side.ENEMY))
		if target != null:
			var cmd: BattleCommand = BattleCommand.stunt(actor.id, actor.stunts[0], PackedStringArray([target.id]))
			if st.validate(cmd) == "":
				return cmd
	return st.choose_ai_command()


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	var n: int = s.size()
	return float(s[n / 2]) if n % 2 == 1 else (float(s[n / 2 - 1]) + float(s[n / 2])) / 2.0


# --- tests ------------------------------------------------------------------------------------------------------------

func test_season_is_deterministic() -> void:
	var a: Dictionary = run_season(11, AUTO, PACE_HUMAN)
	var b: Dictionary = run_season(11, AUTO, PACE_HUMAN)
	assert_eq(a, b, "same seed + same data = same season")


## GDD §13 bands, median over SEASON_SEEDS seasons of the reference player (auto battles, --pace=human, every group).
func test_season_show_economy_in_gdd_bands() -> void:
	var rows: Array[Dictionary] = _seasons(AUTO, PACE_HUMAN, SEASON_SEEDS)
	var m: Dictionary = _medians(rows)
	var info: String = " (season medians %s)" % str(m)
	print("[m7_show] reference season (auto, human pace): ", m)
	assert_between(float(m["followers"]), BAND_FOLLOWERS.x, BAND_FOLLOWERS.y, "followers at the end of floor 1" + info)
	assert_between(float(m["viewers_max"]), BAND_VIEWERS.x, BAND_VIEWERS.y, "peak viewers of floor 1")
	assert_between(float(m["gifts"]), BAND_GIFTS.x, BAND_GIFTS.y, "sponsor gifts per floor")
	assert_between(float(m["achievements"]), BAND_ACHIEVEMENTS.x, BAND_ACHIEVEMENTS.y, "achievements per floor")
	assert_between(float(m["boxes"]), BAND_BOXES.x, BAND_BOXES.y, "lootboxes per floor")
	assert_between(float(m["hype_start"]), BAND_HYPE_START.x, BAND_HYPE_START.y, "hype at the start of a regular fight")
	assert_between(float(m["hype_end"]), BAND_HYPE_END.x, BAND_HYPE_END.y, "hype at the end of a regular fight")
	# the show must still be felt: a fight visibly moves the meter, the top end stays reachable, nothing saturates
	assert_true(float(m["hype_gain"]) >= MIN_HYPE_GAIN, "median hype gain per regular fight >= %d%s" % [
		int(MIN_HYPE_GAIN), info])
	var high: int = 0
	var saturated: int = 0
	var fights: int = 0
	for r: Dictionary in rows:
		for h: int in r["hype_end"] as Array[int]:
			fights += 1
			high += 1 if h >= 60 else 0
			saturated += 1 if h >= 96 else 0
	assert_true(float(high) / float(maxi(1, fights)) >= 0.10, "regular fights ending at 60+: %d of %d" % [high, fights])
	assert_true(float(saturated) / float(maxi(1, fights)) <= 0.10,
		"regular fights ending at 96–100: %d of %d (before the balancing: almost all)" % [saturated, fights])


## The extremes stay bounded: a player who stunts at every chance (the bot never stunts) and a speedrunner (fast pace
## keeps the hype between fights) earn more — by design — but within the caps: at most 1 gift per regular fight, 2 per
## boss.
func test_season_extremes_stay_bounded() -> void:
	var human: Dictionary = _medians(_seasons(AUTO, PACE_HUMAN, EXTREME_SEEDS))
	for v: Array in [[STUNTS, PACE_HUMAN], [AUTO, PACE_FAST]]:
		var rows: Array[Dictionary] = _seasons(str(v[0]), float(v[1]), EXTREME_SEEDS)
		var m: Dictionary = _medians(rows)
		var label: String = "%s / pace %.1f s: %s" % [str(v[0]), float(v[1]), str(m)]
		assert_true(float(m["followers"]) <= EXTREME_MAX_FOLLOWERS, "followers bounded — " + label)
		assert_true(float(m["viewers_max"]) <= EXTREME_MAX_VIEWERS, "peak viewers bounded — " + label)
		assert_true(float(m["hype_end"]) > float(human["hype_end"]), "more show than the reference — " + label)
		var top: int = 0
		for r: Dictionary in rows:
			for h: int in r["hype_end"] as Array[int]:
				top += 1 if h >= SponsorSystem.THRESHOLDS[0] else 0
		assert_gt(top, 0, "regular fights reach sponsor territory (>= %d) — %s" % [SponsorSystem.THRESHOLDS[0], label])
		for r: Dictionary in rows:
			var regular: int = (r["hype_end"] as Array[int]).size()
			var cap: int = regular * SponsorSystem.MAX_GIFTS_PER_BATTLE \
				+ (r["boss"] as Dictionary).size() * SponsorSystem.MAX_GIFTS_PER_BOSS_BATTLE
			assert_true(int(r["gifts"]) <= cap, "gift caps hold — " + label)


## GDD §13 "Hausmeister ~20 % Niederlage-Rate beim 1. Versuch, Königin ~35 %": auto battles at the GDD levels (5 / 7)
## with the bot's loadout (BOSS_LOADOUT) and the sponsor gifts as they occur. The fight starts at the exploration floor
## (BOSS_HYPE_START): before a boss one heals in a safe room and the walk to the boss room cools the show down (full-run
## bot, 30 human-pace runs: median hype at the start 25 Hausmeister / 30 Königin). The bot's own first-try loss rates on
## the real game are in the GDD §13 table.
func test_boss_loss_rates_with_gifts() -> void:
	for enc_id: String in BOSS_WIN_BAND:
		var hype0: float = BOSS_HYPE_START
		var with_gifts: Dictionary = _boss_series(enc_id, hype0, true)
		var without: Dictionary = _boss_series(enc_id, hype0, false)
		var band: Vector2 = BOSS_WIN_BAND[enc_id]
		var turns: Vector2 = M7.BOSS_TURNS[enc_id]
		var label: String = "%s at L%d, hype %.0f: %s / without gifts %s" % [enc_id, int(M7.PLAN[enc_id][0]), hype0,
			str(with_gifts), str(without)]
		print("[m7_show] ", label)
		assert_between(float(with_gifts["win_rate"]), band.x, band.y, "win rate with gifts — " + label)
		assert_between(float(with_gifts["turns"]), turns.x, turns.y, "party turns per won fight — " + label)
		assert_between(float(with_gifts["gifts"]), 1.0, float(SponsorSystem.MAX_GIFTS_PER_BOSS_BATTLE),
			"the sponsors show up in a boss fight, within the cap — " + label)
		assert_true(float(with_gifts["win_rate"]) >= float(without["win_rate"]) - 0.05,
			"gifts help (never cost more than noise) — " + label)


# --- helpers (tests) --------------------------------------------------------------------------------------------------

func _seasons(policy: String, pace: float, n: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i in n:
		rows.append(run_season(SeedUtil.derive(4242, "m7_show_season", i), policy, pace))
	return rows


## Medians over seasons of the per-season numbers; hype_start / hype_end / hype_gain over all regular fights.
static func _medians(rows: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ["followers", "viewers_max", "gifts", "achievements", "boxes"]:
		var v: Array = []
		for r: Dictionary in rows:
			v.append(int(r[k]))
		out[k] = median(v)
	var hs: Array = []
	var he: Array = []
	var hg: Array = []
	for r: Dictionary in rows:
		var s: Array[int] = r["hype_start"]
		var e: Array[int] = r["hype_end"]
		for i in s.size():
			hs.append(s[i])
			he.append(e[i])
			hg.append(e[i] - s[i])
	out["hype_start"] = median(hs)
	out["hype_end"] = median(he)
	out["hype_gain"] = median(hg)
	return out


## BOSS_SEEDS auto battles of a boss at its PLAN level/gear/kit, hype0 at the start → {"win_rate", "turns", "gifts"}.
func _boss_series(enc_id: String, hype0: float, gifts_on: bool) -> Dictionary:
	var p: Array = M7.PLAN[enc_id]
	var wins: int = 0
	var turns: int = 0
	var gifts: int = 0
	for i in BOSS_SEEDS:
		Game.state = GameState.create_new(real_data(), 0, "Kai", SeedUtil.derive(4242, "m7_boss_state", i))
		Game.state.show.hype = hype0
		for a: AchievementDef in real_data().all_achievements():
			Game.state.show.achievements.append(a.id)          # no achievement hype: the boss fight alone
		var r: Dictionary = show_battle(enc_id, int(p[0]), str(p[1]), str(p[2]), SeedUtil.derive(7331, "m7_boss", i),
			AUTO, gifts_on, BattleSetup.Advantage.NORMAL, BOSS_LOADOUT[enc_id])
		Game.state = null
		if bool(r["win"]):
			wins += 1
			turns += int(r["turns"])
		gifts += int(r["gifts"])
	return {"win_rate": snappedf(float(wins) / float(BOSS_SEEDS), 0.01),
		"turns": snappedf(float(turns) / float(maxi(1, wins)), 0.1),
		"gifts": snappedf(float(gifts) / float(BOSS_SEEDS), 0.01)}
