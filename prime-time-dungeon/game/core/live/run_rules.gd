class_name RunRules extends RefCounted
## THE state changes of the recorded exploration commands (02_TECH §3.4) — one implementation per rule, shared by the
## live run (Game: plus record(), Events signals and the Show reactions) and the verifier (RunSim.apply). Live run and
## replay therefore cannot drift apart when a rule changes (02_TECH §7.1). The commands of the 06 packages follow the
## same pattern with their own core classes — Talents.pick / Casting.choose (B), HeroRules.set_hero / Secrets.open (A)
## are the state changes (called by Game and RunSim.apply), their legality is part of command_refusal.
## No autoloads, no SceneTree; randomness only from the seed streams named per function (05 §3.3).

const KEY_MASTER: String = "itm_key_master"        # opens locked chests (02_TECH §7.3)
const LOCATION_START: StringName = &"start"        # FloorRun.location outside a safe room


## state.rng_counter += 1 → SeedUtil.derive(state.seed, purpose, rng_counter): the run's streams "battle", "show",
## "lootbox", "gift" (Game.next_seed and RunSim.next_seed).
static func next_seed(state: GameState, purpose: String) -> int:
	state.rng_counter += 1
	return SeedUtil.derive(state.seed, purpose, state.rng_counter)


## New FloorRun of floor `index` (FloorRun.create with the run seed and the CURRENT difficulty — the Vorabend timer
## factor applies from here, GDD §2.9). false = unknown floor (nothing changes). Staffeln (09, ST1-B): with a season
## SeasonRules.on_floor_start follows (Am-Stück countdown, programme, binge clock).
static func start_floor(state: GameState, data: GameData, index: int) -> bool:
	var def: FloorDef = data.floor_def(index) if data != null else null
	if state == null or def == null:
		return false
	var prev: FloorRun = state.floor_run
	state.floor_run = FloorRun.create(def, state.seed, state.difficulty)
	TwistApplier.on_floor(state, index)                 # 06-D: twists end with their floor
	if state.season != null:                            # Staffeln (09, ST1-B)
		SeasonRules.on_floor_start(state, data, prev)
	return true


## First visit of `cell`: visited += cell, a STAIRS cell sets stairs_found. false = already visited / no floor.
static func visit_room(state: GameState, layout: FloorLayout, cell: Vector2i) -> bool:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null or fr.visited.has(cell):
		return false
	fr.visited.append(cell)
	var rc: RoomCell = layout.cell_at(cell) if layout != null else null
	if rc != null and rc.kind == RoomCell.Kind.STAIRS:
		fr.stairs_found = true
	return true


## The chest `chest_id` of the current floor if it can be opened now, else null (nothing changes): unknown id (warning),
## already open, or locked without KEY_MASTER in the inventory.
static func openable_chest(state: GameState, layout: FloorLayout, chest_id: String) -> ChestSpawn:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null or fr.opened_chests.has(chest_id):
		return null
	var chest: ChestSpawn = layout.chest_by_id(chest_id) if layout != null else null
	if chest == null:
		push_warning("[RunRules] unknown chest '%s'" % chest_id)
		return null
	if chest.type == "locked" and (state.inventory == null or not state.inventory.has(KEY_MASTER)):
		return null
	return chest


## Opens an openable chest: LootRoller.roll_chest with SeedUtil.derive(floor_run.loot_seed, "chest", k), k from the id
## "<floor>_c<k>" (05 CR-11: the layout seed is public, the loot seed is not); rewards → inventory
## (Inventory.add_rewards); opened_chests += id. Returns the rewards.
static func open_chest(state: GameState, data: GameData, chest: ChestSpawn) -> Array[LootReward]:
	var fr: FloorRun = state.floor_run
	var k: int = chest.id.get_slice("_c", 1).to_int()
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.loot_seed, "chest", k))
	var spec: Dictionary = {"id": chest.id, "type": chest.type, "contents": chest.contents}
	var rewards: Array[LootReward] = LootRoller.roll_chest(spec, data, fr.index, state, rng)
	for r: LootReward in rewards:                       # 06-D: tw_double_credits (capped bonus, booked in the twist)
		if r.kind == "credits":
			r.amount += TwistApplier.take_bonus_credits(state, r.amount)
	state.inventory.add_rewards(data, rewards)
	fr.opened_chests.append(chest.id)
	return rewards


## True if `box_id` is a known lootbox waiting in pending_lootboxes.
static func lootbox_pending(state: GameState, data: GameData, box_id: String) -> bool:
	return state != null and data != null and data.has_id("lootboxes", box_id) and state.pending_lootboxes.has(box_id)


## Opens a pending lootbox (check lootbox_pending first): removes it, LootRoller.roll_lootbox with next_seed("lootbox"),
## rewards → inventory. Returns the rewards.
static func open_lootbox(state: GameState, data: GameData, box_id: String) -> Array[LootReward]:
	state.pending_lootboxes.remove_at(state.pending_lootboxes.find(box_id))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(next_seed(state, "lootbox"))
	var floor_index: int = state.floor_run.index if state.floor_run != null else 1
	var rewards: Array[LootReward] = LootRoller.roll_lootbox(data.lootbox(box_id), data, floor_index, state, rng)
	state.inventory.add_rewards(data, rewards)
	return rewards


## Gate `key` ("x,y,DIR") opened once (the requirement is checked by the exploration). false = already open / no floor.
static func open_gate(state: GameState, key: String) -> bool:
	if state == null or state.floor_run == null or state.floor_run.opened_gates.has(key):
		return false
	state.floor_run.opened_gates.append(key)
	return true


## Floor event (02_TECH §7.4): k = index of the event in layout.events, rng SeedUtil.derive(floor_run.seed, "event",
## k × 16 + event_uses[id]); FloorEvent.resolve + apply. Returns the outcome ({} = unknown event, warning). Lootboxes of
## the outcome are added by add_event_boxes — the live run adds them after its Show reactions.
static func apply_floor_event(state: GameState, data: GameData, layout: FloorLayout, event_id: String,
		choice: String) -> Dictionary:
	var fr: FloorRun = state.floor_run if state != null else null
	var ev: EventSpawn = layout.event_by_id(event_id) if layout != null and fr != null else null
	if ev == null:
		push_warning("[RunRules] unknown floor event '%s'" % event_id)
		return {}
	var k: int = layout.events.find(ev)
	var uses: int = int(fr.event_uses.get(event_id, 0))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(fr.seed, "event", k * 16 + uses))
	var outcome: Dictionary = FloorEvent.resolve(ev, choice, state, data, rng)
	FloorEvent.apply(outcome, ev, choice, state, data)
	_rt_regen_after_damage(fr, outcome)                  # Echtzeitkampf (07 §2.7, R1b)
	return outcome


## Echtzeitkampf (07 §2.7, R1b): damage outside combat (a floor event's party_damage_pct) restarts the regeneration
## counter of RunSim step 7 — here, because live play and the replay both apply events through this function.
static func _rt_regen_after_damage(fr: FloorRun, outcome: Dictionary) -> void:
	var dmg: Variant = outcome.get("party_damage_pct", {})
	if not (dmg is Dictionary) or not bool(outcome.get("valid", false)):
		return
	for k: Variant in (dmg as Dictionary).keys():
		if JsonUtil.to_int((dmg as Dictionary)[k]) > 0:
			fr.regen_ticks = 0
			return


## outcome["boxes"] of a floor event → pending_lootboxes.
static func add_event_boxes(state: GameState, outcome: Dictionary) -> void:
	for box: Variant in outcome.get("boxes", PackedStringArray()):
		state.pending_lootboxes.append(str(box))


## Safe room entry: location = id, safe_room_visits += 1, first visit → visited_safe_rooms, full heal. Returns the
## scene condition context {"safe_room_id", "first_visit", "safe_room_visits", "kai_level"} (scenes.json conditions).
static func enter_safe_room(state: GameState, data: GameData, safe_room_id: String) -> Dictionary:
	var fr: FloorRun = state.floor_run if state != null else null
	if fr == null:
		return {"safe_room_id": safe_room_id, "first_visit": false, "safe_room_visits": 0, "kai_level": 1}
	fr.location = StringName(safe_room_id)
	fr.safe_room_visits += 1
	var first_visit: bool = not fr.visited_safe_rooms.has(safe_room_id)
	if first_visit:
		fr.visited_safe_rooms.append(safe_room_id)
	Progression.full_heal(state, data)
	TwistApplier.on_safe_room_enter(state)              # 06-D: tw_happy_hour prices apply during this visit
	if state.season != null:                            # Staffeln (09 §7.1, ST1-B): the medics' destination
		SeasonRules.on_safe_room(state, safe_room_id)
	var kai: PartyMember = state.member("kai")
	return {"safe_room_id": safe_room_id, "first_visit": first_visit, "safe_room_visits": fr.safe_room_visits,
		"kai_level": kai.level if kai != null else 1}


## Back in the exploration: location = &"start".
static func leave_safe_room(state: GameState) -> void:
	if state != null and state.floor_run != null:
		state.floor_run.location = LOCATION_START
		TwistApplier.on_safe_room_exit(state)           # 06-D: a visit twist that ran ends


## True while the party is in a safe room (FloorRun.location is a safe room id).
static func in_safe_room(state: GameState) -> bool:
	return state != null and state.floor_run != null and state.floor_run.location != LOCATION_START


## The scene may play now: not yet seen (once) and its condition holds for the safe room context `ctx`
## (enter_safe_room) with the run's flags and show stats. Game.next_scene picks with it, RunSim checks "scene" with it.
static func scene_allowed(state: GameState, scene: SceneDef, ctx: Dictionary) -> bool:
	if state == null or scene == null:
		return false
	if scene.once and bool(state.flags.get("scene_" + scene.id, false)):
		return false
	var stats: Dictionary = state.show.stats if state.show != null else {}
	return scene.expr != null and scene.expr.eval(ctx, stats, state.flags)


## Scene seen: flags scene_<id> = true and the scene's set_flag (e.g. mop_pep_talk, GDD §10.2).
static func mark_scene_seen(state: GameState, scene: SceneDef) -> void:
	state.flags["scene_" + scene.id] = true
	if scene.set_flag != "":
		state.flags[scene.set_flag] = true


## Only &"prime" → &"vorabend" (never up). Damage/EXP apply from the next combat (BattleBridge.make_rt_setup), the timer
## factor from the next floor start (FloorRun.create, GDD §2.9) — the running floor timer is unchanged. false = no
## change.
static func lower_difficulty(state: GameState, d: StringName) -> bool:
	if state == null or state.difficulty != &"prime" or d != &"vorabend":
		return false
	state.difficulty = d
	return true


## THE legality check of a recorded player command against the run (verifiers vs forged logs, 05 §11.4) — RunSim
## (command_refusal) and Game.replay_log run it before applying; "" = allowed, else the reason. Gifts are checked by
## the gift policy (GiftPolicy.refusal) instead. `floor_done`: "descend" was applied and no new floor started;
## `scene_ctx`: the context of the current safe room visit (enter_safe_room; {} outside).
## - after "descend" only the next "floor" → run_not_active
## - floor: the first floor of the run, or exactly floor_run.index + 1 after "descend" → not_allowed
## - difficulty: event runs (rules non-empty) play the event's difficulty (05 §10.1) → not_allowed
## - scene: only in a safe room, not yet seen (once) and its condition true for the visit (scene_allowed) → not_allowed
## - talent (06 §2.2): Talents.check_pick — in a safe room, from the offer of the oldest open level → its reason
## - casting (06 §3.4/§3.6): Casting.check — floor >= min_floor, in a safe room, re-spec locks → its reason
## - hero (06 §1.7): HeroRules.check — the choice of a new run before it started, later switches in a safe room →
##   its reason
## - secret (06 §2.7): Secrets.check_open on the current floor — unknown, already open, note behind a standing wall →
##   its reason
## - persona (08 §2.3, K0): PersonaRules.check — `event_run` (RunSim.is_event_run: header event_id or event rules) →
##   event_run; else version (v2 or v1), catalog, bias, once per run before the run started
## - Echtzeitkampf (07, R5a): loadout: loadout_refusal (every run fights in real time since R5b part 2b)
## - Staffeln (09 §9.1, ST0): season, clock, away, sleep, prof, gather, craft, cast and talent v2: season_refusal
##   (no season → no_season; with one the owning module); sd (10 §6.8): sd_unavailable until SD3
## - Staffeln (09, ST1-B): first SeasonRules.gate — with a season the sleeping figure / the finished candidate act no
##   more (asleep / season_over), floor 1 starts it, "descend" follows the staircase rule; without a season only the
##   start of one in an event run is refused (event_run), so every run of today passes unchanged
## (flag keys are whitelisted by Command.validate; QA Sponsor-Fenster by SponsorWindows.dev_allowed; twists by
## twist_refusal below; the entries of a running real-time combat by combat_refusal.)
static func command_refusal(state: GameState, data: GameData, rules: Dictionary, c: Dictionary, floor_done: bool,
		scene_ctx: Dictionary, event_run: bool = false) -> String:
	var t: String = str(c.get("t", ""))
	if t == "gift" or state == null:
		return ""
	var gate: String = SeasonRules.gate(state, data, c, event_run)   # Staffeln (09, ST1-B)
	if gate != "":
		return gate
	if floor_done and t != "floor":
		return "run_not_active"
	match t:
		"floor":
			if state.floor_run != null and not (floor_done and int(c.get("floor", 0)) == state.floor_run.index + 1):
				return "not_allowed"
		"difficulty":
			if not rules.is_empty():
				return "not_allowed"
		"scene":
			var sid: String = str(c.get("id", ""))
			if data == null or not data.has_id("scenes", sid) or not in_safe_room(state) or scene_ctx.is_empty() \
					or not scene_allowed(state, data.scene_def(sid), scene_ctx):
				return "not_allowed"
		"talent":
			if c.has("v"):                         # Staffeln (09, ST0): talent v2, a row of the talent tree
				return season_refusal(state, data, c)
			return Talents.check_pick(state, data, str(c.get("member", "")), str(c.get("id", "")))
		"casting":
			return Casting.check(state, data, str(c.get("member", "")), str(c.get("species", "")),
				str(c.get("class", "")))
		"hero":
			return HeroRules.check(state, str(c.get("id", "")))
		"secret":
			var def: FloorDef = data.floor_def(state.floor_run.index) if data != null and state.floor_run != null \
				else null
			return Secrets.check_open(state, def, str(c.get("id", "")))
		"persona":                                 # Casting (08 §2.3, K0): event runs never take one (event_run)
			return PersonaRules.check(state, data, c, event_run)
		"loadout":                                 # Echtzeitkampf (07 §4.1, §5.2; R5a)
			return loadout_refusal(state, data, c)
		"season", "clock", "away", "sleep", "prof", "gather", "craft", "cast":   # Staffeln (09 §9.1, ST0)
			return season_refusal(state, data, c)
		"sd":                                      # Stempelduell (10 §6.8): SdRules from SD3
			return SD_UNAVAILABLE
	return ""


## 06-D: THE check of a twist command `tw` (TwistApplier.complete form) at `now_tick` — the live entry
## (Game.apply_twist), the core verifier (RunSim.command_refusal and its buffer) and the full verifier (Game.replay_log)
## all ask here: the run is over / the floor is done → run_not_active; with `buffer_ahead` (the verifiers) a tick that
## has passed → twist_tick_passed and a tick ahead → "" (the caller buffers it: TwistApplier.buffer, checked again when
## due); else TwistApplier.validate (the live entry never waits: a tick that is not now → tick_mismatch).
static func twist_refusal(state: GameState, data: GameData, rules: Dictionary, tw: Dictionary, now_tick: int,
		in_battle: bool, run_active: bool, buffer_ahead: bool, layout: FloorLayout = null) -> String:
	if state == null or not run_active:
		return "run_not_active"
	if buffer_ahead:
		var at: int = JsonUtil.to_int(tw.get("tick", now_tick))
		if at < now_tick:
			return "twist_tick_passed"
		if at > now_tick:
			return ""
	return TwistApplier.validate(state, data, tw, rules, now_tick, in_battle, layout)


## The id a refused command names in both verifiers (RunSim.rejected_cmds["gift_id"], Game.replay_log errors): the
## gift_id of a gift, the hero / secret id (06-A), the twist id (06-D); else "".
static func refused_id(c: Dictionary) -> String:
	match str(c.get("t", "")):
		"gift":
			var g: Variant = c.get("gift", null)
			return str((g as Dictionary).get("gift_id", "")) if g is Dictionary else ""
		"hero", "secret":
			return str(c.get("id", ""))
		"persona":                                 # Casting (08 §2.3): v2 the head-start profession, v1 the talent
			return str(c.get("prof", "")) if c.has("prof") else str(c.get("talent", ""))
		"twist":
			var tw: Variant = c.get("twist", null)
			return str((tw as Dictionary).get("id", "")) if tw is Dictionary else ""
	return ""


# --- Staffeln (09 §9.1, ST0) ------------------------------------------------------------------------------------------

## THE switch of 09 (V-4): every rule of the seasons hangs at state.season != null.
const NO_SEASON: String = "no_season"
const SD_UNAVAILABLE: String = "sd_unavailable"      # 10 §6.8: the "sd" command until SD3


## "" or why a season command ("season", "clock", "away", "sleep", "prof", "gather", "craft", "cast", "talent" v2) is
## refused now: the start of a season → SeasonRules (it has no season yet); every other one without a season →
## no_season; with one the owning module decides — SeasonRules (season, clock, sleep; ST1-B), SleepResolver (away;
## ST1-G), TalentTree (talent v2; ST1-D), Professions (prof, gather, craft; ST1-E), CastSim (cast; ST1-F). The modules
## of the packages to come are stubs that refuse with season_unavailable. Read-only.
static func season_refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	var t: String = str(c.get("t", ""))
	if t == "season" and str(c.get("op", "")) == "start":
		return SeasonRules.refusal(state, data, c)
	if state == null or state.season == null:
		return NO_SEASON
	match t:
		"season", "clock", "sleep":
			return SeasonRules.refusal(state, data, c)
		"away":
			return SleepResolver.refusal(state, data, c)
		"talent":
			return TalentTree.refusal(state, data, c)
		"prof", "gather", "craft":
			return Professions.refusal(state, data, c)
		"cast":
			return CastSim.refusal(state, data, c)
	return "not_allowed"


## Staffeln (09 §2.5, ST1-B): a rescue moved the candidate to floor `index` (the SeasonRules event "rescue": the new
## FloorRun stands) — the part of a floor start the season module cannot do itself (core/live): the twists of the old
## floor end. RunSim and Game call it first when they act on the event (then hype, Sponsor-Fenster, their context).
static func season_moved(state: GameState, index: int) -> void:
	if state != null:
		TwistApplier.on_floor(state, index)


## Applies an accepted season command (season_refusal == ""): the owning module's state change — THE rule the live
## game (Game's season facades) and RunSim.apply share. Returns its explore events (the stubs of the packages to come
## change nothing).
static func apply_season(state: GameState, data: GameData, c: Dictionary) -> Array[ExploreEvent]:
	match str(c.get("t", "")):
		"season", "clock", "sleep":
			return SeasonRules.apply(state, data, c)
		"away":
			return SleepResolver.apply(state, data, c)
		"talent":
			return TalentTree.apply(state, data, c)
		"prof", "gather", "craft":
			return Professions.apply(state, data, c)
		"cast":
			return CastSim.apply(state, data, c)
	var none: Array[ExploreEvent] = []
	return none


# --- Echtzeitkampf (07, R5a) ------------------------------------------------------------------------------------------

const RT_VERSION: int = 1                          # 07 §10.2: run log header "rt_version" of a real-time run
const REALTIME: StringName = &"realtime"
const LOADOUT_SLOTS: PackedStringArray = ["2", "3", "4"]   # 07 §4.1: the slots with variants

## "" or why the combat entry `c` (RtCommand.is_combat_cmd) is refused by a verifier before it is replayed against
## `sim`, the running combat (07 §10.2, §10.6): none → "no_combat"; a move_batch (verifiers replay the expanded log,
## RunLog.expanded) → "not_expanded"; a ct before the combat tick → "past_tick" — and for a gift: one per tick boundary
## (`gift_ct`: ct of the last gift of this combat) → "gift_twice", at the boundary before the inputs of its tick
## (`input_ct`: ct of the last submitted input) → "gift_order", only external gifts are recorded (05 §10.6: system
## gifts come back from the Show rng) → "system_gift"; then the gift policy (GiftPolicy, the caller's). After the
## combat's end (combat_after_end) only a combat_hint of its last tick passes.
static func combat_refusal(c: Dictionary, sim: RtSim, gift_ct: int, input_ct: int) -> String:
	if sim == null:
		return "no_combat"
	var t: String = str(c.get("t", ""))
	if t == "move_batch":
		return "not_expanded"
	var ct: int = JsonUtil.to_int(c.get("ct", -1), -1)
	if ct < sim.tick():
		return "past_tick"
	if t == "gift":
		var g: Variant = c.get("gift", null)
		if g is Dictionary and not Gift.is_external(g):
			return "system_gift"
		if ct == gift_ct:
			return "gift_twice"
		if ct == input_ct:
			return "gift_order"
	return combat_after_end(c, sim)


## "" or "combat_cmd_after_end" (07 §10.2): an entry for a combat that is over — except the combat_hint of its last
## tick (a hint card the events of the final tick showed, recorded before Game.end_combat).
static func combat_after_end(c: Dictionary, sim: RtSim) -> String:
	if sim == null or not sim.is_finished():
		return ""
	if str(c.get("t", "")) == "combat_hint" and JsonUtil.to_int(c.get("ct", -1), -1) == sim.tick():
		return ""
	return "combat_cmd_after_end"


## Hint card `id` shown in a real-time combat (07 §2.13): state.flags["rt_hints"][id] = true (the sim ignores it) —
## Game.combat_hint (live, Game.replay_log) and RunSim.
static func mark_hint(state: GameState, id: String) -> void:
	var v: Variant = state.flags.get("rt_hints", {})
	var hints: Dictionary = v if v is Dictionary else {}
	hints[id] = true
	state.flags["rt_hints"] = hints


## The start of a new run (07 §12.1): full HP / MP (the real-time HP are in the data since R5b part 2b, 07 §3.9.4).
## Game.new_game / start_event_run (live) and both verifiers for a log that does not start at a save — so a replay
## starts from the same state as the live run.
static func rt_start(state: GameState, data: GameData) -> void:
	if state == null:
		return
	Progression.full_heal(state, data)


## Keys of the optional event rules rules.combat (07 §10.7; part of rules_hash): "mode" (R5b) "realtime" — the only
## mode since R5b part 2b (the key stays valid, the shipped events name it), "autopilot" / "assist" / "hints" bool,
## "max_enemies" int >= 1.
const COMBAT_RULE_KEYS: PackedStringArray = ["mode", "autopilot", "assist", "hints", "max_enemies"]


## Schema problems of rules.combat (EventDef.validate): a Dictionary of COMBAT_RULE_KEYS with their types.
static func combat_rules_errors(rules: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if not rules.has("combat"):
		return out
	var raw: Variant = rules["combat"]
	if not (raw is Dictionary):
		out.append("rules.combat must be a Dictionary")
		return out
	var c: Dictionary = raw
	for k: Variant in c.keys():
		if not COMBAT_RULE_KEYS.has(str(k)):
			out.append("rules.combat: unknown key '%s'" % str(k))
	if c.has("mode") and not (c["mode"] is String and str(c["mode"]) == String(REALTIME)):
		out.append("rules.combat.mode must be realtime (the campaign fights in real time only since R5b part 2b)")
	for k: String in ["autopilot", "assist", "hints"]:
		if c.has(k) and not (c[k] is bool):
			out.append("rules.combat.%s must be a bool" % k)
	if c.has("max_enemies") and not (JsonUtil.is_integral(c["max_enemies"]) and JsonUtil.to_int(c["max_enemies"]) >= 1):
		out.append("rules.combat.max_enemies must be an integer >= 1")
	return out


## The run log header names a real-time run (07 §10.2: "combat_mode": "realtime"), as every log of this kernel does.
static func header_realtime(h: Dictionary) -> bool:
	return str(h.get("combat_mode", "")) == String(REALTIME)


## Header problems of a run (07 §10.2): "combat_mode" realtime or absent (hand-made logs) — a CTB log ("ctb") is of an
## older kernel (R5b part 2b); with the key "rt_version" must be RT_VERSION.
static func rt_header_errors(h: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var mode: String = str(h.get("combat_mode", ""))
	if mode != "" and mode != String(REALTIME):
		out.append("header: combat_mode '%s' — this kernel plays real-time runs only (R5b part 2b)" % mode)
	if header_realtime(h) and JsonUtil.to_int(h.get("rt_version", 0)) != RT_VERSION:
		out.append("header: rt_version %s — this kernel plays real-time runs of version %d" % [str(h.get("rt_version",
			"")), RT_VERSION])
	return out


## The loadout command (R5a; 07 §4.1 variants and §5.2 partner tactic, chosen outside a combat in the skills menu): the
## member's complete choice {"t": "loadout", "member", "bar": {"2" | "3" | "4": variant skill id}, "preset": "" |
## RtVocab.RT_PRESETS, "tog": {switch: bool}} — {} / "" are the defaults (the base ability, party.json
## rt.default_preset, RtVocab.RT_TOGGLE_DEFAULTS). Game.apply_loadout records it.
static func loadout_cmd(member_id: String, bar: Dictionary, preset: String = "", tog: Dictionary = {}) -> Dictionary:
	var b: Dictionary = {}
	var keys: Array = bar.keys()
	keys.sort_custom(func(a: Variant, z: Variant) -> bool: return str(a) < str(z))
	for k: Variant in keys:
		b[str(k)] = str(bar[k])
	var t: Dictionary = {}
	for k: String in RtVocab.RT_TOGGLES:
		if tog.has(k):
			t[k] = bool(tog[k])
	return {"t": "loadout", "member": member_id, "bar": b, "preset": preset, "tog": t}


## "" or why the loadout command `c` (schema: Command.validate) is refused — both verifiers and Game.apply_loadout: no
## run or a member without a party.json entry → unknown_member; a bar entry that is no variant of its slot (party.json
## rt.bar "variant": true) → not_a_variant; a variant above the member's level → not_learned.
static func loadout_refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	if state == null:
		return "unknown_member"
	var m: PartyMember = state.member(str(c.get("member", "")))
	if m == null or data == null or not data.has_id("party", m.id):
		return "unknown_member"
	var raw_rows: Variant = data.party_member(m.id).rt.get("bar", [])
	var rows: Array = raw_rows if raw_rows is Array else []
	var raw_bar: Variant = c.get("bar", {})
	var bar: Dictionary = raw_bar if raw_bar is Dictionary else {}
	for k: Variant in bar.keys():
		var level: int = -1
		for r: Variant in rows:
			if r is Dictionary and bool((r as Dictionary).get("variant", false)) \
					and JsonUtil.to_int((r as Dictionary).get("slot", 0)) == str(k).to_int() \
					and str((r as Dictionary).get("skill", "")) == str(bar[k]):
				level = JsonUtil.to_int((r as Dictionary).get("level", 1), 1)
		if level < 0:
			return "not_a_variant"
		if level > m.level:
			return "not_learned"
	return ""


## Applies a loadout command that passed loadout_refusal: the member's rt_loadout (sorted slots), rt_preset and
## rt_toggles (known switches) — the setup of the next real-time combat (BattleBridge.make_rt_setup) reads them.
static func apply_loadout(state: GameState, c: Dictionary) -> bool:
	var m: PartyMember = state.member(str(c.get("member", ""))) if state != null else null
	if m == null:
		return false
	var cmd: Dictionary = loadout_cmd(m.id, c.get("bar", {}) as Dictionary, str(c.get("preset", "")),
		c.get("tog", {}) as Dictionary)
	m.rt_loadout = cmd["bar"]
	m.rt_preset = str(cmd["preset"])
	m.rt_toggles = cmd["tog"]
	return true
