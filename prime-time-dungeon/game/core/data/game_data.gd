class_name GameData extends RefCounted
## Loaded, normalized and validated game data (02_TECH §4.5). Pure RefCounted: no autoloads, no SceneTree.
## Loading never prints; problems are collected in `errors` / `warnings` (DB pushes them).
## Getters for unknown ids return null and push_error (data bug). Defs are immutable after loading.

## Echtzeitkampf (07 §3.16, R1a): tuning values of the real-time combat — not a table (no "entries"), optional.
const RT_BALANCE_FILE: String = "rt_balance.json"
const TABLES: PackedStringArray = ["statuses", "skills", "items", "classes", "party", "enemies", "floors",
	"lootboxes", "achievements", "sponsors", "milestones", "mod_lines", "scenes",
	"talents", "species",                       # 06 package B
	"marotten",                                 # 06-C
	"twists",                                   # 06-D (KI-Admin): twists.json
	"origins", "looks",                         # Casting (08, K0): persona catalog + avatar looks (08 §3.8, §6.1)
	"seasons", "professions", "cast", "themes"]   # Staffeln (09, ST0): templates, professions, AI cast, Kulissen

var source: String = ""                    # dir or "dicts"
var errors: PackedStringArray = []
var warnings: PackedStringArray = []
# --- Inhaltspakete (11-P1, 11 §3.4/§3.9): the content pack mixed into the raw tables ("" without one) ----------------
var pack_id: String = ""
var pack_version: String = ""
var pack_hash: String = ""                 # PackLoader.content_hash (SHA-256 over pack.json + data/*.json)

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
var _twists: Dictionary = {}               # 06-D: id → TwistDef
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
var _all_twists: Array[TwistDef] = []      # 06-D: sorted by id
# --- Echtzeitkampf (07, R1a): data/rt_balance.json → "values" (RtBalance.from_data; {} = RtBalance.DEFAULTS) ---------
var _rt_balance: Dictionary = {}
# --- Casting (08, K0): origins.json (+ its lists) and looks.json — plain read-only dictionaries ---------------------
var _origins: Dictionary = {}              # org id → entry
var _all_origins: Array[Dictionary] = []   # file order
var _persona_lists: Dictionary = {}        # list (hobbies, traits, rivals, brands, gags, greetings) → {id → entry}
var _persona_plans: Array = []             # origins.json → plans (file order)
var _persona_canon: Dictionary = {}        # origins.json → canon
var _looks: Dictionary = {}                # lk id → entry
var _looks_by_kind: Dictionary = {}        # kind → Array[Dictionary] (file order)
# --- Staffeln (09, ST0): seasons / professions / cast / themes.json --------------------------------------------------
var _seasons: Dictionary = {}              # ssn id → SeasonDef
var _all_seasons: Array[SeasonDef] = []    # file order
var _professions: Dictionary = {}          # prf id → ProfessionDef
var _all_professions: Array[ProfessionDef] = []
var _recipes: Dictionary = {}              # rcp id → RecipeDef (professions.json → recipes)
var _all_recipes: Array[RecipeDef] = []
var _materials: Dictionary = {}            # mat id → entry (professions.json → materials)
var _nodes: Dictionary = {}                # nod id → entry (professions.json → nodes)
var _cast: Dictionary = {}                 # profile id → entry
var _all_cast: Array[Dictionary] = []      # file order
var _cast_names: Array[Dictionary] = []    # cast.json → names ({"name", "form"}, file order)
var _themes: Dictionary = {}               # thm id → ThemeDef
var _all_themes: Array[ThemeDef] = []
# --- Staffeln (09 §8.2, contract pass 4): party.json → exp_table ([] without the key; never mutated) -----------------
var _exp_table: PackedInt32Array = []


## Loads all TABLES from `dir` (<table>.json). Full validation (rules 1–10). True if no errors.
## Inhaltspakete (11-P1, 11 §3.4): with `pack` (PackLoader.read) its overlays and art.json are mixed into the raw
## tables first (PackLoader.merge) and the result is validated with every rule plus the pack rules, the provenance
## going to ip_words; pack_id / pack_version / pack_hash name the pack, its read and merge errors come first in
## `errors`. Without a pack everything is exactly as before.
func load_dir(dir: String = "res://data", pack: PackDef = null) -> bool:
	var raw: Dictionary = {}
	var read_errors: Dictionary = {}
	for t: String in TABLES:
		var path: String = dir.path_join(t + ".json")
		var parsed: Variant = JsonUtil.read_file(path)
		if parsed == null:
			read_errors[t] = "%s (%s)" % [JsonUtil.last_error(), path]
		else:
			raw[t] = parsed
	var rt_path: String = dir.path_join(RT_BALANCE_FILE)         # Echtzeitkampf (07, R1a): optional, not a table
	if FileAccess.file_exists(rt_path):
		raw["rt_balance"] = JsonUtil.read_file(rt_path)
	if pack == null:
		return _load(raw, dir, true, read_errors)
	var merged: Dictionary = PackLoader.merge(raw, pack)          # Inhaltspakete (11-P1)
	_load(merged["raw"], dir, true, read_errors, PackLoader.provenance(pack, merged["owned"]))
	pack_id = pack.id
	pack_version = pack.version
	pack_hash = pack.pack_hash
	var first: PackedStringArray = pack.errors.duplicate()
	first.append_array(merged["errors"])
	first.append_array(errors)
	errors = first
	return errors.is_empty()


## Test helper: {"skills": [ {...} ], ..., "party_start": {...}, "lootbox_pools": {...}, "lootbox_pity": {...},
## "pseudo_units": [...]}. Missing tables = empty, missing extras = defaults. Same validation except rules 7–9.
func load_from_dicts(tables: Dictionary) -> bool:
	var raw: Dictionary = {}
	for t: String in TABLES:
		var file: Dictionary = {"schema": 1, "entries": (tables.get(t, []) as Array).duplicate(true)}
		match t:
			"party":
				file["start"] = (tables.get("party_start", {"inventory": {}, "credits": 0}) as Dictionary).duplicate(true)
				if tables.has("exp_table"):                   # Staffeln (09 §8.2, contract pass 4)
					file["exp_table"] = (tables["exp_table"] as Array).duplicate()
			"enemies":
				if tables.has("pseudo_units"):
					file["pseudo_units"] = (tables["pseudo_units"] as Array).duplicate(true)
			"lootboxes":
				file["pools"] = (tables.get("lootbox_pools", {}) as Dictionary).duplicate(true)
				file["pity"] = (tables.get("lootbox_pity", {"rare": 4, "epic": 8}) as Dictionary).duplicate(true)
			"origins":                                    # Casting (08, K0): {hobbies, traits, …, canon}
				file.merge((tables.get("origin_extras", {}) as Dictionary).duplicate(true))
			"professions":                                # Staffeln (09, ST0): {recipes, materials, nodes}
				file.merge((tables.get("profession_extras", {}) as Dictionary).duplicate(true))
			"cast":                                       # Staffeln (09, ST0): {names}
				file.merge((tables.get("cast_extras", {}) as Dictionary).duplicate(true))
		raw[t] = file
	if tables.has("rt_balance"):                              # Echtzeitkampf (07, R1a): file object or bare values
		var rb: Variant = tables["rt_balance"]
		raw["rt_balance"] = rb if (rb is Dictionary and (rb as Dictionary).has("values")) \
			else {"schema": 1, "values": rb}
	return _load(raw, "dicts", false, {})


## Loads file-shaped tables ({"<table>": {"schema": 1, "entries": [...], ...}}) from memory with full validation
## (rules 1–10, like load_dir). Used by load_dir and by negative tests.
func load_from_tables(raw: Dictionary, p_source: String = "tables") -> bool:
	return _load(raw, p_source, true, {})


func is_valid() -> bool:
	return errors.is_empty()


## Inhaltspakete (11-P1, 11 §3.9): the pack fields of a run-log header and a leaderboard entry — {"pack": id,
## "pack_version", "pack_hash"}; {} without a pack, so a record of the base game stays exactly as before.
func pack_fields() -> Dictionary:
	if pack_id == "":
		return {}
	return {"pack": pack_id, "pack_version": pack_version, "pack_hash": pack_hash}


## Inhaltspakete (11-P1, 11 §3.9): the save block "pack" {"id", "version", "hash"}; {} without a pack.
func pack_record() -> Dictionary:
	if pack_id == "":
		return {}
	return {"id": pack_id, "version": pack_version, "hash": pack_hash}


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


## Talents whose `for` includes `member_id` (or is empty), sorted by id. The 06-B pool only: a talent of the talent
## tree (row > 0, 09 §8.4, contract pass 4) is never offered by the Talent-Show — ST1-D reads them via all_talents().
func talents_for(member_id: String) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	for t: TalentDef in _all_talents:
		if t.is_for(member_id) and not t.is_tree():
			out.append(t)
	return out


## File order (spc_original first in the real data).
func all_species() -> Array[SpeciesDef]:
	return _all_species.duplicate()


## 06-C: M.O.D. preference / Unterhosen-Liga (marotten.json, 06 §4.9).
func marotte(id: String) -> MarotteDef:
	return _get_def(_marotten, "marotten", id) as MarotteDef
## 06-D: twist catalog entry (06 §5.6).
func twist(id: String) -> TwistDef:
	return _get_def(_twists, "twists", id) as TwistDef


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


## Staffeln (09 §8.2, contract pass 4): party.json → exp_table — the EXP of level 1..49 to the next (index level − 1;
## levels 1–9 = Progression.EXP_TABLE), a copy; [] without the key (nothing reads it outside a season, ST1-D).
func exp_table() -> PackedInt32Array:
	return _exp_table.duplicate()


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


## Tables: TABLES plus "pseudo_units" and "encounters" (09 ST0: plus "recipes", "materials", "nodes" of
## professions.json).
func has_id(table: String, id: String) -> bool:
	var d: Dictionary = _table_dict(table)
	return d.has(id)


## Sorted ascending. Tables: as has_id.
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
## 06-D: the twist catalog, sorted by id.
func all_twists() -> Array[TwistDef]:
	return _all_twists.duplicate()


# --- Casting (08 §3.8, §6.1, K0): persona catalog getters — unknown ids give {} / null without an error (persona
# files may name ids a data update removed: the caller shows the canon value, 08 §2.5) ---------------------------------

## origins.json entry ({} if unknown).
func origin(id: String) -> Dictionary:
	return _origins.get(id, {})


## All origins, file order (23 tiles + org_allround in the full catalog, K1).
func all_origins() -> Array[Dictionary]:
	return _all_origins.duplicate()


## origins.json → hobbies entry ({} if unknown).
func hobby(id: String) -> Dictionary:
	return persona_entry("hobbies", id)


## origins.json → traits entry ({} if unknown).
func trait_def(id: String) -> Dictionary:
	return persona_entry("traits", id)


## An entry of one of the persona lists of origins.json (hobbies, traits, rivals, brands, gags, greetings).
func persona_entry(list: String, id: String) -> Dictionary:
	return (_persona_lists.get(list, {}) as Dictionary).get(id, {})


## Casting (08, K1 — additive): every entry of one persona list (hobbies, traits, rivals, brands, gags, greetings),
## file order — the casting's tiles and chips.
func persona_list(list: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign((_persona_lists.get(list, {}) as Dictionary).values())
	return out


## origins.json → canon (the canon persona, 08 §3.6).
func persona_canon() -> Dictionary:
	return _persona_canon.duplicate(true)


## origins.json → plans (broadcast plans, 08 §4.7), file order.
func persona_plans() -> Array:
	return _persona_plans.duplicate(true)


## looks.json entry ({} if unknown).
func look(id: String) -> Dictionary:
	return _looks.get(id, {})


## Looks of one category (hair, hair_color, skin, beard, glasses, outfit), file order.
func looks_of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_looks_by_kind.get(kind, []))
	return out


## Casting (08 §6.1, K2): the canon option of a look category (Kai's look; "canon": true, else the first; {} if the
## category has none).
func look_canon(kind: String) -> Dictionary:
	var list: Array = _looks_by_kind.get(kind, [])
	for d: Dictionary in list:
		if bool(d.get("canon", false)):
			return d
	return list[0] if not list.is_empty() else {}


func _build_persona(norm: Dictionary) -> void:
	for d: Dictionary in norm.get("origins", []):
		if not _origins.has(str(d["id"])):
			_origins[str(d["id"])] = d
			_all_origins.append(d)
	var extras: Dictionary = norm.get("origin_extras", {})
	for list: String in ["hobbies", "traits", "rivals", "brands", "gags", "greetings"]:
		var by_id: Dictionary = {}
		for d: Dictionary in extras.get(list, []):
			if not by_id.has(str(d.get("id", ""))):
				by_id[str(d.get("id", ""))] = d
		_persona_lists[list] = by_id
	_persona_plans = (extras.get("plans", []) as Array).duplicate(true)
	_persona_canon = (extras.get("canon", {}) as Dictionary).duplicate(true)
	for d: Dictionary in norm.get("looks", []):
		if _looks.has(str(d["id"])):
			continue
		_looks[str(d["id"])] = d
		var kind: String = str(d.get("kind", ""))
		if not _looks_by_kind.has(kind):
			_looks_by_kind[kind] = []
		(_looks_by_kind[kind] as Array).append(d)
	for v: Variant in [_origins, _persona_lists, _persona_canon, _looks, _looks_by_kind]:
		_freeze(v)
	_freeze(_persona_plans)


# --- Staffeln (09, ST0): getters of seasons / professions / cast / themes.json (defs: null + error if unknown, like
# every def getter; entries: {} if unknown) ---------------------------------------------------------------------------

## seasons.json template (ssn_).
func season_def(id: String) -> SeasonDef:
	return _get_def(_seasons, "seasons", id) as SeasonDef


## All season templates, file order.
func all_seasons() -> Array[SeasonDef]:
	return _all_seasons.duplicate()


## professions.json entry (prf_).
func profession(id: String) -> ProfessionDef:
	return _get_def(_professions, "professions", id) as ProfessionDef


## All professions, file order.
func all_professions() -> Array[ProfessionDef]:
	return _all_professions.duplicate()


## professions.json → recipes entry (rcp_).
func recipe(id: String) -> RecipeDef:
	return _get_def(_recipes, "professions", id) as RecipeDef


## All recipes, file order.
func all_recipes() -> Array[RecipeDef]:
	return _all_recipes.duplicate()


## professions.json → materials entry ({} if unknown).
func material(id: String) -> Dictionary:
	return _materials.get(id, {})


## professions.json → nodes entry, a gathering node ({} if unknown).
func gather_node(id: String) -> Dictionary:
	return _nodes.get(id, {})


## cast.json profile of the AI candidates ({} if unknown).
func cast_profile(id: String) -> Dictionary:
	return _cast.get(id, {})


## All AI candidate profiles, file order.
func all_cast_profiles() -> Array[Dictionary]:
	return _all_cast.duplicate()


## cast.json → names: the name catalog of the AI candidates ({"name", "form"}, file order).
func cast_names() -> Array[Dictionary]:
	return _cast_names.duplicate()


## themes.json Kulisse (thm_).
func theme(id: String) -> ThemeDef:
	return _get_def(_themes, "themes", id) as ThemeDef


## All Kulissen, file order.
func all_themes() -> Array[ThemeDef]:
	return _all_themes.duplicate()


func _build_season(norm: Dictionary) -> void:
	for d: Dictionary in norm.get("seasons", []):
		var s: SeasonDef = SeasonDef.from_dict(d)
		if not _seasons.has(s.id):
			_seasons[s.id] = s
			_all_seasons.append(s)
	for d: Dictionary in norm.get("professions", []):
		var p: ProfessionDef = ProfessionDef.from_dict(d)
		if not _professions.has(p.id):
			_professions[p.id] = p
			_all_professions.append(p)
	var extras: Dictionary = norm.get("profession_extras", {})
	for d: Dictionary in extras.get("recipes", []):
		var r: RecipeDef = RecipeDef.from_dict(d)
		if not _recipes.has(r.id):
			_recipes[r.id] = r
			_all_recipes.append(r)
	for d: Dictionary in extras.get("materials", []):
		if not _materials.has(str(d["id"])):
			_materials[str(d["id"])] = d
	for d: Dictionary in extras.get("nodes", []):
		if not _nodes.has(str(d["id"])):
			_nodes[str(d["id"])] = d
	for d: Dictionary in norm.get("cast", []):
		if not _cast.has(str(d["id"])):
			_cast[str(d["id"])] = d
			_all_cast.append(d)
	_cast_names.assign((norm.get("cast_extras", {}) as Dictionary).get("names", []))
	for d: Dictionary in norm.get("themes", []):
		var t: ThemeDef = ThemeDef.from_dict(d)
		if not _themes.has(t.id):
			_themes[t.id] = t
			_all_themes.append(t)
	for v: Variant in [_materials, _nodes, _cast, _cast_names]:
		_freeze(v)
	for table: Dictionary in [_seasons, _professions, _recipes, _themes]:
		for def: Variant in table.values():
			_freeze_object(def as Object)


## Echtzeitkampf (07 §3.16, R1a): the "values" of data/rt_balance.json (a copy; {} without the file). Read through
## RtBalance.from_data(data), which falls back to RtBalance.DEFAULTS.
func rt_balance_values() -> Dictionary:
	return _rt_balance.duplicate(true)


## All pseudo units (enemies.json → pseudo_units), file order.
func all_pseudo_units() -> Array[PseudoUnitDef]:
	var out: Array[PseudoUnitDef] = []
	for id: String in ids("pseudo_units"):
		out.append(_pseudo[id] as PseudoUnitDef)
	return out


# --- loading ---------------------------------------------------------------------------------------------------------

## `provenance` (11-P1): PackLoader.provenance of a mixed-in pack; {} = base data.
func _load(raw: Dictionary, p_source: String, p_strict: bool, read_errors: Dictionary,
		provenance: Dictionary = {}) -> bool:
	_clear()
	source = p_source
	var v: DataValidator = DataValidator.new()
	var norm: Dictionary = v.validate(raw, p_strict, read_errors, provenance)
	errors = v.errors.duplicate()
	warnings = v.warnings.duplicate()
	_build(norm)
	var rb: Variant = raw.get("rt_balance", null)                 # Echtzeitkampf (07, R1a)
	if rb is Dictionary and (rb as Dictionary).get("values", null) is Dictionary:
		_rt_balance = ((rb as Dictionary)["values"] as Dictionary).duplicate(true)
		_freeze(_rt_balance)
	return errors.is_empty()


func _clear() -> void:
	errors = PackedStringArray()
	warnings = PackedStringArray()
	pack_id = ""                                                  # Inhaltspakete (11-P1): load_dir sets them again
	pack_version = ""
	pack_hash = ""
	for d: Dictionary in [_statuses, _skills, _items, _classes, _party, _enemies, _pseudo, _floors, _floors_by_id,
			_encounters, _lootboxes, _achievements, _sponsors, _milestones, _mod_lines, _mod_lines_by_tag, _scenes,
			_talents, _species, _marotten, _twists]:
		d.clear()
	_party_start = {"inventory": {}, "credits": 0}
	_pools = {}
	_pity = {"rare": 4, "epic": 8}
	_rt_balance = {}                                              # Echtzeitkampf (07, R1a)
	# Casting (08, K0): fresh containers — the loaded ones are frozen (read-only) and cannot be cleared
	_origins = {}
	_persona_lists = {}
	_persona_canon = {}
	_looks = {}
	_looks_by_kind = {}
	_all_origins = []
	_persona_plans = []
	# Staffeln (09, ST0): fresh containers (the loaded entries are frozen)
	_seasons = {}
	_all_seasons = []
	_professions = {}
	_all_professions = []
	_recipes = {}
	_all_recipes = []
	_materials = {}
	_nodes = {}
	_cast = {}
	_all_cast = []
	_cast_names = []
	_themes = {}
	_all_themes = []
	_exp_table = PackedInt32Array()                               # Staffeln (contract pass 4)
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
	_all_twists.clear()


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
	# 06-D: twists
	for d: Dictionary in norm.get("twists", []):
		var s: TwistDef = TwistDef.from_dict(d)
		if not _twists.has(s.id):
			_twists[s.id] = s
			_all_twists.append(s)
	_all_twists.sort_custom(func(a: TwistDef, b: TwistDef) -> bool: return a.id < b.id)
	_party_start = (norm.get("party_start", {"inventory": {}, "credits": 0}) as Dictionary).duplicate(true)
	_pools = (norm.get("lootbox_pools", {}) as Dictionary).duplicate(true)
	_pity = (norm.get("lootbox_pity", {"rare": 4, "epic": 8}) as Dictionary).duplicate(true)
	var exp_t: Variant = norm.get("exp_table", PackedInt32Array())       # Staffeln (09 §8.2, contract pass 4)
	_exp_table = (exp_t as PackedInt32Array).duplicate() if exp_t is PackedInt32Array else PackedInt32Array()
	_build_persona(norm)                                          # Casting (08, K0)
	_build_season(norm)                                           # Staffeln (09, ST0)
	_freeze_defs()


## Defs are immutable after loading (§4.5, §13.3): every Dictionary/Array field of every def is made read-only,
## recursively (layout cells, ai.actions, phases, …). A write then fails loudly (SCRIPT ERROR) instead of silently
## changing DB.data / the shared test cache. Callers that need a mutable copy use duplicate(true).
## Packed*Array fields cannot be locked by Godot (they are shared references too): never mutate them.
func _freeze_defs() -> void:
	for table: Dictionary in [_statuses, _skills, _items, _classes, _party, _enemies, _pseudo, _floors_by_id,
			_encounters, _lootboxes, _achievements, _sponsors, _milestones, _mod_lines, _scenes, _talents, _species,
			_marotten, _twists]:
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
		"twists":
			return _twists
		"origins":                                                # Casting (08, K0)
			return _origins
		"looks":
			return _looks
		# --- Staffeln (09, ST0) ---
		"seasons":
			return _seasons
		"professions":
			return _professions
		"recipes":
			return _recipes
		"materials":
			return _materials
		"nodes":
			return _nodes
		"cast":
			return _cast
		"themes":
			return _themes
	return {}


func _get_def(table: Dictionary, file: String, id: String) -> RefCounted:
	if table.has(id):
		return table[id]
	push_error("GameData: unknown %s id '%s' (res://data/%s.json)" % [file, id, file])
	return null
