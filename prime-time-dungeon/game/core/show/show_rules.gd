class_name ShowRules extends RefCounted
## ActionEvent → ShowDelta for one battle (02_TECH §6.1/§6.2, GDD §7.3 row by row).
##
## Self-contained: needs only ActionEvent fields + the BattleSetup (party combatant ids → member def ids, boss flag,
## advantage) and skill/item defs for `hype` / `kill_hype`. Side is read from the id (`p…` party, `e…` enemy,
## `u…` pseudo unit, §5.3). Deltas are raw (before hype_gain_mult, which Show applies to the positive parts only).
##
## Interpretations (documented): crit +5 per crit, weakness +4 at most once per action (GDD §7.3 is canonical for
## numbers); enemies killed without a party actor (status tick) count as kills but give no kill hype (not a party
## action): the kill is credited to the party action that applied the ticking status (STATUS_ADDED during an open
## party action → its `by` / `member`, `kills_skill` for a skill), otherwise `by: "attack"`, `member: ""` — `by` stays
## within the documented attack/skill/stunt/item (§6.3); "falls under 25 %" needs the previous HP at ≥ 25 %.

const HYPE_START_NORMAL: float = 5.0
const HYPE_START_PREEMPTIVE: float = 5.0
const HYPE_START_AMBUSH: float = 8.0
const HYPE_START_BOSS: float = 10.0          # replaces the others
const HYPE_VARIETY: float = 3.0              # action_key not among the last VARIETY_WINDOW party keys
const VARIETY_WINDOW: int = 4
const HYPE_REPEAT: float = -5.0              # same key the REPEAT_COUNT-th time in a row (and every further time)
const REPEAT_COUNT: int = 3
const HYPE_DEFEND_TWICE: float = -4.0        # defend twice in a row by the same character
const HYPE_DRAG: float = -3.0                # every party turn after the DRAG_AFTER-th (boss: DRAG_AFTER_BOSS)
const DRAG_AFTER: int = 10
const DRAG_AFTER_BOSS: int = 25
const HYPE_CRIT: float = 5.0
const HYPE_WEAK: float = 4.0
const HYPE_KILL_ATTACK: float = 3.0          # also item kills
const HYPE_KILL_SKILL: float = 6.0
const HYPE_KILL_STUNT: float = 10.0
const HYPE_OVERKILL: float = 8.0
const HYPE_KILL_STREAK: float = 6.0          # STREAK_KILLS kills within STREAK_ACTIONS consecutive party actions
const STREAK_KILLS: int = 3
const STREAK_ACTIONS: int = 3
const HYPE_COMBO: float = 5.0
const HYPE_STUNT_SUCCESS: float = 20.0
const HYPE_STUNT_FAIL: float = 8.0
const HYPE_LOW_HP: float = 6.0               # party member falls under LOW_HP_PCT % (once per member and battle)
const LOW_HP_PCT: int = 25
const HYPE_PARTY_KO: float = 10.0
const HYPE_REVIVE: float = 8.0
const HYPE_FLEE_OK: float = -30.0
const HYPE_FLEE_FAIL: float = -5.0
const HYPE_BORING: float = -2.0              # party turn without a positive hype event since its ACTION_START
const HYPE_CLOSE_WIN: float = 15.0           # victory with min_party_hp_pct <= CLOSE_WIN_PCT
const CLOSE_WIN_PCT: float = 0.10
const HYPE_FLAWLESS: float = 5.0             # victory with damage_taken == 0

var _data: GameData = null
var _setup: BattleSetup = null
var _party_defs: Dictionary = {}             # combatant id → party member def id
var _hp: Dictionary = {}                     # party combatant id → last known hp
var _keys: PackedStringArray = []            # party action keys, oldest first
var _repeat: int = 0                         # length of the current run of identical party keys
var _last_own_key: Dictionary = {}           # combatant id → key of its previous action
var _party_actions: int = 0
var _in_action: bool = false                 # a party action is open (ACTION_START … TURN_END)
var _actor: String = ""
var _command: int = -1
var _skill_id: String = ""
var _item_id: String = ""
var _positive: bool = false                  # positive hype event since the open party ACTION_START
var _weak_done: bool = false
var _kill_window: Array[int] = []            # kills of the last STREAK_ACTIONS party actions (current last)
var _low_hp_done: Dictionary = {}
var _stunts_ok: int = 0
var _started: bool = false
var _status_src: Dictionary = {}             # "<enemy id>|<status id>" → {"actor", "command"} of the applying party action
var _tick_status: Dictionary = {}            # enemy id → status id of its last status-tick DAMAGE


## Self-contained: needs only ActionEvent fields + setup.
func _init(p_data: GameData, p_setup: BattleSetup) -> void:
	_data = p_data
	_setup = p_setup
	if _setup != null:
		for c: Combatant in _setup.party:
			if c != null and c.id != "":
				_party_defs[c.id] = c.def_id
				_hp[c.id] = c.hp


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
	match e.type:
		ActionEvent.Type.BATTLE_START:
			return start_delta()
		ActionEvent.Type.ACTION_START:
			_on_action_start(d, e)
		ActionEvent.Type.DAMAGE:
			_on_damage(d, e)
		ActionEvent.Type.HEAL:
			if _is_party(e.target_id) and e.hp_after >= 0:
				_hp[e.target_id] = e.hp_after
		ActionEvent.Type.KO:
			_on_ko(d, e)
		ActionEvent.Type.STATUS_ADDED:
			_on_status_added(e)
		ActionEvent.Type.COMBO:
			if _is_party(e.actor_id):
				_add(d, HYPE_COMBO, &"combo")
				_trigger(d, "combo", {"member": _member(e.actor_id), "enemy_id": e.def_id})
		ActionEvent.Type.STUNT_RESULT:
			if _is_party(e.actor_id):
				_on_stunt(d, e)
		ActionEvent.Type.REVIVE:
			if _is_party(e.target_id):
				_add(d, HYPE_REVIVE, &"revive")
				if e.hp_after >= 0:
					_hp[e.target_id] = e.hp_after
		ActionEvent.Type.FLEE_RESULT:
			if _is_party(e.actor_id):
				if e.success:
					_add(d, HYPE_FLEE_OK, &"flee")
				else:
					_add(d, HYPE_FLEE_FAIL, &"flee_fail")
		ActionEvent.Type.TURN_END:
			if _in_action and e.actor_id == _actor:
				if not _positive:
					_add(d, HYPE_BORING)
				_in_action = false
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


# --- event handlers ---------------------------------------------------------------------------------------------------

func _on_action_start(d: ShowDelta, e: ActionEvent) -> void:
	if not _is_party(e.actor_id):
		_in_action = false
		return
	_in_action = true
	_actor = e.actor_id
	_command = e.command
	_skill_id = e.skill_id
	_item_id = e.item_id
	_positive = false
	_weak_done = false
	_party_actions += 1
	_kill_window.append(0)
	while _kill_window.size() > STREAK_ACTIONS:
		_kill_window.pop_front()
	var key: String = _action_key(e)
	var recent: PackedStringArray = _keys.slice(maxi(0, _keys.size() - VARIETY_WINDOW))
	if not recent.has(key):
		_add(d, HYPE_VARIETY)
	if not _keys.is_empty() and _keys[_keys.size() - 1] == key:
		_repeat += 1
	else:
		_repeat = 1
	if _repeat >= REPEAT_COUNT:
		_add(d, HYPE_REPEAT, &"boring_fight")
	var sk: SkillDef = _action_skill(e)
	if sk != null and sk.hype != 0:
		_add(d, float(sk.hype))
	if key == "defend" and str(_last_own_key.get(e.actor_id, "")) == "defend":
		_add(d, HYPE_DEFEND_TWICE)
	var drag_after: int = DRAG_AFTER_BOSS if (_setup != null and _setup.is_boss) else DRAG_AFTER
	if _party_actions > drag_after:
		_add(d, HYPE_DRAG)
	_keys.append(key)
	_last_own_key[e.actor_id] = key


func _on_damage(d: ShowDelta, e: ActionEvent) -> void:
	if e.actor_id == "" and e.status_id != "" and _is_enemy(e.target_id):
		_tick_status[e.target_id] = e.status_id
	if _is_party(e.actor_id) and _is_enemy(e.target_id) and e.status_id == "":
		if e.crit:
			_add(d, HYPE_CRIT, &"crit")
			_stat(d, "crits_total")
		if e.weak and not _weak_done:
			_weak_done = true
			_add(d, HYPE_WEAK, &"weakness")
	if _is_party(e.target_id):
		_check_low_hp(d, e)
		if e.hp_after >= 0:
			_hp[e.target_id] = e.hp_after


func _on_ko(d: ShowDelta, e: ActionEvent) -> void:
	if _is_enemy(e.target_id):
		_stat(d, "kills_total")
		var by: String = "attack"
		var member: String = ""
		var overkill: bool = e.value == 1
		if not _is_party(e.actor_id):
			var src: Dictionary = _kill_source(e)
			if not src.is_empty():
				by = _by_for(int(src.get("command", BattleCommand.Kind.ATTACK)))
				member = _member(str(src.get("actor", "")))
				if by == "skill":
					_stat(d, "kills_skill")
		else:
			member = _member(e.actor_id)
			by = _by_for(_command if (_in_action and e.actor_id == _actor) else BattleCommand.Kind.ATTACK)
			match by:
				"skill":
					_add(d, HYPE_KILL_SKILL)
					_stat(d, "kills_skill")
				"stunt":
					_add(d, HYPE_KILL_STUNT)
				_:
					_add(d, HYPE_KILL_ATTACK)
			var ks: SkillDef = _skill_or_null(e.skill_id if e.skill_id != "" else _skill_id)
			if ks != null and ks.kill_hype > 0:
				_add(d, float(ks.kill_hype))
			if overkill:
				_add(d, HYPE_OVERKILL, &"overkill")
			_count_streak_kill(d)
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


## Remembers which party action applied a status to an enemy (a later tick kill is credited to it); applied outside a
## party action (enemy, boss op, gift) → no party source.
func _on_status_added(e: ActionEvent) -> void:
	if not _is_enemy(e.target_id) or e.status_id == "":
		return
	var key: String = e.target_id + "|" + e.status_id
	if _in_action:
		_status_src[key] = {"actor": _actor, "command": _command}
	else:
		_status_src.erase(key)


## {"actor", "command"} of the party action behind a kill without party actor (status tick); {} if unknown.
func _kill_source(e: ActionEvent) -> Dictionary:
	if e.actor_id != "":
		return {}
	var status_id: String = str(_tick_status.get(e.target_id, ""))
	if status_id == "":
		return {}
	return _status_src.get(e.target_id + "|" + status_id, {})


func _on_stunt(d: ShowDelta, e: ActionEvent) -> void:
	if e.success:
		_add(d, HYPE_STUNT_SUCCESS, &"stunt_success")
		_stat(d, "stunts_success")
		_stunts_ok += 1
	else:
		_add(d, HYPE_STUNT_FAIL, &"stunt_fail")
		_stat(d, "stunts_fail")
	var skill_id: String = e.skill_id if e.skill_id != "" else _skill_id
	_trigger(d, "stunt_resolved", {"success": e.success, "member": _member(e.actor_id), "skill_id": skill_id})


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


## STREAK_KILLS kills within the last STREAK_ACTIONS party actions → bonus, then the window starts over.
func _count_streak_kill(d: ShowDelta) -> void:
	if _kill_window.is_empty():
		_kill_window.append(0)
	_kill_window[_kill_window.size() - 1] += 1
	var total: int = 0
	for k: int in _kill_window:
		total += k
	if total >= STREAK_KILLS:
		_add(d, HYPE_KILL_STREAK, &"kill_streak")
		_kill_window = [0]


# --- helpers ----------------------------------------------------------------------------------------------------------

## `attack`, skill id, item id, `stunt`, `defend`, `flee` (§6.2; GDD §7.3 adds `flee`).
func _action_key(e: ActionEvent) -> String:
	match e.command:
		BattleCommand.Kind.ATTACK:
			return "attack"
		BattleCommand.Kind.SKILL:
			return e.skill_id if e.skill_id != "" else "skill"
		BattleCommand.Kind.STUNT:
			return "stunt"
		BattleCommand.Kind.ITEM:
			return e.item_id if e.item_id != "" else "item"
		BattleCommand.Kind.DEFEND:
			return "defend"
		BattleCommand.Kind.FLEE:
			return "flee"
	return e.skill_id if e.skill_id != "" else "attack"


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
