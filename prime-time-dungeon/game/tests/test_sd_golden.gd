extends TestCase
## 10 §6.9 test_sd_golden (SD2-B): one fixed duel of 41 moves — Ulla against a Mappe with show cards, time cards and
## Rohrpost — with a scripted player (one entry per own number: the moves the Graf's hint chose when the golden was
## recorded, now fixed data) and the opponent's EnemyAI. On its way: filing, a reshuffle, the Umlaufmappe, a show card,
## heals, Ulla's immunity and her Leinen-Fallstrick cancelling the player's Eilvermerk. It ends with a frozen
## SdDuel.state_hash, event count, digest of the event stream, result (Ulla wins it) and number of moves; two runs are
## identical and the SdLog replays it through JSON.
##
## A change of the rulebook's mechanics, the duel adapter or the frozen engine moves these values: then it needs a
## reason and an SD_VERSION step (10 §6.6). Updating — deliberately, never to turn a red test green by accident: run
## `tools/check.sh --tests-only --filter=sd_golden`; the failure prints the current values ("golden now: …"); paste
## them into GOLDEN and give the reason in the commit message.

const Sx := preload("res://tests/test_sd_fixture.gd")
const SEED: int = 424
const OPPONENT: String = "sdo_ulla"
const DECK: Dictionary = {"sdc_stereo": 2, "sdc_kabelpeitsche": 2, "sdc_leinen": 2, "sdc_formular_27b": 2,
	"sdc_ablehnung": 2, "sdc_wuchtschlag": 2, "sdc_gutachten": 2, "sdc_schlabbern": 2, "sdc_kleingedrucktes": 1,
	"sdc_umlaufmappe": 1, "sdc_suplex": 1, "sdc_auftritt": 1}
## The player's moves, one per own number (cycled if a changed rule ever needs more).
const SCRIPT: Array = [["play", 2], ["play", 2], ["play", 0], ["play", 2], ["play", 2], ["play", 4], ["play", 4],
	["play", 2], ["play", 4], ["play", 4], ["play", 4], ["file", 3], ["play", 0], ["play", 0], ["play", 2], ["play", 3],
	["play", 3], ["play", 4]]
## SD2 (2026-10-12), SD_VERSION 1: frozen when the golden duel was recorded (see the test header).
const GOLDEN: Dictionary = {"hash": "f8da1c05ac65d05ecd8b68528e11806235f094f97f0774a90613fa164af80241", "events": 340,
	"stream": "f445f1e9a768632495aa518354ff00743735d559421c955906602fc2f630a1f8", "result": "lost", "moves": 41}


func _run() -> Dictionary:
	var b: SdRulebook = Sx.book()
	var setup: SdSetup = SdSetup.create(b, OPPONENT, Sx.deck_of(DECK), SEED)
	var d: SdDuel = SdDuel.new(setup, b)
	var l: SdLog = SdLog.begin(setup)
	var events: Array[SdEvent] = d.start()
	var k: int = 0
	var guard: int = 0
	while not d.is_finished() and guard < 400:
		guard += 1
		if d.side_to_move() == SdDuel.Side.PLAYER:
			var row: Array = SCRIPT[k % SCRIPT.size()]
			var m: Dictionary = {"op": str(row[0]), "slot": int(row[1])}
			k += 1
			l.add(m)
			events.append_array(d.submit(m))
		else:
			events.append_array(d.submit(d.opponent_move()))
	l.finish(d)
	return {"duel": d, "events": events, "log": l}


static func _values(run: Dictionary) -> Dictionary:
	var d: SdDuel = run["duel"]
	return {"hash": d.state_hash(), "events": (run["events"] as Array).size(),
		"stream": CanonicalJson.sha256_hex(Sx.dicts(run["events"])), "result": SdDuel.RESULT_NAMES[int(d.result)],
		"moves": d.moves}


func test_golden_values() -> void:
	var run: Dictionary = _run()
	var d: SdDuel = run["duel"]
	assert_true(d.is_finished(), "the golden duel ends")
	assert_between(d.moves, 36, 46, "≈ 40 moves")
	var got: Dictionary = _values(run)
	assert_eq(got, GOLDEN, "golden now: %s" % JSON.stringify(got))


func test_two_runs_are_identical() -> void:
	var a: Dictionary = _run()
	var b: Dictionary = _run()
	assert_eq(_values(a), _values(b))
	assert_eq(Sx.dicts(a["events"]), Sx.dicts(b["events"]))
	assert_eq((a["duel"] as SdDuel).to_dict(), (b["duel"] as SdDuel).to_dict())


func test_the_log_replays_through_json() -> void:
	var a: Dictionary = _run()
	var parsed: Variant = JSON.parse_string(JSON.stringify((a["log"] as SdLog).to_dict()))
	var rep: Dictionary = SdLog.from_dict(parsed as Dictionary).replay(Sx.book())
	assert_eq([rep["ok"], rep["hash"], rep["result"]], [true, (a["duel"] as SdDuel).state_hash(),
		SdDuel.RESULT_NAMES[int((a["duel"] as SdDuel).result)]], str(rep["error"]))
	var seen: Dictionary = {}
	for e: SdEvent in a["events"]:
		seen[SdEvent.kind_name(e.kind)] = true
		if e.engine != null:
			seen[ActionEvent.type_name(e.engine.type)] = true
	for k: String in ["CARD_PLAYED", "CARD_FILED", "CARD_DRAWN", "RESHUFFLED", "HAND_REFRESHED", "DUEL_END",
			"STUNT_RESULT", "STATUS_ADDED", "STATUS_REMOVED", "HEAL"]:
		assert_true(seen.has(k), "the golden duel covers %s" % k)
