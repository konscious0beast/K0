class_name ShowRules extends RefCounted
## ActionEvent → ShowDelta for one battle (02_TECH §6.1/§6.2, GDD §7.3 row by row).
##
## Self-contained: needs only ActionEvent fields + the BattleSetup (party combatant ids → member def ids, boss flag,
## advantage) and skill/item defs for `hype` / `kill_hype`. Side is read from the id (`p…` party, `e…` enemy,
## `u…` pseudo unit, §5.3). Deltas are raw (before hype_gain_mult, which Show applies to the positive parts only).
##
## Interpretations (documented): enemies killed without a party hit (status tick, zone) count as kills but give no kill
## hype: the kill is credited to the party action that applied the ticking status (its `by` / `member`, `kills_skill`
## for a skill), otherwise `by: "attack"`, `member: ""` — `by` stays within the documented attack/skill/stunt/item
## (§6.3); "falls under 25 %" needs the previous HP at ≥ 25 %.
##
## Echtzeitkampf (07 §9.1, R5a): the profile &"rt" — the only one since R5b part 2b (the CTB profile left the campaign
## with the CTB battle, 10 SD1). It (constants RT_*) reads the real-time event stream: skill
## moments (variety, repetition without slot 1, interrupts, dodges, taunts, own SHOW stats) count only the person's
## actions (ActionEvent.by_ai == false; interrupts and dodges only of the controlled unit, RtSetup.controlled_id /
## CONTROL_CHANGED), crits, weakness, kills, overkill, streaks (3 kills in 6 s), combos and SHOW results count for the
## whole party; boredom and drag run on SECOND; train kills, perfect boss phases and the first ENRAGE have their own
## hype. Presentation tags of the M.O.D. lines (rt_interrupt, rt_control_switch:<member>, …) come as reasons.

const HYPE_START_NORMAL: float = 3.0
const HYPE_START_PREEMPTIVE: float = 3.0
const HYPE_START_AMBUSH: float = 5.0
const HYPE_START_BOSS: float = 8.0           # replaces the others
const HYPE_KILL_ATTACK: float = 1.0          # also item kills
const HYPE_KILL_SKILL: float = 2.0
const HYPE_KILL_STUNT: float = 4.0
const HYPE_OVERKILL: float = 3.0
const HYPE_KILL_STREAK: float = 5.0          # RT_STREAK_KILLS kills of the party within RT_STREAK_TICKS
const HYPE_LOW_HP: float = 6.0               # party member falls under LOW_HP_PCT % (once per member and battle)
const LOW_HP_PCT: int = 25
const HYPE_PARTY_KO: float = 10.0
const HYPE_REVIVE: float = 8.0
const HYPE_FLEE_OK: float = -30.0
const HYPE_CLOSE_WIN: float = 15.0           # victory with min_party_hp_pct <= CLOSE_WIN_PCT
const CLOSE_WIN_PCT: float = 0.10
const HYPE_FLAWLESS: float = 3.0             # victory with damage_taken == 0

var _data: GameData = null
var _setup: BattleSetup = null
var _party_defs: Dictionary = {}             # combatant id → party member def id
var _hp: Dictionary = {}                     # party combatant id → last known hp
var _positive: bool = false                  # a positive hype event since the last SECOND (boredom, 07 §9.1)
var _low_hp_done: Dictionary = {}
var _stunts_ok: int = 0
var _started: bool = false
# "<enemy id>|<status id>" → {"actor", "command"} of the applying party action (a later status kill is credited to it)
var _status_src: Dictionary = {}
var _tick_status: Dictionary = {}            # enemy id → status id while its last DAMAGE was a status tick


## Self-contained: needs only ActionEvent fields + setup.
func _init(p_data: GameData, p_setup: BattleSetup) -> void:
	_data = p_data
	_setup = p_setup
	if _setup != null:
		for c: Combatant in _setup.party:
			if c != null and c.id != "":
				_party_defs[c.id] = c.def_id
				_hp[c.id] = c.hp
	if _setup is RtSetup:                        # Echtzeitkampf (07 §9.1, R5a)
		_rt_init(_setup as RtSetup)


## Battle start hype (§6.2): normal / preemptive / ambush / boss +5 / +5 / +8 / +10. Returned once per battle
## (feed(BATTLE_START) uses it too), later calls return an empty delta.
func start_delta() -> ShowDelta:
	var d: ShowDelta = ShowDelta.new()
	if _started:
		return d
	_started = true
	var amount: float = HYPE_START_NORMAL
	if _setup != null:
		if _setup.is_boss:
			amount = HYPE_START_BOSS
		elif _setup.advantage == BattleSetup.Advantage.PREEMPTIVE:
			amount = HYPE_START_PREEMPTIVE
		elif _setup.advantage == BattleSetup.Advantage.AMBUSH:
			amount = HYPE_START_AMBUSH
	_add(d, amount)
	return d


## One event → its show delta (never null; empty delta when the event is show-neutral).
func feed(e: ActionEvent) -> ShowDelta:
	var d: ShowDelta = ShowDelta.new()
	if e == null:
		return d
	if e.type == ActionEvent.Type.BATTLE_START:
		return start_delta()
	_rt_feed(d, e)                               # Echtzeitkampf (07 §9.1, R5a)
	return d


## Close win (+15, min_party_hp_pct <= 0.10) / flawless (+5, no damage taken); victories only.
func end_delta(result: BattleResult) -> ShowDelta:
	var d: ShowDelta = ShowDelta.new()
	if result == null or result.outcome != BattleResult.Outcome.VICTORY:
		return d
	if result.min_party_hp_pct <= CLOSE_WIN_PCT:
		_add(d, HYPE_CLOSE_WIN, &"close_win")
	if result.damage_taken == 0:
		_add(d, HYPE_FLAWLESS, &"flawless")
	return d


func stunts_succeeded() -> int:
	return _stunts_ok


# --- shared rules ---------------------------------------------------------------------------------------------------

## "Falls under 25 %": previous hp >= 25 % (unknown = full), new hp > 0 and < 25 %; once per member and battle.
func _check_low_hp(d: ShowDelta, e: ActionEvent) -> void:
	if e.max_hp <= 0 or e.hp_after <= 0 or _low_hp_done.has(e.target_id):
		return
	if e.hp_after * 100 >= e.max_hp * LOW_HP_PCT:
		return
	var prev: int = int(_hp.get(e.target_id, e.max_hp))
	if prev * 100 < e.max_hp * LOW_HP_PCT:
		return
	_low_hp_done[e.target_id] = true
	_add(d, HYPE_LOW_HP, &"low_hp")


# --- helpers ----------------------------------------------------------------------------------------------------------

## Skill whose `hype` counts for this action: an item's use_skill, otherwise the action's skill.
func _action_skill(e: ActionEvent) -> SkillDef:
	if e.command == BattleCommand.Kind.ITEM and e.item_id != "":
		if _data != null and _data.has_id("items", e.item_id):
			return _skill_or_null(_data.item(e.item_id).use_skill)
		return null
	return _skill_or_null(e.skill_id)


func _skill_or_null(skill_id: String) -> SkillDef:
	if _data == null or skill_id == "" or not _data.has_id("skills", skill_id):
		return null
	return _data.skill(skill_id)


static func _by_for(command: int) -> String:
	match command:
		BattleCommand.Kind.SKILL:
			return "skill"
		BattleCommand.Kind.STUNT:
			return "stunt"
		BattleCommand.Kind.ITEM:
			return "item"
	return "attack"


func _member(combatant_id: String) -> String:
	return str(_party_defs.get(combatant_id, ""))


func _add(d: ShowDelta, amount: float, reason: StringName = &"") -> void:
	d.hype += amount
	if amount > 0.0:
		d.hype_gain += amount
		_positive = true
	elif amount < 0.0:
		d.hype_loss += amount
	if reason != &"" and not d.reasons.has(reason):
		d.reasons.append(reason)


static func _stat(d: ShowDelta, stat_id: String, n: int = 1) -> void:
	d.stats[stat_id] = int(d.stats.get(stat_id, 0)) + n


static func _trigger(d: ShowDelta, trigger_id: String, payload: Dictionary) -> void:
	d.triggers.append({"trigger": trigger_id, "payload": payload})


static func _is_party(combatant_id: String) -> bool:
	return combatant_id.begins_with("p")


static func _is_enemy(combatant_id: String) -> bool:
	return combatant_id.begins_with("e")


# --- Echtzeitkampf (07 §9.1, R5a): profile rt ------------------------------------------------------------------------

const PROFILE_RT: StringName = &"rt"
const RT_VARIETY: float = 1.0                # the person's skill / item not among their last RT_VARIETY_WINDOW actions
const RT_VARIETY_WINDOW: int = 4
const RT_REPEAT: float = -3.0                # the same skill RT_REPEAT_COUNT times in a row (not the slot-1 skill)
const RT_REPEAT_COUNT: int = 4
const RT_CRIT: float = 1.0                   # E32: ability hits only (R5a +2)
const RT_WEAK: float = 1.0                   # E32: once per ability action, ability hits only
const RT_STREAK_KILLS: int = 3               # kills of the party within RT_STREAK_TICKS → HYPE_KILL_STREAK
const RT_STREAK_TICKS: int = 180             # 6 s
const RT_INTERRUPT: float = 3.0              # CAST_INTERRUPTED by the controlled unit (by_ai false)
const RT_DODGE: float = 2.0                  # TELEGRAPH_DODGED of the controlled unit (by_ai false)
const RT_DODGE_CLOSE: float = 4.0
const RT_TRAIN_KILL: float = 4.0             # an add killed by an enemy telegraph (the train)
const RT_PERFECT_PHASE: float = 8.0          # PHASE_CHANGE / BATTLE_END with success
const RT_ENRAGE: float = 5.0                 # the first ENRAGE
const RT_BORING: float = -2.0                # every RT_BORING_SEC combat seconds without a positive event
const RT_BORING_SEC: int = 6
const RT_DRAG: float = -3.0                  # every RT_DRAG_EVERY_SEC from RT_DRAG_AFTER_SEC (boss: _BOSS) on
const RT_DRAG_AFTER_SEC: int = 45
const RT_DRAG_AFTER_SEC_BOSS: int = 240
const RT_DRAG_EVERY_SEC: int = 10
# E32 (07 §9.1, R5b-2a): the show economy of the real-time combat in the GDD §13 bands. A real-time combat has about
# three times the moments per minute of a CTB battle (auto-attacks, a combo every 5 s, the party SHOW every 30 s):
# auto-attack hits are no actions and bring no crit / weakness hype (RT_CRIT, RT_WEAK), combos and SHOW results count
# half (CTB +2 / +12 / +4), heals are no repetition (the healer's work, like slot 1); after a regular
# real-time combat with a system gift the next RT_GIFT_PAUSE regular ones bring none (Show; external gifts are never
# paced), and the followers of a won real-time combat are scaled (Show.end_battle).
const RT_COMBO: float = 1.0
const RT_SHOW_SUCCESS: float = 6.0           # SHOW / FINALE result (STUNT_RESULT)
const RT_SHOW_FAIL: float = 2.0
const RT_GIFT_PAUSE: int = 4                 # regular real-time combats without a system gift after one with a gift
const RT_FOLLOWER_PM: int = 600              # followers of a won real-time combat, per mille (ShowModel, integer)

## &"rt" — the only profile since R5b part 2b.
var profile: StringName = PROFILE_RT
var _controlled: String = ""                 # the controlled unit (RtSetup.controlled_id, CONTROL_CHANGED)
var _slot1: Dictionary = {}                  # party unit id → its slot-1 skill (no repetition penalty)
var _finale_skills: Dictionary = {}          # FINALE skill ids of the party (party.json rt.bar "finale")
var _taunts: Dictionary = {}                 # skill id → bool: applies a "fixate" status (memo)
var _rt_open: Dictionary = {}                # party unit id → {"command", "skill", "weak"} of its open action
var _rt_keys: PackedStringArray = []         # the person's last action keys (skill / item ids), oldest first
var _rt_repeat: int = 0
var _rt_kill_cts: Array[int] = []            # cts of the party's kills inside the streak window
var _rt_quiet: int = 0                       # combat seconds since the last positive event
var _rt_enraged: bool = false
var _rt_healer_said: bool = false


## The controlled unit as the profile knows it ("" without an RtSetup).
func controlled_id() -> String:
	return _controlled


func _rt_init(s: RtSetup) -> void:
	_controlled = s.controlled_id
	for u: RtUnit in s.units:
		if u == null or u.side != Combatant.Side.PARTY:
			continue
		_slot1[u.id] = str(u.bar.get(1, u.bar.get("1", "")))
		if _data != null and _data.has_id("party", u.def_id):
			for row: Variant in (_data.party_member(u.def_id).rt.get("bar", []) as Array):
				if row is Dictionary and bool((row as Dictionary).get("finale", false)):
					_finale_skills[str((row as Dictionary).get("skill", ""))] = true


func _rt_feed(d: ShowDelta, e: ActionEvent) -> void:
	match e.type:
		ActionEvent.Type.ACTION_START:
			_rt_action_start(d, e)
		ActionEvent.Type.ACTION_END:
			if str((_rt_open.get(e.actor_id, {}) as Dictionary).get("skill", "")) == e.skill_id:
				_rt_open.erase(e.actor_id)
		ActionEvent.Type.DAMAGE:
			_rt_damage(d, e)
		ActionEvent.Type.HEAL:
			if _is_party(e.target_id) and e.hp_after >= 0:
				_hp[e.target_id] = e.hp_after
		ActionEvent.Type.KO:
			_rt_ko(d, e)
		ActionEvent.Type.STATUS_ADDED:
			_rt_status_added(e)
		ActionEvent.Type.COMBO:
			if _is_party(e.actor_id):
				_add(d, RT_COMBO, &"combo")
				_trigger(d, "combo", {"member": _member(e.actor_id), "enemy_id": e.def_id})
		ActionEvent.Type.STUNT_RESULT:
			if _is_party(e.actor_id):
				_rt_stunt(d, e)
		ActionEvent.Type.REVIVE:
			if _is_party(e.target_id):
				_add(d, HYPE_REVIVE, &"revive")
				if e.hp_after >= 0:
					_hp[e.target_id] = e.hp_after
		ActionEvent.Type.FLEE_RESULT:
			if _is_party(e.actor_id) and e.success:
				_add(d, HYPE_FLEE_OK, &"flee")
		ActionEvent.Type.CAST_INTERRUPTED:
			if e.actor_id == _controlled and not e.by_ai:
				_add(d, RT_INTERRUPT, &"rt_interrupt")
				_stat(d, "interrupts_total")
		ActionEvent.Type.TELEGRAPH_DODGED:
			if e.target_id == _controlled and not e.by_ai:
				_add(d, RT_DODGE_CLOSE if e.success else RT_DODGE, &"rt_dodge_close" if e.success else &"")
				_stat(d, "dodges_total")
		ActionEvent.Type.TELEGRAPH_IMPACT:
			if _controlled != "" and e.target_ids.has(_controlled):
				_reason(d, &"rt_telegraph_hit")
		ActionEvent.Type.PHASE_CHANGE, ActionEvent.Type.BATTLE_END:
			if e.success:
				_add(d, RT_PERFECT_PHASE)
		ActionEvent.Type.ENRAGE:
			if not _rt_enraged:
				_rt_enraged = true
				_add(d, RT_ENRAGE)
		ActionEvent.Type.CONTROL_CHANGED:
			_controlled = e.target_id
			_reason(d, StringName("rt_control_switch:" + _member(e.target_id)))
		ActionEvent.Type.PRESET_CHANGED:
			_reason(d, StringName("rt_partner_preset:" + e.text))
		ActionEvent.Type.FLEE_WARNING:
			if e.actor_id == _controlled:
				_reason(d, &"rt_flee_warn")
		ActionEvent.Type.CAST_START:
			if not _rt_healer_said and _is_enemy(e.actor_id):
				var sk: SkillDef = _skill_or_null(e.skill_id)
				if sk != null and sk.damage_type == "heal":
					_rt_healer_said = true
					_reason(d, &"rt_healer_first")
		ActionEvent.Type.SECOND:
			_rt_second(d, e.value)


## ACTION_START (07 §9.1): the action opens (weakness once per action, the source of its statuses); a skill's own hype
## (an item's use_skill, e.g. the megaphone) for every party actor; the person's actions (by_ai false: the controlled
## unit and the Partner-Spezial) count for variety, repetition (never the slot-1 skill), taunts and the FINALE line.
func _rt_action_start(d: ShowDelta, e: ActionEvent) -> void:
	if not _is_party(e.actor_id):
		return
	_rt_open[e.actor_id] = {"command": e.command, "skill": e.skill_id, "weak": false}
	var sk: SkillDef = _action_skill(e)
	if sk != null and sk.hype != 0:
		_add(d, float(sk.hype))
	if e.by_ai:
		return
	var key: String = e.item_id if e.command == BattleCommand.Kind.ITEM and e.item_id != "" else e.skill_id
	if not _rt_keys.has(key):
		_add(d, RT_VARIETY)
	_rt_repeat = _rt_repeat + 1 if not _rt_keys.is_empty() and _rt_keys[_rt_keys.size() - 1] == key else 1
	if _rt_repeat >= RT_REPEAT_COUNT and key != str(_slot1.get(e.actor_id, "")) and not _is_heal(e.skill_id):
		_add(d, RT_REPEAT, &"boring_fight")
	_rt_keys.append(key)
	while _rt_keys.size() > RT_VARIETY_WINDOW:
		_rt_keys.remove_at(0)
	if e.command != BattleCommand.Kind.ITEM and _is_taunt(e.skill_id):
		_stat(d, "taunts_total")
	if e.command == BattleCommand.Kind.STUNT and _finale_skills.has(e.skill_id):
		_reason(d, &"rt_finale")


func _rt_damage(d: ShowDelta, e: ActionEvent) -> void:
	if e.actor_id == "" and e.status_id != "" and _is_enemy(e.target_id):
		_tick_status[e.target_id] = e.status_id
	else:
		_tick_status.erase(e.target_id)
	if _is_party(e.actor_id) and _is_enemy(e.target_id) and e.status_id == "":
		# E32: an auto-attack hit (no open action of its skill) is no action — its crit / weakness is presentation only
		var a: Dictionary = _rt_open.get(e.actor_id, {})
		var ability: bool = not a.is_empty() and str(a["skill"]) == e.skill_id
		if e.crit:
			_stat(d, "crits_total")
			if ability:
				_add(d, RT_CRIT, &"crit")
			else:
				_reason(d, &"crit")
		if e.weak:
			if not ability:
				_reason(d, &"weakness")
			elif not bool(a["weak"]):
				a["weak"] = true
				_add(d, RT_WEAK, &"weakness")
	if _is_party(e.target_id):
		_check_low_hp(d, e)
		if e.hp_after >= 0:
			_hp[e.target_id] = e.hp_after


## KO (07 §9.1, §3.13): an enemy killed by a party hit (KO.command ATTACK / SKILL / STUNT / ITEM) → kill hype by kind
## (+ kill_hype, overkill, streak); by a party status / zone (command −1) → credited to the action that applied the
## status, no kill hype; by an enemy telegraph → train kill. A party KO: its hype, stat and trigger.
func _rt_ko(d: ShowDelta, e: ActionEvent) -> void:
	if _is_enemy(e.target_id):
		_stat(d, "kills_total")
		var by: String = "attack"
		var member: String = ""
		var overkill: bool = e.value == 1
		if _is_party(e.actor_id) and e.command >= 0:
			member = _member(e.actor_id)
			by = _by_for(e.command)
			match by:
				"skill":
					_add(d, HYPE_KILL_SKILL)
					_stat(d, "kills_skill")
				"stunt":
					_add(d, HYPE_KILL_STUNT)
				_:
					_add(d, HYPE_KILL_ATTACK)
			var ks: SkillDef = _skill_or_null(e.skill_id)
			if ks != null and ks.kill_hype > 0:
				_add(d, float(ks.kill_hype))
			if overkill:
				_add(d, HYPE_OVERKILL, &"overkill")
			_rt_streak_kill(d, e.tick)
		elif _is_party(e.actor_id):
			member = _member(e.actor_id)
			var src: Dictionary = _status_src.get(e.target_id + "|" + str(_tick_status.get(e.target_id, "")), {})
			by = _by_for(int(src.get("command", BattleCommand.Kind.ATTACK)))
			if by == "skill":
				_stat(d, "kills_skill")
		elif _is_enemy(e.actor_id):
			_add(d, RT_TRAIN_KILL, &"rt_train_kill")
			_stat(d, "train_kills")
		_tick_status.erase(e.target_id)
		_trigger(d, "enemy_killed", {"enemy_id": e.def_id, "overkill": overkill, "by": by, "member": member})
	elif _is_party(e.target_id):
		var who: String = _member(e.target_id)
		if who == "":
			who = e.def_id
		_add(d, HYPE_PARTY_KO, StringName(who + "_ko"))
		if who == "mopsula":
			_stat(d, "ko_mopsula")
		_trigger(d, "party_ko", {"member": who})
		_hp[e.target_id] = 0


## The party action behind a status on an enemy (a later status kill is credited to it): the applying unit's open
## action, else an auto-attack.
func _rt_status_added(e: ActionEvent) -> void:
	if not _is_enemy(e.target_id) or e.status_id == "":
		return
	var key: String = e.target_id + "|" + e.status_id
	if _is_party(e.actor_id):
		var a: Dictionary = _rt_open.get(e.actor_id, {})
		_status_src[key] = {"actor": e.actor_id, "command": int(a.get("command", BattleCommand.Kind.ATTACK))}
	else:
		_status_src.erase(key)


## SHOW / FINALE results count for the whole party's hype; the stats and the stunt_resolved trigger (achievements,
## "own SHOW") only for the person's (E27: the AI partner's SHOW is no own SHOW).
func _rt_stunt(d: ShowDelta, e: ActionEvent) -> void:
	if e.success:
		_add(d, RT_SHOW_SUCCESS, &"stunt_success")
	else:
		_add(d, RT_SHOW_FAIL, &"stunt_fail")
	if e.by_ai:
		return
	if e.success:
		_stat(d, "stunts_success")
		_stunts_ok += 1
	else:
		_stat(d, "stunts_fail")
	_trigger(d, "stunt_resolved", {"success": e.success, "member": _member(e.actor_id), "skill_id": e.skill_id})


## 3 kills of the party within RT_STREAK_TICKS → the streak bonus, then the window starts over.
func _rt_streak_kill(d: ShowDelta, ct: int) -> void:
	_rt_kill_cts.append(ct)
	while not _rt_kill_cts.is_empty() and ct - _rt_kill_cts[0] >= RT_STREAK_TICKS:
		_rt_kill_cts.pop_front()
	if _rt_kill_cts.size() >= RT_STREAK_KILLS:
		_add(d, HYPE_KILL_STREAK, &"kill_streak")
		_rt_kill_cts.clear()


## SECOND (whole combat seconds): boredom (RT_BORING per RT_BORING_SEC seconds without a positive event) and drag
## (RT_DRAG every RT_DRAG_EVERY_SEC seconds from RT_DRAG_AFTER_SEC, bosses RT_DRAG_AFTER_SEC_BOSS, on).
func _rt_second(d: ShowDelta, sec: int) -> void:
	_rt_quiet = 0 if _positive else _rt_quiet + 1
	_positive = false
	if _rt_quiet >= RT_BORING_SEC:
		_rt_quiet = 0
		_add(d, RT_BORING)
	var after: int = RT_DRAG_AFTER_SEC_BOSS if _setup != null and _setup.is_boss else RT_DRAG_AFTER_SEC
	if sec >= after and (sec - after) % RT_DRAG_EVERY_SEC == 0:
		_add(d, RT_DRAG)


## E32: a heal (SkillDef.damage_type "heal") is never a repetition — healing the tank four times in a row is work.
func _is_heal(skill_id: String) -> bool:
	var sk: SkillDef = _skill_or_null(skill_id)
	return sk != null and sk.damage_type == "heal"


## The skill applies a status with the rt flag "fixate" (a taunt, 07 §9.4 taunts_total). Memoized.
func _is_taunt(skill_id: String) -> bool:
	if _taunts.has(skill_id):
		return bool(_taunts[skill_id])
	var yes: bool = false
	var sk: SkillDef = _skill_or_null(skill_id)
	if sk != null:
		for s: Variant in (sk.rt.get("statuses", []) as Array):
			var sid: String = str((s as Dictionary).get("id", "")) if s is Dictionary else ""
			if sid != "" and _data.has_id("statuses", sid) \
					and (_data.status(sid).rt.get("flags", []) as Array).has("fixate"):
				yes = true
	_taunts[skill_id] = yes
	return yes


## A presentation reason without hype (a M.O.D. line tag, 07 §9.3).
static func _reason(d: ShowDelta, reason: StringName) -> void:
	if not d.reasons.has(reason):
		d.reasons.append(reason)
