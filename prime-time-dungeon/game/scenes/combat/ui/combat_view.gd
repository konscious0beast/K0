extends RefCounted
## Display model of the real-time combat HUD (07 §8): every frame the HUD reads its states from the PURE RtSim queries
## (bar, can_use, cooldown_left/total, gcd_left/total, item_cd_*, items_left, cast_progress, suggest,
## partner_special_skill) and the unit snapshots — no event bookkeeping for states (07 §8.2). Static functions only,
## no node, no autoload except DB for names → headless tests read exactly what the HUD draws. Private R3 helper.

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")

const SLOT_SHOW: int = 5
const SLOT_POTION: int = 6
const TICKS_PER_SEC: int = 30
## Reasons that mean "the unit could act, only this skill cannot right now" (state tints, never a hidden slot).
const ENEMY_TARGETS: PackedStringArray = ["single_enemy", "all_enemies", "random_enemy"]
const ALLY_TARGETS: PackedStringArray = ["single_ally", "all_allies", "single_ally_ko"]
## Whom a status of a skill's rt block lands on (RtVocab.STATUS_TO; "target" needs no word).
const STATUS_TO_NAMES: Dictionary = {"self": "selbst", "all_enemies": "alle Gegner", "all_allies": "ganze Party"}


## The controlled unit (null when unknown).
static func controlled(sim: RtSim) -> RtUnit:
	return sim.unit(sim.controlled_id()) if sim != null else null


## First living (or, failing that, any) party unit that is not controlled: the AI partner (07 §5.1).
static func partner(sim: RtSim) -> RtUnit:
	if sim == null:
		return null
	var ctl: String = sim.controlled_id()
	var fallback: RtUnit = null
	for u: RtUnit in sim.units():
		if u.side != Combatant.Side.PARTY or u.id == ctl:
			continue
		if u.hp > 0:
			return u
		if fallback == null:
			fallback = u
	return fallback


static func party(sim: RtSim) -> Array[RtUnit]:
	var out: Array[RtUnit] = []
	if sim == null:
		return out
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.PARTY:
			out.append(u)
	return out


static func enemies(sim: RtSim, alive_only: bool = true) -> Array[RtUnit]:
	var out: Array[RtUnit] = []
	if sim == null:
		return out
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.ENEMY and not u.left_battle and (not alive_only or u.hp > 0):
			out.append(u)
	return out


## The living boss (first by unit order), null outside boss fights.
static func boss(sim: RtSim) -> RtUnit:
	for u: RtUnit in enemies(sim, false):
		if u.is_boss:
			return u
	return null


## Bar slot → id as RtSim.bar() reports it, keys normalised to int, slots 1..6 in order.
static func bar_entries(sim: RtSim, unit_id: String) -> Dictionary:
	var out: Dictionary = {}
	if sim == null or unit_id == "":
		return out
	var raw: Dictionary = sim.bar(unit_id)
	for k: Variant in raw.keys():
		var slot: int = int(str(k))
		var id: String = str(raw[k])
		if slot >= 1 and slot <= 6 and id != "":
			out[slot] = id
	return out


static func is_item_id(id: String) -> bool:
	return id.begins_with("itm_")


## Display name of an item id (the id itself when the data does not know it).
static func _item_name(id: String) -> String:
	if CombatStyle.gd().has_id("items", id):
		return TranslationServer.translate(CombatStyle.gd().item(id).name)
	return id


## Skill def behind a bar entry (items: their use_skill), null if unknown.
static func skill_of(id: String) -> SkillDef:
	if is_item_id(id):
		if not CombatStyle.gd().has_id("items", id):
			return null
		var it: ItemDef = CombatStyle.gd().item(id)
		if it.use_skill != "" and CombatStyle.gd().has_id("skills", it.use_skill):
			return CombatStyle.gd().skill(it.use_skill)
		return null
	return CombatStyle.gd().skill(id) if CombatStyle.gd().has_id("skills", id) else null


static func skill_mp(def: SkillDef) -> int:
	if def == null:
		return 0
	if not def.rt.is_empty() and def.rt.has("mp"):
		return int(def.rt["mp"])
	return def.mp_cost


static func uses_gcd(def: SkillDef) -> bool:
	return def != null and (def.rt.is_empty() or bool(def.rt.get("gcd", true)))


## Real-time text of a skill (R5b-2a text pass): its description without a rule part that counts CTB turns ("Sie
## ziehen alle Blicke auf sich: Provoziert und Gepanzert für 3 Züge." keeps the part before the colon — the data keep
## the CTB text until they are baked, R5b part 2) plus one line with the statuses of its rt block in seconds, e.g.
## "Wirkung: Provoziert (alle Gegner) 4 s · Gepanzert (selbst) 6 s".
static func skill_text(def: SkillDef) -> String:
	if def == null:
		return ""
	var lines: PackedStringArray = []
	var desc: String = TranslationServer.translate(def.desc)
	if desc.contains(" Züge") or desc.contains(" Zug."):
		var cut: int = desc.rfind(": ")
		desc = desc.substr(0, cut) + "." if cut > 0 else ""
	if desc != "":
		lines.append(desc)
	var parts: PackedStringArray = []
	for v: Variant in def.rt.get("statuses", []) as Array:
		var s: Dictionary = (v as Dictionary) if v is Dictionary else {}
		var sid: String = str(s.get("id", ""))
		if not CombatStyle.gd().has_id("statuses", sid):
			continue
		var st: StatusDef = CombatStyle.gd().status(sid)
		var ms: int = int(s.get("ms", 0)) if int(s.get("ms", 0)) > 0 else int(st.rt.get("default_ms", 0))
		var text: String = TranslationServer.translate(st.name)
		var to: String = str(STATUS_TO_NAMES.get(str(s.get("to", "target")), ""))
		if to != "":
			text += " (%s)" % to
		if ms > 0:
			text += " " + seconds_text(ms)
		var pm: int = int(s.get("chance_pm", 1000))
		if pm < 1000:
			text += " (%s %%)" % _decimal(pm)
		parts.append(text)
	if not parts.is_empty():
		lines.append("Wirkung: " + " · ".join(parts))
	return "\n".join(lines)


## 4000 ms → "4 s", 1500 → "1,5 s" (German decimal comma).
static func seconds_text(ms: int) -> String:
	return "%s s" % _decimal(ms / 100)


## Tenths → "4" / "1,5": 40 → "4", 15 → "1,5".
static func _decimal(tenths: int) -> String:
	return str(tenths / 10) if tenths % 10 == 0 else "%d,%d" % [tenths / 10, tenths % 10]


## True if `skill_id` is the FINALE entry of slot 5 of party member `def_id` (party.json rt.bar "finale", 07 §4.1;
## RtSim.bar puts it into slot 5 while the condition holds). Without an rt.bar entry: the show tag "finisher".
static func is_finale(def_id: String, skill_id: String) -> bool:
	if CombatStyle.gd().has_id("party", def_id):
		var bar: Variant = CombatStyle.gd().party_member(def_id).rt.get("bar", [])
		if bar is Array:
			for e: Variant in (bar as Array):
				if e is Dictionary and str((e as Dictionary).get("skill", "")) == skill_id:
					return bool((e as Dictionary).get("finale", false))
	var def: SkillDef = CombatStyle.gd().skill(skill_id) if CombatStyle.gd().has_id("skills", skill_id) else null
	return def != null and def.show_tags.has("finisher")


## The target a press of this skill sends: the current target when its side fits the skill, else "" (the sim picks
## the smart target, 07 §4.4).
static func target_for(sim: RtSim, u: RtUnit, def: SkillDef) -> String:
	if u == null or def == null or u.target_id == "":
		return ""
	var t: RtUnit = sim.unit(u.target_id)
	if t == null:
		return ""
	if ENEMY_TARGETS.has(def.target):
		return t.id if t.side != u.side and t.hp > 0 else ""
	if ALLY_TARGETS.has(def.target):
		return t.id if t.side == u.side else ""
	return ""


## Display state of every visible slot of the controlled unit (07 §8.2). ctx: {"assist": bool, "hype": float}.
## Per slot: slot, id, is_item, icon, name, mp, cd_left, cd_total, gcd_left, gcd_total, reason, no_mp, out_of_range,
## no_target, queued, assist, show, finale, count, max_count.
static func slots(sim: RtSim, ctx: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u: RtUnit = controlled(sim)
	if u == null:
		return out
	var entries: Dictionary = bar_entries(sim, u.id)
	var suggestion: String = sim.suggest(u.id) if bool(ctx.get("assist", false)) else ""
	var gcd_l: int = sim.gcd_left(u.id)
	var gcd_t: int = sim.gcd_total(u.id)
	var keys: Array = entries.keys()
	keys.sort()
	for k: Variant in keys:
		var slot: int = int(k)
		var id: String = str(entries[k])
		var item: bool = is_item_id(id)
		var def: SkillDef = skill_of(id)
		var s: Dictionary = {"slot": slot, "id": id, "is_item": item, "show": slot == SLOT_SHOW,
			"finale": slot == SLOT_SHOW and not item and is_finale(u.def_id, id)}
		s["icon"] = CombatStyle.item_icon(id) if item else CombatStyle.skill_icon(def)
		s["name"] = _item_name(id) if item else (TranslationServer.translate(def.name) if def != null else id)
		s["mp"] = 0 if item else skill_mp(def)
		var target: String = target_for(sim, u, def)
		var reason: String = sim.can_use_item(u.id, id, target) if item else sim.can_use(u.id, id, target)
		s["reason"] = reason
		if item:
			s["cd_left"] = sim.item_cd_left()
			s["cd_total"] = sim.item_cd_total()
			s["gcd_left"] = 0
			s["gcd_total"] = 0
			s["count"] = sim.items_left()
			s["max_count"] = _item_max(sim)
		else:
			s["cd_left"] = sim.cooldown_left(u.id, id)
			s["cd_total"] = sim.cooldown_total(u.id, id)
			var g: bool = uses_gcd(def)
			s["gcd_left"] = gcd_l if g else 0
			s["gcd_total"] = gcd_t if g else 0
			s["count"] = -1
			s["max_count"] = -1
		s["no_mp"] = reason == "mp"
		s["out_of_range"] = reason == "range" or reason == "los"
		s["no_target"] = reason == "target" or reason == "target_hp"
		var q: Dictionary = u.queued
		s["queued"] = not q.is_empty() and (str(q.get("skill", "")) == id or str(q.get("item", "")) == id)
		s["assist"] = suggestion != "" and suggestion == id
		out.append(s)
	return out


static func _item_max(sim: RtSim) -> int:
	var b: RtBalance = sim.bal if sim != null else null              # the sim's balance (setup.balance or the data)
	if b == null and sim != null and sim.setup != null:
		b = sim.setup.balance
	return b.i("ITEM_MAX_PER_COMBAT") if b != null and b.i("ITEM_MAX_PER_COMBAT") > 0 else 3


## 0..1 remaining of a running cooldown / GCD (0 when none).
static func ratio(left: int, total: int) -> float:
	if left <= 0 or total <= 0:
		return 0.0
	return clampf(float(left) / float(total), 0.0, 1.0)


## Statuses of a unit for a status row: [{"id", "def", "icon", "color", "left" (ticks, -1 = until combat end),
## "total", "stacks", "buff"}], buffs before debuffs, then by remaining time; hidden statuses left out (07 §8.4).
static func statuses(sim: RtSim, u: RtUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if u == null:
		return out
	var now: int = sim.tick() if sim != null else 0
	for st: StatusEffect in u.statuses:
		var def: StatusDef = st.def
		if def == null or def.has_flag("hidden") or (def.rt.has("flags") and (def.rt["flags"] as Array).has("hidden")):
			continue
		var left: int = -1
		var total: int = 0
		var stacks: int = 1
		if st is RtStatus:
			var rs: RtStatus = st
			left = maxi(0, rs.ends_at - now) if rs.ends_at >= 0 else -1
			total = maxi(1, rs.ends_at - rs.applied_at) if rs.ends_at >= 0 else 0
			stacks = rs.stacks
		out.append({"id": def.id, "def": def, "icon": CombatStyle.status_icon(def),
			"color": CombatStyle.status_color(def), "left": left, "total": total, "stacks": stacks,
			"buff": def.kind == "buff"})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["buff"]) != bool(b["buff"]):
			return bool(a["buff"])
		var la: int = int(a["left"]) if int(a["left"]) >= 0 else 1 << 30
		var lb: int = int(b["left"]) if int(b["left"]) >= 0 else 1 << 30
		if la != lb:
			return la < lb
		return str(a["id"]) < str(b["id"]))
	return out


## Cast state of a unit: {} when it casts nothing, else {"skill", "name", "elapsed", "total", "ratio", "tier"
## (&"worthy" | &"open" | &"locked" | &"party"), "channel", "item"} — 07 §6.2 / §8.3.
static func cast(sim: RtSim, u: RtUnit) -> Dictionary:
	if sim == null or u == null or u.cast.is_empty():
		return {}
	var pr: Vector2i = sim.cast_progress(u.id)
	if pr.y <= 0:
		var s0: int = int(u.cast.get("start", 0))
		var e0: int = int(u.cast.get("end", 0))
		pr = Vector2i(clampi(sim.tick() - s0, 0, maxi(0, e0 - s0)), maxi(0, e0 - s0))
	if pr.y <= 0:
		return {}
	var sid: String = str(u.cast.get("skill", ""))
	var item_id: String = str(u.cast.get("item", ""))
	var name: String = sid
	if str(u.cast.get("kind", "ability")) == "item" and CombatStyle.gd().has_id("items", item_id):
		name = TranslationServer.translate(CombatStyle.gd().item(item_id).name)
	elif CombatStyle.gd().has_id("skills", sid):
		name = TranslationServer.translate(CombatStyle.gd().skill(sid).name)
	var tier: StringName = &"party"
	if u.side == Combatant.Side.ENEMY:
		if bool(u.cast.get("worthy", false)) and bool(u.cast.get("interruptible", false)):
			tier = &"worthy"
		elif bool(u.cast.get("interruptible", false)):
			tier = &"open"
		else:
			tier = &"locked"
	return {"skill": sid, "name": name, "elapsed": pr.x, "total": pr.y,
		"ratio": clampf(float(pr.x) / float(pr.y), 0.0, 1.0), "tier": tier,
		"channel": bool(u.cast.get("channel", false)), "item": item_id,
		"left": maxi(0, pr.y - pr.x)}


## How many living enemies attack `unit_id` right now (aggro counter "×2", 07 §8.4).
static func attackers(sim: RtSim, unit_id: String) -> int:
	var n: int = 0
	for e: RtUnit in enemies(sim):
		if e.target_id == unit_id or (e.fixate_id == unit_id and e.fixate_until > sim.tick()):
			n += 1
	return n


## Party colour of the unit an enemy attacks ("" side → transparent), for the threat dot (07 §8.5).
static func threat_color(sim: RtSim, e: RtUnit) -> Color:
	if e == null or e.target_id == "":
		return Color(0, 0, 0, 0)
	var t: RtUnit = sim.unit(e.target_id)
	if t == null or t.side != Combatant.Side.PARTY:
		return Color(0, 0, 0, 0)
	return CombatStyle.member_color(t.def_id)


## Number of boss phases (rt.phases) and the current one from 1 (07 §8.4 Phasen-Rauten).
static func boss_phases(b: RtUnit) -> Vector2i:
	if b == null or not CombatStyle.gd().has_id("enemies", b.def_id):
		return Vector2i(1, 1)
	var phases: Variant = CombatStyle.gd().enemy(b.def_id).rt.get("phases", [])
	var n: int = (phases as Array).size() if phases is Array else 0
	return Vector2i(clampi(b.phase + 1, 1, maxi(1, n)), maxi(1, n))


## Ticks until the boss enrage (rt.enrage.at_ms), -1 without one or once it started (07 §8.4: shown in the last
## minute).
static func enrage_left(sim: RtSim, b: RtUnit) -> int:
	if b == null or not CombatStyle.gd().has_id("enemies", b.def_id):
		return -1
	var en: Variant = CombatStyle.gd().enemy(b.def_id).rt.get("enrage", {})
	if not (en is Dictionary) or not (en as Dictionary).has("at_ms"):
		return -1
	var at: int = int((en as Dictionary)["at_ms"]) * 3 / 100
	var left: int = at - sim.tick()
	return left if left > 0 else -1


## The partner's Partner-Spezial (07 §4.1): {"unit", "skill", "icon", "cd_left", "cd_total", "reason"}, {} when the
## button is hidden — no partner skill yet, tutorial (never, 07 §2.13), no living partner.
static func partner_special(sim: RtSim) -> Dictionary:
	var p: RtUnit = partner(sim)
	if p == null or sim.setup == null or sim.setup.tutorial:
		return {}
	var sid: String = sim.partner_special_skill(p.id)
	if sid == "":
		return {}
	var def: SkillDef = CombatStyle.gd().skill(sid) if CombatStyle.gd().has_id("skills", sid) else null
	var nm: String = TranslationServer.translate(def.name) if def != null else sid
	return {"unit": p.id, "skill": sid, "icon": CombatStyle.skill_icon(def), "name": nm,
		"cd_left": sim.cooldown_left(p.id, sid), "cd_total": sim.cooldown_total(p.id, sid),
		"reason": sim.can_use(p.id, sid, "") if p.hp > 0 else "dead", "ko": p.hp <= 0}


## Taktik-Chip from level 3 of the partner, never in the tutorial (07 §5.2, §8.1, E28).
static func tactic_visible(sim: RtSim) -> bool:
	var p: RtUnit = partner(sim)
	return p != null and sim.setup != null and not sim.setup.tutorial and p.level >= 3


## The partner's preset / switches as the sim knows them (RtSetup.presets for the start, RtUnit.preset/toggles once
## the sim set them).
static func partner_preset(sim: RtSim) -> Dictionary:
	var p: RtUnit = partner(sim)
	if p == null:
		return {"preset": "support", "tog": RtVocab.RT_TOGGLE_DEFAULTS.duplicate()}
	var preset: String = p.preset
	var tog: Dictionary = p.toggles.duplicate()
	if sim.setup != null and sim.setup.presets.has(p.id):
		var d: Dictionary = sim.setup.presets[p.id]
		if preset == "":
			preset = str(d.get("preset", ""))
		if tog.is_empty():
			tog = (d.get("tog", {}) as Dictionary).duplicate()
	if preset == "":
		preset = "support" if p.def_id == "mopsula" else "attack"
	for k: String in RtVocab.RT_TOGGLES:
		if not tog.has(k):
			tog[k] = bool(RtVocab.RT_TOGGLE_DEFAULTS[k])
	return {"preset": preset, "tog": tog}
