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
## Casting (08 §2.1 P-2, §2.7, K0): display names are not game state — of() leaves out `player_name` and every party
## member's `display_name`, of_battle() the `display_name` of the party combatants (setup.party and combatants), so
## renaming the candidate changes no hash and no hash input carries the name (canary test, test_08_k0_contract).
## A state that cannot be serialized canonically (e.g. a non-integral float in flags) yields "" plus a warning; ""
## is never a valid hash.

const EXCLUDED_KEYS: PackedStringArray = ["play_time_sec", "slot",
	"player_name"]                                                    # Casting (08, K0): display field (P-2)
const EXCLUDED_MEMBER_KEYS: PackedStringArray = ["display_name"]   # Casting (08, K0): party members, combatants
const EXCLUDED_SHOW_KEYS: PackedStringArray = ["viewers"]
const EXCLUDED_FLAG_KEYS: PackedStringArray = ["twist_buffer"]        # == TwistApplier.BUFFER_KEY


static func of(state: GameState) -> String:
	if state == null:
		return ""
	return _hash(hash_input(state), "GameState")


static func of_battle(state: BattleState) -> String:
	if state == null:
		return ""
	return _hash(battle_hash_input(state), "BattleState")


## The exact dictionary that of_battle() hashes: BattleState.to_dict() without the display names of the party
## combatants (Casting, 08 §2.7 Nr. 5, K0).
static func battle_hash_input(state: BattleState) -> Dictionary:
	if state == null:
		return {}
	var d: Dictionary = state.to_dict()
	d["combatants"] = _without_party_names(d.get("combatants", []))
	var setup: Variant = d.get("setup", null)
	if setup is Dictionary:
		var s: Dictionary = (setup as Dictionary).duplicate()
		s["party"] = _without_party_names(s.get("party", []))
		d["setup"] = s
	return d


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
	var party: Array = []                                             # Casting (08, K0): no display names
	for m: Variant in (d.get("party", []) as Array):
		var md: Dictionary = (m as Dictionary).duplicate() if m is Dictionary else {}
		for k: String in EXCLUDED_MEMBER_KEYS:
			md.erase(k)
		party.append(md)
	d["party"] = party
	return d


## Combatant dictionaries of the party (side 0) without their display names (Casting, 08 §2.7 Nr. 5).
static func _without_party_names(list: Variant) -> Array:
	var out: Array = []
	var src: Array = list if list is Array else []
	for c: Variant in src:
		if c is Dictionary and int((c as Dictionary).get("side", 0)) == 0:
			var cd: Dictionary = (c as Dictionary).duplicate()
			for k: String in EXCLUDED_MEMBER_KEYS:
				cd.erase(k)
			out.append(cd)
		else:
			out.append(c)
	return out


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
