class_name BattleState extends RefCounted
## Battle model + state machine (02_TECH §5.1, §5.6). RefCounted, synchronous, no autoloads/nodes/await.
##
##   SETUP ──start()──► AWAIT_COMMAND ──submit(cmd)──► (resolve + TURN_END + CTB + internal turns) ──► AWAIT_COMMAND …
##                                                     └─ all enemies gone / all party KO / fled ──► FINISHED
##
## Invariant after start(), submit() and apply_gift(): either is_finished() or current_actor() is a living real
## (non-pseudo) unit that can act. Internal turns (pseudo units, actors dying from poison at TURN_START) are resolved
## inside and appear completely in the returned list.
## Determinism (Brief §6b.1, 05 CR-2): every TURN_START sets action_n += 1, rng.seed = derive(seed, "action", action_n),
## ai_rng.seed = derive(seed, "ai", action_n); start counters use derive(seed, "ctb", 0), gift k uses
## derive(seed, "gift", k).
## choose_ai_command() never mutates the battle, so replaying recorded commands gives identical events.

const FixedMath := preload("res://core/stats/fixed_math.gd")

enum Phase { SETUP, AWAIT_COMMAND, FINISHED }
const SNAPSHOT_VERSION: int = 1
const MAX_INTERNAL_TURNS: int = 100000       # safety net against data that never lets a real unit act
const TEXT_PREEMPTIVE: String = "Präventivschlag!"
const TEXT_AMBUSH: String = "Hinterhalt!"
const TEXT_DEFEND: String = "Verteidigen"
const TEXT_FLEE: String = "Flucht"
const MAX_LIVING_ENEMIES: int = 4

var phase: BattleState.Phase = Phase.SETUP
var setup: BattleSetup = null
var data: GameData = null
var rng: RandomNumberGenerator = null       # resolution; reseeded per action (§5.1)
var ai_rng: RandomNumberGenerator = null    # EnemyAI only; reseeded per action
var action_n: int = 0
var combatants: Array[Combatant] = []       # party (p0..) then enemies (e0..), summons and pseudo units appended
var queue: CTBQueue = null
var items: Dictionary = {}                  # copy of setup.items, mutated by ITEM use / gifts
var turn_count: int = 0
var failed_flee_attempts: int = 0
var last_actor_side: int = -1               # Combatant.Side of the previous turn (pseudo counts as ENEMY)
var last_party_actor_id: String = ""        # combo detection
var last_party_target_id: String = ""       # "" if the previous party action was not a single-target damage action
var credits_stolen: int = 0
var result: BattleResult = null
var history: Array[ActionEvent] = []        # every event ever returned (debug/tests)

# --- M1 runtime (core-internal, written by ActionResolver; all part of the snapshot) -------------------------------
var advantage: int = 0                      # effective BattleSetup.Advantage (bosses always NORMAL)
var turn_actor_id: String = ""              # unit whose turn is running ("" between turns): fresh statuses, self delay
var combo_target_id: String = ""            # target that gets combo_second_hit in the running action
var action_target_id: String = ""           # single enemy target of the running party damage action ("" otherwise)
var self_delay: int = 0                     # delays that hit the actor in its own turn (stun on self, stunt fail)
var stunt_used: bool = false                # STUNT used in the running turn (no cooldown tick at its end)
var running_command: int = -1               # BattleCommand.Kind being resolved (-1 between actions; KO.command)
var fled: bool = false
var gift_n: int = 0
var next_enemy_n: int = 0
var next_pseudo_n: int = 0
var tally: Dictionary = {}                  # accumulators for BattleResult (see _new_tally)

var _current: Combatant = null
var _seed_source: Callable = Callable()


func _init(p_setup: BattleSetup, p_data: GameData) -> void:
	setup = p_setup if p_setup != null else BattleSetup.new()
	data = p_data
	rng = RandomNumberGenerator.new()
	ai_rng = RandomNumberGenerator.new()
	queue = CTBQueue.new()
	items = {}
	for k: Variant in setup.items.keys():
		items[str(k)] = JsonUtil.to_int(setup.items[k])
	tally = _new_tally()


## Optional (05 CR-2, server mode S4): `c.call(action_n) -> int` supplies the action seed instead of SeedUtil.derive.
func set_action_seed_source(c: Callable) -> void:
	_seed_source = c


## BATTLE_START, ANNOUNCE (preemptive/ambush), boss phase 1 on_enter ops, CTB_ORDER, TURN_START(first actor)
## [+ internal turns]
func start() -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if phase != Phase.SETUP:
		push_error("BattleState.start: battle already started")
		return out
	advantage = BattleSetup.Advantage.NORMAL if _has_boss_setup() else int(setup.advantage)
	combatants.clear()
	for c: Combatant in setup.party:
		if c != null:
			var copy: Combatant = c.duplicate_combatant()
			copy.side = Combatant.Side.PARTY
			combatants.append(copy)
	for i in setup.enemy_ids.size():
		var eid: String = setup.enemy_ids[i]
		if data == null or not data.has_id("enemies", eid):
			push_error("BattleState.start: unknown enemy id '%s'" % eid)
			continue
		combatants.append(Combatant.create_enemy(data.enemy(eid), "e%d" % next_enemy_n, i))
		next_enemy_n += 1
	queue.setup(combatants, advantage, SeedUtil.make_rng(SeedUtil.derive(setup.seed, "ctb", 0)))
	rng.seed = _action_seed(0)
	ai_rng.seed = SeedUtil.derive(setup.seed, "ai", 0)
	var bs: ActionEvent = ActionEvent.make(ActionEvent.Type.BATTLE_START)
	bs.value = advantage
	for c: Combatant in combatants:
		bs.target_ids.append(c.id)
	out.append(bs)
	if advantage == BattleSetup.Advantage.PREEMPTIVE or advantage == BattleSetup.Advantage.AMBUSH:
		var an: ActionEvent = ActionEvent.make(ActionEvent.Type.ANNOUNCE)
		an.text = TEXT_PREEMPTIVE if advantage == BattleSetup.Advantage.PREEMPTIVE else TEXT_AMBUSH
		out.append(an)
	var initial: Array[Combatant] = combatants.duplicate()
	for c: Combatant in initial:
		if not c.is_party() and not c.is_pseudo and not c.phases.is_empty():
			ActionResolver.enter_first_phase(self, c, out)
	phase = Phase.AWAIT_COMMAND
	_advance(out)
	history.append_array(out)
	return out


func current_actor() -> Combatant:
	return _current if phase == Phase.AWAIT_COMMAND else null


func get_combatant(id: String) -> Combatant:
	for c: Combatant in combatants:
		if c.id == id:
			return c
	return null


func party() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_party():
			out.append(c)
	return out


## Without pseudo units (dead/escaped included).
func enemies() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in combatants:
		if not c.is_party() and not c.is_pseudo:
			out.append(c)
	return out


## Without pseudo units; living (hp > 0, not escaped), sorted by slot (stable).
func living(side: Combatant.Side) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.side == side and not c.is_pseudo and c.is_alive():
			out.append(c)
	return sort_by_slot(out)


func pseudo_units() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_pseudo and c.is_alive():
			out.append(c)
	return out


## BattleCommand.Kind values in menu order.
## FLEE only if setup.can_flee and not setup.tutorial (and no boss); STUNT only if stunts non-empty, stunt_cooldown == 0
## and no no_stunt flag; ITEM only if any usable item count > 0; SKILL only if skills non-empty.
## Enemies: ATTACK, SKILL, DEFEND.
func available_commands(actor: Combatant) -> Array[int]:
	var out: Array[int] = []
	if actor == null or actor.is_pseudo or not actor.is_alive():
		return out
	out.append(BattleCommand.Kind.ATTACK)
	if not actor.skills.is_empty():
		out.append(BattleCommand.Kind.SKILL)
	if actor.is_party() and not actor.stunts.is_empty() and actor.stunt_cooldown <= 0 and not actor.has_flag("no_stunt"):
		out.append(BattleCommand.Kind.STUNT)
	if actor.is_party() and not usable_items().is_empty():
		out.append(BattleCommand.Kind.ITEM)
	out.append(BattleCommand.Kind.DEFEND)
	if actor.is_party() and flee_allowed():
		out.append(BattleCommand.Kind.FLEE)
	return out


## MP sufficient, no no_magic flag for category magic/heal/buff/debuff (stunts excluded; unknown ids skipped).
func usable_skills(actor: Combatant) -> PackedStringArray:
	var out: PackedStringArray = []
	if actor == null:
		return out
	for sid: String in actor.skills:
		var sk: SkillDef = skill_def(sid)
		if sk == null or sk.is_stunt() or sk.mp_cost > actor.mp:
			continue
		if actor.has_flag("no_magic") and ["magic", "heal", "buff", "debuff"].has(sk.category):
			continue
		out.append(sid)
	return out


## count > 0, usable battle/both (consumables with a use_skill), sorted by id; escape items only if fleeing is allowed.
func usable_items() -> PackedStringArray:
	var out: PackedStringArray = []
	for k: Variant in items.keys():
		var iid: String = str(k)
		if JsonUtil.to_int(items[k]) <= 0:
			continue
		var it: ItemDef = item_def(iid)
		if it == null or it.type != "consumable" or not (it.usable == "battle" or it.usable == "both"):
			continue
		var sk: SkillDef = skill_def(it.use_skill)
		if sk == null or (sk.flee_guaranteed and not flee_allowed()):
			continue
		out.append(iid)
	out.sort()
	return out


## Never pseudo units. skill_id "" = the actor's attack skill. Sorted by slot.
func valid_targets(actor: Combatant, skill_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if actor == null:
		return out
	var sk: SkillDef = skill_def(skill_id if skill_id != "" else actor.attack_skill)
	if sk == null:
		return out
	var own: Combatant.Side = actor.side
	var other: Combatant.Side = Combatant.Side.ENEMY if actor.is_party() else Combatant.Side.PARTY
	match sk.target:
		"single_enemy", "all_enemies", "random_enemy":
			for c: Combatant in living(other):
				out.append(c.id)
		"single_ally", "all_allies":
			for c: Combatant in living(own):
				out.append(c.id)
		"self":
			out.append(actor.id)
		"single_ally_ko":
			var ko: Array[Combatant] = []
			for c: Combatant in combatants:
				if c.side == own and c.is_ko():
					ko.append(c)
			for c: Combatant in sort_by_slot(ko):
				out.append(c.id)
	return out


## Enemy: lowest hp; ally heal: lowest ratio. Ties: lower slot. "" if there is no valid target.
func default_target(actor: Combatant, skill_id: String) -> String:
	var ids: PackedStringArray = valid_targets(actor, skill_id)
	if ids.is_empty():
		return ""
	var sk: SkillDef = skill_def(skill_id if skill_id != "" else actor.attack_skill)
	var cands: Array[Combatant] = []
	for id: String in ids:
		cands.append(get_combatant(id))
	if sk.target == "single_ally" or sk.target == "all_allies":
		return lowest_ratio(cands).id
	if sk.target == "single_ally_ko" or sk.target == "self":
		return cands[0].id
	return lowest_hp(cands).id


func preview_order(count: int, hover_rank: int = -1, overrides: Dictionary = {}) -> PackedStringArray:
	if phase == Phase.AWAIT_COMMAND and _current != null:
		return queue.preview(count, _current, hover_rank if hover_rank > 0 else CTBQueue.RANK_NORMAL, overrides)
	return queue.preview(count, null, -1, overrides)


## Ghost preview for the HUD (GDD §3.4): counters the targets would have if `skill_id` (skill or item use_skill)
## applied its stun (`delay_on_apply`) statuses — chance ignored; already stunned or immune targets stay unchanged.
## For the actor itself the value is its follow-up counter (delay + stun). Pass the result as `overrides` to
## preview_order().
## Haste/slow only change future delays, not current counters, so they are not part of the ghost.
func ghost_overrides(actor: Combatant, skill_id: String, target_ids: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var sk: SkillDef = skill_def(skill_id)
	if sk == null or actor == null:
		return out
	for s: Dictionary in sk.statuses:
		var sid: String = str(s.get("id", ""))
		var def: StatusDef = status_def(sid)
		if def == null or not def.has_flag("delay_on_apply"):
			continue
		for tid: String in target_ids:
			var t: Combatant = get_combatant(tid)
			if t == null or t.is_pseudo or not t.is_alive() or t.has_status(sid) or t.status_immune.has(sid):
				continue
			var bd: int = CTBQueue.base_delay(t.stat(StatBlock.Stat.SPD))
			var delay: int = FixedMath.mul_pm(bd, FixedMath.pm(Balance.STUN_BOSS_MULT)) if t.is_boss else bd
			var base: int = CTBQueue.delay_for(t, sk.rank) if t == actor else t.ctb_counter
			out[tid] = JsonUtil.to_int(out.get(tid, base)) + delay
	return out


## ATTACK 3, SKILL/STUNT SkillDef.rank, ITEM rank of the use_skill (default 2), DEFEND 2, FLEE 2.
func command_rank(cmd: BattleCommand) -> int:
	if cmd == null:
		return CTBQueue.RANK_NORMAL
	match cmd.kind:
		BattleCommand.Kind.ATTACK:
			return CTBQueue.RANK_NORMAL
		BattleCommand.Kind.SKILL, BattleCommand.Kind.STUNT:
			var sk: SkillDef = skill_def(cmd.skill_id)
			return sk.rank if sk != null else CTBQueue.RANK_NORMAL
		BattleCommand.Kind.ITEM:
			var it: ItemDef = item_def(cmd.item_id)
			var us: SkillDef = skill_def(it.use_skill) if it != null else null
			return us.rank if us != null else CTBQueue.RANK_QUICK
	return CTBQueue.RANK_QUICK


## "" valid, otherwise reason (English, for logs).
func validate(cmd: BattleCommand) -> String:
	if phase != Phase.AWAIT_COMMAND or _current == null:
		return "battle is not awaiting a command"
	if cmd == null:
		return "null command"
	var actor: Combatant = _current
	if cmd.actor_id != actor.id:
		return "'%s' is not the current actor ('%s')" % [cmd.actor_id, actor.id]
	if not available_commands(actor).has(int(cmd.kind)):
		return "command '%s' is not available for %s" % [cmd.kind_name(), actor.id]
	match cmd.kind:
		BattleCommand.Kind.ATTACK:
			var atk: SkillDef = skill_def(actor.attack_skill)
			if atk == null:
				return "actor %s has no valid attack skill" % actor.id
			return _validate_targets(actor, atk, cmd.target_ids)
		BattleCommand.Kind.SKILL:
			if not actor.skills.has(cmd.skill_id):
				return "skill '%s' is not known by %s" % [cmd.skill_id, actor.id]
			if not usable_skills(actor).has(cmd.skill_id):
				return "skill '%s' is not usable (MP/no_magic)" % cmd.skill_id
			return _validate_targets(actor, skill_def(cmd.skill_id), cmd.target_ids)
		BattleCommand.Kind.STUNT:
			var st: SkillDef = skill_def(cmd.skill_id)
			if not actor.stunts.has(cmd.skill_id) or st == null:
				return "stunt '%s' is not known by %s" % [cmd.skill_id, actor.id]
			return _validate_targets(actor, st, cmd.target_ids)
		BattleCommand.Kind.ITEM:
			if not usable_items().has(cmd.item_id):
				return "item '%s' is not usable" % cmd.item_id
			return _validate_targets(actor, skill_def(item_def(cmd.item_id).use_skill), cmd.target_ids)
	return ""


## push_error + [] if invalid or not current actor.
func submit(cmd: BattleCommand) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	var reason: String = validate(cmd)
	if reason != "":
		push_error("BattleState.submit: rejected command (%s)" % reason)
		return out
	var actor: Combatant = _current
	var rank: int = command_rank(cmd)
	out = ActionResolver.resolve(self, cmd)
	_mark_once(actor, cmd)
	_finish_turn(actor, rank, out)
	_advance(out)
	history.append_array(out)
	return out


## Enemy → EnemyAI (ai_rng); party → AutoPolicy. Pure: never changes the battle (ai_rng is reseeded on every call).
func choose_ai_command() -> BattleCommand:
	var actor: Combatant = current_actor()
	if actor == null:
		return null
	if actor.is_party():
		return AutoPolicy.choose(self, actor)
	ai_rng.seed = SeedUtil.derive(setup.seed, "ai", action_n)
	return EnemyAI.choose(self, actor, ai_rng)


## Only in AWAIT_COMMAND; does not consume a turn (05 CR-2). Gift dictionary schema 05 §6.5:
## sponsor_buff → SPONSOR_GIFT + SponsorDef.gift effects (scaled by effect_pm), gold → CREDITS_GAINED,
## chest/fan_pack → ITEM_GAINED/CREDITS_GAINED per content (empty contents: rolled with the "gift" stream).
## A changed turn order is followed by CTB_ORDER.
func apply_gift(g: Dictionary) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	if phase != Phase.AWAIT_COMMAND or _current == null:
		push_warning("BattleState.apply_gift: only possible while awaiting a command")
		return out
	gift_n += 1
	var before: PackedStringArray = preview_order(CTBQueue.PREVIEW_LENGTH)
	var action_rng: RandomNumberGenerator = rng
	rng = SeedUtil.make_rng(SeedUtil.derive(setup.seed, "gift", gift_n))
	ActionResolver.apply_gift_effects(self, g, out)
	rng = action_rng
	var after: PackedStringArray = preview_order(CTBQueue.PREVIEW_LENGTH)
	if after != before:
		var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.CTB_ORDER)
		ev.order = after
		out.append(ev)
		_pseudo_warnings(after, out)
	history.append_array(out)
	return out


func is_finished() -> bool:
	return phase == Phase.FINISHED


# --- public helpers (UI, AI, tests) ------------------------------------------------------------------------------

func skill_def(id: String) -> SkillDef:
	return data.skill(id) if data != null and id != "" and data.has_id("skills", id) else null


func item_def(id: String) -> ItemDef:
	return data.item(id) if data != null and id != "" and data.has_id("items", id) else null


func status_def(id: String) -> StatusDef:
	return data.status(id) if data != null and id != "" and data.has_id("statuses", id) else null


## FLEE allowed: setup.can_flee, no tutorial, no boss battle.
func flee_allowed() -> bool:
	return setup.can_flee and not setup.tutorial and not _has_boss_setup()


## clampf(0.40 + (Ø SPD party − Ø SPD enemies) × 0.03 + 0.15 × failed attempts + (PREEMPTIVE ? 0.25 : 0), 0.10, 0.95).
func flee_chance() -> float:
	var c: float = Balance.FLEE_BASE + (_avg_stat(living(Combatant.Side.PARTY), StatBlock.Stat.SPD)
			- _avg_stat(living(Combatant.Side.ENEMY), StatBlock.Stat.SPD)) * Balance.FLEE_PER_SPD \
			+ Balance.FLEE_PER_FAIL * float(failed_flee_attempts)
	if advantage == BattleSetup.Advantage.PREEMPTIVE:
		c += Balance.FLEE_PREEMPT
	return clampf(c, Balance.FLEE_MIN, Balance.FLEE_MAX)


## clampf(minf(success_base + LCK × success_lck, success_cap) + (living boss enemy ? success_boss_mod : 0), 0.05, 1.0).
func stunt_chance(actor: Combatant, skill: SkillDef) -> float:
	if actor == null or skill == null:
		return 0.0
	var c: float = minf(skill.success_base + float(actor.stat(StatBlock.Stat.LCK)) * skill.success_lck, skill.success_cap)
	var other: Combatant.Side = Combatant.Side.ENEMY if actor.is_party() else Combatant.Side.PARTY
	for e: Combatant in living(other):
		if e.is_boss:
			c += skill.success_boss_mod
			break
	return clampf(c, Balance.STUNT_CHANCE_MIN, 1.0)


## A free enemy slot exists (max. 4 living enemies, slots 0..3).
func free_enemy_slot() -> int:
	var used: Array[int] = []
	for c: Combatant in living(Combatant.Side.ENEMY):
		used.append(c.slot)
	if used.size() >= MAX_LIVING_ENEMIES:
		return -1
	for s in MAX_LIVING_ENEMIES:
		if not used.has(s):
			return s
	return -1


static func sort_by_slot(list: Array[Combatant]) -> Array[Combatant]:
	var out: Array[Combatant] = list.duplicate()
	# Stable insertion sort (list order breaks slot ties).
	for i in range(1, out.size()):
		var c: Combatant = out[i]
		var j: int = i - 1
		while j >= 0 and out[j].slot > c.slot:
			out[j + 1] = out[j]
			j -= 1
		out[j + 1] = c
	return out


## Lowest hp ratio (exact integer comparison), ties: lower slot. null for an empty list.
static func lowest_ratio(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in sort_by_slot(list):
		if best == null or maxi(0, c.hp) * best.max_hp() < maxi(0, best.hp) * c.max_hp():
			best = c
	return best


## Lowest absolute hp, ties: lower slot.
static func lowest_hp(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in sort_by_slot(list):
		if best == null or c.hp < best.hp:
			best = c
	return best


## Highest absolute hp, ties: lower slot.
static func highest_hp(list: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in sort_by_slot(list):
		if best == null or c.hp > best.hp:
			best = c
	return best


# --- snapshot (05 CR-14) ------------------------------------------------------------------------------------------

## Snapshot incl. CTB counters, statuses, items, action_n, RNG state. Float-free and JSON-safe (canonical JSON: ints,
## strings, bools, arrays, string-keyed dictionaries); 64-bit RNG values as decimal strings.
func to_dict() -> Dictionary:
	var cs: Array = []
	for c: Combatant in combatants:
		cs.append(c.to_dict())
	var its: Dictionary = {}
	var keys: PackedStringArray = []
	for k: Variant in items.keys():
		keys.append(str(k))
	keys.sort()
	for k: String in keys:
		its[k] = JsonUtil.to_int(items[k])
	var res: Dictionary = {}
	if result != null:
		res = result.to_dict()
		res.erase("min_party_hp_pct")
		res["min_party_hp_pct_ppm"] = FixedMath.ppm(result.min_party_hp_pct)
	return {
		"version": SNAPSHOT_VERSION, "phase": int(phase), "setup": setup.to_dict(), "action_n": action_n,
		"rng_seed": str(rng.seed), "rng_state": str(rng.state), "combatants": cs, "queue": queue.to_dict(),
		"items": its, "turn_count": turn_count, "failed_flee_attempts": failed_flee_attempts,
		"last_actor_side": last_actor_side, "last_party_actor_id": last_party_actor_id,
		"last_party_target_id": last_party_target_id, "credits_stolen": credits_stolen,
		"current": _current.id if _current != null else "", "advantage": advantage, "turn_actor_id": turn_actor_id,
		"combo_target_id": combo_target_id, "action_target_id": action_target_id, "self_delay": self_delay,
		"stunt_used": stunt_used, "fled": fled, "gift_n": gift_n, "next_enemy_n": next_enemy_n,
		"next_pseudo_n": next_pseudo_n, "tally": _tally_to_dict(), "result": res,
	}


## Inverse of to_dict (also after a JSON round trip): from_dict(s.to_dict()).to_dict() == s.to_dict(), and the restored
## battle continues exactly like the original (history is not part of the snapshot).
static func from_dict(d: Dictionary, p_data: GameData) -> BattleState:
	var sd: Variant = d.get("setup", {})
	var s: BattleState = BattleState.new(BattleSetup.from_dict(sd if sd is Dictionary else {}, p_data), p_data)
	s.phase = clampi(JsonUtil.to_int(d.get("phase", 0)), 0, 2) as BattleState.Phase
	s.action_n = JsonUtil.to_int(d.get("action_n", 0))
	s.rng.seed = str(d.get("rng_seed", "0")).to_int()
	s.rng.state = str(d.get("rng_state", "0")).to_int()
	s.ai_rng.seed = SeedUtil.derive(s.setup.seed, "ai", s.action_n)
	for v: Variant in (d.get("combatants", []) as Array):
		if v is Dictionary:
			var c: Combatant = Combatant.from_dict(v, p_data)
			if c != null:
				s.combatants.append(c)
	var qd: Variant = d.get("queue", {})
	s.queue = CTBQueue.from_dict(qd if qd is Dictionary else {}, s.combatants)
	s.items = {}
	var its: Variant = d.get("items", {})
	if its is Dictionary:
		for k: Variant in (its as Dictionary).keys():
			s.items[str(k)] = JsonUtil.to_int((its as Dictionary)[k])
	s.turn_count = JsonUtil.to_int(d.get("turn_count", 0))
	s.failed_flee_attempts = JsonUtil.to_int(d.get("failed_flee_attempts", 0))
	s.last_actor_side = JsonUtil.to_int(d.get("last_actor_side", -1), -1)
	s.last_party_actor_id = str(d.get("last_party_actor_id", ""))
	s.last_party_target_id = str(d.get("last_party_target_id", ""))
	s.credits_stolen = JsonUtil.to_int(d.get("credits_stolen", 0))
	s._current = s.get_combatant(str(d.get("current", "")))
	s.advantage = JsonUtil.to_int(d.get("advantage", 0))
	s.turn_actor_id = str(d.get("turn_actor_id", ""))
	s.combo_target_id = str(d.get("combo_target_id", ""))
	s.action_target_id = str(d.get("action_target_id", ""))
	s.self_delay = JsonUtil.to_int(d.get("self_delay", 0))
	s.stunt_used = bool(d.get("stunt_used", false))
	s.fled = bool(d.get("fled", false))
	s.gift_n = JsonUtil.to_int(d.get("gift_n", 0))
	s.next_enemy_n = JsonUtil.to_int(d.get("next_enemy_n", 0))
	s.next_pseudo_n = JsonUtil.to_int(d.get("next_pseudo_n", 0))
	var td: Variant = d.get("tally", {})
	s.tally = _tally_from_dict(td if td is Dictionary else {})
	var rd: Variant = d.get("result", {})
	if rd is Dictionary and not (rd as Dictionary).is_empty():
		s.result = BattleResult.from_dict(rd)
	return s


# --- internals ------------------------------------------------------------------------------------------------------

## Runs turns until a real unit awaits a command or the battle ends.
func _advance(out: Array[ActionEvent]) -> void:
	for _guard in MAX_INTERNAL_TURNS:
		if _check_end(out):
			return
		var order: PackedStringArray = queue.preview(CTBQueue.PREVIEW_LENGTH)
		var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.CTB_ORDER)
		ev.order = order
		out.append(ev)
		_pseudo_warnings(order, out)
		var actor: Combatant = queue.next_actor()
		if actor == null:
			_finish(BattleResult.Outcome.DEFEAT, out)
			return
		_begin_turn(actor, out)
		if actor.is_pseudo:
			ActionResolver.pseudo_turn(self, actor, out)
			_finish_turn(actor, CTBQueue.RANK_NORMAL, out)
			continue
		ActionResolver.turn_start(self, actor, out)
		if not actor.is_alive():
			_close_turn(actor)
			continue
		_current = actor
		phase = Phase.AWAIT_COMMAND
		return
	push_error("BattleState: no real unit could act within %d internal turns" % MAX_INTERNAL_TURNS)
	_finish(BattleResult.Outcome.DEFEAT, out)


func _begin_turn(actor: Combatant, out: Array[ActionEvent]) -> void:
	action_n += 1
	rng.seed = _action_seed(action_n)
	ai_rng.seed = SeedUtil.derive(setup.seed, "ai", action_n)
	turn_count += 1
	if actor.is_party():
		tally["party_turns"] = int(tally["party_turns"]) + 1
	turn_actor_id = actor.id
	self_delay = 0
	stunt_used = false
	running_command = -1
	combo_target_id = ""
	action_target_id = ""
	_current = null
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.TURN_START)
	ev.actor_id = actor.id
	out.append(ev)


## turn_end ticks/durations/cooldown → on_acted (+ delays that hit the actor in its own turn) → TURN_END.
func _finish_turn(actor: Combatant, rank: int, out: Array[ActionEvent]) -> void:
	if not actor.is_pseudo and not actor.left_battle:
		ActionResolver.end_of_turn(self, actor, out)
	if actor.is_alive():
		queue.on_acted(actor, rank)
		if self_delay > 0:
			queue.add_delay(actor, self_delay)
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.TURN_END)
	ev.actor_id = actor.id
	out.append(ev)
	_close_turn(actor)


func _close_turn(actor: Combatant) -> void:
	last_actor_side = int(Combatant.Side.PARTY if actor.is_party() else Combatant.Side.ENEMY)
	if actor.is_party():
		last_party_actor_id = actor.id
		last_party_target_id = action_target_id
	turn_actor_id = ""
	self_delay = 0
	stunt_used = false
	running_command = -1
	combo_target_id = ""
	action_target_id = ""
	_current = null


func _check_end(out: Array[ActionEvent]) -> bool:
	if phase == Phase.FINISHED:
		return true
	if fled:
		_finish(BattleResult.Outcome.FLED, out)
	elif living(Combatant.Side.ENEMY).is_empty():
		_finish(BattleResult.Outcome.VICTORY, out)
	elif living(Combatant.Side.PARTY).is_empty():
		_finish(BattleResult.Outcome.DEFEAT, out)
	else:
		return false
	return true


func _finish(outcome: BattleResult.Outcome, out: Array[ActionEvent]) -> void:
	phase = Phase.FINISHED
	_current = null
	turn_actor_id = ""
	result = _build_result(outcome)
	var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.BATTLE_END)
	ev.value = int(outcome)
	out.append(ev)


func _build_result(outcome: BattleResult.Outcome) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = outcome
	r.encounter_id = setup.encounter_id
	r.group_id = setup.group_id
	r.is_boss = setup.is_boss
	r.advantage = advantage
	r.turns = turn_count
	r.party_turns = int(tally["party_turns"])
	for c: Combatant in enemies():
		if c.is_boss and not c.is_summon:
			r.boss_id = c.def_id
			r.is_boss = true
			break
	var killed: Array = tally["killed"]
	var overkill: Array = tally["overkill"]
	for v: Variant in killed:
		var c: Combatant = get_combatant(str(v))
		if c != null:
			r.defeated_ids.append(c.def_id)
	r.kills = killed.size()
	if outcome == BattleResult.Outcome.VICTORY:
		var exp_sum: int = 0
		var lck_sum: int = 0
		var alive: Array[Combatant] = living(Combatant.Side.PARTY)
		for m: Combatant in alive:
			lck_sum += m.stat(StatBlock.Stat.LCK)
		# chance × (1 + Ø LCK / 100) = chance × (100·n + ΣLCK) / (100·n), in basis points with integer division.
		var lck_den: int = FixedMath.pm(Balance.DROP_LCK_DIV) * maxi(1, alive.size())
		for v: Variant in killed:
			var c: Combatant = get_combatant(str(v))
			if c == null or c.is_summon:
				continue
			exp_sum += c.exp_reward
			var cr: int = c.credit_reward
			if overkill.has(c.id):
				var bonus: int = FixedMath.mul_pm(cr, FixedMath.pm(Balance.OVERKILL_CREDIT_MULT))
				r.overkill_credits += bonus - cr
				cr = bonus
			r.credits += cr
			for drop: Dictionary in c.drops:
				var base_bp: int = FixedMath.bp(float(drop.get("chance", 0.0)))
				var bp: int = base_bp * (lck_den + lck_sum * FixedMath.PM) / lck_den
				if FixedMath.roll_bp(rng, bp):
					r.drops.append(str(drop.get("item", "")))
			if c.is_boss:
				for bd: Dictionary in c.boss_drops:
					r.boss_rewards.append({"kind": str(bd.get("kind", "")), "id": str(bd.get("id", "")),
						"amount": JsonUtil.to_int(bd.get("amount", 1), 1)})
		r.exp = exp_sum * FixedMath.pm(setup.exp_mult) / FixedMath.PM
	var thieves: Dictionary = tally["thieves"]
	for k: Variant in thieves.keys():
		var t: Dictionary = thieves[k]
		var refunded: bool = outcome == BattleResult.Outcome.VICTORY and bool(t.get("refund", false)) and killed.has(str(k))
		if not refunded:
			r.credits_stolen += JsonUtil.to_int(t.get("amount", 0))
	r.credits_delta = int(tally["credits_delta"])
	r.item_delta = (tally["item_delta"] as Dictionary).duplicate(true)
	var wf: Dictionary = tally["weak_found"]
	for k: Variant in wf.keys():
		r.weak_found[str(k)] = JsonUtil.to_str_array(wf[k])
	r.escaped = JsonUtil.to_str_array(tally["escaped"])
	r.damage_taken = int(tally["damage_taken"])
	r.crits = int(tally["crits"])
	r.weakness_hits = int(tally["weakness_hits"])
	r.items_used = int(tally["items_used"])
	r.party_kos = int(tally["party_kos"])
	var min_hp: int = -1
	var min_pct: float = 0.0
	var low: Combatant = null
	for m: Combatant in party():
		r.party_hp[m.def_id] = maxi(0, m.hp)
		r.party_mp[m.def_id] = maxi(0, m.mp)
		if m.is_alive():
			if min_hp < 0 or m.hp < min_hp:
				min_hp = m.hp
			if low == null or m.hp * low.max_hp() < low.hp * m.max_hp():
				low = m
	r.min_party_hp = maxi(0, min_hp)
	if low != null:
		min_pct = low.hp_ratio()
	r.min_party_hp_pct = min_pct
	return r


func _validate_targets(actor: Combatant, sk: SkillDef, ids: PackedStringArray) -> String:
	if sk == null:
		return "unknown skill"
	var valid: PackedStringArray = valid_targets(actor, sk.id)
	match sk.target:
		"single_enemy", "single_ally", "single_ally_ko":
			if ids.size() != 1 or not valid.has(ids[0]):
				return "invalid target %s for %s (valid: %s)" % [str(ids), sk.id, str(valid)]
		"all_enemies", "all_allies", "random_enemy":
			if valid.is_empty():
				return "no targets for %s" % sk.id
			for id: String in ids:
				if not valid.has(id):
					return "invalid target %s for %s" % [id, sk.id]
		"self":
			if not (ids.is_empty() or (ids.size() == 1 and ids[0] == actor.id)):
				return "%s can only target the user" % sk.id
	return ""


## Marks the first unused `once` AI action of the actor's current action list that uses cmd.skill_id
## (done at resolution, so replays without AI recomputation stay identical).
func _mark_once(actor: Combatant, cmd: BattleCommand) -> void:
	if actor.is_party() or cmd.kind != BattleCommand.Kind.SKILL:
		return
	var actions: Array = EnemyAI.actions_of(actor)
	for i in actions.size():
		var a: Dictionary = actions[i]
		if str(a.get("skill", "")) != cmd.skill_id:
			continue
		var cond: Dictionary = a.get("cond", {})
		if not bool(cond.get("once", false)):
			continue
		var key: String = EnemyAI.once_key(actor, i)
		if not actor.used_once.has(key):
			actor.used_once.append(key)
			return


## MOD_LINE(warn_tag) once per approach when a pseudo unit reaches preview position <= warn_at (1-based).
func _pseudo_warnings(order: PackedStringArray, out: Array[ActionEvent]) -> void:
	for c: Combatant in combatants:
		if not c.is_pseudo or not c.is_alive() or c.warned or c.pseudo_def == null:
			continue
		var pos: int = order.find(c.id)
		if pos >= 0 and pos < c.pseudo_def.warn_at:
			c.warned = true
			if c.pseudo_def.warn_tag != "":
				var ev: ActionEvent = ActionEvent.make(ActionEvent.Type.MOD_LINE)
				ev.text = c.pseudo_def.warn_tag
				out.append(ev)


func _action_seed(n: int) -> int:
	if _seed_source.is_valid():
		return JsonUtil.to_int(_seed_source.call(n))
	return SeedUtil.derive(setup.seed, "action", n)


func _has_boss_setup() -> bool:
	if setup.is_boss:
		return true
	if data == null:
		return false
	for eid: String in setup.enemy_ids:
		if data.has_id("enemies", eid) and data.enemy(eid).boss:
			return true
	return false


static func _avg_stat(list: Array[Combatant], s: StatBlock.Stat) -> float:
	if list.is_empty():
		return 0.0
	var sum: int = 0
	for c: Combatant in list:
		sum += c.stat(s)
	return float(sum) / float(list.size())


static func _new_tally() -> Dictionary:
	return {
		"party_turns": 0, "crits": 0, "weakness_hits": 0, "items_used": 0, "party_kos": 0, "damage_taken": 0,
		"credits_delta": 0, "item_delta": {}, "weak_found": {}, "escaped": [], "killed": [], "overkill": [],
		"thieves": {},
	}


func _tally_to_dict() -> Dictionary:
	var d: Dictionary = _new_tally()
	for k: String in ["party_turns", "crits", "weakness_hits", "items_used", "party_kos", "damage_taken", "credits_delta"]:
		d[k] = int(tally[k])
	d["item_delta"] = _sorted_int_dict(tally["item_delta"])
	var wf: Dictionary = {}
	var src_wf: Dictionary = tally["weak_found"]
	var keys: PackedStringArray = []
	for k: Variant in src_wf.keys():
		keys.append(str(k))
	keys.sort()
	for k: String in keys:
		wf[k] = Array(JsonUtil.to_str_array(src_wf[k]))
	d["weak_found"] = wf
	d["escaped"] = Array(JsonUtil.to_str_array(tally["escaped"]))
	d["killed"] = Array(JsonUtil.to_str_array(tally["killed"]))
	d["overkill"] = Array(JsonUtil.to_str_array(tally["overkill"]))
	var th: Dictionary = {}
	var src_th: Dictionary = tally["thieves"]
	keys = []
	for k: Variant in src_th.keys():
		keys.append(str(k))
	keys.sort()
	for k: String in keys:
		var t: Dictionary = src_th[k]
		th[k] = {"amount": JsonUtil.to_int(t.get("amount", 0)), "refund": bool(t.get("refund", false))}
	d["thieves"] = th
	return d


static func _tally_from_dict(d: Dictionary) -> Dictionary:
	var t: Dictionary = _new_tally()
	for k: String in ["party_turns", "crits", "weakness_hits", "items_used", "party_kos", "damage_taken", "credits_delta"]:
		t[k] = JsonUtil.to_int(d.get(k, 0))
	t["item_delta"] = _sorted_int_dict(d.get("item_delta", {}))
	var wf: Variant = d.get("weak_found", {})
	if wf is Dictionary:
		for k: Variant in (wf as Dictionary).keys():
			t["weak_found"][str(k)] = Array(JsonUtil.to_str_array((wf as Dictionary)[k]))
	for k: String in ["escaped", "killed", "overkill"]:
		t[k] = Array(JsonUtil.to_str_array(d.get(k, [])))
	var th: Variant = d.get("thieves", {})
	if th is Dictionary:
		for k: Variant in (th as Dictionary).keys():
			var e: Variant = (th as Dictionary)[k]
			if e is Dictionary:
				t["thieves"][str(k)] = {"amount": JsonUtil.to_int((e as Dictionary).get("amount", 0)),
					"refund": bool((e as Dictionary).get("refund", false))}
	return t


static func _sorted_int_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (v is Dictionary):
		return out
	var src: Dictionary = v
	var keys: PackedStringArray = []
	for k: Variant in src.keys():
		keys.append(str(k))
	keys.sort()
	for k: String in keys:
		out[k] = JsonUtil.to_int(src[k])
	return out
