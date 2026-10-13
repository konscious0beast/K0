extends Node
## Autoload `DB`: loads GameData in _init() (02_TECH §3.3) and offers a getter facade.
## Every load error is pushed as "DB: <msg> (res://data/<table>.json)" so that check.sh fails on data bugs.
## data/events.json is NOT loaded here (EventCatalog, M8).
## Inhaltspakete (11-P1, 11 §3.8): _init asks PackLoader which content pack this run plays (feature tag pack_<id>;
## --pack=<id> in debug builds) and loads the data with it; `pack` keeps it for the whole run (no later switch). A pack
## that cannot start (pack_ambiguous, pack_missing, pack_engine, pack_invalid) sets `pack_error`, `ok` stays false and
## the boot card turns into an error card (scenes/boot/boot.gd) — never a silent start with the base data.

const DATA_DIR: String = "res://data"

var data: GameData            # created + loaded in _init()
var ok: bool                  # data.is_valid() (and no pack_error, 11-P1)
var _data_hash: String = ""
# --- Inhaltspakete (11-P1) -------------------------------------------------------------------------------------------
var pack: PackDef = null                     # the content pack of this run; null = the base game
var pack_via: String = ""                    # "" | "feature" (export tag) | "arg" (--pack in a debug run)
var pack_error: String = ""                  # "" | pack_ambiguous | pack_missing | pack_engine | pack_invalid
var pack_messages: PackedStringArray = []    # why (the boot error card shows the first five)
var _data_hash_pack: String = ""             # the pack element _data_hash was computed with


func _init() -> void:
	var act: Dictionary = PackLoader.active_id(OS.get_cmdline_user_args(), OS.is_debug_build())   # 11-P1
	var res: Dictionary = PackLoader.load_data(DATA_DIR, act,
		str(ProjectSettings.get_setting("application/config/version", "")))
	data = res["data"]
	pack = res["pack"]
	pack_via = str(act.get("via", ""))
	pack_error = str(res["error"])
	pack_messages = res["messages"]
	ok = data.is_valid() and pack_error == ""
	if str(act.get("note", "")) != "":
		push_warning("DB: %s" % str(act["note"]))
	if pack_error == PackLoader.PACK_AMBIGUOUS or pack_error == PackLoader.PACK_MISSING \
			or pack_error == PackLoader.PACK_ENGINE:
		push_error("DB: %s (%s)" % [pack_messages[0] if not pack_messages.is_empty() else pack_error, PackLoader.ROOT])
	for msg: String in PackLoader.licence_notes(pack, Time.get_date_string_from_system()):
		push_warning("DB: %s (%s)" % [msg, PackLoader.ROOT])
	for msg: String in data.errors:
		push_error("DB: %s (%s)" % [msg, _source_of(msg)])
	for msg: String in data.warnings:
		push_warning("DB: %s (%s)" % [msg, _source_of(msg)])


## Where a load message points: res://data/<table>.json, or the pack folder for "pack[<id>]…" messages (11-P1).
func _source_of(msg: String) -> String:
	if msg.begins_with("pack[") and pack != null:
		return pack.root
	return "%s/%s.json" % [DATA_DIR, _table_of(msg)]


## Table name at the start of an error message ("skills[3|skl_x].power: …" → "skills").
static func _table_of(msg: String) -> String:
	var end: int = msg.length()
	for sep: String in ["[", ".", ":"]:
		var p: int = msg.find(sep)
		if p >= 0 and p < end:
			end = p
	return msg.substr(0, end)


# --- Facade (identical semantics to GameData, §4.5) -------------------------------------------------------------------

func enemy(id: String) -> EnemyDef:
	return data.enemy(id)


func pseudo_unit(id: String) -> PseudoUnitDef:
	return data.pseudo_unit(id)


func skill(id: String) -> SkillDef:
	return data.skill(id)


func item(id: String) -> ItemDef:
	return data.item(id)


func party_member(id: String) -> PartyMemberDef:
	return data.party_member(id)


func achievement(id: String) -> AchievementDef:
	return data.achievement(id)


func lootbox(id: String) -> LootboxDef:
	return data.lootbox(id)


func sponsor(id: String) -> SponsorDef:
	return data.sponsor(id)


func milestone(id: String) -> MilestoneDef:
	return data.milestone(id)


func status(id: String) -> StatusDef:
	return data.status(id)


func class_def(id: String) -> ClassDef:
	return data.class_def(id)


func scene_def(id: String) -> SceneDef:
	return data.scene_def(id)


func talent(id: String) -> TalentDef:           # 06 package B
	return data.talent(id)


func species_def(id: String) -> SpeciesDef:     # 06 package B
	return data.species_def(id)


func floor_def(index: int) -> FloorDef:
	return data.floor_def(index)


func encounter(id: String) -> EncounterDef:
	return data.encounter(id)


func mod_lines(tag: String) -> Array[ModLineDef]:
	return data.mod_lines(tag)


func has_id(table: String, id: String) -> bool:
	return data.has_id(table, id)


# --- Staffeln (09, ST0) ---

func season_def(id: String) -> SeasonDef:
	return data.season_def(id)


func profession(id: String) -> ProfessionDef:
	return data.profession(id)


func recipe(id: String) -> RecipeDef:
	return data.recipe(id)


func theme(id: String) -> ThemeDef:
	return data.theme(id)


## SHA-256 (hex) over the game data files (res://data/*.json, sorted by name: name + per-file SHA-256) — the
## data_hash of leaderboard entries and commits (05 §7.3/§10.4). Cached after the first call.
## Inhaltspakete (11-P1, 11 §3.9): with a content pack (the pack of `data`) the list ends with the element
## "pack:<id>:<pack_hash>" (data_hash_input); without one the hash is exactly the one of before.
func data_hash() -> String:
	var elem: String = PackLoader.hash_element(data)
	if _data_hash != "" and elem == _data_hash_pack:
		return _data_hash
	_data_hash = "|".join(data_hash_input()).sha256_text()
	_data_hash_pack = elem
	return _data_hash


## The parts data_hash() hashes: "<name>:<sha256>" of every res://data/*.json (sorted; no sub folders such as
## data/stempel), then the pack element of 11 §3.9 when `data` carries a content pack.
func data_hash_input() -> PackedStringArray:
	var names: PackedStringArray = []
	for f: String in DirAccess.get_files_at(DATA_DIR):
		if f.get_extension() == "json":
			names.append(f)
	names.sort()
	var parts: PackedStringArray = []
	for f: String in names:
		parts.append(f + ":" + FileAccess.get_sha256(DATA_DIR.path_join(f)))
	var elem: String = PackLoader.hash_element(data)
	if elem != "":
		parts.append(elem)
	return parts


# --- Casting (08 §6.3, K0 → K2) ---------------------------------------------------------------------------------------

## The member whose figure wears the persona look (the candidate, 08 §2.4).
const LOOK_MEMBER: String = "kai"


## THE place where a party figure's ModelSpec comes from (08 §6.3, K2): a copy of PartyMemberDef.model; for "kai" mixed
## with the running persona's look (Game.persona, PersonaLook.apply — presentation only, never in a hash or a log).
## Without a persona (tests, autoplay, event runs: the canon Kai) and for every other member: the def model; {} for an
## unknown member. The one figure entry for the exploration rigs (also the real-time puppets and the unit frames),
## the safe room and the intro; later also the equipment look (03_ART A8).
func party_model(member_id: String) -> Dictionary:
	if not data.has_id("party", member_id):
		return {}
	var model: Dictionary = data.party_member(member_id).model.duplicate(true)
	var persona: PersonaProfile = Game.persona
	if member_id != LOOK_MEMBER or persona == null:
		return model
	return PersonaLook.apply(model, persona.look, data)
