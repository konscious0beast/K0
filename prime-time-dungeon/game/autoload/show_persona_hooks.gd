# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
extends RefCounted
## Private helper of the Show autoload (no class_name, preloaded by show.gd): the persona hooks H2–H5, H7 (08 §4.3) —
## at most one persona line per hook event, from the broadcast plan (PersonaBeats), never while Game.in_battle (a
## waiting line is dropped when a battle starts), always said (ModAnnouncer.ALWAYS_SAID_PREFIXES "persona_"), silent
## in replays. Stub: every hook is a no-op (no persona lines before K1).

var show: Node = null                      # the Show autoload
var _pending: Array[String] = []           # tags waiting for the end of a line (K1)


func _init(p_show: Node) -> void:
	show = p_show


## H2: the first chest of the floor was opened. Stub: nothing.
func on_chest(_chest_id: String) -> void:
	pass


## H3: a boss was defeated and the battle is over. Stub: nothing.
func on_boss_won(_boss_id: String) -> void:
	pass


## H4: first visit of a safe room. Stub: nothing.
func on_safe_room(_safe_room_id: String) -> void:
	pass


## H5: the floor was completed. Stub: nothing.
func on_floor_end(_floor_index: int) -> void:
	pass


## H7 / plan start of a floor. Stub: nothing.
func on_floor_start(_floor_index: int) -> void:
	pass


## A battle starts: waiting persona lines are dropped (08 §4.3 "nie im Kampf").
func drop_pending() -> void:
	_pending.clear()
