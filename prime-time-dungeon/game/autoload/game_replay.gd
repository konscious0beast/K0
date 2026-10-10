extends RefCounted
## Private helper of the Game autoload (02_TECH §0.3: no class_name, preloaded by game.gd): THE replay engine behind
## Game.replay_log — the verifier of complete live runs (05 §11.4). One instance per replay.
##
## It replays a RunLog against a fresh GameState — or, for a log that starts at a loaded save ("from_save"), against a
## copy of its anchor (RunSim.anchor_state: header start_state, checked against start_hash) — by driving the SAME
## Game/Show methods as the live run (Game.record() is a no-op meanwhile, no Router/Save calls): RNG consumption
## (next_seed "battle"/"show"/"lootbox"/"gift"), Show reactions (hype, followers, milestones, achievements, sponsor
## gifts), safe-room bookkeeping and event rules (header.event_id → EventDef.rules) are identical by construction.
## Battles follow §5.7 (BattleState + Show.begin_battle/on_battle_event/take_pending_gift/end_battle). The walk is
## RunLog.walk (shared with RunSim.replay); checkpoint k = state after all commands with k' <= k. The live context
## (state, log, sim, quest, …) is restored afterwards (Game._capture_context/_restore_context).

var game: Node                        # the Game autoload
var _battle: BattleState = null       # the battle the walk is in (encounter → its battle / gift commands)


func _init(p_game: Node) -> void:
	game = p_game


## Game.replay_log: {"final_hash", "result", "mismatch_at", "errors"} — see there.
func run(p_log: RunLog, until_tick: int) -> Dictionary:
	var out: Dictionary = {"final_hash": "", "result": {}, "mismatch_at": -1, "errors": PackedStringArray()}
	if p_log == null:
		return out
	var errors: PackedStringArray = p_log.validate()
	out["errors"] = errors
	if game.replaying or game.in_battle:
		errors.append("replay_log is not possible during a replay or a battle")
		return out
	if p_log.rejected > 0:
		errors.append("log: %d entries rejected (out of tick order, duplicate / invalid cmd ids, malformed)"
			% p_log.rejected)
	var header: Dictionary = p_log.header
	var anchor: GameState = null
	if bool(header.get("from_save", false)):
		anchor = RunSim.anchor_state(header, errors)    # the loaded state the log starts at (Save.load_slot)
		if anchor == null:
			return out
	var event_id: String = str(header.get("event_id", ""))
	var def: EventDef = null
	if event_id != "":
		def = game._load_event_def(event_id)
		if def == null:
			errors.append("header: event '%s' not found in %s (no replay without its rules)"
				% [event_id, RunSim.EVENTS_PATH])
			return out
		errors.append_array(RunSim.header_errors(header, def, def.rules))
	var run_seed: int = int(header.get("seed", header.get("run_seed", 1)))
	var difficulty: StringName = StringName(str(header.get("difficulty", "prime")))
	var saved: Dictionary = game._capture_context()
	game.replaying = true
	game._reset_run()
	var rules: Dictionary = {}
	game.mode = &"campaign"
	if def != null:
		game.mode = &"event_offline"
		game._event_def = def
		rules = def.rules
		game.quest = QuestTracker.from_def(def.quest)
	var on_rejected: Callable = func(gift_id: String, reason: String) -> void:
		errors.append("gift '%s' refused (%s)" % [gift_id, reason])
	Events.gift_rejected.connect(on_rejected)
	var st: GameState = anchor if anchor != null else GameState.create_new(DB.data, int(header.get("slot", 0)),
		str(header.get("player_name", "Kai")), run_seed, difficulty)
	game.state = st
	if anchor != null:
		Show.sync_from_state()                         # like Save.load_slot after adopting the loaded state
	if st != null:
		game.sim = RunSim.new(DB.data, st, rules, RunSim.identity_of(header))
		_walk(p_log, out, errors)
		if until_tick >= 0:
			_advance(until_tick)
		var quest: QuestTracker = game.quest
		out["final_hash"] = StateHash.of(st)
		out["result"] = {"ticks": (game.sim as RunSim).tick(), "cmds": p_log.size(),
			"floor": st.floor_run.index if st.floor_run != null else 1,
			"quest_complete": quest.is_complete() if quest != null else false,
			"quest_progress": quest.progress() if quest != null else 0.0}
	Events.gift_rejected.disconnect(on_rejected)
	game._restore_context(saved)
	game.replaying = false
	if game.state != null:
		Show.sync_from_state()
		Events.party_changed.emit()
		Events.inventory_changed.emit()
	return out


func _walk(p_log: RunLog, out: Dictionary, errors: PackedStringArray) -> void:
	var cmds: Array[Dictionary] = p_log.cmds()
	_battle = null
	var advance: Callable = func(k: int) -> void:
		_advance(k)
	var apply_cmd: Callable = func(i: int, c: Dictionary) -> int:
		return _cmd(cmds, i, c, errors)
	var on_checkpoint: Callable = func(cp: int, k: int, want: String) -> void:
		_advance(k)
		if int(out["mismatch_at"]) < 0 and want != "" and StateHash.of(game.state) != want:
			out["mismatch_at"] = cp
	p_log.walk(advance, apply_cmd, on_checkpoint)
	_battle = null


## One command of the walk (index i) → the index of the next one (a battle replay consumes the gift commands recorded
## at its turn boundaries). Non-battle commands pass RunRules.command_refusal first (the same legality check as
## RunSim.command_refusal); refused ones are errors and skipped.
func _cmd(cmds: Array[Dictionary], i: int, c: Dictionary, errors: PackedStringArray) -> int:
	var next: int = i + 1
	match str(c.get("t", "")):
		"encounter":
			_battle = _begin_battle(c)
			if _battle != null:
				next = _play(_battle.start(), cmds, next)
				_end_if_finished()
		"battle":
			if _battle == null or _battle.is_finished():
				errors.append("cmd %d: battle command without an active battle" % i)
			else:
				var bc: BattleCommand = BattleCommand.from_dict(c.get("cmd", {}))
				var why: String = _battle.validate(bc) if bc != null else "malformed battle command"
				if why != "":
					errors.append("cmd %d: battle command refused (%s)" % [i, why])
				else:
					next = _play(_battle.submit(bc), cmds, next)
				_end_if_finished()
		_:
			var refusal: String = RunRules.command_refusal(game.state, DB.data, (game.sim as RunSim).rules, c,
				game._floor_done, game._scene_ctx)
			if refusal != "":
				errors.append("cmd %d (%s): refused by the rules (%s)" % [i, str(c.get("t", "")), refusal])
			elif not _apply(c):
				errors.append("cmd %d (%s): not applicable" % [i, str(c.get("t", ""))])
	return next


## Steps the clock tick by tick to `k` with the live dispatch (stops if the clock stops: expired timer).
func _advance(k: int) -> void:
	var sim: RunSim = game.sim
	while sim.tick() < k:
		var before: int = sim.tick()
		game._dispatch(sim.step(1))
		if sim.tick() == before:
			break


## §5.7 BattleController.run: setup (next_seed "battle"), BattleState, Show.begin_battle (next_seed "show"),
## Events.battle_started.
func _begin_battle(c: Dictionary) -> BattleState:
	var setup: BattleSetup = game.make_battle_setup(str(c.get("enc", "")), int(c.get("adv", 0)),
		str(c.get("group", "")))
	if setup == null:
		return null
	var battle: BattleState = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	return battle


## §5.7 _play: events → Show.on_battle_event; then (battle not finished) one pending gift. An external gift is recorded
## when it is delivered (§3.5), i.e. as the "gift" command directly after this boundary → fed before take_pending_gift.
## Returns the index of the next command.
func _play(events: Array[ActionEvent], cmds: Array[Dictionary], i: int) -> int:
	for e: ActionEvent in events:
		if e != null:
			Show.on_battle_event(e)
	if _battle.is_finished():
		return i
	if i < cmds.size() and str((cmds[i].get("c", {}) as Dictionary).get("t", "")) == "gift":
		Show.receive_gift((cmds[i]["c"] as Dictionary).get("gift", {}))
		i += 1
	var g: Dictionary = Show.take_pending_gift(_battle)
	if not g.is_empty():
		var gift_events: Array[ActionEvent] = _battle.apply_gift(g)
		Show.note_battle_gift(g, gift_events)
		for e: ActionEvent in gift_events:
			if e != null:
				Show.on_battle_event(e)
	return i


## §5.7 after the loop: battle_ended, apply_battle_result, Show.end_battle; DEFEAT → on_game_over(&"defeat").
func _end_if_finished() -> void:
	if not _battle.is_finished():
		return
	var result: BattleResult = _battle.result
	_battle = null
	if result == null:
		game.in_battle = false
		return
	Events.battle_ended.emit(result.outcome, result.encounter_id)
	game.apply_battle_result(result)
	Show.end_battle(result)
	if result.outcome == BattleResult.Outcome.DEFEAT:
		game.on_game_over(&"defeat")


## Non-battle commands → the same Game/Show method the live run used. false = not applicable (a QA Sponsor-Fenster the
## rules do not allow, a talent pick / casting / hero switch / secret the core refuses, an unknown type); gifts Show
## refuses are reported through gift_rejected.
func _apply(c: Dictionary) -> bool:
	match str(c.get("t", "")):
		"floor":
			game.start_floor(int(c.get("floor", 1)))
		"lootbox":
			game.open_lootbox(str(c.get("box", "")))
		"buy":
			game.buy(str(c.get("item", "")), int(c.get("qty", 1)), str(c.get("safe_room", "")))
		"sell":
			game.sell(str(c.get("item", "")), int(c.get("qty", 1)))
		"equip":
			game.equip(str(c.get("member", "")), str(c.get("slot", "")), str(c.get("item", "")))
		"use_item":
			game.use_item(str(c.get("item", "")), str(c.get("member", "")))
		"rest":
			game.rest_full_heal()
		"event":
			game.apply_floor_event(str(c.get("id", "")), str(c.get("choice", "")))
		"chest":
			game.open_chest(str(c.get("id", "")))
		"gate":
			game.open_gate(str(c.get("key", "")))
		"room":
			game.visit_room(JsonUtil.arr_to_vec2i(c.get("cell", []), Vector2i(-999, -999)))
		"safe_room":
			game.enter_safe_room(str(c.get("id", "")))
		"safe_room_exit":
			game.leave_safe_room()
		"scene":
			game.mark_scene_seen(DB.scene_def(str(c.get("id", ""))))
		"flag":
			game.set_flag(str(c.get("key", "")), c.get("value", null))
		"difficulty":
			game.set_difficulty(StringName(str(c.get("to", ""))))
		"descend":
			game.timer_running = false
			game._floor_done = true
			var st: GameState = game.state
			if st.floor_run != null:
				Events.floor_completed.emit(st.floor_run.index)
		"gift":
			Show.receive_gift(c.get("gift", {}))
		"sponsor_window":
			return game.open_dev_sponsor_window(int(c.get("sec", 0)), int(c.get("slots", 0)))
		"talent":                                        # 06 package B
			return game.pick_talent(str(c.get("member", "")), str(c.get("id", "")))
		"casting":
			return game.choose_casting(str(c.get("member", "")), str(c.get("species", "")), str(c.get("class", "")))
		"hero":                                          # 06 package A
			return game.set_hero(str(c.get("id", "")))
		"secret":
			return game.open_secret(str(c.get("id", "")))
		_:
			push_warning("[GameReplay] unknown command '%s'" % str(c.get("t", "")))
			return false
	return true
