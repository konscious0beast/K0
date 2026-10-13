class_name ScriptedModVoice extends ModVoiceProvider
## The default voice (06 §5.12 S0): the written M.O.D. — ModAnnouncer lines through Show.say, unchanged. As a provider
## it answers every round at once with nothing (no lines, no twist): the script is already speaking, and the offline
## Regie (RegieDirector) makes the twists. Always available, no network, no cost.


func kind() -> StringName:
	return &"scripted"


func is_available() -> bool:
	return true


func request_turn(batch: Dictionary) -> String:
	var id: String = _req_id_of(batch)
	turn_ready.emit(id, [], {})
	return id
