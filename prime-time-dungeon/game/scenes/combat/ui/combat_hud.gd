extends CanvasLayer
## Real-time combat HUD (07 §8, R3): the TV overlay of a running RtSim — unit frames, target / boss frames, cast bars,
## name plates, action bar (PC / pad) or thumb group (touch), Partner-Spezial, Taktik-Chip, combat text, banners, flee
## countdown, hint cards, item wheel, tactic panel — and the combat input (CombatInput). Layers (02_TECH §9.4): this one
## 6 (above the exploration HUD), the thumb group 21 (above TouchControls), hint card / wheel / tactic panel 46 (above
## the M.O.D. subtitles: cards have priority over every line, 07 §9.3), combat text twins 4.
## Integration (R2): the CombatDirector instantiates res://scenes/combat/ui/combat_hud.tscn, calls
## setup({"director": <CombatDirector>, "camera_rig": <CameraRig, optional>}) and adds it; the HUD binds itself to
## Events.combat_started (or bind(Game.combat) when added later), reads its states every frame from the pure RtSim
## queries (07 §8.2), routes Events.combat_event, sends every input through CombatDirector.submit and pauses for hint
## cards with pause_for_hint / resume. At Events.combat_finished it gives the screen back (overlay mode, dialog layout,
## input map, touch layer) and frees itself after a 0.25 s fade; the results are CombatResults (combat_results.gd).
## While bound: ShowOverlay mode &"combat" (timer chip, 07 §8.8), ModDialog subtitle layout (Events.
## dialog_layout_requested, 07 §8.8), CombatInput.apply_input_mode(true) (07 §7.7), TouchControls combat mode
## (stick bottom left only, tap ≠ drag, 07 §7.3). Private R3 script (scene root, loaded by path, 02_TECH §13.2).

const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const ActionBar := preload("res://scenes/combat/ui/action_bar.gd")
const UnitFrames := preload("res://scenes/combat/ui/unit_frames.gd")
const Nameplates := preload("res://scenes/combat/ui/nameplates.gd")
const HintCards := preload("res://scenes/combat/ui/hint_cards.gd")
const CombatBanner := preload("res://scenes/combat/ui/combat_banner.gd")
const CombatTouch := preload("res://scenes/combat/ui/combat_touch.gd")
const ItemWheel := preload("res://scenes/combat/ui/item_wheel.gd")
const TacticPanel := preload("res://scenes/combat/ui/tactic_panel.gd")
const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const UiUtil := preload("res://scenes/ui/ui_util.gd")
const InputGlyph := preload("res://scenes/ui/input_glyph.gd")
const TouchScript := preload("res://scenes/ui/touch_controls.gd")

const LAYER_HUD: int = 6
const LAYER_TOUCH: int = 21
const LAYER_OVERLAY: int = 46
const FADE_SEC: float = 0.25
const BAR_BOTTOM: float = 36.0              # action bar bottom edge above the safe frame bottom (07 §8.1)
const CAST_BOTTOM: float = 108.0            # player cast bar (PC); touch 100 at x = 590
## Touch: the middle column between stick and thumb group sits 50 px left of the centre (x 590 / 330–850 at 1280,
## 07 §8.1) and keeps that offset on wider phones.
const TOUCH_SHIFT: float = -50.0
const FLEE_Y: float = 276.0                 # abs y 300
const TOAST_SEC: float = 1.6
const SUBTITLE_PC: Dictionary = {"bottom": 130, "width": 600, "max_lines": 2, "blocking": false,
	"mouse_filter_ignore": true}
const SUBTITLE_TOUCH: Dictionary = {"bottom": 36, "width": 520, "shift": TOUCH_SHIFT, "max_lines": 2,
	"blocking": false, "mouse_filter_ignore": true}
## Optional sounds of R2's synth (07 §8.3 "Ding" / "Plattennadel-Kratzer") with existing fallbacks.
const SFX_DING: Array[StringName] = [&"rt_ding", &"coin"]
const SFX_SCRATCH: Array[StringName] = [&"rt_scratch", &"ui_cancel"]

## Bound combat (null before Events.combat_started / bind).
var sim: RtSim = null
## The CombatDirector (or a test double with submit / pause_for_hint / resume / unit_position).
var director: Node = null
var input: CombatInput = null
var bar: Control = null
var frames: Control = null
var plates: Control = null
var hints: Control = null
var banner: Control = null
var touch_ui: Control = null
var wheel: Control = null
var tactic: Control = null
## Every command this HUD sent (tests / captures).
var sent: Array[Dictionary] = []
## Events seen (tests).
var events_seen: int = 0

var _params: Dictionary = {}
var _root: Control
var _frame: Control
var _show_overlay: Node = null              # R5b: GlobalUi's ShowOverlay (its hype meter, _hype_left)
var _overlay_layer: CanvasLayer
var _overlay_frame: Control
var _touch_layer: CanvasLayer
var _cast_bar: Control
var _cast_label: Label
var _cast_time: Label
var _flee: Label
var _toast: Label
var _autopilot: Label
var _text_anchor: Node3D
var _touch: bool = false
var _toast_t: float = 0.0
var _flee_left: int = -1
var _flee_at: int = -1
var _threat: bool = false
var _ending: bool = false
var _modes_applied: bool = false
var _fail_t: float = 0.0
var _cast_fail_text: String = ""
var _data: GameData = null


## {"director": Node, "camera_rig": Node3D, "sim": RtSim (bind at once), "data": GameData (defs of the sim; default
##  DB.data), "auto_events": bool (default true: Events.combat_*), "modes": bool (default true: overlay / dialog /
##  input map / touch modes)}.
func setup(params: Dictionary) -> void:
	_params = params
	director = params.get("director", null) as Node


func _init() -> void:
	layer = LAYER_HUD


func _ready() -> void:
	_build()
	if bool(_params.get("auto_events", true)):
		Events.combat_started.connect(func(s: RefCounted) -> void: bind(s as RtSim))
		Events.combat_event.connect(func(e: RefCounted) -> void: on_event(e as ActionEvent))
		Events.combat_finished.connect(func(r: RefCounted) -> void: finish(r as BattleResult))
		Events.input_scheme_changed.connect(func(_s: int) -> void: _apply_scheme())
		Events.settings_changed.connect(_apply_scheme)
	var s0: RtSim = _params.get("sim", null) as RtSim
	if s0 == null and Game.combat != null:
		s0 = Game.combat
	if s0 != null:
		bind(s0)


func _exit_tree() -> void:
	_restore_modes()
	CombatStyle.data = null


# --- binding ---------------------------------------------------------------------------------------------------------

## Binds a running combat: builds the per-combat state, applies the combat modes, starts the hint cards.
func bind(p_sim: RtSim) -> void:
	if p_sim == null:
		return
	sim = p_sim
	_data = _params.get("data", null) as GameData
	CombatStyle.data = _data
	_ending = false
	_threat = threat_unlocked()
	sent.clear()
	_flee_left = -1
	for c: Control in [frames, plates]:
		c.set("sim", sim)
	plates.set("director", director)
	frames.set("threat_revealed", _threat)
	plates.set("threat_revealed", _threat)
	input.sim = sim
	input.active = true
	if bool(_params.get("modes", true)):
		_apply_modes()
	_apply_scheme()
	hints.call("begin", sim, director, _hint_ctx())
	_start_banners()
	_root.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_SEC)
	_refresh()


## Bound and running.
func is_bound() -> bool:
	return sim != null and not _ending


## The shown touch layout (thumb group, touch frames) instead of the action bar.
func is_touch() -> bool:
	return _touch


## The first own taunt revealed the threat display (07 §8.1): StatId taunts_total > 0, or an own taunt in this combat.
static func threat_unlocked() -> bool:
	if Game.state == null or Game.state.show == null:
		return false
	return int(Game.state.show.stats.get("taunts_total", 0)) > 0


func _apply_modes() -> void:
	if _modes_applied:
		return
	_modes_applied = true
	CombatInput.apply_input_mode(true)
	Events.overlay_mode_requested.emit(&"combat")
	Events.dialog_layout_requested.emit(&"combat", SUBTITLE_TOUCH if _touch_layout() else SUBTITLE_PC)


func _restore_modes() -> void:
	if not _modes_applied:
		return
	_modes_applied = false
	CombatInput.apply_for_game()
	Events.dialog_layout_requested.emit(&"combat", {})
	if TouchScript.active != null and is_instance_valid(TouchScript.active) and \
			TouchScript.active.has_method("set_combat_mode"):
		TouchScript.active.call("set_combat_mode", false, Callable(), Callable())
	if is_inside_tree():
		Events.overlay_mode_requested.emit(&"explore")


static func _touch_layout() -> bool:
	return TouchScript.should_show()


## Input scheme / touch setting changed: touch layout (thumb group + touch frames) or the bar with key caps.
func _apply_scheme() -> void:
	_touch = _touch_layout() or bool(_params.get("force_touch", false))
	bar.visible = not _touch
	_touch_layer.visible = _touch
	frames.set("touch", _touch)
	var pad: bool = Game.input_scheme == Game.InputScheme.GAMEPAD
	var keys: Dictionary = {}
	if not _touch:
		for slot in range(1, 7):
			keys[slot] = _key_text(StringName("bar_%d" % slot), pad)
	bar.set("key_texts", keys)
	frames.set("special_key", "" if _touch else _key_text(&"partner_special", pad))
	frames.set("chip_key", "" if _touch else _key_text(&"partner_preset", pad))
	if _autopilot != null:                       # R5b: the key of the scheme, none on touch (was a fixed "T")
		_autopilot.text = "AUTOPILOT" if _touch else "AUTOPILOT · " + _key_text(&"toggle_auto", pad)
	if hints != null:
		hints.set("ctx", _hint_ctx())
	if sim != null and _modes_applied:
		Events.dialog_layout_requested.emit(&"combat", SUBTITLE_TOUCH if _touch else SUBTITLE_PC)
		var tc: Node = TouchScript.active
		if _touch and tc != null and is_instance_valid(tc) and tc.has_method("set_combat_mode"):
			tc.call("set_combat_mode", true, Callable(self, "_on_touch_tap"), Callable(self, "blocks_touch"))


## Key cap text of an action in the current scheme ("1", "Tab", "A", "RB", "Links" …).
static func _key_text(action: StringName, pad: bool) -> String:
	return InputGlyph.binding_text(action, Game.InputScheme.GAMEPAD if pad else Game.InputScheme.KEYBOARD_MOUSE)


func _hint_ctx() -> Dictionary:
	var keys: Dictionary = bar.get("key_texts") if bar != null else {}
	return {"touch": _touch, "pad": Game.input_scheme == Game.InputScheme.GAMEPAD, "keys": keys,
		"special_key": frames.get("special_key") if frames != null else "R"}


# --- per frame -------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.3, 0.0, 1.0)
		_toast.visible = _toast_t > 0.0
	_fail_t = maxf(0.0, _fail_t - delta)
	if sim != null:
		_refresh()


func _refresh() -> void:
	var states: Array[Dictionary] = CombatView.slots(sim, {"assist": assist_on()})
	var hype: float = Show.hype() if Show != null else 0.0
	var focus: int = int(hints.call("focus_slot")) if hints != null else 0
	if focus > 0:
		for s: Dictionary in states:
			if int(s["slot"]) == focus:
				s["assist"] = true
	bar.set("hype", hype)
	bar.call("set_states", states)
	_place_bar()
	if _touch:
		touch_ui.set("hype", hype)
		touch_ui.set("focus_slot", focus)
		touch_ui.call("set_states", states)
	frames.set("reserve_right", _hype_left())
	frames.call("refresh")
	var block_bottom: float = float(frames.call("top_block_bottom"))
	banner.set("top", maxf(CombatBanner.TOP, block_bottom + 10.0))
	var fr: Rect2 = frames.get_global_rect()
	var br: Rect2 = frames.call("boss_rect") as Rect2 if CombatView.boss(sim) != null else Rect2(Vector2(
		(fr.size.x - UnitFrames.TARGET_W) * 0.5, 0.0), Vector2(UnitFrames.TARGET_W, 0.0))
	plates.set("blocked", Rect2(fr.position.x + br.position.x, fr.position.y, br.size.x, block_bottom)
		if block_bottom > 0.0 else Rect2())
	plates.set("camera", get_viewport().get_camera_3d() if is_inside_tree() else null)
	plates.call("refresh")
	hints.call("on_frame")
	hints.call("place", _overlay_frame.size, _touch)
	_update_cast_bar()
	_update_flee()
	_update_autopilot()


## R5b: the touch layout's hype meter (ShowOverlay, top right next to the pause button) as a local x of the unit
## frames — the boss frame keeps clear of it (the meter's "HYPE" ran over the boss's percentage). −1 without touch.
func _hype_left() -> float:
	if not _touch or not is_inside_tree():
		return -1.0
	if _show_overlay == null or not is_instance_valid(_show_overlay):
		_show_overlay = get_tree().root.find_child("ShowOverlay", true, false)
	if _show_overlay == null or not _show_overlay.has_method("hype_rect"):
		return -1.0
	var hr: Rect2 = _show_overlay.call("hype_rect") as Rect2
	if hr.size.x <= 0.0:
		return -1.0
	return hr.position.x - frames.get_global_rect().position.x


func _place_bar() -> void:
	var w: float = bar.size.x
	bar.position = Vector2((_frame.size.x - w) * 0.5, _frame.size.y - BAR_BOTTOM - ActionBar.SLOT)


## Assist ring (07 §5.6): GameSettings.combat_assist (−1 = on with touch) and the run rule rules.combat.assist.
func assist_on() -> bool:
	if sim != null and sim.setup != null:
		var c: Variant = sim.setup.rules.get("combat", {})
		if (c is Dictionary and (c as Dictionary).has("assist") and not bool((c as Dictionary)["assist"])) or \
				(sim.setup.rules.has("assist") and not bool(sim.setup.rules["assist"])):
			return false
	var v: int = Game.settings.combat_assist if Game.settings != null else -1
	return _touch if v < 0 else v == 1


## Soft target framing (07 §7.5): GameSettings.combat_camera_assist (−1 = on with touch).
func camera_assist_on() -> bool:
	var v: int = Game.settings.combat_camera_assist if Game.settings != null else -1
	return _touch if v < 0 else v == 1


func camera_rig() -> Node3D:
	return _params.get("camera_rig", null) as Node3D


func _update_cast_bar() -> void:
	var u: RtUnit = CombatView.controlled(sim)
	var c: Dictionary = CombatView.cast(sim, u)
	_cast_bar.visible = not c.is_empty() or _fail_t > 0.0
	_cast_bar.set_meta("cast", c)
	_cast_bar.set_meta("fail", _fail_t)
	if c.is_empty() and _fail_t <= 0.0:
		_cast_label.visible = false
		_cast_time.visible = false
		return
	var w: float = 240.0
	var x: float = (_frame.size.x - w) * 0.5
	var bottom: float = CAST_BOTTOM
	if _touch:
		x += TOUCH_SHIFT
		bottom = 100.0
	_cast_bar.position = Vector2(x, _frame.size.y - bottom - 14.0)
	_cast_bar.size = Vector2(w, 14.0)
	_cast_label.visible = true
	_cast_label.position = _cast_bar.position + Vector2(5.0, -2.0)
	_cast_label.size = Vector2(w - 60.0, 16.0)
	_cast_time.visible = not c.is_empty()
	_cast_time.position = _cast_bar.position + Vector2(w - 60.0, -2.0)
	_cast_time.size = Vector2(55.0, 16.0)
	if c.is_empty():
		_cast_label.text = _cast_fail_text
	else:
		_cast_label.text = UiUtil.glyph_safe(str(c["name"]))
		_cast_time.text = "%s s" % CombatStyle.secs(int(c["left"]))
	_cast_bar.queue_redraw()


func _update_flee() -> void:
	var u: RtUnit = CombatView.controlled(sim)
	if _flee_at < 0 or u == null or u.outside_since < 0:
		if u != null and u.outside_since < 0:
			_flee_at = -1
		_flee.visible = false
		return
	var left: int = _flee_left - (sim.tick() - _flee_at)
	if left <= 0:
		_flee.visible = false
		return
	_flee.visible = true
	var secs: int = ceili(float(left) / 30.0)
	_flee.text = "Zurück ans Set! %s" % ("… ".join(_countdown(secs)) + "…")


static func _countdown(secs: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for i in range(secs, 0, -1):
		out.append(str(i))
	return out


func _update_autopilot() -> void:
	var u: RtUnit = CombatView.controlled(sim)
	_autopilot.visible = u != null and u.driver == RtUnit.Driver.AUTOPILOT
	if _autopilot.visible:
		_autopilot.position = Vector2((_frame.size.x - 220.0) * 0.5, _frame.size.y - BAR_BOTTOM - ActionBar.SLOT - 52.0)


# --- events ----------------------------------------------------------------------------------------------------------

## One sim event (Events.combat_event; tests call it directly).
func on_event(e: ActionEvent) -> void:
	if e == null or sim == null:
		return
	events_seen += 1
	hints.call("on_event", e)
	_combat_text(e)
	match e.type:
		ActionEvent.Type.ACTION_REFUSED:
			_on_refused(e)
		ActionEvent.Type.ACTION_START:
			if not e.by_ai and _is_taunt(e.skill_id) and not _threat:
				_threat = true
				frames.set("threat_revealed", true)
				plates.set("threat_revealed", true)
		ActionEvent.Type.CAST_START:
			if e.actor_id.begins_with("e") and int(e.rt.get("worthy", 0)) == 1:
				_play(SFX_DING)
		ActionEvent.Type.CAST_INTERRUPTED:
			_play(SFX_SCRATCH)
		ActionEvent.Type.CAST_FAILED:
			if e.actor_id == sim.controlled_id() and e.text == "moved":
				_fail_t = 0.6
				_cast_fail_text = "Abgebrochen"
		ActionEvent.Type.FLEE_WARNING:
			if e.actor_id == sim.controlled_id():
				_flee_left = int(e.value)
				_flee_at = sim.tick()
		ActionEvent.Type.PHASE_CHANGE:
			if int(e.value) > 1:
				var b: RtUnit = sim.unit(e.actor_id)
				banner.call("show_banner", "PHASE %d" % int(e.value), CombatStyle.unit_name(b) if b != null else "",
					CombatStyle.C_GOLD)
		ActionEvent.Type.CONTROL_CHANGED:
			var before: RtUnit = sim.unit(e.actor_id)
			var now: RtUnit = sim.unit(e.target_id)
			if before != null and now != null:
				banner.call("show_banner", "STEUERUNGSWECHSEL", "%s ist K.O. — du spielst jetzt %s!" % [
					CombatStyle.unit_name(before), CombatStyle.unit_name(now)], CombatStyle.C_CYAN, 2.0)
		ActionEvent.Type.ENRAGE:
			if int(e.value) <= 1:
				banner.call("show_banner", "ÜBERSTUNDEN!", "Ab jetzt tut jeder Treffer mehr weh.", CombatStyle.C_DANGER)
		ActionEvent.Type.BATTLE_END:
			input.active = false
			wheel.call("close")
			tactic.call("close")


func _on_refused(e: ActionEvent) -> void:
	Sfx.play_ui(&"ui_error")
	var p: RtUnit = CombatView.partner(sim)
	if p != null and e.actor_id == p.id and e.skill_id == sim.partner_special_skill(p.id):
		frames.call("refuse_special")
		bar.call("refuse", -1, e.text)
		return
	if e.actor_id != sim.controlled_id():
		return
	var slot: int = -1
	var entries: Dictionary = CombatView.bar_entries(sim, e.actor_id)
	for k: Variant in entries.keys():
		var id: String = str(entries[k])
		if id == e.skill_id or (e.item_id != "" and id == e.item_id):
			slot = int(k)
	bar.call("refuse", slot, e.text)
	if _touch and slot > 0:
		touch_ui.call("refuse", slot)


static func _is_taunt(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var def: SkillDef = CombatView.skill_of(skill_id)
	if def == null:
		return skill_id.ends_with("_taunt")
	for st: Variant in (def.rt.get("statuses", []) as Array):
		if st is Dictionary and str((st as Dictionary).get("id", "")) in ["sts_taunted", "sts_taunt"]:
			return true
	for st2: Dictionary in def.statuses:
		if str(st2.get("id", "")) in ["sts_taunted", "sts_taunt"]:
			return true
	return skill_id.ends_with("_taunt")


func _play(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if SfxSynth.SFX_IDS.has(String(id)):
			Sfx.play(id)
			return


## Combat text of 07 §8.6 (Vfx.combat_text over the 3D world).
func _combat_text(e: ActionEvent) -> void:
	if not is_inside_tree() or get_viewport().get_camera_3d() == null:
		return
	var scale: int = Game.settings.floating_text_scale if Game.settings != null else 100
	match e.type:
		ActionEvent.Type.DAMAGE:
			if e.target_id == "" or e.amount < 0:
				return
			var at: Vector3 = _text_pos(e.target_id)
			if e.immune or (e.amount == 0 and e.resist):
				Vfx.combat_text(_text_anchor, at, "IMMUN", &"rt_word", scale, false, CombatStyle.C_GREY)
				return
			if e.target_id.begins_with("p"):
				Vfx.combat_text(_text_anchor, at, str(e.amount), &"rt_taken", scale)
				var pct: int = _percent_hit(e)
				if pct > 0:
					frames.call("pop_percent", e.target_id, pct)
			else:
				var style: StringName = &"rt_dealt"
				var p: RtUnit = CombatView.partner(sim)
				if p != null and e.actor_id == p.id and e.command == BattleCommand.Kind.ATTACK:
					style = &"rt_partner"
				Vfx.combat_text(_text_anchor, at, str(e.amount), style, scale, e.crit)
				if e.weak:
					Vfx.combat_text(_text_anchor, at + Vector3(0, 0.3, 0), "SCHWACH!", &"rt_word", scale, false,
						CombatStyle.C_GOLD)
		ActionEvent.Type.HEAL:
			if e.amount > 0 and e.target_id != "":
				Vfx.combat_text(_text_anchor, _text_pos(e.target_id), "+%d" % e.amount, &"rt_heal", scale)
		ActionEvent.Type.CAST_INTERRUPTED:
			Vfx.combat_text(_text_anchor, _text_pos(e.target_id), "UNTERBROCHEN!", &"rt_word", scale, false,
				CombatStyle.C_GOLD, 26)
		ActionEvent.Type.TELEGRAPH_DODGED:
			if e.target_id == sim.controlled_id():
				Vfx.combat_text(_text_anchor, _text_pos(e.target_id), "KNAPP!" if e.success else "AUSGEWICHEN",
					&"rt_word", scale, false, CombatStyle.C_GOLD if e.success else CombatStyle.C_CYAN)
		ActionEvent.Type.STATUS_BLOCKED:
			if e.target_id != "":
				var t: RtUnit = sim.unit(e.target_id)
				var immune: bool = t != null and t.status_immune.has(e.status_id)
				Vfx.combat_text(_text_anchor, _text_pos(e.target_id), "IMMUN" if immune else "WIDERSTAND", &"rt_word",
					scale, false, CombatStyle.C_GREY)


## Percent hit (07 §8.6 "−25 % am Party-Rahmen"): a skill with rt.pct_maxhp; the share of the max HP.
func _percent_hit(e: ActionEvent) -> int:
	var def: SkillDef = CombatView.skill_of(e.skill_id) if e.skill_id != "" else null
	if def == null or def.rt.is_empty() or int(def.rt.get("pct_maxhp", 0)) <= 0:
		return 0
	var mx: int = e.max_hp if e.max_hp > 0 else 0
	if mx <= 0:
		var u: RtUnit = sim.unit(e.target_id)
		mx = u.max_hp() if u != null else 0
	return clampi(roundi(100.0 * float(e.amount) / float(maxi(1, mx))), 1, 100)


## Combat text anchor: enemies above their name plate (head + 0.4 m) so numbers never sit on the plate or its name;
## party members (no plates) just over the head.
func _text_pos(id: String) -> Vector3:
	var u: RtUnit = sim.unit(id)
	var h: float = plates.call("head_height", u) if u != null else 1.4
	var lift: float = Nameplates.HEAD_LIFT + 0.6 if u != null and u.side == Combatant.Side.ENEMY else 0.3
	return unit_world_position(id) + Vector3(0.0, h + lift, 0.0)


func _start_banners() -> void:
	var st: RtSetup = sim.setup
	if st == null:
		return
	var title: String = "KAMPF!"
	var sub: String = ""
	var col: Color = CombatStyle.C_MAGENTA
	match int(st.advantage):
		int(BattleSetup.Advantage.PREEMPTIVE):
			title = "ERSTSCHLAG!"
			# 07 E35: Graf Mopsula's bark → pull says where the first strike came from
			sub = "Angebellt und noch ganz verdattert." if st.opener == "bark" else "Die Gegner sind noch ganz verdattert."
			col = CombatStyle.C_GOLD
		int(BattleSetup.Advantage.AMBUSH):
			title = "HINTERHALT!"
			sub = "Von hinten erwischt. Kopf hoch, Kamera läuft!"
			col = CombatStyle.C_DANGER
	if st.tutorial:
		sub = "Dein erster Auftritt. Keine Panik — wir schneiden das später."
	banner.call("show_banner", title, sub, col)
	var story: String = UiUtil.mod_line("story_battle:" + st.encounter_id) if _has_line("story_battle:" +
		st.encounter_id) else ""
	if story != "":
		banner.call("show_banner", "EILMELDUNG", story, CombatStyle.C_CYAN, 2.4)
	var enc: EncounterDef = _encounter(st.encounter_id)
	if enc != null and not enc.show_boss.is_empty():
		var rule: String = UiUtil.mod_line(str(enc.show_boss.get("banner_tag", "showboss_rule"))) if _has_line(
			str(enc.show_boss.get("banner_tag", "showboss_rule"))) else ""
		banner.call("show_banner", "SHOW-BOSS", rule if rule != "" else
			"Hausordnung verschärft: alle 8 Sekunden ein Strafzettel.", CombatStyle.C_GOLD, 2.4)


static func _has_line(tag: String) -> bool:
	return DB.data != null and not DB.mod_lines(tag).is_empty()


func _encounter(id: String) -> EncounterDef:
	var d: GameData = _data if _data != null else DB.data
	return d.encounter(id) if d != null and d.has_id("encounters", id) else null


## Combat over (Events.combat_finished): input off, screen given back, fade out and free.
func finish(_result: BattleResult = null) -> void:
	if _ending:
		return
	_ending = true
	input.active = false
	wheel.call("close")
	tactic.call("close")
	if hints.call("is_showing"):
		hints.call("dismiss")
	_restore_modes()
	if not is_inside_tree():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS          # a boss credits panel pauses the tree: fade out anyway
	var tw: Tween = create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_SEC)
	tw.parallel().tween_property(_overlay_frame, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(queue_free)


# --- API for CombatInput / touch -------------------------------------------------------------------------------------

## Every player command: CombatDirector.submit (ct = this tick) + the hint cards.
func send(cmd: Dictionary) -> void:
	if sim == null or _ending:
		return
	sent.append(cmd.duplicate(true))
	if director != null and director.has_method("submit"):
		director.call("submit", cmd)
	hints.call("on_command", cmd)


func any_input(_event: InputEvent) -> void:
	hints.call("on_any_input")


func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_t = TOAST_SEC
	_toast.size = Vector2(_frame.size.x, 24.0)
	_toast.position = Vector2(0.0, _frame.size.y * 0.5 - 60.0)


func toast_text() -> String:
	return _toast.text if _toast.visible else ""


## World position of a unit (director, interpolated); the room-local sim position as a fallback.
func unit_world_position(id: String) -> Vector3:
	if director != null and director.has_method("unit_position"):
		return director.call("unit_position", id) as Vector3
	var u: RtUnit = sim.unit(id) if sim != null else null
	return Vector3(float(u.x) / 100.0, 0.0, float(u.z) / 100.0) if u != null else Vector3.ZERO


func pick_unit(screen_pos: Vector2) -> String:
	return str(plates.call("pick", screen_pos))


func overlay_open() -> bool:
	return bool(wheel.call("is_open")) or bool(tactic.call("is_open"))


func close_overlays() -> void:
	wheel.call("close")
	tactic.call("close")


func open_wheel(_from_pad: bool = false) -> void:
	if sim == null or sim.setup == null:
		return
	var at: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if _touch:
		at = touch_ui.call("center_of", "slot6") as Vector2
	elif bar.call("slot_rect", CombatView.SLOT_POTION) != Rect2():
		at = bar.get_global_rect().position + (bar.call("slot_rect", CombatView.SLOT_POTION) as Rect2).get_center()
	wheel.call("open", ItemWheel.entries_from(sim.items), at + Vector2(0, -150))


func wheel_stick(v: Vector2) -> void:
	wheel.call("stick", v)


func wheel_confirm() -> void:
	wheel.call("confirm")


func open_tactic() -> void:
	if not CombatView.tactic_visible(sim):
		return
	var cur: Dictionary = CombatView.partner_preset(sim)
	var p: RtUnit = CombatView.partner(sim)
	var chip: Rect2 = frames.call("hit_rect", "chip") as Rect2
	var at: Vector2 = Vector2(chip.end.x + 12.0, chip.position.y - 40.0) if chip.size.x > 0.0 else Vector2(220, 220)
	tactic.call("open", str(cur["preset"]), cur["tog"] as Dictionary, CombatStyle.unit_name(p) if p != null else "", at)


## TouchControls combat tap (07 §7.3: a tap is target selection).
func _on_touch_tap(pos: Vector2) -> void:
	if input != null:
		input.pick(pos, false)


## TouchControls asks whether a touch belongs to the combat UI (buttons, frames, chip, wheel, card).
func blocks_touch(pos: Vector2) -> bool:
	if touch_ui != null and touch_ui.is_visible_in_tree() and bool(touch_ui.call("blocks", pos)):
		return true
	for n: String in ["ctl_frame", "partner_frame", "special", "chip", "sword", "target_frame"]:
		if bool(frames.call("hit_contains", n, pos)):
			return true
	if overlay_open() or (hints.call("is_showing") and (hints.call("card_rect") as Rect2).has_point(pos)):
		return true
	return false


# --- build -----------------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	UiUtil.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(_root)
	add_child(_root)
	plates = Nameplates.new()
	plates.name = "Nameplates"
	UiUtil.full_rect(plates)
	_root.add_child(plates)
	var safe: SafeAreaContainer = SafeAreaContainer.new()
	safe.name = "Safe"
	_root.add_child(safe)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(_frame)
	frames = UnitFrames.new()
	frames.name = "UnitFrames"
	UiUtil.full_rect(frames)
	_frame.add_child(frames)
	banner = CombatBanner.new()
	banner.name = "Banner"
	UiUtil.full_rect(banner)
	_frame.add_child(banner)
	bar = ActionBar.new()
	bar.name = "ActionBar"
	_frame.add_child(bar)
	_cast_bar = Control.new()
	_cast_bar.name = "PlayerCast"
	_cast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_bar.visible = false
	_cast_bar.draw.connect(_draw_player_cast)
	_frame.add_child(_cast_bar)
	_cast_label = CombatStyle.label("", 13, CombatStyle.C_PAPER, true)
	_cast_label.name = "PlayerCastLabel"
	_cast_label.visible = false
	_frame.add_child(_cast_label)
	_cast_time = CombatStyle.label("", 13, CombatStyle.C_PAPER, true)
	_cast_time.name = "PlayerCastTime"
	_cast_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cast_time.visible = false
	_frame.add_child(_cast_time)
	_autopilot = CombatStyle.label("AUTOPILOT · T", 16, CombatStyle.C_CYAN, true)
	_autopilot.name = "Autopilot"
	_autopilot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_autopilot.size = Vector2(220, 20)
	_autopilot.visible = false
	_frame.add_child(_autopilot)
	_flee = CombatStyle.label("", 36, CombatStyle.C_GOLD, true)
	_flee.name = "FleeCountdown"
	_flee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flee.add_theme_constant_override("outline_size", 6)
	_flee.add_theme_color_override("font_outline_color", CombatStyle.C_INK)
	_flee.visible = false
	_frame.add_child(_flee)
	_frame.resized.connect(func() -> void:
		_flee.size = Vector2(_frame.size.x, 44.0)
		_flee.position = Vector2(0.0, FLEE_Y))
	_toast = CombatStyle.label("", 20, CombatStyle.C_PAPER, true)
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.add_theme_color_override("font_outline_color", CombatStyle.C_INK)
	_toast.visible = false
	_frame.add_child(_toast)
	# touch thumb group (layer 21)
	_touch_layer = CanvasLayer.new()
	_touch_layer.name = "TouchLayer"
	_touch_layer.layer = LAYER_TOUCH
	_touch_layer.visible = false
	add_child(_touch_layer)
	var troot: Control = Control.new()
	UiUtil.full_rect(troot)
	troot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(troot)
	_touch_layer.add_child(troot)
	touch_ui = CombatTouch.new()
	touch_ui.name = "CombatTouch"
	UiUtil.full_rect(touch_ui)
	troot.add_child(touch_ui)
	# overlay (layer 46): hint card, item wheel, tactic panel
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.layer = LAYER_OVERLAY
	add_child(_overlay_layer)
	var oroot: Control = Control.new()
	UiUtil.full_rect(oroot)
	oroot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiUtil.apply_theme(oroot)
	_overlay_layer.add_child(oroot)
	var osafe: SafeAreaContainer = SafeAreaContainer.new()
	oroot.add_child(osafe)
	_overlay_frame = Control.new()
	_overlay_frame.name = "OverlayFrame"
	_overlay_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osafe.add_child(_overlay_frame)
	hints = HintCards.new()
	hints.name = "HintCards"
	UiUtil.full_rect(hints)
	_overlay_frame.add_child(hints)
	wheel = ItemWheel.new()
	wheel.name = "ItemWheel"
	UiUtil.full_rect(wheel)
	oroot.add_child(wheel)
	tactic = TacticPanel.new()
	tactic.name = "TacticPanel"
	UiUtil.full_rect(tactic)
	oroot.add_child(tactic)
	_text_anchor = Node3D.new()
	_text_anchor.name = "CombatText"
	add_child(_text_anchor)
	input = CombatInput.new()
	input.name = "CombatInput"
	input.hud = self
	add_child(input)
	# wiring
	bar.connect("slot_pressed", func(slot: int) -> void: input.press_slot(slot))
	bar.connect("slot_alt_pressed", func(slot: int) -> void:
		if slot == CombatView.SLOT_POTION:
			open_wheel())
	touch_ui.connect("slot_pressed", func(slot: int) -> void: input.press_slot(slot))
	touch_ui.connect("wheel_requested", func() -> void: open_wheel())
	touch_ui.connect("target_cycle", func(fwd: bool) -> void: input.cycle_target(fwd))
	frames.connect("friendly_target_requested", func(id: String) -> void: input.set_target(id))
	frames.connect("partner_special_pressed", func() -> void: input.partner_special())
	frames.connect("tactic_pressed", open_tactic)
	frames.connect("auto_attack_pressed", func() -> void: input.toggle_auto_attack())
	wheel.connect("item_chosen", func(id: String) -> void: input.use_item(id))
	tactic.connect("preset_changed", func(p: String, t: Dictionary) -> void: input.set_preset(p, t))
	hints.connect("tactic_requested", open_tactic)


func _draw_player_cast() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _cast_bar.size)
	var c: Dictionary = _cast_bar.get_meta("cast", {}) as Dictionary
	var m: IconMesh = IconMesh.new()
	m.rect(r.grow(2.0), Color(CombatStyle.C_INK, 0.9))
	if c.is_empty():
		m.rect(r, Color(CombatStyle.C_DANGER, 0.85))         # "Abgebrochen": a short red flash (07 §8.3)
	else:
		var ratio: float = float(c["ratio"])
		if bool(c["channel"]):
			ratio = 1.0 - ratio
		m.rect(Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)), CombatStyle.C_MANA)
		m.rect_outline(r.grow(1.0), Color(CombatStyle.C_PAPER, 0.6), 1.0)
	m.commit(_cast_bar)
