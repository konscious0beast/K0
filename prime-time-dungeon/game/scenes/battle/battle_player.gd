extends Node
## BattlePlayer (02_TECH §5.7): plays ActionEvent lists back on the stage — camera shots, rig dashes and animations,
## Vfx, damage numbers, banners — and emits event_played(e) once per event, in list order, at the moment it is
## presented (the controller forwards it to Show.on_battle_event; the HUD gets on_event right before; a SUMMON is
## staged first so the HUD finds the new unit). Events of one action with the same beat start together; durations
## follow the §5.7 table divided by `speed` (Settings battle_speed ∈ {1, 2}, autoplay 4); a victory waits for the
## camera's 3 s victory orbit. Reads only event data during playback, never the BattleState.
## Private M5 helper (no class_name).

signal event_played(e: ActionEvent)
## Emitted every frame; all waits await this node-local signal (never SceneTree timers or process_frame), so a
## battle that is freed mid-playback never resumes a coroutine of a freed instance.
signal frame_ticked

const BEAT_SEC: float = 0.35
## Length of the camera's victory orbit at speed 1 (03_ART §8.3); BATTLE_END (victory) waits for the whole orbit —
## like every beat the wait is divided by the playback speed (×2: 1.5 s, autoplay ×4: 0.75 s), the orbit is too.
const VICTORY_ORBIT_SEC: float = 3.0
const DUR: Dictionary = {
	"battle_start": 1.2, "battle_start_boss": 2.5, "turn_start": 0.15, "combo": 0.4, "damage": 0.35,
	"status": 0.25, "ko": 0.6, "summon": 0.6, "credits": 0.6, "stunt_result": 0.6, "banner": 1.0, "sponsor": 1.5,
	"turn_end": 0.15, "battle_end": 1.5, "dash": 0.24, "dash_back": 0.2,
}
const EFFECT_TYPES: Array[ActionEvent.Type] = [ActionEvent.Type.DAMAGE, ActionEvent.Type.HEAL,
	ActionEvent.Type.MP_CHANGE, ActionEvent.Type.STATUS_ADDED, ActionEvent.Type.STATUS_REMOVED,
	ActionEvent.Type.STATUS_BLOCKED, ActionEvent.Type.KO, ActionEvent.Type.REVIVE, ActionEvent.Type.SUMMON,
	ActionEvent.Type.PSEUDO_REMOVED, ActionEvent.Type.ESCAPED, ActionEvent.Type.CREDITS_STOLEN,
	ActionEvent.Type.CREDITS_GAINED, ActionEvent.Type.ITEM_GAINED, ActionEvent.Type.PHASE_CHANGE,
	ActionEvent.Type.MOD_LINE, ActionEvent.Type.DEFEND, ActionEvent.Type.STUNT_RESULT, ActionEvent.Type.FLEE_RESULT,
	ActionEvent.Type.COMBO]
const ELEMENT_SFX: Dictionary = {"fire": &"fire", "ice": &"ice", "shock": &"shock", "poison": &"toxic"}
const C_PARTY: Color = Color("#22d3ee")
const C_DANGER: Color = Color("#ff4d4d")
const C_GOLD: Color = Color("#ffc93c")
const C_MAGENTA: Color = Color("#ff2e88")

var speed: float = 1.0
var stage: Node3D = null              # battle_stage.gd
var camera: Camera3D = null           # battle_camera.gd
var hud: CanvasLayer = null           # ui/battle_hud.gd
var setup: BattleSetup = null
var playing: bool = false
var emitted: int = 0                  # events emitted so far (tests)

var _defending: Dictionary = {}       # combatant id → true until its next TURN_START
var _ko: Dictionary = {}              # combatant id → true (party + enemies)


func _process(_delta: float) -> void:
	frame_ticked.emit()


## Coroutine: presents `events` in order.
func play(events: Array[ActionEvent]) -> void:
	playing = true
	var i: int = 0
	var n: int = events.size()
	while i < n:
		var e: ActionEvent = events[i]
		if e.type == ActionEvent.Type.ACTION_START:
			var j: int = i + 1
			while j < n and not [ActionEvent.Type.TURN_END, ActionEvent.Type.BATTLE_END, ActionEvent.Type.TURN_START,
					ActionEvent.Type.CTB_ORDER].has(events[j].type):
				j += 1
			await _play_action(_sub(events, i, j))
			i = j
			continue
		if e.type == ActionEvent.Type.SPONSOR_GIFT:
			await _play_sponsor(e)
			i += 1
			continue
		if EFFECT_TYPES.has(e.type):
			var k: int = i
			while k < n and EFFECT_TYPES.has(events[k].type):
				k += 1
			await _play_effects(_sub(events, i, k), "", null)
			i = k
			continue
		await _play_single(e)
		i += 1
	playing = false


static func _sub(events: Array[ActionEvent], from: int, to: int) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for k in range(from, mini(to, events.size())):
		out.append(events[k])
	return out


func _emit(e: ActionEvent) -> void:
	if hud != null and is_instance_valid(hud):
		hud.call("on_event", e)
	emitted += 1
	event_played.emit(e)


# --- single events ----------------------------------------------------------------------------------------------------

func _play_single(e: ActionEvent) -> void:
	match e.type:
		ActionEvent.Type.BATTLE_START:
			await _battle_start(e)
		ActionEvent.Type.TURN_START:
			_emit(e)
			_on_turn_start(e.actor_id)
			await _wait(DUR["turn_start"])
		ActionEvent.Type.TURN_END:
			_emit(e)
			var r: CharacterRig = _rig(e.actor_id)
			if r != null and not _ko.has(e.actor_id):
				_face_home(e.actor_id)
			await _wait(DUR["turn_end"])
		ActionEvent.Type.CTB_ORDER:
			_emit(e)
		ActionEvent.Type.ANNOUNCE:
			_emit(e)
			_banner_big(e.text, C_GOLD, DUR["banner"])
			await _wait(DUR["banner"])
		ActionEvent.Type.BATTLE_END:
			await _battle_end(e)
		_:
			_emit(e)


func _battle_start(e: ActionEvent) -> void:
	_emit(e)
	if hud != null:
		hud.call("set_intro", true)
	var boss_id: String = ""
	for id: String in e.target_ids:
		if id.begins_with("e") and stage != null and bool((stage.call("info", id) as Dictionary).get("boss", false)):
			boss_id = id
			break
	var dur: float = DUR["battle_start"]
	if boss_id != "":
		dur = DUR["battle_start_boss"]
		_shot(&"boss_intro", {"actor": boss_id})
		# subject-bound: TV lower third, never over the boss's head during the crane
		_lower_third(tr("BOSSKAMPF"), str(stage.call("display_name", boss_id)), C_DANGER,
			dur / maxf(speed, 0.01) * 0.85)
	else:
		_shot(&"establishing")
		_banner_big(tr("KAMPF!"), C_GOLD, 1.0 / maxf(speed, 0.01))
	await _wait(dur)
	if hud != null:
		hud.call("set_intro", false)


func _battle_end(e: ActionEvent) -> void:
	_emit(e)
	if stage != null:
		stage.call("set_active", "")
	match e.value:
		BattleResult.Outcome.VICTORY:
			for id: String in _ids(true):
				var r: CharacterRig = _rig(id)
				if r != null and not _ko.has(id):
					r.rotation = Vector3.ZERO
					r.play(&"victory")
			_shot(&"victory")
			_banner_big(tr("SIEG!"), C_GOLD, DUR["battle_end"] / maxf(speed, 0.01), "", 76)
			Sfx.music(&"victory", 0.4)
			# the cheering party gets the whole victory orbit (3.0 s at speed 1) before the results panel opens
			await _wait(maxf(DUR["battle_end"], VICTORY_ORBIT_SEC))
			return
		BattleResult.Outcome.DEFEAT:
			var ko_id: String = ""
			for id2: String in _ids(true):
				ko_id = id2
				break
			_shot(&"defeat", {"actor": ko_id})
			_banner_big(tr("K.O."), C_DANGER, DUR["battle_end"] / maxf(speed, 0.01), tr("Sendeschluss"), 76)
			Sfx.music(&"", 0.6)
		_:
			_banner_big(tr("GEFLOHEN!"), Color("#ff9a2e"), DUR["battle_end"] / maxf(speed, 0.01), "", 64)
	await _wait(DUR["battle_end"])


func _on_turn_start(id: String) -> void:
	if stage != null:
		stage.call("set_active", id)
	if _defending.has(id):
		_defending.erase(id)
		var r: CharacterRig = _rig(id)
		if r != null and not _ko.has(id):
			r.play(&"idle")
	if id.begins_with("e"):
		_shot(&"enemy_turn", {"actor": id})
	elif id.begins_with("p") and camera != null and Game.auto_battle:
		_shot(&"command", {"actor": id})


# --- actions ----------------------------------------------------------------------------------------------------------

func _play_action(block: Array[ActionEvent]) -> void:
	var start: ActionEvent = block[0]
	var actor: String = start.actor_id
	var party: bool = actor.begins_with("p")
	_emit(start)
	var k: int = 1
	var pre: Array[ActionEvent] = []
	while k < block.size() and (block[k].type == ActionEvent.Type.COMBO or (block[k].type == ActionEvent.Type.MP_CHANGE
			and block[k].target_id == actor and block[k].amount < 0)):
		pre.append(block[k])
		k += 1
	var rest: Array[ActionEvent] = _sub(block, k, block.size())
	var tail_at: int = rest.size()
	while tail_at > 0 and _is_tail(rest[tail_at - 1], actor):
		tail_at -= 1
	var effects: Array[ActionEvent] = _sub(rest, 0, tail_at)
	var tail: Array[ActionEvent] = _sub(rest, tail_at, rest.size())
	var skill: SkillDef = DB.skill(start.skill_id) if start.skill_id != "" and DB.has_id("skills", start.skill_id) \
		else null
	if hud != null and start.text != "":
		hud.get("banner").call("show_skill", tr(start.text), party, 1.0 / maxf(speed, 0.01))
	var has_combo: bool = false
	for p: ActionEvent in pre:
		_emit(p)
		if p.type == ActionEvent.Type.COMBO:
			has_combo = true
	if has_combo:
		_banner_big(tr("COMBO!"), C_MAGENTA, DUR["combo"] / maxf(speed, 0.01) + 0.3)
		Sfx.play(&"buff")
		await _wait(DUR["combo"])
	if actor.begins_with("u"):
		await _pseudo_action(start, effects)
	elif start.command == BattleCommand.Kind.DEFEND:
		await _defend_action(actor, effects)
	elif start.command == BattleCommand.Kind.FLEE or _has_type(effects, ActionEvent.Type.FLEE_RESULT):
		await _flee_action(start, effects, skill)
	else:
		await _skill_action(start, effects, skill)
	if not tail.is_empty():
		await _play_effects(tail, actor, null)


func _skill_action(start: ActionEvent, effects: Array[ActionEvent], skill: SkillDef) -> void:
	var actor: String = start.actor_id
	var party: bool = actor.begins_with("p")
	var rig: CharacterRig = _rig(actor)
	var targets: PackedStringArray = start.target_ids
	var anim: StringName = _anim_for(start, skill)
	var opposite: bool = false
	for t: String in targets:
		if t.substr(0, 1) != actor.substr(0, 1):
			opposite = true
	var area: bool = targets.size() > 1
	var melee: bool = rig != null and opposite and (anim == &"attack" or anim == &"stunt") and not area \
		and _home(targets[0]).y < 0.5 and _home(actor).y < 0.5 and targets.size() == 1
	if rig != null and not targets.is_empty():
		rig.face_towards(_target_center(targets))
	if rig != null and skill != null:
		var el: Color = Palette.element_color(skill.element) if skill.element not in ["", "none", "physical"] \
			else C_PARTY
		rig.cast_color = el
		rig.item_color = Color("#6bffb0") if skill.damage_type == "heal" else el
	# camera before the move
	var fast: bool = speed >= 2.0
	if party:
		if anim == &"stunt":
			_shot(&"stunt", {"actor": actor})
		elif melee:
			_shot(&"action_side", {"actor": actor, "target": targets[0]})
		elif anim == &"cast" and not fast:
			_shot(&"skill_closeup", {"actor": actor})
		elif anim == &"item" or anim == &"cast":
			_shot(&"skill_release", {"target": targets[0] if targets.size() == 1 else "", "area": area})
		else:
			_shot(&"skill_release", {"target": targets[0] if targets.size() == 1 else "", "area": area})
	var home: Vector3 = _home(actor)
	if melee:
		var strike: Vector3 = _strike_pos(actor, targets[0])
		rig.set_locomotion(7.0)
		Sfx.play(&"step")
		await _tween_pos(rig, strike, DUR["dash"])
		# a rig freed mid-dash only skips the animation steps: every event below is still played (and emitted)
		if is_instance_valid(rig):
			rig.set_locomotion(0.0)
			rig.face_towards(_target_center(targets))
		else:
			rig = null
	if rig != null and is_instance_valid(rig):
		rig.play(anim, speed)
		Sfx.play(&"swing" if anim == &"attack" else (&"magic" if anim == &"cast" else &"buff"), -4.0)
		var impact_at: float = float(CharacterRig.IMPACT_AT.get(anim, 0.3))
		await _wait_signal(rig.impact, impact_at / maxf(speed, 0.01) + 0.6)
	else:
		await _wait(0.25)
	if party and (anim == &"cast" or anim == &"stunt") and not effects.is_empty():
		_shot(&"skill_release", {"target": targets[0] if targets.size() == 1 else "", "area": area})
	await _play_effects(effects, actor, skill)
	if anim == &"stunt" and rig != null and is_instance_valid(rig):
		await _wait(0.25)
	if melee and is_instance_valid(rig) and not _ko.has(actor):
		rig.set_locomotion(3.0)
		await _tween_pos(rig, home, DUR["dash_back"])
		if is_instance_valid(rig):
			rig.set_locomotion(0.0)


func _defend_action(actor: String, effects: Array[ActionEvent]) -> void:
	var rig: CharacterRig = _rig(actor)
	if rig != null:
		rig.play(&"defend")
		Vfx.spawn(&"buff", stage, _anchor(actor, &"feet") + Vector3(0, 0.1, 0), Color("#9aa7b8"),
			maxf(rig.size_factor(), 0.6))
	_defending[actor] = true
	Sfx.play(&"defend")
	await _play_effects(effects, actor, null)


func _flee_action(start: ActionEvent, effects: Array[ActionEvent], skill: SkillDef) -> void:
	var actor: String = start.actor_id
	var rig: CharacterRig = _rig(actor)
	var ok: bool = false
	for e: ActionEvent in effects:
		if e.type == ActionEvent.Type.FLEE_RESULT:
			ok = e.success
	_shot(&"flee")
	if skill != null and rig != null:
		rig.play(&"item", speed)
		await _wait_signal(rig.impact, 0.35 / maxf(speed, 0.01) + 0.5)
		Vfx.spawn(&"smoke", stage, _party_center() + Vector3(0, 0.4, 0), Color(0, 0, 0, 0), 2.0)
	elif rig != null:
		rig.face_towards(rig.global_position + Vector3(0, 0, 1) if rig.is_inside_tree() else Vector3(0, 0, 10))
		rig.set_locomotion(6.0)
		await _tween_pos(rig, _home(actor) + Vector3(0, 0, 1.4), 0.35)
		if is_instance_valid(rig):
			rig.set_locomotion(0.0)
	for e2: ActionEvent in effects:
		_emit(e2)
	Sfx.play(&"flee")
	if ok:
		for id: String in _ids(true):
			var r: CharacterRig = _rig(id)
			if r == null or _ko.has(id):
				continue
			r.face_towards(r.global_position + Vector3(0, 0, 1) if r.is_inside_tree() else Vector3(0, 0, 10))
			r.set_locomotion(7.0)
			var tw: Tween = r.create_tween() if r.is_inside_tree() else null
			if tw != null:
				tw.tween_property(r, "position", r.position + Vector3(0, 0, 8.0), 0.7 / maxf(speed, 0.01))
		await _wait(0.6)
	else:
		_banner_big(tr("FLUCHT GESCHEITERT!"), C_DANGER, 0.8 / maxf(speed, 0.01))
		await _wait(0.6)
		if is_instance_valid(rig) and skill == null:
			rig.set_locomotion(3.0)
			await _tween_pos(rig, _home(actor), 0.25)
			if is_instance_valid(rig):
				rig.set_locomotion(0.0)
				_face_home(actor)


## Pseudo unit turn (train): banner, wide shot, the train rushes through the party; damage on its pass.
func _pseudo_action(start: ActionEvent, effects: Array[ActionEvent]) -> void:
	_shot(&"train")
	_banner_big(tr("ZUG FÄHRT EIN!"), C_DANGER, 0.9 / maxf(speed, 0.01), tr(start.text), 52)
	Sfx.play(&"timer_warn")
	var train: Node = stage.get("train") if stage != null else null
	if train == null or not is_instance_valid(train):
		await _wait(0.4)
		await _play_effects(effects, start.actor_id, null)
		return
	var state: Dictionary = {"hit": false}
	var cb: Callable = func() -> void: state["hit"] = true
	train.connect("hit", cb, CONNECT_ONE_SHOT)
	train.call("pass_through", 1.3 / maxf(speed, 0.01))
	var t: float = 0.0
	while not bool(state["hit"]) and t < 3.0:
		await frame_ticked
		t += get_process_delta_time()
	if is_instance_valid(train) and train.is_connected("hit", cb):
		train.disconnect("hit", cb)
	Sfx.play(&"hit_crit")
	# the payoff: cut from the wide train shot to a push-in on the party for the damage beats (readable numbers)
	_shot(&"party_hit")
	if camera != null:
		camera.call("add_trauma", 0.6)
	await _play_effects(effects, start.actor_id, null)
	await _wait(0.35)


func _play_sponsor(e: ActionEvent) -> void:
	_emit(e)
	var col: Color = C_MAGENTA
	if DB.has_id("sponsors", e.sponsor_id):
		col = Palette.hex(DB.sponsor(e.sponsor_id).color, C_MAGENTA)
	_shot(&"sponsor_drop")
	if stage != null:
		Vfx.spawn(&"sponsor", stage, Vector3(0, 0, 0.5), col, 1.0)
	_lower_third(tr("SPONSOR-GESCHENK!"), tr(e.text), col, DUR["sponsor"] / maxf(speed, 0.01))
	await _wait(DUR["sponsor"])


# --- effects ----------------------------------------------------------------------------------------------------------

## Presents effect events in order; a higher beat waits BEAT_SEC (or the longest effect of the previous beat);
## PHASE_CHANGE is a barrier (previous hits finish, banner, then the phase ops).
func _play_effects(effects: Array[ActionEvent], actor: String, skill: SkillDef) -> void:
	if effects.is_empty():
		return
	var beat: int = -1
	var group_wait: float = 0.0
	for e: ActionEvent in effects:
		if e.type == ActionEvent.Type.PHASE_CHANGE:
			if group_wait > 0.0:
				await _wait(group_wait)
				group_wait = 0.0
			_emit(e)
			_phase_change(e)
			await _wait(DUR["banner"])
			continue
		if beat >= 0 and e.beat > beat and group_wait > 0.0:
			await _wait(maxf(group_wait, BEAT_SEC))
			group_wait = 0.0
		beat = maxi(beat, e.beat)
		if e.type == ActionEvent.Type.SUMMON:
			# the stage registers the new unit first, so the HUD builds its plate / CTB entry with its real name,
			# letter and max HP (the event itself is still emitted exactly once, in list order)
			var dur: float = _present(e, actor, skill)
			_emit(e)
			group_wait = maxf(group_wait, dur)
			continue
		_emit(e)
		group_wait = maxf(group_wait, _present(e, actor, skill))
	if group_wait > 0.0:
		await _wait(group_wait)


## Non-blocking visuals of one effect event; returns its duration (speed 1).
func _present(e: ActionEvent, actor: String, skill: SkillDef) -> float:
	match e.type:
		ActionEvent.Type.DAMAGE:
			return _present_damage(e, skill)
		ActionEvent.Type.HEAL:
			_number(e.target_id, str(e.amount), &"heal")
			_vfx(&"heal", e.target_id, &"center", Color(0, 0, 0, 0))
			var r: CharacterRig = _rig(e.target_id)
			if r != null:
				r.flash(Color("#6bffb0"), 0.25)
			Sfx.play(&"heal", -3.0)
			return DUR["damage"]
		ActionEvent.Type.MP_CHANGE:
			if e.amount > 0:
				_number(e.target_id, str(e.amount), &"mp")
				return DUR["status"]
			return 0.0
		ActionEvent.Type.STATUS_ADDED:
			if stage != null:
				stage.call("set_status_visual", e.target_id, e.status_id, true)
			var def: StatusDef = DB.status(e.status_id) if DB.has_id("statuses", e.status_id) else null
			if def != null:
				_number(e.target_id, tr(def.name), &"status")
				_vfx(&"buff" if def.kind == "buff" else &"debuff", e.target_id, &"feet", Palette.status_color(e.status_id))
				Sfx.play(&"buff" if def.kind == "buff" else &"debuff", -4.0)
			return DUR["status"]
		ActionEvent.Type.STATUS_REMOVED:
			if stage != null:
				stage.call("set_status_visual", e.target_id, e.status_id, false)
			return 0.1
		ActionEvent.Type.STATUS_BLOCKED:
			_number(e.target_id, tr("ABGEWEHRT"), &"miss")
			return DUR["status"]
		ActionEvent.Type.KO:
			_present_ko(e)
			return DUR["ko"]
		ActionEvent.Type.REVIVE:
			_ko.erase(e.target_id)
			var rr: CharacterRig = _rig(e.target_id)
			if rr != null:
				rr.reset_pose()
				rr.flash(Color("#6bffb0"), 0.35)
			_vfx(&"heal", e.target_id, &"center", Color(0, 0, 0, 0))
			_number(e.target_id, str(e.hp_after), &"heal")
			Sfx.play(&"heal")
			return DUR["summon"]
		ActionEvent.Type.SUMMON:
			if stage != null:
				if e.target_id.begins_with("u"):
					stage.call("add_pseudo", e.target_id, e.def_id)
					_banner_big(tr("ACHTUNG: GLEIS 9!"), C_DANGER, 1.0 / maxf(speed, 0.01))
					Sfx.play(&"timer_warn")
				else:
					stage.call("add_enemy", e.target_id, e.def_id, e.value, true)
					Sfx.play(&"door", -4.0)
			return DUR["summon"]
		ActionEvent.Type.PSEUDO_REMOVED:
			if stage != null:
				stage.call("remove_pseudo", e.target_id)
			return DUR["summon"]
		ActionEvent.Type.ESCAPED:
			_present_escape(e.actor_id)
			return DUR["summon"]
		ActionEvent.Type.CREDITS_STOLEN:
			_number(e.actor_id, "-%d Cr" % e.value, &"damage")
			Sfx.play(&"coin")
			return DUR["credits"]
		ActionEvent.Type.CREDITS_GAINED:
			_number_at(_party_center() + Vector3(0, 1.6, 0), "+%d Cr" % e.value, &"heal")
			Sfx.play(&"coin")
			return DUR["credits"]
		ActionEvent.Type.ITEM_GAINED:
			var name_text: String = tr(DB.item(e.item_id).name) if DB.has_id("items", e.item_id) else e.item_id
			_number_at(_party_center() + Vector3(0, 1.9, 0), "+%d %s" % [e.value, name_text], &"status")
			Sfx.play(&"coin")
			return DUR["credits"]
		ActionEvent.Type.STUNT_RESULT:
			if e.success:
				_banner_big(tr("STUNT GEGLÜCKT!"), C_GOLD, DUR["stunt_result"] / maxf(speed, 0.01) + 0.3)
				Sfx.play(&"stunt_success")
				if camera != null:
					camera.call("add_trauma", 0.5)
			else:
				_banner_big(tr("PATZER!"), C_DANGER, DUR["stunt_result"] / maxf(speed, 0.01) + 0.3)
				Sfx.play(&"stunt_fail")
			return DUR["stunt_result"]
		ActionEvent.Type.DEFEND:
			_defending[e.actor_id] = true
			return 0.0
		ActionEvent.Type.COMBO:
			_banner_big(tr("COMBO!"), C_MAGENTA, DUR["combo"] / maxf(speed, 0.01) + 0.3)
			return DUR["combo"]
	return 0.0


func _present_damage(e: ActionEvent, skill: SkillDef) -> float:
	var id: String = e.target_id
	var r: CharacterRig = _rig(id)
	var style: StringName = &"damage"
	if e.immune:
		style = &"resist"
	elif e.crit:
		style = &"crit"
	elif e.weak:
		style = &"weak"
	elif e.resist:
		style = &"resist"
	_number(id, "IMMUN" if e.immune else str(e.amount), style)
	var kind: StringName = &"hit"
	if skill != null and e.status_id == "":
		kind = Vfx.for_skill(skill)
	elif e.status_id != "":
		kind = &"toxic" if e.element == "poison" else &"debuff"
	elif e.element in ["fire", "ice", "shock"]:
		kind = StringName(e.element)
	var col: Color = Color(0, 0, 0, 0)
	if kind == &"debuff" and e.status_id != "":
		col = Palette.status_color(e.status_id)
	_vfx(kind, id, &"center", col)
	if e.crit:
		_vfx(&"crit", id, &"center", Color(0, 0, 0, 0))
	if r != null and not e.immune:
		if _defending.has(id) or e.status_id != "":
			r.flash(Color.WHITE, 0.12)
		elif not _ko.has(id):
			r.play(&"hit", speed)
	var sfx: StringName = &"hit"
	if e.immune:
		sfx = &"miss"
	elif e.crit:
		sfx = &"hit_crit"
	elif e.weak:
		sfx = &"hit_weak"
	elif e.status_id != "":
		sfx = &"toxic"
	elif ELEMENT_SFX.has(e.element):
		sfx = ELEMENT_SFX[e.element]
	Sfx.play(sfx, -2.0)
	if camera != null and not e.immune:
		camera.call("add_trauma", 0.35 if e.crit else (0.2 if e.amount > 0 else 0.0))
	return DUR["damage"]


func _present_ko(e: ActionEvent) -> void:
	var id: String = e.target_id
	_ko[id] = true
	_defending.erase(id)
	if stage != null:
		stage.call("clear_status_visuals", id)
	var r: CharacterRig = _rig(id)
	if r != null:
		r.play(&"die", speed)
	Sfx.play(&"ko")
	if e.value == 1:
		_banner_big(tr("OVERKILL!"), C_MAGENTA, 0.9 / maxf(speed, 0.01))
		if camera != null:
			camera.call("add_trauma", 0.3)


func _present_escape(id: String) -> void:
	_ko[id] = true
	var r: CharacterRig = _rig(id)
	Vfx.spawn(&"smoke", stage, _anchor(id, &"center"), Color(0, 0, 0, 0), 1.2)
	Sfx.play(&"flee")
	if r == null or not r.is_inside_tree():
		return
	r.face_towards(r.global_position + Vector3(0, 0, -1))
	r.set_locomotion(7.0)
	var tw: Tween = r.create_tween()
	tw.tween_property(r, "position", r.position + Vector3(0, 0, -7.0), 0.5 / maxf(speed, 0.01))
	tw.tween_callback(func() -> void: r.visible = false)


func _phase_change(e: ActionEvent) -> void:
	var r: CharacterRig = _rig(e.actor_id)
	if r != null:
		r.set_boss_phase(e.value)
		r.flash(C_DANGER, 0.4)
	var who: String = str(stage.call("display_name", e.actor_id)) if stage != null else ""
	_lower_third(who, tr("PHASE %d") % e.value, C_DANGER, DUR["banner"] / maxf(speed, 0.01))
	Sfx.play(&"debuff")
	if camera != null:
		camera.call("add_trauma", 0.4)


static func _is_tail(e: ActionEvent, actor: String) -> bool:
	if e.target_id != actor:
		return false
	if e.type == ActionEvent.Type.STATUS_REMOVED:
		return true
	if (e.type == ActionEvent.Type.DAMAGE or e.type == ActionEvent.Type.HEAL) and e.status_id != "":
		return true
	return e.type == ActionEvent.Type.KO and e.actor_id == ""


static func _has_type(list: Array[ActionEvent], t: ActionEvent.Type) -> bool:
	for e: ActionEvent in list:
		if e.type == t:
			return true
	return false


static func _anim_for(start: ActionEvent, skill: SkillDef) -> StringName:
	match start.command:
		BattleCommand.Kind.STUNT:
			return &"stunt"
		BattleCommand.Kind.ITEM:
			return &"item"
	if skill != null and CharacterRig.ANIMS.has(StringName(skill.anim)):
		return StringName(skill.anim)
	return &"attack"


# --- helpers ----------------------------------------------------------------------------------------------------------

func _wait(sec: float) -> void:
	var s: float = sec / maxf(speed, 0.01)
	var t: float = 0.0
	while t < s:
		await frame_ticked
		t += get_process_delta_time()


## Waits for `sig` (any arity) or `timeout` seconds of game time, whichever comes first.
func _wait_signal(sig: Signal, timeout: float) -> void:
	var state: Dictionary = {"done": false}
	var cb: Callable = func(_a: Variant = null) -> void: state["done"] = true
	if sig.get_object() == null or not is_instance_valid(sig.get_object()):
		return
	sig.connect(cb, CONNECT_ONE_SHOT)
	var t: float = 0.0
	while not bool(state["done"]) and t < timeout:
		await frame_ticked
		t += get_process_delta_time()
	var obj: Object = sig.get_object()
	if obj != null and is_instance_valid(obj) and sig.is_connected(cb):
		sig.disconnect(cb)


func _tween_pos(node: Node3D, to: Vector3, sec: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.is_inside_tree():
		node.position = to
		return
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "position", to, sec / maxf(speed, 0.01)).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	await _wait_signal(tw.finished, sec / maxf(speed, 0.01) + 0.3)


func _shot(name_id: StringName, ctx: Dictionary = {}) -> void:
	if camera != null and is_instance_valid(camera):
		camera.set("speed", speed)
		camera.call("shot", name_id, ctx)


func _banner_big(text: String, col: Color, duration: float, sub: String = "", font_size: int = 64) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	hud.get("banner").call("announce", text, col, maxf(0.35, duration), sub, font_size)


## Subject-bound announcement (boss intro, phase change, sponsor gift) as a TV lower third.
func _lower_third(kicker: String, title: String, col: Color, duration: float) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	hud.get("banner").call("lower_third", kicker, title, col, maxf(0.6, duration))


func _rig(id: String) -> CharacterRig:
	if stage == null or id == "":
		return null
	return stage.call("rig", id) as CharacterRig


func _home(id: String) -> Vector3:
	return stage.call("home", id) if stage != null else Vector3.ZERO


func _anchor(id: String, a: StringName) -> Vector3:
	return stage.call("anchor_pos", id, a) if stage != null else Vector3(0, 1, 0)


func _party_center() -> Vector3:
	return stage.call("party_center") if stage != null else Vector3(0, 0, 3.1)


func _ids(party: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	if stage == null:
		return out
	for id: String in stage.call("unit_ids"):
		if id.begins_with("p") == party:
			out.append(id)
	out.sort()
	return out


func _target_center(targets: PackedStringArray) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	for t: String in targets:
		sum += _home(t)
	return sum / float(maxi(1, targets.size()))


## Melee position in front of the target (towards the attacker), on the ground.
func _strike_pos(actor: String, target: String) -> Vector3:
	var th: Vector3 = _home(target)
	var ah: Vector3 = _home(actor)
	var dir: Vector3 = Vector3(ah.x - th.x, 0, ah.z - th.z)
	if dir.length_squared() < 0.001:
		dir = Vector3(0, 0, 1)
	var tr2: CharacterRig = _rig(target)
	var ar: CharacterRig = _rig(actor)
	var reach: float = 0.45 + 0.35 * (tr2.size_factor() if tr2 != null else 1.0) \
		+ 0.3 * (ar.size_factor() if ar != null else 1.0)
	var p: Vector3 = th + dir.normalized() * reach
	p.y = 0.0
	return p


func _face_home(id: String) -> void:
	var r: CharacterRig = _rig(id)
	if r == null:
		return
	r.rotation = Vector3(0, 0.0 if id.begins_with("p") else PI, 0)


func _vfx(kind: StringName, id: String, a: StringName, col: Color) -> void:
	if stage == null:
		return
	var r: CharacterRig = _rig(id)
	var s: float = clampf(r.size_factor(), 0.6, 2.0) if r != null else 1.0
	Vfx.spawn(kind, stage, _anchor(id, a), col, s)


func _number(id: String, text: String, style: StringName) -> void:
	_number_at(_anchor(id, &"overhead"), text, style)


func _number_at(at: Vector3, text: String, style: StringName) -> void:
	if stage == null:
		return
	Vfx.damage_number(stage, at, text, style)
