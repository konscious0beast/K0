extends RefCounted
## R2 world fixture (07 §12.2: "Fixture-Kampf spielbar" before R1b): builds a FakeRtSim stream for the encounter command
## the ExplorationScene recorded — the units of the real data in the real set cell (party poses and group leads from
## the command, extras in formation around their lead, 07 §3.5.5), and a scripted course of the combat: enemies walk
## in and close in, swings and hits, a telegraph on the controlled unit (dodged), KOs, victory — or flight, the control
## switch + defeat, a boss with the Gleis-9 train lane, or an endless loop for stills / perf. Format: fake_rt_sim.gd.
## Private test helper (no class_name). Used through Game.rt_sim_factory:
##   Game.rt_sim_factory = WorldStream.factory(scene, "win")      # → func(cmd, seed) -> FakeRtSim
## The stream is scripted, not simulated (positions, HP and events are plausible, never authoritative).

const T := ActionEvent.Type
const K := BattleCommand.Kind
const FORMATION: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-130, 90), Vector2i(130, 90), Vector2i(0, 180)]
const PLANS: PackedStringArray = ["win", "flee", "defeat", "boss", "loop"]

var data: GameData = null
var plan: String = "win"
var geo: Dictionary = {}
var _setup: RtSetup = null
var _ticks: Dictionary = {}                 # ct → {"events": Array, "overlays": Dictionary}
var _hp: Dictionary = {}
var _max: Dictionary = {}
var _pos: Dictionary = {}                   # unit id → Vector2i (cm, room-local) at the last scripted overlay
var _ctl: String = "p0"
var _ai: String = "p1"
var _enemies: PackedStringArray = []
var _tele_id: int = 0


## A Game.rt_sim_factory for the world `scene` (ExplorationScene): every encounter command becomes a FakeRtSim with
## `p_plan` ("win" | "flee" | "defeat" | "boss" | "loop"); `length` = ticks until the end (loop: never).
static func factory(scene: Node, p_plan: String = "win", length: int = 300) -> Callable:
	var script: GDScript = load("res://tests/fixtures/rt_world/world_stream.gd") as GDScript
	return func(cmd: Dictionary, seed: int) -> RtSim:
		var b: RefCounted = script.new()
		b.set("data", DB.data)
		b.set("plan", p_plan)
		var rt: Dictionary = cmd.get("rt", {})
		var cell: Vector2i = Vector2i(int((rt["cell"] as Array)[0]), int((rt["cell"] as Array)[1]))
		var enc: EncounterDef = DB.encounter(str(cmd.get("enc", ""))) if DB.has_id("encounters",
			str(cmd.get("enc", ""))) else null
		var closed: bool = enc != null and (enc.boss or enc.tutorial or not enc.can_flee)
		b.set("geo", scene.call("rt_geo", cell, closed))
		var stream: Dictionary = b.call("build", cmd, seed, length)
		var sim: FakeRtSim = FakeRtSim.new(stream, DB.data)
		sim.stream_name = "world_" + p_plan
		return sim


## The stream of `cmd` (07 §10.1 encounter with its rt block).
func build(cmd: Dictionary, seed: int, length: int) -> Dictionary:
	_ticks = {}
	_hp = {}
	_max = {}
	_pos = {}
	_enemies = PackedStringArray()
	_tele_id = 0
	_setup = _make_setup(cmd, seed)
	_prelude()
	match plan:
		"flee":
			_script_flee()
		"defeat":
			_script_defeat()
		"boss":
			_script_boss(length)
		"loop":
			_script_loop(length)
		_:
			_script_win(length)
	var rows: Array = []
	var cts: Array = _ticks.keys()
	cts.sort()
	for ct: Variant in cts:
		rows.append([int(ct), (_ticks[ct] as Dictionary)["events"], (_ticks[ct] as Dictionary)["overlays"]])
	return {"name": "world_" + plan, "notes": "R2 world fixture", "setup": _setup.to_dict(), "ticks": rows,
		"result": _result_dict()}


# --- setup -----------------------------------------------------------------------------------------------------------

func _make_setup(cmd: Dictionary, seed: int) -> RtSetup:
	var rt: Dictionary = cmd["rt"]
	var s: RtSetup = RtSetup.new()
	var enc_id: String = str(cmd.get("enc", ""))
	var enc: EncounterDef = data.encounter(enc_id) if data.has_id("encounters", enc_id) else null
	s.encounter_id = enc_id
	s.group_id = str(cmd.get("group", ""))
	s.advantage = int(cmd.get("adv", 0)) as BattleSetup.Advantage
	s.seed = seed
	s.is_boss = enc != null and enc.boss
	s.can_flee = enc == null or enc.can_flee
	s.tutorial = enc != null and enc.tutorial
	s.floor_index = 1
	s.balance = RtBalance.from_data(data)
	s.cell = Vector2i(int((rt["cell"] as Array)[0]), int((rt["cell"] as Array)[1]))
	s.room_kind = 0
	s.geo = geo.duplicate(true)
	s.controlled_id = str(rt.get("ctl", "p0"))
	_ctl = s.controlled_id
	s.presets = (rt.get("presets", {}) as Dictionary).duplicate(true)
	s.rt_opener = (rt.get("open", {}) as Dictionary).duplicate(true)
	var party: Array[Combatant] = []
	var st: GameState = Game.state
	for p: Variant in (rt.get("party", []) as Array):
		var pd: Dictionary = p
		var uid: String = str(pd["u"])
		var member: String = _member_of(uid)
		var m: PartyMember = st.member(member) if st != null else null
		if m == null:
			continue
		var c: Combatant = Progression.to_combatant(m, data, uid, int(uid.substr(1)))
		var u: RtUnit = RtUnit.from_snapshot(c.to_dict(), data)
		u.display_name = data.party_member(member).name
		var hp: int = maxi(1, u.max_hp()) * 4
		u.stats.values[StatBlock.Stat.HP] = hp
		u.hp = hp
		u.driver = RtUnit.Driver.PLAYER if uid == _ctl else RtUnit.Driver.AI
		var pose: Array = pd["p"]
		u.x = int(pose[0])
		u.z = int(pose[1])
		u.yaw = int(pose[2])
		u.radius = 35 if member == "mopsula" else 40
		u.swing_ticks = 72 if member == "mopsula" else 60
		u.reach = 1000 if member == "mopsula" else 250
		if uid != _ctl:
			_ai = uid
		party.append(u)
		s.units.append(u)
	s.party = party
	var n: int = 0
	var groups: Array = rt.get("groups", [])
	if groups.is_empty() and enc != null:
		groups = [{"group": "", "enc": enc_id, "lead": [0, -300, 128], "state": "IDLE"}]
	for g: Variant in groups:
		var gd: Dictionary = g
		var genc: EncounterDef = data.encounter(str(gd["enc"])) if data.has_id("encounters", str(gd["enc"])) else null
		var ids: PackedStringArray = _enemy_ids(genc)
		var lead: Array = gd["lead"]
		var lp: Vector2i = _inside(Vector2i(int(lead[0]), int(lead[1])), 60)
		var yaw: int = int(lead[2])
		for i in ids.size():
			var edef: EnemyDef = data.enemy(ids[i])
			var uid: String = "e%d" % n
			var u: RtUnit = RtUnit.from_snapshot(Combatant.create_enemy(edef, uid, n).to_dict(), data)
			var hp: int = int(edef.stats.get("hp", 30)) * 7
			if edef.boss:
				hp = 1600
			u.stats.values[StatBlock.Stat.HP] = hp
			u.hp = hp
			u.driver = RtUnit.Driver.AI
			var off: Vector2i = _rot(FORMATION[mini(i, FORMATION.size() - 1)], yaw)
			var p: Vector2i = Vector2i(int(lead[0]), int(lead[1])) if i == 0 else _inside(lp + off, 60)
			u.x = p.x
			u.z = p.y
			u.yaw = yaw
			u.radius = 90 if edef.boss else 35
			u.pop_in_until = 15 if i > 0 else 0
			if i == 0 and p != lp:
				u.entry = [lp.x, lp.y]
			s.units.append(u)
			_enemies.append(uid)
			n += 1
		s.groups.append({"group_id": str(gd["group"]), "encounter_id": str(gd["enc"]), "enemy_ids": Array(ids),
			"lead": [int(lead[0]), int(lead[1]), yaw], "state": str(gd.get("state", "IDLE")), "entry": [lp.x, lp.y]})
	s.enemy_ids = PackedStringArray()
	for u: RtUnit in s.units:
		_hp[u.id] = u.hp
		_max[u.id] = u.max_hp()
		_pos[u.id] = Vector2i(u.x, u.z)
		if u.side == Combatant.Side.ENEMY and s.enemy_ids.size() < 4:
			s.enemy_ids.append(u.def_id)
	return s


static func _member_of(uid: String) -> String:
	for m: PartyMemberDef in DB.data.all_party():
		if "p%d" % m.battle_slot == uid:
			return m.id
	return "kai"


static func _enemy_ids(enc: EncounterDef) -> PackedStringArray:
	if enc == null:
		return PackedStringArray(["enm_kanalratte"])
	var ids: PackedStringArray = JsonUtil.to_str_array(enc.rt.get("enemies", [])) if not enc.rt.is_empty() \
		else PackedStringArray()
	return ids if not ids.is_empty() else enc.enemies


## Formation offset (+dz = behind the anchor) turned by a u8 yaw (07 §3.5.5).
static func _rot(off: Vector2i, yaw: int) -> Vector2i:
	var a: float = float(yaw) * TAU / 256.0
	var x: float = float(off.x) * cos(a) + float(off.y) * sin(a)
	var z: float = -float(off.x) * sin(a) + float(off.y) * cos(a)
	return Vector2i(roundi(x), roundi(z))


## A point at least `margin` cm inside the ring.
func _inside(p: Vector2i, margin: int) -> Vector2i:
	var r: float = float(int(geo.get("r", 480)) - margin)
	var v: Vector2 = Vector2(p)
	if v.length() <= r:
		return p
	v = v.normalized() * r
	return Vector2i(roundi(v.x), roundi(v.y))


# --- building blocks --------------------------------------------------------------------------------------------------

func _e(t: ActionEvent.Type, f: Dictionary) -> Dictionary:
	var e: ActionEvent = ActionEvent.make(t)
	for k: Variant in f.keys():
		e.set(str(k), f[k])
	return e.to_dict()


func _ev(ct: int, t: ActionEvent.Type, f: Dictionary) -> void:
	var g: Dictionary = f.duplicate()
	g["tick"] = maxi(0, ct)
	_add(ct, _e(t, g))


func _add(ct: int, ev: Dictionary) -> void:
	if not _ticks.has(ct):
		_ticks[ct] = {"events": [], "overlays": {}}
	((_ticks[ct] as Dictionary)["events"] as Array).append(ev)


func _ov(ct: int, uid: String, f: Dictionary) -> void:
	if not _ticks.has(ct):
		_ticks[ct] = {"events": [], "overlays": {}}
	var ov: Dictionary = (_ticks[ct] as Dictionary)["overlays"]
	var cur: Dictionary = ov.get(uid, {})
	cur.merge(f, true)
	ov[uid] = cur


func _prelude() -> void:
	var ids: PackedStringArray = []
	for u: RtUnit in _setup.units:
		ids.append(u.id)
	var start: Dictionary = _e(T.BATTLE_START, {"value": int(_setup.advantage), "target_ids": ids})
	start["tick"] = 0
	_add(-1, start)


## Walks `uid` from its last scripted position towards `to` (cm) during [c0, c1], an overlay every 3 ticks.
func _walk(uid: String, to: Vector2i, c0: int, c1: int) -> void:
	var from: Vector2i = _pos.get(uid, to)
	var dest: Vector2i = _inside(to, 60)
	var d: Vector2i = dest - from
	var yaw: int = posmod(roundi(atan2(-float(d.x), -float(d.y)) * 256.0 / TAU), 256) if d != Vector2i.ZERO else 0
	var c: int = c0
	while c <= c1:
		var u: float = float(c - c0) / float(maxi(1, c1 - c0))
		var p: Vector2i = Vector2i(roundi(lerpf(from.x, dest.x, u)), roundi(lerpf(from.y, dest.y, u)))
		var f: Dictionary = {"x": p.x, "z": p.y}
		if d != Vector2i.ZERO:
			f["yaw"] = yaw
		_ov(c, uid, f)
		c += 3
	_ov(c1, uid, {"x": dest.x, "z": dest.y})
	_pos[uid] = dest


## The point `dist` cm in front of `of_uid` as seen from `uid` (melee spot).
func _near(uid: String, of_uid: String, dist: int) -> Vector2i:
	var a: Vector2i = _pos.get(uid, Vector2i.ZERO)
	var b: Vector2i = _pos.get(of_uid, Vector2i.ZERO)
	var v: Vector2 = Vector2(a - b)
	if v.length() < 1.0:
		v = Vector2(0.0, -1.0)
	var p: Vector2 = Vector2(b) + v.normalized() * dist
	return Vector2i(roundi(p.x), roundi(p.y))


func _swing(ct: int, a: String, t: String, amount: int) -> void:
	_ev(ct, T.SWING, {"actor_id": a, "target_id": t, "skill_id": "skl_attack"})
	_hit(ct + 9, a, t, amount, K.ATTACK)


func _hit(ct: int, a: String, t: String, amount: int, command: int) -> void:
	var dmg: int = mini(amount, int(_hp.get(t, 0)))
	if dmg <= 0:
		return
	_hp[t] = int(_hp[t]) - dmg
	_ev(ct, T.DAMAGE, {"actor_id": a, "target_id": t, "amount": dmg, "hp_after": int(_hp[t]), "max_hp": int(_max[t]),
		"element": "physical", "command": command})
	_ov(ct, t, {"hp": int(_hp[t])})
	if int(_hp[t]) == 0:
		_ev(ct, T.KO, {"actor_id": a, "target_id": t, "max_hp": int(_max[t]), "command": command})
		_ov(ct, t, {"ko_at": ct, "target_id": "", "cast": {}})


func _telegraph(ct: int, a: String, shape: int, x: int, z: int, yaw: int, r: int, r2: int, impact: int,
		hits: PackedStringArray = []) -> void:
	_tele_id += 1
	var id: int = _tele_id
	_ev(ct, T.CAST_START, {"actor_id": a, "skill_id": "skl_e_test_slam", "value": impact - ct, "success": false,
		"rt": {"end": impact, "worthy": 0}, "by_ai": true})
	_ev(ct, T.TELEGRAPH_START, {"actor_id": a, "skill_id": "skl_e_test_slam", "value": id, "by_ai": true,
		"rt": {"shape": shape, "x": x, "z": z, "yaw": yaw, "r": r, "r2": r2, "half": 45, "start": ct, "impact": impact}})
	_ov(ct, a, {"cast": {"skill": "skl_e_test_slam", "target": "", "x": 0, "z": 0, "start": ct, "end": impact,
		"interruptible": false, "worthy": false, "moving_cancels": false, "channel": false, "next_tick": -1, "tele": id,
		"kind": "ability", "item": ""}})
	_ev(impact, T.TELEGRAPH_IMPACT, {"actor_id": a, "skill_id": "skl_e_test_slam", "value": id, "target_ids": hits})
	_ov(impact, a, {"cast": {}})


func _end(ct: int, outcome: int) -> void:
	_ev(ct, T.BATTLE_END, {"value": outcome, "success": false})
	_end_ct = ct
	_outcome = outcome
	var c: int = 29
	while c <= ct:
		_ev(c, T.SECOND, {"value": (c + 1) / 30})
		c += 30


var _end_ct: int = -1
var _outcome: int = BattleResult.Outcome.VICTORY


func _result_dict() -> Dictionary:
	var r: BattleResult = BattleResult.new()
	r.outcome = _outcome as BattleResult.Outcome
	r.encounter_id = _setup.encounter_id
	r.group_id = _setup.group_id
	var gids: PackedStringArray = []
	for g: Dictionary in _setup.groups:
		if str(g["group_id"]) != "":
			gids.append(str(g["group_id"]))
	r.group_ids = gids
	r.advantage = int(_setup.advantage)
	r.is_boss = _setup.is_boss
	r.duration_ticks = maxi(1, _end_ct + 1)
	var killed: PackedStringArray = []
	for u: RtUnit in _setup.units:
		if u.side == Combatant.Side.PARTY:
			r.party_hp[u.def_id] = maxi(1, int(_hp[u.id]) / 4)
			r.party_mp[u.def_id] = u.mp
		elif int(_hp[u.id]) == 0:
			killed.append(u.def_id)
			if _outcome == BattleResult.Outcome.VICTORY:
				r.exp += u.exp_reward
				r.credits += u.credit_reward
	r.defeated_ids = killed
	r.kills = killed.size()
	if _setup.is_boss and not killed.is_empty():
		r.boss_id = killed[0]
	r.min_party_hp = 1
	var d: Dictionary = r.to_dict()
	d.erase("min_party_hp_pct")
	return d


# --- plans ------------------------------------------------------------------------------------------------------------

## Enemies walk in, the party fights, a telegraph on the controlled unit (dodged), KOs one by one, victory.
func _script_win(length: int) -> void:
	var end: int = maxi(120, length)
	for i in _enemies.size():
		var e: String = _enemies[i]
		_walk(e, _near(e, _ctl if i % 2 == 0 else _ai, 160 + 40 * (i % 3)), 0, 40 + 6 * i)
	_ev(0, T.TARGET_CHANGED, {"actor_id": _ctl, "target_id": _enemies[0]})
	_ov(0, _ctl, {"target_id": _enemies[0]})
	_walk(_ai, _near(_ai, _enemies[mini(1, _enemies.size() - 1)], 450), 0, 30)
	var ctl_pos: Vector2i = _pos.get(_ctl, Vector2i.ZERO)
	_telegraph(45, _enemies[0], RtTelegraph.Shape.CIRCLE, ctl_pos.x, ctl_pos.y, 0, 250, 0, 81)
	_ev(81, T.TELEGRAPH_DODGED, {"target_id": _ctl, "value": _tele_id, "success": true})
	if _enemies.size() > 2:
		var p2: Vector2i = _pos.get(_ai, Vector2i.ZERO)
		var e2: Vector2i = _pos.get(_enemies[2], Vector2i.ZERO)
		_telegraph(60, _enemies[2], RtTelegraph.Shape.CONE, e2.x, e2.y, _yaw_to(_enemies[2], _ai), 400, 0, 114)
		_ev(114, T.TELEGRAPH_DODGED, {"target_id": _ai, "value": _tele_id, "success": false, "by_ai": true})
		_walk(_ai, p2 + Vector2i(150, 0), 90, 110)
	var per: int = maxi(20, (end - 60) / maxi(1, _enemies.size()))
	var t: int = 30
	for i in _enemies.size():
		var e: String = _enemies[i]
		var c0: int = 30 + per * i
		while t < c0 + per - 12:
			_swing(t, _ctl, e, maxi(1, int(_max[e]) / 4))
			_swing(t + 12, _ai, e, maxi(1, int(_max[e]) / 6))
			_swing(t + 20, e, _ctl if i % 2 == 0 else _ai, 12)
			t += 30
		_hit(c0 + per - 6, _ctl, e, int(_hp[e]), K.SKILL)
		t = c0 + per
	_end(t, BattleResult.Outcome.VICTORY)


## The controlled unit walks out through a door lane: FLEE_WARNING at 15 ticks outside, FLED after 60.
func _script_flee() -> void:
	for i in _enemies.size():
		_walk(_enemies[i], _near(_enemies[i], _ctl, 200), 0, 40)
	_ev(30, T.FLEE_WARNING, {"actor_id": _ctl, "value": 45})
	_ev(75, T.FLEE_RESULT, {"actor_id": _ctl, "success": true})
	_end(75, BattleResult.Outcome.FLED)


## Kai falls, control follows life to Graf Mopsula, then the party falls: defeat (07 §2.6).
func _script_defeat() -> void:
	for i in _enemies.size():
		_walk(_enemies[i], _near(_enemies[i], _ctl, 150), 0, 30)
	var t: int = 20
	while int(_hp[_ctl]) > 0:
		_swing(t, _enemies[0], _ctl, maxi(1, int(_max[_ctl]) / 3))
		t += 20
	var ko: int = t - 11
	_ev(ko, T.CONTROL_CHANGED, {"actor_id": _ctl, "target_id": _ai})
	_ov(ko, _ai, {"driver": RtUnit.Driver.PLAYER})
	_ov(ko, _ctl, {"driver": RtUnit.Driver.AI})
	t += 30
	while int(_hp[_ai]) > 0:
		_swing(t, _enemies[0], _ai, maxi(1, int(_max[_ai]) / 2))
		t += 20
	_end(t - 11, BattleResult.Outcome.DEFEAT)


## Boss: the queen with her court — 2 rats at once, 3 more at tick 300 (summons with a smoke puff) — phase 2 at
## tick 150 with the Gleis-9 train as a lane telegraph along x (07 §6.7: lanes z = -330 / +330, width 300, a chord of
## the ring, alternating every 200 ticks), puddle circles leaving poison zones; victory at the end.
func _script_boss(length: int) -> void:
	var boss: String = _enemies[0]
	_ev(0, T.PHASE_CHANGE, {"actor_id": boss, "value": 1})
	_walk(_ai, _near(_ai, boss, 500), 0, 30)
	var r: int = int(geo.get("r", 600))
	var end: int = maxi(300, length) - 30
	for i in 5:
		var at: int = 10 if i < 2 else 300
		if at + 40 < end:
			var add: String = _summon(at, boss, "enm_kanalratte", i)
			_walk(add, _near(add, _ctl if i % 2 == 0 else _ai, 140), at + 15, at + 45)
	_ev(150, T.PHASE_CHANGE, {"actor_id": boss, "value": 2, "success": true})
	var c: int = 160
	var k: int = 0
	while c + 90 < end:
		_telegraph(c, boss, RtTelegraph.Shape.LINE, -r, -330 if k % 2 == 0 else 330, 192, 2 * r, 300, c + 90)
		var px: int = 250 - 170 * (k % 3)
		_telegraph(c + 40, boss, RtTelegraph.Shape.CIRCLE, px, 230, 0, 200, 0, c + 85)
		_ev(c + 85, T.ZONE_START, {"actor_id": boss, "status_id": "sts_poison", "value": 2000 + k,
			"rt": {"shape": 0, "x": px, "z": 230, "r": 200, "end": c + 385}})
		_ev(mini(c + 385, end - 1), T.ZONE_END, {"value": 2000 + k})
		c += 200
		k += 1
	var t: int = 20
	while t < end:
		_swing(t, _ctl, boss, maxi(1, int(_max[boss]) / 14))
		_swing(t + 15, boss, _ctl, 20)
		t += 30
	_hit(t, _ctl, boss, int(_hp[boss]), K.STUNT)
	_end(t, BattleResult.Outcome.VICTORY)


## A summoned enemy `def_id` next to `by` at tick `ct` (full snapshot overlay + SUMMON event, 07 §3.12); its unit id.
func _summon(ct: int, by: String, def_id: String, k: int) -> String:
	var edef: EnemyDef = data.enemy(def_id)
	var n: int = _enemies.size()
	var uid: String = "e%d" % n
	var u: RtUnit = RtUnit.from_snapshot(Combatant.create_enemy(edef, uid, n).to_dict(), data)
	u.is_summon = true
	u.driver = RtUnit.Driver.AI
	u.radius = 35
	var hp: int = int(edef.stats.get("hp", 30)) * 7
	u.stats.values[StatBlock.Stat.HP] = hp
	u.hp = hp
	var bp: Vector2i = _pos.get(by, Vector2i.ZERO)
	var p: Vector2i = _inside(bp + Vector2i(-180 + 90 * k, 170), 60)
	u.x = p.x
	u.z = p.y
	_ov(ct, uid, u.snapshot())
	_ev(ct, T.SUMMON, {"actor_id": by, "target_id": uid})
	_enemies.append(uid)
	_hp[uid] = hp
	_max[uid] = u.max_hp()
	_pos[uid] = p
	return uid


## Never ends inside `length` ticks: enemies close in, telegraphs and zones keep coming (stills, perf: worst case).
func _script_loop(length: int) -> void:
	for i in _enemies.size():
		_walk(_enemies[i], _near(_enemies[i], _ctl if i % 2 == 0 else _ai, 170 + 30 * (i % 3)), 0, 30 + 4 * i)
	_walk(_ai, _near(_ai, _enemies[0], 450), 0, 30)
	var r: int = int(geo.get("r", 480))
	var c: int = 20
	var k: int = 0
	while c < length:
		var e: String = _enemies[k % _enemies.size()]
		var ep: Vector2i = _pos.get(e, Vector2i.ZERO)
		var shape: int = k % 4
		match shape:
			RtTelegraph.Shape.CIRCLE:
				var cp: Vector2i = _pos.get(_ctl, Vector2i.ZERO)
				_telegraph(c, e, shape, cp.x + 60, cp.y - 40, 0, 220, 0, c + 60)
			RtTelegraph.Shape.CONE:
				_telegraph(c, e, shape, ep.x, ep.y, _yaw_to(e, _ctl), 420, 0, c + 54)
			RtTelegraph.Shape.RING:
				_telegraph(c, e, shape, ep.x, ep.y, 0, 380, 200, c + 72)
			_:
				_telegraph(c, e, shape, -r, -260 + 170 * (k % 3), 192, 2 * r, 150, c + 66)
		if k % 3 == 0:
			_ev(c + 2, T.ZONE_START, {"actor_id": e, "status_id": "sts_poison", "value": 1000 + k,
				"rt": {"shape": 0, "x": -150 + 40 * (k % 5), "z": 120, "r": 180, "end": c + 150}})
			_ev(c + 150, T.ZONE_END, {"value": 1000 + k})
		_swing(c + 5, e, _ctl if k % 2 == 0 else _ai, 1)
		_swing(c + 8, _ctl, _enemies[0], 1)
		c += 22
		k += 1


func _yaw_to(a: String, b: String) -> int:
	var d: Vector2i = (_pos.get(b, Vector2i.ZERO) as Vector2i) - (_pos.get(a, Vector2i.ZERO) as Vector2i)
	if d == Vector2i.ZERO:
		return 0
	return posmod(roundi(atan2(-float(d.x), -float(d.y)) * 256.0 / TAU), 256)
