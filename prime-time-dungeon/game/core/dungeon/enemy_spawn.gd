# STUB(M0) — owned by M3. Replace completely, keep the public API.
class_name EnemySpawn extends RefCounted
## Visible enemy group placement (02_TECH §7.1).

var id: String = ""                          # "f1_g3" / "f1_s0" (stray) / "f1_qb" / "f1_fb"
var cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO
var encounter_id: String = ""
var lead_enemy_id: String = ""               # first enemy of the encounter (visual + explore params)
var is_boss: bool = false
var start_state: StringName = &"PATROL"      # &"IDLE" | &"PATROL"
var can_turn: bool = true                    # false: IDLE group never turns (tutorial)
var waypoints: Array[Vector2] = []           # room-local XZ; empty PATROL → circle r 4 m around offset
