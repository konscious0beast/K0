extends RefCounted
## Private M6 helper (§0.3): display data of offline events (05 CR-10) — event list via EventCatalog (M8), falling back
## to a read-only parse of data/events.json while the catalog is a stub; human-readable quest / rules texts.
## Display only: starting a run always goes through Game.start_event_run().

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const EVENTS_PATH: String = "res://data/events.json"
const KIND_NAMES: Dictionary = {"offline": "Offline-Event", "daily": "Tagesquote", "weekly": "Wochenshow",
	"live_show": "Live-Sendung", "special": "Großevent"}
const NAME_KEYS: Dictionary = {"evt_offline_gleis9_name": "Gleis-9-Räumung", "evt_saturday_show_name": "Samstagabend-Show",
	"evt_offline_pacifist_name": "Pazifist:in der Unterstadt"}
const METRIC_TEXT: Dictionary = {"viewers_target_peak": "Erreiche %s Zuschauer.",
	"followers_gained_run": "Gewinne %s Follower.", "hype_100_count": "Bringe den Hype %s× auf 100."}


## [{id, name, kind, kind_name, floor, quest, rules, scoring, seed}] — catalog first, raw JSON as fallback.
static func all_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var catalog: EventCatalog = EventCatalog.new()
	if catalog.load_file(EVENTS_PATH):
		for def: EventDef in catalog.all():
			if def != null and def.id != "":
				out.append(_from_def(def))
	if not out.is_empty():
		return out
	var text: String = FileAccess.get_file_as_string(EVENTS_PATH)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for e: Variant in (parsed as Dictionary).get("events", []):
		if typeof(e) == TYPE_DICTIONARY:
			out.append(_from_raw(e as Dictionary))
	return out


## Offline events only (S0 lobby).
static func offline_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in all_events():
		if str(e.get("kind", "")) == "offline":
			out.append(e)
	return out


static func find(event_id: String) -> Dictionary:
	if event_id == "":
		return {}
	for e: Dictionary in all_events():
		if str(e.get("id", "")) == event_id:
			return e
	return {}


static func _from_def(def: EventDef) -> Dictionary:
	return {"id": def.id, "name": event_name(def.name_key, def.id), "kind": def.kind,
		"kind_name": str(KIND_NAMES.get(def.kind, def.kind)), "floor": def.floor_index, "quest": def.quest,
		"rules": def.rules, "scoring": def.scoring, "seed": int(def.seed_policy.get("run_seed", 0)),
		"seed_type": str(def.seed_policy.get("type", ""))}


static func _from_raw(d: Dictionary) -> Dictionary:
	var sp: Dictionary = d.get("seed_policy", {}) if typeof(d.get("seed_policy", {})) == TYPE_DICTIONARY else {}
	var kind: String = str(d.get("kind", "offline"))
	return {"id": str(d.get("id", "")), "name": event_name(str(d.get("name_key", "")), str(d.get("id", ""))),
		"kind": kind, "kind_name": str(KIND_NAMES.get(kind, kind)), "floor": int(d.get("floor", 1)),
		"quest": d.get("quest", {}), "rules": d.get("rules", {}), "scoring": d.get("scoring", {}),
		"seed": int(sp.get("run_seed", 0)), "seed_type": str(sp.get("type", ""))}


## tr(name_key); untranslated keys → known German titles → humanized id.
static func event_name(name_key: String, event_id: String) -> String:
	if name_key != "":
		var t: String = TranslationServer.translate(name_key)
		if t != name_key:
			return t
		if NAME_KEYS.has(name_key):
			return str(NAME_KEYS[name_key])
	var s: String = event_id.trim_prefix("evt_").replace("offline_", "").replace("_", " ")
	return s.capitalize() if s != "" else "Event"


## Quest dictionary (05 §1.3) → German sentence.
static func quest_text(q: Dictionary) -> String:
	var params: Dictionary = q.get("params", {}) if typeof(q.get("params", {})) == TYPE_DICTIONARY else {}
	match str(q.get("type", "")):
		"reach_stairs":
			return "Erreiche die Treppe von Etage %d." % int(params.get("floor", 1))
		"defeat_boss":
			return "Besiege %s." % _enemy_name(str(params.get("boss_id", "")))
		"bounty":
			return "Besiege %d× %s." % [int(params.get("count", 1)), _enemy_name(str(params.get("enemy_id", "")))]
		"hype_peak":
			var metric: String = str(params.get("metric", "viewers_target_peak"))
			return str(METRIC_TEXT.get(metric, "Erreiche %s.")) % UiUtil.fmt_int(int(params.get("target", 0)))
		"pacifist":
			var sub: Dictionary = params.get("then", {}) if typeof(params.get("then", {})) == TYPE_DICTIONARY else {}
			return "Höchstens %d Kämpfe – %s" % [int(params.get("max_battles", 0)), quest_text(sub)]
		"achievement_hunt":
			var ids: Array = params.get("ids", [])
			var names: PackedStringArray = []
			for id: Variant in ids:
				names.append(UiUtil.tr_text(DB.achievement(str(id)).name) if DB.has_id("achievements", str(id))
					else str(id).trim_prefix("ach_").replace("_", " ").capitalize())
			return "Schalte %d von %d Achievements frei: %s." % [int(params.get("min", ids.size())), ids.size(),
				", ".join(names)]
		"all_of":
			var parts: PackedStringArray = []
			for sub: Variant in params.get("quests", []):
				if typeof(sub) == TYPE_DICTIONARY:
					parts.append(quest_text(sub as Dictionary).trim_suffix("."))
			return " + ".join(parts) + "."
	return "Überlebe die Sendung."


static func _enemy_name(id: String) -> String:
	for cand: String in [id, "enm_" + id]:
		if DB.has_id("enemies", cand):
			return UiUtil.tr_text(DB.enemy(cand).name)
	var s: String = id.trim_prefix("enm_").trim_prefix("boss_").replace("_", " ")
	return s.capitalize() if s != "" else "den Boss"


## Rule lines for the lobby card.
static func rule_lines(info: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var rules: Dictionary = info.get("rules", {}) if typeof(info.get("rules", {})) == TYPE_DICTIONARY else {}
	var timer: int = int(rules.get("floor_timer_sec", 0))
	if timer > 0:
		out.append("Etagen-Timer %s (läuft nur in der Erkundung)" % UiUtil.fmt_time(timer) if str(rules.get(
			"timer_mode", "explore_only")) == "explore_only" else "Etagen-Timer %s (Echtzeit)" % UiUtil.fmt_time(timer))
	var leagues: Array = rules.get("leagues", ["pur"])
	if leagues.has("pur") and leagues.size() == 1:
		out.append("Pur-Liga – keine Zuschauer-Geschenke")
	elif leagues.has("show"):
		out.append("Show-Liga oder Pur-Liga (Wahl vor dem Lauf)")
	out.append("Solo: Kai + Graf Mopsula, Startausrüstung" if str(rules.get("mode", "solo")) == "solo"
		else "Koop (2–4)")
	if str(info.get("seed_type", "")) == "fixed":
		out.append("Fester Seed #%d – alle spielen dieselbe Etage" % int(info.get("seed", 0)))
	var attempts: Dictionary = rules.get("attempts", {}) if typeof(rules.get("attempts", {})) == TYPE_DICTIONARY else {}
	if bool(attempts.get("practice", false)):
		out.append("Versuche: unbegrenzt, lokale Bestenliste")
	return out


## Local top entries (Save.load_leaderboard → Leaderboard.top), fallback raw "entries".
static func leaderboard(event_id: String, n: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Dictionary = Save.load_leaderboard(event_id)
	var board: Leaderboard = Leaderboard.from_dict(raw)
	if board != null:
		out = board.top(n)
	if out.is_empty():
		for e: Variant in raw.get("entries", []):
			if typeof(e) == TYPE_DICTIONARY:
				out.append(e as Dictionary)
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("score", 0)) > int(b.get("score", 0)))
		out = out.slice(0, n)
	return out


## Entry → display name of the first player.
static func entry_name(e: Dictionary) -> String:
	var players: Array = e.get("players", [])
	if not players.is_empty() and typeof(players[0]) == TYPE_DICTIONARY:
		return str((players[0] as Dictionary).get("display_name", "Kai"))
	return "Kai"
