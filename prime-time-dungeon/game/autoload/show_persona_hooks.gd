extends RefCounted
## Private helper of the Show autoload (no class_name, preloaded by show.gd): the persona hooks H2–H5, H7 (08 §4.3).
## At most one persona line per hook event, chosen by the run's broadcast plan (PersonaBeats, deterministic from the
## seed); the lines are Show.say lines (persona_* are always said and skip the cooldown, ModAnnouncer). Nothing without
## a persona (Game.persona null: tests, autoplay, event runs), nothing in replays (Show.say is silent there), never in
## a battle (CTB and real-time, R6): H3 waits until the battle is over and the exploration runs again, and every
## waiting line is dropped when a battle starts. Waiting lines: H3 "boss won" → the next exploration second; H4 "safe
## room" → right after the safe room's safe_room_enter line; H7 "marotte" → right after floor_start (before M.O.D.
## announces the preferences). Also the line-pool provider of ModAnnouncer (R15): the candidate's AI lines (K3,
## persona file → ai.lines, filtered on load) for their hook with weight 2, each at most once per floor.

## A "line" slot uses its variant tag (persona_boss_won:<org>, …) or the general tag — 50 : 50 (presentation RNG), so
## the general lines of a hook stay in rotation.
const VARIANT_CHANCE: float = 0.5
## AI line hook → the persona tag whose pool it joins (08 §4.10; "card" is the card screen's, the intro and game over
## are screens that read lines directly — K3).
const AI_POOLS: Dictionary = {"first_chest": "persona_first_chest", "safe_room": "persona_safe_room",
	"floor_end": "persona_floor_end"}

var show: Node = null                      # the Show autoload
## Waiting lines: {"tag", "ctx", "after": the tag of the line they follow ("" = the next exploration second)}.
var _pending: Array[Dictionary] = []
var _ai_used: Dictionary = {}              # "<floor>:<line index>" → true
## Tags this helper said (presentation; tests and the full-run bot read it).
var said: PackedStringArray = []


func _init(p_show: Node) -> void:
	show = p_show


## New game / loaded save: nothing waits, the AI lines are fresh.
func reset() -> void:
	_pending.clear()
	_ai_used.clear()
	said.clear()


## A persona exists and the campaign runs live (not replaying).
func active() -> bool:
	return Game.persona != null and Game.state != null and Game.state.floor_run != null \
		and Game.mode == &"campaign" and not Game.replaying


## The run's broadcast plan.
func plan() -> String:
	return PersonaBeats.plan_for(DB.data, Game.state.seed) if Game.state != null else ""


## H2: the first chest of the floor was opened (exploration).
func on_chest(_chest_id: String) -> void:
	if not active() or Game.state.floor_run.opened_chests.size() != 1:
		return
	_say(_tag(&"first_chest", 1), {})


## H3: a boss was defeated — the line waits until the battle is over (the next exploration second). Its ordinal is
## the number of the floor's bosses (quarter / floor boss) defeated so far; other bosses count 0.
func on_boss_won(boss_id: String) -> void:
	if not active():
		return
	var fr: FloorRun = Game.state.floor_run
	var def: FloorDef = DB.floor_def(fr.index)
	var n: int = 0
	if def != null and boss_id != "" and _is_floor_boss(def, boss_id):
		n = int(fr.quarter_boss_defeated) + int(fr.floor_boss_defeated)
	_queue(_tag(&"boss_won", n), {}, "")


## H4: first visit of a safe room — ordinal = the n-th safe room visited on the floor; waits for safe_room_enter.
func on_safe_room(_safe_room_id: String) -> void:
	if not active():
		return
	_queue(_tag(&"safe_room", Game.state.floor_run.visited_safe_rooms.size()), {}, "safe_room_enter")


## H5: the floor was completed (right after floor_end).
func on_floor_end(_floor_index: int) -> void:
	if not active():
		return
	_say(_tag(&"floor_end", 1), {})


## H7: from floor BIAS_MIN_FLOOR, when one of today's preferences was weighted by the card (08 §4.8), M.O.D. says
## persona_marotte with that trait right after floor_start — before she announces the preferences.
func on_floor_start(floor_index: int) -> void:
	if not active() or floor_index < PersonaRules.BIAS_MIN_FLOOR or Game.state.show == null:
		return
	var bias: PackedStringArray = PersonaRules.bias(Game.state)
	for id: String in JsonUtil.to_str_array(Game.state.show.marotten.get("active", [])):
		if not bias.has(id):
			continue
		var tag: String = PersonaBeats.tag_for(DB.data, Game.persona, plan(), floor_index, &"floor_start", 1)
		if tag != "":
			_queue(tag, {"trait": _trait_for(id)}, "floor_start")
		return


## Show.say calls this after every line it said (after mod_said reached every listener, so the HUD queues the waiting
## line behind it): lines waiting for this tag are said now.
func on_said(tag: String) -> void:
	if _pending.is_empty() or tag.begins_with("persona_"):
		return
	var keep: Array[Dictionary] = []
	var due: Array[Dictionary] = []
	for p: Dictionary in _pending:
		(due if str(p["after"]) == tag else keep).append(p)
	_pending = keep
	for p: Dictionary in due:
		_say(str(p["tag"]), p["ctx"])


## One exploration second (Show forwards Events.explore_tick): lines waiting for the battle end are said; lines that
## waited for another line and missed it are dropped.
func on_explore_tick() -> void:
	if _pending.is_empty() or Game.in_battle:
		return
	var due: Array[Dictionary] = []
	for p: Dictionary in _pending:
		if str(p["after"]) == "":
			due.append(p)
	_pending.clear()
	for p: Dictionary in due:
		_say(str(p["tag"]), p["ctx"])


## A battle starts: waiting persona lines are dropped (08 §4.3 "nie im Kampf").
func drop_pending() -> void:
	_pending.clear()


## Waiting lines (tests).
func pending_tags() -> PackedStringArray:
	var out: PackedStringArray = []
	for p: Dictionary in _pending:
		out.append(str(p["tag"]))
	return out


## ModAnnouncer's line-pool provider (R15): the candidate's AI lines of the tag's hook as ModLineDefs (weight 2 in
## ModAnnouncer), only for the general tag of a hook (never a variant or a beat), never in a battle, each at most once
## per floor (an offered line counts as used).
func extra_lines(tag: String) -> Array:
	var out: Array = []
	if Game.persona == null or Game.in_battle or Game.state == null or tag.contains(":"):
		return out
	var lines: Variant = Game.persona.ai.get("lines", [])
	if not (lines is Array) or (lines as Array).is_empty():
		return out
	var hidden: Array = Game.persona.ai.get("hidden", []) if Game.persona.ai.get("hidden", []) is Array else []
	var floor_index: int = Game.state.floor_run.index if Game.state.floor_run != null else 1
	for i in (lines as Array).size():
		var l: Variant = (lines as Array)[i]
		if not (l is Dictionary) or hidden.has(i) or str(AI_POOLS.get(str((l as Dictionary).get("hook", "")), "")) != tag:
			continue
		var key: String = "%d:%d" % [floor_index, i]
		if _ai_used.has(key):
			continue
		_ai_used[key] = true
		out.append(ModLineDef.from_dict({"id": "mod_persona_ai_%d" % i, "tag": tag,
			"voice": str((l as Dictionary).get("voice", "mod")), "text": str((l as Dictionary).get("text", ""))}))
	return out


# --- internals --------------------------------------------------------------------------------------------------------

## The plan's tag of a hook event on the current floor; a "line" variant (…:<org> / …:<hob>) falls back to the
## general tag half of the time.
func _tag(hook: StringName, ordinal: int) -> String:
	var floor_index: int = Game.state.floor_run.index
	var tag: String = PersonaBeats.tag_for(DB.data, Game.persona, plan(), floor_index, hook, ordinal)
	var line: String = PersonaBeats.line_tag(Game.persona, String(hook))
	if tag != "" and tag == line and tag.contains(":") and _rng().randf() < VARIANT_CHANCE:
		tag = tag.get_slice(":", 0)
	return tag


func _queue(tag: String, ctx: Dictionary, after: String) -> void:
	if tag != "":
		_pending.append({"tag": tag, "ctx": ctx, "after": after})


func _say(tag: String, ctx: Dictionary) -> void:
	if tag == "" or Game.in_battle or not active():
		return
	if str(show.call("say", tag, ctx)) != "":
		said.append(tag)


## The trait of the card whose bias is `marotte_id` ({trait} of persona_marotte).
func _trait_for(marotte_id: String) -> String:
	for t: String in Game.persona.traits:
		var d: Dictionary = DB.data.trait_def(t)
		if str(d.get("bias", "")) == marotte_id:
			return str(d.get("name", ""))
	return str(PersonaText.FALLBACK["trait"])


func _is_floor_boss(def: FloorDef, boss_id: String) -> bool:
	for enc: String in [def.quarter_boss, def.floor_boss]:
		if enc != "" and DB.data.has_id("encounters", enc):
			for e: Variant in DB.data.encounter(enc).enemies:
				if str(e) == boss_id:
					return true
	return false


func _rng() -> RandomNumberGenerator:
	var r: Variant = show.get("_fx_rng") if show != null else null
	return r as RandomNumberGenerator if r is RandomNumberGenerator else RandomNumberGenerator.new()
