extends RefCounted
## The minimal season data of 09 ST0 (tests/fixtures/season_min): the data_min tables (tests/fixtures/data_min) with
## the four season tables of this folder — seasons (ssn_test), professions (prf_cooking and prf_first_aid for the
## data_min origins, prf_scrap for the node; one recipe, material and node), cast (one profile, one name), themes
## (thm_test) — and SAVE_V2, a save with the season block. ST1 packages test their modules against it before their
## real data exist. Private test helper (no class_name; preload it).

const DIR: String = "res://tests/fixtures/season_min"
const BASE_DIR: String = "res://tests/fixtures/data_min"
const SEASON_TABLES: PackedStringArray = ["seasons", "professions", "cast", "themes"]
## A v2 save with the season block (09 §9.1): ssn_test day 0 = 1791921600, the member fields (rested, professions,
## prof_head, talent_rows) and the floor-run fields (gather_nodes, respawn, daily); loads against data(). Since ST1-B
## the season block is complete (SeasonState.to_dict: one hour after day 0, the day-0 air time passed).
const SAVE_V2: String = "res://tests/fixtures/season_min/save_v2_season.json"


## The file-shaped tables ({"<table>": {"schema": 1, "entries": [...], ...}}): data_min with this folder's season
## tables.
static func tables() -> Dictionary:
	var raw: Dictionary = {}
	for t: String in GameData.TABLES:
		var dir: String = DIR if SEASON_TABLES.has(t) else BASE_DIR
		raw[t] = JsonUtil.read_file(dir.path_join(t + ".json"))
	return raw


## The loaded data (full validation; `errors` is empty for the fixture).
static func data() -> GameData:
	var d: GameData = GameData.new()
	d.load_from_tables(tables(), "season_min")
	return d
