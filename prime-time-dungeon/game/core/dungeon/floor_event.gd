class_name FloorEvent extends RefCounted
## Rules of the floor events (02_TECH §7.4, GDD §2.6). Pure core logic: no autoloads, randomness only via the rng
## passed in (Game.apply_floor_event: SeedUtil.derive(floor_run.seed, "event", k × 16 + event_uses[id])).
##
## Choices per type: photo_drone pose|smash · lost_candidate give:<item_id>|leave · wheel spin|ignore ·
## lever pull|leave · broken_vending kick|leave. Every choice except leave/ignore completes the event (once per floor);
## the wheel allows further spins up to max_spins without a second completion.

const TYPES: PackedStringArray = ["photo_drone", "lost_candidate", "wheel", "lever", "broken_vending"]
## Choices that only close the dialog (the event stays open).
const PASSIVE_CHOICES: PackedStringArray = ["leave", "ignore"]
const GIVE_PREFIX: String = "give:"


## Choices that are possible right now (UI greys out every other option). [] = nothing left to do
## (completed event, wheel without spins left, unknown type).
static func choices(ev: EventSpawn, state: GameState, data: GameData) -> PackedStringArray:
	var out: PackedStringArray = []
	if ev == null or state == null or state.floor_run == null:
		return out
	var fr: FloorRun = state.floor_run
	var done: bool = fr.completed_events.has(ev.id)
	var p: Dictionary = ev.params
	match ev.type:
		"photo_drone":
			if not done:
				out.append("pose")
				out.append("smash")
		"lost_candidate":
			if not done:
				for item_id: String in _items_with_tag(state, data, str(p.get("tag", "heal"))):
					out.append(GIVE_PREFIX + item_id)
				out.append("leave")
		"wheel":
			var uses: int = int(fr.event_uses.get(ev.id, 0))
			if uses < int(p.get("max_spins", 3)):
				if _credits(state) >= int(p.get("cost", 0)):
					out.append("spin")
				out.append("ignore")
		"lever":
			if not done:
				out.append("pull")
				out.append("leave")
		"broken_vending":
			if not done:
				out.append("kick")
				out.append("leave")
	return out


## Pure (no mutation): {"completed": bool, "credits": int, "items_add": Dictionary, "items_remove": Dictionary,
## "boxes": PackedStringArray, "hype": float, "followers": int, "party_damage_pct": Dictionary (member → %),
## "encounter_id": String, "open_gate": String ("x,y,D"), "mod_tag": String}
## Additionally "valid": bool (false: choice not possible now → nothing happens), "success": bool (lever/vending roll),
## "wheel": Dictionary (the wheel entry that was hit).
static func resolve(ev: EventSpawn, choice: String, state: GameState, data: GameData,
		rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = _base_outcome()
	if not choices(ev, state, data).has(choice):
		return out
	out["valid"] = true
	var p: Dictionary = ev.params
	var first: bool = not state.floor_run.completed_events.has(ev.id)
	match ev.type:
		"photo_drone":
			if choice == "pose":
				out["hype"] = float(p.get("pose_hype", 0))
				out["followers"] = int(p.get("pose_followers", 0))
				out["mod_tag"] = "event_photo_drone_pose"
			else:
				out["credits"] = int(p.get("smash_credits", 0))
				out["hype"] = float(p.get("smash_hype", 0))
				out["mod_tag"] = "event_photo_drone_smash"
			out["completed"] = true
		"lost_candidate":
			if choice.begins_with(GIVE_PREFIX):
				var item_id: String = choice.substr(GIVE_PREFIX.length())
				(out["items_remove"] as Dictionary)[item_id] = 1
				var reward: String = str(p.get("reward_item", ""))
				if reward != "":
					(out["items_add"] as Dictionary)[reward] = 1
				out["followers"] = int(p.get("followers", 0))
				out["mod_tag"] = "event_lost_candidate_give"
				out["completed"] = true
			else:
				out["mod_tag"] = "event_lost_candidate_leave"
		"wheel":
			if choice == "spin":
				var credits: int = -int(p.get("cost", 0))
				var entry: Dictionary = _wheel_pick(p.get("table", []), rng)
				out["wheel"] = entry.duplicate(true)
				var amount: int = maxi(1, int(entry.get("amount", 1)))
				var id: String = str(entry.get("id", ""))
				match str(entry.get("kind", "nothing")):
					"item":
						(out["items_add"] as Dictionary)[id] = amount
					"credits":
						credits += amount
					"box":
						var boxes: PackedStringArray = []
						for _i in amount:
							boxes.append(id)
						out["boxes"] = boxes
					"encounter":
						out["encounter_id"] = id
				out["credits"] = credits
				out["mod_tag"] = "event_wheel_spin"
				out["completed"] = first
		"lever":
			if choice == "pull":
				var ok: bool = rng.randf() < float(p.get("success", 0.0))
				out["success"] = ok
				if ok:
					out["open_gate"] = str(p.get("gate", ""))
					out["mod_tag"] = "event_lever_open"
				else:
					var pct: int = int(p.get("flood_pct", 0))
					var dmg: Dictionary = {}
					for m: PartyMember in state.party:
						if m != null and m.hp > 0 and pct > 0:
							dmg[m.id] = pct
					out["party_damage_pct"] = dmg
					out["encounter_id"] = str(p.get("encounter", ""))
					out["mod_tag"] = "event_lever_flood"
				out["completed"] = true
		"broken_vending":
			if choice == "kick":
				var kai: PartyMember = _kai(state)
				var lck: int = stat_of(kai, data, "lck") if kai != null else 0
				var chance: float = float(p.get("base", 0.5)) + lck * float(p.get("per_lck", 0.0))
				var ok: bool = rng.randf() < chance
				out["success"] = ok
				if ok:
					(out["items_add"] as Dictionary)[str(p.get("reward_item", ""))] = int(p.get("reward_amount", 1))
					out["mod_tag"] = "event_broken_vending_ok"
				else:
					if kai != null and kai.hp > 0 and int(p.get("fail_pct", 0)) > 0:
						out["party_damage_pct"] = {kai.id: int(p.get("fail_pct", 0))}
					out["hype"] = float(p.get("fail_hype", 0))
					out["mod_tag"] = "event_broken_vending_fail"
				out["completed"] = true
	return out


## Mutates GameState only (credits, items, hp (never below 1), opened_gates, completed_events, event_uses);
## hype/followers via Show, boxes → pending_lootboxes by Game.apply_floor_event.
static func apply(outcome: Dictionary, ev: EventSpawn, choice: String, state: GameState, data: GameData) -> void:
	if outcome.is_empty() or not bool(outcome.get("valid", false)) or ev == null or state == null \
			or state.floor_run == null:
		return
	var fr: FloorRun = state.floor_run
	var inv: Inventory = state.inventory
	if inv != null:
		var credits: int = int(outcome.get("credits", 0))
		if credits > 0:
			inv.add_credits(credits)
		elif credits < 0:
			inv.spend_credits(-credits)
		var rem: Dictionary = outcome.get("items_remove", {})
		for item_id: Variant in rem.keys():
			inv.remove(str(item_id), int(rem[item_id]))
		var add: Dictionary = outcome.get("items_add", {})
		for item_id: Variant in add.keys():
			_add_item(inv, data, str(item_id), int(add[item_id]))
	var dmg: Dictionary = outcome.get("party_damage_pct", {})
	for member_id: Variant in dmg.keys():
		var m: PartyMember = state.member(str(member_id))
		if m == null or m.hp <= 0:
			continue
		var amount: int = maxi(1, floori(max_hp_of(m, data) * int(dmg[member_id]) / 100.0))
		m.hp = maxi(1, m.hp - amount)
	var gate: String = str(outcome.get("open_gate", ""))
	if gate != "" and not fr.opened_gates.has(gate):
		fr.opened_gates.append(gate)
	if not PASSIVE_CHOICES.has(choice):
		fr.event_uses[ev.id] = int(fr.event_uses.get(ev.id, 0)) + 1
	if bool(outcome.get("completed", false)) and not fr.completed_events.has(ev.id):
		fr.completed_events.append(ev.id)


## Effective MaxHP of a member (Progression.total_stats; falls back to the level formula of GDD §4.1).
static func max_hp_of(m: PartyMember, data: GameData) -> int:
	return maxi(maxi(1, m.hp), stat_of(m, data, "hp"))


## Effective stat (incl. equipment) via Progression.total_stats; while that is unavailable the level formula
## floori(base + growth × (level − 1)) of the member's PartyMemberDef.
static func stat_of(m: PartyMember, data: GameData, key: String) -> int:
	if m == null:
		return 0
	var idx: int = StatBlock.KEYS.find(key)
	if data != null and idx >= 0:
		var sb: StatBlock = Progression.total_stats(m, data)
		if sb != null:
			var v: int = sb.get_stat(idx as StatBlock.Stat)
			if v > 0:
				return v
	if data == null or not data.has_id("party", m.id):
		return 0
	var def: PartyMemberDef = data.party_member(m.id)
	return floori(float(def.base_stats.get(key, 0)) + float(def.growth.get(key, 0.0)) * (m.level - 1))


# ======================================================================================================================
# Private
# ======================================================================================================================

static func _base_outcome() -> Dictionary:
	return {"valid": false, "completed": false, "credits": 0, "items_add": {}, "items_remove": {},
		"boxes": PackedStringArray(), "hype": 0.0, "followers": 0, "party_damage_pct": {}, "encounter_id": "",
		"open_gate": "", "mod_tag": "", "success": false, "wheel": {}}


static func _credits(state: GameState) -> int:
	return state.inventory.credits if state.inventory != null else 0


## Item ids carrying `tag` via Inventory.ids_with_tag (§6.1, M2), sorted (deterministic choice list).
## While Inventory is still the M0 stub (its API ignores its own `counts`) the counts are scanned directly instead.
static func _items_with_tag(state: GameState, data: GameData, tag: String) -> PackedStringArray:
	var inv: Inventory = state.inventory
	if inv == null or data == null:
		return PackedStringArray()
	var out: PackedStringArray = inv.ids_with_tag(data, tag)
	if out.is_empty() and _inventory_api_is_stub(inv):
		for k: Variant in inv.counts.keys():
			var item_id: String = str(k)
			if int(inv.counts[k]) > 0 and data.has_id("items", item_id) and data.item(item_id).tags.has(tag):
				out.append(item_id)
	out.sort()
	return out


## True for the M0 stub: an item listed in `counts` that count() does not report.
static func _inventory_api_is_stub(inv: Inventory) -> bool:
	for k: Variant in inv.counts.keys():
		if int(inv.counts[k]) > 0 and inv.count(str(k)) <= 0:
			return true
	return false


static func _kai(state: GameState) -> PartyMember:
	var kai: PartyMember = state.member("kai")
	if kai == null and not state.party.is_empty():
		kai = state.party[0]
	return kai


## Weighted entry of the wheel table (weights >= 1); {} for an empty table.
static func _wheel_pick(table: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for e: Variant in table:
		total += maxi(0, int((e as Dictionary).get("weight", 0)))
	if total <= 0:
		return {}
	var r: int = rng.randi_range(0, total - 1)
	for e: Variant in table:
		r -= maxi(0, int((e as Dictionary).get("weight", 0)))
		if r < 0:
			return e as Dictionary
	return {}


## Adds items like Game.add_rewards: overflow above max_stack is paid out at the sell value.
static func _add_item(inv: Inventory, data: GameData, item_id: String, n: int) -> void:
	if n <= 0 or item_id == "":
		return
	var max_stack: int = 9
	if data != null and data.has_id("items", item_id):
		max_stack = data.item(item_id).max_stack
	var added: int = inv.add(item_id, n, max_stack)
	var overflow: int = n - maxi(0, added)
	if overflow > 0 and data != null and data.has_id("items", item_id):
		inv.add_credits(overflow * Shop.sell_value(data, item_id))
