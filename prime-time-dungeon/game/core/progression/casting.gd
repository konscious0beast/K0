class_name Casting extends RefCounted
## Casting from floor 3 (06 §3, 02_TECH §6.5): each party member picks a species ("Wer bist du?", species.json) and
## its first specialization ("Was kannst du?", the classes of classes.json). The players see the round as the
## "Recall" (08 F-7; code names Casting / casting stay): its screen is scenes/ui/recall.tscn (06 §3.5), opened in the
## safe rooms of floor 3 and later. Static and pure (core); the choice is the recorded command
## {"t": "casting", "member", "species", "class"} (Game.choose_casting).
##
## Rules (06 §3.1 / §3.6):
##   - only in a safe room, on a floor >= the species' and the class' min_floor (3)
##   - the first casting of a member works in any safe room of such a floor (nobody misses it by skipping a room)
##   - species: freely changeable during the safe-room visit of the casting, fixed afterwards ("Vertrag ist Vertrag")
##   - specialization: changeable during the visit it was chosen in, and once per later floor in the first safe room
##     of that floor ("Umschulung")
## Bookkeeping in PartyMember.casting: {"floor", "visit"} of the species choice, {"class_floor", "class_visit"} of the
## class choice (visit = FloorRun.safe_room_visits, which counts every safe-room entry of the floor).
## Stats: Progression.total_stats applies class stat_mult, then species stat_mult (round half up each).

const REASONS: PackedStringArray = ["floor_too_low", "not_for_member", "unknown_species", "unknown_class", "locked",
	"not_in_safe_room"]


## {"species": PackedStringArray (spc_original first, then file order), "classes": PackedStringArray (file order)} —
## everything the member may ever choose (check() says whether it is possible right now).
static func options(state: GameState, data: GameData, member_id: String) -> Dictionary:
	var out: Dictionary = {"species": PackedStringArray(), "classes": PackedStringArray()}
	if state == null or data == null or state.member(member_id) == null:
		return out
	var spc: PackedStringArray = []
	if data.has_id("species", SpeciesDef.ORIGINAL):
		spc.append(SpeciesDef.ORIGINAL)
	for s: SpeciesDef in data.all_species():
		if s.id != SpeciesDef.ORIGINAL and s.is_for(member_id):
			spc.append(s.id)
	var cls: PackedStringArray = []
	for c: ClassDef in data.all_classes():
		if c.is_for(member_id):
			cls.append(c.id)
	out["species"] = spc
	out["classes"] = cls
	return out


## "" = allowed, else one of REASONS.
static func check(state: GameState, data: GameData, member_id: String, species_id: String, class_id: String) -> String:
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null or data == null:
		return "not_for_member"
	if not data.has_id("species", species_id):
		return "unknown_species"
	if not data.has_id("classes", class_id):
		return "unknown_class"
	var spc: SpeciesDef = data.species_def(species_id)
	var cls: ClassDef = data.class_def(class_id)
	if not spc.is_for(member_id) or not cls.is_for(member_id):
		return "not_for_member"
	var fr: FloorRun = state.floor_run
	var floor_index: int = fr.index if fr != null else 0
	if floor_index < spc.min_floor or floor_index < cls.min_floor:
		return "floor_too_low"
	if not RunRules.in_safe_room(state):
		return "not_in_safe_room"
	if m.casting.is_empty():
		return ""                                            # first casting: any safe room
	var visit: int = fr.safe_room_visits
	if species_id != m.species_id and not _same_visit(m, "floor", "visit", floor_index, visit):
		return "locked"
	if class_id != m.class_id and not _same_visit(m, "class_floor", "class_visit", floor_index, visit):
		var retrain: bool = int(m.casting.get("class_floor", 0)) < floor_index \
			and not fr.visited_safe_rooms.is_empty() and String(fr.location) == fr.visited_safe_rooms[0]
		if not retrain:
			return "locked"
	return ""


## Applies an allowed choice: species / class, bookkeeping, class skills up to the member's level; HP / MP follow the
## new maxima like a level-up. false (nothing changes) if check() refuses.
static func choose(state: GameState, data: GameData, member_id: String, species_id: String, class_id: String) -> bool:
	if check(state, data, member_id, species_id, class_id) != "":
		return false
	var m: PartyMember = state.member(member_id)
	var fr: FloorRun = state.floor_run
	var before: StatBlock = Progression.total_stats(m, data)
	if species_id != m.species_id or not m.casting.has("floor"):
		m.casting["floor"] = fr.index
		m.casting["visit"] = fr.safe_room_visits
	if class_id != m.class_id or not m.casting.has("class_floor"):
		m.casting["class_floor"] = fr.index
		m.casting["class_visit"] = fr.safe_room_visits
	m.species_id = species_id
	m.class_id = class_id
	for skill_id: String in Progression.class_skills_up_to(m, data, m.level):
		if not m.skills.has(skill_id):
			m.skills.append(skill_id)
	_drop_foreign_variants(state, data, m)       # Recall (06 §3.6): an Umschulung leaves no old class on the bar
	Progression.follow_max_vitals(m, before, Progression.total_stats(m, data))
	return true


static func _same_visit(m: PartyMember, floor_key: String, visit_key: String, floor_index: int, visit: int) -> bool:
	return int(m.casting.get(floor_key, -1)) == floor_index and int(m.casting.get(visit_key, -1)) == visit


# --- Recall (06 §3.5) -------------------------------------------------------------------------------------------------
# What the Recall screen offers right now, the class signature it puts on the bar, and the two species passives that
# act outside a combat (07 §9.6: pas_authentic → the Show, pas_court_flight's bark → the exploration). Pure like the
# rest of this file: the screen asks, Game.choose_casting / Game.apply_loadout record.

## The modes of mode(): the first choice, trying again during the visit of the choice, the Umschulung (class only).
const MODES: PackedStringArray = ["first", "redo", "retrain"]


## What the Recall offers `member_id` right now (06 §3.5, §3.6): "first" — no class yet and a choice is allowed here
## (any safe room of a floor >= 3); "redo" — the visit of the species choice: species and class stay open ("im Raum
## ausprobieren"); "retrain" — the Umschulung: only the class (a later floor's first safe room, then the rest of that
## visit); "" — nothing to choose here and now (no safe room, floor < 3, both fixed). Asks check() for every option.
static func mode(state: GameState, data: GameData, member_id: String) -> String:
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null or data == null:
		return ""
	var o: Dictionary = options(state, data, member_id)
	var species: PackedStringArray = o["species"]
	var classes: PackedStringArray = o["classes"]
	if m.class_id == "":
		for s: String in species:
			for c: String in classes:
				if check(state, data, member_id, s, c) == "":
					return "first"
		return ""
	var own: String = m.species_id if m.species_id != "" else SpeciesDef.ORIGINAL
	for s: String in species:
		if s != m.species_id and check(state, data, member_id, s, m.class_id) == "":
			return "redo"
	for c: String in classes:
		if c != m.class_id and check(state, data, member_id, own, c) == "":
			return "retrain"
	return ""


## The members the Recall walks through now (mode() != ""): the controlled hero first, then the partner (06 §3.5
## step 5: "Danach … die andere Figur").
static func open_members(state: GameState, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	if state == null:
		return out
	var order: Array[PartyMember] = []
	for m: PartyMember in state.party:
		if m != null and m.id == state.hero:
			order.append(m)
	for m: PartyMember in state.party:
		if m != null and m.id != state.hero:
			order.append(m)
	for m: PartyMember in order:
		if mode(state, data, m.id) != "":
			out.append(m.id)
	return out


## The lowest floor of any species or class (the Recall's floor, 3 with today's data); 0 without data.
static func min_floor(data: GameData) -> int:
	var lo: int = 0
	if data == null:
		return lo
	for s: SpeciesDef in data.all_species():
		lo = s.min_floor if lo == 0 else mini(lo, s.min_floor)
	for c: ClassDef in data.all_classes():
		lo = c.min_floor if lo == 0 else mini(lo, c.min_floor)
	return lo


## The class signature of `class_id` (09 §8.3: classes.json rt.bar, the row of level 1 — learned with the class):
## {"slot", "skill", "level", "kind", "source"} like AbilityBook.rows, {} without one.
static func signature(data: GameData, member_id: String, class_id: String) -> Dictionary:
	if data == null or class_id == "":
		return {}
	for r: Dictionary in AbilityBook.rows(data, member_id, class_id):
		if str(r["source"]) == class_id and int(r["level"]) <= 1:
			return r
	return {}


## The loadout command (RunRules.loadout_cmd, recorded through Game.apply_loadout) that puts the member's class
## signature on its slot right after the Recall — only in a season (the class bar acts there, 09 V-4), never over a
## party variant the player chose for that slot (the ability book is the place to swap, 09 §8.3). {} when there is
## nothing to do (no class or signature, the slot holds it already) or the loadout would be refused.
static func signature_loadout(state: GameState, data: GameData, member_id: String) -> Dictionary:
	var m: PartyMember = state.member(member_id) if state != null else null
	if m == null or state.season == null:
		return {}
	var sig: Dictionary = signature(data, member_id, m.class_id)
	if sig.is_empty() or not RunRules.LOADOUT_SLOTS.has(str(int(sig["slot"]))):
		return {}
	var slot: String = str(int(sig["slot"]))
	var held: String = str(m.rt_loadout.get(slot, ""))
	if held == str(sig["skill"]):
		return {}
	if held != "" and not AbilityBook.class_skills(data, m.class_id).has(held):
		return {}                                  # the player's own variant stays
	var bar: Dictionary = m.rt_loadout.duplicate()
	bar[slot] = str(sig["skill"])
	var cmd: Dictionary = RunRules.loadout_cmd(member_id, bar, m.rt_preset, m.rt_toggles)
	return cmd if RunRules.loadout_refusal(state, data, cmd) == "" else {}


## Species passive pas_authentic (06 §3.2 Original-Verpackung, "Das Publikum liebt Echtes."; 07 §9.6: the Show only):
## the battle followers × params.follower_pm for every member that chose it at the Recall (species_id spc_original —
## "" = never cast counts nothing). The party product in per mille, round half up; 1000 without one — GameState.
## follower_pm multiplies it in (bit-identical without a species).
static func follower_pm(state: GameState, data: GameData) -> int:
	var pm: int = 1000
	if state == null or data == null:
		return pm
	for m: PartyMember in state.party:
		var f: int = passive_pm(m, data, "pas_authentic", "follower_pm")
		if f != 1000:
			pm = (pm * f + 500) / 1000
	return pm


## Species passive pas_court_flight (06 §3.2 Flattermops: "Bellen-Reichweite +50 %"; 07 §9.6: the exploration): the
## field ability's reach × params.bark_range_pm while the member leads (HeroRules.field_mods). 1000 = neutral.
static func field_range_pm(member: PartyMember, data: GameData) -> int:
	return passive_pm(member, data, "pas_court_flight", "bark_range_pm")


## params[key] of the member's species passive when it is `passive_id` (per mille, >= 0), else 1000.
static func passive_pm(member: PartyMember, data: GameData, passive_id: String, key: String) -> int:
	if member == null or data == null or member.species_id == "" or not data.has_id("species", member.species_id):
		return 1000
	var sp: SpeciesDef = data.species_def(member.species_id)
	if str(sp.passive.get("id", "")) != passive_id:
		return 1000
	var params: Variant = sp.passive.get("params", {})
	return maxi(0, JsonUtil.to_int((params as Dictionary).get(key, 1000), 1000)) if params is Dictionary else 1000


## A class change (06 §3.6 Umschulung) leaves the old class's abilities in PartyMember.rt_loadout: such an entry is no
## variant of the member's slots any more (AbilityBook.variant_level −1) and would make every later loadout command —
## it carries the whole bar — fail with not_a_variant. Dropped here, in both verifiers alike (Casting.choose).
static func _drop_foreign_variants(state: GameState, data: GameData, m: PartyMember) -> void:
	var keys: Array = m.rt_loadout.keys()
	keys.sort()
	for k: Variant in keys:
		if AbilityBook.variant_level(state, data, m, str(k).to_int(), str(m.rt_loadout[k])) < 0:
			m.rt_loadout.erase(k)
