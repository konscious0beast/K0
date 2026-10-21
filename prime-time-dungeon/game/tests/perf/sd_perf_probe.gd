extends SceneTree
## Performance probe of the Stempelduell (10 §6.10), the "stempel" scenario of tools/perf.sh (its marked section runs
## it under Xvfb; headless only the timings). The table against the Stempelmeister with the Durchsage on the board (the
## fullest table: phase chip, two Zuständigkeiten rows, the M.O.D. box, the Prognose) inside the real GlobalUi
## (overlay "duel", ModDialog). Checks the targets of 10 §6.10:
##   UI draw calls ≤ 120 (canvas, the whole frame), 3D draw calls 0, rulebook ≤ 50 ms, table build ≤ 300 ms (warm;
##   cold printed), a move ≤ 2 ms and a dry run (preview) ≤ 3 ms on average, no _process / _physics_process in the
##   table while it waits, at most one particle emitter.
## Prints a Markdown table and "PERF: OK" or "PERF: OVER BUDGET (<n>): …"; exit code 1 when over budget.
## godot --path <game> [--rendering-driver opengl3 --resolution 1280x720] -s res://tests/perf/sd_perf_probe.gd

const TABLE: String = "res://scenes/stempel/sd_table.tscn"
const GLOBAL_UI: String = "res://scenes/ui/global_ui.tscn"
const SESSION: String = "res://scenes/stempel/sd_session.gd"
const SEED: int = 11
const BUDGET_DC_UI: int = 120
const BUDGET_DC_3D: int = 0
const BUDGET_RULEBOOK_MS: float = 50.0
const BUDGET_BUILD_MS: float = 300.0
const BUDGET_MOVE_MS: float = 2.0
const BUDGET_PREVIEW_MS: float = 3.0
const BUDGET_EMITTERS: int = 1
const SAMPLE_FRAMES: int = 60

var _over: PackedStringArray = []
var _rows: Array[Array] = []
var _rendered: bool = false


func _initialize() -> void:
	await process_frame
	_rendered = DisplayServer.get_name() != "headless"
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.set("ephemeral", true)
	var save: Node = root.get_node_or_null("Save")
	if save != null:
		save.set("read_only", true)
	var session: GDScript = load(SESSION) as GDScript
	session.set("ephemeral", true)
	print("# Stempelduell — Perf-Probe (10 §6.10), %s" % ("%dx%d, %s" % [root.get_visible_rect().size.x,
		root.get_visible_rect().size.y, RenderingServer.get_current_rendering_driver_name()] if _rendered
		else "headless"))
	_rulebook()
	_engine_timings(session)
	await _table_section(session)
	print("")
	print("| Größe | Wert | Ziel |")
	print("|---|---|---|")
	for r: Array in _rows:
		print("| %s | %s | %s |" % [str(r[0]), str(r[1]), str(r[2])])
	print("")
	if _over.is_empty():
		print("PERF: OK")
	else:
		print("PERF: OVER BUDGET (%d): %s" % [_over.size(), "; ".join(_over)])
	quit(0 if _over.is_empty() else 1)


func _row(what: String, value: String, target: String, ok: bool) -> void:
	_rows.append([what, value, target])
	if not ok:
		_over.append("%s %s (%s)" % [what, value, target])


## The rulebook from its files (fresh loads, not the session's shared one): the first load also compiles the scripts
## of core/stempel (printed), the budget holds the load itself (files, validator, engine data, rules_hash).
func _rulebook() -> void:
	var keep: Array[SdRulebook] = []                     # no rulebook is freed inside a timed load
	var t0: int = Time.get_ticks_usec()
	keep.append(SdRulebook.load_dir())
	var cold: float = (Time.get_ticks_usec() - t0) / 1000.0
	var best: float = INF
	for i in 3:
		var t1: int = Time.get_ticks_usec()
		keep.append(SdRulebook.load_dir())
		best = minf(best, (Time.get_ticks_usec() - t1) / 1000.0)
	var b: SdRulebook = keep.back()
	_row("Regelbuch laden (erstes Mal mit Skripten %.0f ms)" % cold, "%.1f ms" % best, "≤ %d ms"
		% int(BUDGET_RULEBOOK_MS), b.is_valid() and best <= BUDGET_RULEBOOK_MS)


## A move and a dry run on the engine, averaged over whole duels (Graf's suggestions against the Stempelmeister).
func _engine_timings(session: GDScript) -> void:
	var b: SdRulebook = session.call("book") as SdRulebook
	var moves: int = 0
	var move_us: int = 0
	var previews: int = 0
	var preview_us: int = 0
	for s in range(SEED, SEED + 6):
		var duel: SdDuel = SdDuel.new(SdSetup.create(b, "sdo_meister", b.startmappe_list(), s), b)
		duel.start()
		var guard: int = 0
		while not duel.is_finished() and guard < 200:
			guard += 1
			if duel.side_to_move() != SdDuel.Side.PLAYER:
				duel.submit(duel.opponent_move())
				continue
			for slot in duel.hand(SdDuel.Side.PLAYER).size():
				var p0: int = Time.get_ticks_usec()
				duel.preview({"op": "play", "slot": slot})
				preview_us += Time.get_ticks_usec() - p0
				previews += 1
			var m: Dictionary = SdAi.suggest(duel)
			var t0: int = Time.get_ticks_usec()
			duel.submit(m)
			move_us += Time.get_ticks_usec() - t0
			moves += 1
	var mv: float = move_us / 1000.0 / maxf(1.0, float(moves))
	var pv: float = preview_us / 1000.0 / maxf(1.0, float(previews))
	_row("Zug (Mittel, %d Züge)" % moves, "%.2f ms" % mv, "≤ %d ms" % int(BUDGET_MOVE_MS), mv <= BUDGET_MOVE_MS)
	_row("Vorschau (Mittel, %d Probeläufe)" % previews, "%.2f ms" % pv, "≤ %d ms" % int(BUDGET_PREVIEW_MS),
		pv <= BUDGET_PREVIEW_MS)


## The table in the real UI: build times, the fullest board, draw calls, idle processing, emitters.
func _table_section(session: GDScript) -> void:
	var ui: Node = (load(GLOBAL_UI) as PackedScene).instantiate()
	root.add_child(ui)
	var cold: float = 0.0
	var warm: float = 0.0
	var table: Node = null
	for i in 2:
		session.call("use_sample")                       # the sample collection, never saved (ephemeral)
		var t0: int = Time.get_ticks_usec()
		table = (load(TABLE) as PackedScene).instantiate()
		# no "capture": the M.O.D. lines and the waiting-room loop run as in the game (the cold build synthesizes it)
		table.call("setup", {"opp": "sdo_meister", "mappe": "a", "seed": SEED})
		root.add_child(table)
		var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
		if i == 0:
			cold = ms
			for k in 3:
				await process_frame
			table.queue_free()
			await process_frame
		else:
			warm = ms
	_row("Tisch aufbauen (warm; kalt %.0f ms)" % cold, "%.0f ms" % warm, "≤ %d ms" % int(BUDGET_BUILD_MS),
		warm <= BUDGET_BUILD_MS)
	# the fullest table: the Stempelmeister in phase 2, the Durchsage at the second place
	var ok: bool = await _until(func() -> bool: return _waits(table), 1200)
	if ok:
		table.set("instant", true)
		for n in 160:
			var d: SdDuel = table.get("duel") as SdDuel
			if d.is_finished():
				break
			var foe: Combatant = d.combatant(SdDuel.Side.OPPONENT)
			var order: PackedStringArray = d.order()
			if _waits(table) and foe.phase >= 1 and order.size() > 1 and order[1].begins_with("u"):
				break
			if _waits(table):
				table.call("_submit_player", SdAi.suggest(d))
			await process_frame
		table.set("instant", false)
		table.call("_player_turn")
	var acc: Dictionary = {"dc": 0, "canvas": 0, "dc3d": 0}
	for f in SAMPLE_FRAMES:
		if _rendered:
			await RenderingServer.frame_post_draw
		else:
			await process_frame
		var vp: RID = root.get_viewport_rid()
		acc["dc"] = maxi(int(acc["dc"]), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		acc["canvas"] = maxi(int(acc["canvas"]), RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		acc["dc3d"] = maxi(int(acc["dc3d"]), RenderingServer.viewport_get_render_info(vp,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	if _rendered:
		_row("UI-Draw-Calls (ganzes Bild, max. %d Frames)" % SAMPLE_FRAMES, str(acc["dc"]), "≤ %d" % BUDGET_DC_UI,
			int(acc["dc"]) <= BUDGET_DC_UI)
		_row("3D-Draw-Calls", str(acc["dc3d"]), "%d (keine Drohne in der Duell-Box)" % BUDGET_DC_3D,
			int(acc["dc3d"]) <= BUDGET_DC_3D)
	else:
		_row("UI-Draw-Calls", "– (headless)", "≤ %d" % BUDGET_DC_UI, true)
	# idle: nothing processes per frame while the table waits for the player
	var busy_nodes: PackedStringArray = []
	var emitters: int = 0
	for n2: Node in table.find_children("*", "", true, false) + [table]:
		if n2.is_processing() or n2.is_physics_processing():
			busy_nodes.append(str(n2.name))
		if n2 is CPUParticles2D or n2 is GPUParticles2D:
			emitters += 1
	_row("_process im Leerlauf", "keiner" if busy_nodes.is_empty() else ", ".join(busy_nodes), "keiner",
		busy_nodes.is_empty())
	_row("Partikel-Emitter", str(emitters), "≤ %d" % BUDGET_EMITTERS, emitters <= BUDGET_EMITTERS)
	table.queue_free()
	ui.queue_free()
	for k in 10:                                         # the mix thread releases the stopped playbacks
		await process_frame


func _waits(t: Node) -> bool:
	var d: SdDuel = t.get("duel") as SdDuel
	return d != null and not bool(t.get("busy")) and not bool(t.get("finished")) \
		and d.side_to_move() == SdDuel.Side.PLAYER


func _until(cond: Callable, limit: int) -> bool:
	for i in limit:
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())
