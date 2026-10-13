class_name RemoteModVoice extends ModVoiceProvider
## "M.O.D. live" over the network (06 §5.3/§5.4, package D): one async HTTPRequest per round to services/mod-brain.
## OFF by default — only used when settings.mod_live != &"off" and an endpoint is configured (debug builds /
## --mod-live-url=). Never blocks gameplay: the round runs in the background, a client timeout of 6 s, any error,
## refusal or malformed answer yields an empty round (turn_ready with [] / {}), and the script keeps talking.
## Holds NO secrets: no API key ever lives in the client. It fetches a short-lived session token from the service's
## token endpoint against platform authentication (S1 dev: platform "dev", accepted by a dev-mode service on
## localhost/staging only; later: Steam session ticket etc.) and sends it as Bearer token.
##
## POST <base>/v1/auth/token {"platform", "ticket", "run_ref"} → {"token", "expires_in"}
## POST <base>/v1/mod/turn  (ModLiveSummary request, ≤ MAX_BODY bytes) → {"lines": [{"text", "tag", "voice",
##      "line_id"}], "twist": {"id", "params"} | null, "mood"}
## The token is bound to the run's pseudonym (the service checks run_ref): a new run_ref (new game / load) drops it.
## Healthy is only a 2xx answer with a well-formed JSON object (healthy_body); a 429 / 413 / 5xx, a JSON error body,
## a timeout or garbage is a failure (status degraded) — ModLiveLink pauses after 3 in a row and hands the twists back
## to the offline Regie.

const CLIENT_TIMEOUT_SEC: float = 6.0
const MAX_BODY: int = 8192
const MAX_LINES: int = 3
const TURN_PATH: String = "/v1/mod/turn"
const TOKEN_PATH: String = "/v1/auth/token"

var base_url: String = ""
var platform: String = "dev"             # platform of the session ticket (S1: "dev")
var ticket: String = "local-dev"         # platform session ticket (dev: not a secret)
## The run pseudonym the session token is bound to (ModLiveLink sets it per run); a new value drops the cached token
## and a round still running for the old run.
var run_ref: String = "":
	set(v):
		if v != run_ref:
			_token = ""
			if _phase != &"idle" and _http != null and is_instance_valid(_http):
				_http.cancel_request()
			_phase = &"idle"
			_req = ""
		run_ref = v

var _host: Node = null
var _http: HTTPRequest = null
var _token: String = ""
var _phase: StringName = &"idle"         # &"idle" | &"token" | &"turn"
var _req: String = ""                    # running round
var _body: String = ""


func _init(p_base_url: String = "") -> void:
	base_url = p_base_url.strip_edges().trim_suffix("/")


func kind() -> StringName:
	return &"remote"


## An http(s) endpoint and a host node for the HTTPRequest.
func is_available() -> bool:
	return _host != null and is_instance_valid(_host) and valid_url(base_url)


static func valid_url(url: String) -> bool:
	return url.begins_with("http://") or url.begins_with("https://")


func attach(host: Node) -> void:
	_host = host
	if _http != null and is_instance_valid(_http):
		return
	_http = HTTPRequest.new()
	_http.name = "ModBrainRequest"
	_http.timeout = CLIENT_TIMEOUT_SEC
	_http.request_completed.connect(_on_completed)
	host.add_child(_http)


## One round; "" when not available, busy or the request is too large.
func request_turn(batch: Dictionary) -> String:
	if not is_available() or _phase != &"idle":
		return ""
	var body: String = JSON.stringify(batch)
	if body.to_utf8_buffer().size() > MAX_BODY:
		return ""
	_req = _req_id_of(batch)
	_body = body
	if _token == "":
		_phase = &"token"
		var tb: String = JSON.stringify({"platform": platform, "ticket": ticket, "run_ref": run_ref})
		if _http.request(base_url + TOKEN_PATH, ["Content-Type: application/json"], HTTPClient.METHOD_POST, tb) != OK:
			_fail()
			return ""
		return _req
	_send_turn()
	return _req


func cancel(req_id: String) -> void:
	if req_id == _req and _http != null and is_instance_valid(_http):
		_http.cancel_request()
		_phase = &"idle"
		_req = ""


func _send_turn() -> void:
	_phase = &"turn"
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + _token]
	if _http.request(base_url + TURN_PATH, headers, HTTPClient.METHOD_POST, _body) != OK:
		_fail()


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Dictionary = healthy_body(result, code, body)
	if _phase == &"token":
		if str(parsed.get("token", "")) != "":
			_token = str(parsed["token"])
			_send_turn()
		else:
			_fail()
		return
	if _phase != &"turn":
		return
	if code == 401:
		_token = ""                       # expired / another run: fetch a new one next round
	if not (parsed.get("lines", null) is Array):
		_fail()
		return
	var id: String = _req
	_phase = &"idle"
	_req = ""
	status_changed.emit(&"ok")
	turn_ready.emit(id, parse_lines(parsed.get("lines", [])), parse_twist(parsed.get("twist", null)))


## The answer object of a healthy exchange, else {}: transport ok, HTTP 2xx and a JSON object that is no error body
## (no "error" / "detail" field). 429 (rate limit), 413 (too large), 5xx, timeouts and anything unparsable → {}.
static func healthy_body(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code > 299:
		return {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or (parsed as Dictionary).has("error") or (parsed as Dictionary).has("detail"):
		return {}
	return parsed


func _fail() -> void:
	var id: String = _req
	_phase = &"idle"
	_req = ""
	status_changed.emit(&"degraded")
	if id != "":
		turn_ready.emit(id, [], {})


## Shape check of the service's lines (the content is filtered again by Show.say_external): ≤ MAX_LINES dictionaries
## with String text, tag ([a-z0-9_:], ≤ 32) and voice ∈ ModLineFilter.VOICES.
static func parse_lines(v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for e: Variant in (v as Array):
		if out.size() >= MAX_LINES or not (e is Dictionary):
			continue
		var d: Dictionary = e
		var text: Variant = d.get("text", null)
		var tag: String = str(d.get("tag", "live"))
		var voice: String = str(d.get("voice", "mod"))
		if not (text is String) or not ModLineFilter.VOICES.has(voice) or tag.length() > 32 or not _tag_ok(tag):
			continue
		out.append({"text": str(text), "tag": tag, "voice": voice, "line_id": str(d.get("line_id", ""))})
	return out


## {} or {"id", "params": {String: int}} (TwistApplier decides whether it applies).
static func parse_twist(v: Variant) -> Dictionary:
	if not (v is Dictionary) or not ((v as Dictionary).get("id", null) is String):
		return {}
	var params: Dictionary = {}
	var p: Variant = (v as Dictionary).get("params", {})
	if p is Dictionary:
		for k: Variant in (p as Dictionary).keys():
			var val: Variant = (p as Dictionary)[k]
			if typeof(val) == TYPE_INT or (typeof(val) == TYPE_FLOAT and float(val) == floorf(float(val))):
				params[str(k)] = int(val)
			else:
				return {}
	return {"id": str((v as Dictionary)["id"]), "params": params}


static func _tag_ok(tag: String) -> bool:
	for c: String in tag:
		if not ("abcdefghijklmnopqrstuvwxyz0123456789_:".contains(c)):
			return false
	return tag != ""
