extends RefCounted
## Pull by a person outside a combat (07 §2.2, §7.1–§7.4, E34): the pure rules behind the exploration's target and the
## opening ability — the bar of the controlled figure (party.json rt.bar by level and loadout, as BattleBridge builds it
## for the combat), which skills can open a combat (an ability aimed at the lead), the range of a slot (rt.range_cm,
## else the figure's reach_cm; centre distance ≤ range + the lead's radius, 07 §3.6.9), MP, the Tab order (±60° of the
## camera first, then by distance — 07 §7.4) and the state word of the target frame. The selection itself is never
## recorded; only the pull is (ExplorationScene.pull → the encounter command). Private helper of the exploration (no
## class_name, preloaded like encounter_rules.gd).

## Bar slots a pull can use: 1–4 and SHOW (the potion slot 6 never pulls, 07 §7.1).
const SLOTS: int = 5
const TAB_CONE_DEG: float = 60.0


## party.json rt.bar of `def` for `m`: slot (1..SLOTS) → skill id — the base skill of every slot reached by the level, a
## chosen variant (PartyMember.rt_loadout "2".."4") once its level is reached; FINALE entries stay out (the sim shows
## them only in a combat). The rule of BattleBridge._rt_bar without RtMods unlock_variant (no data use one;
## test_r5b_pull compares both). Staffeln (09 §8.3, ST1-D): `class_vars` (AbilityBook.class_variants: skill → slot,
## {} without a season) puts a chosen class ability on its slot like BattleBridge._rt_class_bar.
static func bar_slots(m: PartyMember, def: PartyMemberDef, class_vars: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {}
	if m == null or def == null:
		return out
	var variants: Dictionary = {}
	for b: Variant in (def.rt.get("bar", []) as Array):
		var e: Dictionary = b
		var slot: int = int(e.get("slot", 0))
		if int(e.get("level", 1)) > m.level or bool(e.get("finale", false)) or slot < 1 or slot > SLOTS:
			continue
		if bool(e.get("variant", false)):
			variants[str(e.get("skill", ""))] = slot
		elif not out.has(slot):
			out[slot] = str(e.get("skill", ""))
	for k: Variant in m.rt_loadout.keys():
		var sid: String = str(m.rt_loadout[k])
		var slot: int = str(k).to_int()
		if variants.has(sid) and int(variants[sid]) == slot:
			out[slot] = sid
		elif class_vars.has(sid) and int(class_vars[sid]) == slot and out.has(slot):
			out[slot] = sid
	return out


## Can `sk` open a combat as a pull? An ability aimed at an enemy (07 §2.2 "eine Fähigkeit … auf einen Anführer"):
## single_enemy, or all_enemies around a target point (rt.aoe.center "target"). Areas around the figure itself (they
## would hit nobody while the lead still walks in), heals, buffs and random targets: no.
static func is_opener(sk: SkillDef) -> bool:
	if sk == null:
		return false
	if sk.target == "single_enemy":
		return true
	var aoe: Variant = sk.rt.get("aoe", {})
	return sk.target == "all_enemies" and aoe is Dictionary and str((aoe as Dictionary).get("center", "self")) == "target"


## Range of `sk` in cm: rt.range_cm, else the figure's reach (party.json rt.reach_cm) — the rule of RtAbility.targets.
static func range_cm(sk: SkillDef, reach_cm: int) -> int:
	var r: int = int(sk.rt.get("range_cm", 0)) if sk != null else 0
	return r if r > 0 else reach_cm


## MP cost of `sk` (rt.mp, else mp_cost — RtAbility.mp_cost; no RtMods change the cost of an opener today).
static func mp_cost(sk: SkillDef) -> int:
	return maxi(0, int(sk.rt.get("mp", sk.mp_cost))) if sk != null else 0


## Why a pull with `sk` is refused ("" = it pulls): no_opener, range (centre distance `dist_cm` > range + the lead's
## radius), mp (the member's `mp` below the cost). The sim itself runs the opener without a range check (07 §3.4).
static func refusal(sk: SkillDef, mp: int, dist_cm: int, reach_cm: int, target_radius_cm: int) -> String:
	if sk == null:
		return "not_learned"
	if not is_opener(sk):
		return "no_opener"
	if dist_cm > range_cm(sk, reach_cm) + maxi(0, target_radius_cm):
		return "range"
	if mp < mp_cost(sk):
		return "mp"
	return ""


## Tab order outside a combat (07 §7.4): `cands` = [{"id": group id, "pos": Vector3}], seen from `from` — first the
## leads within ±60° of the camera's flat forward by distance, then the others by distance; ties by id.
static func tab_order(cands: Array[Dictionary], from: Vector3, cam_forward: Vector3) -> PackedStringArray:
	var cone: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	var fwd: Vector2 = Vector2(cam_forward.x, cam_forward.z)
	fwd = fwd.normalized() if fwd.length() > 0.0001 else Vector2(0, -1)
	var cos_lim: float = cos(deg_to_rad(TAB_CONE_DEG))
	for c: Dictionary in cands:
		var p: Vector3 = c["pos"]
		var d: Vector2 = Vector2(p.x - from.x, p.z - from.z)
		var e: Dictionary = {"id": str(c["id"]), "d": d.length()}
		if d.length() < 0.0001 or d.normalized().dot(fwd) >= cos_lim:
			cone.append(e)
		else:
			rest.append(e)
	var by_dist: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["d"]), float(b["d"])):
			return float(a["d"]) < float(b["d"])
		return str(a["id"]) < str(b["id"])
	cone.sort_custom(by_dist)
	rest.sort_custom(by_dist)
	var out: PackedStringArray = []
	for e: Dictionary in cone + rest:
		out.append(str(e["id"]))
	return out


## The next (or previous) id after `current` in `order`; wraps, an unknown current starts at the first / last.
static func next_in(order: PackedStringArray, current: String, forward: bool) -> String:
	if order.is_empty():
		return ""
	var i: int = order.find(current)
	if i < 0:
		return order[0] if forward else order[order.size() - 1]
	return order[posmod(i + (1 if forward else -1), order.size())]


## The state word of the target frame for an exploration state (EnemyActor) — what the lead is doing right now.
static func state_text(state: StringName, asleep: bool) -> String:
	if asleep:
		return "schläft"
	match state:
		&"DAZED":
			return "verdutzt"
		&"IDLE":
			return "ahnungslos"
		&"PATROL":
			return "auf Streife"
		&"ALERT":
			return "hat dich bemerkt"
		&"CHASE":
			return "verfolgt dich"
		&"RETURN":
			return "kehrt um"
	return ""
