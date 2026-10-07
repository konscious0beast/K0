# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name FairRoll extends RefCounted
## Commit-reveal dice (05 §7; hook, tests only in the slice).


static func hmac(key: PackedByteArray, msg: String) -> PackedByteArray:
	return PackedByteArray()


static func u48(b: PackedByteArray) -> int:
	return 0


static func commit(server_seed: PackedByteArray, event_id: String, window_id: String, tables_hash: String,
		rules_hash: String, data_hash: String, sim_version: int) -> String:
	return ""


static func layout_seed(server_seed: PackedByteArray, event_id: String, window_id: String) -> int:
	return 0


static func roll_key(server_seed: PackedByteArray, event_id: String, window_id: String, sender_ref: String,
		client_seed: String, nonce: int) -> PackedByteArray:
	return PackedByteArray()


static func roll_chest(roll_key: PackedByteArray, tier: Dictionary, pool: Dictionary, rolls: int,
		pity_forced: String) -> Array[Dictionary]:
	return []
