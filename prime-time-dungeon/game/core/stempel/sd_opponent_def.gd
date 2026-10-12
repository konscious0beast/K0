class_name SdOpponentDef extends RefCounted
## One opponent of the Stempelduell rulebook (data/stempel/opponents.json, 10 §3, §2.7). Immutable after loading.
## The engine sees the opponent as the enemy `enm_<id>` (name = the id, 10 §6.4): Geduld, Zuständigkeiten
## (element_mods), immunities, the AI table in the engine's `ai` / `phases` format. Name, short name, role, file text
## and rule sentence are display only and never reach a hash.

var id: String = ""
var name: String = ""
var short: String = ""                      # ≤ 7 characters on the ticket display (10 §3.1, §4.3)
var role: String = ""
var akte: String = ""                       # file text before the duel (10 §4.7)
var rule: String = ""                       # the one new rule in one sentence (10 §3.1)
var symbol: String = ""
var geduld: int = 1
var element_mods: Dictionary = {}           # element → 1.5 (Wunder Punkt) / 0.5 (Nicht zuständig)
var status_immune: PackedStringArray = []
var deck: Dictionary = {}                   # card id → copies
var ai: Dictionary = {}
var phases: Array[Dictionary] = []
var first_win: Dictionary = {}              # {"cards": [...], "cosmetics": [...]} (10 §5.2)
var season_win: Dictionary = {}             # {"followers": int} (10 §5.3, SD3)
var unlock_after: String = ""               # opponent id that must be beaten first ("" = after the Lernduell)
var open_hand: bool = false                 # "Gegnerhand offen" default (the Graf: on, 10 §3.5)
var lines: String = ""                      # tag suffix of the opponent's lines (sd_opp_intro:<lines> …)


static func from_dict(d: Dictionary) -> SdOpponentDef:
	var o: SdOpponentDef = SdOpponentDef.new()
	o.id = str(d.get("id", ""))
	o.name = str(d.get("name", ""))
	o.short = str(d.get("short", ""))
	o.role = str(d.get("role", ""))
	o.akte = str(d.get("akte", ""))
	o.rule = str(d.get("rule", ""))
	o.symbol = str(d.get("symbol", ""))
	o.geduld = JsonUtil.to_int(d.get("geduld", 1), 1)
	o.element_mods = _dict(d.get("element_mods", {}))
	o.status_immune = JsonUtil.to_str_array(d.get("status_immune", []))
	var deck_raw: Dictionary = _dict(d.get("deck", {}))
	for k: Variant in deck_raw.keys():
		o.deck[str(k)] = JsonUtil.to_int(deck_raw[k])
	o.ai = _dict(d.get("ai", {"type": "weighted", "actions": []}))
	var ph: Variant = d.get("phases", [])
	for p: Variant in (ph as Array if ph is Array else []):
		if p is Dictionary:
			o.phases.append((p as Dictionary).duplicate(true))
	o.first_win = _dict(d.get("first_win", {}))
	o.season_win = _dict(d.get("season_win", {}))
	o.unlock_after = str(d.get("unlock_after", ""))
	o.open_hand = bool(d.get("open_hand", false))
	o.lines = str(d.get("lines", ""))
	return o


## Engine enemy id (`enm_<opponent id>`, 10 §6.4).
func enemy_id() -> String:
	return "enm_" + id


## The deck as a list: card ids sorted, each repeated by its count (a canonical order; the duel shuffles it).
func deck_list() -> PackedStringArray:
	var ids: PackedStringArray = []
	for k: Variant in deck.keys():
		ids.append(str(k))
	ids.sort()
	var out: PackedStringArray = []
	for cid: String in ids:
		for _i in maxi(0, JsonUtil.to_int(deck[cid])):
			out.append(cid)
	return out


## Element multiplier as printed on the plate (1.0 if the opponent has no Zuständigkeit for it).
func element_mult(element: String) -> float:
	return float(element_mods.get(element, 1.0))


## Cards of the first victory (10 §2.5).
func first_win_cards() -> PackedStringArray:
	return JsonUtil.to_str_array(first_win.get("cards", []))


func first_win_cosmetics() -> PackedStringArray:
	return JsonUtil.to_str_array(first_win.get("cosmetics", []))


## Every AI action list of the opponent: [ai.actions] for a weighted one, one list per phase for a phased one.
func action_lists() -> Array:
	if not phases.is_empty():
		var out: Array = []
		for p: Dictionary in phases:
			out.append(p.get("actions", []))
		return out
	return [ai.get("actions", [])]


static func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}
