class_name ModVoiceProvider extends RefCounted
## Where M.O.D.'s improvised voice comes from (06 §5.3, package D). ModLiveLink asks the provider for one "round"
## (request_turn with a ModLiveSummary request) and gets the answer through turn_ready — immediately (scripted, mock)
## or later (remote). The game NEVER waits for it: story, rules and mandatory lines always come from the script
## (Show.say); provider lines only fill pauses (Show.say_external) and a proposed twist still has to pass
## Game.apply_twist (TwistApplier).
##
## Implementations: ScriptedModVoice (default: the written M.O.D. keeps talking, the provider adds nothing),
## RemoteModVoice (HTTPS to services/mod-brain, off by default, timeout + scripted fallback, no secrets),
## tests/fixtures/live/mock_mod_voice.gd (tests).

## lines: Array of {"text", "tag", "voice"} (+ "line_id"); twist: {} or {"id", "params"}.
signal turn_ready(req_id: String, lines: Array, twist: Dictionary)
signal status_changed(status: StringName)        # &"ok" | &"degraded"

var _seq: int = 0


## &"scripted" | &"remote" | &"mock"
func kind() -> StringName:
	return &"none"


## True when request_turn can be answered at all (remote: an endpoint is configured and a host node is attached).
func is_available() -> bool:
	return false


## Starts one round; returns its req_id ("" = not started, e.g. busy). The answer arrives through turn_ready.
func request_turn(_batch: Dictionary) -> String:
	return ""


## Forget a running round (its turn_ready will not be acted on).
func cancel(_req_id: String) -> void:
	pass


## Providers that need the SceneTree (HTTPRequest) get a host node from ModLiveLink.
func attach(_host: Node) -> void:
	pass


## The round's id: batch["req_id"] (ModLiveLink sets it) or a new "r_<n>".
func _req_id_of(batch: Dictionary) -> String:
	var given: String = str(batch.get("req_id", ""))
	if given != "":
		return given
	_seq += 1
	return "r_%06d" % _seq
