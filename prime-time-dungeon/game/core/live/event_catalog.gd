# STUB(M0) — owned by M8. Replace completely, keep the public API.
class_name EventCatalog extends RefCounted
## Loads + validates data/events.json (05 CR-9). Not part of GameData.TABLES.

var errors: PackedStringArray = []


func load_file(path: String) -> bool:
	return false


func get_event(id: String) -> EventDef:
	return null


func all() -> Array[EventDef]:
	return []
