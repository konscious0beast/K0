class_name Casting extends RefCounted
## Casting from floor 3 (06 §3, 02_TECH §6.5): each party member picks a species ("Wer bist du?", species.json) and
## its first specialization ("Was kannst du?", the classes of classes.json). Data model + rules only — the Casting UI
## follows with floor 3. Static and pure (core); the choice is the recorded command
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
	Progression.follow_max_vitals(m, before, Progression.total_stats(m, data))
	return true


static func _same_visit(m: PartyMember, floor_key: String, visit_key: String, floor_index: int, visit: int) -> bool:
	return int(m.casting.get(floor_key, -1)) == floor_index and int(m.casting.get(visit_key, -1)) == visit
