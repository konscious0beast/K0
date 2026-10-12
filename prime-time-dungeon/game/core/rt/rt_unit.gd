class_name RtUnit extends Combatant
## A combatant with position, timers, cast, threat (07 §3.4). Ids, stats, hp/mp, statuses (RtStatus), element mods,
## crit bonus, rewards: inherited from Combatant (02_TECH §5.4); value talents arrive through these fields (06 B), the
## two behaviour talents as opener_pm / stunt_pm below (07 §9.6). max_hp() is already scaled (07 §3.9.4).
## display_name is the Def name (08 §2.7 Nr. 5: never the persona name; frames resolve names via UiUtil.member_name,
## StateHash.of_rt leaves display names out). RtSim works on its own copies (duplicate_unit) — an RtSetup's units stay
## the start data.

enum Driver { PLAYER, AI, AUTOPILOT }      # not "Control": would shadow the global Control class

## Snapshot keys of the real-time fields (in this order; Combatant.to_dict() supplies the rest).
const RT_FIELDS: PackedStringArray = ["driver", "x", "z", "yaw", "radius", "move_cm_tick", "stationary", "keep_cm",
	"follow_cm", "sample", "move_budget", "goal", "entry", "target_id", "auto_on", "auto_skill", "auto_ranged_skill",
	"swing_ticks", "reach", "swing_ready", "gcd_until", "gcd_len", "cast", "queued", "partner_order", "cooldowns",
	"lockout_until", "threat", "fixate_id", "fixate_until", "rules", "rule_ready", "follow_up", "preset", "toggles",
	"react_at", "ai_seen", "mp_regen", "mp_regen_next", "mp_hit_ready", "threat_pm", "dmg_pm", "ko_at",
	"outside_since", "pop_in_until", "phase_perfect", "opener_done", "opener_pm", "stunt_pm", "bar"]

var driver: RtUnit.Driver = Driver.AI
var x: int = 0                              # cm, room-local
var z: int = 0
var yaw: int = 0                            # 0..255
var radius: int = 40                        # cm
var move_cm_tick: int = 18                  # base speed (data cm/s / 30)
var stationary: bool = false
var keep_cm: int = 0                        # ranged: preferred distance to the target (0 = melee), ≤ 700
var follow_cm: int = 0                      # AI partner: max distance to the controlled unit while idle
var sample: Array[int] = []                 # PLAYER: last accepted move sample [ct, x, z, vx, vz, yaw] (mm per tick)
var move_budget: int = 600                  # PLAYER: tolerance budget in mm (§3.5.2)
var goal: Array[int] = []                   # sim-driven: [x, z] movement goal of this tick ([] = stand)
var entry: Array[int] = []                  # enemies: [x, z] Auftritt goal ([] = inside); no actions before arrival
var target_id: String = ""
var auto_on: bool = true
var auto_skill: String = ""                 # auto-attack skill id ("" = none)
var auto_ranged_skill: String = ""          # fallback auto-attack when the target is out of reach (§6.2)
var swing_ticks: int = 60
var reach: int = 250                        # auto-attack reach in cm
var swing_ready: int = 0                    # ct of the next possible swing
var gcd_until: int = 0
var gcd_len: int = 0                        # ticks of the running GCD (gcd_total)
## {} | {"skill", "target", "x", "z", "start", "end", "interruptible", "worthy", "moving_cancels", "channel",
## "next_tick", "tele", "kind": "ability"|"item", "item"}
var cast: Dictionary = {}
var queued: Dictionary = {}                 # {} | {"skill"|"item", "target", "at": ct of the press}
var partner_order: Dictionary = {}          # {} | {"skill", "until": ct}: buffered Partner-Spezial (§3.6.13)
var cooldowns: Dictionary = {}              # skill id → [ct ready again, cooldown length]
var lockout_until: int = 0                  # interrupted: no new casts before this ct
var threat: Dictionary = {}                 # enemies: unit id → int
var fixate_id: String = ""                  # enemies: forced target (taunt) …
var fixate_until: int = 0                   # … until this ct
var rules: Array[Dictionary] = []           # compiled RtRules of the current phase / preset
var rule_ready: Dictionary = {}             # rule key → ct when the rule may fire again
var follow_up: Dictionary = {}              # {} | {"skill", "target", "at"}: queued "then" skill of a rule (§5.3)
var preset: String = ""                     # party AI preset
var toggles: Dictionary = {}                # party AI switches
var react_at: int = -1                      # AI: ct at which the pending telegraph reaction starts (§5.5)
var ai_seen: Dictionary = {}                # AI: caster unit id → ct from which this unit reacts to that caster's
                                            #     current interrupt-worthy cast (E25, §5.3)
## {"mode": "hit"|"time", "amount", "taken", "taken_every_ticks", "every_ticks"}
var mp_regen: Dictionary = {}
var mp_regen_next: int = 0
var mp_hit_ready: int = 0                   # "hit" mode: ct from which a taken hit gives MP again
var threat_pm: int = 1000                   # unit threat multiplier (Kai 1500)
var dmg_pm: int = 1000                      # enemies: RT damage knob for formula hits (EnemyDef.rt.dmg_pm)
var ko_at: int = -1
var outside_since: int = -1                 # controlled unit: first ct outside the ring (flight), -1 inside
var pop_in_until: int = 0                   # formation members: no actions before this ct
var phase_perfect: bool = true              # bosses: no telegraph hit on the party during the current phase
var opener_done: bool = false               # party: first damaging hit of the combat already dealt (§9.6)
var opener_pm: int = 1000                   # party: Talents.preemptive_dmg_pm (06 B), set by make_rt_setup (§9.6)
var stunt_pm: int = 1000                    # party: Talents.stunt_window_pm (06 B), SHOW success (§9.6)
var bar: Dictionary = {}                    # party: slot (1..5) → skill id (loadout, level-filtered)


## Canonical snapshot (07 §3.4, §10.4): Combatant.to_dict() + every real-time field; dictionaries with sorted String
## keys (bar slots as "1".."5"), statuses as RtStatus.to_dict().
func snapshot() -> Dictionary:
	var d: Dictionary = to_dict()
	for k: String in RT_FIELDS:
		var v: Variant = get(k)
		if k == "driver":
			v = int(driver)
		d[k] = _canon(v)
	return d


## Inverse of snapshot() (fake sim, R1b restore): Combatant fields like Combatant.from_dict, statuses as RtStatus,
## then every real-time field. null without an id.
static func from_snapshot(d: Dictionary, data: GameData) -> RtUnit:
	var plain: Dictionary = d.duplicate()
	plain.erase("statuses")                  # RtStatus dictionaries, read below (Combatant.from_dict expects CTB ones)
	var base: Combatant = Combatant.from_dict(plain, null)
	if base == null:
		return null
	var u: RtUnit = RtUnit.new()
	for prop: Dictionary in base.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var pname: String = str(prop["name"])
		if pname == "statuses":
			continue
		u.set(pname, base.get(pname))
	for sv: Variant in (d.get("statuses", []) as Array):
		if sv is Dictionary:
			var st: RtStatus = RtStatus.from_rt_dict(sv, data)
			if st != null:
				u.statuses.append(st)
	if data != null and u.side == Side.ENEMY and data.has_id("enemies", u.def_id):
		u._apply_enemy_def(data.enemy(u.def_id), false)
	elif data != null and u.side == Side.PARTY and data.has_id("party", u.def_id):
		u.model = data.party_member(u.def_id).model.duplicate(true)
	u.driver = clampi(JsonUtil.to_int(d.get("driver", Driver.AI)), 0, 2) as RtUnit.Driver
	for k: String in RT_FIELDS:
		if k == "driver" or not d.has(k):
			continue
		var cur: Variant = u.get(k)
		var raw: Variant = d[k]
		if cur is Array:
			var arr: Array = cur
			arr.clear()
			if raw is Array:
				for e: Variant in (raw as Array):
					if arr.is_typed() and arr.get_typed_builtin() == TYPE_INT:
						arr.append(JsonUtil.to_int(e))
					elif arr.is_typed() and arr.get_typed_builtin() == TYPE_DICTIONARY:
						if e is Dictionary:
							arr.append((e as Dictionary).duplicate(true))
					else:
						arr.append(e)
		elif cur is Dictionary:
			u.set(k, (raw as Dictionary).duplicate(true) if raw is Dictionary else {})
		elif cur is bool:
			u.set(k, bool(raw))
		elif cur is int:
			u.set(k, JsonUtil.to_int(raw, int(cur)))
		else:
			u.set(k, str(raw))
	if not u.bar.is_empty():
		var bar_int: Dictionary = {}
		for sk: Variant in u.bar.keys():
			bar_int[str(sk).to_int()] = str(u.bar[sk])
		u.bar = bar_int
	return u


## A new RtUnit with every Combatant field of `c` (deep copies; statuses copied, the RT fields keep their defaults).
static func from_combatant(c: Combatant) -> RtUnit:
	var u: RtUnit = RtUnit.new()
	if c != null:
		_copy_fields(c, u, _combatant_fields())
	return u


## A new enemy unit of `def` (07 §4.9, §3.12) — BattleBridge.make_rt_setup and the sim's summons build them alike:
## Combatant.create_enemy (stats, rewards, element factors, immunities) plus the rt block: the real-time max HP
## (stats.hp, baked in R5b part 2b; a summon: rt.summon_hp when set, is_summon), radius, speed, stationary, keep
## distance, auto-attack (rt.auto_skill, else the attack skill), swing, reach, dmg_pm, rt.immune, the first swing after
## FIRST_SWING_TICKS; phase −1 for an enemy with rt.phases (entered when the combat starts, RtSim.start), else phase 0
## with its compiled rt.rules (keys "0:<index>", 07 §5.3).
static func from_enemy(def: EnemyDef, id: String, slot: int, bal: RtBalance, summon: bool = false) -> RtUnit:
	var u: RtUnit = from_combatant(Combatant.create_enemy(def, id, slot))
	if def == null:
		return u
	var b: RtBalance = bal if bal != null else RtBalance.new()
	var ert: Dictionary = def.rt
	var hp: int = maxi(1, int(def.stats.get("hp", 1)))
	if summon:
		if int(ert.get("summon_hp", 0)) > 0:
			hp = int(ert["summon_hp"])
		u.is_summon = true
	u.stats.values[StatBlock.Stat.HP] = hp
	u.hp = hp
	u.driver = Driver.AI
	u.radius = int(ert.get("radius_cm", 30))
	u.move_cm_tick = int(ert.get("move_cm_s", 360)) / 30
	u.stationary = bool(ert.get("stationary", false))
	u.keep_cm = clampi(int(ert.get("keep_cm", 0)), 0, 700)
	u.auto_skill = str(ert.get("auto_skill", def.attack_skill))
	u.auto_ranged_skill = str(ert.get("auto_ranged_skill", ""))
	u.swing_ticks = maxi(1, int(ert.get("swing_ms", 2400)) * 3 / 100)
	u.reach = int(ert.get("reach_cm", 220))
	u.dmg_pm = int(ert.get("dmg_pm", 1000))
	u.swing_ready = b.i("FIRST_SWING_TICKS")
	for sid: Variant in (ert.get("immune", []) as Array):
		if not u.status_immune.has(str(sid)):
			u.status_immune.append(str(sid))
	u.phase = -1 if not (ert.get("phases", []) as Array).is_empty() else 0
	if u.phase == 0:
		u.rules = RtRules.compile(ert.get("rules", []) as Array, "0")
	return u


## Deep copy with every field (Combatant + real time); statuses as copies, defs shared (immutable).
func duplicate_unit() -> RtUnit:
	var u: RtUnit = RtUnit.new()
	_copy_fields(self, u, _all_fields())
	return u


static var _fields_combatant: PackedStringArray = []
static var _fields_all: PackedStringArray = []


static func _combatant_fields() -> PackedStringArray:
	if _fields_combatant.is_empty():
		var base: Combatant = Combatant.new()
		for prop: Dictionary in base.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				_fields_combatant.append(str(prop["name"]))
	return _fields_combatant


static func _all_fields() -> PackedStringArray:
	if _fields_all.is_empty():
		var u: RtUnit = RtUnit.new()
		for prop: Dictionary in u.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
				_fields_all.append(str(prop["name"]))
	return _fields_all


static func _copy_fields(src: Combatant, dst: RtUnit, names: PackedStringArray) -> void:
	for n: String in names:
		var v: Variant = src.get(n)
		match n:
			"statuses":
				var sts: Array[StatusEffect] = []
				for st: StatusEffect in src.statuses:
					sts.append(st.duplicate_effect())
				dst.statuses = sts
				continue
			"stats":
				dst.stats = src.stats.duplicate_block() if src.stats != null else StatBlock.new()
				continue
		if v is Array or v is Dictionary or v is PackedStringArray:
			dst.set(n, v.duplicate(true) if not (v is PackedStringArray) else (v as PackedStringArray).duplicate())
		else:
			dst.set(n, v)


static func _canon(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var src: Dictionary = v
			var keys: Array = src.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var out: Dictionary = {}
			for k: Variant in keys:
				out[str(k)] = _canon(src[k])
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(_canon(e))
			return out_a
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return _canon(Array(v))
		TYPE_STRING_NAME:
			return String(v)
	return v
