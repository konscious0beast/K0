class_name StatusEffect extends RefCounted
## Active status on a combatant (02_TECH §5.4, GDD §3.9).
## Durations count own turns of the bearer and drop by 1 at its TURN_END. A status applied during the bearer's own turn
## (`fresh`) is not counted down at that turn's end (GDD §3.3: "3 eigene Züge" = the 3 following own turns).

var def: StatusDef = null
var turns_left: int = 0
var source_id: String = ""
var fresh: bool = false            # applied during the bearer's own running turn (cleared at that TURN_END)


func _init(p_def: StatusDef, p_turns: int, p_source_id: String) -> void:
	def = p_def
	turns_left = p_turns
	source_id = p_source_id


func id() -> String:
	return def.id if def != null else ""


func duplicate_effect() -> StatusEffect:
	var s: StatusEffect = StatusEffect.new(def, turns_left, source_id)
	s.fresh = fresh
	return s


## Snapshot (05 CR-14): {"id", "turns_left", "source_id", "fresh"}.
func to_dict() -> Dictionary:
	return {"id": id(), "turns_left": turns_left, "source_id": source_id, "fresh": fresh}


## Unknown status id → null (push_warning).
static func from_dict(d: Dictionary, data: GameData) -> StatusEffect:
	var sid: String = str(d.get("id", ""))
	if data == null or not data.has_id("statuses", sid):
		push_warning("StatusEffect.from_dict: unknown status '%s'" % sid)
		return null
	var s: StatusEffect = StatusEffect.new(data.status(sid), JsonUtil.to_int(d.get("turns_left", 0)),
			str(d.get("source_id", "")))
	s.fresh = bool(d.get("fresh", false))
	return s
