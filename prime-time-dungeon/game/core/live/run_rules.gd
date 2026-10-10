class_name RunRules extends RefCounted
## THE state changes of the recorded exploration commands (02_TECH §3.4) — one implementation per rule, shared by the
## live run (Game: plus record(), Events signals and the Show reactions) and the verifier (RunSim.apply). Live run and
## replay therefore cannot drift apart when a rule changes (02_TECH §7.1).
## No autoloads, no SceneTree; randomness only from the seed streams named per function (05 §3.3).

const KEY_MASTER: String = "itm_key_master"        # opens locked chests (02_TECH §7.3)
const LOCATION_START: StringName = &"start"        # FloorRun.location outside a safe room


## state.rng_counter += 1 → SeedUtil.derive(state.seed, purpose, rng_counter): the run's streams "battle", "show",
## "lootbox", "gift" (Game.next_seed and RunSim.next_seed).
static func next_seed(state: GameState, purpose: String) -> int:
	state.rng_counter += 1
	return SeedUtil.derive(state.seed, purpose, state.rng_counter)


## New FloorRun of floor `index` (FloorRun.create with the run seed and the CURRENT difficulty — the Vorabend timer
## factor applies from here, GDD §2.9). false = unknown floor (nothing changes).
static func start_floor(state: GameState, data: GameData, index: int) -> bool:
	var def: FloorDef = data.floor_def(index) if data != null else null
	if state == null or def == null:
		return false
	state.floor_run = FloorRun.create(def, state.seed, state.difficulty)
	TwistApplier.on_floor(state, index)                 # 06-D: twists end with their floor
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
	return outcome


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


## Only &"prime" → &"vorabend" (never up). Damage/EXP apply from the next battle (BattleBridge.make_setup), the timer
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
## (flag keys are whitelisted by Command.validate; QA Sponsor-Fenster by SponsorWindows.dev_allowed.)
static func command_refusal(state: GameState, data: GameData, rules: Dictionary, c: Dictionary, floor_done: bool,
		scene_ctx: Dictionary) -> String:
	var t: String = str(c.get("t", ""))
	if t == "gift" or state == null:
		return ""
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
	return ""
