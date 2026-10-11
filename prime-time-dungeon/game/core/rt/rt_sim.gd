class_name RtSim extends RefCounted
## One real-time combat (07 §3). Deterministic: same RtSetup + same submitted commands (with ct) → same events, same
## snapshot hashes. No autoloads, no SceneTree, no clock: the caller decides when a tick passes (07 §3.3: tick
## boundary → submit → step). Integer math only (07 §3.14); every random draw has its own generator
## SeedUtil.derive(setup.seed, "rt", rng_n).
##
## R1b-I1: move samples and their plausibility, the set geometry, the exact tick order, GCD / casts / channels / queue
## / cancel thresholds, auto-attacks, party abilities with SHOW / FINALE and the Partner-Spezial order, items,
## statuses, threat, the damage fold, the MP economy, results, snapshot and the pure queries. R1b-I2: the rule AI of
## the AI partner and the autopilot (RtRules with presets, switches and the fixed engine rules), the human reaction of
## E25 (ai_seen from the own AI stream "rt_ai", the GCD tail), the telegraph reaction (react_at, RtGeo.escape_point),
## the assist (suggest). R1b-I3: the enemy rules (rt.rules / the phase rules, slot offset), telegraph skills with
## their anchors, impacts, dodges, zones and MAX_TELEGRAPHS (Tele), boss phases with their ops, enrage, summons,
## credit theft and escape (Boss), the static modifiers (RtMods: fold factors, skill factors, forbid ops, shared
## rules, "on" reactions), sponsor gifts at the tick boundary (Gifts), random targets, run_to_end.
## Steps of a tick and their helpers: 1a Movement.player_positions, 1b Ability.apply_commands, 2 StatusFx.tick_all,
## 3 Tele.zones, 4 Tele.impacts, 5 Ability.resolve_hits, 6 Ability.end_casts, 7 Ability.queue_and_ai → ai_step, 8
## Ability.auto_attacks, 9 Movement.move_units + Tele.track, 10 Boss.step + Result.check_end, 11 _clock; then the
## RtMods "on" reactions to the events of the tick.
## The methods after "--- helper interface" serve the private helpers of core/rt; nothing outside core/rt calls them.

const TICKS_PER_SEC: int = 30
## Staggered AI thinking (07 §3.15, §5.3): a sim-driven unit picks its target, rules and goal every AI_THINK_TICKS
## ticks, at (ct + its index in the unit list) % AI_THINK_TICKS == 0; reactions and movement run every tick.
const AI_THINK_TICKS: int = 3
## The AI escapes shapes that strike within this many ticks (07 §5.5).
const ESCAPE_LOOKAHEAD_TICKS: int = 60
## Reasons a rule's "then" follow-up waits out (anything else drops it).
const FOLLOW_UP_WAIT: PackedStringArray = ["queue", "gcd", "casting", "drinking", "stunned", "locked"]
const _NONE: Dictionary = {}                 # the empty, read-only skill set of known_skills
const FixedMath := preload("res://core/stats/fixed_math.gd")
const Ability := preload("res://core/rt/rt_ability.gd")
const Damage := preload("res://core/rt/rt_damage.gd")
const StatusFx := preload("res://core/rt/rt_status_fx.gd")
const Threat := preload("res://core/rt/rt_threat.gd")
const Movement := preload("res://core/rt/rt_movement.gd")
const Result := preload("res://core/rt/rt_result.gd")
const Tele := preload("res://core/rt/rt_tele.gd")
const Boss := preload("res://core/rt/rt_boss.gd")
const Gifts := preload("res://core/rt/rt_gift.gd")
const TALLY_INTS: PackedStringArray = ["damage_taken", "crits", "weakness_hits", "party_kos", "turns", "party_turns",
	"interrupts", "dodges", "telegraph_hits", "train_kills", "perfect_phases", "flee_attempts", "potions_used",
	"credits_delta"]
const _NO_PMS: Array[int] = []              # the empty factor list of a unit without mods
const _NO_CMDS: Array[Dictionary] = []      # the commands of a tick without any (read-only)
const _NO_GOAL: Array = []                  # no rule goal (read-only)

var setup: RtSetup = null
var result: BattleResult = null             # set when finished

# --- state read and written by the helpers (all part of snapshot()) ------------------------------------------------
var bal: RtBalance = null                   # setup.balance (or RtBalance.from_data); not state, pinned by the data
var tally: Dictionary = {}                  # result counters (07 §3.12), kill lists, the thieves' ledger
var combo: Dictionary = {}                  # target id → [unit id, ct] of the last party ability hit
var combo_ready: int = 0                    # ct from which the next COMBO may happen
var items: Dictionary = {}                  # party battle inventory (item id → count), used up in combat
var fled: bool = false                      # the party fled (door lane 2 s, smoke) — FLED at step 10
var lane_n: Dictionary = {}                 # "<unit id>|<skill id>" → lane telegraphs cast so far (07 §6.3 "lane")
var first_hit: Dictionary = {}              # unit id → first_hit_taken_pm factors not used yet (RtMods)
var escape: Dictionary = {}                 # party unit id → [x, z]: the escape point of its running reaction (§5.5)

var _data: GameData = null
var _tick: int = 0
var _list: Array[RtUnit] = []               # the units (stable order, 07 §3.3); copies of setup.units
var _party: Array[RtUnit] = []              # the party units of _list (slot order; never changes)
var _time_regen: Array[RtUnit] = []         # the units of _list with mp_regen mode "time" (step 11), unit order
var _by_id: Dictionary = {}
var _ctl: String = ""                       # controlled unit id
var _rng_n: int = 0
var _ai_rng_n: int = 0
var _next_enemy: int = 0                    # next enemy number (summons, never reused)
var _next_tele: int = 1
var _cmds: Array[Dictionary] = []           # accepted commands not applied yet: {"ct", "n", "cmd"} in submit order
var _cmd_n: int = 0
var _hits: Array[Dictionary] = []           # pending hits (instants, auto-attacks), creation order
var _hits_next: int = 0                     # derived: the smallest "at" of _hits (no hit is due before it)
var _show_cd: Array[int] = [0, 0]           # party SHOW / FINALE cooldown [ready ct, length]
var _item_cd: Array[int] = [0, 0]           # party consumable cooldown [ready ct, length]
var _items_used: int = 0
var _opener: Dictionary = {}                # RtSetup.rt_opener until tick 0 is done
var _started: bool = false
var _out: Array[ActionEvent] = []
var _telegraphs: Array[RtTelegraph] = []
var _gift_n: int = 0                        # gifts applied (their generator: SeedUtil.derive(seed, "gift", n))
# --- derived once from setup + data (not state: a function of the start data) ------------------------------------
var _views: Dictionary = {}                 # skill id → SkillDef with the real-time power (rt.power ≠ power)
var _finale: Dictionary = {}                # party unit id → FINALE skill id (bar entry finale, level reached)
var _context: Dictionary = {}               # party unit id → [{"slot", "skill", "when"}] (level reached)
var _ps: Dictionary = {}                    # party unit id → Partner-Spezial skill (rt.partner_special, on its bar)
var _auto_target: Dictionary = {}           # enemy id → EnemyDef.rt.auto_target
var _followers: Dictionary = {}             # group leader id → [komparse ids] (pop-in after the leader's entry)
var _pop_in: int = 15                       # bal POP_IN_TICKS (read on every targetable())
var _margin: int = 60                       # bal ESCAPE_MARGIN_CM (read on every shape test of the AI's dodging)
var _slot_offset: int = 9                   # bal AI_SLOT_OFFSET_TICKS (enemy rule timers, 07 §5.3)
## Hot balance values and set facts, read once per combat (R5b perf; the balance and the geometry never change during a
## combat): the rule walk (RtRules), the checks (Ability), the goals (Movement) and the escape search (RtGeo).
var gcd_tail_ticks: int = 5                 # bal AI_INTERRUPT_GCD_TAIL_TICKS
var show_grace_ticks: int = 150             # bal AI_SHOW_GRACE_TICKS
var queue_ticks: int = 9                    # bal QUEUE_TICKS
var melee_stop_cm: int = 30                 # bal MELEE_STOP_CM
var finale_below_pm: int = 300              # bal FINALE_TARGET_BELOW_PM
var geo_r: int = 0                          # setup.geo "r": the set radius (0 = no set)
var geo_plain: bool = false                 # geo_r > 0 and no blockers: walkable(p, r, false) ⇔ |p| ≤ geo_r − r
var geo_cell_half: int = 800                # setup.geo "cell_half" (Movement.in_cell)
var threat_switch_pm: int = 1100            # bal THREAT_SWITCH_PM (Threat.top_target)
var max_combat_ticks: int = 18000           # bal MAX_COMBAT_TICKS (Result.check_end)
var dr_max_ticks: int = 30                  # bal DR_MAX_TICKS (Movement.dead_reckon)
var _bar_known: Dictionary = {}             # party unit id → {skill id: true} of its bar (static per combat)
var _known_all: Dictionary = {}             # party unit id → {skill id: true}: bar + FINALE + context variants
var _assist: Dictionary = {}                # party unit id → compiled rules of its assist_preset (§5.6)
var _intr_mp: Dictionary = {}               # party unit id → MP of its interrupter on the bar (filler reserve)
var _skill_defs: Dictionary = {}            # skill id → SkillDef | null (memo of skill_def)
var _skill_meta: Dictionary = {}            # skill id → PackedInt32Array (memo of skill_meta)
var _enemy_rts: Dictionary = {}             # enemy def id → EnemyDef.rt (memo of enemy_rt)
var _skill_area: Dictionary = {}            # skill id → PackedInt32Array (memo of skill_area)
var _skill_area_rt: Dictionary = {}         # skill id → the rt block the memo was made from (identity check)
var _foes: Array[RtUnit] = []               # enemies with rt.phases or an enrage block (Boss.step), unit order
var _mods_any: bool = false                 # RtSetup.mods is not empty
var _on_any: bool = false                   # some mod has op "on"
var _mod_dealt: Dictionary = {}             # unit id → Array[int] dmg_dealt_pm factors (RtMods)
var _mod_taken: Dictionary = {}             # unit id → Array[int] dmg_taken_pm factors
var _mod_heal: Dictionary = {}              # unit id → Array[int] heal_taken_pm factors
var _forbid: Dictionary = {}                # unit id → {"skills": {id: true}, "tags": [tags]} (forbid ops)
var _skill_mods: Array[Dictionary] = []     # the skill_pm mods
var _skill_pm: Dictionary = {}              # "<unit id>|<skill id>" → [power, cooldown, cast, mp] ‰ (memo)
var _unit_views: Dictionary = {}            # "<unit id>|<skill id>" → SkillDef with the unit's power factor (memo)


func _init(p_setup: RtSetup, p_data: GameData) -> void:
	setup = p_setup
	_data = p_data
	bal = setup.balance if setup != null and setup.balance != null else RtBalance.from_data(p_data)
	_pop_in = bal.i("POP_IN_TICKS")
	_margin = bal.i("ESCAPE_MARGIN_CM")
	_slot_offset = bal.i("AI_SLOT_OFFSET_TICKS")
	gcd_tail_ticks = bal.i("AI_INTERRUPT_GCD_TAIL_TICKS")
	show_grace_ticks = bal.i("AI_SHOW_GRACE_TICKS")
	queue_ticks = bal.i("QUEUE_TICKS")
	melee_stop_cm = bal.i("MELEE_STOP_CM")
	finale_below_pm = bal.i("FINALE_TARGET_BELOW_PM")
	threat_switch_pm = bal.i("THREAT_SWITCH_PM")
	max_combat_ticks = bal.i("MAX_COMBAT_TICKS")
	dr_max_ticks = bal.i("DR_MAX_TICKS")
	if setup != null:
		geo_r = int(setup.geo.get("r", 0))
		geo_plain = geo_r > 0 and (setup.geo.get("blockers", []) as Array).is_empty()
		geo_cell_half = int(setup.geo.get("cell_half", RtGeo.DEFAULT_CELL_HALF))
	tally = {"killed": [], "overkill": [], "weak_found": {}, "item_delta": {}, "escaped": [], "thieves": {}}
	for k: String in TALLY_INTS:
		tally[k] = 0
	if setup == null:
		return
	for su: RtUnit in setup.units:
		var u: RtUnit = su.duplicate_unit()
		_list.append(u)
		_by_id[u.id] = u
		if u.side == Combatant.Side.PARTY:
			_party.append(u)
		if str(u.mp_regen.get("mode", "")) == "time":
			_time_regen.append(u)
		if u.side == Combatant.Side.ENEMY and u.id.begins_with("e"):
			_next_enemy = maxi(_next_enemy, u.id.substr(1).to_int() + 1)
	_ctl = setup.controlled_id if _by_id.has(setup.controlled_id) else _first_party_id()
	for k: Variant in setup.items.keys():
		items[str(k)] = JsonUtil.to_int(setup.items[k])
	_derive()


## ct 0 prelude: BATTLE_START, ANNOUNCE (first strike / ambush), POS_CORRECTED (party outside the ring), STATUS_ADDED
## (dazed), the start threat, PHASE_CHANGE of the bosses (their first phase with its ops), the "on combat_start"
## reactions (RtMods); the pull opener runs at ct 0 (07 §2.2, §3.4). Called by the first step() if needed.
func start() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if _started or setup == null:
		return out
	_started = true
	_out = out
	var bs: ActionEvent = ev(ActionEvent.Type.BATTLE_START)
	bs.value = int(setup.advantage)
	for u: RtUnit in _list:
		bs.target_ids.append(u.id)
	if setup.advantage == BattleSetup.Advantage.PREEMPTIVE:
		ev(ActionEvent.Type.ANNOUNCE).text = "Erstschlag!"
	elif setup.advantage == BattleSetup.Advantage.AMBUSH:
		ev(ActionEvent.Type.ANNOUNCE).text = "Hinterhalt!"
	var geo: Dictionary = setup.geo
	for u: RtUnit in _list:
		if u.side == Combatant.Side.PARTY and is_alive(u) and not RtGeo.in_circle(geo, u.x, u.z, u.radius):
			var q: Vector2i = RtGeo.project_walkable(geo, u.x, u.z, u.radius, false)
			u.x = q.x
			u.z = q.y
			Movement.pos_corrected(self, u)
	var ctl: RtUnit = unit(_ctl)
	if ctl != null and ctl.driver == RtUnit.Driver.PLAYER and ctl.sample.size() != 6:
		ctl.sample = [0, ctl.x, ctl.z, 0, 0, ctl.yaw]
	var dazed: StatusDef = status_def("sts_dazed")
	if dazed != null:
		var ms: int = int(StatusFx.rt_of(dazed, "default_ms", 3000))
		for u: RtUnit in _list:
			if not is_alive(u):
				continue
			if setup.advantage == BattleSetup.Advantage.PREEMPTIVE and u.side == Combatant.Side.ENEMY and not u.is_boss:
				StatusFx.apply(self, "", u, "sts_dazed", ms, 1000, 0, null, true)
			elif setup.advantage == BattleSetup.Advantage.AMBUSH and u.side == Combatant.Side.PARTY:
				StatusFx.apply(self, "", u, "sts_dazed", maxi(100, ms / 2), 1000, 0, null, true)
	_opener = setup.rt_opener.duplicate(true)
	var opener_unit: RtUnit = _opener_unit()
	var target: RtUnit = unit(str(_opener.get("target", "")))
	if opener_unit != null and target != null and target.side != opener_unit.side:
		Ability.target_change(self, opener_unit, target.id)
		if str(_opener.get("kind", "")) == "strike":
			opener_unit.swing_ready = 0
	_start_threat(opener_unit)
	Boss.start(self)
	if _on_any:
		_react_mods(0)
	return out


## Schema + static checks (RtCommand.validate, ct ≥ tick(), unit exists and is the person's to command, the skill is on
## the unit's bar / unlocked, tutorial and run rules); "" = queued for cmd.ct, else one of RtCommand.REASONS. The
## dynamic checks (GCD, MP, range, …) happen in step 1b of that tick (07 §3.4 "zwei Prüfstufen").
func submit(cmd: Dictionary) -> String:
	if is_finished():
		return "finished"
	if RtCommand.validate(cmd) != "":
		return "schema"
	var t: String = str(cmd.get("t", ""))
	if not RtCommand.CT_TYPES.has(t):
		return "schema"
	if JsonUtil.to_int(cmd.get("ct", -1), -1) < tick():
		return "past_tick"
	if t == "move_input":
		return "grade_b"
	if t == "combat_hint":
		return ""
	var u: RtUnit = unit(str(cmd.get("u", "")))
	if u == null:
		return "unknown_unit"
	var why: String = _static_check(t, u, cmd)
	if why != "":
		return why
	_cmd_n += 1
	_cmds.append({"ct": JsonUtil.to_int(cmd["ct"]), "n": _cmd_n, "cmd": _norm(cmd)})
	return ""


## Processes tick() and returns its events (07 §3.3); the first call plays start() if it has not run.
func step() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if is_finished() or setup == null:
		return out
	if not _started:
		out.append_array(start())
	_out = out
	var c: int = _tick
	var samples: Array[Dictionary] = _NO_CMDS
	var rest: Array[Dictionary] = _NO_CMDS
	if not _cmds.is_empty():
		samples = []
		rest = []
		for e: Dictionary in _take_cmds(c):
			if str((e["cmd"] as Dictionary).get("t", "")) == "move_sample":
				samples.append(e)
			else:
				rest.append(e)
	var mark: int = out.size()
	Movement.player_positions(self, c, samples)          # 1a
	Ability.apply_commands(self, rest)                   # 1b
	StatusFx.tick_all(self, c)                           # 2
	if not _telegraphs.is_empty():
		Tele.zones(self, c)                              # 3
		Tele.impacts(self, c)                            # 4
	Ability.resolve_hits(self, c)                        # 5
	Ability.end_casts(self, c)                           # 6
	Ability.queue_and_ai(self, c)                        # 7
	Ability.auto_attacks(self, c)                        # 8
	Movement.move_units(self, c)                         # 9
	if not _telegraphs.is_empty():
		Tele.track(self, c)
	if c == 0:
		_opener = {}
	if not _foes.is_empty():
		Boss.step(self, c)                               # 10
	var outcome: int = Result.check_end(self, c)
	if outcome >= 0:
		_finish(outcome, c)
	else:
		_clock(c)                                        # 11
		if _on_any:
			_react_mods(mark)
	_tick = c + 1
	_out = []
	return out


## Index of the next tick to process (= processed ticks).
func tick() -> int:
	return _tick


func is_finished() -> bool:
	return result != null


## The controlled unit (changes on KO: control follows life, CONTROL_CHANGED).
func controlled_id() -> String:
	return _ctl


## null if unknown.
func unit(id: String) -> RtUnit:
	return _by_id.get(id, null) as RtUnit


## Stable order (07 §3.3); read-only for callers.
func units() -> Array[RtUnit]:
	var out: Array[RtUnit] = []
	out.assign(_list)
	return out


## Active telegraphs and zones, creation order; read-only.
func telegraphs() -> Array[RtTelegraph]:
	var out: Array[RtTelegraph] = []
	out.assign(_telegraphs)
	return out


## A gift at the tick boundary before step() of tick() (07 §9.2): its effects (Gifts: SPONSOR_GIFT, HEAL, MP_CHANGE,
## STATUS_ADDED, REVIVE, ITEM_GAINED, CREDITS_GAINED) with tick = tick() and rt.boundary = 1; chest rolls draw from
## SeedUtil.derive(seed, "gift", n) (n = gifts so far + 1), never from the combat stream. Plays start() first if it
## has not run; nothing once the combat is over.
func apply_gift(g: Dictionary) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if setup == null or is_finished():
		return out
	if not _started:
		out.append_array(start())
	_out = out
	var mark: int = out.size()
	_gift_n += 1
	Gifts.apply(self, g, SeedUtil.make_rng(SeedUtil.derive(setup.seed, "gift", _gift_n)))
	for i in range(mark, out.size()):
		var d: Dictionary = out[i].rt.duplicate()
		d["boundary"] = 1
		out[i].rt = d
	_out = []
	return out


## Headless: step until finished or max_ticks steps.
func run_to_end(max_ticks: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	var n: int = 0
	while not is_finished() and n < max_ticks:
		out.append_array(step())
		n += 1
	return out


## Canonical and complete (StateHash.of_rt, 07 §10.4): the combat counters, every unit (RtUnit.snapshot), telegraphs,
## pending hits, queued commands, the party cooldowns and inventory, the result, RtSetup.mods, the lane counters, the
## unused first-hit factors, the gift counter and the kept escape points.
func snapshot() -> Dictionary:
	var us: Array = []
	for u: RtUnit in _list:
		us.append(u.snapshot())
	var tg: Array = []
	for t: RtTelegraph in _telegraphs:
		tg.append(t.to_dict())
	return {"ct": _tick, "rng_n": _rng_n, "ai_rng_n": _ai_rng_n, "next_enemy": _next_enemy, "next_tele": _next_tele,
		"controlled_id": _ctl, "started": _started, "finished": is_finished(), "result": _result_dict(),
		"show_cd": Array(_show_cd), "item_cd": Array(_item_cd), "items_used": _items_used,
		"items": RtUnit._canon(items), "combo": RtUnit._canon(combo), "combo_ready": combo_ready, "fled": fled,
		"opener": RtUnit._canon(_opener), "tally": RtUnit._canon(tally), "units": us, "telegraphs": tg,
		"hits": RtUnit._canon(_hits), "cmds": RtUnit._canon(_cmds),
		"mods": RtUnit._canon(setup.mods if setup != null else []), "lanes": RtUnit._canon(lane_n),
		"first_hit": RtUnit._canon(first_hit), "gift_n": _gift_n, "escape": RtUnit._canon(escape)}


# --- pure queries: no RNG draw, no state change, no events (test_r1_rt_pure) -----------------------------------------

## "" (a use now would start or be buffered) or the refusal reason (HUD states, 07 §8.2).
func can_use(unit_id: String, skill_id: String, target_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null:
		return "unknown_unit"
	var reason: String = str(Ability.check(self, u, skill_id, target_id)["reason"])
	return "" if reason == "queue" else reason


func can_use_item(unit_id: String, item_id: String, target_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null:
		return "unknown_unit"
	if setup.tutorial:
		return "forbidden"
	return str(Ability.check_item(self, u, item_id, target_id)["reason"])


## Assist (§5.6): skill id of the ability the assist suggests for the party unit now ("" = none) — the first rule of its
## assist_preset list (party.json rt) it could use now (usable or buffered; no items, no movement, no AI reserve).
func suggest(unit_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null or u.side != Combatant.Side.PARTY:
		return ""
	return RtRules.suggest(self, u, _assist.get(u.id, []))


## Slot (1..6) → skill / item id shown right now (07 §4.1): the bar (loadout, level), slot 2 as its context variant
## on a KO'd friendly target, slot 5 as FINALE (level reached, hostile target below FINALE_TARGET_BELOW_PM), slot 6 the
## potion pick (if any heal item is left). Tutorial combat: slots 1 and 5 of the controlled unit only (E28).
func bar(unit_id: String) -> Dictionary:
	var u: RtUnit = unit(unit_id)
	var out: Dictionary = {}
	if u == null or u.side != Combatant.Side.PARTY:
		return out
	var slots: Array = u.bar.keys()
	slots.sort()
	for s: Variant in slots:
		out[int(s)] = str(u.bar[s])
	var tut: bool = setup.tutorial and u.id == _ctl
	if tut:
		for s: int in out.keys():
			if s != 1 and s != 5:
				out.erase(s)
		return out
	var t: RtUnit = unit(u.target_id)
	for cx: Dictionary in _context.get(u.id, []):
		if str(cx.get("when", "")) == "target_ko" and t != null and t.side == u.side and t.is_ko():
			out[int(cx["slot"])] = str(cx["skill"])
	var fin: String = str(_finale.get(u.id, ""))
	if fin != "" and t != null and t.side != u.side and targetable(t) \
			and t.hp * 1000 < t.max_hp() * bal.i("FINALE_TARGET_BELOW_PM"):
		out[5] = fin
	var potion: String = Ability.potion_pick(self, u)
	if potion != "":
		out[6] = potion
	return out


## bar(unit_id).get(slot, "") without building the whole bar (the FINALE check of the bot, the HUD): the same rules —
## tutorial slots 1 and 5 only, a context variant on a KO'd friendly target, slot 5 as FINALE, slot 6 the potion pick.
## Pure.
func bar_slot(unit_id: String, slot: int) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null or u.side != Combatant.Side.PARTY:
		return ""
	var v: String = ""
	for k: Variant in u.bar:
		if int(k) == slot:
			v = str(u.bar[k])
	if setup.tutorial and u.id == _ctl:
		return v if slot == 1 or slot == 5 else ""
	var t: RtUnit = unit(u.target_id)
	for cx: Dictionary in _context.get(u.id, []):
		if int(cx["slot"]) == slot and str(cx.get("when", "")) == "target_ko" and t != null and t.side == u.side \
				and t.is_ko():
			v = str(cx["skill"])
	if slot == 5:
		var fin: String = str(_finale.get(u.id, ""))
		if fin != "" and t != null and t.side != u.side and targetable(t) \
				and t.hp * 1000 < t.max_hp() * bal.i("FINALE_TARGET_BELOW_PM"):
			v = fin
	elif slot == 6:
		var potion: String = Ability.potion_pick(self, u)
		if potion != "":
			v = potion
	return v


## Skill the Partner-Spezial would order now ("" = none: no AI partner, not learned, tutorial, KO).
func partner_special_skill(unit_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	if u == null or u.side != Combatant.Side.PARTY or u.id == _ctl or not is_alive(u) or setup.tutorial:
		return ""
	return str(_ps.get(u.id, ""))


## Ticks (SHOW / FINALE: the party-shared SHOW cooldown).
func cooldown_left(unit_id: String, skill_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	if u == null:
		return 0
	if is_show_skill(u, skill_id):
		return show_cd_left()
	return Ability.cooldown_left(self, u, skill_id)


## Length of the running cooldown in ticks (0 = none).
func cooldown_total(unit_id: String, skill_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	if u == null or cooldown_left(unit_id, skill_id) <= 0:
		return 0
	if is_show_skill(u, skill_id):
		return _show_cd[1]
	return int((u.cooldowns[skill_id] as Array)[1])


func gcd_left(unit_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	return maxi(0, u.gcd_until - _tick) if u != null else 0


func gcd_total(unit_id: String) -> int:
	var u: RtUnit = unit(unit_id)
	return u.gcd_len if u != null and u.gcd_until > _tick else 0


## (elapsed, total) ticks of the running cast / channel / drink; (0, 0) = none.
func cast_progress(unit_id: String) -> Vector2i:
	var u: RtUnit = unit(unit_id)
	if u == null or u.cast.is_empty():
		return Vector2i.ZERO
	var s: int = int(u.cast.get("start", 0))
	var e: int = int(u.cast.get("end", 0))
	return Vector2i(clampi(_tick - s, 0, maxi(0, e - s)), maxi(0, e - s))


## Party-shared consumable cooldown (07 §3.11).
func item_cd_left() -> int:
	return maxi(0, _item_cd[0] - _tick)


func item_cd_total() -> int:
	return _item_cd[1] if item_cd_left() > 0 else 0


## Consumables still allowed in this combat (0..ITEM_MAX_PER_COMBAT).
func items_left() -> int:
	return maxi(0, bal.i("ITEM_MAX_PER_COMBAT") - _items_used)


# --- helper interface (core/rt only) ---------------------------------------------------------------------------------

## The units without a copy (helpers iterate it; never resized while iterating within a step).
func units_ref() -> Array[RtUnit]:
	return _list


## The party units without a copy (slot order; the party never changes during a combat).
func party_ref() -> Array[RtUnit]:
	return _party


## AI_SLOT_OFFSET_TICKS (07 §5.3: an enemy's first rule readiness is first_ms + slot × this).
func slot_offset() -> int:
	return _slot_offset


func is_alive(u: RtUnit) -> bool:
	return u != null and u.hp > 0 and not u.left_battle


## Alive and on stage: a komparse waiting for its leader's entry (pop-in) is not yet in the picture.
func targetable(u: RtUnit) -> bool:
	return u != null and u.hp > 0 and not u.left_battle \
		and (u.side != Combatant.Side.ENEMY or _tick >= u.pop_in_until - _pop_in)


## targetable() for a loop without a call per unit: an enemy is on stage when pop_in_until ≤ this (tick + POP_IN).
func on_stage_gate() -> int:
	return _tick + _pop_in


## RtGeo.in_circle(setup.geo, x, z, r) without the dictionary: inside the ring part |p| ≤ geo.r − r.
func in_ring(x: int, z: int, r: int) -> bool:
	var big: int = geo_r - r
	return geo_r > 0 and big >= 0 and x * x + z * z <= big * big


## RtGeo.walkable(setup.geo, x, z, r, true) (party: ring or open door lane) with the plain-set case first.
func walkable_party(x: int, z: int, r: int) -> bool:
	if geo_plain:
		return in_ring(x, z, r) or RtGeo.in_gap(setup.geo, x, z, r)
	return RtGeo.walkable(setup.geo, x, z, r, true)


## RtGeo.walkable(setup.geo, x, z, r, false) (ring only, no door lanes) with the plain-set case first.
func walkable_ring(x: int, z: int, r: int) -> bool:
	if geo_plain:
		return in_ring(x, z, r)
	return RtGeo.walkable(setup.geo, x, z, r, false)


## Sim-driven units choose by AI: enemies, the AI partner, the autopilot (by_ai, 07 §3.13).
func is_ai_driven(u: RtUnit) -> bool:
	return u.side == Combatant.Side.ENEMY or u.driver != RtUnit.Driver.PLAYER


## A new generator for one random draw group (07 §3.9.3).
func rng() -> RandomNumberGenerator:
	_rng_n += 1
	return SeedUtil.make_rng(SeedUtil.derive(setup.seed, "rt", _rng_n))


## A new generator for one draw of the AI reactions (E25, 07 §3.9.3): its own stream "rt_ai" and counter, so neither the
## AI nor an autopilot switch shifts a damage, status or loot draw.
func ai_rng() -> RandomNumberGenerator:
	_ai_rng_n += 1
	return SeedUtil.make_rng(SeedUtil.derive(setup.seed, "rt_ai", _ai_rng_n))


## A new event of the running tick, appended to the output.
func ev(t: ActionEvent.Type) -> ActionEvent:
	var e: ActionEvent = ActionEvent.make(t)
	e.tick = _tick
	_out.append(e)
	return e


func ev_target(t: ActionEvent.Type, u: RtUnit) -> ActionEvent:
	var e: ActionEvent = ev(t)
	e.target_id = u.id
	e.def_id = u.def_id
	return e


func def_of(unit_id: String) -> String:
	var u: RtUnit = unit(unit_id)
	return u.def_id if u != null else ""


## The SkillDef of `id` (null if unknown); memoized (the data never changes during a combat — not state).
func skill_def(id: String) -> SkillDef:
	var d: Variant = _skill_defs.get(id, false)
	if d is bool:
		d = _data.skill(id) if _data != null and id != "" and _data.has_id("skills", id) else null
		_skill_defs[id] = d
	return d as SkillDef


func status_def(id: String) -> StatusDef:
	return _data.status(id) if _data != null and id != "" and _data.has_id("statuses", id) else null


func item_def(id: String) -> ItemDef:
	return _data.item(id) if _data != null and id != "" and _data.has_id("items", id) else null


## The skill with its real-time power (rt.power overrides power, 07 §3.9.1) for DamageCalc.
func view(sk: SkillDef) -> SkillDef:
	if sk == null or int(sk.rt.get("power", sk.power)) == sk.power:
		return sk
	var v: SkillDef = _views.get(sk.id, null) as SkillDef
	return v if v != null else _make_view(sk)


## Static: may unit u use skill_id at all (bar, FINALE, context variants; enemies: any)?
func knows(u: RtUnit, skill_id: String) -> bool:
	return u.side == Combatant.Side.ENEMY or known_skills(u).has(skill_id)


## knows() of a party unit as a set {skill id: true} (read-only; the tutorial's controlled unit: its bar only); {} for
## enemies (they may use any skill).
func known_skills(u: RtUnit) -> Dictionary:
	var d: Variant = (_bar_known if setup.tutorial and u.id == _ctl else _known_all).get(u.id)
	return d if d != null else _NONE


## The FINALE of a party unit ("" if none reached).
func finale_of(u: RtUnit) -> String:
	return _finale.get(u.id, "")


## Static facts of a skill for the rule engine (memoized, not state; RtRules.M_*): [known to the data, GCD, MP cost,
## cast or channel, moving_cancels, SHOW category] as 0/1 (MP as the cost).
func skill_meta(id: String) -> PackedInt32Array:
	var m: Variant = _skill_meta.get(id)
	if m == null:
		var sk: SkillDef = skill_def(id)
		var pm: PackedInt32Array = [0, 0, 0, 0, 0, 0]
		if sk != null:
			var cast_like: bool = int(sk.rt.get("cast_ms", 0)) * 3 / 100 > 0 or Ability.channel_ticks(sk) > 0
			pm = [1, 1 if bool(sk.rt.get("gcd", true)) else 0, Ability.mp_cost(sk), 1 if cast_like else 0,
				1 if bool(sk.rt.get("moving_cancels", false)) else 0, 1 if sk.is_stunt() else 0]
		_skill_meta[id] = pm
		m = pm
	return m


## Static area facts of a skill (memoized, not state; Ability.targets / Ability.A_*): [rt.range_cm, rt.aoe.radius_cm,
## rt.aoe.cone_deg, aoe.center == "self" (the default) as 1/0, rt.aoe.max_targets].
func skill_area(sk: SkillDef) -> PackedInt32Array:
	var a: Variant = _skill_area.get(sk.id)
	if a == null or not is_same(sk.rt, _skill_area_rt.get(sk.id)):    # (views share their skill's rt block)
		var rt: Dictionary = sk.rt
		var aoe: Dictionary = rt.get("aoe", {})
		var pa: PackedInt32Array = [int(rt.get("range_cm", 0)), int(aoe.get("radius_cm", 0)), int(aoe.get("cone_deg", 0)),
			1 if str(aoe.get("center", "self")) == "self" else 0, int(aoe.get("max_targets", 0))]
		_skill_area[sk.id] = pa
		_skill_area_rt[sk.id] = rt
		a = pa
	return a


## RtMods forbid_skill (07 §9.5): the skill is forbidden for the unit.
func forbidden_skill(u: RtUnit, skill_id: String) -> bool:
	if _forbid.is_empty() or u == null:
		return false
	var f: Variant = _forbid.get(u.id)
	return f != null and ((f as Dictionary)["skills"] as Dictionary).has(skill_id)


## The tutorial forbids items (E28), a closed set the smoke bomb (07 §4.5); RtMods forbid_items: an item with a
## forbidden tag of the unit.
func forbidden_item(u: RtUnit, item_id: String) -> bool:
	if setup.tutorial:
		return true
	var it: ItemDef = item_def(item_id)
	if it != null and not _forbid.is_empty() and u != null and _forbid.has(u.id):
		for tag: String in ((_forbid[u.id] as Dictionary)["tags"] as PackedStringArray):
			if it.tags.has(tag):
				return true
	var sk: SkillDef = skill_def(it.use_skill) if it != null else null
	return sk != null and sk.flee_guaranteed and (bool(setup.geo.get("closed", false)) or not setup.can_flee)


## SHOW (stunt category) or FINALE of a party unit: the party-shared SHOW cooldown (07 §3.6.12).
func is_show_skill(u: RtUnit, skill_id: String) -> bool:
	if u == null or u.side != Combatant.Side.PARTY:
		return false
	if is_finale(u, skill_id):
		return true
	var sk: SkillDef = skill_def(skill_id)
	return sk != null and sk.is_stunt()


func is_finale(u: RtUnit, skill_id: String) -> bool:
	return skill_id != "" and str(_finale.get(u.id, "")) == skill_id


func show_cd_left() -> int:
	return maxi(0, _show_cd[0] - _tick)


## Another party unit is casting a SHOW (its cooldown starts at the cast end — nobody else fires meanwhile).
func show_cast_running(u: RtUnit) -> bool:
	for v: RtUnit in _list:
		if v != u and v.side == Combatant.Side.PARTY and not v.cast.is_empty() \
				and is_show_skill(v, str(v.cast.get("skill", ""))):
			return true
	return false


func start_show_cd() -> void:
	var length: int = bal.i("SHOW_CD_TICKS")
	_show_cd = [_tick + length, length]


## A consumable is used (07 §3.11): one less in the inventory, the party cooldown starts, it counts against the limit.
func use_up_item(item_id: String) -> void:
	items[item_id] = maxi(0, int(items.get(item_id, 0)) - 1)
	var delta: Dictionary = tally["item_delta"]
	delta[item_id] = int(delta.get(item_id, 0)) - 1
	_items_used += 1
	tally["potions_used"] = int(tally["potions_used"]) + 1
	var length: int = bal.i("ITEM_CD_TICKS")
	_item_cd = [_tick + length, length]


## ACTION_START bookkeeping: turns (all), party_turns (by_ai false, 07 §3.12).
func note_action(_u: RtUnit, ai: bool) -> void:
	tally["turns"] = int(tally["turns"]) + 1
	if not ai:
		tally["party_turns"] = int(tally["party_turns"]) + 1


func add_hit(h: Dictionary) -> void:
	_hits_next = mini(_hits_next, int(h["at"])) if not _hits.is_empty() else int(h["at"])
	_hits.append(h)


## The pending hits due at c (removed from the list), creation order.
func take_due_hits(c: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if _hits.is_empty() or c < _hits_next:              # (nothing due: the list stays as it is)
		return due
	var keep: Array[Dictionary] = []
	var next: int = 0
	for h: Dictionary in _hits:
		var at: int = int(h["at"])
		if at <= c:
			due.append(h)
		else:
			next = mini(next, at) if not keep.is_empty() else at
			keep.append(h)
	_hits = keep
	_hits_next = next
	return due


func end_action(unit_id: String, skill_id: String, item_id: String) -> void:
	var e: ActionEvent = ev(ActionEvent.Type.ACTION_END)
	e.actor_id = unit_id
	e.skill_id = skill_id
	e.item_id = item_id


## CAST_FAILED (moved, target, mp, stunned, dead) + ACTION_END; MP and cooldown stay (07 §3.6.5).
func fail_cast(u: RtUnit, why: String) -> void:
	var skill_id: String = str(u.cast.get("skill", ""))
	var item_id: String = str(u.cast.get("item", ""))
	var e: ActionEvent = ev(ActionEvent.Type.CAST_FAILED)
	e.actor_id = u.id
	e.skill_id = skill_id
	e.text = why
	cast_over(u)
	end_action(u.id, skill_id, item_id)


## Interrupts tgt's interruptible cast / channel (07 §3.6.8): CAST_INTERRUPTED, the spell goes into its cooldown,
## lockout INTERRUPT_LOCKOUT_TICKS. Counted for the result only for the person's own unit.
func interrupt(src: RtUnit, tgt: RtUnit, ai: bool) -> bool:
	if tgt == null or tgt.cast.is_empty() or not bool(tgt.cast.get("interruptible", true)) \
			or str(tgt.cast.get("kind", "")) == "item":
		return false
	var skill_id: String = str(tgt.cast.get("skill", ""))
	var e: ActionEvent = ev_target(ActionEvent.Type.CAST_INTERRUPTED, tgt)
	e.actor_id = src.id if src != null else ""
	e.skill_id = skill_id
	e.by_ai = ai
	if src != null and src.id == _ctl and not ai:
		tally["interrupts"] = int(tally["interrupts"]) + 1
	var sk: SkillDef = skill_def(skill_id)
	var cd: int = Ability.cooldown_ticks(self, tgt, sk) if sk != null else 0
	if cd > 0:
		tgt.cooldowns[skill_id] = [_tick + cd, cd]
	tgt.lockout_until = _tick + bal.i("INTERRUPT_LOCKOUT_TICKS")
	cast_over(tgt)
	end_action(tgt.id, skill_id, "")
	return true


## A cast / channel / drink of `u` is over (end, failure, interruption, KO, escape): an interrupt-worthy one is
## forgotten by every unit (ai_seen, E25); the telegraphs of a telegraph cast still pending are removed
## (TELEGRAPH_CANCELLED, 07 §6.3 — at the normal end they have struck already).
func cast_over(u: RtUnit) -> void:
	var worthy: bool = bool(u.cast.get("worthy", false))
	if int(u.cast.get("tele", -1)) > 0 and not _telegraphs.is_empty():
		Tele.cancel(self, u.id, int(u.cast.get("start", -1)), str(u.cast.get("skill", "")))
	u.cast = {}
	if worthy:
		for v: RtUnit in _list:
			v.ai_seen.erase(u.id)


## E25 (07 §5.3, §3.9.3): an interrupt-worthy cast of an enemy starts — every living party unit (slot order, whoever
## steers it) draws from the AI stream its jitter (0 … AI_INTERRUPT_JITTER_TICKS), then "late" (AI_INTERRUPT_LATE_PM
## ‰): ai_seen[caster] = start + AI_INTERRUPT_REACT_TICKS + jitter (+ AI_INTERRUPT_LATE_TICKS).
func notice_cast(caster: RtUnit) -> void:
	if caster.side == Combatant.Side.PARTY:
		return
	var start_ct: int = int(caster.cast.get("start", _tick))
	var react: int = bal.i("AI_INTERRUPT_REACT_TICKS")
	for v: RtUnit in _list:
		if v.side != Combatant.Side.PARTY or not is_alive(v):
			continue
		var jitter: int = ai_rng().randi_range(0, maxi(0, bal.i("AI_INTERRUPT_JITTER_TICKS")))
		var late: bool = FixedMath.roll_bp(ai_rng(), bal.i("AI_INTERRUPT_LATE_PM") * 10)
		v.ai_seen[caster.id] = start_ct + react + jitter + (bal.i("AI_INTERRUPT_LATE_TICKS") if late else 0)


## A new telegraph or zone of the running tick (07 §6.3): at most MAX_TELEGRAPHS at once — beyond that the oldest zone
## ends early (ZONE_END); with no zone to end the shape is not placed (0). Then its id, the set radius it is clipped
## to and TELEGRAPH_START (rt = {shape, x, z, yaw, r, r2, half, start, impact}, by_ai) with the reaction draws of the
## party (_notice_telegraph), or ZONE_START for a zone (status_id, rt = {shape, x, z, yaw, r, r2, half, start, end}).
## Returns the id.
func add_telegraph(t: RtTelegraph) -> int:
	while _telegraphs.size() >= bal.i("MAX_TELEGRAPHS"):
		var oldest: RtTelegraph = null
		for o: RtTelegraph in _telegraphs:
			if o.is_zone:
				oldest = o
				break
		if oldest == null:
			return 0
		end_zone(oldest)
	t.id = _next_tele
	_next_tele += 1
	if t.set_r <= 0:
		t.set_r = int(setup.geo.get("r", 0))
	var reach: int = t.bound_radius() + 2 * _margin
	t.far2 = reach * reach
	_telegraphs.append(t)
	var src: RtUnit = unit(t.source_id)
	var e: ActionEvent = ev(ActionEvent.Type.ZONE_START if t.is_zone else ActionEvent.Type.TELEGRAPH_START)
	e.actor_id = t.source_id
	e.skill_id = t.skill_id
	e.value = t.id
	if t.is_zone:
		e.status_id = t.status_id
		e.rt = {"shape": int(t.shape), "x": t.x, "z": t.z, "yaw": t.yaw, "r": t.r, "r2": t.r2, "half": t.half_deg,
			"start": t.start, "end": t.ends_at}
		return t.id
	e.rt = {"shape": int(t.shape), "x": t.x, "z": t.z, "yaw": t.yaw, "r": t.r, "r2": t.r2, "half": t.half_deg,
		"start": t.start, "impact": t.impact_at}
	e.by_ai = src != null and is_ai_driven(src)
	_notice_telegraph(t)
	return t.id


## The telegraphs and zones without a copy (Tele; never resized while a helper iterates it).
func telegraphs_ref() -> Array[RtTelegraph]:
	return _telegraphs


func remove_telegraph(t: RtTelegraph) -> void:
	_telegraphs.erase(t)


## A zone ends (its time is up, MAX_TELEGRAPHS, clear_zones): ZONE_END.
func end_zone(z: RtTelegraph) -> void:
	_telegraphs.erase(z)
	ev(ActionEvent.Type.ZONE_END).value = z.id


## The lane index of the next "lane" telegraph of `u` with skill `skill_id` (07 §6.3: alternating from the first).
func next_lane(u: RtUnit, skill_id: String) -> int:
	var key: String = "%s|%s" % [u.id, skill_id]
	var n: int = int(lane_n.get(key, 0))
	lane_n[key] = n + 1
	return n


## The shapes of telegraph skill `sk` cast by `u` now, striking at `impact_at` (Tele.create): the id of the first
## shape, 0 if none could be placed.
func telegraph_cast(u: RtUnit, sk: SkillDef, primary_id: String, impact_at: int) -> int:
	return Tele.create(self, u, sk, primary_id, impact_at)


## The warning ticks of a telegraph cast of `cast_t` cast ticks (Vorabendprogramm × EASY_WARN_PM, 07 §6.3).
func warn_ticks(cast_t: int) -> int:
	return Tele.warn_ticks(self, cast_t)


## The specials and summons of a skill at its effect (07 §3.12): credit theft / escape (skill.special), the enemies of
## skill.summon at the door.
func skill_extras(u: RtUnit, sk: SkillDef) -> void:
	if not sk.special.is_empty():
		Boss.special(self, u, sk)
	for k in sk.summon.size():
		if is_alive(u):
			Boss.summon(self, u, sk.summon[k], "door", k)


## A KO'd unit's pending telegraphs end (07 §3.3: TELEGRAPH_CANCELLED).
func drop_telegraphs(u: RtUnit) -> void:
	if not _telegraphs.is_empty():
		Tele.cancel(self, u.id, -1, "")


## Is (x, z) safe for `u` (07 §5.5): outside every hostile shape that strikes within ESCAPE_LOOKAHEAD_TICKS (grown by
## ESCAPE_MARGIN_CM) and outside every hostile zone. Pure (RtGeo.escape_point).
func safe_point(u: RtUnit, x: int, z: int) -> bool:
	for t: RtTelegraph in _telegraphs:
		if t.side != u.side or (t.far2 >= 0 and (x - t.x) * (x - t.x) + (z - t.z) * (z - t.z) > t.far2):
			continue
		if t.is_zone:
			if t.contains(x, z):
				return false
		elif t.impact_at > _tick and t.impact_at - _tick <= ESCAPE_LOOKAHEAD_TICKS and t.contains_inflated(x, z, _margin):
			return false
	return true


## The shapes safe_point tests for `u` (creation order): its side's zones and the pending telegraphs that strike within
## ESCAPE_LOOKAHEAD_TICKS — safe_among(danger_shapes(u), x, z) == safe_point(u, x, z) for many points (the escape
## search). Pure.
func danger_shapes(u: RtUnit) -> Array[RtTelegraph]:
	var out: Array[RtTelegraph] = []
	for t: RtTelegraph in _telegraphs:
		if t.side == u.side and (t.is_zone or (t.impact_at > _tick and t.impact_at - _tick <= ESCAPE_LOOKAHEAD_TICKS)):
			out.append(t)
	return out


## safe_point over a danger_shapes list. Pure.
func safe_among(shapes: Array[RtTelegraph], x: int, z: int) -> bool:
	for t: RtTelegraph in shapes:
		var dx: int = x - t.x
		var dz: int = z - t.z
		if t.far2 >= 0 and dx * dx + dz * dz > t.far2:
			continue
		if t.is_zone:
			if t.contains(x, z):
				return false
		elif t.contains_inflated(x, z, _margin):
			return false
	return true


## Does the sim-driven party unit escape right now (07 §5.5): it reacts (react_at reached) and stands in a hostile
## shape that strikes within ESCAPE_LOOKAHEAD_TICKS (grown by ESCAPE_MARGIN_CM), or it stands in a hostile zone. Pure.
func escaping(u: RtUnit) -> bool:
	if _telegraphs.is_empty() or u.side != Combatant.Side.PARTY or not is_ai_driven(u):
		return false
	if u.react_at >= 0 and _tick >= u.react_at and _shape_impact(u, u.x, u.z) >= 0:
		return true
	return _in_zone(u, u.x, u.z)


## The ct from which the party SHOW is ready (the end of the last SHOW cooldown; 0 before the first SHOW) — the AI
## fires its SHOW AI_SHOW_GRACE_TICKS later (07 §4.1, §5.3).
func show_ready_at() -> int:
	return _show_cd[0]


## The MP of the unit's own interrupter (the dearest skill with rt.interrupt on its bar; 0 = none): the filler reserve
## of 07 §3.10 / §5.3.
func interrupter_mp(u: RtUnit) -> int:
	return int(_intr_mp.get(u.id, 0))


## party.json rt of a party unit ({} without data).
func party_rt(u: RtUnit) -> Dictionary:
	if u == null or u.side != Combatant.Side.PARTY or _data == null or not _data.has_id("party", u.def_id):
		return {}
	return _data.party_member(u.def_id).rt


## A new tactic of a party unit (07 §5.2): its rules (party.json rt.presets, RtRules.preset_rules) and its distance
## keep_cm[preset] (≤ 700, §5.5); rule timers stay (keys "<preset>:<index>").
func change_preset(u: RtUnit, preset: String) -> void:
	var prt: Dictionary = party_rt(u)
	u.preset = preset
	u.rules = RtRules.preset_rules(prt, preset)
	u.keep_cm = clampi(int((prt.get("keep_cm", {}) as Dictionary).get(preset, 0)), 0, 700)


## The party flees (FLED at step 10). `by_item`: the smoke bomb (a flight attempt of its own, 07 §3.12).
func flee_now(by_item: RtUnit) -> void:
	if bool(setup.geo.get("closed", false)) or not setup.can_flee:
		return
	fled = true
	if by_item != null:
		tally["flee_attempts"] = int(tally["flee_attempts"]) + 1


## Control follows life (07 §2.6): the first living AI party unit (slot order) becomes the controlled one.
func control_follows_life(dead: RtUnit) -> void:
	for v: RtUnit in _list:
		if v == dead or v.side != Combatant.Side.PARTY or not is_alive(v) or v.driver != RtUnit.Driver.AI:
			continue
		var before: String = _ctl
		dead.driver = RtUnit.Driver.AI
		v.driver = RtUnit.Driver.PLAYER
		v.sample = [_tick, v.x, v.z, 0, 0, v.yaw]
		v.move_budget = bal.i("MOVE_BUDGET_MM")
		v.partner_order = {}
		v.queued = {}
		v.goal = []
		v.auto_on = dead.auto_on
		_ctl = v.id
		var e: ActionEvent = ev(ActionEvent.Type.CONTROL_CHANGED)
		e.actor_id = before
		e.target_id = v.id
		e.def_id = v.def_id
		return


## The controlled unit's target fell: with auto_retarget the enemy attacking it, else the nearest (07 §7.4).
func retarget_after_kill(dead: RtUnit) -> void:
	var ctl: RtUnit = unit(_ctl)
	if ctl == null or ctl.target_id != dead.id or not setup.auto_retarget or not is_alive(ctl):
		return
	var pick: RtUnit = null
	for v: RtUnit in _list:
		if v.side == Combatant.Side.ENEMY and targetable(v) and v.target_id == ctl.id:
			pick = v
			break
	if pick == null:
		var best: int = -1
		for v: RtUnit in _list:
			if v.side != Combatant.Side.ENEMY or not targetable(v):
				continue
			var d2: int = DetMath.dist2(ctl.x, ctl.z, v.x, v.z)
			if best < 0 or d2 < best:
				best = d2
				pick = v
	Ability.target_change(self, ctl, pick.id if pick != null else "")


## Party AI target "assist" (07 §5.3): the controlled unit's hostile target, else the own, else the nearest enemy.
func assist_target(u: RtUnit) -> String:
	var ctl: RtUnit = _by_id.get(_ctl, null)
	if ctl != null and ctl != u:
		var ct: RtUnit = _by_id.get(ctl.target_id, null)
		if ct != null and ct.side != u.side and targetable(ct):
			return ct.id
	var own: RtUnit = _by_id.get(u.target_id, null)
	if own != null and own.side != u.side and targetable(own):
		return own.id
	var best: RtUnit = null
	var best_d: int = -1
	for v: RtUnit in _list:
		if v.side == u.side or v.hp <= 0 or v.left_battle \
				or (v.side == Combatant.Side.ENEMY and _tick < v.pop_in_until - _pop_in):
			continue
		var dx: int = v.x - u.x
		var dz: int = v.z - u.z
		var d2: int = dx * dx + dz * dz
		if best == null or d2 < best_d:
			best = v
			best_d = d2
	return best.id if best != null else ""


## Step 7 of a sim-driven unit (07 §5.3, §5.5, §6.2). It thinks (`think`) only every AI_THINK_TICKS ticks, offset by
## its index in the unit list (07 §3.15 "gestaffeltes KI-Denken"): its target (enemies: auto_target — threat_top,
## lowest_hp_pct_enemy, nearest_enemy, random_enemy; AI partner / autopilot: "assist"); a party unit's telegraph
## reaction (_react); a due "then" follow-up and the rules (RtRules.choose — both held while a Partner-Spezial order
## waits); then the movement goal: escape point > following the controlled unit out of the ring (flight, §2.5) >
## partner order (`ordered`: it walks into range) > the range goal of a rule > §3.5.3 — a party goal into a shape it
## reacts to becomes "stand", one into a zone the escape point. Stationary units never get one. In between it keeps
## its target and goal; only a party unit's reaction (escape point) and its flight following run every tick.
func ai_step(u: RtUnit, ordered: bool, think: bool = true) -> void:
	if not u.entry.is_empty() or u.hp <= 0 or u.left_battle \
			or (u.side == Combatant.Side.ENEMY and _tick < u.pop_in_until - _pop_in):     # not targetable(u)
		return
	var party: bool = u.side == Combatant.Side.PARTY
	if not think:
		if party and not _react(u):
			_follow_flight(u)
		return
	var tid: String = assist_target(u) if party else Boss.auto_target(self, u, str(_auto_target.get(u.id, "")))
	if tid != u.target_id:
		Ability.target_change(self, u, tid)
	var escape: bool = party and _react(u)
	var rule_goal: Array = _NO_GOAL
	if u.partner_order.is_empty() and _tick >= u.pop_in_until:
		if not u.follow_up.is_empty():
			_follow_up(u)
		if not u.rules.is_empty():
			var pick: Dictionary = RtRules.choose(self, u)
			if not pick.is_empty():
				if pick.has("skill") or pick.has("item"):
					_apply_pick(u, pick)
				rule_goal = pick.get("goal", _NO_GOAL)
	if escape or u.stationary or (party and _follow_flight(u)) or ordered:
		return
	if _tick < u.pop_in_until:
		if not u.goal.is_empty():
			u.goal = []
		return
	var g: Array[int]
	if rule_goal.size() == 2:
		g = []
		g.assign(rule_goal)
	else:
		g = Movement.goal_for(self, u, _by_id.get(tid, null))
	u.goal = _safe_goal(u, g) if party else g


## The pull opener at ct 0 (07 §2.2): a skill or item of the opening unit, without a range check.
func run_opener() -> void:
	var u: RtUnit = _opener_unit()
	if u == null or not is_alive(u):
		return
	match str(_opener.get("kind", "")):
		"skill":
			Ability.use_ability(self, u, str(_opener.get("skill", "")), str(_opener.get("target", "")), false, true)
		"item":
			Ability.use_item(self, u, str(_opener.get("item", "")), str(_opener.get("target", "")), false, true)


## The pull strike (07 §2.2): at ct 0 the opening unit's first auto swing on the struck enemy, regardless of reach.
func opener_strike(u: RtUnit, t: RtUnit) -> bool:
	return str(_opener.get("kind", "")) == "strike" and u == _opener_unit() and t.id == str(_opener.get("target", ""))


## A periodic status hit (StatusFx → Damage without a preload cycle).
func status_damage(src_id: String, u: RtUnit, amount: int, def: StatusDef) -> void:
	Damage.status_damage(self, src_id, u, amount, def)


func heal_unit(src: RtUnit, u: RtUnit, amount: int, skill_id: String, status_id: String) -> int:
	return Damage.heal(self, src, u, amount, skill_id, status_id)


## A group leader reached its ring point: its komparsen pop in now and act POP_IN_TICKS later (07 §2.3, §3.5.5).
func leader_arrived(u: RtUnit, c: int) -> void:
	for fid: Variant in _followers.get(u.id, []):
		var f: RtUnit = unit(str(fid))
		if f != null:
			f.pop_in_until = c + bal.i("POP_IN_TICKS")


## The game data of the combat (Gifts, Result).
func game_data() -> GameData:
	return _data


## EnemyDef.rt of an enemy def id ({} if unknown; memoized — not state).
func enemy_rt(def_id: String) -> Dictionary:
	var r: Variant = _enemy_rts.get(def_id)
	if r == null:
		r = _data.enemy(def_id).rt if _data != null and def_id != "" and _data.has_id("enemies", def_id) else {}
		_enemy_rts[def_id] = r
	return r


func enemy_def(id: String) -> EnemyDef:
	return _data.enemy(id) if _data != null and id != "" and _data.has_id("enemies", id) else null


## The enemies with rt.phases or an enrage block (Boss.step; a copy — summons may join while it is walked).
func special_foes() -> Array[RtUnit]:
	var out: Array[RtUnit] = []
	out.assign(_foes)
	return out


## The next enemy number (summons count on, never reused, 07 §3.3).
func take_enemy_number() -> int:
	_next_enemy += 1
	return _next_enemy - 1


## Living enemies still in the combat (summon cap MAX_ENEMIES, 07 §3.12).
func living_enemies() -> int:
	var n: int = 0
	for u: RtUnit in _list:
		if u.side == Combatant.Side.ENEMY and u.hp > 0 and not u.left_battle:
			n += 1
	return n


## The centre of the living party (rounded mean; the set centre without one).
func party_center() -> Vector2i:
	var sx: int = 0
	var sz: int = 0
	var n: int = 0
	for u: RtUnit in _list:
		if u.side == Combatant.Side.PARTY and is_alive(u):
			sx += u.x
			sz += u.z
			n += 1
	return Vector2i(FixedMath.div_round(sx, n), FixedMath.div_round(sz, n)) if n > 0 else Vector2i.ZERO


## A new unit joins the combat (a summon, 07 §3.12): the per-unit mods of the list (stats, speed, swing, threat,
## element swap) and its add_rule rules (a shared timer as the others have it), its mod factors, then the unit list
## (after all others, 07 §3.3).
func add_unit(u: RtUnit) -> void:
	if _mods_any:
		for m: Dictionary in setup.mods:
			var op: String = str(m.get("op", ""))
			if op != "add_rule" and op != "on" and op != "extra_enemy" and RtMods.applies(m, u):
				RtMods.apply_unit_op(u, m)
		for r: Dictionary in RtMods.unit_rules(setup.mods, u):
			var key: String = str(r["key"])
			u.rules.append(r)
			if r.has("shared"):
				var ready: int = int(r["first"])
				for v: RtUnit in _list:
					if v.rule_ready.has(key):
						ready = int(v.rule_ready[key])
						break
				u.rule_ready[key] = ready
		_derive_mods(u)
	_list.append(u)
	_by_id[u.id] = u
	if str(u.mp_regen.get("mode", "")) == "time":
		_time_regen.append(u)
	if u.side == Combatant.Side.ENEMY:
		_derive_foe(u)


## The add_rule rules of `u` (compiled, list order; RtMods.unit_rules) — a new phase keeps them.
func mod_rules(u: RtUnit) -> Array[Dictionary]:
	if not _mods_any:
		var none: Array[Dictionary] = []
		return none
	return RtMods.unit_rules(setup.mods, u)


## Index of the next event of the running tick (RtMods.on_event).
func out_len() -> int:
	return _out.size()


## The events of the running tick from index `i` on.
func out_from(i: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	out.assign(_out.slice(i))
	return out


func change_unit_mp(u: RtUnit, delta: int) -> int:
	return Damage.change_mp(self, u, delta)


## A status from `src_id` on `u` without a resistance roll (RtMods "on" effects).
func add_status(src_id: String, u: RtUnit, status_id: String, ms: int) -> void:
	StatusFx.apply(self, src_id, u, status_id, ms, 1000, 0, null, true)


## [power, cooldown, cast, mp] ‰ of skill `sk` for unit `u` (RtMods skill_pm; [1000 × 4] without; memoized).
func skill_pm(u: RtUnit, sk: SkillDef) -> PackedInt32Array:
	if _skill_mods.is_empty() or u == null or sk == null:
		return RtMods.NEUTRAL4
	var key: String = "%s|%s" % [u.id, sk.id]
	var v: Variant = _skill_pm.get(key)
	if v == null:
		v = RtMods.skill_factors(_skill_mods, u, sk)
		_skill_pm[key] = v
	return v


## view() with the unit's power factor (skill_pm power) — the skill as DamageCalc sees it for `u`.
func view_for(u: RtUnit, sk: SkillDef) -> SkillDef:
	if _skill_mods.is_empty() or sk == null:
		return view(sk)
	var pm: int = skill_pm(u, sk)[0]
	if pm == 1000:
		return view(sk)
	var key: String = "%s|%s" % [u.id, sk.id]
	var v: SkillDef = _unit_views.get(key, null) as SkillDef
	if v == null:
		v = _make_view(sk)
		v.power = FixedMath.mul_pm(v.power, pm)
		_unit_views[key] = v
	return v


## The MP cost `base` of skill `skill_id` for `u` with its skill_pm mp factor.
func mp_of(u: RtUnit, skill_id: String, base: int) -> int:
	if _skill_mods.is_empty():
		return base
	var sk: SkillDef = skill_def(skill_id)
	return FixedMath.mul_pm(base, skill_pm(u, sk)[3]) if sk != null else base


## Appends the mod factors of the damage fold (07 §3.9.1 "mods_pm"): `src`'s dmg_dealt_pm (when `dealt`), `tgt`'s
## dmg_taken_pm and, once, its first_hit_taken_pm.
func mod_factors(src: RtUnit, tgt: RtUnit, dealt: bool, factors: Array[int]) -> void:
	if not _mods_any:
		return
	if dealt and src != null:
		factors.append_array(_mod_dealt.get(src.id, _NO_PMS))
	factors.append_array(_mod_taken.get(tgt.id, _NO_PMS))
	if first_hit.has(tgt.id):
		var fh: Array[int] = []
		fh.assign(first_hit[tgt.id])
		factors.append_array(fh)
		first_hit.erase(tgt.id)


## Healing on `u` with its heal_taken_pm factors (each step mul_pm; never below 1 for a positive amount).
func heal_taken(u: RtUnit, amount: int) -> int:
	if not _mods_any or amount <= 0 or not _mod_heal.has(u.id):
		return amount
	var a: int = amount
	for pm: Variant in (_mod_heal[u.id] as Array):
		a = FixedMath.mul_pm(a, int(pm))
	return maxi(1, a)


# --- private --------------------------------------------------------------------------------------------------------

## The end (07 §3.13): FLEE_RESULT on a flight, BATTLE_END (success = a won boss fight whose last phase was perfect —
## counted as a perfect phase, 07 §6.4), the result.
func _finish(outcome: int, c: int) -> void:
	if outcome == BattleResult.Outcome.FLED:
		var fr: ActionEvent = ev(ActionEvent.Type.FLEE_RESULT)
		fr.actor_id = _ctl
		fr.success = true
		if not fled:
			fr.text = "Sendezeit überzogen!"
	var be: ActionEvent = ev(ActionEvent.Type.BATTLE_END)
	be.value = outcome
	if outcome == BattleResult.Outcome.VICTORY:
		for u: RtUnit in _foes:
			if u.is_boss and not u.is_summon and u.phase >= 0 and u.phase_perfect \
					and not (enemy_rt(u.def_id).get("phases", []) as Array).is_empty():
				be.success = true
				tally["perfect_phases"] = int(tally["perfect_phases"]) + 1
				break
	result = Result.build(self, outcome, c)


## Step 11 (07 §3.3): MP over time ("time" units: +amount every every_ticks from ct 0, also while casting), SECOND
## every 30 ticks (value = whole combat seconds).
func _clock(c: int) -> void:
	for u: RtUnit in _time_regen:
		var every: int = int(u.mp_regen.get("every_ticks", 0))
		if every <= 0 or c < u.mp_regen_next:
			continue
		u.mp_regen_next += every
		if is_alive(u):
			Damage.change_mp(self, u, int(u.mp_regen.get("amount", 0)))
	if (c + 1) % TICKS_PER_SEC == 0:
		ev(ActionEvent.Type.SECOND).value = (c + 1) / TICKS_PER_SEC


## The accepted commands of tick c (submit order), removed from the queue.
func _take_cmds(c: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	if _cmds.is_empty():
		return due
	var keep: Array[Dictionary] = []
	for e: Dictionary in _cmds:
		if int(e["ct"]) == c:
			due.append(e)
		elif int(e["ct"]) > c:
			keep.append(e)
	_cmds = keep
	return due


## Static submit checks (07 §3.4): the person commands the controlled unit (and the AI partner's tactic / order);
## skills must be on the bar or unlocked; the tutorial forbids items and the Partner-Spezial; run rules
## (rules.combat.autopilot, 07 §10.7).
func _static_check(t: String, u: RtUnit, cmd: Dictionary) -> String:
	var own: bool = u.side == Combatant.Side.PARTY and u.id == _ctl
	var partner: bool = u.side == Combatant.Side.PARTY and u.id != _ctl
	match t:
		"ability_use":
			if not own:
				return "not_controlled"
			if not knows(u, str(cmd.get("skill", ""))) or skill_def(str(cmd.get("skill", ""))) == null:
				return "not_learned"
			if forbidden_skill(u, str(cmd.get("skill", ""))):
				return "forbidden"
		"target_change", "auto_attack", "move_sample":
			if not own:
				return "not_controlled"
		"autopilot":
			if not own:
				return "not_controlled"
			if not bool((setup.rules.get("combat", {}) as Dictionary).get("autopilot", true)):
				return "forbidden"
		"combat_item":
			if not own:
				return "not_controlled"
			if setup.tutorial or forbidden_item(u, str(cmd.get("item", ""))):
				return "forbidden"
			if item_def(str(cmd.get("item", ""))) == null:
				return "no_item"
		"partner_preset":
			if not partner:
				return "not_controlled"
		"partner_special":
			if not partner:
				return "not_controlled"
			if setup.tutorial:
				return "forbidden"
			if str(_ps.get(u.id, "")) == "":
				return "not_available"
	return ""


## Static data derived from the setup: the mod data of every unit (RtMods), real-time skill views, FINALE / context
## variants / Partner-Spezial of the party (party.json rt, level reached), the interrupter MP, the auto targets of
## enemies and the foes with phases / enrage, the komparsen of each group leader.
func _derive() -> void:
	_mods_any = not setup.mods.is_empty()
	if _mods_any:
		for m: Dictionary in setup.mods:
			match str(m.get("op", "")):
				"on":
					_on_any = true
				"skill_pm":
					_skill_mods.append(m)
		for u: RtUnit in _list:
			_derive_mods(u)
	var skills: PackedStringArray = []
	for u: RtUnit in _list:
		skills.append(u.auto_skill)
		skills.append(u.auto_ranged_skill)
		var known: Dictionary = {}
		var intr: int = 0
		for s: Variant in u.bar.values():
			skills.append(str(s))
			known[str(s)] = true
			var bsk: SkillDef = skill_def(str(s))
			if bsk != null and bool(bsk.rt.get("interrupt", false)):
				intr = maxi(intr, Ability.cost(self, u, bsk))
		if u.side == Combatant.Side.PARTY:
			_bar_known[u.id] = known
			_known_all[u.id] = known.duplicate()
			_intr_mp[u.id] = intr
		if u.side == Combatant.Side.PARTY and _data != null and _data.has_id("party", u.def_id):
			var prt: Dictionary = _data.party_member(u.def_id).rt
			for b: Variant in (prt.get("bar", []) as Array):
				var bd: Dictionary = b
				if bool(bd.get("finale", false)) and int(bd.get("level", 1)) <= u.level:
					_finale[u.id] = str(bd.get("skill", ""))
					skills.append(str(bd.get("skill", "")))
			var extra: Dictionary = _known_all[u.id]
			if _finale.has(u.id):
				extra[str(_finale[u.id])] = true
			var ctx: Array = []
			for cv: Variant in (prt.get("context", []) as Array):
				var cd: Dictionary = cv
				if int(cd.get("level", 1)) <= u.level:
					ctx.append({"slot": int(cd.get("slot", 0)), "skill": str(cd.get("skill", "")),
						"when": str(cd.get("when", ""))})
					skills.append(str(cd.get("skill", "")))
					extra[str(cd.get("skill", ""))] = true
			_context[u.id] = ctx
			var ps: String = str(prt.get("partner_special", ""))
			if ps != "" and u.bar.values().has(ps):
				_ps[u.id] = ps
			_assist[u.id] = RtRules.preset_rules(prt, str(prt.get("assist_preset", "attack")))
		elif u.side == Combatant.Side.ENEMY:
			_derive_foe(u)
	for k: Variant in items.keys():
		var it: ItemDef = item_def(str(k))
		if it != null:
			skills.append(it.use_skill)
	for sid: String in skills:
		var sk: SkillDef = skill_def(sid)
		if sk != null and not _views.has(sid) and int(sk.rt.get("power", sk.power)) != sk.power:
			_views[sid] = _make_view(sk)
	for g: Dictionary in setup.groups:
		var ids: Array = g.get("units", [])
		if ids.size() > 1:
			_followers[str(ids[0])] = ids.slice(1)


static func _make_view(sk: SkillDef) -> SkillDef:
	var v: SkillDef = SkillDef.new()
	v.id = sk.id
	v.name = sk.name
	v.user = sk.user
	v.category = sk.category
	v.target = sk.target
	v.damage_type = sk.damage_type
	v.element = sk.element
	v.power = int(sk.rt.get("power", sk.power))
	v.heal_mode = sk.heal_mode
	v.hits = sk.hits
	v.crit_bonus = sk.crit_bonus
	v.rt = sk.rt
	return v


## The unit of the pull opener (its "u", else the controlled unit).
func _opener_unit() -> RtUnit:
	if _opener.is_empty():
		return null
	var uid: String = str(_opener.get("u", ""))
	return unit(uid if uid != "" else _ctl)


## Start threat (07 §3.7): the opener (else the party unit nearest to the first enemy) gets 1 on every enemy.
func _start_threat(opener_unit: RtUnit) -> void:
	var trigger: RtUnit = opener_unit
	if trigger == null:
		var first: RtUnit = null
		for v: RtUnit in _list:
			if v.side == Combatant.Side.ENEMY and is_alive(v):
				first = v
				break
		if first == null:
			return
		var best_d: int = -1
		for v: RtUnit in _list:
			if v.side == Combatant.Side.PARTY and is_alive(v):
				var d2: int = DetMath.dist2(first.x, first.z, v.x, v.z)
				if best_d < 0 or d2 < best_d:
					best_d = d2
					trigger = v
	if trigger == null:
		return
	for v: RtUnit in _list:
		if v.side == Combatant.Side.ENEMY:
			Threat.add(v, trigger.id, 1)


## Applies the pick of RtRules.choose (07 §5.3 Nr. 5) with by_ai: a random_enemy target is drawn now (combat stream,
## §3.9.3); the rule's timer (every; once: never again) and its "then" follow-up are set when the action starts.
func _apply_pick(u: RtUnit, pick: Dictionary) -> void:
	var rule: Dictionary = u.rules[int(pick["at"])]
	var tid: String = str(pick.get("target", ""))
	var reason: String = ""
	if pick.has("item"):
		reason = Ability.use_item(self, u, str(pick["item"]), tid, true)
	else:
		var skill_id: String = str(pick["skill"])
		var cands: Array = pick.get("random", [])
		if cands.size() > 1:
			var alt: String = str(cands[rng().randi_range(0, cands.size() - 1)])
			if str(Ability.check(self, u, skill_id, alt)["reason"]) == "":
				tid = alt
		reason = Ability.use_ability(self, u, skill_id, tid, true)
	if reason != "":
		return
	var key: String = str(rule["key"])
	var ready: int = -1
	if bool(rule["once"]):
		ready = RtRules.NEVER
	elif int(rule["every"]) > 0:
		ready = _tick + int(rule["every"])
	if ready >= 0:
		if rule.has("shared"):
			for v: RtUnit in _list:
				if v.rule_ready.has(key):
					v.rule_ready[key] = ready
		else:
			u.rule_ready[key] = ready
	var th: Dictionary = rule["then"]
	if not th.is_empty():
		u.follow_up = {"skill": str(th["skill"]), "target": tid, "at": _tick + int(th["delay"])}


## A rule's "then" (07 §5.3 Nr. 5): from follow_up.at on it starts as soon as it is usable (no conditions); the busy
## reasons of FOLLOW_UP_WAIT wait, any other drops it.
func _follow_up(u: RtUnit) -> void:
	if u.follow_up.is_empty() or _tick < int(u.follow_up.get("at", 0)):
		return
	var skill_id: String = str(u.follow_up.get("skill", ""))
	var r: Dictionary = Ability.check(self, u, skill_id, str(u.follow_up.get("target", "")))
	var reason: String = str(r["reason"])
	if reason == "":
		u.follow_up = {}
		Ability.start(self, u, skill_def(skill_id), r, true)
	elif not FOLLOW_UP_WAIT.has(reason):
		u.follow_up = {}


## The telegraph reaction of a sim-driven party unit (07 §5.5) in step 7: react_at ends once no hostile telegraph is
## pending; from react_at on, standing in a hostile shape that strikes within ESCAPE_LOOKAHEAD_TICKS (grown by
## ESCAPE_MARGIN_CM) — or in a zone at any time — it walks to RtGeo.escape_point. An own cast that walking breaks is
## aborted (CAST_FAILED moved) unless it ends in time (end ≤ impact − walking ticks); a drink, an unbreakable cast or
## no escape point keep it standing. Returns true while it escapes (goal set).
func _react(u: RtUnit) -> bool:
	if _telegraphs.is_empty():
		u.react_at = -1
		escape.erase(u.id)
		return false
	var pending: bool = false
	var zone: bool = false
	var impact: int = -1
	var reacting: bool = u.react_at >= 0 and _tick >= u.react_at
	var watch: bool = u.react_at >= 0             # pending shapes matter only for a set react_at (reset / reaction)
	var ux: int = u.x
	var uz: int = u.z
	var side: int = u.side
	for t: RtTelegraph in _telegraphs:
		if t.side != side or (not t.is_zone and not watch):
			continue
		var dx: int = ux - t.x
		var dz: int = uz - t.z
		var near: bool = t.far2 < 0 or dx * dx + dz * dz <= t.far2
		if t.is_zone:
			zone = zone or (near and t.contains(ux, uz))
		elif t.impact_at > _tick:
			pending = true
			if near and reacting and t.impact_at - _tick <= ESCAPE_LOOKAHEAD_TICKS \
					and (impact < 0 or t.impact_at < impact) and t.contains_inflated(ux, uz, _margin):
				impact = t.impact_at
	if u.react_at >= 0 and not pending:
		u.react_at = -1
	if impact < 0 and not zone:
		escape.erase(u.id)
		return false
	var p: Vector2i = _escape_point(u)
	if p.x == u.x and p.y == u.z:
		return false
	if not u.cast.is_empty():
		if impact < 0 or str(u.cast.get("kind", "")) == "item" or not bool(u.cast.get("moving_cancels", false)):
			return false
		var walk: int = FixedMath.div_ceil(DetMath.dist(u.x, u.z, p.x, p.y), maxi(1, Movement.speed(u)))
		if int(u.cast.get("end", 0)) <= impact - walk:
			return false
		fail_cast(u, "moved")
	u.goal = [p.x, p.y]
	return true


## The escape point of `u` (RtGeo.escape_point, 07 §5.5), kept in `escape` while it stays safe — one search when a
## reaction starts (or when its point becomes unsafe), not one per tick; the unit's own spot is never kept.
func _escape_point(u: RtUnit) -> Vector2i:
	var kept: Variant = escape.get(u.id)
	if kept is Array:
		var k: Array = kept
		if (int(k[0]) != u.x or int(k[1]) != u.z) and safe_point(u, int(k[0]), int(k[1])):
			return Vector2i(int(k[0]), int(k[1]))
	var p: Vector2i = RtGeo.escape_point(self, u)
	if p.x != u.x or p.y != u.z:
		escape[u.id] = [p.x, p.y]
	else:
		escape.erase(u.id)
	return p


## The AI partner follows the controlled unit as soon as it leaves the ring (flight, 07 §2.5, §5.5): the goal next to
## it (the door lane is open to the party while the controlled unit is outside). Returns true when it does.
func _follow_flight(u: RtUnit) -> bool:
	var ctl: RtUnit = _by_id.get(_ctl, null)
	if ctl == null or ctl == u or ctl.hp <= 0 or ctl.left_battle or in_ring(ctl.x, ctl.z, ctl.radius):
		return false
	var p: Vector2i = DetMath.toward(ctl.x, ctl.z, u.x, u.z, u.radius + ctl.radius)
	u.goal = [p.x, p.y]
	return true


## A party goal that leads into danger (07 §5.5): into a hostile zone → the escape point (or stand); into a shape the
## unit reacts to → stand.
func _safe_goal(u: RtUnit, g: Array[int]) -> Array[int]:
	if g.size() != 2 or _telegraphs.is_empty():
		return g
	var out: Array[int] = []
	if _in_zone(u, g[0], g[1]):
		var p: Vector2i = _escape_point(u)
		if p.x != u.x or p.y != u.z:
			out.assign([p.x, p.y])
		return out
	if u.react_at >= 0 and _tick >= u.react_at and _shape_impact(u, g[0], g[1]) >= 0:
		return out
	return g


## TELEGRAPH_START (07 §5.5, E25): every living party unit (slot order, whoever steers it) draws "missed" from the AI
## stream (AI_DODGE_MISS_PM of its tactic); a sim-driven unit that sees the shape and stands in it (grown by
## ESCAPE_MARGIN_CM) reacts at start + REACT_TICKS[tactic] — the earlier reaction wins while another hostile
## telegraph is pending.
func _notice_telegraph(t: RtTelegraph) -> void:
	if t.side != Combatant.Side.PARTY:
		return
	var others: bool = false
	for o: RtTelegraph in _telegraphs:
		if o != t and not o.is_zone and o.side == t.side and o.impact_at > _tick:
			others = true
			break
	var m: int = bal.i("ESCAPE_MARGIN_CM")
	for v: RtUnit in _list:
		if v.side != Combatant.Side.PARTY or not is_alive(v):
			continue
		var preset: String = v.preset if RtVocab.RT_PRESETS.has(v.preset) else "attack"
		var missed: bool = FixedMath.roll_bp(ai_rng(), bal.sub("AI_DODGE_MISS_PM", preset) * 10)
		if missed or not is_ai_driven(v) or not t.contains_inflated(v.x, v.z, m):
			continue
		var at: int = t.start + bal.sub("REACT_TICKS", preset)
		v.react_at = mini(v.react_at, at) if others and v.react_at >= 0 else at


## The earliest impact of a pending hostile shape (no zone) that strikes within ESCAPE_LOOKAHEAD_TICKS and contains
## (x, z) grown by ESCAPE_MARGIN_CM; −1 if none.
func _shape_impact(u: RtUnit, x: int, z: int) -> int:
	var best: int = -1
	var m: int = _margin
	for t: RtTelegraph in _telegraphs:
		if t.is_zone or t.side != u.side or t.impact_at <= _tick or t.impact_at - _tick > ESCAPE_LOOKAHEAD_TICKS:
			continue
		if t.far2 >= 0 and (x - t.x) * (x - t.x) + (z - t.z) * (z - t.z) > t.far2:
			continue
		if (best < 0 or t.impact_at < best) and t.contains_inflated(x, z, m):
			best = t.impact_at
	return best


## Is (x, z) inside a hostile zone of `u`?
func _in_zone(u: RtUnit, x: int, z: int) -> bool:
	for t: RtTelegraph in _telegraphs:
		if t.is_zone and t.side == u.side and (t.far2 < 0 or (x - t.x) * (x - t.x) + (z - t.z) * (z - t.z) <= t.far2) \
				and t.contains(x, z):
			return true
	return false


## The mod data of one unit (RtMods): fold and heal factors, the unused first-hit factors (state), the forbid ops.
func _derive_mods(u: RtUnit) -> void:
	for pair: Array in [[_mod_dealt, "dmg_dealt_pm"], [_mod_taken, "dmg_taken_pm"], [_mod_heal, "heal_taken_pm"]]:
		var pms: Array[int] = RtMods.pms(setup.mods, u, str(pair[1]))
		if not pms.is_empty():
			(pair[0] as Dictionary)[u.id] = pms
	var fh: Array[int] = RtMods.pms(setup.mods, u, "first_hit_taken_pm")
	if not fh.is_empty():
		first_hit[u.id] = fh
	var f: Dictionary = RtMods.forbidden(setup.mods, u)
	if not (f["skills"] as Dictionary).is_empty() or not (f["tags"] as PackedStringArray).is_empty():
		_forbid[u.id] = f


## The auto target of an enemy (rt.auto_target) and whether Boss.step looks at it (phases or an enrage block).
func _derive_foe(u: RtUnit) -> void:
	var ert: Dictionary = enemy_rt(u.def_id)
	_auto_target[u.id] = str(ert.get("auto_target", "threat_top"))
	if not (ert.get("phases", []) as Array).is_empty() or not (ert.get("enrage", {}) as Dictionary).is_empty():
		_foes.append(u)


## The RtMods "on" reactions (07 §9.5) to the events of the running tick from index `mark` on (their own events are
## not reacted to again).
func _react_mods(mark: int) -> void:
	var n: int = _out.size()
	for i in range(mark, n):
		RtMods.on_event(self, _out[i])


func _first_party_id() -> String:
	for u: RtUnit in _list:
		if u.side == Combatant.Side.PARTY:
			return u.id
	return ""


## BattleResult.to_dict without floats (min_party_hp_pct as ppm), {} while running. Without rt_presets (R5b): derived
## from the units' preset / toggles, which the snapshot holds already — so the hashes of R1b–R5a stay.
func _result_dict() -> Dictionary:
	if result == null:
		return {}
	var d: Dictionary = result.to_dict()
	d.erase("rt_presets")
	d.erase("min_party_hp_pct")
	d["min_party_hp_pct_ppm"] = FixedMath.ppm(result.min_party_hp_pct)
	return RtUnit._canon(d)


## Deep copy of a command with integral JSON numbers as int (replays parse every number as float).
static func _norm(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				out[str(k)] = _norm((v as Dictionary)[k])
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(_norm(e))
			return out_a
	if JsonUtil.is_integral(v) and typeof(v) != TYPE_INT:
		return JsonUtil.to_int(v)
	return v
