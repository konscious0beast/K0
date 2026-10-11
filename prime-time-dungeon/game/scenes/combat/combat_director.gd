class_name CombatDirector extends Node
## Real-time combat in the world (07 §2, §3.5, §9.2, §10.6; R2): owns the tick loop of the running Game.combat — per
## tick c (1) Game.combat_boundary(), (2) the MoveSampler sample and every input with ct == c via
## Game.combat_submit(cmd), (3) Game.combat_step() — plus the puppets, the LED set ring with its collision, the
## telegraph layer, the boss intro, flight / victory / defeat, the roll shutters, the combat camera, the temporary
## control switch and R3's combat HUD (one per combat, combat_hud.tscn). No signals of its own: start, events and end go
## through Events.combat_started / combat_event / combat_finished (it listens to them while armed).
##
## Lifecycle: the ExplorationScene owns one director (child, idle between combats). For a combat it arms it (arm(ctx):
## the set cell and its geometry) and calls Game.make_rt_setup(cmd); Events.combat_started then builds the set (ring +
## collision, telegraph clipping, puppets, the presentation of 07 §2.8) before the ct-0 prelude events arrive. Ticks
## run in _physics_process after the bodies moved (process_physics_priority), at combat_speed_pm (07 §7.6), at most
## MAX_CATCHUP ticks per frame (07 §3.15: the rest of a hitch is dropped); while a hint card stands (pause_for_hint) or
## the tree is paused, no tick passes. BATTLE_END is only flagged inside the event handler — Game.end_combat() runs
## after combat_step() returned.

const SetRingScript := preload("res://scenes/combat/set_ring.gd")
const TelegraphLayerScript := preload("res://scenes/combat/telegraph_layer.gd")
const MoveSamplerScript := preload("res://scenes/combat/move_sampler.gd")
const PuppetsScript := preload("res://scenes/combat/puppets.gd")
const Rules := preload("res://scenes/exploration/encounter_rules.gd")
const RESULTS_SCRIPT: String = "res://scenes/combat/ui/combat_results.gd"
const HUD_SCENE: String = "res://scenes/combat/ui/combat_hud.tscn"    # R3 (loaded by path: optional until merged)
const TICK_SEC: float = 1.0 / 30.0
const MAX_CATCHUP: int = 4                    # 07 §3.15: at most 4 ticks per frame, the rest of a hitch is dropped
const FLASH_SEC: float = 0.4                  # 07 §2.8: broadcast stinger, white flash 15 %
const FLASH_ALPHA: float = 0.15
const MUSIC_DELAY_TICKS: int = 150            # 07 §2.8 / O10: battle music once the combat runs 5 s; bosses at once
const MUSIC_FADE_SEC: float = 0.5
const GLIDE_CM: int = 60                      # 07 §3.5.2: corrections up to 60 cm glide 0.1 s, larger ones snap
const GLIDE_SEC: float = 0.1
const START_GLIDE_SEC: float = 0.3            # 07 §3.5.5: a party unit outside the ring glides onto it at ct 0
const INTRO_SEC: float = 2.5                  # 07 §2.9: "Boss-Kran" camera move
const INTRO_LINE_MAX_SEC: float = 12.0        # safety net for the blocking boss line
const BOSS_ZOOM: float = 9.0                  # 07 §7.5: combat zoom 8 m, bosses 9 m
const ZOOM: float = 8.0
const C_BOSS: Color = Color("#ff4d4d")
const C_INK: Color = Color("#140d1c")
const C_PAPER: Color = Color("#f5f0e6")
const LOWER_Y: float = 0.686                  # intro lower third: bottom edge (fraction of the height), …
const LOWER_RIGHT_X: float = 0.925            # … right edge (fraction of the width), as the CTB boss lower third

enum Phase { IDLE, INTRO, RUNNING, ENDING }

## The ExplorationScene (set by the scene).
var scene: ExplorationScene = null
var phase: Phase = Phase.IDLE
var ring: Node3D = null                       # set_ring.gd
var telegraphs: Node3D = null                 # telegraph_layer.gd
var puppets: Node3D = null                    # puppets.gd
var sampler: RefCounted = MoveSamplerScript.new()
## Armed context (exploration): {"cell": Vector2i, "origin": Vector3, "room_kind": int, "room_doors": int,
## "geo": RtGeo dictionary, "closed": bool, "boss": bool, "groups": PackedStringArray, "waiting": PackedStringArray}
var ctx: Dictionary = {}
var last_result: BattleResult = null
var last_rewards: BattleRewards = null
var ticks_run: int = 0                        # ticks this combat processed (diagnostics, tests)
var samples_sent: int = 0                     # accepted move samples
var corrections: int = 0                      # POS_CORRECTED events for the controlled unit
## Frame cost of the director (tick loop + puppets + telegraphs) in µs: last, maximum and sum over cost_frames
## (perf scenarios, 07 §8.10); reset at every combat start.
var cost_us: int = 0
var cost_max_us: int = 0
var cost_sum_us: int = 0
var cost_frames: int = 0
var intro_line: String = ""                   # the blocking boss line of the last intro ("" = none)
## Tests: false → no CombatResults panel / Router.game_over at the end (the end bookkeeping still runs).
var present_results: bool = true
## Tests: false → no combat HUD (its hint cards would hold the ticks of a test that drives the director itself).
var use_hud: bool = true
## Tests / captures: false → no tick passes in real time, only advance(n) steps the combat (deterministic stills).
var auto_tick: bool = true
## R3's combat HUD of the running combat (it gives the screen back and frees itself at Events.combat_finished).
var hud: CanvasLayer = null

var _armed: bool = false
var _acc: float = 0.0
var _alpha: float = 1.0
var _hint_id: String = ""
var _pending: Array[Dictionary] = []
var _finished: bool = false
var _music_on: bool = false
var _controlled: String = ""
var _flash: CanvasLayer = null
var _results: CanvasLayer = null
var _glide: Tween = null


func _init() -> void:
	name = "CombatDirector"
	process_physics_priority = 100            # after the player body moved this physics frame


func _ready() -> void:
	Events.combat_started.connect(_on_combat_started)
	Events.combat_event.connect(_on_combat_event)


# ======================================================================================================================
# Public API (07 §12.2 stub list: R3 calls submit / pause_for_hint / resume / unit_position)
# ======================================================================================================================

## An input of the controlled player for the current tick (ct = Game.combat.tick()); the director hands it to
## Game.combat_submit in step (2) of that tick. Inputs during a hint card keep the halted ct (07 §2.13).
func submit(cmd: Dictionary) -> void:
	if Game.combat == null or phase != Phase.RUNNING:
		return
	var c: Dictionary = cmd.duplicate(true)
	if RtCommand.CT_TYPES.has(str(c.get("t", ""))):
		c["ct"] = Game.combat.tick()
	_pending.append(c)


## Shows hint card `id` (07 §2.13): records it via Game.combat_hint and stops the ticks until resume(). The
## controlled body stands still meanwhile (no sample drifts away from the halted sim).
func pause_for_hint(id: String) -> void:
	if Game.combat == null or phase != Phase.RUNNING or _hint_id != "":
		return
	_hint_id = id
	Game.combat_hint(id)
	_update_player_drive()


## Continues the ticks after a hint card.
func resume() -> void:
	if _hint_id == "":
		return
	_hint_id = ""
	_acc = 0.0
	_update_player_drive()


func is_paused_for_hint() -> bool:
	return _hint_id != ""


## World position of the body or puppet of `unit_id` (interpolated; the controlled figure: its physics position);
## Vector3.ZERO if unknown.
func unit_position(unit_id: String) -> Vector3:
	if puppets == null:
		return Vector3.ZERO
	var p: Vector3 = puppets.call("position_of", unit_id)
	return Vector3.ZERO if p == Vector3.INF else p


## The controlled unit id of the running combat ("" outside).
func controlled_unit() -> String:
	return _controlled


## Head height of `unit_id`'s figure above its feet in metres (R3's name plates): the bound rig's height, else 1.5.
func unit_height(unit_id: String) -> float:
	var rig: Node3D = puppets.call("rig_of", unit_id) if puppets != null else null
	if rig == null or not is_instance_valid(rig) or not ("height" in rig):
		return 1.5
	return float(rig.get("height")) * rig.global_transform.basis.get_scale().y


# ======================================================================================================================
# Exploration side
# ======================================================================================================================

## Prepares the next Events.combat_started (the scene calls Game.make_rt_setup right after).
func arm(p_ctx: Dictionary) -> void:
	ctx = p_ctx.duplicate(true)
	_armed = true


func disarm() -> void:
	_armed = false


## A start that did not happen (no setup could be built): the intro's ring and shutters go away again.
func cancel() -> void:
	_armed = false
	if phase == Phase.INTRO:
		phase = Phase.IDLE
	if ring != null and is_instance_valid(ring):
		ring.call("set_shutters", false, 0.0)
		_drop_ring_now()
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null:
		cam.call("exit_combat")


func is_running() -> bool:
	return phase == Phase.RUNNING or phase == Phase.ENDING


## Drops a running combat without a result (perf scenarios; the exploration leaving the tree mid-combat): Game ends it
## like an aborted battle (no rewards, Show.abort_battle), the world goes back to exploring (groups unchanged).
func abort() -> void:
	if phase == Phase.IDLE:
		return
	if phase == Phase.INTRO:
		cancel()
		return
	phase = Phase.ENDING
	if Game.combat != null:
		Game.end_combat()
	if telegraphs != null:
		telegraphs.call("clear")
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null:
		cam.call("exit_combat")
	_hint_id = ""
	_pending.clear()
	if scene != null and scene.is_inside_tree():
		scene.rt_combat_ended(null, ctx)
	if puppets != null:
		puppets.call("release_all")
	_controlled = ""
	phase = Phase.IDLE
	_drop_ring_now()


func _exit_tree() -> void:
	if phase != Phase.IDLE and Game.combat != null:
		Game.end_combat()                     # never leave a combat behind (e.g. "Zum Titel" from the pause menu)


func is_busy() -> bool:
	return phase != Phase.IDLE


## Room entry (07 §8.10 rule 5): the extra rigs of every group in the cell are built invisibly now.
func prewarm(def_ids: PackedStringArray) -> void:
	_ensure_nodes()
	puppets.call("prewarm", def_ids, DB.data)


## 07 §2.9: boss intro in the world BEFORE the combat exists — the scene froze the exploration; shutters down (0.3 s,
## "Rolltor"), the closed 6 m ring lights up, the camera "Boss-Kran" (2.5 s) from the boss's face to the combat view,
## the banner and the blocking M.O.D. line boss_intro:<enemy_id> (the only blocking line in a combat context).
## Coroutine; the caller creates the RtSim afterwards (only then the encounter is recorded).
func run_boss_intro(p_ctx: Dictionary, boss: Node3D, boss_enemy_id: String, boss_name: String) -> void:
	_ensure_nodes()
	phase = Phase.INTRO
	ctx = p_ctx.duplicate(true)
	_build_set(ctx.get("geo", {}) as Dictionary)
	ring.call("set_shutters", true)
	Sfx.play(&"rt_shutter")
	ring.call("light_up")
	Sfx.play(&"rt_light_on", -4.0)
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null and boss != null:
		cam.call("enter_combat", BOSS_ZOOM, true)
		var head: Vector3 = boss.global_position + Vector3(0.0, _rig_height(boss) * 0.85, 0.0)
		cam.call("crane", head, Rules.flat_forward(boss.global_transform.basis), INTRO_SEC)
	_banner(tr("BOSS"), boss_name, C_BOSS)
	var tag: String = "boss_intro:" + boss_enemy_id
	intro_line = Show.say(tag, {}, true)
	var t0: int = Time.get_ticks_msec()
	if is_inside_tree():
		await get_tree().create_timer(INTRO_SEC, false).timeout
	if intro_line != "" and Game.has_dialog_presenter() and is_inside_tree():
		var done: Array[bool] = [false]
		var cb: Callable = func(t: String) -> void:
			if t == tag:
				done[0] = true
		Events.dialog_finished.connect(cb)
		while is_inside_tree() and not done[0] and Time.get_ticks_msec() - t0 < int(INTRO_LINE_MAX_SEC * 1000.0):
			await get_tree().process_frame
		if Events.dialog_finished.is_connected(cb):
			Events.dialog_finished.disconnect(cb)
	if phase == Phase.INTRO:
		phase = Phase.IDLE


# ======================================================================================================================
# Start
# ======================================================================================================================

func _ensure_nodes() -> void:
	if puppets != null:
		return
	puppets = PuppetsScript.new()
	add_child(puppets)
	telegraphs = TelegraphLayerScript.new()
	add_child(telegraphs)


func _on_combat_started(sim_ref: RefCounted) -> void:
	if not _armed or not is_inside_tree():
		return
	_armed = false
	var sim: RtSim = sim_ref as RtSim
	if sim == null or sim.setup == null:
		return
	_ensure_nodes()
	var companion: Node3D = scene.get_companion() if scene != null else null
	var comp_from: Vector3 = companion.global_position if companion != null else Vector3.INF
	phase = Phase.RUNNING
	_finished = false
	_acc = 0.0
	_alpha = 1.0
	_hint_id = ""
	_pending.clear()
	_music_on = false
	ticks_run = 0
	samples_sent = 0
	corrections = 0
	cost_us = 0
	cost_max_us = 0
	cost_sum_us = 0
	cost_frames = 0
	last_result = null
	last_rewards = null
	_controlled = sim.controlled_id()
	var geo: Dictionary = sim.setup.geo if not sim.setup.geo.is_empty() else ctx.get("geo", {})
	if ring == null or not is_instance_valid(ring):
		_build_set(geo)
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)
	telegraphs.call("setup", origin, float(int(geo.get("r", 480))) / 100.0,
		Game.settings != null and Game.settings.telegraph_contrast == &"high")
	puppets.set("origin", origin)
	sampler.call("reset")
	sampler.call("configure", sim.setup.balance)
	_bind_units(sim)
	puppets.call("snap")
	if comp_from != Vector3.INF:
		for u: RtUnit in sim.units():
			if u.side == Combatant.Side.PARTY and u.id != _controlled:
				puppets.call("glide_in", u.id, comp_from, START_GLIDE_SEC)
	_present_start(sim)
	_add_hud()


func _build_set(geo: Dictionary) -> void:
	if ring != null and is_instance_valid(ring):
		_drop_ring_now()
	ring = SetRingScript.new()
	add_child(ring)
	ring.call("build", ctx.get("origin", Vector3.ZERO), geo, int(ctx.get("room_doors", 0)))
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null:
		(cam.get("exclude") as Array).append(ring.call("body_rid"))


## Bodies for every unit: the controlled figure = the player body; the AI partner = the companion (puppet); a group's
## lead = its EnemyActor (puppet); every other enemy = a pooled extra rig with a smoke puff (Komparsen, 07 §2.3).
func _bind_units(sim: RtSim) -> void:
	var player: Node3D = scene.get_player() if scene != null else null
	var companion: Node3D = scene.get_companion() if scene != null else null
	var leads: Dictionary = _lead_units(sim)
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.PARTY:
			if u.id == _controlled and player != null:
				puppets.call("bind", u, player, player.get("rig"), &"player")
			elif companion != null:
				scene.rt_puppet_companion(true)
				puppets.call("bind", u, companion, companion.get("rig"), &"companion")
			continue
		var actor: Node3D = leads.get(u.id, null) as Node3D
		if actor != null and is_instance_valid(actor):
			scene.rt_puppet_actor(actor, true)
			puppets.call("bind", u, actor, actor.get("rig"), &"actor")
		else:
			puppets.call("bind_extra", u, true)
	_update_player_drive()


## Unit id → EnemyActor of the group it leads (the units are the party, then the enemies in group order; the first
## unit of every group is its lead, 07 §3.4 / §3.5.5).
func _lead_units(sim: RtSim) -> Dictionary:
	var out: Dictionary = {}
	var enemies: Array[RtUnit] = []
	for u: RtUnit in sim.units():
		if u.side == Combatant.Side.ENEMY and not u.is_summon:
			enemies.append(u)
	var i: int = 0
	for g: Dictionary in sim.setup.groups:
		var ids: Variant = g.get("enemy_ids", [])
		var n: int = 1
		if ids is Array:
			n = (ids as Array).size()
		elif ids is PackedStringArray:
			n = (ids as PackedStringArray).size()
		if i < enemies.size() and scene != null:
			var actor: Node3D = scene.get_enemy(str(g.get("group_id", "")))
			if actor != null:
				out[enemies[i].id] = actor
		i += maxi(1, n)
	return out


## 07 §2.8: ring + stinger + overlay mode + camera + music (bosses at once, regular fights after 5 s).
func _present_start(sim: RtSim) -> void:
	if ring != null and float(ring.call("brightness")) < 0.99:
		ring.call("light_up")
		Sfx.play(&"rt_light_on", -4.0)
	if ring != null and bool(ctx.get("closed", false)) and not bool(ring.call("shutters_down")):
		ring.call("set_shutters", true)
		Sfx.play(&"rt_shutter")
	_white_flash()
	Sfx.play(&"rt_stinger")
	Events.overlay_mode_requested.emit(&"combat")
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null:
		cam.call("enter_combat", BOSS_ZOOM if sim.setup.is_boss else ZOOM, false)
	if sim.setup.is_boss:
		_start_music(sim)


## R3's combat HUD (07 §8; integration note in combat_hud.gd): one per combat, setup({"director", "camera_rig"}),
## added while Game.combat is set, so it binds the combat at once and hears the ct-0 prelude.
func _add_hud() -> void:
	if not use_hud or not is_inside_tree() or not ResourceLoader.exists(HUD_SCENE):
		return
	var ps: PackedScene = load(HUD_SCENE) as PackedScene
	var node: Node = ps.instantiate() if ps != null else null
	if not (node is CanvasLayer):
		if node != null:
			node.free()
		return
	hud = node as CanvasLayer
	if hud.has_method("setup"):
		hud.call("setup", {"director": self, "camera_rig": scene.get_camera_rig() if scene != null else null})
	add_child(hud)


func _start_music(sim: RtSim) -> void:
	if _music_on:
		return
	_music_on = true
	Sfx.music(music_id(sim.setup), MUSIC_FADE_SEC)


## encounters[].rt.music, else the encounter's music, else battle / boss (07 §2.8).
static func music_id(s: BattleSetup) -> StringName:
	if s != null and DB.has_id("encounters", s.encounter_id):
		var enc: EncounterDef = DB.encounter(s.encounter_id)
		var m: String = str(enc.rt.get("music", "")) if not enc.rt.is_empty() else ""
		if m == "":
			m = enc.music
		if m != "":
			return StringName(m)
	return &"boss" if s != null and s.is_boss else &"battle"


func _white_flash() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if _flash == null or not is_instance_valid(_flash):
		_flash = CanvasLayer.new()
		_flash.name = "StingerFlash"
		_flash.layer = 30
		var rect: ColorRect = ColorRect.new()
		rect.name = "Flash"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.color = Color(1.0, 1.0, 1.0, 0.0)
		_flash.add_child(rect)
		add_child(_flash)
	var r: ColorRect = _flash.get_node("Flash") as ColorRect
	r.color = Color(1.0, 1.0, 1.0, FLASH_ALPHA)
	var tw: Tween = create_tween()
	tw.tween_property(r, "color:a", 0.0, FLASH_SEC).set_ease(Tween.EASE_OUT)


## TV lower third of the boss intro (07 §2.9 "Banner BOSS: <Name> mit Titelzeile"; the look of the CTB boss lower
## third, 03_ART §9.1): the kicker on the accent colour, the name on ink, right of the centre with its bottom edge
## LOWER_Y down the screen (above the M.O.D. box of the intro line); slides in 16 px, holds, fades out. Every banner
## after the combat start is the HUD's (R3).
func _banner(kicker: String, title: String, color: Color) -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "IntroBanner"
	layer.layer = 31
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	box.anchor_left = LOWER_RIGHT_X
	box.anchor_right = LOWER_RIGHT_X
	box.anchor_top = LOWER_Y
	box.anchor_bottom = LOWER_Y
	layer.add_child(box)
	var kick: PanelContainer = _banner_panel(color, Color(0.0, 0.0, 0.0, 0.0), Vector4(22, 2, 22, 2))
	box.add_child(kick)
	kick.add_child(_banner_label(kicker.to_upper(), 18, C_INK, 0))
	var name_box: PanelContainer = _banner_panel(Color(C_INK, 0.9), color, Vector4(30, 4, 34, 6))
	var sb: StyleBoxFlat = name_box.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_width_left = 6
	sb.border_width_bottom = 2
	box.add_child(name_box)
	name_box.add_child(_banner_label(title, 36, C_PAPER, 6))
	box.reset_size()
	var sz: Vector2 = box.get_combined_minimum_size()
	box.offset_top = -sz.y
	box.offset_bottom = 0.0
	box.offset_left = -sz.x + 16.0
	box.offset_right = 16.0
	box.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.18)
	tw.tween_property(box, "offset_left", -sz.x, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "offset_right", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(INTRO_SEC - 0.4)
	tw.chain().tween_property(box, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(layer.queue_free)


static func _banner_panel(bg: Color, border: Color, margin: Vector4) -> PanelContainer:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.skew = Vector2(0.21, 0.0)
	sb.content_margin_left = margin.x
	sb.content_margin_top = margin.y
	sb.content_margin_right = margin.z
	sb.content_margin_bottom = margin.w
	sb.anti_aliasing = true
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _banner_label(text: String, size: int, color: Color, outline: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_INK)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_font_override("font", UiTheme.font_bold())
	return l


# ======================================================================================================================
# Tick loop
# ======================================================================================================================

func _physics_process(delta: float) -> void:
	if phase != Phase.RUNNING or Game.combat == null:
		return
	var t0: int = Time.get_ticks_usec()
	var sim: RtSim = Game.combat
	if auto_tick and _hint_id == "" and not _finished:
		_acc += delta * _speed()
		var n: int = 0
		while _acc >= TICK_SEC and n < MAX_CATCHUP and not _finished:
			_acc -= TICK_SEC
			n += 1
			_tick(sim)
		if n >= MAX_CATCHUP and _acc >= TICK_SEC:
			_acc = fmod(_acc, TICK_SEC)          # 07 §3.15: never spiral — the rest of a hitch is dropped
	_alpha = clampf(_acc / TICK_SEC, 0.0, 1.0) if auto_tick else 1.0
	_present_frame(delta)
	cost_us = Time.get_ticks_usec() - t0
	cost_max_us = maxi(cost_max_us, cost_us)
	cost_sum_us += cost_us
	cost_frames += 1
	if _finished and phase == Phase.RUNNING:
		_finish()


## Steps the combat `n` ticks right now (tests, captures, perf scenarios): the same per-tick order as the loop.
func advance(n: int) -> void:
	for _i in n:
		if phase != Phase.RUNNING or Game.combat == null or _finished or _hint_id != "":
			break
		_tick(Game.combat)
	_alpha = 1.0
	_present_frame(0.0)
	if _finished and phase == Phase.RUNNING:
		_finish()


static func _speed() -> float:
	return float(Game.settings.combat_speed_pm if Game.settings != null else 1000) / 1000.0


## One combat tick c (07 §9.2): boundary → sample + inputs with ct == c → step.
func _tick(sim: RtSim) -> void:
	var c: int = sim.tick()
	Game.combat_boundary()
	_submit_sample(sim, c)
	var cmds: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	for cmd: Dictionary in cmds:
		if RtCommand.CT_TYPES.has(str(cmd.get("t", ""))):
			cmd["ct"] = c
		Game.combat_submit(cmd)
	Game.combat_step()
	ticks_run += 1
	if Game.combat == null:
		return
	puppets.call("sync", sim.units())
	_update_player_drive()
	if not _music_on and sim.tick() >= MUSIC_DELAY_TICKS:
		_start_music(sim)


## Step (2a): the controlled body's sample when one is due (07 §3.5.1); none while the sim drives the unit.
func _submit_sample(sim: RtSim, c: int) -> void:
	var u: RtUnit = sim.unit(_controlled)
	var player: Node3D = scene.get_player() if scene != null else null
	if u == null or u.driver != RtUnit.Driver.PLAYER or u.hp <= 0 or player == null:
		return
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)
	var p: Vector2i = MoveSamplerScript.local_cm(player.global_position, origin)
	var vel: Vector3 = (player as CharacterBody3D).velocity if player is CharacterBody3D else Vector3.ZERO
	var v: Vector2i = MoveSamplerScript.vel_mm(vel)
	var yaw: int = MoveSamplerScript.yaw_u8(player.rotation.y)
	var soon: bool = bool(telegraphs.call("impacts_at", c)) or bool(telegraphs.call("impacts_at", c + 1))
	var s: Array[int] = sampler.call("sample_for", c, p.x, p.y, v.x, v.y, yaw, soon)
	if s.is_empty():
		return
	if Game.combat_submit(RtCommand.move(c, _controlled, s[0], s[1], s[2], s[3], s[4])) == "":
		samples_sent += 1


## The player body is driven by the input (PLAYER) or follows the sim like a puppet (AUTOPILOT, 07 §5.1); its speed
## follows the controlled unit's move_pm and the combat speed (honest samples never exceed the plausibility limits,
## 07 §3.5.2); no_move statuses, a drinking pause, a KO and a hint card hold it (07 §3.11, §2.13).
func _update_player_drive() -> void:
	var sim: RtSim = Game.combat
	if scene == null or sim == null:
		return
	var u: RtUnit = sim.unit(_controlled)
	if u == null:
		return
	var auto: bool = u.driver == RtUnit.Driver.AUTOPILOT
	var e: Dictionary = (puppets.get("entries") as Dictionary).get(_controlled, {})
	if not e.is_empty():
		e["kind"] = &"autopilot" if auto else &"player"
	var pm: int = move_pm(u, DB.data)
	if u.hp <= 0 or str(u.cast.get("kind", "")) == "item" or _hint_id != "":
		pm = 0
	scene.rt_player_drive(not auto, float(pm) / 1000.0 * _speed())


## Movement factor (‰) of a unit from its statuses (07 §3.5.3: no_move → 0, move_pm per stack) — presentation only,
## the sim stays authoritative (a mismatch becomes a correction).
static func move_pm(u: RtUnit, _data: GameData = null) -> int:
	var f: int = 1000
	for st: StatusEffect in u.statuses:
		var def: StatusDef = st.def
		if def == null or def.rt.is_empty():
			continue
		var flags: Variant = def.rt.get("flags", [])
		if flags is Array and (flags as Array).has("no_move"):
			return 0
		var m: int = int(def.rt.get("move_pm", 1000))
		var stacks: int = maxi(1, int(st.get("stacks"))) if "stacks" in st else 1
		for _i in stacks:
			f = f * m / 1000
	return f


func _present_frame(delta: float) -> void:
	puppets.call("apply", _alpha, delta)
	var sim: RtSim = Game.combat
	if sim != null:
		telegraphs.call("update", float(sim.tick() - 1) + _alpha, delta)


# ======================================================================================================================
# Events
# ======================================================================================================================

func _on_combat_event(ev: RefCounted) -> void:
	if phase != Phase.RUNNING or not is_inside_tree():
		return
	var e: ActionEvent = ev as ActionEvent
	if e == null:
		return
	telegraphs.call("on_event", e)
	match e.type:
		ActionEvent.Type.SWING:
			puppets.call("play", e.actor_id, &"attack")
		ActionEvent.Type.ACTION_START:
			puppets.call("play", e.actor_id, _action_anim(e))
		ActionEvent.Type.CAST_START:
			puppets.call("play", e.actor_id, &"cast")
		ActionEvent.Type.DAMAGE:
			puppets.call("hit", e.target_id, e.crit)
		ActionEvent.Type.HEAL:
			var hp: Vector3 = unit_position(e.target_id)
			if hp != Vector3.ZERO:
				Vfx.spawn(&"heal", puppets, hp + Vector3(0.0, 0.6, 0.0))
		ActionEvent.Type.KO:
			puppets.call("knock_out", e.target_id, e.target_id.begins_with("e"))
		ActionEvent.Type.REVIVE:
			puppets.call("revive", e.target_id)
		ActionEvent.Type.SUMMON:
			var su: RtUnit = Game.combat.unit(e.target_id) if Game.combat != null else null
			if su != null and not bool(puppets.call("has", su.id)):
				puppets.call("bind_extra", su, true)
		ActionEvent.Type.ESCAPED:
			puppets.call("knock_out", e.target_id, true)
		ActionEvent.Type.TELEGRAPH_START:
			Sfx.play(&"rt_telegraph", -6.0)
		ActionEvent.Type.TELEGRAPH_IMPACT:
			for id: String in e.target_ids:
				if id.begins_with("p"):
					_shake()
					break
		ActionEvent.Type.POS_CORRECTED:
			if e.target_id == _controlled:
				corrections += 1
				_correct_player(int(e.rt.get("x", 0)), int(e.rt.get("z", 0)), START_GLIDE_SEC if e.tick == 0 else 0.0)
		ActionEvent.Type.CONTROL_CHANGED:
			_control_switch(e.actor_id, e.target_id)
		ActionEvent.Type.PHASE_CHANGE:
			var rig: Node3D = puppets.call("rig_of", e.actor_id)
			if rig != null and rig.has_method("set_boss_phase"):
				rig.call("set_boss_phase", e.value)
		ActionEvent.Type.BATTLE_END:
			_finished = true


static func _action_anim(e: ActionEvent) -> StringName:
	match e.command:
		BattleCommand.Kind.STUNT:
			return &"stunt"
		BattleCommand.Kind.ITEM:
			return &"item"
	return &"attack"


## 07 §3.5.2: the scene puts the figure where the sim says — up to GLIDE_CM as a 0.1 s glide, else at once; `sec` > 0
## glides over that time whatever the distance (07 §3.5.5: the start correction onto the ring, 0.3 s).
func _correct_player(x: int, z: int, sec: float = 0.0) -> void:
	var player: Node3D = scene.get_player() if scene != null else null
	if player == null:
		return
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)
	var to: Vector3 = Vector3(origin.x + x / 100.0, player.global_position.y, origin.z + z / 100.0)
	var d: float = Vector2(to.x - player.global_position.x, to.z - player.global_position.z).length() * 100.0
	if _glide != null and _glide.is_valid():
		_glide.kill()
	if (d <= GLIDE_CM or sec > 0.0) and is_inside_tree():
		_glide = create_tween()
		_glide.tween_property(player, "global_position", to, sec if sec > 0.0 else GLIDE_SEC)
	else:
		player.call("teleport", to, player.rotation.y)
	sampler.call("reset")                     # the next sample starts from the corrected position


## 07 §2.6, §5.1: control follows life — the player body becomes the living figure, the fallen one lies as a puppet.
func _control_switch(prev_id: String, new_id: String) -> void:
	var sim: RtSim = Game.combat
	if sim == null or scene == null:
		return
	var nu: RtUnit = sim.unit(new_id)
	var pu: RtUnit = sim.unit(prev_id)
	if nu == null:
		return
	_controlled = new_id
	scene.control_temporarily(nu.def_id)
	puppets.call("unbind", new_id)
	puppets.call("unbind", prev_id)
	var player: Node3D = scene.get_player()
	var companion: Node3D = scene.get_companion()
	puppets.call("bind", nu, player, player.get("rig"), &"player")
	if pu != null and companion != null:
		puppets.call("bind", pu, companion, companion.get("rig"), &"companion")
		if pu.hp <= 0:
			puppets.call("lie_down", prev_id)
	sampler.call("reset")
	_update_player_drive()


func _shake() -> void:
	if Game.settings != null and not Game.settings.camera_shake:
		return
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null and cam.has_method("shake"):
		cam.call("shake", 0.15, 0.08)


static func _rig_height(n: Node3D) -> float:
	var rig: Variant = n.get("rig") if "rig" in n else null
	if rig is Node3D and "height" in (rig as Node3D):
		return float((rig as Node3D).get("height"))
	return 1.5


# ======================================================================================================================
# End
# ======================================================================================================================

## 07 §2.11: Game.end_combat (apply_battle_result → Show.end_battle → combat_finished → battle_ended), then the scene's
## bookkeeping (defeated groups vanish, fled groups reset, bodies back), the ring fades, results; a boss victory shows
## the credits panel (CombatResults, pauses) and opens the shutters afterwards; a defeat is the existing sign-off.
func _finish() -> void:
	phase = Phase.ENDING
	var result: BattleResult = Game.combat.result if Game.combat != null else null
	var boss: bool = Game.combat != null and Game.combat.setup != null and Game.combat.setup.is_boss
	last_rewards = Game.end_combat()
	last_result = result
	telegraphs.call("clear")
	if ring != null and is_instance_valid(ring):
		ring.call("fade_out")
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null:
		cam.call("exit_combat")
	_hint_id = ""
	_pending.clear()
	var outcome: int = int(result.outcome) if result != null else -1
	if scene != null:
		scene.rt_combat_ended(result, ctx)
	puppets.call("release_all")
	_controlled = ""
	phase = Phase.IDLE
	if outcome == BattleResult.Outcome.DEFEAT:
		if present_results:
			Router.game_over(&"defeat")
		return
	if present_results and result != null:
		await _present_results(result, last_rewards)
	if boss and ring != null and is_instance_valid(ring):
		ring.call("set_shutters", false)
		Sfx.play(&"rt_shutter")
	_drop_ring_later()


func _present_results(result: BattleResult, rewards: BattleRewards) -> void:
	if not ResourceLoader.exists(RESULTS_SCRIPT):
		return
	if _results == null or not is_instance_valid(_results):
		var script: GDScript = load(RESULTS_SCRIPT) as GDScript
		if script == null:
			return
		_results = script.new() as CanvasLayer
		if _results == null:
			return
		_results.name = "CombatResults"
		if Game.autoplay:
			_results.set("auto_continue_sec", 1.0)
		add_child(_results)
	await _results.call("present", result, rewards)


## The faded ring (and its collision) goes after its fade-out; a new combat in the meantime keeps its own ring.
func _drop_ring_later() -> void:
	if ring == null or not is_inside_tree():
		return
	var old: Node3D = ring
	await get_tree().create_timer(SetRingScript.FADE_OUT_SEC + 0.1, false).timeout
	if is_instance_valid(old) and old == ring and phase == Phase.IDLE:
		_drop_ring_now()


func _drop_ring_now() -> void:
	if ring == null:
		return
	var cam: Node3D = scene.get_camera_rig() if scene != null else null
	if cam != null and is_instance_valid(ring):
		(cam.get("exclude") as Array).erase(ring.call("body_rid"))
	if is_instance_valid(ring):
		ring.queue_free()
	ring = null
