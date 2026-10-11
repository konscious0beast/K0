extends TestCase
## 07 §3.14, §10.4, §12.5 (R1b-I1 … I3) test_r1_rt_golden: the canned combat (RtKit.canned_*: Kai level 6, two groups —
## two rats, a rat and the test caster — and ~200 scripted commands) ends with fixed golden values: StateHash.of_rt,
## the number of events, a digest of the event stream, the ticks played and the accepted commands. Two runs are
## identical; replaying only the accepted commands — also through a JSON round trip (every number a float, like a
## parsed log) — gives the same hash and the same events.
##
## Updating the golden values — deliberately, never to turn a red test green by accident: every change of the sim's
## behaviour, of the rt_min fixture or of the canned commands moves them (R1b-I2 did: AI rules; I3 did: enemy rules,
## telegraphs, staggered thinking). Run `tools/check.sh --tests-only --filter=r1_rt_golden`; the failure prints the
## current values ("golden now: {…}"). Check that the difference is the intended one (the other tests of the change
## must say why), paste the values into GOLDEN and give the reason in the commit message (07 §12.5: "geänderte
## Golden-Werte nur mit Begründung im Commit").

## R1b-I2: the AI partner Mopsula and Kai's autopilot phase (ticks 250–400) play the rule lists of 07 §5.4.
## R1b-I3: the enemies play their rt.rules from first_ms + slot × AI_SLOT_OFFSET_TICKS (the rats' bites at 91 / 99 /
## 110, the caster's hex every 8 s and its slam as a telegraph — 3 TELEGRAPH_START / IMPACT, 2 dodges, 1 telegraph
## hit), every AI-driven unit thinks every AI_THINK_TICKS (07 §3.15); still a won fight in 816 ticks (372 → 426 events).
const GOLDEN: Dictionary = {
	"hash": "e64961ae297687b7e0759b098adafce82f4af55ef261afb76e8f79333714a720",
	"events": 426,
	"stream": "17ce399966807c599c8333ec3c3d85e2b5d9399ea6681ffab7a532d9e00a3bcc",
	"ticks": 816,
	"accepted": 183,
}
const MAX_TICKS: int = 1800


func _run(cmds: Array = []) -> Dictionary:
	var sim: RtSim = RtKit.canned_sim()
	var r: Dictionary = RtKit.play(sim, cmds if not cmds.is_empty() else RtKit.canned_commands(), MAX_TICKS)
	r["sim"] = sim
	return r


static func _dicts(events: Array) -> Array:
	var out: Array = []
	for e: ActionEvent in events:
		out.append(e.to_dict())
	return out


static func _values(run: Dictionary) -> Dictionary:
	var sim: RtSim = run["sim"]
	return {"hash": StateHash.of_rt(sim), "events": (run["events"] as Array).size(),
		"stream": CanonicalJson.sha256_hex(_dicts(run["events"])), "ticks": sim.tick(),
		"accepted": (run["accepted"] as Array).size()}


func test_golden_values() -> void:
	var run: Dictionary = _run()
	var got: Dictionary = _values(run)
	assert_eq(got, GOLDEN, "golden now: %s" % JSON.stringify(got))
	var sim: RtSim = run["sim"]
	assert_true(sim.is_finished() and sim.result.outcome == BattleResult.Outcome.VICTORY and sim.result.kills == 4,
		"the canned combat is a won fight")
	assert_eq(run["answers"], {"": GOLDEN["accepted"], "finished": RtKit.canned_commands().size() - GOLDEN["accepted"]})


func test_two_runs_are_identical() -> void:
	var a: Dictionary = _run()
	var b: Dictionary = _run()
	assert_eq(_values(a), _values(b))
	assert_eq(_dicts(a["events"]), _dicts(b["events"]))
	assert_eq((a["sim"] as RtSim).snapshot(), (b["sim"] as RtSim).snapshot())


func test_replay_of_the_accepted_commands() -> void:
	var a: Dictionary = _run()
	var accepted: Array = a["accepted"]
	var replay: Dictionary = _run(accepted)
	assert_eq(replay["answers"], {"": accepted.size()}, "every recorded command is accepted again")
	assert_eq(_values(replay), _values(a))
	var parsed: Variant = JSON.parse_string(JSON.stringify(accepted))
	assert_true(parsed is Array and typeof((parsed as Array)[0]["ct"]) == TYPE_FLOAT, "a parsed log: floats")
	var json: Dictionary = _run(parsed as Array)
	assert_eq(json["answers"], {"": accepted.size()})
	assert_eq(_values(json), _values(a), "the JSON round trip changes nothing")
