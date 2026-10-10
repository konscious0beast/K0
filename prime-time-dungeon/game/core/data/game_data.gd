class_name GameData extends RefCounted
## Loaded, normalized and validated game data (02_TECH §4.5). Pure RefCounted: no autoloads, no SceneTree.
## Loading never prints; problems are collected in `errors` / `warnings` (DB pushes them).
## Getters for unknown ids return null and push_error (data bug). Defs are immutable after loading.

const TABLES: PackedStringArray = ["statuses", "skills", "items", "classes", "party", "enemies", "floors",
	"lootboxes", "achievements", "sponsors", "milestones", "mod_lines", "scenes",
	"talents", "species",                       # 06 package B
	"marotten"]                                 # 06-C

var source: String = ""                    # dir or "dicts"
var errors: PackedStringArray = []
var warnings: PackedStringArray = []

var _statuses: Dictionary = {}             # id → StatusDef
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _classes: Dictionary = {}
var _party: Dictionary = {}
var _enemies: Dictionary = {}
var _pseudo: Dictionary = {}
var _floors: Dictionary = {}               # index → FloorDef
var _floors_by_id: Dictionary = {}
var _encounters: Dictionary = {}           # enc id → EncounterDef
var _lootboxes: Dictionary = {}
var _achievements: Dictionary = {}
var _sponsors: Dictionary = {}
var _milestones: Dictionary = {}
var _mod_lines: Dictionary = {}            # id → ModLineDef
var _mod_lines_by_tag: Dictionary = {}     # tag → Array[ModLineDef]
var _scenes: Dictionary = {}
var _marotten: Dictionary = {}             # 06-C: id → MarotteDef
var _party_start: Dictionary = {"inventory": {}, "credits": 0}
var _pools: Dictionary = {}
var _pity: Dictionary = {"rare": 4, "epic": 8}

var _all_statuses: Array[StatusDef] = []
var _all_skills: Array[SkillDef] = []
var _all_items: Array[ItemDef] = []
var _all_classes: Array[ClassDef] = []
var _all_party: Array[PartyMemberDef] = []
var _all_enemies: Array[EnemyDef] = []
var _all_floors: Array[FloorDef] = []
var _all_lootboxes: Array[LootboxDef] = []
var _all_achievements: Array[AchievementDef] = []
var _all_sponsors: Array[SponsorDef] = []
var _all_milestones: Array[MilestoneDef] = []
var _all_scenes: Array[SceneDef] = []
# --- 06 package B: talents + species ---------------------------------------------------------------------------------
var _talents: Dictionary = {}              # id → TalentDef
var _species: Dictionary = {}              # id → SpeciesDef
var _all_talents: Array[TalentDef] = []    # sorted by id
var _all_species: Array[SpeciesDef] = []   # file order
var _all_marotten: Array[MarotteDef] = []  # 06-C: file order


## Loads all TABLES from `dir` (<table>.json). Full validation (rules 1–10). True if no errors.
func load_dir(dir: String = "res://data") -> bool:
	var raw: Dictionary = {}
	var read_errors: Dictionary = {}
	for t: String in TABLES:
		var path: String = dir.path_join(t + ".json")
		var parsed: Variant = JsonUtil.read_file(path)
		if parsed == null:
			read_errors[t] = "%s (%s)" % [JsonUtil.last_error(), path]
		else:
			raw[t] = parsed
	return _load(raw, dir, true, read_errors)


## Test helper: {"skills": [ {...} ], ..., "party_start": {...}, "lootbox_pools": {...}, "lootbox_pity": {...},
## "pseudo_units": [...]}. Missing tables = empty, missing extras = defaults. Same validation except rules 7–9.
func load_from_dicts(tables: Dictionary) -> bool:
	var raw: Dictionary = {}
	for t: String in TABLES:
		var file: Dictionary = {"schema": 1, "entries": (tables.get(t, []) as Array).duplicate(true)}
		match t:
			"party":
				file["start"] = (tables.get("party_start", {"inventory": {}, "credits": 0}) as Dictionary).duplicate(true)
			"enemies":
				if tables.has("pseudo_units"):
					file["pseudo_units"] = (tables["pseudo_units"] as Array).duplicate(true)
			"lootboxes":
				file["pools"] = (tables.get("lootbox_pools", {}) as Dictionary).duplicate(true)
				file["pity"] = (tables.get("lootbox_pity", {"rare": 4, "epic": 8}) as Dictionary).duplicate(true)
		raw[t] = file
	return _load(raw, "dicts", false, {})


## Loads file-shaped tables ({"<table>": {"schema": 1, "entries": [...], ...}}) from memory with full validation
## (rules 1–10, like load_dir). Used by load_dir and by negative tests.
func load_from_tables(raw: Dictionary, p_source: String = "tables") -> bool:
	return _load(raw, p_source, true, {})


func is_valid() -> bool:
	return errors.is_empty()


# --- getters (unknown id → null + push_error) --------------------------------------------------------------------

func enemy(id: String) -> EnemyDef:
	return _get_def(_enemies, "enemies", id) as EnemyDef


func pseudo_unit(id: String) -> PseudoUnitDef:
	return _get_def(_pseudo, "enemies", id) as PseudoUnitDef


func skill(id: String) -> SkillDef:
	return _get_def(_skills, "skills", id) as SkillDef


func item(id: String) -> ItemDef:
	return _get_def(_items, "items", id) as ItemDef


func party_member(id: String) -> PartyMemberDef:
	return _get_def(_party, "party", id) as PartyMemberDef


func achievement(id: String) -> AchievementDef:
	return _get_def(_achievements, "achievements", id) as AchievementDef


func lootbox(id: String) -> LootboxDef:
	return _get_def(_lootboxes, "lootboxes", id) as LootboxDef


func sponsor(id: String) -> SponsorDef:
	return _get_def(_sponsors, "sponsors", id) as SponsorDef


func milestone(id: String) -> MilestoneDef:
	return _get_def(_milestones, "milestones", id) as MilestoneDef


func status(id: String) -> StatusDef:
	return _get_def(_statuses, "statuses", id) as StatusDef


func class_def(id: String) -> ClassDef:
	return _get_def(_classes, "classes", id) as ClassDef


func scene_def(id: String) -> SceneDef:
	return _get_def(_scenes, "scenes", id) as SceneDef


# --- 06 package B: talents (talents.json) + species (species.json) ----------------------------------------------------

func talent(id: String) -> TalentDef:
	return _get_def(_talents, "talents", id) as TalentDef


func species_def(id: String) -> SpeciesDef:
	return _get_def(_species, "species", id) as SpeciesDef


## Sorted by id (Talents.offer draws in this order).
func all_talents() -> Array[TalentDef]:
	return _all_talents.duplicate()


## Talents whose `for` includes `member_id` (or is empty), sorted by id.
func talents_for(member_id: String) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	for t: TalentDef in _all_talents:
		if t.is_for(member_id):
			out.append(t)
	return out


## File order (spc_original first in the real data).
func all_species() -> Array[SpeciesDef]:
	return _all_species.duplicate()


## 06-C: M.O.D. preference / Unterhosen-Liga (marotten.json, 06 §4.9).
func marotte(id: String) -> MarotteDef:
	return _get_def(_marotten, "marotten", id) as MarotteDef


## null (no error) if `index` has no floor → end of content.
func floor_def(index: int) -> FloorDef:
	return _floors.get(index, null) as FloorDef


func floor_by_id(id: String) -> FloorDef:
	return _get_def(_floors_by_id, "floors", id) as FloorDef


func encounter(id: String) -> EncounterDef:
	return _get_def(_encounters, "floors", id) as EncounterDef


## [] if none (no error).
func mod_lines(tag: String) -> Array[ModLineDef]:
	var out: Array[ModLineDef] = []
	if _mod_lines_by_tag.has(tag):
		out.assign(_mod_lines_by_tag[tag])
	return out


## {"inventory": {item_id: int}, "credits": int}
func party_start() -> Dictionary:
	return _party_start.duplicate(true)


## pools.f<i> (fallback: highest pool index <= floor_index); rarity incl. "fan". [] if none.
func loot_pool(floor_index: int, rarity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var best: int = -1
	for k: Variant in _pools.keys():
		var n: int = str(k).trim_prefix("f").to_int()
		if n <= floor_index and n > best:
			best = n
	if best < 0:
		return out
	var pool: Dictionary = _pools["f%d" % best]
	if pool.has(rarity):
		out.assign((pool[rarity] as Array).duplicate(true))
	return out


## {"rare": int, "epic": int}
func pity_limits() -> Dictionary:
	return _pity.duplicate()


## Tables: TABLES plus "pseudo_units" and "encounters".
func has_id(table: String, id: String) -> bool:
	var d: Dictionary = _table_dict(table)
	return d.has(id)


## Sorted ascending. Tables: TABLES plus "pseudo_units" and "encounters".
func ids(table: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var d: Dictionary = _table_dict(table)
	for k: Variant in d.keys():
		out.append(str(k))
	out.sort()
	return out


func all_statuses() -> Array[StatusDef]:
	return _all_statuses.duplicate()


func all_skills() -> Array[SkillDef]:
	return _all_skills.duplicate()


func all_items() -> Array[ItemDef]:
	return _all_items.duplicate()


func all_classes() -> Array[ClassDef]:
	return _all_classes.duplicate()


## Sorted by battle_slot.
func all_party() -> Array[PartyMemberDef]:
	return _all_party.duplicate()


func all_enemies() -> Array[EnemyDef]:
	return _all_enemies.duplicate()


## Sorted by index.
func all_floors() -> Array[FloorDef]:
	return _all_floors.duplicate()


func all_lootboxes() -> Array[LootboxDef]:
	return _all_lootboxes.duplicate()


func all_achievements() -> Array[AchievementDef]:
	return _all_achievements.duplicate()


func all_achievements_for(trigger_id: String) -> Array[AchievementDef]:
	var out: Array[AchievementDef] = []
	for a: AchievementDef in _all_achievements:
		if a.trigger == trigger_id:
			out.append(a)
	return out


func all_sponsors() -> Array[SponsorDef]:
	return _all_sponsors.duplicate()


## Sorted by followers.
func all_milestones() -> Array[MilestoneDef]:
	return _all_milestones.duplicate()


## Sorted by priority, then id.
func all_scenes() -> Array[SceneDef]:
	return _all_scenes.duplicate()


## 06-C: all marotten (file order).
func all_marotten() -> Array[MarotteDef]:
	return _all_marotten.duplicate()


## All pseudo units (enemies.json → pseudo_units), file order.
func all_pseudo_units() -> Array[PseudoUnitDef]:
	var out: Array[PseudoUnitDef] = []
	for id: String in ids("pseudo_units"):
		out.append(_pseudo[id] as PseudoUnitDef)
	return out


# --- loading ---------------------------------------------------------------------------------------------------------

func _load(raw: Dictionary, p_source: String, p_strict: bool, read_errors: Dictionary) -> bool:
	_clear()
	source = p_source
	var v: DataValidator = DataValidator.new()
	var norm: Dictionary = v.validate(raw, p_strict, read_errors)
	errors = v.errors.duplicate()
	warnings = v.warnings.duplicate()
	_build(norm)
	return errors.is_empty()


func _clear() -> void:
	errors = PackedStringArray()
	warnings = PackedStringArray()
	for d: Dictionary in [_statuses, _skills, _items, _classes, _party, _enemies, _pseudo, _floors, _floors_by_id,
			_encounters, _lootboxes, _achievements, _sponsors, _milestones, _mod_lines, _mod_lines_by_tag, _scenes,
			_talents, _species, _marotten]:
		d.clear()
	_party_start = {"inventory": {}, "credits": 0}
	_pools = {}
	_pity = {"rare": 4, "epic": 8}
	_all_statuses.clear()
	_all_skills.clear()
	_all_items.clear()
	_all_classes.clear()
	_all_party.clear()
	_all_enemies.clear()
	_all_floors.clear()
	_all_lootboxes.clear()
	_all_achievements.clear()
	_all_sponsors.clear()
	_all_milestones.clear()
	_all_scenes.clear()
	_all_talents.clear()
	_all_species.clear()
	_all_marotten.clear()


func _build(norm: Dictionary) -> void:
	for d: Dictionary in norm.get("statuses", []):
		var s: StatusDef = StatusDef.from_dict(d)
		if not _statuses.has(s.id):
			_statuses[s.id] = s
			_all_statuses.append(s)
	for d: Dictionary in norm.get("skills", []):
		var s: SkillDef = SkillDef.from_dict(d)
		if not _skills.has(s.id):
			_skills[s.id] = s
			_all_skills.append(s)
	for d: Dictionary in norm.get("items", []):
		var s: ItemDef = ItemDef.from_dict(d)
		if not _items.has(s.id):
			_items[s.id] = s
			_all_items.append(s)
	for d: Dictionary in norm.get("classes", []):
		var s: ClassDef = ClassDef.from_dict(d)
		if not _classes.has(s.id):
			_classes[s.id] = s
			_all_classes.append(s)
	for d: Dictionary in norm.get("party", []):
		var s: PartyMemberDef = PartyMemberDef.from_dict(d)
		if not _party.has(s.id):
			_party[s.id] = s
			_all_party.append(s)
	_all_party.sort_custom(func(a: PartyMemberDef, b: PartyMemberDef) -> bool:
		return a.battle_slot < b.battle_slot if a.battle_slot != b.battle_slot else a.id < b.id)
	for d: Dictionary in norm.get("enemies", []):
		var s: EnemyDef = EnemyDef.from_dict(d)
		if not _enemies.has(s.id):
			_enemies[s.id] = s
			_all_enemies.append(s)
	for d: Dictionary in norm.get("pseudo_units", []):
		var s: PseudoUnitDef = PseudoUnitDef.from_dict(d)
		if not _pseudo.has(s.id):
			_pseudo[s.id] = s
	for d: Dictionary in norm.get("floors", []):
		var s: FloorDef = FloorDef.from_dict(d)
		if _floors.has(s.index) or _floors_by_id.has(s.id):
			continue
		_floors[s.index] = s
		_floors_by_id[s.id] = s
		_all_floors.append(s)
		for e: EncounterDef in s.encounters:
			if not _encounters.has(e.id):
				_encounters[e.id] = e
	_all_floors.sort_custom(func(a: FloorDef, b: FloorDef) -> bool: return a.index < b.index)
	for d: Dictionary in norm.get("lootboxes", []):
		var s: LootboxDef = LootboxDef.from_dict(d)
		if not _lootboxes.has(s.id):
			_lootboxes[s.id] = s
			_all_lootboxes.append(s)
	for d: Dictionary in norm.get("achievements", []):
		var s: AchievementDef = AchievementDef.from_dict(d)
		if not _achievements.has(s.id):
			_achievements[s.id] = s
			_all_achievements.append(s)
	for d: Dictionary in norm.get("sponsors", []):
		var s: SponsorDef = SponsorDef.from_dict(d)
		if not _sponsors.has(s.id):
			_sponsors[s.id] = s
			_all_sponsors.append(s)
	for d: Dictionary in norm.get("milestones", []):
		var s: MilestoneDef = MilestoneDef.from_dict(d)
		if not _milestones.has(s.id):
			_milestones[s.id] = s
			_all_milestones.append(s)
	_all_milestones.sort_custom(func(a: MilestoneDef, b: MilestoneDef) -> bool:
		return a.followers < b.followers if a.followers != b.followers else a.id < b.id)
	for d: Dictionary in norm.get("mod_lines", []):
		var s: ModLineDef = ModLineDef.from_dict(d)
		if _mod_lines.has(s.id):
			continue
		_mod_lines[s.id] = s
		if not _mod_lines_by_tag.has(s.tag):
			var list: Array[ModLineDef] = []
			_mod_lines_by_tag[s.tag] = list
		(_mod_lines_by_tag[s.tag] as Array).append(s)
	for d: Dictionary in norm.get("scenes", []):
		var s: SceneDef = SceneDef.from_dict(d)
		if not _scenes.has(s.id):
			_scenes[s.id] = s
			_all_scenes.append(s)
	_all_scenes.sort_custom(func(a: SceneDef, b: SceneDef) -> bool:
		return a.priority < b.priority if a.priority != b.priority else a.id < b.id)
	for d: Dictionary in norm.get("talents", []):
		var s: TalentDef = TalentDef.from_dict(d)
		if not _talents.has(s.id):
			_talents[s.id] = s
			_all_talents.append(s)
	_all_talents.sort_custom(func(a: TalentDef, b: TalentDef) -> bool: return a.id < b.id)
	for d: Dictionary in norm.get("species", []):
		var s: SpeciesDef = SpeciesDef.from_dict(d)
		if not _species.has(s.id):
			_species[s.id] = s
			_all_species.append(s)
	for d: Dictionary in norm.get("marotten", []):             # 06-C
		var s: MarotteDef = MarotteDef.from_dict(d)
		if not _marotten.has(s.id):
			_marotten[s.id] = s
			_all_marotten.append(s)
	_party_start = (norm.get("party_start", {"inventory": {}, "credits": 0}) as Dictionary).duplicate(true)
	_pools = (norm.get("lootbox_pools", {}) as Dictionary).duplicate(true)
	_pity = (norm.get("lootbox_pity", {"rare": 4, "epic": 8}) as Dictionary).duplicate(true)
	_freeze_defs()


## Defs are immutable after loading (§4.5, §13.3): every Dictionary/Array field of every def is made read-only,
## recursively (layout cells, ai.actions, phases, …). A write then fails loudly (SCRIPT ERROR) instead of silently
## changing DB.data / the shared test cache. Callers that need a mutable copy use duplicate(true).
## Packed*Array fields cannot be locked by Godot (they are shared references too): never mutate them.
func _freeze_defs() -> void:
	for table: Dictionary in [_statuses, _skills, _items, _classes, _party, _enemies, _pseudo, _floors_by_id,
			_encounters, _lootboxes, _achievements, _sponsors, _milestones, _mod_lines, _scenes, _talents, _species,
			_marotten]:
		for def: Variant in table.values():
			_freeze_object(def as Object)
	for list: Variant in _mod_lines_by_tag.values():
		(list as Array).make_read_only()


static func _freeze_object(obj: Object) -> void:
	if obj == null:
		return
	for prop: Dictionary in obj.get_property_list():
		if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var v: Variant = obj.get(str(prop["name"]))
		if v is Dictionary or v is Array:
			_freeze(v)


## Makes a Dictionary/Array and everything nested in it read-only (objects inside are left alone).
static func _freeze(v: Variant) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		for k: Variant in d.keys():
			_freeze(d[k])
		d.make_read_only()
	elif v is Array:
		var a: Array = v
		for e: Variant in a:
			_freeze(e)
		a.make_read_only()


func _table_dict(table: String) -> Dictionary:
	match table:
		"statuses":
			return _statuses
		"skills":
			return _skills
		"items":
			return _items
		"classes":
			return _classes
		"party":
			return _party
		"enemies":
			return _enemies
		"pseudo_units":
			return _pseudo
		"floors":
			return _floors_by_id
		"encounters":
			return _encounters
		"lootboxes":
			return _lootboxes
		"achievements":
			return _achievements
		"sponsors":
			return _sponsors
		"milestones":
			return _milestones
		"mod_lines":
			return _mod_lines
		"scenes":
			return _scenes
		"talents":
			return _talents
		"species":
			return _species
		"marotten":
			return _marotten
	return {}


func _get_def(table: Dictionary, file: String, id: String) -> RefCounted:
	if table.has(id):
		return table[id]
	push_error("GameData: unknown %s id '%s' (res://data/%s.json)" % [file, id, file])
	return null
