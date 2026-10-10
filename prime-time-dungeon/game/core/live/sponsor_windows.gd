class_name SponsorWindows extends RefCounted
## Sponsor-Fenster (user decision 2026-10-08, 00_BRIEF §6b, 05 §6.13): spectators can help only a LIMITED number of
## times at SPECIFIC times. Deterministic in run ticks (RunSim), integers only, no clock. The state lives in
## GameState.flags["live"]["sponsor"] (part of StateHash and of the save) and is written only by RunSim (clock and
## the trigger commands floor / room / safe_room / safe_room_exit / sponsor_window, which Game forwards to the same
## functions) and by GiftPolicy.note_applied (slot booking at application). GiftPolicy.check → check() enforces it for
## every external gift — Show.receive_gift (reception and application) and RunSim.gift_refusal share that one rule.
##
## Windows (one at a time; rules.sponsor_windows of the event, DEFAULT_RULES for the campaign and events without it):
##   periodic  — every periodic.every_sec of EXPLORATION ticks (the first after periodic.first_sec), open
##               periodic.open_sec; skipped when another window is open at that moment
##   safe_room — on entering a safe room (once per safe room and floor with safe_room.once_per_room), open while inside,
##               at most safe_room.max_sec; the run clock keeps ticking in safe rooms ("idle ticks": no floor timer, no
##               hype decay, no strays) — so the limit is ticks, too
##   boss      — "Boss-Countdown": on the first entry of a quarter/floor boss room, boss.countdown_sec; after a LOST
##               boss attempt it opens once more on the next entry of that boss room ("Comeback-Fenster", 06 §6
##               decision 3, boss.comeback 1/0): on_battle_result marks the boss kind pending (state "comeback"
##               {"floor", "pending", "done"}), on_room opens the window with "comeback": true and moves it to done —
##               at most once per boss and floor, never after the boss is beaten. The campaign carries the mark over
##               the game over into the save slot (Save.record_game_over → merge_comeback).
##   dev       — QA command {"t": "sponsor_window", "op": "dev_open", "sec", "slots"} (rules.dev_open; never accepted
##               from clients by a server)
## A safe_room / boss / dev window supersedes an open window. Battles stop the run clock, so an open window freezes
## (gifts accepted during the battle wait for a turn boundary as before, 05 §6.10), no window opens and the periodic
## countdown pauses. A floor change closes the window and restarts the countdown.
## Every window has slots_per_player slots (first come, first served) and per_viewer gifts per sender_ref ("" =
## unknown sender, e.g. dev gifts: no per-viewer limit); exempt_kinds (cheer, cosmetic) need no window and take no slot.
## A gift stamped with a window id (field "sponsor_window": Show stamps it at acceptance, the gift service at its
## reservation, 05 §6.4) is still accepted grace_sec after that window closed — within that window's slots.
## Refusals (reason codes of Show.receive_gift / GiftPolicy.check → protocol codes 05 §4.5):
##   window_closed → E_WINDOW_CLOSED · window_full → E_WINDOW_FULL · window_sender_limit → E_WINDOW_SENDER_LIMIT

const TICKS_PER_SEC: int = 30          # == RunSim.TICKS_PER_SEC
const STATE_KEY: String = "sponsor"    # GameState.flags["live"][STATE_KEY]
## Key of the pending reservations in the `run` dictionary of check(): [[window_id, sender_ref], …] (Show's queue).
const PENDING_KEY: String = "sw_pending"
const KINDS: PackedStringArray = ["periodic", "safe_room", "boss", "dev"]
## 06-C: M.O.D. tag suffix of the comeback window ("sponsor_window_open:boss_comeback", live presentation only).
const COMEBACK_TAG: String = "boss_comeback"
const COMEBACK_KEY: String = "comeback"
const CLOSE_REASONS: PackedStringArray = ["time", "left", "superseded", "floor"]
const REASONS: PackedStringArray = ["window_closed", "window_full", "window_sender_limit"]
const PROTOCOL_CODES: Dictionary = {"window_closed": "E_WINDOW_CLOSED", "window_full": "E_WINDOW_FULL",
	"window_sender_limit": "E_WINDOW_SENDER_LIMIT"}
const DEV_MAX_SEC: int = 600
const DEV_MAX_SLOTS: int = 16
## Defaults for the campaign / offline runs and for every key an event leaves out (05 §10.1 rules.sponsor_windows).
const DEFAULT_RULES: Dictionary = {
	"enabled": true,
	"slots_per_player": 3,
	"per_viewer": 1,
	"grace_sec": 15,
	"exempt_kinds": ["cheer"],
	"periodic": {"enabled": true, "first_sec": 300, "every_sec": 300, "open_sec": 60},
	"safe_room": {"enabled": true, "max_sec": 90, "once_per_room": true},
	"boss": {"enabled": true, "countdown_sec": 45, "comeback": 1},   # 06-C: comeback 1 = once after a defeat
	"dev_open": true,
}
## Integer keys (validate): path → minimum.
const INT_KEYS: Dictionary = {"slots_per_player": 1, "per_viewer": 1, "grace_sec": 0, "periodic.first_sec": 1,
	"periodic.every_sec": 1, "periodic.open_sec": 1, "safe_room.max_sec": 1, "boss.countdown_sec": 1,
	"boss.comeback": 0}
## Integer keys with an upper bound (validate): path → maximum.
const INT_MAX: Dictionary = {"boss.comeback": 1}
const BOOL_KEYS: PackedStringArray = ["enabled", "dev_open", "periodic.enabled", "safe_room.enabled",
	"safe_room.once_per_room", "boss.enabled"]


## rules.sponsor_windows of event rules (or {}) merged over DEFAULT_RULES (nested dictionaries key by key).
static func rules_of(rules: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULT_RULES.duplicate(true)
	var src: Variant = rules.get("sponsor_windows", null)
	if src is Dictionary:
		_merge(out, src)
	return out


## Windows run for this run: rules.sponsor_windows.enabled, gifts enabled (rules.gifts / the run's stored gift rules)
## and not the Pur-Liga (L5: no viewer gifts at all → no windows). The campaign ({}) runs them with the defaults.
static func active(st: GameState, rules: Dictionary) -> bool:
	if st == null:
		return false
	if not bool(rules_of(rules).get("enabled", true)):
		return false
	var live: Dictionary = _live(st)
	var eff: Dictionary = rules
	if eff.is_empty() and live.get("gift_rules", null) is Dictionary:
		eff = {"gifts": live["gift_rules"]}
	if not bool(GiftPolicy.gift_rules(eff).get("enabled", true)):
		return false
	return GiftPolicy.run_league(live, eff) != "pur"


## The window state of the run ({} = windows not tracked).
static func state_of(st: GameState) -> Dictionary:
	if st == null:
		return {}
	var sw: Variant = _live(st).get(STATE_KEY, null)
	return sw if sw is Dictionary else {}


static func tracked(st: GameState) -> bool:
	return not state_of(st).is_empty()


## Creates the state when the windows are active for the run and it is missing (first floor / tick / old save).
## Returns it, {} when not active.
static func ensure(st: GameState, rules: Dictionary) -> Dictionary:
	var sw: Dictionary = state_of(st)
	if not sw.is_empty():
		return sw
	if not active(st, rules):
		return {}
	var swr: Dictionary = rules_of(rules)
	sw = {"seq": 0, "next_in": _first_ticks(swr), "open": {}, "last": {}, "rooms": [],
		"exempt": (swr["exempt_kinds"] as Array).duplicate() if swr["exempt_kinds"] is Array else []}
	GiftApplier.live_counters(st)[STATE_KEY] = sw
	return sw


# --- clock and triggers (RunSim) --------------------------------------------------------------------------------------

## One run tick. explore = exploration tick (periodic countdown runs), false = idle tick in a safe room. The open
## window and the grace of the last closed one count down on every run tick. Returns events
## {"type": "opened", "window": view} / {"type": "closed", "id", "kind", "reason"}.
static func tick(st: GameState, rules: Dictionary, explore: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sw: Dictionary = ensure(st, rules)
	if sw.is_empty():
		return out
	var open: Dictionary = _dict(sw, "open")
	if not open.is_empty():
		open["left"] = _int(open.get("left", 0)) - 1
		if _int(open["left"]) <= 0:
			_close(sw, rules, "time", out)
	var last: Dictionary = _dict(sw, "last")
	if not last.is_empty():
		last["grace"] = _int(last.get("grace", 0)) - 1
		if _int(last["grace"]) <= 0:
			sw["last"] = {}
	var swr: Dictionary = rules_of(rules)
	var periodic: Dictionary = swr["periodic"]
	if explore and bool(periodic.get("enabled", true)):
		sw["next_in"] = _int(sw.get("next_in", 0)) - 1
		if _int(sw["next_in"]) <= 0:
			sw["next_in"] = maxi(1, _int(periodic["every_sec"])) * TICKS_PER_SEC
			if _dict(sw, "open").is_empty():
				_open(sw, swr, rules, "periodic", "", _int(periodic["open_sec"]) * TICKS_PER_SEC,
					_int(swr["slots_per_player"]), out)
	return out


## Floor start ("floor" command): closes an open window, forgets the last one, restarts the periodic countdown and
## the safe rooms of the floor.
static func on_floor(st: GameState, rules: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sw: Dictionary = ensure(st, rules)
	if sw.is_empty():
		return out
	if not _dict(sw, "open").is_empty():
		_close(sw, rules, "floor", out)
	sw["last"] = {}
	sw["next_in"] = _first_ticks(rules_of(rules))
	sw["rooms"] = []
	sw.erase(COMEBACK_KEY)                     # 06-C: comeback marks belong to their floor
	return out


## Entering a safe room ("safe_room" command): a safe_room window for room_id (once per room and floor), unless that
## very window is already open (re-entry after loading a save).
static func on_safe_room_enter(st: GameState, rules: Dictionary, room_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sw: Dictionary = ensure(st, rules)
	var swr: Dictionary = rules_of(rules)
	var cfg: Dictionary = swr["safe_room"]
	if sw.is_empty() or not bool(cfg.get("enabled", true)) or room_id == "":
		return out
	var open: Dictionary = _dict(sw, "open")
	if str(open.get("kind", "")) == "safe_room" and str(open.get("ref", "")) == room_id:
		return out
	var rooms: Array = sw["rooms"] if sw.get("rooms", null) is Array else []
	if bool(cfg.get("once_per_room", true)) and rooms.has(room_id):
		return out
	rooms.append(room_id)
	sw["rooms"] = rooms
	_open(sw, swr, rules, "safe_room", room_id, _int(cfg["max_sec"]) * TICKS_PER_SEC, _int(swr["slots_per_player"]),
		out)
	return out


## Leaving the safe room ("safe_room_exit"): its window closes (reason "left").
static func on_safe_room_exit(st: GameState, rules: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sw: Dictionary = state_of(st)
	if not sw.is_empty() and str(_dict(sw, "open").get("kind", "")) == "safe_room":
		_close(sw, rules, "left", out)
	return out


## Entry of a room ("room" command): the first entry of a quarter/floor boss room opens the Boss-Countdown (ref = the
## cell kind); a later entry only while a comeback is due for that boss (06-C) — then, and on a first entry with a due
## comeback, the window carries "comeback": true and the mark is used up.
static func on_room(st: GameState, rules: Dictionary, kind: int, first: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind != RoomCell.Kind.QUARTER_BOSS and kind != RoomCell.Kind.FLOOR_BOSS:
		return out
	var comeback: bool = comeback_due(st, rules, kind)
	if not first and not comeback:
		return out
	var sw: Dictionary = ensure(st, rules)
	var swr: Dictionary = rules_of(rules)
	var cfg: Dictionary = swr["boss"]
	if sw.is_empty() or not bool(cfg.get("enabled", true)):
		return out
	var extra: Dictionary = {}
	if comeback:
		extra[COMEBACK_KEY] = true
		_use_comeback(sw, RoomCell.KIND_NAMES[kind])
	_open(sw, swr, rules, "boss", RoomCell.KIND_NAMES[kind], _int(cfg["countdown_sec"]) * TICKS_PER_SEC,
		_int(swr["slots_per_player"]), out, extra)
	return out


# --- 06-C: comeback window after a lost boss attempt (06 §6 decision 3) -----------------------------------------------

## After every battle (Game.apply_battle_result / RunSim._end_battle, after BattleBridge.apply_result): a lost battle
## against the floor's quarter / floor boss marks that boss kind pending (unless its comeback was used on this
## floor); a won one clears the mark. No-op when windows are not tracked or boss.comeback is 0.
static func on_battle_result(st: GameState, rules: Dictionary, data: GameData, result: BattleResult) -> void:
	var sw: Dictionary = state_of(st)
	if sw.is_empty() or result == null or not result.is_boss or st.floor_run == null:
		return
	var cfg: Dictionary = rules_of(rules)["boss"]
	if _int(cfg.get("comeback", 1)) < 1 or not bool(cfg.get("enabled", true)):
		return
	var kind: String = boss_kind_of(data, st.floor_run.index, result.encounter_id)
	if kind == "":
		return
	var cb: Dictionary = _comeback(sw, st.floor_run.index)
	var pending: Array = cb["pending"]
	if result.outcome == BattleResult.Outcome.DEFEAT:
		if not pending.has(kind) and not (cb["done"] as Array).has(kind):
			pending.append(kind)
	elif result.outcome == BattleResult.Outcome.VICTORY:
		pending.erase(kind)


## 06 §6 decision 4 (co-op, S4): one window per team (one broadcast), `slots_per_player` slots for EACH player — the
## team's window holds slots_per_player × players slots, so the best-known streamer cannot take them all; per_viewer
## stays per window and team (one viewer cannot gift every player). Solo runs: players = 1.
static func team_slots(rules: Dictionary, players: int) -> int:
	return maxi(1, _int(rules_of(rules)["slots_per_player"])) * maxi(1, players)


## True while a comeback is due for the boss room kind `kind` (RoomCell.Kind) on the current floor.
static func comeback_due(st: GameState, rules: Dictionary, kind: int) -> bool:
	if kind != RoomCell.Kind.QUARTER_BOSS and kind != RoomCell.Kind.FLOOR_BOSS:
		return false
	if st == null or st.floor_run == null:
		return false
	var cfg: Dictionary = rules_of(rules)["boss"]
	if _int(cfg.get("comeback", 1)) < 1 or not bool(cfg.get("enabled", true)):
		return false
	var cb: Variant = state_of(st).get(COMEBACK_KEY, null)
	if not (cb is Dictionary) or _int((cb as Dictionary).get("floor", 0)) != st.floor_run.index:
		return false
	var pending: Variant = (cb as Dictionary).get("pending", [])
	return pending is Array and (pending as Array).has(RoomCell.KIND_NAMES[kind])


## "quarter_boss" | "floor_boss" | "" for an encounter of floor `floor_index` (FloorDef.quarter_boss / floor_boss).
static func boss_kind_of(data: GameData, floor_index: int, encounter_id: String) -> String:
	var def: FloorDef = data.floor_def(floor_index) if data != null else null
	if def == null or encounter_id == "":
		return ""
	if encounter_id == def.quarter_boss:
		return RoomCell.KIND_NAMES[RoomCell.Kind.QUARTER_BOSS]
	if encounter_id == def.floor_boss:
		return RoomCell.KIND_NAMES[RoomCell.Kind.FLOOR_BOSS]
	return ""


## The comeback record of the run ({} = none) — Save.record_game_over carries it into the slot.
static func comeback_record(st: GameState) -> Dictionary:
	var cb: Variant = state_of(st).get(COMEBACK_KEY, null)
	return (cb as Dictionary).duplicate(true) if cb is Dictionary else {}


## Campaign game over (Save.record_game_over): the dying run's comeback record → the slot's saved state (raw save
## dictionary), when that save is on the same floor and tracks Sponsor-Fenster: its pending marks are added, its done
## marks too (a used comeback stays used — no farming by reloading). false = nothing to carry.
static func merge_comeback(saved_state: Dictionary, record: Dictionary) -> bool:
	if record.is_empty():
		return false
	var fr: Variant = saved_state.get("floor_run", null)
	if not (fr is Dictionary) or _int((fr as Dictionary).get("index", 0)) != _int(record.get("floor", 0)):
		return false
	var flags: Variant = saved_state.get("flags", null)
	var live: Variant = (flags as Dictionary).get("live", null) if flags is Dictionary else null
	var sw: Variant = (live as Dictionary).get(STATE_KEY, null) if live is Dictionary else null
	if not (sw is Dictionary) or (sw as Dictionary).is_empty():
		return false
	var cb: Dictionary = _comeback(sw, _int(record.get("floor", 0)))
	for key: String in ["pending", "done"]:
		var dst: Array = cb[key]
		var src: Variant = record.get(key, [])
		if src is Array:
			for k: Variant in (src as Array):
				if not dst.has(str(k)):
					dst.append(str(k))
	for k: Variant in (cb["done"] as Array):
		(cb["pending"] as Array).erase(k)
	return true


static func _comeback(sw: Dictionary, floor_index: int) -> Dictionary:
	var cb: Variant = sw.get(COMEBACK_KEY, null)
	if not (cb is Dictionary) or _int((cb as Dictionary).get("floor", 0)) != floor_index:
		cb = {"floor": floor_index, "pending": [], "done": []}
		sw[COMEBACK_KEY] = cb
	for key: String in ["pending", "done"]:
		if not ((cb as Dictionary).get(key, null) is Array):
			(cb as Dictionary)[key] = []
	return cb


static func _use_comeback(sw: Dictionary, kind_name: String) -> void:
	var cb: Variant = sw.get(COMEBACK_KEY, null)
	if not (cb is Dictionary):
		return
	((cb as Dictionary).get("pending", []) as Array).erase(kind_name)
	var done: Array = (cb as Dictionary).get("done", []) as Array
	if not done.has(kind_name):
		done.append(kind_name)
	(cb as Dictionary)["done"] = done


## QA: a dev window of `sec` seconds with `slots` slots (rules.dev_open). [] when not allowed / not tracked.
static func dev_open(st: GameState, rules: Dictionary, sec: int, slots: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not dev_allowed(st, rules, sec, slots):
		return out
	_open(ensure(st, rules), rules_of(rules), rules, "dev", "", sec * TICKS_PER_SEC, slots, out)
	return out


## Read-only (a refused command must not change the state).
static func dev_allowed(st: GameState, rules: Dictionary, sec: int, slots: int) -> bool:
	return bool(rules_of(rules).get("dev_open", false)) and sec >= 1 and sec <= DEV_MAX_SEC and slots >= 1 \
		and slots <= DEV_MAX_SLOTS and (tracked(st) or active(st, rules))


# --- gifts (GiftPolicy) -----------------------------------------------------------------------------------------------

## "" or the window refusal of the external gift `g` for the run counters `run` (flags.live, plus PENDING_KEY
## reservations of gifts accepted but not applied yet): not tracked / system / exempt kind → ""; no open window (or,
## for a stamped gift, neither its window open nor in grace) → window_closed; all slots used or reserved →
## window_full; the sender's gifts in this window reached per_viewer → window_sender_limit. Read-only.
static func check(run: Dictionary, g: Dictionary) -> String:
	var sw: Variant = run.get(STATE_KEY, null)
	if not (sw is Dictionary) or (sw as Dictionary).is_empty() or not needs_window(sw, g):
		return ""
	var w: Dictionary = _target(sw, g)
	if w.is_empty():
		return "window_closed"
	var wid: String = str(w.get("id", ""))
	var ref: String = _sender_ref(g)
	var pending_all: int = 0
	var pending_ref: int = 0
	var pending: Variant = run.get(PENDING_KEY, [])
	if pending is Array:
		for p: Variant in (pending as Array):
			if p is Array and (p as Array).size() >= 2 and str((p as Array)[0]) == wid:
				pending_all += 1
				if ref != "" and str((p as Array)[1]) == ref:
					pending_ref += 1
	if _int(w.get("used", 0)) + pending_all >= _int(w.get("slots", 0)):
		return "window_full"
	if ref != "":
		var senders: Dictionary = _dict(w, "senders")
		if _int(senders.get(ref, 0)) + pending_ref >= _int(w.get("per_viewer", 1)):
			return "window_sender_limit"
	return ""


## Books an applied external gift into its window (GiftPolicy.note_applied: once per gift id): used +1, sender +1.
static func book(run: Dictionary, g: Dictionary) -> void:
	var sw: Variant = run.get(STATE_KEY, null)
	if not (sw is Dictionary) or (sw as Dictionary).is_empty() or not needs_window(sw, g):
		return
	var w: Dictionary = _target(sw, g)
	if w.is_empty():
		return
	w["used"] = _int(w.get("used", 0)) + 1
	var ref: String = _sender_ref(g)
	if ref != "":
		if not (w.get("senders", null) is Dictionary):
			w["senders"] = {}
		var senders: Dictionary = w["senders"]
		senders[ref] = _int(senders.get(ref, 0)) + 1


## Id of the window an accepted gift belongs to ("" = needs none / not tracked): its stamp, else the open window.
static func window_for(run: Dictionary, g: Dictionary) -> String:
	var sw: Variant = run.get(STATE_KEY, null)
	if not (sw is Dictionary) or (sw as Dictionary).is_empty() or not needs_window(sw, g):
		return ""
	return str(_target(sw, g).get("id", ""))


## External, not exempt (state "exempt", copied from rules.sponsor_windows.exempt_kinds when the run started).
static func needs_window(sw: Dictionary, g: Dictionary) -> bool:
	if not Gift.is_external(g):
		return false
	var exempt: Variant = sw.get("exempt", [])
	return not (exempt is Array and (exempt as Array).has(str(g.get("kind", ""))))


static func protocol_code(reason: String) -> String:
	return str(PROTOCOL_CODES.get(reason, ""))


# --- views ------------------------------------------------------------------------------------------------------------

## UI/protocol view of the run's windows (JSON types only): {"tracked", "open", "id", "kind", "ref", "slots", "used",
## "free", "full", "per_viewer", "left_ticks", "len_ticks", "left_sec", "next_in_ticks", "next_in_sec"}.
## next_in_* = exploration ticks/seconds until the next periodic window (-1 = none scheduled); it pauses in battles
## and safe rooms. left_sec rounds up (a window with 1 tick left shows 0:01).
static func view(st: GameState, rules: Dictionary) -> Dictionary:
	var sw: Dictionary = state_of(st)
	var out: Dictionary = {"tracked": not sw.is_empty(), "open": false, "id": "", "kind": "", "ref": "", "slots": 0,
		"used": 0, "free": 0, "full": false, "per_viewer": 0, "left_ticks": 0, "len_ticks": 0, "left_sec": 0,
		"next_in_ticks": -1, "next_in_sec": -1}
	if sw.is_empty():
		return out
	var w: Dictionary = _dict(sw, "open")
	if not w.is_empty():
		out.merge(window_view(w), true)
	if bool((rules_of(rules)["periodic"] as Dictionary).get("enabled", true)):
		out["next_in_ticks"] = maxi(0, _int(sw.get("next_in", 0)))
		out["next_in_sec"] = (_int(out["next_in_ticks"]) + TICKS_PER_SEC - 1) / TICKS_PER_SEC
	return out


## View of one window record (signal payloads).
static func window_view(w: Dictionary) -> Dictionary:
	var slots: int = _int(w.get("slots", 0))
	var used: int = _int(w.get("used", 0))
	var left: int = maxi(0, _int(w.get("left", 0)))
	return {"open": true, "id": str(w.get("id", "")), "kind": str(w.get("kind", "")), "ref": str(w.get("ref", "")),
		"slots": slots, "used": used, "free": maxi(0, slots - used), "full": used >= slots,
		"per_viewer": _int(w.get("per_viewer", 1)), "left_ticks": left, "len_ticks": _int(w.get("len", 0)),
		"left_sec": (left + TICKS_PER_SEC - 1) / TICKS_PER_SEC, "comeback": bool(w.get(COMEBACK_KEY, false))}


# --- validation (EventDef) --------------------------------------------------------------------------------------------

## Problems of rules.sponsor_windows ({} / missing = defaults): known keys only, integers (>= minimum), bools,
## exempt_kinds ⊆ Gift.KINDS.
static func validate_rules(cfg: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	if cfg == null:
		return out
	if not (cfg is Dictionary):
		out.append("rules.sponsor_windows must be a Dictionary")
		return out
	_check_keys(cfg, DEFAULT_RULES, "rules.sponsor_windows", out)
	var merged: Dictionary = rules_of({"sponsor_windows": cfg})
	for path: String in INT_KEYS.keys():
		var v: Variant = _at(merged, path)
		if not _is_int(v) or int(v) < int(INT_KEYS[path]):
			out.append("rules.sponsor_windows.%s must be an integer >= %d" % [path, int(INT_KEYS[path])])
		elif INT_MAX.has(path) and int(v) > int(INT_MAX[path]):
			out.append("rules.sponsor_windows.%s must be <= %d" % [path, int(INT_MAX[path])])
	for path: String in BOOL_KEYS:
		if not (_at(merged, path) is bool):
			out.append("rules.sponsor_windows.%s must be a bool" % path)
	var ex: Variant = merged.get("exempt_kinds", [])
	if not (ex is Array):
		out.append("rules.sponsor_windows.exempt_kinds must be an Array")
	else:
		for k: Variant in (ex as Array):
			if not Gift.KINDS.has(str(k)):
				out.append("rules.sponsor_windows.exempt_kinds: unknown gift kind '%s'" % str(k))
	return out


# --- internals --------------------------------------------------------------------------------------------------------

static func _open(sw: Dictionary, swr: Dictionary, rules: Dictionary, kind: String, ref: String, len_ticks: int,
		slots: int, out: Array[Dictionary], extra: Dictionary = {}) -> void:
	if not _dict(sw, "open").is_empty():
		_close(sw, rules, "superseded", out)
	sw["seq"] = _int(sw.get("seq", 0)) + 1
	var w: Dictionary = {"id": "sw_%d" % _int(sw["seq"]), "kind": kind, "ref": ref, "slots": maxi(1, slots),
		"used": 0, "per_viewer": maxi(1, _int(swr["per_viewer"])), "senders": {}, "left": maxi(1, len_ticks),
		"len": maxi(1, len_ticks)}
	w.merge(extra, true)
	sw["open"] = w
	out.append({"type": "opened", "window": window_view(w)})


static func _close(sw: Dictionary, rules: Dictionary, reason: String, out: Array[Dictionary]) -> void:
	var w: Dictionary = _dict(sw, "open")
	sw["open"] = {}
	if w.is_empty():
		return
	var grace: int = maxi(0, _int(rules_of(rules)["grace_sec"])) * TICKS_PER_SEC
	if grace > 0:
		var last: Dictionary = w.duplicate(true)
		last["left"] = 0
		last["grace"] = grace
		sw["last"] = last
	else:
		sw["last"] = {}
	out.append({"type": "closed", "id": str(w.get("id", "")), "kind": str(w.get("kind", "")), "reason": reason})


## The window record a gift goes into: stamped → that window if open, or the last closed one within its grace;
## unstamped → the open window. {} = none.
static func _target(sw: Dictionary, g: Dictionary) -> Dictionary:
	var stamp: String = str(g.get("sponsor_window", ""))
	var open: Dictionary = _dict(sw, "open")
	if stamp == "":
		return open
	if not open.is_empty() and str(open.get("id", "")) == stamp:
		return open
	var last: Dictionary = _dict(sw, "last")
	if not last.is_empty() and str(last.get("id", "")) == stamp and _int(last.get("grace", 0)) > 0:
		return last
	return {}


static func _first_ticks(swr: Dictionary) -> int:
	var p: Dictionary = swr["periodic"]
	return maxi(1, _int(p.get("first_sec", p.get("every_sec", 300)))) * TICKS_PER_SEC


static func _live(st: GameState) -> Dictionary:
	var live: Variant = st.flags.get("live", {}) if st != null else {}
	return live if live is Dictionary else {}


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	return v if v is Dictionary else {}


static func _sender_ref(g: Dictionary) -> String:
	var s: Variant = g.get("sender", {})
	return str((s as Dictionary).get("sender_ref", "")) if s is Dictionary else ""


static func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k: Variant in src.keys():
		var key: String = str(k)
		if dst.get(key, null) is Dictionary and src[k] is Dictionary:
			_merge(dst[key], src[k])
		else:
			dst[key] = src[k].duplicate(true) if (src[k] is Dictionary or src[k] is Array) else src[k]


static func _check_keys(cfg: Dictionary, ref: Dictionary, path: String, out: PackedStringArray) -> void:
	for k: Variant in cfg.keys():
		var key: String = str(k)
		if not ref.has(key):
			out.append("%s: unknown key '%s'" % [path, key])
		elif ref[key] is Dictionary:
			if cfg[k] is Dictionary:
				_check_keys(cfg[k], ref[key], path + "." + key, out)
			else:
				out.append("%s.%s must be a Dictionary" % [path, key])


static func _at(d: Dictionary, path: String) -> Variant:
	var cur: Variant = d
	for part: String in path.split("."):
		if not (cur is Dictionary):
			return null
		cur = (cur as Dictionary).get(part, null)
	return cur


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
