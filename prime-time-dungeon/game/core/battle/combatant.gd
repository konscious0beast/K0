class_name Combatant extends RefCounted
## Battle participant (02_TECH §5.4). Effective stats are integers (status stat_mult applied in permille, 05 CR-12).

const FixedMath := preload("res://core/stats/fixed_math.gd")

enum Side { PARTY, ENEMY }

var id: String = ""                          # "p0".."p3" / "e0".. / "u0".. (summons continue numbering, never reused)
var def_id: String = ""                      # "kai" / "enm_kanalratte" / "pu_train_gleis9"
var side: Combatant.Side = Side.PARTY
var is_pseudo: bool = false                  # not targetable, no HP, acts via PseudoUnitDef.action, in CTB preview
var slot: int = 0                            # stage slot 0..3 (pseudo: -1)
var display_name: String = ""
var level: int = 1
var stats: StatBlock = null                  # incl. equipment/class (computed outside); max_hp = stats HP
var hp: int = 0
var mp: int = 0
var statuses: Array[StatusEffect] = []
var ctb_counter: int = 0
var defending: bool = false
var attack_skill: String = ""
var skills: PackedStringArray = []
var stunts: PackedStringArray = []
var stunt_cooldown: int = 0                  # own turns until STUNT is available again
var element_mods: Dictionary = {}
var status_immune: PackedStringArray = []
var status_resist: Dictionary = {}           # status id → 0..1
var attack_element: String = "physical"
var crit_bonus: float = 0.0                  # from equipment
var ai: Dictionary = {}                      # EnemyDef.ai (normalized)
var phases: Array[Dictionary] = []           # EnemyDef.phases
var phase: int = 0                           # current phase index (0-based; -1 = not yet entered)
var used_once: PackedStringArray = []        # AI actions with cond.once already used ("<phase>:<index>")
var own_turns: int = 0                       # completed own turns (turn_mod, first own turn = 0)
var is_boss: bool = false
var is_summon: bool = false                  # summoned units give no EXP/credits/drops
var exp_reward: int = 0
var credit_reward: int = 0
var drops: Array[Dictionary] = []
var boss_drops: Array[Dictionary] = []
var model: Dictionary = {}                   # ModelSpec passthrough for presentation
var last_action_key: String = ""             # "attack" / skill id / item id / "stunt" / "defend" (show variety)

# --- M1 runtime extensions (part of the snapshot) ------------------------------------------------------------------
var left_battle: bool = false                # escaped enemy / removed pseudo unit: out of the battle and the CTB order
var pseudo_def: PseudoUnitDef = null         # pseudo units only (action, ctr_after, warning)
var warned: bool = false                     # pseudo units: M.O.D. warning given since the unit's last action
## 06 package B: battle-time talent factors of a party member (Talents.battle_mods): {"preemptive_dmg_pm": int,
## "stunt_pm": int}, only non-neutral entries; part of the snapshot only when set (old snapshots stay identical).
var talent_mods: Dictionary = {}


static func create_enemy(def: EnemyDef, id: String, slot: int) -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = id
	c.side = Side.ENEMY
	c.slot = slot
	if def == null:
		c.stats = StatBlock.new()
		return c
	c.def_id = def.id
	c.display_name = def.name
	c.level = def.level
	c.stats = StatBlock.from_dict(def.stats)
	c.hp = c.max_hp()
	c.mp = c.max_mp()
	c.attack_skill = def.attack_skill
	c.skills = enemy_skill_ids(def)
	c.attack_element = Elements.PHYSICAL
	c._apply_enemy_def(def, true)
	c.element_mods = def.element_mods.duplicate(true)
	c.status_immune = def.status_immune.duplicate()
	c.status_resist = def.status_resist.duplicate(true)
	c.phase = -1 if not def.phases.is_empty() else 0
	return c


static func create_pseudo(def: PseudoUnitDef, id: String) -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = id
	c.side = Side.ENEMY
	c.is_pseudo = true
	c.slot = -1
	c.stats = StatBlock.new()
	c.pseudo_def = def
	if def != null:
		c.def_id = def.id
		c.display_name = def.name
	return c


static func create_party(def: PartyMemberDef, id: String, slot: int, display_name: String, level: int,
		stats: StatBlock, hp: int, mp: int, skills: PackedStringArray, stunts: PackedStringArray, attack_skill: String,
		element_mods: Dictionary, status_immune: PackedStringArray, attack_element: String, crit_bonus: float) -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = id
	c.side = Side.PARTY
	c.slot = slot
	c.display_name = display_name
	c.level = level
	c.stats = stats.duplicate_block() if stats != null else StatBlock.new()
	c.hp = hp
	c.mp = mp
	c.skills = skills.duplicate()
	c.stunts = stunts.duplicate()
	c.attack_skill = attack_skill
	c.element_mods = element_mods.duplicate(true)
	c.status_immune = status_immune.duplicate()
	c.attack_element = attack_element if attack_element != "" else Elements.PHYSICAL
	c.crit_bonus = crit_bonus
	if def != null:
		c.def_id = def.id
		c.status_resist = def.status_resist.duplicate(true)
		c.model = def.model.duplicate(true)
		if c.display_name == "":
			c.display_name = def.name
	return c


## Skill ids an enemy can use: all AI actions (ai.actions + every phase) in data order, then the attack skill.
static func enemy_skill_ids(def: EnemyDef) -> PackedStringArray:
	var out: PackedStringArray = []
	var lists: Array = [def.ai.get("actions", [])]
	for p: Dictionary in def.phases:
		lists.append(p.get("actions", []))
	for list: Variant in lists:
		for a: Variant in (list as Array):
			var sid: String = str((a as Dictionary).get("skill", ""))
			if sid != "" and not out.has(sid):
				out.append(sid)
	if def.attack_skill != "" and not out.has(def.attack_skill):
		out.append(def.attack_skill)
	return out


## Pseudo: true while in the order. Others: hp > 0 and still in the battle (not escaped).
func is_alive() -> bool:
	if left_battle:
		return false
	if is_pseudo:
		return true
	return hp > 0


## KO'd (revivable): a real unit with hp <= 0 that did not leave the battle.
func is_ko() -> bool:
	return not is_pseudo and not left_battle and hp <= 0


func is_party() -> bool:
	return side == Side.PARTY


func max_hp() -> int:
	return stats.get_stat(StatBlock.Stat.HP) if stats != null else 0


func max_mp() -> int:
	return stats.get_stat(StatBlock.Stat.MP) if stats != null else 0


## Effective: base × product(status stat_mult), roundi, min 1 (HP/MP unmodified).
func stat(s: StatBlock.Stat) -> int:
	if stats == null:
		return 0
	var base: int = stats.get_stat(s)
	if s == StatBlock.Stat.HP or s == StatBlock.Stat.MP:
		return base
	var key: String = StatBlock.KEYS[int(s)]
	var v: int = base * FixedMath.PM
	for st: StatusEffect in statuses:
		if st.def != null and st.def.stat_mult.has(key):
			v = FixedMath.mul_pm(v, FixedMath.pm(float(st.def.stat_mult[key])))
	return maxi(1, FixedMath.div_round(v, FixedMath.PM))


func has_status(status_id: String) -> bool:
	return get_status(status_id) != null


func get_status(status_id: String) -> StatusEffect:
	for st: StatusEffect in statuses:
		if st.id() == status_id:
			return st
	return null


## Any active status has flag.
func has_flag(flag: String) -> bool:
	for st: StatusEffect in statuses:
		if st.def != null and st.def.has_flag(flag):
			return true
	return false


func hp_ratio() -> float:
	var m: int = max_hp()
	if m <= 0:
		return 0.0
	return float(maxi(0, hp)) / float(m)


func mp_ratio() -> float:
	var m: int = max_mp()
	if m <= 0:
		return 0.0
	return float(maxi(0, mp)) / float(m)


## Product of tick_speed_mult of active statuses (haste 0.6 / slow 1.5).
func speed_mult() -> float:
	return float(speed_pm()) / float(FixedMath.PM)


## speed_mult() in permille (integer product, used by CTBQueue).
func speed_pm() -> int:
	var v: int = FixedMath.PM
	for st: StatusEffect in statuses:
		if st.def != null:
			v = FixedMath.mul_pm(v, FixedMath.pm(st.def.tick_speed_mult))
	return maxi(1, v)


## Deep copy (StatusDef references shared, they are immutable).
func duplicate_combatant() -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = id
	c.def_id = def_id
	c.side = side
	c.is_pseudo = is_pseudo
	c.slot = slot
	c.display_name = display_name
	c.level = level
	c.stats = stats.duplicate_block() if stats != null else StatBlock.new()
	c.hp = hp
	c.mp = mp
	for st: StatusEffect in statuses:
		c.statuses.append(st.duplicate_effect())
	c.ctb_counter = ctb_counter
	c.defending = defending
	c.attack_skill = attack_skill
	c.skills = skills.duplicate()
	c.stunts = stunts.duplicate()
	c.stunt_cooldown = stunt_cooldown
	c.element_mods = element_mods.duplicate(true)
	c.status_immune = status_immune.duplicate()
	c.status_resist = status_resist.duplicate(true)
	c.attack_element = attack_element
	c.crit_bonus = crit_bonus
	c.ai = ai.duplicate(true)
	c.phases.assign(phases.duplicate(true))
	c.phase = phase
	c.used_once = used_once.duplicate()
	c.own_turns = own_turns
	c.is_boss = is_boss
	c.is_summon = is_summon
	c.exp_reward = exp_reward
	c.credit_reward = credit_reward
	c.drops.assign(drops.duplicate(true))
	c.boss_drops.assign(boss_drops.duplicate(true))
	c.model = model.duplicate(true)
	c.last_action_key = last_action_key
	c.left_battle = left_battle
	c.pseudo_def = pseudo_def
	c.warned = warned
	c.talent_mods = talent_mods.duplicate()
	return c


## Float-free snapshot (05 CR-14): runtime state only; static def data (ai, phases, drops, model, pseudo action) is
## re-derived from GameData by from_dict. Floats (element_mods, status_resist, crit_bonus) as ppm ints.
func to_dict() -> Dictionary:
	var sts: Array = []
	for st: StatusEffect in statuses:
		sts.append(st.to_dict())
	return {
		"id": id, "def_id": def_id, "side": int(side), "is_pseudo": is_pseudo, "slot": slot,
		"display_name": display_name, "level": level,
		"stats": stats.to_dict() if stats != null else StatBlock.new().to_dict(),
		"hp": hp, "mp": mp, "statuses": sts, "ctb_counter": ctb_counter, "defending": defending,
		"attack_skill": attack_skill, "skills": Array(skills), "stunts": Array(stunts), "stunt_cooldown": stunt_cooldown,
		"element_mods_ppm": _to_ppm(element_mods), "status_immune": Array(status_immune),
		"status_resist_ppm": _to_ppm(status_resist), "attack_element": attack_element,
		"crit_bonus_ppm": FixedMath.ppm(crit_bonus), "phase": phase, "used_once": Array(used_once),
		"own_turns": own_turns, "is_boss": is_boss, "is_summon": is_summon, "exp_reward": exp_reward,
		"credit_reward": credit_reward, "last_action_key": last_action_key, "left_battle": left_battle,
		"warned": warned,
	}.merged({"talent_mods": talent_mods.duplicate()} if not talent_mods.is_empty() else {})


static func from_dict(d: Dictionary, data: GameData) -> Combatant:
	var c: Combatant = Combatant.new()
	c.id = str(d.get("id", ""))
	if c.id == "":
		return null
	c.def_id = str(d.get("def_id", ""))
	c.side = (Side.PARTY if JsonUtil.to_int(d.get("side", 0)) == 0 else Side.ENEMY) as Combatant.Side
	c.is_pseudo = bool(d.get("is_pseudo", false))
	c.slot = JsonUtil.to_int(d.get("slot", 0))
	c.display_name = str(d.get("display_name", ""))
	c.level = JsonUtil.to_int(d.get("level", 1), 1)
	var sd: Variant = d.get("stats", {})
	c.stats = StatBlock.from_dict(sd if sd is Dictionary else {})
	c.hp = JsonUtil.to_int(d.get("hp", 0))
	c.mp = JsonUtil.to_int(d.get("mp", 0))
	for v: Variant in (d.get("statuses", []) as Array):
		if v is Dictionary:
			var st: StatusEffect = StatusEffect.from_dict(v, data)
			if st != null:
				c.statuses.append(st)
	c.ctb_counter = JsonUtil.to_int(d.get("ctb_counter", 0))
	c.defending = bool(d.get("defending", false))
	c.attack_skill = str(d.get("attack_skill", ""))
	c.skills = JsonUtil.to_str_array(d.get("skills", []))
	c.stunts = JsonUtil.to_str_array(d.get("stunts", []))
	c.stunt_cooldown = JsonUtil.to_int(d.get("stunt_cooldown", 0))
	c.element_mods = _from_ppm(d.get("element_mods_ppm", {}))
	c.status_immune = JsonUtil.to_str_array(d.get("status_immune", []))
	c.status_resist = _from_ppm(d.get("status_resist_ppm", {}))
	c.attack_element = str(d.get("attack_element", Elements.PHYSICAL))
	c.crit_bonus = FixedMath.from_ppm(JsonUtil.to_int(d.get("crit_bonus_ppm", 0)))
	c.phase = JsonUtil.to_int(d.get("phase", 0))
	c.used_once = JsonUtil.to_str_array(d.get("used_once", []))
	c.own_turns = JsonUtil.to_int(d.get("own_turns", 0))
	c.is_boss = bool(d.get("is_boss", false))
	c.is_summon = bool(d.get("is_summon", false))
	c.exp_reward = JsonUtil.to_int(d.get("exp_reward", 0))
	c.credit_reward = JsonUtil.to_int(d.get("credit_reward", 0))
	c.last_action_key = str(d.get("last_action_key", ""))
	c.left_battle = bool(d.get("left_battle", false))
	c.warned = bool(d.get("warned", false))
	var tm: Variant = d.get("talent_mods", {})
	if tm is Dictionary:
		for k: Variant in (tm as Dictionary).keys():
			c.talent_mods[str(k)] = JsonUtil.to_int((tm as Dictionary)[k], 1000)
	if data != null:
		if c.is_pseudo:
			if data.has_id("pseudo_units", c.def_id):
				c.pseudo_def = data.pseudo_unit(c.def_id)
		elif c.side == Side.ENEMY:
			if data.has_id("enemies", c.def_id):
				c._apply_enemy_def(data.enemy(c.def_id), false)
		elif data.has_id("party", c.def_id):
			c.model = data.party_member(c.def_id).model.duplicate(true)
	return c


## Static enemy data (not part of the snapshot): AI, phases, drops, boss drops, model; rewards and boss flag only on
## creation.
func _apply_enemy_def(def: EnemyDef, with_rewards: bool) -> void:
	ai = def.ai.duplicate(true)
	phases.assign(def.phases.duplicate(true))
	drops.assign(def.drops.duplicate(true))
	boss_drops.assign(def.boss_drops.duplicate(true))
	model = def.model.duplicate(true)
	if with_rewards:
		exp_reward = def.exp
		credit_reward = def.credits
		is_boss = def.boss


static func _to_ppm(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: PackedStringArray = []
	for k: Variant in d.keys():
		keys.append(str(k))
	keys.sort()
	for k: String in keys:
		out[k] = FixedMath.ppm(float(d[k]))
	return out


static func _from_ppm(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		var src: Dictionary = v
		for k: Variant in src.keys():
			out[str(k)] = FixedMath.from_ppm(JsonUtil.to_int(src[k]))
	return out
