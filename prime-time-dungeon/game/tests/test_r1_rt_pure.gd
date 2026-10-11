extends TestCase
## 07 §3.4 "Reinheit", §3.14, §10.4 (R1b-I1, I2: suggest, RtRules.choose, RtGeo.escape_point) test_r1_rt_pure: the
## queries never change the sim — 1 000 calls of every query in a running combat leave StateHash.of_rt unchanged (no
## draw, no write, no event), and a run with queries
## after every tick has the same end hash and the same events as one without. Hash invariance: the snapshot is
## complete (every hashed Combatant field, every real-time unit and status field and the combat state move the hash),
## display names never do, and RtSetup.to_dict is canonical.

const T := ActionEvent.Type
const EXTRA_SKILLS: Array = ["skl_kai_prime_finisher", "skl_mop_inferno", "skl_mop_revive", "skl_item_bandage",
	"skl_does_not_exist", ""]


## Every query of 07 §3.4 for every unit, skill (bar, FINALE, context, auto, unknown), item and target; returns the
## number of calls.
static func _query_all(sim: RtSim) -> int:
	var n: int = 0
	var ids: Array = ["", "e99"]
	for u: RtUnit in sim.units():
		ids.append(u.id)
	var items: Array = sim.items.keys()
	items.append_array(["itm_key_master", "itm_does_not_exist"])
	for u: RtUnit in sim.units():
		var skills: Array = u.bar.values()
		skills.append(u.auto_skill)
		skills.append_array(EXTRA_SKILLS)
		for sid: Variant in skills:
			for tid: Variant in ids:
				sim.can_use(u.id, str(sid), str(tid))
				n += 1
			sim.cooldown_left(u.id, str(sid))
			sim.cooldown_total(u.id, str(sid))
			n += 2
		for iid: Variant in items:
			for tid: Variant in ids:
				sim.can_use_item(u.id, str(iid), str(tid))
				n += 1
		sim.suggest(u.id)
		sim.bar(u.id)
		sim.partner_special_skill(u.id)
		sim.gcd_left(u.id)
		sim.gcd_total(u.id)
		sim.cast_progress(u.id)
		RtRules.choose(sim, u)                                       # the rule engine is pure as well (R1b-I2)
		RtGeo.escape_point(sim, u)
		n += 8
	for q: String in ["item_cd_left", "item_cd_total", "items_left", "tick", "is_finished", "controlled_id", "units",
			"telegraphs", "snapshot"]:
		sim.call(q)
		n += 1
	sim.unit("e0")
	sim.unit("nobody")
	sim.can_use("nobody", "skl_kai_heavy_swing", "")
	sim.can_use_item("nobody", "itm_bandage", "")
	return n + 4


## The cheaper set run after every tick: the party's bar, items and the timers.
static func _query_party(sim: RtSim) -> void:
	for id: String in ["p0", "p1"]:
		var bar: Dictionary = sim.bar(id)
		for s: Variant in bar.keys():
			sim.can_use(id, str(bar[s]), "")
			sim.can_use(id, str(bar[s]), "e0")
			sim.cooldown_left(id, str(bar[s]))
		sim.can_use_item(id, "itm_bandage", "")
		sim.partner_special_skill(id)
		sim.suggest(id)
		sim.cast_progress(id)
		sim.gcd_left(id)
	sim.items_left()
	sim.item_cd_left()


static func _dicts(events: Array) -> Array:
	var out: Array = []
	for e: ActionEvent in events:
		out.append(e.to_dict())
	return out


func test_thousand_queries_change_nothing() -> void:
	var cmds: Array = RtKit.canned_commands()
	var sim: RtSim = RtKit.canned_sim()
	var twin: RtSim = RtKit.canned_sim()
	RtKit.play(sim, cmds, 300)
	RtKit.play(twin, cmds, 300)
	var h0: String = StateHash.of_rt(sim)
	var calls: int = 0
	while calls < 1000:
		calls += _query_all(sim)
	assert_gt(calls, 999)
	assert_eq(StateHash.of_rt(sim), h0, "%d queries: no draw, no write" % calls)
	assert_eq(h0, StateHash.of_rt(twin))
	var rest: Array = RtKit.from_tick(cmds, 300)
	var a: Dictionary = RtKit.play(sim, rest, 1800)
	var b: Dictionary = RtKit.play(twin, rest, 1800)
	assert_eq(_dicts(a["events"]), _dicts(b["events"]), "and no hidden state: the rest of the combat is the same")
	assert_eq(StateHash.of_rt(sim), StateHash.of_rt(twin))


func test_queries_after_every_tick() -> void:
	var cmds: Array = RtKit.canned_commands()
	var a: RtSim = RtKit.canned_sim()
	var b: RtSim = RtKit.canned_sim()
	var ra: Dictionary = RtKit.play(a, cmds, 1800, _query_party)
	var rb: Dictionary = RtKit.play(b, cmds, 1800)
	assert_true(a.is_finished())
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "same end hash")
	assert_eq(_dicts(ra["events"]), _dicts(rb["events"]), "same events")


## Sets one field of `obj` to a different value of the same type (arrays and dictionaries in place).
static func _mutate(obj: Object, f: String) -> void:
	var v: Variant = obj.get(f)
	match typeof(v):
		TYPE_INT:
			obj.set(f, (int(v) + 1) % 3 if f == "driver" else int(v) + 1)
		TYPE_BOOL:
			obj.set(f, not bool(v))
		TYPE_STRING:
			obj.set(f, str(v) + "x")
		TYPE_FLOAT:
			obj.set(f, float(v) + 0.25)
		TYPE_ARRAY:
			var a: Array = v
			if a.is_typed() and a.get_typed_builtin() == TYPE_INT:
				a.append(7)
			elif a.is_typed() and a.get_typed_builtin() == TYPE_DICTIONARY:
				a.append({"x": 1})
			else:
				a.append("x")
		TYPE_PACKED_STRING_ARRAY:
			var p: PackedStringArray = v
			p.append("x")
			obj.set(f, p)
		TYPE_DICTIONARY:
			(v as Dictionary)["zz"] = 1


func test_snapshot_is_complete() -> void:
	var plain: Array = []
	for f: String in RtUnit._combatant_fields():
		if not f in ["display_name", "statuses", "stats", "ai", "phases", "drops", "boss_drops", "model", "pseudo_def"]:
			plain.append(f)
	assert_gt(plain.size(), 20)
	for f: String in plain + Array(RtUnit.RT_FIELDS):
		var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
		var h0: String = StateHash.of_rt(sim)
		_mutate(sim.unit("p1"), f)
		assert_ne(StateHash.of_rt(sim), h0, "unit field %s is hashed" % f)
	var s2: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	var h2: String = StateHash.of_rt(s2)
	s2.unit("e0").stats.values[StatBlock.Stat.DEF] += 1
	assert_ne(StateHash.of_rt(s2), h2, "stats")
	for f: String in ["ends_at", "period", "next_tick_at", "stacks", "applied_at", "amount", "source_id"]:
		var s3: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
		var st: RtStatus = RtSim.StatusFx.apply(s3, "p0", s3.unit("e0"), "sts_poison", 0, 1000)
		var h3: String = StateHash.of_rt(s3)
		_mutate(st, f)
		assert_ne(StateHash.of_rt(s3), h3, "status field %s is hashed" % f)


func test_combat_state_is_hashed() -> void:
	var changes: Dictionary = {
		"rng_n": func(s: RtSim) -> void: s.rng(),
		"items": func(s: RtSim) -> void: s.items["itm_bandage"] = 9,
		"item use": func(s: RtSim) -> void: s.use_up_item("itm_bandage"),
		"show cooldown": func(s: RtSim) -> void: s.start_show_cd(),
		"tally": func(s: RtSim) -> void: s.tally["crits"] = 5,
		"combo": func(s: RtSim) -> void: s.combo["e0"] = ["p0", 0],
		"combo_ready": func(s: RtSim) -> void: s.combo_ready = 10,
		"fled": func(s: RtSim) -> void: s.fled = true,
		"queued command": func(s: RtSim) -> void: s.submit(RtCommand.target(5, "p0", "e0")),
		"pending hit": func(s: RtSim) -> void: s.add_hit({"at": 9, "src": "p0", "skill": "skl_attack_kai", "item": "",
			"targets": ["e0"], "primary": "e0", "kind": 0, "ai": false, "cmd": 0}),
		"control": func(s: RtSim) -> void: s.control_follows_life(s.unit("p0")),
		"tick": func(s: RtSim) -> void: s.step(),
	}
	for k: String in changes:
		var sim: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
		var h0: String = StateHash.of_rt(sim)
		(changes[k] as Callable).call(sim)
		assert_ne(StateHash.of_rt(sim), h0, k)
	var a: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	var b: RtSim = RtKit.sim(RtKit.dummy_cmd(), 6)
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "the same start, the same hash")
	for u: RtUnit in b.units():
		u.display_name = "Persona " + u.id
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "display names are presentation")
	assert_eq(b.submit(RtCommand.ability(0, "p0", "skl_mop_noble_flame", "e0")), "not_learned")
	assert_eq(StateHash.of_rt(a), StateHash.of_rt(b), "a refused submit leaves no trace")


func test_setup_to_dict_is_canonical() -> void:
	var s: RtSetup = RtKit.setup(RtKit.canned_state(), RtKit.canned_encounter())
	var d: Dictionary = s.to_dict()
	assert_ne(CanonicalJson.sha256_hex(d), "", "canonical JSON: " + CanonicalJson.last_error)
	assert_eq(CanonicalJson.sha256_hex(d), CanonicalJson.sha256_hex(RtKit.setup(RtKit.canned_state(),
		RtKit.canned_encounter()).to_dict()), "the same command, the same setup")
	for k: String in ["cell", "room_kind", "geo", "units", "groups", "controlled_id", "presets", "auto_attack",
			"auto_retarget", "rt_opener", "mods", "rules", "difficulty", "tutorial_steps", "seed", "encounter_id"]:
		assert_true(d.has(k), k)
	assert_eq((d["units"] as Array).size(), 6)
	var sim: RtSim = RtSim.new(s, RtKit.data())
	sim.start()
	for _i in 60:
		sim.step()
	assert_eq(CanonicalJson.sha256_hex(s.to_dict()), CanonicalJson.sha256_hex(d), "the sim never changes its setup")
