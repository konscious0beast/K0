class_name PersonaBeats extends RefCounted
## Deterministic broadcast plans of the persona's story beats (08 §4.6, §4.7): which beat a hook gets on which floor.
## Pure, no randomness consumed: the plan follows from SeedUtil.derive(seed, "persona_plan", 0) % plans; the slots come
## from origins.json → plans. A plan's slots of floor F are used on floor F; a floor without own slots uses the
## pattern of floor 0. `n` is the ordinal of the hook on the floor (the n-th first safe-room visit, the n-th boss
## won; game over: the n-th game over), n = 0 = every other ordinal. `every` k: the slot only on every k-th floor
## (game over: every k-th time), else the `else` slot.
## Slots → M.O.D. tags: card → persona_intro:<org> (persona_intro:custom for "Anderes …" without a match), line →
## the hook's general line (persona_<hook>[:<org|hob>]), rival:<case> → persona_beat_rival:<case>, greeting →
## persona_beat_greeting:<gr id>, sponsor:<case> → persona_beat_sponsor:<case>, gag:<n> → persona_gag:<gag id>:<n>
## (without a gag: the hook's line), marotte → persona_marotte.

## The hooks whose "line" slot has a per-origin (or per-hobby) variant tag.
const ORIGIN_VARIANTS: PackedStringArray = ["boss_won", "floor_end", "game_over"]
const ALLROUND: String = "org_allround"


## The plan id of a run seed ("" without plans).
static func plan_for(data: GameData, seed: int) -> String:
	var plans: Array = data.persona_plans() if data != null else []
	if plans.is_empty():
		return ""
	return str((plans[posmod(SeedUtil.derive(seed, "persona_plan", 0), plans.size())] as Dictionary).get("id", ""))


## The M.O.D. tag of hook `hook` (ordinal `ordinal` on floor `floor_index`) for persona `p` in plan `plan_id`
## ("" = no persona line): the first of tags_for.
static func tag_for(data: GameData, p: PersonaProfile, plan_id: String, floor_index: int, hook: StringName,
		ordinal: int) -> String:
	var tags: PackedStringArray = tags_for(data, p, plan_id, floor_index, hook, ordinal)
	return tags[0] if not tags.is_empty() else ""


## Every tag of one hook event in plan order (the intro: the card, then its beat; other hooks: at most one).
static func tags_for(data: GameData, p: PersonaProfile, plan_id: String, floor_index: int, hook: StringName,
		ordinal: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if data == null:
		return out
	var prof: PersonaProfile = p if p != null else PersonaProfile.canon(data)
	for slot: String in slots_for(data, plan_id, floor_index, hook, ordinal):
		var tag: String = slot_tag(prof, String(hook), slot)
		if tag != "" and not out.has(tag):
			out.append(tag)
	return out


## The slot names of one hook event (after `every` / `else`), plan order.
static func slots_for(data: GameData, plan_id: String, floor_index: int, hook: StringName,
		ordinal: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var slots: Array = _plan_slots(data, plan_id)
	var floor_set: int = floor_index if _has_floor(slots, floor_index) else 0
	var h: String = String(hook)
	var exact: Array = []
	var other: Array = []
	for s: Variant in slots:
		var d: Dictionary = s
		if JsonUtil.to_int(d.get("floor", -1)) != floor_set or str(d.get("hook", "")) != h:
			continue
		var n: int = JsonUtil.to_int(d.get("n", 0))
		if n == ordinal and ordinal > 0:
			exact.append(d)
		elif n == 0:
			other.append(d)
	for d: Dictionary in (exact if not exact.is_empty() else other):
		var slot: String = str(d.get("slot", ""))
		var every: int = JsonUtil.to_int(d.get("every", 0))
		if every >= 2:
			var k: int = ordinal if h == "game_over" else floor_index
			if posmod(k, every) != 0:
				slot = str(d.get("else", ""))
		if slot != "":
			out.append(slot)
	return out


## The M.O.D. tag of one slot for persona `p` at hook `hook` ("" = no line: unknown slot, no card outside the intro).
static func slot_tag(p: PersonaProfile, hook: String, slot: String) -> String:
	match slot:
		"card":
			if p.origin == ALLROUND and p.job_text != "":
				return "persona_intro:custom"
			return "persona_intro:" + p.origin
		"line":
			return line_tag(p, hook)
		"greeting":
			return "persona_beat_greeting:" + str(p.beats.get("greeting", PersonaProfile.COLLEAGUES))
		"marotte":
			return "persona_marotte"
	if slot.begins_with("rival:"):
		return "persona_beat_rival:" + slot.trim_prefix("rival:")
	if slot.begins_with("sponsor:"):
		return "persona_beat_sponsor:" + slot.trim_prefix("sponsor:")
	if slot.begins_with("gag:"):
		var gag: String = str(p.beats.get("gag", ""))
		return "persona_gag:%s:%s" % [gag, slot.trim_prefix("gag:")] if gag != "" else line_tag(p, hook)
	return ""


## The general persona line of a hook: persona_<hook> with the origin (boss_won, floor_end, game_over) or hobby
## (safe_room) as variant; the intro's line is the card; summary and floor_start have none.
static func line_tag(p: PersonaProfile, hook: String) -> String:
	match hook:
		"intro":
			return slot_tag(p, hook, "card")
		"first_chest":
			return "persona_first_chest"
		"safe_room":
			return "persona_safe_room:" + p.hobby if p.hobby != "" else "persona_safe_room"
		"summary", "floor_start":
			return ""
	if ORIGIN_VARIANTS.has(hook):
		return "persona_%s:%s" % [hook, p.origin]
	return ""


static func _plan_slots(data: GameData, plan_id: String) -> Array:
	for p: Variant in data.persona_plans():
		if str((p as Dictionary).get("id", "")) == plan_id:
			return (p as Dictionary).get("slots", []) as Array
	return []


static func _has_floor(slots: Array, floor_index: int) -> bool:
	for s: Variant in slots:
		if JsonUtil.to_int((s as Dictionary).get("floor", -1)) == floor_index:
			return true
	return false
