extends Node
## BattleController (02_TECH §5.7, 05_LIVE_MODUS CR-7): drives BattleState — Show.begin_battle, battle_started,
## plays every event list through the BattlePlayer (event_played → Show.on_battle_event), asks the HUD for party
## commands (or AutoPolicy / EnemyAI), records each command as {"t": "battle", "cmd", "auto"}, delivers pending gifts
## at the turn boundary (Show.take_pending_gift → BattleState.apply_gift → Show.note_battle_gift), then battle_ended →
## Game.apply_battle_result
## → Show.end_battle / unlocked_this_battle → results → Router.end_battle. Private M5 helper (no class_name).
## 06 §1.4 (package A): with GameSettings.partner_auto the partner's turns (the character the player does not control,
## Game.partner()) come from AutoPolicy like an auto battle (recorded "auto": true → replays unchanged); the hero's
## turns stay manual. The full auto battle (toggle_auto) wins. The hero's party panel shows "DU", the partner's "AUTO".

signal finished(result: BattleResult)

const BattlePlayer := preload("res://scenes/battle/battle_player.gd")
const BattleHud := preload("res://scenes/battle/ui/battle_hud.gd")
const BattleResults := preload("res://scenes/battle/ui/battle_results.gd")

var state: BattleState = null
var hud: BattleHud = null
var player: BattlePlayer = null
var results: BattleResults = null
var result: BattleResult = null
var rewards: BattleRewards = null
var running: bool = false
var done: bool = false
## false: stay in the scene after the results (tests, captures) instead of Router.end_battle.
var exit_on_end: bool = true
## Party turns chosen by AutoPolicy before the command menu appears (capture still: a few turns into the battle).
var auto_turns: int = 0
## Ignores Game.auto_battle (capture: always stops at the command menu).
var force_manual: bool = false
## Every command submitted in this battle (BattleCommand.to_dict() + "auto"), in order.
var commands: Array[Dictionary] = []
## Gifts delivered in this battle (Show.take_pending_gift results).
var gifts: Array[Dictionary] = []


func _ready() -> void:
	if player != null and not player.event_played.is_connected(_on_event_played):
		player.event_played.connect(_on_event_played)
	Events.settings_changed.connect(func() -> void:     # "Partner automatisch" switched in the pause menu
		if is_inside_tree() and running:
			mark_roles())


## Wires the player (event_played → Show) — call before run().
func bind(p_player: BattlePlayer, p_hud: BattleHud, p_results: BattleResults) -> void:
	player = p_player
	hud = p_hud
	results = p_results
	if not player.event_played.is_connected(_on_event_played):
		player.event_played.connect(_on_event_played)


## Coroutine: the whole battle (02_TECH §5.7).
func run(setup: BattleSetup) -> void:
	running = true
	state = BattleState.new(setup, DB.data)
	Show.begin_battle(setup)
	Events.battle_started.emit(setup.encounter_id, setup.is_boss)
	mark_roles()
	await _play(state.start())
	while not state.is_finished():
		var actor: Combatant = state.current_actor()
		if actor == null:
			push_error("[BattleController] no current actor in AWAIT_COMMAND")
			break
		Events.battle_turn_started.emit(actor.id, actor.is_party())
		var chosen: bool = actor.is_party() and (force_manual or not Game.auto_battle) and auto_turns <= 0 \
			and (force_manual or not is_partner_auto(actor.def_id))
		var cmd: BattleCommand = null
		if chosen:
			cmd = await hud.request_command(state, actor)
			if cmd == null:
				chosen = false                    # auto battle switched on while the menu was open
		if cmd == null:
			cmd = safe_ai_command(state, actor.id)
			if actor.is_party() and auto_turns > 0:
				auto_turns -= 1
		var events: Array[ActionEvent] = state.submit(cmd)
		if events.is_empty():
			push_error("[BattleController] submit returned no events for %s" % actor.id)
			break
		var d: Dictionary = cmd.to_dict()
		commands.append({"cmd": d, "auto": not chosen})
		Game.record({"t": "battle", "cmd": d, "auto": not chosen})
		await _play(events)
	running = false
	result = state.result
	if result == null:
		abort_unfinished()
		return
	Events.battle_ended.emit(result.outcome, result.encounter_id)
	var before: Dictionary = _party_snapshot()
	rewards = Game.apply_battle_result(result)
	rewards.followers = Show.end_battle(result)
	rewards.achievements = Show.unlocked_this_battle()
	if results != null:
		results.before = before
		await results.present(result, rewards)
	done = true
	finished.emit(result)
	if exit_on_end:
		Router.end_battle(result)


## 06 §1.4: does AutoPolicy play this party member? Only the partner (not the controlled hero) and only with
## "Partner automatisch" switched on.
static func is_partner_auto(member_def_id: String) -> bool:
	return Game.settings != null and Game.settings.partner_auto and member_def_id == Game.partner()


## Party panels: "DU" on the controlled character, "AUTO" on the partner while "Partner automatisch" is on.
func mark_roles() -> void:
	if hud == null or state == null:
		return
	var panels: Dictionary = hud.get("panels") as Dictionary
	if panels == null:
		return
	for c: Combatant in state.setup.party:          # BattleState builds its combatants only in start()
		if c == null or not panels.has(c.id):
			continue
		var p: Object = panels[c.id] as Object
		if p != null and p.has_method("set_role"):
			p.call("set_role", c.def_id == Game.hero(), not force_manual and is_partner_auto(c.def_id))


## The loop stopped without a BattleResult (a BattleState bug: no current actor, or no events for a validated
## command — reported by push_error). The player must never be stuck on the battle screen: the battle is dropped
## without rewards (Game.in_battle false, Show.abort_battle), `finished(null)` fires and, with exit_on_end, the Router
## returns to the previous screen (payload battle_result null).
func abort_unfinished() -> void:
	running = false
	Game.in_battle = false
	Show.abort_battle()
	done = true
	finished.emit(null)
	if exit_on_end:
		Router.end_battle(null)


## EnemyAI / AutoPolicy command of the current actor. An invalid one would make submit() return [] without consuming
## the turn and the battle loop would spin inside one frame forever, so it falls back to Verteidigen (always valid
## for the current actor) with a push_error (`report` false: tests). `st`: BattleState (or a test double).
static func safe_ai_command(st: Object, actor_id: String, report: bool = true) -> BattleCommand:
	var cmd: BattleCommand = st.call("choose_ai_command") as BattleCommand
	var reason: String = str(st.call("validate", cmd)) if cmd != null else "no command"
	if reason != "":
		if report:
			push_error("[BattleController] invalid AI command for %s (%s) → defend" % [actor_id, reason])
		cmd = BattleCommand.defend(actor_id)
	return cmd


func _play(events: Array[ActionEvent]) -> void:
	await player.play(events)          # BattlePlayer emits event_played(e) per event → Show.on_battle_event(e)
	if hud != null:
		hud.sync_from_state(state)
	if state.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(state)
	if not g.is_empty():
		gifts.append(g)
		var gift_events: Array[ActionEvent] = state.apply_gift(g)
		Show.note_battle_gift(g, gift_events)    # run counters / gift items, like RunSim (05 §6.9)
		await player.play(gift_events)
		if hud != null:
			hud.sync_from_state(state)


func _on_event_played(e: ActionEvent) -> void:
	Show.on_battle_event(e)


## member id → {"level", "exp"} before the rewards (results screen EXP bars).
func _party_snapshot() -> Dictionary:
	var out: Dictionary = {}
	if Game.state == null:
		return out
	for m: PartyMember in Game.state.party:
		if m != null:
			out[m.id] = {"level": m.level, "exp": m.exp}
	return out
