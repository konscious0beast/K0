class_name GameState extends RefCounted
## Complete runtime save state (02_TECH §6.1). Everything except play_time_sec and show.viewers (display fields)
## is game-relevant and part of the state hash (05 §3.3 Nr. 8); to_dict() only contains integral numbers there.

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
	var st: GameState = GameState.new()
	st.slot = slot
	st.seed = seed
	st.player_name = player_name
	st.difficulty = difficulty
	st.inventory = Inventory.new()
	st.show = ShowState.new()
	st.show.hype = ShowModel.HYPE_START
	if data == null:
		return st
	var start: Dictionary = data.party_start()
	var start_items: Dictionary = start.get("inventory", {})
	var item_ids: Array = start_items.keys()
	item_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for item_id: Variant in item_ids:
		var iid: String = str(item_id)
		var max_stack: int = data.item(iid).max_stack if data.has_id("items", iid) else 9
		st.inventory.add(iid, JsonUtil.to_int(start_items[item_id]), max_stack)
	st.inventory.credits = maxi(0, JsonUtil.to_int(start.get("credits", 0)))
	for def: PartyMemberDef in data.all_party():
		var m: PartyMember = PartyMember.new()
		m.id = def.id
		m.display_name = player_name if (def.id == "kai" and player_name != "") else def.name
		m.level = 1
		m.exp = 0
		var eq: Dictionary = {"weapon": "", "armor": "", "accessory": ""}
		for slot_key: String in eq.keys():
			var item_id: String = str(def.equipment.get(slot_key, ""))
			if item_id != "" and data.has_id("items", item_id):
				eq[slot_key] = item_id
		m.equipment = eq
		for entry: Dictionary in def.learnset:
			var skill_id: String = str(entry.get("skill", ""))
			if int(entry.get("level", 99)) <= 1 and skill_id != "" and not m.skills.has(skill_id):
				m.skills.append(skill_id)
		var sb: StatBlock = Progression.total_stats(m, data)
		m.hp = sb.values[StatBlock.Stat.HP]
		m.mp = sb.values[StatBlock.Stat.MP]
		st.party.append(m)
	return st


func member(id: String) -> PartyMember:
	for m: PartyMember in party:
		if m != null and m.id == id:
			return m
	return null


## Product of equipped show_mods.hype_gain_mult.
func hype_gain_mult(data: GameData) -> float:
	return _show_mod_product(data, "hype_gain_mult")


## Product of equipped show_mods.follower_mult.
func follower_mult(data: GameData) -> float:
	return _show_mod_product(data, "follower_mult")


func to_dict() -> Dictionary:
	var members: Array = []
	for m: PartyMember in party:
		if m != null:
			members.append(m.to_dict())
	var best: Dictionary = {}
	var enemy_ids: Array = bestiary.keys()
	enemy_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for enemy_id: Variant in enemy_ids:
		var entry: Variant = bestiary[enemy_id]
		var ed: Dictionary = entry if entry is Dictionary else {}
		best[str(enemy_id)] = {"defeated": JsonUtil.to_int(ed.get("defeated", 0)),
			"weak_known": Array(JsonUtil.to_str_array(ed.get("weak_known", [])))}
	return {
		"slot": slot,
		"seed": seed,
		"player_name": player_name,
		"difficulty": String(difficulty),
		"play_time_sec": play_time_sec,
		"rng_counter": rng_counter,
		"pity_rare": pity_rare,
		"pity_epic": pity_epic,
		"party": members,
		"inventory": (inventory if inventory != null else Inventory.new()).to_dict(),
		"pending_lootboxes": Array(pending_lootboxes),
		"bestiary": best,
		"floor_run": floor_run.to_dict() if floor_run != null else null,
		"show": (show if show != null else ShowState.new()).to_dict(),
		"flags": _normalize(flags),
	}


## Missing fields → defaults; numbers converted with int() (JSON numbers are floats); integral float flags → int.
## No data validation (unknown ids): SaveCodec.decode sanitizes against GameData.
static func from_dict(d: Dictionary) -> GameState:
	var st: GameState = GameState.new()
	st.slot = JsonUtil.to_int(d.get("slot", 0))
	st.seed = JsonUtil.to_int(d.get("seed", 0))
	st.player_name = str(d.get("player_name", "Kai"))
	var diff: String = str(d.get("difficulty", "prime"))
	st.difficulty = &"vorabend" if diff == "vorabend" else &"prime"
	st.play_time_sec = maxf(0.0, JsonUtil.to_float(d.get("play_time_sec", 0.0)))
	st.rng_counter = maxi(0, JsonUtil.to_int(d.get("rng_counter", 0)))
	st.pity_rare = maxi(0, JsonUtil.to_int(d.get("pity_rare", 0)))
	st.pity_epic = maxi(0, JsonUtil.to_int(d.get("pity_epic", 0)))
	var raw_party: Variant = d.get("party", [])
	if raw_party is Array:
		for e: Variant in raw_party:
			if e is Dictionary:
				var m: PartyMember = PartyMember.from_dict(e)
				if m != null and st.member(m.id) == null:
					st.party.append(m)
	var raw_inv: Variant = d.get("inventory", {})
	st.inventory = Inventory.from_dict(raw_inv if raw_inv is Dictionary else {})
	st.pending_lootboxes = JsonUtil.to_str_array(d.get("pending_lootboxes", []))
	var raw_best: Variant = d.get("bestiary", {})
	if raw_best is Dictionary:
		for enemy_id: Variant in (raw_best as Dictionary).keys():
			var entry: Variant = (raw_best as Dictionary)[enemy_id]
			if entry is Dictionary:
				st.bestiary[str(enemy_id)] = {
					"defeated": maxi(0, JsonUtil.to_int((entry as Dictionary).get("defeated", 0))),
					"weak_known": JsonUtil.to_str_array((entry as Dictionary).get("weak_known", [])),
				}
	var raw_fr: Variant = d.get("floor_run", null)
	if raw_fr is Dictionary:
		st.floor_run = FloorRun.from_dict(raw_fr)
		if st.floor_run != null and st.floor_run.loot_seed < 0:
			st.floor_run.loot_seed = SeedUtil.derive(st.seed, "loot", st.floor_run.index)
	var raw_show: Variant = d.get("show", {})
	st.show = ShowState.from_dict(raw_show if raw_show is Dictionary else {})
	var raw_flags: Variant = d.get("flags", {})
	if raw_flags is Dictionary:
		st.flags = _normalize(raw_flags)
	return st


func _show_mod_product(data: GameData, key: String) -> float:
	var mult: float = 1.0
	if data == null:
		return mult
	for m: PartyMember in party:
		if m == null:
			continue
		for slot_key: String in ["weapon", "armor", "accessory"]:
			var item_id: String = str(m.equipment.get(slot_key, ""))
			if item_id != "" and data.has_id("items", item_id):
				mult *= float(data.item(item_id).show_mods.get(key, 1.0))
	return mult


## Deep copy with sorted String keys; integral floats become int (JSON round trips stay hash-stable).
static func _normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var src: Dictionary = v
			var out: Dictionary = {}
			var keys: Array = src.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			for k: Variant in keys:
				out[str(k)] = _normalize(src[k])
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(_normalize(e))
			return out_a
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return _normalize(Array(v))
		TYPE_FLOAT:
			if JsonUtil.is_integral(v):
				return int(v)
			return v
		TYPE_STRING_NAME:
			return String(v)
	return v
