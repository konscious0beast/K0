# STUB(M0) — owned by M2. Replace completely, keep the public API.
extends Node
## Autoload `Save` (02_TECH §3.6): slots, file I/O, autosave.

const SLOT_COUNT: int = 3                    # slots 1..3; slot 0 = "no slot" (debug/autoplay, never written)

var save_dir: String = "user://saves"        # tests may redirect, e.g. "user://test_saves"
var read_only: bool = false                  # Autoplay: true → save calls return OK without writing


## save_dir + "/slot_%d.json" % slot
func slot_path(slot: int) -> String:
	return save_dir + "/slot_%d.json" % slot


func has_save(slot: int) -> bool:
	return false


## {} empty; {"corrupt": true} unreadable; else SaveCodec summary keys.
func slot_summary(slot: int) -> Dictionary:
	return {}


## Game.state → SaveCodec.encode → atomic write; emits game_saved.
func save_slot(slot: int) -> Error:
	return OK


## read → SaveCodec.decode → Game.state (+ grace time_left ≥ 180 s, §6.4), Game.sim/run_log new; emits game_loaded.
func load_slot(slot: int) -> Error:
	return ERR_UNAVAILABLE


func delete_slot(slot: int) -> Error:
	return OK


## save_slot(Game.state.slot); slot 0 → OK, no write.
func autosave() -> Error:
	return OK


## Slot with the latest saved_at_unix, 0 if none (Title "Fortsetzen").
func newest_slot() -> int:
	return 0


## Read-modify-write: state.show.stats.game_overs += 1 in the slot file; slot 0 → OK.
func record_game_over(slot: int) -> Error:
	return OK


## M8 (05 CR-8): user://leaderboards/<event_id>.json
func load_leaderboard(event_id: String) -> Dictionary:
	return {}


## Atomic like slots.
func save_leaderboard(event_id: String, d: Dictionary) -> Error:
	return OK


## user://replays/<run_id>.json, max. 20 files.
func save_replay(p_log: RunLog) -> Error:
	return OK


func last_error() -> String:
	return ""
