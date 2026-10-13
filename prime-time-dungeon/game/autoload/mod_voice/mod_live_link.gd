extends Node
## ModLiveLink (06 §5.3/§5.8, package D) — child of Game (no class_name, 02_TECH §0.3): the bridge between the run and
## a ModVoiceProvider. Idle while settings.mod_live == &"off" (the default). With "M.O.D. live" on it collects compact
## events (ids and small numbers only, ModLiveSummary), starts a round every ROUND_SEC of run clock (a highlight —
## boss down, achievement, level up, party KO, floor done — pulls the next round forward, but never closer than
## HIGHLIGHT_MIN_SEC), and acts on the answer:
##   lines  → Show.say_external (filtered, lowest priority, only in pauses; answers older than MAX_AGE_SEC of run clock
##            are dropped unless tagged "evergreen")
##   twist  → only in mode &"lines_twists": Game.apply_twist({"id", "params", "src": "mod_brain", "req"}) within
##            TWIST_VALID_SEC — TwistApplier decides, the twist is recorded like every other one
## The game never waits: rounds run in the background, one at a time. MAX_FAILS failed rounds in a row pause the link
## for FAIL_PAUSE_SEC (the script keeps talking, nobody notices). Status → Events.mod_live_status (off | ok | degraded).
## While the AI chooses twists (lines_twists and status ok) the offline Regie steps back (replaces_regie); when the
## link fails, the Regie takes over again.
## Debug builds: --mod-live-url=<base url> and --mod-live=lines|lines_twists on the command line.

const ROUND_SEC: int = 40
const HIGHLIGHT_MIN_SEC: int = 20
const MAX_AGE_SEC: int = 12
const TWIST_VALID_SEC: int = 20
const MAX_FAILS: int = 3
const FAIL_PAUSE_SEC: float = 300.0
const MAX_RECENT: int = 6
const TICKS_PER_SEC: int = 30
const HIGHLIGHTS: PackedStringArray = ["boss_defeated", "achievement", "level_up", "party_ko", "floor_completed"]

var provider: ModVoiceProvider = null
var status: StringName = &"off"
var run_ref: String = ""
var recent_line_ids: PackedStringArray = []
var rounds_started: int = 0
var lines_shown: int = 0
var last_twist_result: String = ""

var _forced: bool = false                # set_provider (tests): keep it regardless of the settings
var _provider_key: String = ""
var _events: Array = []
var _highlight: bool = false
var _last_round_tick: int = -1
var _pending_req: String = ""
var _pending_tick: int = 0
var _awaiting: bool = false
var _req_seq: int = 0
var _fails: int = 0
var _paused_until_ms: int = 0
var _said_on: bool = false


func _ready() -> void:
	_read_cmdline()
	_new_run(0)
	Events.new_game_started.connect(_new_run)
	Events.game_loaded.connect(_new_run)
	Events.enemy_killed.connect(func(p: Dictionary) -> void:
		_note({"t": "kill", "id": str(p.get("enemy_id", "")), "by": str(p.get("by", "")),
			"member": str(p.get("member", ""))}))
	Events.boss_defeated.connect(func(p: Dictionary) -> void:
		_note({"t": "boss_defeated", "id": str(p.get("boss_id", ""))}))
	Events.achievement_unlocked.connect(func(id: String) -> void: _note({"t": "achievement", "id": id}))
	Events.level_up.connect(func(p: Dictionary) -> void:
		_note({"t": "level_up", "member": str(p.get("member", "")), "level": int(p.get("level", 1))}))
	Events.stunt_resolved.connect(func(p: Dictionary) -> void:
		if bool(p.get("success", false)):
			_note({"t": "stunt", "member": str(p.get("member", ""))}))
	Events.battle_won.connect(func(_p: Dictionary) -> void: _note({"t": "battle_won"}))
	Events.battle_fled.connect(func(_p: Dictionary) -> void: _note({"t": "battle_fled"}))
	Events.party_ko.connect(func(p: Dictionary) -> void: _note({"t": "party_ko", "member": str(p.get("member", ""))}))
	Events.floor_completed.connect(func(i: int) -> void: _note({"t": "floor_completed", "n": i}))
	Events.chest_opened.connect(func(_id: String, _r: Array) -> void: _note({"t": "chest"}))
	Events.twist_applied.connect(func(tv: Dictionary) -> void: _note({"t": "twist_applied", "id": str(tv.get("id", ""))}))
	Events.twist_ended.connect(func(id: String) -> void: _note({"t": "twist_ended", "id": id}))
	Events.floor_timer_warning.connect(func(s: int) -> void: _note({"t": "timer_warning", "n": s}))


func _process(_delta: float) -> void:
	if Game.state == null or Game.sim == null or Game.replaying:
		return
	_ensure_provider()
	if mode() == &"off" or provider == null or not provider.is_available():
		_set_status(&"off")
		return
	if _pending_req != "" or Time.get_ticks_msec() < _paused_until_ms:
		return
	var now: int = Game.sim.tick()
	var since: int = now - _last_round_tick
	if _last_round_tick >= 0 and since < ROUND_SEC * TICKS_PER_SEC \
			and not (_highlight and since >= HIGHLIGHT_MIN_SEC * TICKS_PER_SEC):
		return
	start_round()


## &"off" | &"lines" | &"lines_twists" (GameSettings.mod_live).
func mode() -> StringName:
	return Game.settings.mod_live if Game.settings != null else &"off"


## The AI chooses the twists itself (lines_twists, link healthy) → Game skips the offline Regie.
func replaces_regie() -> bool:
	return mode() == &"lines_twists" and status == &"ok"


## Tests / tools: use this provider (attached to this node) instead of the one the settings pick.
func set_provider(p: ModVoiceProvider) -> void:
	_forced = p != null
	_use(p)


## One round now: ModLiveSummary of the run → provider.request_turn. Returns the req_id ("" = not started).
func start_round() -> String:
	if provider == null or Game.state == null or Game.sim == null:
		return ""
	_req_seq += 1
	var req: String = "r_%06d" % _req_seq
	var batch: Dictionary = ModLiveSummary.build(Game.state, DB.data, Game.sim.rules, Game.sim.tick(),
		Game.in_battle, _events, recent_line_ids, req, run_ref, last_twist_result, Game._current_layout())
	_pending_req = req
	_pending_tick = Game.sim.tick()
	_last_round_tick = Game.sim.tick()
	_events = []
	_highlight = false
	rounds_started += 1
	_awaiting = true
	var got: String = provider.request_turn(batch)
	if got == "" and _awaiting:
		_pending_req = ""                     # not started (busy / too large): try again next round
		_awaiting = false
	return got


func _on_turn_ready(req_id: String, lines: Array, twist: Dictionary) -> void:
	if not _awaiting or req_id != _pending_req or Game.state == null or Game.sim == null:
		return
	_awaiting = false
	_pending_req = ""
	var age: int = Game.sim.tick() - _pending_tick
	for l: Variant in lines:
		if not (l is Dictionary):
			continue
		var d: Dictionary = l
		if age > MAX_AGE_SEC * TICKS_PER_SEC and str(d.get("tag", "")) != "evergreen":
			continue
		if Show.say_external(str(d.get("text", "")), StringName(str(d.get("voice", "mod"))), str(d.get("tag", "live"))):
			lines_shown += 1
			if str(d.get("line_id", "")) != "":
				recent_line_ids.append(str(d["line_id"]))
				if recent_line_ids.size() > MAX_RECENT:
					recent_line_ids = recent_line_ids.slice(recent_line_ids.size() - MAX_RECENT)
	if not twist.is_empty() and mode() == &"lines_twists" and age <= TWIST_VALID_SEC * TICKS_PER_SEC:
		var why: String = Game.apply_twist({"id": str(twist.get("id", "")), "params": twist.get("params", {}),
			"src": "mod_brain", "req": req_id})
		last_twist_result = "applied" if why == "" else why


func _on_status(s: StringName) -> void:
	if s == &"degraded":
		_fails += 1
		if _fails >= MAX_FAILS:
			_paused_until_ms = Time.get_ticks_msec() + int(FAIL_PAUSE_SEC * 1000.0)
			_fails = 0
	else:
		_fails = 0
	_set_status(s)


func _set_status(s: StringName) -> void:
	if s == status:
		return
	status = s
	Events.mod_live_status.emit(s)
	if s == &"ok" and not _said_on:
		_said_on = true
		Show.say("mod_live_on")


func _note(e: Dictionary) -> void:
	if Game.replaying or mode() == &"off":
		return
	_events.append(e)
	if _events.size() > ModLiveSummary.MAX_EVENTS * 2:
		_events = _events.slice(_events.size() - ModLiveSummary.MAX_EVENTS)
	if HIGHLIGHTS.has(str(e.get("t", ""))):
		_highlight = true


## New run: fresh pseudonym (random, never derived from the player), no history.
func _new_run(_slot: int) -> void:
	run_ref = "rr_" + Crypto.new().generate_random_bytes(8).hex_encode()
	recent_line_ids = []
	_events = []
	_highlight = false
	_last_round_tick = -1
	_pending_req = ""
	_awaiting = false
	last_twist_result = ""
	if provider is RemoteModVoice:
		(provider as RemoteModVoice).run_ref = run_ref


## The provider the settings ask for: off / no endpoint → ScriptedModVoice; endpoint + mode → RemoteModVoice.
func _ensure_provider() -> void:
	if _forced:
		return
	var url: String = Game.settings.mod_live_url if Game.settings != null else ""
	var remote: bool = mode() != &"off" and RemoteModVoice.valid_url(url)
	var key: String = ("remote:" + url) if remote else "scripted"
	if key == _provider_key and provider != null:
		return
	_provider_key = key
	if remote:
		var r: RemoteModVoice = RemoteModVoice.new(url)
		r.run_ref = run_ref
		_use(r)
	else:
		_use(ScriptedModVoice.new())


func _use(p: ModVoiceProvider) -> void:
	if provider != null:
		if provider.turn_ready.is_connected(_on_turn_ready):
			provider.turn_ready.disconnect(_on_turn_ready)
		if provider.status_changed.is_connected(_on_status):
			provider.status_changed.disconnect(_on_status)
	provider = p
	_pending_req = ""
	_awaiting = false
	if p != null:
		p.turn_ready.connect(_on_turn_ready)
		p.status_changed.connect(_on_status)
		p.attach(self)


func _read_cmdline() -> void:
	if not OS.is_debug_build() or Game.settings == null:
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mod-live-url="):
			Game.settings.mod_live_url = a.trim_prefix("--mod-live-url=")
			if Game.settings.mod_live == &"off":
				Game.settings.mod_live = &"lines"
		elif a.begins_with("--mod-live="):
			var m: StringName = StringName(a.trim_prefix("--mod-live="))
			if GameSettings.MOD_LIVE_MODES.has(m):
				Game.settings.mod_live = m
