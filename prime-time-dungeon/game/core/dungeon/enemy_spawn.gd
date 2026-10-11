class_name EnemySpawn extends RefCounted
## Visible enemy group placement (02_TECH §7.1). One spawn = one map symbol = one encounter.

var id: String = ""                          # "f1_g3" / "f1_s0" (stray) / "f1_qb" / "f1_fb"
var cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO
var encounter_id: String = ""
var lead_enemy_id: String = ""               # first enemy of the encounter (visual + explore params)
var is_boss: bool = false
var start_state: StringName = &"PATROL"      # &"IDLE" | &"PATROL"
var can_turn: bool = true                    # false: IDLE group never turns (tutorial)
var waypoints: Array[Vector2] = []           # room-local XZ; empty PATROL → circle r 4 m around offset


## Builds a spawn for `encounter` (lead enemy = first enemy of the encounter).
static func make(p_id: String, p_cell: Vector2i, encounter: EncounterDef, p_offset: Vector2 = Vector2.ZERO,
		p_state: StringName = &"PATROL") -> EnemySpawn:
	var s: EnemySpawn = EnemySpawn.new()
	s.id = p_id
	s.cell = p_cell
	s.offset = p_offset
	s.start_state = p_state
	if encounter != null:
		s.encounter_id = encounter.id
		s.lead_enemy_id = encounter.enemies[0] if not encounter.enemies.is_empty() else ""
		s.is_boss = encounter.boss
	return s


## Stray groups ("f<i>_s<n>", spawned by RunSim/STRAY_DUE).
func is_stray() -> bool:
	return id.get_slice("_", 1).begins_with("s")


func to_dict() -> Dictionary:
	var wps: Array = []
	for w: Vector2 in waypoints:
		wps.append([w.x, w.y])
	return {"id": id, "cell": [cell.x, cell.y], "offset": [offset.x, offset.y], "enc": encounter_id,
		"lead": lead_enemy_id, "boss": is_boss, "state": String(start_state), "turn": can_turn, "waypoints": wps}
