class_name GiftPolicy extends RefCounted
## Caps and diminishing effect of external gifts, integers only (05 §6.10, L4/L5).
##
## effect_pm(load_half) = 1000000 // (1000 + effect_k_pm × load_half)   (k = 75 ≙ 0.15 per load point)
## rolls = max(1, (base_rolls × effect_pm + 500) // 1000);  credits = (amount × effect_pm + 500) // 1000
##
## `rules` is either the event rules (with "leagues" and "gifts", data/events.json → rules) or the gift rules alone
## (rules.gifts); {} means the Show-league standard caps below (campaign / debug builds).
## `run` = gift counters of the run, GameState.flags["live"] (05 §6.9):
##   "league": String, "gift_rules": Dictionary  — written by RunSim for event runs (the run's league and rules.gifts)
##   "gift_ids": Array[String]                   — every applied external gift (Show)
##   "load_half", "external", "chests", "gold_chests": int, "per_sender": {sender_ref: int}, "counted": Array[String]
##                                               — applied external gifts (note_applied, idempotent per gift id)
##   "gift_items": {item_id: int}                — items received from gifts (GiftApplier, statistics, L3)
##   optional "gift_accept": "all" | "free_only" | "ask" | "none" (05 §6.11), "tick": int (client-sim deadline)

## Show-league standard (05 §6.10 / §10.1 rules.gifts).
const DEFAULT_GIFT_RULES: Dictionary = {
	"enabled": true, "load_cap_half": 48, "max_external": 16, "max_chests": 8, "max_gold_chests": 2,
	"min_interval_sec": 45, "sale_close_buffer_sec": 120, "max_per_battle": 1, "per_buyer_per_target": 5,
	"load_weights_half": {"cheer": 0, "gold_per_100": 1, "fan_pack": 2, "sponsor_buff": 2, "bronze": 2, "silver": 4,
		"gold": 8},
	"effect_k_pm": 75, "chest_min_effect_pm": 500,
}
## Sources whose load basis is stamped by the gift service at reservation (checked against the applied load).
const SERVICE_SOURCES: PackedStringArray = ["fan", "bits", "shop"]


static func effect_pm(load_half: int, k_pm: int = 75) -> int:
	return 1000000 / (1000 + maxi(0, k_pm) * maxi(0, load_half))


## Load weight in half points of one gift (05 §6.10): cheer 0 · gold 1 per (started) 100 credits · fan_pack 2 ·
## sponsor_buff 2 · chest bronze 2 / silver 4 / gold 8. System gifts weigh nothing. {} → standard weights.
static func load_weight_half(g: Dictionary, weights_half: Dictionary) -> int:
	if not Gift.is_external(g):
		return 0
	var w: Dictionary = weights_half if not weights_half.is_empty() else DEFAULT_GIFT_RULES["load_weights_half"]
	match str(g.get("kind", "")):
		"cheer":
			return _int(w.get("cheer", 0))
		"gold":
			var hundreds: int = (maxi(0, _int(g.get("amount", 0))) + 99) / 100
			return _int(w.get("gold_per_100", 1)) * hundreds
		"fan_pack":
			return _int(w.get("fan_pack", 2))
		"sponsor_buff":
			return _int(w.get("sponsor_buff", 2))
		"chest":
			return _int(w.get(str(g.get("tier", "bronze")), 0))
	return 0


static func rolls_for(base_rolls: int, effect_pm: int) -> int:
	return maxi(1, (base_rolls * effect_pm + 500) / 1000)


## (value * effect_pm + 500) / 1000 — for value >= 0 (credits, percentages, hype bonus).
static func scale(value: int, effect_pm: int) -> int:
	return (value * effect_pm + 500) / 1000


## Chests may be bought / delivered only while effect_pm(load_half) >= chest_min_effect_pm (default 500: blocked from
## load_half 14 on).
static func chest_allowed(load_half: int, rules: Dictionary) -> bool:
	var gr: Dictionary = gift_rules(rules)
	return effect_pm(load_half, _int(gr["effect_k_pm"])) >= _int(gr["chest_min_effect_pm"])


## run = gift counters of the run (GameState.flags["live"]); "" = allowed. Order: system → "" · league (Pur-Liga,
## L5) → league_pur · gifts disabled / source not offered / gift_accept → not_accepting · client-sim deadline →
## deadline_missed · effect factor (effect_pm == effect_pm(load_half); service gifts: load_half >= applied load) →
## effect_mismatch · caps (load, external count, chests, gold chests, per sender) → cap_reached · chest threshold →
## chest_blocked. The per-battle cap is no rejection (Show queues, see can_deliver_in_battle).
static func check(run: Dictionary, g: Dictionary, rules: Dictionary) -> String:
	if not Gift.is_external(g):
		return ""
	var eff: Dictionary = rules if not rules.is_empty() else _run_rules(run)
	var gr: Dictionary = gift_rules(eff)
	var source: String = str(g.get("source", ""))
	var kind: String = str(g.get("kind", ""))
	if run_league(run, eff) == "pur" or str(g.get("league", "")) == "pur":
		return "league_pur"
	if not bool(gr.get("enabled", true)):
		return "not_accepting"
	var sources: Variant = gr.get("sources", null)
	if source != "dev" and sources is Array and not (sources as Array).has(source):
		return "not_accepting"
	match str(run.get("gift_accept", "all")):
		"none":
			return "not_accepting"
		"free_only":
			if kind == "chest" and Gift.PAID_SOURCES.has(source):
				return "not_accepting"
	var deadline: int = _int(g.get("deliver_by_tick", 0))
	if deadline > 0 and run.has("tick") and _int(run["tick"]) > deadline:
		return "deadline_missed"
	var k_pm: int = _int(gr["effect_k_pm"])
	var basis: int = _int(g.get("load_half", 0))
	var applied: int = _int(run.get("load_half", 0))
	if _int(g.get("effect_pm", 0)) != effect_pm(basis, k_pm):
		return "effect_mismatch"
	if SERVICE_SOURCES.has(source) and basis < applied:
		return "effect_mismatch"
	if kind != "cheer":
		var weight: int = load_weight_half(g, gr["load_weights_half"])
		if applied + weight > _int(gr["load_cap_half"]):
			return "cap_reached"
		if _int(run.get("external", 0)) + 1 > _int(gr["max_external"]):
			return "cap_reached"
		var sender_ref: String = _sender_ref(g)
		var per_sender: Variant = run.get("per_sender", {})
		if sender_ref != "" and per_sender is Dictionary \
				and _int((per_sender as Dictionary).get(sender_ref, 0)) + 1 > _int(gr["per_buyer_per_target"]):
			return "cap_reached"
	if kind == "chest":
		if _int(run.get("chests", 0)) + 1 > _int(gr["max_chests"]):
			return "cap_reached"
		if str(g.get("tier", "")) == "gold" and _int(run.get("gold_chests", 0)) + 1 > _int(gr["max_gold_chests"]):
			return "cap_reached"
		if not chest_allowed(maxi(basis, applied), gr):
			return "chest_blocked"
	return ""


# --- additions (M8 helpers) ----------------------------------------------------------------------------------------

## Gift rules with every missing key filled from DEFAULT_GIFT_RULES. Accepts event rules ({"gifts": …}) or the gift
## rules themselves.
static func gift_rules(rules: Dictionary) -> Dictionary:
	var src: Dictionary = rules
	if rules.get("gifts", null) is Dictionary:
		src = rules["gifts"]
	var out: Dictionary = DEFAULT_GIFT_RULES.duplicate(true)
	for k: Variant in src.keys():
		out[str(k)] = src[k]
	if not (out["load_weights_half"] is Dictionary):
		out["load_weights_half"] = DEFAULT_GIFT_RULES["load_weights_half"].duplicate(true)
	return out


## The run's league: run["league"] (RunSim, event runs) → single league of the rules → "" (campaign, unrestricted).
static func run_league(run: Dictionary, rules: Dictionary) -> String:
	if str(run.get("league", "")) != "":
		return str(run["league"])
	var leagues: Variant = rules.get("leagues", null)
	if leagues is Array and (leagues as Array).size() == 1:
		return str((leagues as Array)[0])
	return ""


## External gifts may be handed out at a turn boundary while fewer than max_per_battle (1) were delivered in this
## battle; further ones wait until the battle ends (05 §6.10).
static func can_deliver_in_battle(external_in_battle: int, rules: Dictionary) -> bool:
	return external_in_battle < _int(gift_rules(rules)["max_per_battle"])


## Books an applied external gift into the run counters (idempotent per gift id; system gifts are ignored).
static func note_applied(run: Dictionary, g: Dictionary, rules: Dictionary) -> void:
	if not Gift.is_external(g):
		return
	var gid: String = str(g.get("gift_id", ""))
	if not (run.get("counted", null) is Array):
		run["counted"] = []
	var counted: Array = run["counted"]
	if gid != "" and counted.has(gid):
		return
	if gid != "":
		counted.append(gid)
	var eff: Dictionary = rules if not rules.is_empty() else _run_rules(run)
	var gr: Dictionary = gift_rules(eff)
	var kind: String = str(g.get("kind", ""))
	run["load_half"] = _int(run.get("load_half", 0)) + load_weight_half(g, gr["load_weights_half"])
	if kind != "cheer":
		run["external"] = _int(run.get("external", 0)) + 1
		var sender_ref: String = _sender_ref(g)
		if sender_ref != "":
			if not (run.get("per_sender", null) is Dictionary):
				run["per_sender"] = {}
			var ps: Dictionary = run["per_sender"]
			ps[sender_ref] = _int(ps.get(sender_ref, 0)) + 1
	if kind == "chest":
		run["chests"] = _int(run.get("chests", 0)) + 1
		if str(g.get("tier", "")) == "gold":
			run["gold_chests"] = _int(run.get("gold_chests", 0)) + 1


static func _run_rules(run: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if run.get("gift_rules", null) is Dictionary:
		out["gifts"] = run["gift_rules"]
	return out


static func _sender_ref(g: Dictionary) -> String:
	var s: Variant = g.get("sender", {})
	return str((s as Dictionary).get("sender_ref", "")) if s is Dictionary else ""


static func _int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and is_finite(float(v)):
		return int(v)
	return 0
