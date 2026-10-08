class_name StateHash extends RefCounted
## SHA-256 over GameState / BattleState without display fields (05 §3.3 Nr. 8, §11.2, CR-14).
##
## of(state): CanonicalJson over GameState.to_dict() without the display/bookkeeping fields `play_time_sec`,
## `show.viewers` (05 §11.2) and `slot` (active save slot, Save.save_slot moves it; GameState / Save document it as
## not game-relevant). Everything else — party, inventory, floor run incl. timer ticks, show values and counters,
## flags (incl. flags["live"]), rng_counter, pity — is hashed.
## of_battle(battle): CanonicalJson over BattleState.to_dict() (CTB counters, statuses, items, action_n, RNG state).
## A state that cannot be serialized canonically (e.g. a non-integral float in flags) yields "" plus a warning; ""
## is never a valid hash.

const EXCLUDED_KEYS: PackedStringArray = ["play_time_sec", "slot"]
const EXCLUDED_SHOW_KEYS: PackedStringArray = ["viewers"]


static func of(state: GameState) -> String:
	if state == null:
		return ""
	return _hash(hash_input(state), "GameState")


static func of_battle(state: BattleState) -> String:
	if state == null:
		return ""
	return _hash(state.to_dict(), "BattleState")


## The exact dictionary that of() hashes (debugging desyncs: diff two of these).
static func hash_input(state: GameState) -> Dictionary:
	if state == null:
		return {}
	var d: Dictionary = state.to_dict()
	for k: String in EXCLUDED_KEYS:
		d.erase(k)
	var show: Variant = d.get("show", null)
	if show is Dictionary:
		var s: Dictionary = (show as Dictionary).duplicate()
		for k: String in EXCLUDED_SHOW_KEYS:
			s.erase(k)
		d["show"] = s
	return d


static func _hash(d: Dictionary, what: String) -> String:
	var h: String = CanonicalJson.sha256_hex(d)
	if h == "":
		push_warning("[StateHash] %s is not canonically serializable: %s" % [what, CanonicalJson.last_error])
	return h
