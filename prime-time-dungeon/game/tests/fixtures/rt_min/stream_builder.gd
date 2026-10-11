extends RefCounted
## Builds the canned real-time streams of tests/fixtures/rt_min/streams (07 §12.2, R1a; R1b replaces them with
## recordings of the real sim). Private fixture helper (no class_name): test_r1a_contract checks that the committed
## files equal a fresh build, tests/tools/make_rt_streams.gd writes them. Format: see fake_rt_sim.gd.
## The streams are scripted, not simulated: positions, damage numbers and HP follow a plausible combat of the fixture
## data, every event field follows 07 §3.13, every HP change has its unit overlay.

const DATA_DIR: String = "res://tests/fixtures/rt_min"
const STREAM_DIR: String = "res://tests/fixtures/rt_min/streams"
const NAMES: PackedStringArray = ["regular_win", "boss_phases", "flee", "ko_control_defeat", "gifts"]
const T := ActionEvent.Type
const K := BattleCommand.Kind

var data: GameData = null
var _setup: RtSetup = null
var _ticks: Dictionary = {}                 # ct → {"events": Array, "overlays": Dictionary}
var _hp: Dictionary = {}                    # unit id → current hp (scripted bookkeeping)
var _max: Dictionary = {}                   # unit id → max hp


func _init(p_data: GameData = null) -> void:
	data = p_data if p_data != null else _load_data()


static func _load_data() -> GameData:
	var d: GameData = GameData.new()
	d.load_dir(DATA_DIR)
	return d


## name → stream dictionary (JSON-ready).
func build_all() -> Dictionary:
	return {"regular_win": regular_win(), "boss_phases": boss_phases(), "flee": flee(),
		"ko_control_defeat": ko_control_defeat(), "gifts": gifts()}


## Canonical JSON text of a stream (tab indent, sorted keys) — the committed file content.
static func to_text(stream: Dictionary) -> String:
	return JSON.stringify(stream, "\t", true) + "\n"


## Writes every stream to `dir` (absolute or res://); [] = ok, else the failed paths.
func write_all(dir: String) -> PackedStringArray:
	var failed: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(dir)
	var all: Dictionary = build_all()
	for n: String in NAMES:
		var path: String = dir.path_join(n + ".json")
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			failed.append(path)
			continue
		f.store_string(to_text(all[n]))
		f.close()
	return failed


# --- the five streams ----------------------------------------------------------------------------------------------

## Pull, auto attacks, an interrupt, a dodged telegraph, three kills, victory.
func regular_win() -> Dictionary:
	_begin("enc_f1_a2", "f1_g2", ["enm_kanalratte", "enm_kanalratte", "enm_rt_test_caster"], false)
	_prelude([_e(T.MOD_LINE, {"text": "rt_set_quiet"})])
	_target(0, "p0", "e0")
	_swing(0, "p0", "e0", "skl_attack_kai")
	_hit(9, "p0", "e0", 40, "skl_attack_kai", K.ATTACK)
	_target(3, "p1", "e2")
	_swing(3, "p1", "e2", "skl_attack_mopsula")
	_hit(12, "p1", "e2", 30, "skl_attack_mopsula", K.ATTACK)
	_ev(30, T.CAST_START, {"actor_id": "e2", "skill_id": "skl_e_test_hex", "target_id": "p0", "value": 60,
		"success": true, "rt": {"end": 90, "worthy": 1}, "by_ai": true})
	_ov(30, "e2", {"cast": _cast("skl_e_test_hex", "p0", 30, 90, true, true)})
	_action(33, "p0", "skl_kai_leash_trip", ["e2"], false)
	_ov(33, "p0", {"cooldowns": {"skl_kai_leash_trip": [393, 360]}})
	_hit(42, "p0", "e2", 25, "skl_kai_leash_trip", K.SKILL)
	_ev(42, T.CAST_INTERRUPTED, {"actor_id": "p0", "target_id": "e2", "skill_id": "skl_e_test_hex"})
	_ev(42, T.STATUS_ADDED, {"target_id": "e2", "status_id": "sts_slow", "value": 120, "rt": {"stacks": 1}})
	_ov(42, "e2", {"cast": {}, "lockout_until": 102,
		"statuses": [_status("sts_slow", "p0", 162, 42)]})
	_ev(42, T.ACTION_END, {"actor_id": "p0", "skill_id": "skl_kai_leash_trip"})
	_telegraph(45, "e1", "skl_e_test_slam", 1, RtTelegraph.Shape.CIRCLE, 0, 300, 0, 250, 0, 75)
	_ov(60, "p0", {"x": 0, "z": 600})
	_ev(75, T.TELEGRAPH_IMPACT, {"actor_id": "e1", "skill_id": "skl_e_test_slam", "value": 1})
	_ev(75, T.TELEGRAPH_DODGED, {"target_id": "p0", "value": 1, "success": true})
	_ev(75, T.ACTION_END, {"actor_id": "e1", "skill_id": "skl_e_test_slam", "by_ai": true})
	_ov(75, "e1", {"cast": {}})
	_hit(81, "p0", "e0", 128, "skl_attack_kai", K.ATTACK)
	_action(120, "p0", "skl_kai_heavy_swing", ["e1"], false)
	_hit(129, "p0", "e1", 168, "skl_kai_heavy_swing", K.SKILL)
	_ev(129, T.ACTION_END, {"actor_id": "p0", "skill_id": "skl_kai_heavy_swing"})
	_hit(160, "p1", "e2", 180, "skl_attack_mopsula", K.ATTACK)
	_end(160, BattleResult.Outcome.VICTORY, false)
	_seconds(160)
	var r: BattleResult = _result(BattleResult.Outcome.VICTORY, 161)
	r.interrupts = 1
	r.dodges = 1
	r.turns = 2
	r.party_turns = 2
	return _finish("regular_win", "Pull, Telegraph, Ausweichen, Unterbrechung, Kills, Sieg (07 §12.2).", r)


## Boss intro, phase 1 → 2 (perfect), adds, train kill, enrage, victory.
func boss_phases() -> Dictionary:
	_begin("enc_rt_test_boss", "f1_fb", ["enm_rt_test_boss"], true)
	_prelude([_e(T.MOD_LINE, {"text": "rt_set_quiet"}), _e(T.PHASE_CHANGE, {"actor_id": "e0", "value": 1})])
	_target(0, "p0", "e0")
	_target(3, "p1", "e0")
	for i in 5:
		_swing(i * 60, "p0", "e0", "skl_attack_kai")
		_hit(i * 60 + 9, "p0", "e0", 120, "skl_attack_kai", K.ATTACK)
	_telegraph(90, "e0", "skl_e_test_slam", 1, RtTelegraph.Shape.CIRCLE, 0, 200, 0, 250, 0, 120)
	_ov(105, "p0", {"x": 300, "z": 200})
	_ev(120, T.TELEGRAPH_IMPACT, {"actor_id": "e0", "skill_id": "skl_e_test_slam", "value": 1})
	_ev(120, T.TELEGRAPH_DODGED, {"target_id": "p0", "value": 1, "success": false})
	_ev(120, T.ACTION_END, {"actor_id": "e0", "skill_id": "skl_e_test_slam", "by_ai": true})
	_ov(120, "e0", {"cast": {}})
	_action(250, "p0", "skl_kai_heavy_swing", ["e0"], false)
	_hit(259, "p0", "e0", 300, "skl_kai_heavy_swing", K.SKILL)
	_ev(259, T.ACTION_END, {"actor_id": "p0", "skill_id": "skl_kai_heavy_swing"})
	_ev(300, T.PHASE_CHANGE, {"actor_id": "e0", "value": 2, "success": true})
	_summon(300, "e0", "e1", "enm_kanalratte", 1, -500, -600)
	_summon(300, "e0", "e2", "enm_kanalratte", 2, 500, -600)
	_telegraph(360, "e0", "skl_e_test_train", 2, RtTelegraph.Shape.LINE, -600, -600, 192, 1200, 300, 420)
	_ev(420, T.TELEGRAPH_IMPACT, {"actor_id": "e0", "skill_id": "skl_e_test_train", "value": 2,
		"target_ids": PackedStringArray(["e1", "e2"])})
	_ko(420, "e0", "e1", -1, "skl_e_test_train")
	_ko(420, "e0", "e2", -1, "skl_e_test_train")
	_ev(420, T.ACTION_END, {"actor_id": "e0", "skill_id": "skl_e_test_train", "by_ai": true})
	_ov(420, "e0", {"cast": {}})
	_ev(900, T.ENRAGE, {"actor_id": "e0", "value": 1})
	_ev(900, T.STATUS_ADDED, {"target_id": "e0", "status_id": "sts_enrage", "value": -1, "rt": {"stacks": 1}})
	_ov(900, "e0", {"statuses": [_status("sts_enrage", "e0", -1, 900)]})
	_action(990, "p0", "skl_stunt_kai_suplex", ["e0"], false)
	_ev(1014, T.STUNT_RESULT, {"actor_id": "p0", "skill_id": "skl_stunt_kai_suplex", "success": true})
	_hit(1014, "p0", "e0", int(_hp["e0"]), "skl_stunt_kai_suplex", K.STUNT)
	_end(1014, BattleResult.Outcome.VICTORY, true)
	_seconds(1014)
	var r: BattleResult = _result(BattleResult.Outcome.VICTORY, 1015)
	r.is_boss = true
	r.boss_id = "enm_rt_test_boss"
	r.train_kills = 2
	r.perfect_phases = 2
	r.turns = 4
	r.party_turns = 2
	r.defeated_ids = PackedStringArray(["enm_rt_test_boss"])
	r.kills = 1
	return _finish("boss_phases", "Intro, Phasen, Adds, Zug-Kill, Enrage (07 §12.2).", r)


## The controlled unit leaves the ring: flee warning, flight.
func flee() -> Dictionary:
	_begin("enc_f1_a2", "f1_g2", ["enm_kanalratte"], false)
	_prelude([])
	_target(0, "p0", "e0")
	_ov(30, "p0", {"x": 0, "z": 560, "outside_since": 30})
	_ev(45, T.FLEE_WARNING, {"actor_id": "p0", "value": 45})
	_ov(60, "p0", {"z": 700})
	_ev(90, T.FLEE_RESULT, {"actor_id": "p0", "success": true})
	_end(90, BattleResult.Outcome.FLED, false)
	_seconds(90)
	var r: BattleResult = _result(BattleResult.Outcome.FLED, 91)
	r.flee_attempts = 1
	return _finish("flee", "Fluchtwarnung nach 0,5 s außerhalb des Rings, Flucht (07 §2.5).", r)


## The controlled Kai falls, control follows life to Mopsula, the party falls: defeat.
func ko_control_defeat() -> Dictionary:
	_begin("enc_f1_a2", "f1_g2", ["enm_kanalratte", "enm_kanalratte", "enm_rt_test_caster"], false)
	_prelude([])
	_target(0, "p0", "e0")
	var t: int = 10
	while int(_hp["p0"]) > 0:
		_swing(t, "e0", "p0", "skl_e_strike")
		_hit(t + 9, "e0", "p0", mini(60, int(_hp["p0"])), "skl_e_strike", K.ATTACK)
		t += 72
	_ev(t - 63, T.CONTROL_CHANGED, {"actor_id": "p0", "target_id": "p1"})
	_ev(t - 63, T.MOD_LINE, {"text": "rt_control_switch:mopsula"})
	_ov(t - 63, "p1", {"driver": RtUnit.Driver.PLAYER})
	t += 30
	while int(_hp["p1"]) > 0:
		_swing(t, "e2", "p1", "skl_e_strike")
		_hit(t + 9, "e2", "p1", mini(45, int(_hp["p1"])), "skl_e_strike", K.ATTACK)
		t += 72
	_end(t - 63, BattleResult.Outcome.DEFEAT, false)
	_seconds(t - 63)
	var r: BattleResult = _result(BattleResult.Outcome.DEFEAT, t - 62)
	r.party_kos = 2
	return _finish("ko_control_defeat", "K.O. der gesteuerten Figur, Steuerungswechsel, Niederlage (07 §2.6).", r)


## An external gift at the boundary of tick 40 and a system gift at tick 41 (07 §9.2), then victory.
func gifts() -> Dictionary:
	_begin("enc_f1_a2", "f1_g2", ["enm_kanalratte", "enm_kanalratte"], false)
	_prelude([])
	_target(0, "p0", "e0")
	_swing(0, "e0", "p0", "skl_e_strike")
	_hit(9, "e0", "p0", 80, "skl_e_strike", K.ATTACK)
	_ev(40, T.SPONSOR_GIFT, {"sponsor_id": "spn_gluckwasser", "text": "Glückwasser", "rt": {"boundary": 1}})
	_heal(40, "p0", 60, true)
	_ev(41, T.SPONSOR_GIFT, {"sponsor_id": "spn_gluckwasser", "text": "Glückwasser", "rt": {"boundary": 1}})
	_heal(41, "p0", 20, true)
	_swing(60, "p0", "e0", "skl_attack_kai")
	_hit(69, "p0", "e0", int(_hp["e0"]), "skl_attack_kai", K.ATTACK)
	_target(70, "p0", "e1")
	_swing(120, "p0", "e1", "skl_attack_kai")
	_hit(129, "p0", "e1", int(_hp["e1"]), "skl_attack_kai", K.ATTACK)
	_end(129, BattleResult.Outcome.VICTORY, false)
	_seconds(129)
	var r: BattleResult = _result(BattleResult.Outcome.VICTORY, 130)
	return _finish("gifts", "Externes Geschenk an der Grenze von Tick 40, System-Geschenk an Tick 41 (07 §9.2).", r)


# --- building blocks ---------------------------------------------------------------------------------------------

func _begin(enc_id: String, group_id: String, enemy_ids: Array, boss: bool) -> void:
	_ticks = {}
	_hp = {}
	_max = {}
	var bal: RtBalance = RtBalance.from_data(data)
	var st: GameState = GameState.create_new(data, 0, "Kai", 4242)
	var s: RtSetup = RtSetup.new()
	s.encounter_id = enc_id
	s.group_id = group_id
	s.enemy_ids = PackedStringArray(enemy_ids)
	s.seed = 77
	s.is_boss = boss
	s.can_flee = not boss
	s.floor_index = 1
	s.items = st.inventory.battle_items(data)
	s.credits_available = st.inventory.credits
	s.balance = bal
	s.cell = Vector2i(2, 1)
	s.room_kind = RoomCell.Kind.FLOOR_BOSS if boss else RoomCell.Kind.NORMAL
	s.geo = {"r": bal.sub("SET_R_CM", "boss" if boss else "regular"), "doors": RoomCell.DOOR_N | RoomCell.DOOR_S,
		"closed": boss, "blockers": []}
	var party: Array[Combatant] = []
	for i in st.party.size():
		var m: PartyMember = st.party[i]
		var def: PartyMemberDef = data.party_member(m.id)
		var c: Combatant = Progression.to_combatant(m, data, "p%d" % i, def.battle_slot)
		var u: RtUnit = RtUnit.from_snapshot(c.to_dict(), data)
		u.display_name = def.name
		_party_rt(u, def, i, bal)
		party.append(u)
		s.units.append(u)
	s.party = party
	for i in enemy_ids.size():
		var edef: EnemyDef = data.enemy(str(enemy_ids[i]))
		var u: RtUnit = RtUnit.from_snapshot(Combatant.create_enemy(edef, "e%d" % i, i).to_dict(), data)
		_enemy_rt(u, edef, i, bal)
		s.units.append(u)
	s.groups = [{"group_id": group_id, "encounter_id": enc_id, "enemy_ids": Array(enemy_ids),
		"lead": [0, -300, 128], "state": "PATROL", "entry": []}]
	s.controlled_id = "p0"
	s.presets = {"p1": {"preset": "support", "tog": RtVocab.RT_TOGGLE_DEFAULTS.duplicate()}}
	s.tutorial_steps = PackedStringArray()
	_setup = s
	for u: RtUnit in s.units:
		_hp[u.id] = u.hp
		_max[u.id] = u.max_hp()


func _party_rt(u: RtUnit, def: PartyMemberDef, slot: int, bal: RtBalance) -> void:
	var rt: Dictionary = def.rt
	var hp: int = u.max_hp() * bal.i("HP_SCALE_PM") / 1000
	u.stats.values[StatBlock.Stat.HP] = hp
	u.hp = hp
	u.driver = RtUnit.Driver.PLAYER if slot == 0 else RtUnit.Driver.AI
	u.x = -150 * slot
	u.z = 300 + 100 * slot
	u.radius = int(rt.get("radius_cm", 40))
	u.move_cm_tick = int(rt.get("move_cm_s", 540)) / 30
	u.threat_pm = int(rt.get("threat_pm", 1000))
	u.auto_skill = str(rt.get("auto_skill", ""))
	u.swing_ticks = int(rt.get("swing_ms", 2000)) * 3 / 100
	u.reach = int(rt.get("reach_cm", 250))
	u.follow_cm = int(rt.get("follow_cm", 600)) if slot > 0 else 0
	u.preset = str(rt.get("default_preset", "attack")) if slot > 0 else ""
	u.toggles = RtVocab.RT_TOGGLE_DEFAULTS.duplicate() if slot > 0 else {}
	u.swing_ready = bal.i("FIRST_SWING_TICKS")
	var mpr: Dictionary = rt.get("mp_regen", {})
	u.mp_regen = {"mode": str(mpr.get("mode", "time")), "amount": int(mpr.get("amount", 0)),
		"taken": int(mpr.get("taken", 0)), "taken_every_ticks": int(mpr.get("taken_every_ms", 0)) * 3 / 100,
		"every_ticks": int(mpr.get("every_ms", 0)) * 3 / 100}
	for b: Variant in (rt.get("bar", []) as Array):
		var e: Dictionary = b
		if int(e.get("level", 1)) <= u.level and not bool(e.get("variant", false)) and not bool(e.get("finale", false)):
			u.bar[int(e["slot"])] = str(e["skill"])


func _enemy_rt(u: RtUnit, def: EnemyDef, slot: int, bal: RtBalance) -> void:
	var rt: Dictionary = def.rt
	var hp_pm: int = int(rt.get("hp_pm", 0))
	var hp: int = int(rt.get("hp", 0))
	if hp <= 0:
		hp = int(def.stats.get("hp", 1)) * (hp_pm if hp_pm > 0 else bal.i("ENEMY_HP_PM")) / 1000
	u.stats.values[StatBlock.Stat.HP] = hp
	u.hp = hp
	u.driver = RtUnit.Driver.AI
	u.x = -200 + 200 * slot
	u.z = -300
	u.yaw = 128
	u.radius = int(rt.get("radius_cm", 30))
	u.move_cm_tick = int(rt.get("move_cm_s", 360)) / 30
	u.stationary = bool(rt.get("stationary", false))
	u.keep_cm = int(rt.get("keep_cm", 0))
	u.auto_skill = str(rt.get("auto_skill", ""))
	u.swing_ticks = int(rt.get("swing_ms", 2400)) * 3 / 100
	u.reach = int(rt.get("reach_cm", 220))
	u.dmg_pm = int(rt.get("dmg_pm", 1000))
	u.pop_in_until = slot * bal.i("POP_IN_TICKS")


func _prelude(extra: Array) -> void:
	var ids: PackedStringArray = []
	for u: RtUnit in _setup.units:
		ids.append(u.id)
	_add(-1, _e(T.BATTLE_START, {"value": int(_setup.advantage), "target_ids": ids, "tick": 0}))
	for d: Variant in extra:
		var ed: Dictionary = d
		ed["tick"] = 0
		_add(-1, ed)


## An ActionEvent dictionary of type `t` with `f` (field → value) — exactly ActionEvent.to_dict().
func _e(t: ActionEvent.Type, f: Dictionary) -> Dictionary:
	var e: ActionEvent = ActionEvent.make(t)
	for k: Variant in f.keys():
		e.set(str(k), f[k])
	return e.to_dict()


func _ev(ct: int, t: ActionEvent.Type, f: Dictionary) -> void:
	var g: Dictionary = f.duplicate()
	g["tick"] = ct
	_add(ct, _e(t, g))


func _add(ct: int, ev: Dictionary) -> void:
	if not _ticks.has(ct):
		_ticks[ct] = {"events": [], "overlays": {}}
	(_ticks[ct]["events"] as Array).append(ev)


func _ov(ct: int, unit_id: String, f: Dictionary) -> void:
	if not _ticks.has(ct):
		_ticks[ct] = {"events": [], "overlays": {}}
	var ov: Dictionary = _ticks[ct]["overlays"]
	var cur: Dictionary = ov.get(unit_id, {})
	cur.merge(f, true)
	ov[unit_id] = cur


func _target(ct: int, a: String, t: String) -> void:
	_ev(ct, T.TARGET_CHANGED, {"actor_id": a, "target_id": t, "by_ai": a != "p0"})
	_ov(ct, a, {"target_id": t})


func _swing(ct: int, a: String, t: String, skill: String) -> void:
	_ev(ct, T.SWING, {"actor_id": a, "target_id": t, "skill_id": skill})
	var u: RtUnit = _unit(a)
	_ov(ct, a, {"swing_ready": ct + (u.swing_ticks if u != null else 60)})


func _action(ct: int, a: String, skill: String, targets: Array, by_ai: bool) -> void:
	var def: SkillDef = data.skill(skill)
	var kind: int = K.STUNT if def != null and def.is_stunt() else K.SKILL
	_ev(ct, T.ACTION_START, {"actor_id": a, "command": kind, "skill_id": skill,
		"target_ids": PackedStringArray(targets), "text": def.name if def != null else skill, "by_ai": by_ai})
	_ov(ct, a, {"gcd_until": ct + 45, "gcd_len": 45})


func _hit(ct: int, a: String, t: String, amount: int, skill: String, command: int) -> void:
	var dmg: int = mini(amount, int(_hp[t]))
	_hp[t] = int(_hp[t]) - dmg
	_ev(ct, T.DAMAGE, {"actor_id": a, "target_id": t, "amount": dmg, "hp_after": int(_hp[t]),
		"max_hp": int(_max[t]), "skill_id": skill, "element": "physical", "def_id": _def_id(t)})
	_ov(ct, t, {"hp": int(_hp[t])})
	if int(_hp[t]) == 0:
		_ko(ct, a, t, command, skill)


func _heal(ct: int, t: String, amount: int, boundary: bool) -> void:
	var h: int = mini(amount, int(_max[t]) - int(_hp[t]))
	_hp[t] = int(_hp[t]) + h
	var f: Dictionary = {"target_id": t, "amount": h, "hp_after": int(_hp[t]), "max_hp": int(_max[t]),
		"def_id": _def_id(t)}
	if boundary:
		f["rt"] = {"boundary": 1}
	_ev(ct, T.HEAL, f)
	_ov(ct, t, {"hp": int(_hp[t])})            # boundary heals: the unit shows it from that tick's step on


func _ko(ct: int, a: String, t: String, command: int, skill: String) -> void:
	_hp[t] = 0
	_ev(ct, T.KO, {"actor_id": a, "target_id": t, "def_id": _def_id(t), "max_hp": int(_max[t]), "command": command,
		"skill_id": skill, "by_ai": a != "p0" and command != -1})
	_ov(ct, t, {"hp": 0, "ko_at": ct, "target_id": "", "cast": {}})


func _telegraph(ct: int, a: String, skill: String, id: int, shape: int, x: int, z: int, yaw: int, r: int, r2: int,
		impact: int) -> void:
	_ev(ct, T.CAST_START, {"actor_id": a, "skill_id": skill, "value": impact - ct, "success": false,
		"rt": {"end": impact, "worthy": 0}, "by_ai": true})
	_ev(ct, T.TELEGRAPH_START, {"actor_id": a, "skill_id": skill, "value": id,
		"rt": {"shape": shape, "x": x, "z": z, "yaw": yaw, "r": r, "r2": r2, "half": 0, "start": ct, "impact": impact},
		"by_ai": true})
	_ov(ct, a, {"cast": _cast(skill, "", ct, impact, false, false)})


func _summon(ct: int, a: String, id: String, enemy_id: String, slot: int, x: int, z: int) -> void:
	var def: EnemyDef = data.enemy(enemy_id)
	var u: RtUnit = RtUnit.from_snapshot(Combatant.create_enemy(def, id, slot).to_dict(), data)
	_enemy_rt(u, def, slot, _setup.balance)
	var hp: int = int(def.stats.get("hp", 1)) * _setup.balance.i("SUMMON_HP_PM") / 1000
	u.stats.values[StatBlock.Stat.HP] = hp
	u.hp = hp
	u.is_summon = true
	u.x = x
	u.z = z
	u.entry = [x, z + 200]
	_hp[id] = hp
	_max[id] = hp
	_ev(ct, T.SUMMON, {"actor_id": a, "target_id": id, "def_id": enemy_id, "value": slot})
	_ov(ct, id, u.snapshot())


func _end(ct: int, outcome: int, last_phase_perfect: bool) -> void:
	_ev(ct, T.BATTLE_END, {"value": outcome, "success": last_phase_perfect})


## SECOND every 30 ticks up to `last_ct` (step 11 of every 30th tick, 07 §3.3).
func _seconds(last_ct: int) -> void:
	var c: int = 29
	while c <= last_ct:
		_ev(c, T.SECOND, {"value": (c + 1) / 30})
		c += 30


func _cast(skill: String, target: String, start: int, end: int, interruptible: bool, worthy: bool) -> Dictionary:
	return {"skill": skill, "target": target, "x": 0, "z": 0, "start": start, "end": end,
		"interruptible": interruptible, "worthy": worthy, "moving_cancels": false, "channel": false,
		"next_tick": -1, "tele": 0, "kind": "ability", "item": ""}


func _status(id: String, source: String, ends_at: int, applied_at: int) -> Dictionary:
	return {"id": id, "source_id": source, "ends_at": ends_at, "period": 0, "next_tick_at": -1, "stacks": 1,
		"applied_at": applied_at, "amount": 0}


func _unit(id: String) -> RtUnit:
	for u: RtUnit in _setup.units:
		if u.id == id:
			return u
	return null


func _def_id(id: String) -> String:
	var u: RtUnit = _unit(id)
	if u != null:
		return u.def_id
	return "enm_kanalratte" if id.begins_with("e") else ""


func _result(outcome: int, duration: int) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = outcome as BattleResult.Outcome
	r.encounter_id = _setup.encounter_id
	r.group_id = _setup.group_id
	r.group_ids = PackedStringArray([_setup.group_id])
	r.advantage = int(_setup.advantage)
	r.duration_ticks = duration
	var killed: PackedStringArray = []
	var exp: int = 0
	var credits: int = 0
	for u: RtUnit in _setup.units:
		if u.side == Combatant.Side.PARTY:
			r.party_hp[u.def_id] = int(_hp[u.id])
			r.party_mp[u.def_id] = u.mp
		elif int(_hp[u.id]) == 0:
			killed.append(u.def_id)
			exp += u.exp_reward
			credits += u.credit_reward
	r.defeated_ids = killed
	r.kills = killed.size()
	if outcome == BattleResult.Outcome.VICTORY:
		r.exp = exp
		r.credits = credits
	var min_hp: int = 1 << 30
	for u: RtUnit in _setup.units:
		if u.side == Combatant.Side.PARTY and int(_hp[u.id]) > 0:
			min_hp = mini(min_hp, int(_hp[u.id]))
	r.min_party_hp = min_hp if min_hp != 1 << 30 else 0
	return r


func _finish(name: String, notes: String, r: BattleResult) -> Dictionary:
	var rows: Array = []
	var cts: Array = _ticks.keys()
	cts.sort()
	for ct: Variant in cts:
		var entry: Dictionary = _ticks[ct]
		rows.append([int(ct), entry["events"], entry["overlays"]])
	var res: Dictionary = r.to_dict()
	res.erase("min_party_hp_pct")          # float-free like BattleState snapshots (canonical JSON)
	return {"name": name, "notes": notes, "setup": _setup.to_dict(), "ticks": rows, "result": res}
