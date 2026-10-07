# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name GameState extends RefCounted
## Complete runtime save state (02_TECH §6.1).

var slot: int = 0
var seed: int = 0
var player_name: String = "Kai"
var difficulty: StringName = &"prime"  # &"prime" | &"vorabend" (only lowerable)
var play_time_sec: float = 0.0
var party: Array[PartyMember] = []     # ordered by battle_slot
var inventory: Inventory = null
var pending_lootboxes: PackedStringArray = []
var pity_rare: int = 0
var pity_epic: int = 0
var bestiary: Dictionary = {}          # enemy id → {"defeated": int, "weak_known": PackedStringArray}
var floor_run: FloorRun = null
var show: ShowState = null
var flags: Dictionary = {}
var rng_counter: int = 0


## Party from party.json (level 1, full hp/mp, learnset level ≤ 1, start equipment); inventory + credits from
## data.party_start(); show: hype 30, followers 0; floor_run = null (Game.start_floor).
static func create_new(data: GameData, slot: int, player_name: String, seed: int,
		difficulty: StringName = &"prime") -> GameState:
	# M0 stub: minimal VALID state (party, start inventory/credits, show) so that scenes and tests of other modules
	# work before M2 delivers (02_TECH §0.2). No stats/levels/equipment logic.
	var st: GameState = GameState.new()
	st.slot = slot
	st.seed = seed
	st.player_name = player_name
	st.difficulty = difficulty
	st.inventory = Inventory.new()
	st.show = ShowState.new()
	if data == null:
		return st
	var start: Dictionary = data.party_start()
	st.inventory.counts = (start.get("inventory", {}) as Dictionary).duplicate()
	st.inventory.credits = int(start.get("credits", 0))
	for def: PartyMemberDef in data.all_party():
		var m: PartyMember = PartyMember.new()
		m.id = def.id
		m.display_name = player_name if def.id == "kai" else def.name
		m.hp = int(def.base_stats.get("hp", 1))
		m.mp = int(def.base_stats.get("mp", 0))
		m.equipment = def.equipment.duplicate()
		for entry: Dictionary in def.learnset:
			if int(entry.get("level", 99)) <= 1:
				m.skills.append(str(entry.get("skill", "")))
		st.party.append(m)
	return st


func member(id: String) -> PartyMember:
	for m: PartyMember in party:
		if m != null and m.id == id:
			return m
	return null


## Product of equipped show_mods.hype_gain_mult.
func hype_gain_mult(data: GameData) -> float:
	return 1.0


## Product of equipped show_mods.follower_mult.
func follower_mult(data: GameData) -> float:
	return 1.0


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> GameState:
	return null
