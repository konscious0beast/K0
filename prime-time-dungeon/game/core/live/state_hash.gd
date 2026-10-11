class_name StateHash extends RefCounted
## SHA-256 over GameState / BattleState without display fields (05 §3.3 Nr. 8, §11.2, CR-14).
##
## of(state): CanonicalJson over GameState.to_dict() without the display/bookkeeping fields `play_time_sec`,
## `show.viewers` (05 §11.2) and `slot` (active save slot, Save.save_slot moves it; GameState / Save document it as
## not game-relevant), and without the twist replay buffer flags["twist_buffer"] (06-D, TwistApplier.buffer: input that
## is not applied yet — a twist sorted in early must not change a checkpoint; it is hashed once applied). Everything
## else — party, inventory, floor run incl. timer ticks, show values and counters, flags (incl. flags["live"]),
## rng_counter, pity — is hashed.
## of_battle(battle): CanonicalJson over BattleState.to_dict() (CTB counters, statuses, items, action_n, RNG state).
## A state that cannot be serialized canonically (e.g. a non-integral float in flags) yields "" plus a warning; ""
## is never a valid hash.

const EXCLUDED_KEYS: PackedStringArray = ["play_time_sec", "slot"]
const EXCLUDED_SHOW_KEYS: PackedStringArray = ["viewers"]
const EXCLUDED_FLAG_KEYS: PackedStringArray = ["twist_buffer"]        # == TwistApplier.BUFFER_KEY


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
	var flags: Variant = d.get("flags", null)
	if flags is Dictionary:
		var f: Dictionary = (flags as Dictionary).duplicate()
		for k: String in EXCLUDED_FLAG_KEYS:
			f.erase(k)
		d["flags"] = f
	return d


static func _hash(d: Dictionary, what: String) -> String:
	var h: String = CanonicalJson.sha256_hex(d)
	if h == "":
		push_warning("[StateHash] %s is not canonically serializable: %s" % [what, CanonicalJson.last_error])
	return h


# --- Echtzeitkampf (07, R1a → R1b) ------------------------------------------------------------------------------------

## SHA-256 over the canonical JSON of sim.snapshot() (07 §10.4) without display names (every "display_name" key: the
## Def names are presentation, 08 §2.7 Nr. 5 / CR-24); "" for null. Complete once RtSim.snapshot() is (R1b).
static func of_rt(sim: RtSim) -> String:
	if sim == null:
		return ""
	return _hash(_without_key(sim.snapshot(), "display_name") as Dictionary, "RtSim")


## Deep copy of `v` without any dictionary entry named `key`.
static func _without_key(v: Variant, key: String) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				if str(k) != key:
					out[k] = _without_key((v as Dictionary)[k], key)
			return out
		TYPE_ARRAY:
			var out_a: Array = []
			for e: Variant in (v as Array):
				out_a.append(_without_key(e, key))
			return out_a
	return v
