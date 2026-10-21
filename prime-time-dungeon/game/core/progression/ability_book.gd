class_name AbilityBook extends RefCounted
## The ability book (09 §8.3, ST1-D): every ability a figure has or will have, by bar slot — the figure's bar
## (party.json rt.bar and rt.context, 07 §4.1–4.3: levels 1–9, unchanged) and, from the Recall on, the bar of its class
## (classes.json rt.bar): the signature at the Recall (row level 1), then one ability on each of the levels 12, 17, 22,
## 27, 32, every one a variant of a slot (1–4 or the SHOW); on the levels of rt.ranks (37/42/47) Rang II–IV raise the
## power of every class ability (RtMods skill_pm with the source class:<id>, 07 §9.5). Before the Recall the book
## previews the abilities of all four classes of the figure. The bar stays 4 + SHOW + potion (07): what sits on a slot
## the loadout decides (PartyMember.rt_loadout; RunRules.loadout_refusal asks variant_level).
## Static and pure (core): reads GameState / PartyMember / GameData only. The class bar acts only in a season
## (state.season != null, 09 V-4) — without one every function here answers like the party bar alone.

const SOURCE_PARTY: String = "party"
## The kinds of a row: "" (the base ability of its slot), "variant", "context" (Mopsula's slot 2 on a KO'd target),
## "finale" (slot 5 against a weak target) — party rows; a class row keeps "variant" / "finale" and names its class in
## "source".
const KINDS: PackedStringArray = ["", "variant", "context", "finale"]
## Rank names of a class (Rang I = the abilities themselves).
const RANK_NAMES: PackedStringArray = ["", "I", "II", "III", "IV"]


## The rows of the book of `member_id`: the party bar (+ context) and the class bar of `class_id` ("" = none) —
## [{slot, skill, level, kind, source}] sorted by slot, the base ability first, then by level and skill.
static func rows(data: GameData, member_id: String, class_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data == null or not data.has_id("party", member_id):
		return out
	var prt: Dictionary = data.party_member(member_id).rt
	for b: Variant in (prt.get("bar", []) as Array):
		out.append(_row(b as Dictionary, SOURCE_PARTY, ""))
	for c: Variant in (prt.get("context", []) as Array):
		out.append(_row(c as Dictionary, SOURCE_PARTY, "context"))
	if class_id != "" and data.has_id("classes", class_id):
		for b: Variant in (data.class_def(class_id).rt.get("bar", []) as Array):
			out.append(_row(b as Dictionary, class_id, ""))
	out.sort_custom(_before)
	return out


## The rows of the member's book right now: the class rows only in a season and with a class.
static func rows_of(state: GameState, data: GameData, member: PartyMember) -> Array[Dictionary]:
	if member == null:
		var none: Array[Dictionary] = []
		return none
	return rows(data, member.id, member.class_id if _season(state) else "")


## Is `row` (of rows()) learned by `member`: a party row from its level, a class row only for the member's class —
## the signature (level 1) at the Recall, every other from its level.
static func is_learned(member: PartyMember, row: Dictionary) -> bool:
	if member == null:
		return false
	var source: String = str(row.get("source", SOURCE_PARTY))
	if source != SOURCE_PARTY and source != member.class_id:
		return false
	return int(row.get("level", 1)) <= member.level or (source != SOURCE_PARTY and int(row.get("level", 1)) <= 1)


## The class variants `member` has learned (only in a season): skill id → slot.
static func class_variants(state: GameState, data: GameData, member: PartyMember) -> Dictionary:
	var out: Dictionary = {}
	if not _season(state) or member == null or member.class_id == "" or data == null \
			or not data.has_id("classes", member.class_id):
		return out
	for b: Variant in (data.class_def(member.class_id).rt.get("bar", []) as Array):
		var r: Dictionary = _row(b as Dictionary, member.class_id, "")
		if str(r["kind"]) == "variant" and is_learned(member, r):
			out[str(r["skill"])] = int(r["slot"])
	return out


## The level a variant `skill` needs on `slot` for `member` (RunRules.loadout_refusal): a party variant of that slot
## its bar level; in a season a class variant of the member's class its class level (1 = the Recall); -1 when it is no
## variant of that slot.
static func variant_level(state: GameState, data: GameData, member: PartyMember, slot: int, skill: String) -> int:
	if member == null or data == null:
		return -1
	for r: Dictionary in rows_of(state, data, member):
		if str(r["kind"]) == "variant" and int(r["slot"]) == slot and str(r["skill"]) == skill:
			return int(r["level"])
	return -1


## The skills of the class bar of `class_id` (data order).
static func class_skills(data: GameData, class_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if data == null or not data.has_id("classes", class_id):
		return out
	for b: Variant in (data.class_def(class_id).rt.get("bar", []) as Array):
		var sid: String = str((b as Dictionary).get("skill", ""))
		if sid != "" and not out.has(sid):
			out.append(sid)
	return out


## The class rank of `member` (09 §8.3): Vector2i(rank 1–4, power ‰) — 1 / 1000 without a rank (or a class, or a
## season); Rang II–IV from the levels of classes.json rt.ranks.
static func rank_of(state: GameState, data: GameData, member: PartyMember) -> Vector2i:
	var out: Vector2i = Vector2i(1, 1000)
	if not _season(state) or member == null or member.class_id == "" or data == null \
			or not data.has_id("classes", member.class_id):
		return out
	var ranks: Array = data.class_def(member.class_id).rt.get("ranks", []) as Array
	for i in ranks.size():
		var r: Dictionary = ranks[i]
		if int(r.get("level", 99)) <= member.level:
			out = Vector2i(i + 2, int(r.get("pm", 1000)))
	return out


## The next rank of `member` (Vector2i(rank, level); (0, 0) at Rang IV or without a class).
static func next_rank(data: GameData, member: PartyMember) -> Vector2i:
	if member == null or member.class_id == "" or data == null or not data.has_id("classes", member.class_id):
		return Vector2i.ZERO
	var ranks: Array = data.class_def(member.class_id).rt.get("ranks", []) as Array
	for i in ranks.size():
		var lv: int = int((ranks[i] as Dictionary).get("level", 99))
		if lv > member.level:
			return Vector2i(i + 2, lv)
	return Vector2i.ZERO


## The RtMods of the member's class rank (07 §9.5, source class:<id>; BattleBridge, after species, before talents):
## one skill_pm "power" per ability of the class bar while a rank II–IV stands; [] otherwise.
static func rank_mods(state: GameState, data: GameData, member: PartyMember, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rank: Vector2i = rank_of(state, data, member)
	if rank.x <= 1 or rank.y == 1000:
		return out
	for sid: String in class_skills(data, member.class_id):
		out.append({"src": "class:" + member.class_id, "op": "skill_pm", "unit": uid, "skill": sid, "field": "power",
			"pm": rank.y})
	return out


## The abilities levels old_level+1 … new_level unlock for `member` (the banner "Neue Fähigkeit", 09 §8.3): party
## rows of these levels and — for its class, not the signature (that one comes with the Recall) — class rows.
static func new_between(member: PartyMember, data: GameData, old_level: int, new_level: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if member == null or data == null:
		return out
	for r: Dictionary in rows(data, member.id, member.class_id):
		var lv: int = int(r["level"])
		var src: String = str(r["source"])
		if lv <= old_level or lv > new_level or (src != SOURCE_PARTY and lv <= 1):
			continue
		if not out.has(str(r["skill"])):
			out.append(str(r["skill"]))
	return out


## The "Klassen-Vorschau" before the Recall (09 §8.3): every class of the figure in data order with its rows and ranks —
## [{"class": id, "name", "rows": [...], "ranks": [{level, pm}]}].
static func preview(data: GameData, member_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data == null:
		return out
	for c: ClassDef in data.all_classes():
		if not c.is_for(member_id):
			continue
		var list: Array[Dictionary] = []
		for b: Variant in (c.rt.get("bar", []) as Array):
			list.append(_row(b as Dictionary, c.id, ""))
		list.sort_custom(_before)
		out.append({"class": c.id, "name": c.name, "rows": list, "ranks": (c.rt.get("ranks", []) as Array).duplicate()})
	return out


## The base ability of `slot` on the figure's bar (party.json rt.bar, not a variant or FINALE); "" if none.
static func base_skill(data: GameData, member_id: String, slot: int) -> String:
	if data == null or not data.has_id("party", member_id):
		return ""
	for b: Variant in (data.party_member(member_id).rt.get("bar", []) as Array):
		var e: Dictionary = b
		if int(e.get("slot", 0)) == slot and not bool(e.get("variant", false)) and not bool(e.get("finale", false)):
			return str(e.get("skill", ""))
	return ""


# --- private ---------------------------------------------------------------------------------------------------------

static func _season(state: GameState) -> bool:
	return state != null and state.season != null


static func _row(e: Dictionary, source: String, kind: String) -> Dictionary:
	var k: String = kind
	if k == "":
		k = "finale" if bool(e.get("finale", false)) else ("variant" if bool(e.get("variant", false)) else "")
	return {"slot": int(e.get("slot", 0)), "skill": str(e.get("skill", "")), "level": int(e.get("level", 1)),
		"kind": k, "source": source}


## Slot, then the base ability, then party before class, then level, then skill id.
static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["slot"]) != int(b["slot"]):
		return int(a["slot"]) < int(b["slot"])
	var ab: bool = str(a["kind"]) == ""
	var bb: bool = str(b["kind"]) == ""
	if ab != bb:
		return ab
	var ap: bool = str(a["source"]) == SOURCE_PARTY
	var bp: bool = str(b["source"]) == SOURCE_PARTY
	if ap != bp:
		return ap
	if int(a["level"]) != int(b["level"]):
		return int(a["level"]) < int(b["level"])
	return str(a["skill"]) < str(b["skill"])
