# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name FloorEvent extends RefCounted
## Rules of the floor events (02_TECH §7.4).


static func choices(ev: EventSpawn, state: GameState, data: GameData) -> PackedStringArray:
	return PackedStringArray()


## Pure (no mutation): {"completed": bool, "credits": int, "items_add": Dictionary, "items_remove": Dictionary,
## "boxes": PackedStringArray, "hype": float, "followers": int, "party_damage_pct": Dictionary (member → %),
## "encounter_id": String, "open_gate": String ("x,y,D"), "mod_tag": String}
static func resolve(ev: EventSpawn, choice: String, state: GameState, data: GameData,
		rng: RandomNumberGenerator) -> Dictionary:
	return {}


## Mutates GameState only (credits, items, hp (never below 1), opened_gates, completed_events, event_uses);
## hype/followers via Show.
static func apply(outcome: Dictionary, ev: EventSpawn, choice: String, state: GameState, data: GameData) -> void:
	pass
