class_name RegieDirector extends RefCounted
## The offline Regie (06 §5.7a, package D): "Ab Etage 2 greift M.O.D.s Regie ein paar Mal pro Etage ein — kurz,
## angesagt, meist hilfreich." Everybody experiences "M.O.D. changes the game a little" without any AI or network.
## Static and pure: Game asks at every decision point (every regie.every_sec = 120 s of EXPLORATION time of the floor,
## is_due) and applies the proposal through Game.apply_twist — the twist is recorded like every other one
## (src "regie"), so a later AI only swaps the choice and the lines (06 §5.1).
##
## decide(): rules.twists.regie enabled, floor >= min_floor (refusal_for enforces it again) → with
## regie.chance_pm (350 ‰) per decision point → candidates = TwistApplier.allowed_now(src "regie") filtered by the
## rules of thumb — floor timer < regie.low_timer_sec (180 s) → only tw_overtime, party HP average <
## regie.weak_party_hp_pct (50 %) → only helpful (and presentation) twists — → weighted draw by TwistDef.weight.
## Randomness: SeedUtil.derive(state.seed, "regie", floor × 1000 + decision point) only.
## Limits are TwistApplier's (1 gameplay twist at a time, 90 s gap, ≤ 4 per floor, ≤ 1 spicy) plus
## regie.max_per_floor (3).

const DECISION_EVERY_SEC: int = 120     # == TwistApplier.DEFAULT_RULES.regie.every_sec
const TICKS_PER_SEC: int = 30


## True right after the exploration tick that completes a decision point of the floor (time_used_ticks a positive
## multiple of regie.every_sec × 30) while the Regie may act at all (enabled, floor >= min_floor, timer running).
static func is_due(state: GameState, rules: Dictionary) -> bool:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null or not fr.timer_started or fr.location != &"start":
		return false
	var tr: Dictionary = TwistApplier.rules_of(rules)
	var reg: Dictionary = tr.get("regie", {}) if tr.get("regie", {}) is Dictionary else {}
	if not bool(tr.get("enabled", true)) or not bool(reg.get("enabled", true)) \
			or fr.index < int(tr.get("min_floor", 2)):
		return false
	var period: int = maxi(1, int(reg.get("every_sec", DECISION_EVERY_SEC))) * TICKS_PER_SEC
	var used: int = int(fr.stats.get("time_used_ticks", 0))
	return used > 0 and used % period == 0


## Index of the current decision point of the floor (1, 2, …).
static func decision_index(state: GameState, rules: Dictionary) -> int:
	var reg: Variant = TwistApplier.rules_of(rules).get("regie", {})
	var every: int = int((reg as Dictionary).get("every_sec", DECISION_EVERY_SEC)) if reg is Dictionary \
		else DECISION_EVERY_SEC
	var used: int = int(state.floor_run.stats.get("time_used_ticks", 0)) if state.floor_run != null else 0
	return used / (maxi(1, every) * TICKS_PER_SEC)


## {} (no intervention now) or a proposal {"id", "src": "regie"} for Game.apply_twist. Read-only.
static func decide(state: GameState, data: GameData, rules: Dictionary, now_tick: int,
		layout: FloorLayout = null) -> Dictionary:
	if state == null or data == null or state.floor_run == null:
		return {}
	var tr: Dictionary = TwistApplier.rules_of(rules)
	var reg: Dictionary = tr.get("regie", {}) if tr.get("regie", {}) is Dictionary else {}
	if not bool(tr.get("enabled", true)) or not bool(reg.get("enabled", true)):
		return {}
	var fr: FloorRun = state.floor_run
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(state.seed, "regie",
		fr.index * 1000 + decision_index(state, rules)))
	if rng.randi_range(0, 999) >= int(reg.get("chance_pm", 350)):
		return {}
	var cands: Array[TwistDef] = []
	var timer_sec: int = fr.time_left_ticks / TICKS_PER_SEC
	var weak: bool = TwistApplier.party_hp_pct(state, data) < int(reg.get("weak_party_hp_pct", 50))
	for id: String in TwistApplier.allowed_now(state, data, rules, now_tick, false, "regie", layout):
		var def: TwistDef = data.twist(id)
		if timer_sec < int(reg.get("low_timer_sec", 180)) and id != "tw_overtime":
			continue
		if weak and def.spice != "helpful" and def.spice != "none":
			continue
		cands.append(def)
	if cands.is_empty():
		return {}
	var total: int = 0
	for def: TwistDef in cands:
		total += maxi(1, def.weight)
	var r: int = rng.randi_range(0, total - 1)
	for def: TwistDef in cands:
		r -= maxi(1, def.weight)
		if r < 0:
			return {"id": def.id, "src": "regie"}
	return {"id": cands[cands.size() - 1].id, "src": "regie"}
