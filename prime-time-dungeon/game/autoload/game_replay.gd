extends RefCounted
## Private helper of the Game autoload (02_TECH §0.3: no class_name, preloaded by game.gd): THE replay engine behind
## Game.replay_log — the verifier of complete live runs (05 §11.4). One instance per replay.
##
## It replays a RunLog against a fresh GameState — or, for a log that starts at a loaded save ("from_save"), against a
## copy of its anchor (RunSim.anchor_state: header start_state, checked against start_hash) — by driving the SAME
## Game/Show methods as the live run (Game.record() is a no-op meanwhile, no Router/Save calls): RNG consumption
## (next_seed "battle"/"show"/"lootbox"/"gift"), Show reactions (hype, followers, milestones, achievements, sponsor
## gifts), safe-room bookkeeping and event rules (header.event_id → EventDef.rules) are identical by construction.
## The walk is RunLog.walk (shared with RunSim.replay); checkpoint k = state after all commands with k' <= k. The live
## context (state, log, sim, quest, …) is restored afterwards (Game._capture_context/_restore_context).
## Echtzeitkampf (07 §10.6, R5a): a real-time combat replays through the Game API of the live CombatDirector
## (Game.make_rt_setup, combat_boundary, combat_submit, combat_hint, combat_step, end_combat) in the exact loop of
## _combat; the combat checkpoints are compared tick by tick with the cursor of the replay's RunSim (check_combat); a
## compacted log is replayed expanded; a log that does not start at a save starts from RunRules.rt_start. The campaign
## fights in real time only since R5b part 2b (the CTB battle went to the Stempelduell, 10 SD1).
## Staffeln (09 §9.1, ST1-B): resume replays the command journal of a season slot from its loaded save (Save.load_slot)
## with this engine — a combat the journal ends in is decided by the autopilot from its start.

var game: Node                        # the Game autoload
var _autopilot_at: int = -1           # Staffeln (09, ST1-B): the command index of the open combat of a journal
var _final_state: GameState = null    # the replayed state of the last run()


func _init(p_game: Node) -> void:
	game = p_game


## Game.replay_log: {"final_hash", "result", "mismatch_at", "errors", "version", "combat_mismatch_at"} — see there. A
## log of another sim_version is not replayed (RunSim.version_status / version_error, 08 §10.2 Nr. 7): one error,
## mismatch_at -1. Inhaltspakete (11-P1, 11 §3.9): nor is a log of another content pack (other_pack /
## other_pack_version against DB.data).
func run(p_log: RunLog, until_tick: int) -> Dictionary:
	var out: Dictionary = {"final_hash": "", "result": {}, "mismatch_at": -1, "errors": PackedStringArray(),
		"version": "", "combat_mismatch_at": -1}
	if p_log == null:
		return out
	var src: RunLog = p_log.expanded() if p_log.has_batches() else p_log   # 07 §10.3: replays use the expanded form
	out["version"] = RunSim.version_status(src.header, DB.data)
	if str(out["version"]) != "":                 # another kernel's log: not replayed, nor checked against this schema
		out["errors"] = PackedStringArray([RunSim.version_error(src.header, DB.data)])
		return out
	var errors: PackedStringArray = src.validate()
	out["errors"] = errors
	if game.replaying or game.in_battle:
		errors.append("replay_log is not possible during a replay or a combat")
		return out
	if src.rejected > 0:
		errors.append("log: %d entries rejected (out of tick order, duplicate / invalid cmd ids, malformed)"
			% src.rejected)
	var header: Dictionary = src.header
	errors.append_array(RunRules.rt_header_errors(header))
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
		errors.append_array(RunSim.header_errors(header, def, def.rules, DB.data))
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
	# Casting (08 §2.7 Nr. 2): the header carries no name — the replayed state uses the default display name
	var st: GameState = anchor if anchor != null else GameState.create_new(DB.data, int(header.get("slot", 0)),
		GameState.DEFAULT_NAME, run_seed, difficulty)
	if anchor == null and st != null:
		RunRules.rt_start(st, DB.data)                 # Echtzeitkampf (07 §12.1, R5a): like Game.new_game
	game.state = st
	if anchor != null:
		Show.sync_from_state()                         # like Save.load_slot after adopting the loaded state
	if st != null:
		game.sim = RunSim.new(DB.data, st, rules, RunSim.identity_of(header))
		(game.sim as RunSim).expect_combat_checkpoints(src.combat_checkpoints())
		_walk(src, out, errors)
		if until_tick >= 0:
			_advance(until_tick)
		(game.sim as RunSim).finish_combat_checks()
		out["combat_mismatch_at"] = (game.sim as RunSim).combat_mismatch_at
		out["mismatch_at"] = RunSim.first_mismatch(int(out["mismatch_at"]), int(out["combat_mismatch_at"]))
		# 06-D: buffered twists refused when due (the state's replay buffer, applied by RunSim.step) — reported with
		# their id like RunSim.replay does (RunRules.refused_id / rejected_cmds)
		for rc: Dictionary in (game.sim as RunSim).rejected_cmds:
			errors.append("k %d: %s '%s' refused by the core (%s)" % [int(rc["k"]), str(rc["t"]), str(rc["gift_id"]),
				str(rc["reason"])])
		var quest: QuestTracker = game.quest
		_final_state = st
		out["final_hash"] = StateHash.of(st)
		out["result"] = {"ticks": (game.sim as RunSim).tick(), "cmds": src.size(),
			"floor": st.floor_run.index if st.floor_run != null else 1,
			"quest_complete": quest.is_complete() if quest != null else false,
			"quest_progress": quest.progress() if quest != null else 0.0,
			"twists_waiting": TwistApplier.buffered(st).size()}     # 06-D: still buffered (kept in the state)
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
	var advance: Callable = func(k: int) -> void:
		_advance(k)
	var apply_cmd: Callable = func(i: int, c: Dictionary) -> int:
		return _cmd(cmds, i, c, errors)
	var on_checkpoint: Callable = func(cp: int, k: int, want: String) -> void:
		_advance(k)
		if int(out["mismatch_at"]) < 0 and want != "" and StateHash.of(game.state) != want:
			out["mismatch_at"] = cp
	p_log.walk(advance, apply_cmd, on_checkpoint)


## One command of the walk (index i) → the index of the next one (a combat replay consumes the entries of its combat).
## Other commands pass RunRules.command_refusal first (the same legality check as RunSim.command_refusal); refused ones
## are errors and skipped.
func _cmd(cmds: Array[Dictionary], i: int, c: Dictionary, errors: PackedStringArray) -> int:
	var next: int = i + 1
	if RtCommand.is_combat_cmd(c):                 # Echtzeitkampf (07 §10.6): the combat loop consumes its entries
		errors.append("cmd %d (%s): refused (%s)" % [i, str(c.get("t", "")),
			RunRules.combat_refusal(c, null, -1, -1)])
		return next
	match str(c.get("t", "")):
		"encounter":                                   # Echtzeitkampf (07 §10.6, R5a)
			if i == _autopilot_at:                     # Staffeln (09 §9.1, ST1-B): the open combat of a journal
				return _combat_autopilot(cmds, i, c, errors)
			return _combat(cmds, i, c, errors)
		"twist":                                   # 06-D: applied at its tick (buffered when ahead)
			var why: String = _twist(c.get("twist", {}))
			if why != "":
				errors.append("cmd %d (twist '%s'): refused (%s)" % [i, RunRules.refused_id(c), why])
		_:
			var refusal: String = RunRules.command_refusal(game.state, DB.data, (game.sim as RunSim).rules, c,
				game._floor_done, game._scene_ctx, (game.sim as RunSim).is_event_run())
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
		game._dispatch(sim.step(1))           # incl. the buffered twists due at this tick (RunSim._apply_due_twists)
		if sim.tick() == before:
			break


## 06-D: a twist command now (tick == clock → Game.apply_twist, the live path), later (tick ahead → the state's replay
## buffer, TwistApplier.buffer; RunSim.step applies it when due — like RunSim.replay) or never (RunRules.twist_refusal:
## run not active, tick passed). "" or the refusal.
func _twist(tw: Variant) -> String:
	if not (tw is Dictionary):
		return "malformed"
	var sim: RunSim = game.sim
	var why: String = RunRules.twist_refusal(game.state, DB.data, sim.rules, tw, sim.tick(), game.in_battle,
		not (game._run_finished or game._floor_done), true, game._current_layout())
	if why != "":
		return why
	var at: int = JsonUtil.to_int((tw as Dictionary).get("tick", sim.tick()))
	if at > sim.tick():
		TwistApplier.buffer(game.state, tw, at - sim.tick())
		return ""
	return game.apply_twist(tw)


## The other commands → the same Game/Show method the live run used. false = not applicable (a QA Sponsor-Fenster the
## rules do not allow, a talent pick / casting / hero switch / secret / persona the core refuses, an unknown type);
## gifts Show refuses are reported through gift_rejected.
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
			if st.season != null:                      # Staffeln (09 §2.7, ST1-B): the stairs, the end of the content
				game._dispatch(SeasonRules.on_descend(st, DB.data))
			if st.floor_run != null:
				Events.floor_completed.emit(st.floor_run.index)
		"gift":
			Show.receive_gift(c.get("gift", {}))
		"sponsor_window":
			return game.open_dev_sponsor_window(int(c.get("sec", 0)), int(c.get("slots", 0)))
		"talent":                                        # 06 package B; v2 (09 ST0): a row of the talent tree
			if c.has("v"):
				return game.pick_talent_row(str(c.get("member", "")), JsonUtil.to_int(c.get("row", 0)),
					str(c.get("id", "")))
			return game.pick_talent(str(c.get("member", "")), str(c.get("id", "")))
		"casting":
			return game.choose_casting(str(c.get("member", "")), str(c.get("species", "")), str(c.get("class", "")))
		"hero":                                          # 06 package A
			return game.set_hero(str(c.get("id", "")))
		"secret":
			return game.open_secret(str(c.get("id", "")))
		"persona":                                       # Casting (08 §2.3, K0)
			return game.apply_persona(c)
		"loadout":                                       # Echtzeitkampf (07 §4.1, §5.2; R5a)
			return game.apply_loadout(c)
		# Staffeln (09 §9.1, ST0): the season facades (_cmd refuses them first: no_season / season_unavailable)
		"season":
			return game.season_op(c)
		"clock":
			return game.season_clock(JsonUtil.to_int(c.get("sec", 0)))
		"away":
			return game.season_away(JsonUtil.to_int(c.get("sec", 0)))
		"sleep":                                         # ST1-G: the recorded command as it is (its cell)
			return game.season_sleep_cmd(c)
		"prof":
			return game.prof_action(str(c.get("op", "")), str(c.get("id", "")))
		"gather":
			return game.gather(str(c.get("node", "")))
		"craft":
			return game.craft(str(c.get("recipe", "")), JsonUtil.to_int(c.get("n", 1)))
		"cast":
			return game.cast_action(str(c.get("op", "")), JsonUtil.to_int(c.get("who", -1)), str(c.get("item", "")))
		"sd":                                            # Stempelduell (10 §6.8): _cmd refuses it until SD3
			return false
		"combat_speed":                                  # no state effect (07 §10.7: the "Zeitlupe" mark)
			return true
		# Echtzeitkampf (07 §10.6, R5a): the combat loop (_combat) replays these through Game.combat_*; _cmd refuses
		# them outside a combat (no_combat), so these branches are never reached ("not applicable")
		"ability_use": return false
		"target_change": return false
		"move_sample": return false
		"combat_item": return false
		"partner_preset": return false
		"partner_special": return false
		"auto_attack": return false
		"autopilot": return false
		"combat_hint": return false
		"move_input": return false
		"move_batch": return false
		_:
			push_warning("[GameReplay] unknown command '%s'" % str(c.get("t", "")))
			return false
	return true


# --- Echtzeitkampf (07 §10.6, R5a) ------------------------------------------------------------------------------------

## THE replay of a real-time combat (07 §10.6), through exactly the Game API the live CombatDirector uses:
## Game.make_rt_setup(encounter) (seeds "battle" + "show", Show.begin_battle, the ct-0 prelude; no set → nothing more,
## like live), then per combat tick c:
##   (1) the combat_hint entries of c recorded before its boundary (a card the previous tick's events showed),
##   (2) the gift entry of c → Show.receive_gift (the queue), Game.combat_boundary() — at most one gift: that one, else
##       a due system gift (regenerated by Show, never recorded); a recorded gift the boundary left waiting: an error,
##   (3) the other entries of c in log order: combat_hint → Game.combat_hint, else Game.combat_submit (a refusal is an
##       error); a second gift of c → gift_twice, a gift after inputs of c → gift_order (errors, skipped),
##   (4) Game.combat_step() and the combat checkpoints of c (RunSim.check_combat).
## An entry before the current tick is an error (past_tick, skipped). After the end: the combat_hint of the last tick
## (recorded before Game.end_combat), every further combat entry → combat_cmd_after_end; then Game.end_combat() and,
## after a DEFEAT, Game.on_game_over(&"defeat") (live: Router.game_over). Returns the index of the next command.
func _combat(cmds: Array[Dictionary], i: int, c: Dictionary, errors: PackedStringArray) -> int:
	var j: int = i + 1
	if game.make_rt_setup(c) == null:
		return j
	var sim: RunSim = game.sim
	var k: int = sim.tick()
	var guard: int = (game.combat as RtSim).bal.i("MAX_COMBAT_TICKS") + 1
	while game.combat != null and not (game.combat as RtSim).is_finished() and guard > 0:
		guard -= 1
		var rt: RtSim = game.combat
		var ct: int = rt.tick()
		while j < cmds.size() and _entry_ct(cmds[j]) >= 0 and _entry_ct(cmds[j]) < ct:
			errors.append("cmd %d (%s): refused (past_tick)" % [j, _entry_t(cmds[j])])
			j += 1
		while _entry_at(cmds, j, ct) and _entry_t(cmds[j]) == "combat_hint":
			game.combat_hint(str((cmds[j]["c"] as Dictionary).get("id", "")))
			j += 1
		var gift_id: String = ""
		if _entry_at(cmds, j, ct) and _entry_t(cmds[j]) == "gift":
			var g: Dictionary = (cmds[j]["c"] as Dictionary).get("gift", {})
			if Gift.is_external(g):
				gift_id = str(g.get("gift_id", ""))
				Show.receive_gift(g)
			else:
				errors.append("cmd %d (gift): refused (system_gift)" % j)
			j += 1
		game.combat_boundary()
		if gift_id != "" and Show.is_gift_queued(gift_id):
			errors.append("gift '%s': not applied at the boundary of ct %d" % [gift_id, ct])
		var inputs: int = 0
		while _entry_at(cmds, j, ct):
			var e: Dictionary = cmds[j]["c"]
			match _entry_t(cmds[j]):
				"gift":
					errors.append("cmd %d (gift): refused (%s)" % [j, "gift_order" if inputs > 0 else "gift_twice"])
				"combat_hint":
					game.combat_hint(str(e.get("id", "")))
				_:
					inputs += 1
					var why: String = game.combat_submit(e)
					if why != "":
						errors.append("cmd %d (%s): refused by the combat (%s)" % [j, _entry_t(cmds[j]), why])
			j += 1
		game.combat_step()
		sim.check_combat(k, rt)
	if game.combat == null:
		return j
	var end: RtSim = game.combat
	while j < cmds.size() and _entry_ct(cmds[j]) >= 0:
		var e2: Dictionary = cmds[j]["c"]
		var why2: String = RunRules.combat_after_end(e2, end) if _entry_ct(cmds[j]) >= end.tick() else "past_tick"
		if why2 == "" and _entry_t(cmds[j]) == "combat_hint":
			game.combat_hint(str(e2.get("id", "")))
		else:
			errors.append("cmd %d (%s): refused (%s)" % [j, _entry_t(cmds[j]),
				why2 if why2 != "" else "combat_cmd_after_end"])
		j += 1
	var result: BattleResult = end.result
	game.end_combat()
	if result != null and result.outcome == BattleResult.Outcome.DEFEAT:
		game.on_game_over(&"defeat")
	return j


## The command journal of a season slot (Save.load_slot; 09 §9.1, V-3), replayed from the loaded save `st` with the
## engine of run — every entry through the same Game methods as live, so the Show reactions follow; the log is
## anchored at `st` (a "from_save" header). A combat the journal ends in (CommandJournal.open_combat) is decided from
## its start by the autopilot (_combat_autopilot). {"state": the replayed GameState (null when nothing could be
## replayed), "errors": PackedStringArray (like replay_log's), "autopilot": bool}. The live context is restored
## afterwards like after every replay; the caller (Save) adopts the state.
func resume(st: GameState, entries: Array) -> Dictionary:
	var out: Dictionary = {"state": null, "errors": PackedStringArray(), "autopilot": false}
	if st == null:
		return out
	var open_at: int = CommandJournal.open_combat(entries)
	var header: Dictionary = {"schema": 1, "seed": st.seed, "slot": st.slot, "mode": "campaign",
		"difficulty": String(st.difficulty), "sim_version": RunSim.SIM_VERSION, "event_id": "", "run_id": "journal",
		"player_id": "local", "window_id": "", "league": "", "from_save": true,
		"combat_mode": String(RunRules.REALTIME), "rt_version": RunRules.RT_VERSION,
		"start_state": PersonaPrivacy.scrub_state_dict(st.to_dict()), "start_hash": StateHash.of(st)}
	_autopilot_at = open_at
	_final_state = null
	var res: Dictionary = run(CommandJournal.to_run_log(header, entries, open_at), -1)
	_autopilot_at = -1
	out["state"] = _final_state
	out["errors"] = res["errors"]
	out["autopilot"] = open_at >= 0
	return out


## The open combat of a journal (09 §9.1: "gleicher Seed, beide Einheiten KI, die bis dahin gemachten Eingaben zählen
## nicht"): built like the live one (Game.make_rt_setup: the same seeds), its recorded entries dropped, the controlled
## unit on autopilot from tick 0, played to its end through the CombatDirector's Game API (combat_boundary → submit →
## combat_step), then Game.end_combat (a defeat is the season's death rule). Returns the index of the next command.
func _combat_autopilot(cmds: Array[Dictionary], i: int, c: Dictionary, errors: PackedStringArray) -> int:
	var j: int = i + 1
	while j < cmds.size() and _entry_ct(cmds[j]) >= 0:
		j += 1
	if game.make_rt_setup(c) == null:
		return j
	var rt: RtSim = game.combat
	var guard: int = rt.bal.i("MAX_COMBAT_TICKS") + 1
	var first: bool = true
	while game.combat != null and not (game.combat as RtSim).is_finished() and guard > 0:
		guard -= 1
		game.combat_boundary()
		if first:
			first = false
			var why: String = game.combat_submit(RtCommand.autopilot(0, rt.controlled_id(), true))
			if why != "":
				errors.append("journal: the autopilot was refused (%s)" % why)
		game.combat_step()
	var result: BattleResult = (game.combat as RtSim).result if game.combat != null else null
	game.end_combat()
	if result != null and result.outcome == BattleResult.Outcome.DEFEAT:
		game.on_game_over(&"defeat")
	return j


## The ct of the combat entry `row` of the log (RtCommand.is_combat_cmd); -1 for any other command.
static func _entry_ct(row: Dictionary) -> int:
	var c: Dictionary = row["c"]
	if not RtCommand.is_combat_cmd(c):
		return -1
	return maxi(0, JsonUtil.to_int(c.get("ct", 0)))


static func _entry_t(row: Dictionary) -> String:
	return str((row["c"] as Dictionary).get("t", ""))


## The command at index j is a combat entry of tick ct.
static func _entry_at(cmds: Array[Dictionary], j: int, ct: int) -> bool:
	return j < cmds.size() and _entry_ct(cmds[j]) == ct
