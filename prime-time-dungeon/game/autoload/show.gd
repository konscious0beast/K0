# STUB(M0) — owned by M2. Replace completely, keep the public API.
extends Node
## Autoload `Show` (02_TECH §3.5): hype/viewers/followers, achievements, sponsors, M.O.D.


func viewers() -> int:
	return 0


func display_viewers() -> int:
	return 0


func followers() -> int:
	return 0


func hype() -> float:
	return 0.0


## amount > 0 → × hype_gain_mult (equipment); clamp 0..100; emits hype_changed.
func add_hype(amount: float, reason: StringName = &"") -> void:
	pass


## Emits followers_changed; checks milestones (§4.4.11).
func add_followers(n: int, reason: StringName = &"") -> void:
	pass


func bump_stat(stat_id: String, amount: int = 1) -> void:
	pass


func set_stat(stat_id: String, value: int) -> void:
	pass


func set_stat_max(stat_id: String, value: int) -> void:
	pass


## AchievementTracker.evaluate → unlock handling.
func trigger(trigger_id: String, payload: Dictionary) -> void:
	pass


func is_unlocked(achievement_id: String) -> bool:
	return false


## ModAnnouncer.pick → format → emits mod_said(text, voice, tag, blocking); returns text ("" if none/suppressed).
func say(tag: String, ctx: Dictionary = {}, blocking: bool = false) -> String:
	return ""


## voice &"chat" line → emits chat_posted.
func chat(tag: String, ctx: Dictionary = {}) -> void:
	pass


## hype := Balance.HYPE_START (30); say("floor_start").
func start_floor(floor_index: int) -> void:
	pass


## Re-emit hype/viewers/followers after load or RunSim tick.
func sync_from_state() -> void:
	pass


func begin_battle(setup: BattleSetup) -> void:
	pass


func on_battle_event(e: ActionEvent) -> void:
	pass


## THE single gift entry (Brief §6b.4) → {"accepted": bool, "reason": String}.
func receive_gift(gift: Dictionary) -> Dictionary:
	return {"accepted": false, "reason": "stub"}


## {} = none; battle gives the party situation for weight_mods.
func take_pending_gift(battle: BattleState = null) -> Dictionary:
	return {}


## Followers gained; stats; battle_won/battle_fled/boss_defeated.
func end_battle(result: BattleResult) -> int:
	return 0


func unlocked_this_battle() -> PackedStringArray:
	return PackedStringArray()
