class_name AchievementTracker extends RefCounted
## Achievement evaluation (02_TECH §6.1, GDD §8).
##
## evaluate(trigger, payload) checks every not-yet-unlocked AchievementDef of that trigger (data order) against its
## parsed ConditionExpr with e = payload, s = ShowState.stats, f = GameState.flags, appends the newly unlocked ids to
## ShowState.achievements (each id at most once ever) and returns them. Rewards (box, followers, hype, M.O.D. line,
## toast) are handled by the Show autoload. Counters of the same trigger must be raised before (GDD §8).

var _data: GameData = null
var _show: ShowState = null
var _flags: Dictionary = {}


func _init(p_data: GameData, p_show: ShowState, p_flags: Dictionary) -> void:
	_data = p_data
	_show = p_show
	_flags = p_flags if p_flags != null else {}


## Newly unlocked ids (each id at most once ever).
func evaluate(trigger_id: String, payload: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if _data == null or _show == null:
		return out
	for def: AchievementDef in _data.all_achievements_for(trigger_id):
		if def == null or _show.achievements.has(def.id):
			continue
		if def.expr == null or def.expr.error != "":
			continue
		if def.expr.eval(payload, _show.stats, _flags):
			_show.achievements.append(def.id)
			out.append(def.id)
	return out
