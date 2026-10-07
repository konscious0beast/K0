extends Node
## Autoload `DB`: loads GameData in _init() (02_TECH §3.3) and offers a getter facade.
## Every load error is pushed as "DB: <msg> (res://data/<table>.json)" so that check.sh fails on data bugs.
## data/events.json is NOT loaded here (EventCatalog, M8).

const DATA_DIR: String = "res://data"

var data: GameData            # created + loaded in _init()
var ok: bool                  # data.is_valid()


func _init() -> void:
	data = GameData.new()
	ok = data.load_dir(DATA_DIR)
	for msg: String in data.errors:
		push_error("DB: %s (%s/%s.json)" % [msg, DATA_DIR, _table_of(msg)])
	for msg: String in data.warnings:
		push_warning("DB: %s (%s/%s.json)" % [msg, DATA_DIR, _table_of(msg)])


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


func floor_def(index: int) -> FloorDef:
	return data.floor_def(index)


func encounter(id: String) -> EncounterDef:
	return data.encounter(id)


func mod_lines(tag: String) -> Array[ModLineDef]:
	return data.mod_lines(tag)


func has_id(table: String, id: String) -> bool:
	return data.has_id(table, id)
