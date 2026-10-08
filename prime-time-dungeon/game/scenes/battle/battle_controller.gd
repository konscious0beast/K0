extends Node
## BattleController (02_TECH §5.7, 05_LIVE_MODUS CR-7): drives BattleState — Show.begin_battle, battle_started,
## plays every event list through the BattlePlayer (event_played → Show.on_battle_event), asks the HUD for party
## commands (or AutoPolicy / EnemyAI), records each command as {"t": "battle", "cmd", "auto"}, delivers pending gifts
## at the turn boundary (Show.take_pending_gift → BattleState.apply_gift), then battle_ended → Game.apply_battle_result
## → Show.end_battle / unlocked_this_battle → results → Router.end_battle. Private M5 helper (no class_name).

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
	await _play(state.start())
	while not state.is_finished():
		var actor: Combatant = state.current_actor()
		if actor == null:
			push_error("[BattleController] no current actor in AWAIT_COMMAND")
			break
		Events.battle_turn_started.emit(actor.id, actor.is_party())
		var chosen: bool = actor.is_party() and (force_manual or not Game.auto_battle) and auto_turns <= 0
		var cmd: BattleCommand = null
		if chosen:
			cmd = await hud.request_command(state, actor)
			if cmd == null:
				chosen = false                    # auto battle switched on while the menu was open
		if cmd == null:
			cmd = state.choose_ai_command()
			if actor.is_party() and auto_turns > 0:
				auto_turns -= 1
		if cmd == null:
			push_error("[BattleController] no command for %s" % actor.id)
			break
		var d: Dictionary = cmd.to_dict()
		commands.append({"cmd": d, "auto": not chosen})
		Game.record({"t": "battle", "cmd": d, "auto": not chosen})
		await _play(state.submit(cmd))
	running = false
	result = state.result
	if result == null:
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


func _play(events: Array[ActionEvent]) -> void:
	await player.play(events)          # BattlePlayer emits event_played(e) per event → Show.on_battle_event(e)
	if hud != null:
		hud.sync_from_state(state)
	if state.is_finished():
		return
	var g: Dictionary = Show.take_pending_gift(state)
	if not g.is_empty():
		gifts.append(g)
		await player.play(state.apply_gift(g))
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
