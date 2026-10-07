# STUB(M0) — owned by M2. Replace completely, keep the public API.
class_name SaveCodec extends RefCounted
## Save dict ↔ GameState, versioning, migration (02_TECH §6.1/§6.4).

const FORMAT: String = "ptd_save"
const VERSION: int = 1


static func encode(state: GameState, game_version: String) -> Dictionary:
	return {}


## null on fatal error; errors via last_errors().
static func decode(d: Dictionary, data: GameData) -> GameState:
	return null


## Stepwise v(n) → v(n+1); unknown higher version → {}.
static func migrate(d: Dictionary) -> Dictionary:
	return {}


static func validate(d: Dictionary, data: GameData) -> PackedStringArray:
	return PackedStringArray()


static func summary(state: GameState) -> Dictionary:
	return {}


static func last_errors() -> PackedStringArray:
	return PackedStringArray()
