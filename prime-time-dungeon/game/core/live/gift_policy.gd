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
##   "gift_ids": Array[String]                   — every applied external gift (remember(): Show, RunSim)
##   "load_half", "external", "chests", "gold_chests": int, "per_sender": {sender_ref: int}
##                                               — applied external gifts (note_applied, exactly once per gift)
##   "gift_items": {item_id: int}                — items received from gifts (GiftApplier, statistics, L3)
##   "last_delivery_tick": int                   — run tick of the last service gift (fan/shop/bits, min_interval_sec)
##   optional "gift_accept": "all" | "free_only" | "ask" | "none" (05 §6.11)
##   only in the copy passed to check() (refusal() merges them in): "tick": int (run clock: deadline, interval),
##   "run_id" / "event_id" / "player_id" / "window_id": String (run identity, wrong_target — "" = unknown)
##   "sponsor": Dictionary                       — Sponsor-Fenster state (SponsorWindows, 05 §6.13); plus, only in the
##                                                 copy Show passes to check(), "sw_pending": [[window_id, sender_ref]]

## Show-league standard (05 §6.10 / §10.1 rules.gifts).
const DEFAULT_GIFT_RULES: Dictionary = {
	"enabled": true, "load_cap_half": 48, "max_external": 16, "max_chests": 8, "max_gold_chests": 2,
	"min_interval_sec": 45, "sale_close_buffer_sec": 120, "max_per_battle": 1, "per_buyer_per_target": 5,
	"load_weights_half": {"cheer": 0, "gold_per_100": 1, "fan_pack": 2, "sponsor_buff": 2, "bronze": 2, "silver": 4,
		"gold": 8},
	"effect_k_pm": 75, "chest_min_effect_pm": 500,
}
## Sources whose load basis is stamped by the gift service at reservation (checked against the applied load); they
## also keep the minimum interval between two deliveries (min_interval_sec, 05 §6.10). "dev" (QA) does neither.
const SERVICE_SOURCES: PackedStringArray = ["fan", "bits", "shop"]
## Kinds without game effect: no minimum interval (like the Sponsor-Fenster exempt_kinds).
const INTERVAL_EXEMPT_KINDS: PackedStringArray = ["cheer"]
const TICKS_PER_SEC: int = 30            # == RunSim.TICKS_PER_SEC (min_interval_sec × 30 ticks)


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


## run = gift counters of the run (GameState.flags["live"]) plus "tick" and the run identity; "" = allowed. Order:
## system → "" · league (Pur-Liga, L5) → league_pur; a multi-league event without the run's league → not_accepting ·
## run binding (target run_id / player_id, event_id, window_id against the run's, where both are known, 05 §6.9) →
## wrong_target · gifts disabled / source not offered (rules.gifts.sources; without the key: every source, except that
## "dev" needs an explicit listing in event rules — rules with "leagues"; the campaign accepts it) / gift_accept →
## not_accepting · client-sim
## deadline → deadline_missed · effect factor (effect_pm == effect_pm(load_half); service gifts: load_half >= applied
## load) → effect_mismatch · minimum interval of service gifts (min_interval_sec since last_delivery_tick) → too_soon ·
## caps (load, external count, chests, gold chests, per sender) → cap_reached · chest threshold → chest_blocked ·
## Sponsor-Fenster (SponsorWindows.check: only while the run tracks windows) → window_closed | window_full |
## window_sender_limit — last, so a window refusal always means "everything else is fine, wait for the next window".
## The per-battle cap is no rejection (Show queues, see can_deliver_in_battle).
static func check(run: Dictionary, g: Dictionary, rules: Dictionary) -> String:
	if not Gift.is_external(g):
		return ""
	var eff: Dictionary = rules if not rules.is_empty() else _run_rules(run)
	var gr: Dictionary = gift_rules(eff)
	var source: String = str(g.get("source", ""))
	var kind: String = str(g.get("kind", ""))
	var league: String = run_league(run, eff)
	if league == "pur" or str(g.get("league", "")) == "pur":
		return "league_pur"
	var leagues: Variant = eff.get("leagues", null)
	if league == "" and leagues is Array and (leagues as Array).size() > 1:
		return "not_accepting"
	if _wrong_target(run, g):
		return "wrong_target"
	if not bool(gr.get("enabled", true)):
		return "not_accepting"
	var sources: Variant = gr.get("sources", null)
	if sources is Array:
		if not (sources as Array).has(source):
			return "not_accepting"
	elif source == "dev" and eff.has("leagues"):
		return "not_accepting"           # event rules (they always name their leagues) must list "dev" explicitly
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
	if SERVICE_SOURCES.has(source) and not INTERVAL_EXEMPT_KINDS.has(kind) and run.has("tick") \
			and run.has("last_delivery_tick") \
			and _int(run["tick"]) - _int(run["last_delivery_tick"]) < _int(gr["min_interval_sec"]) * TICKS_PER_SEC:
		return "too_soon"
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
	return SponsorWindows.check(run, g)


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


## THE application check of an external gift (05 §6.10: the check at application is authoritative), shared by Show
## (live: acceptance and hand-out) and RunSim.gift_refusal (verifier), so both always agree. "" or the reason; system
## gifts → "". Order: id already applied in this run (flags.live.gift_ids) → duplicate; contents naming an item the
## game data does not know → invalid_schema; check() with a copy of the run counters merged with `extra` ("tick", run
## identity "run_id"/"event_id"/"player_id"/"window_id", Show's Sponsor-Fenster reservations). Read-only.
static func refusal(state: GameState, data: GameData, g: Dictionary, rules: Dictionary, extra: Dictionary) -> String:
	if not Gift.is_external(g) or state == null:
		return ""
	var live: Variant = state.flags.get("live", {})
	var run: Dictionary = (live as Dictionary).duplicate() if live is Dictionary else {}
	var ids: Variant = run.get("gift_ids", [])
	if ids is Array and (ids as Array).has(str(g.get("gift_id", ""))):
		return "duplicate"
	var contents: Variant = g.get("contents", [])
	if data != null and contents is Array:
		for c: Variant in (contents as Array):
			var item_id: String = str((c as Dictionary).get("item_id", "")) if c is Dictionary else ""
			if item_id != "" and not data.has_id("items", item_id):
				return "invalid_schema"
	run.merge(extra, true)
	return check(run, g, rules)


## Records an applied external gift id in the run (flags.live.gift_ids — duplicate protection, refusal()).
static func remember(state: GameState, gift_id: String) -> void:
	if state == null or gift_id == "":
		return
	if not (state.flags.get("live", null) is Dictionary):
		state.flags["live"] = {}
	var live: Dictionary = state.flags["live"]
	if not (live.get("gift_ids", null) is Array):
		live["gift_ids"] = []
	(live["gift_ids"] as Array).append(gift_id)


## Books an applied external gift into the run counters and into its Sponsor-Fenster (SponsorWindows.book: one slot,
## one gift of its sender); a service gift (fan/shop/bits, not cheer) at run tick `tick` >= 0 sets last_delivery_tick
## (min_interval_sec). System gifts are ignored. Called exactly once per gift: GiftApplier.apply outside battles,
## GiftApplier.note_battle_gift (RunSim) or Show.take_pending_gift (live hand-out) in battle.
static func note_applied(run: Dictionary, g: Dictionary, rules: Dictionary, tick: int = -1) -> void:
	if not Gift.is_external(g):
		return
	var source: String = str(g.get("source", ""))
	if tick >= 0 and SERVICE_SOURCES.has(source) and not INTERVAL_EXEMPT_KINDS.has(str(g.get("kind", ""))):
		run["last_delivery_tick"] = tick
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
	SponsorWindows.book(run, g)


## The gift names another run, player, event or window than the run's (both sides known, i.e. non-empty).
static func _wrong_target(run: Dictionary, g: Dictionary) -> bool:
	var target: Variant = g.get("target", {})
	var t: Dictionary = target if target is Dictionary else {}
	var pairs: Array = [[str(t.get("run_id", "")), str(run.get("run_id", ""))],
		[str(t.get("player_id", "")), str(run.get("player_id", ""))],
		[str(g.get("window_id", "")), str(run.get("window_id", ""))]]
	for p: Array in pairs:
		if str(p[0]) != "" and str(p[1]) != "" and str(p[0]) != str(p[1]):
			return true
	# event binding: a gift for an event only fits that event's run (a campaign run has event_id "")
	var gev: String = str(g.get("event_id", ""))
	return gev != "" and run.has("event_id") and str(run["event_id"]) != gev


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
