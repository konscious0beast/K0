class_name EventCatalog extends RefCounted
## Loads + validates data/events.json (05 §10.1, CR-9). Not part of GameData.TABLES (DB never loads it).
## File: {"schema": 1, "events": [EventDef dict, …]} — any other top-level key is an error. Every problem is
## collected in `errors` ("<path>: <event id>: <problem>"); load_file() returns false then, but valid events stay
## available (get_event / all), invalid ones are left out.

const SCHEMA: int = 1
const TOP_KEYS: PackedStringArray = ["schema", "events"]

var errors: PackedStringArray = []

var _events: Array[EventDef] = []
var _by_id: Dictionary = {}       # id → EventDef


func load_file(path: String) -> bool:
	_clear()
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return false
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: JSON parse error at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return false
	if not (json.data is Dictionary):
		errors.append("%s: top level must be an object" % path)
		return false
	return _load(json.data, path)


## Same as load_file for an already parsed dictionary (tests, server-delivered catalogs).
func load_dict(d: Dictionary, source: String = "events") -> bool:
	_clear()
	return _load(d, source)


func get_event(id: String) -> EventDef:
	return _by_id.get(id, null) as EventDef


func all() -> Array[EventDef]:
	return _events.duplicate()


func _load(d: Dictionary, source: String) -> bool:
	for k: Variant in d.keys():
		if not TOP_KEYS.has(str(k)):
			errors.append("%s: unknown top-level key '%s'" % [source, str(k)])
	var schema: Variant = d.get("schema", null)
	if not ((typeof(schema) == TYPE_INT or typeof(schema) == TYPE_FLOAT) and int(schema) == SCHEMA):
		errors.append("%s: schema must be %d" % [source, SCHEMA])
	var raw: Variant = d.get("events", null)
	if not (raw is Array):
		errors.append("%s: events must be an Array" % source)
		return false
	var list: Array = raw
	for i in list.size():
		if not (list[i] is Dictionary):
			errors.append("%s: events[%d] must be an object" % [source, i])
			continue
		var def: EventDef = EventDef.from_dict(list[i])
		var label: String = def.id if def.id != "" else "events[%d]" % i
		var errs: PackedStringArray = def.validate()
		if _by_id.has(def.id):
			errs.append("duplicate event id")
		if not errs.is_empty():
			for e: String in errs:
				errors.append("%s: %s: %s" % [source, label, e])
			continue
		_events.append(def)
		_by_id[def.id] = def
	return errors.is_empty()


func _clear() -> void:
	errors = PackedStringArray()
	_events.clear()
	_by_id.clear()
