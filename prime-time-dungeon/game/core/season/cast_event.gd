class_name CastEvent extends RefCounted
## One event of the AI cast (09 §4.6: descent, first ascent, death, rescue, out, leaving, Etagenboss, finale, record),
## stamped with the cast time `t` (seconds since day 0 of the season, the Sendepause left out — CastSim.now). The model
## (CastSim) writes the newsworthy ones (importance() ≥ TICKER_MIN) into the ticker of the season block and hands them
## out as explore events SEASON {"kind": "cast", …}; M.O.D. turns them into breaking news (tags cast_<kind>, Game: at
## most one per ten minutes of play, never in a combat, the important ones first). Pure data with a compact text form
## (the season block stores the ticker as one string, so the state hash stays cheap).
##
## Kinds — `who` is a place (0 .. humans − 1 a human, the rest the AI), `at` a floor, `n` / `m` counts:
##   descend {who, at: the new floor} · first {who, at} (the first candidate up the stairs onto floor `at` ≥ 2) ·
##   death {who, at} (Mit Netz from floor 2: the medics) · rescue {who, at: the collapsed floor, n: 1 = the dress
##   rehearsal} · out {who, at, n: OUT_FALLEN | OUT_BURIED} (Ohne Netz from floor 2) · leave {who} (a human left, the
##   AI plays the place on: "übernommen") · fboss {who, at, n: 1 = the first on that floor} · finale {who, at, n: the
##   number of the finalist} · record {who} (a new leader of the AI cast) · collapse {at, n: rescued, m: out} · end
##   {who, at} ("Bis zum Ende dabei") · hired {who, n: fights} · help {who} · helped {who, n: followers} · guest_end
##   {who}

const KINDS: PackedStringArray = ["descend", "first", "death", "rescue", "out", "leave", "fboss", "finale", "record",
	"collapse", "end", "hired", "help", "helped", "guest_end"]
## The breaking-news rank of a kind ("wichtige zuerst", 09 §4.6); 0 = never news. fboss and finale depend on `n`
## (importance()).
const IMPORTANCE: Dictionary = {"descend": 0, "first": 8, "death": 0, "rescue": 0, "out": 7, "leave": 5,
	"fboss": 5, "finale": 9, "record": 6, "collapse": 4, "end": 0, "hired": 0, "help": 0, "helped": 0, "guest_end": 0}
## Events from this importance on go into the ticker (09 §4.6: the ticker of the last 24 h; the routine ones stay out).
const TICKER_MIN: int = 2
const OUT_FALLEN: int = 1
const OUT_BURIED: int = 2

var seq: int = 0          # running number in the season (CastSim assigns it in time order)
var t: int = 0            # cast seconds since day 0 (CastSim.now; negative in the Vorprogramm)
var kind: String = ""
var who: int = -1
var at: int = 0
var n: int = 0
var m: int = 0


static func make(p_t: int, p_kind: String, p_who: int, p_at: int, p_n: int = 0, p_m: int = 0) -> CastEvent:
	var e: CastEvent = CastEvent.new()
	e.t = p_t
	e.kind = p_kind
	e.who = p_who
	e.at = p_at
	e.n = p_n
	e.m = p_m
	return e


## The breaking-news rank: IMPORTANCE of the kind — the first finalist 9, every later one 3; the first Etagenboss of
## a floor 5, every later one 0 (09 §4.6: wichtige zuerst).
func importance() -> int:
	match kind:
		"finale":
			return 9 if n <= 1 else 3
		"fboss":
			return 5 if n == 1 else 0
	return int(IMPORTANCE.get(kind, 0))


## "seq,t,kind,who,at,n,m" (the ticker's text form).
func to_text() -> String:
	return "%d,%d,%s,%d,%d,%d,%d" % [seq, t, kind, who, at, n, m]


## The text form back (null for a malformed one or an unknown kind).
static func from_text(s: String) -> CastEvent:
	var p: PackedStringArray = s.split(",")
	if p.size() != 7 or not KINDS.has(p[2]):
		return null
	for i: int in [0, 1, 3, 4, 5, 6]:
		if not p[i].is_valid_int():
			return null
	var e: CastEvent = make(p[1].to_int(), p[2], p[3].to_int(), p[4].to_int(), p[5].to_int(), p[6].to_int())
	e.seq = p[0].to_int()
	return e


## The explore event: SEASON {"kind": "cast", "ev", "seq", "t", "who", "floor", "n", "m"} (RunSim stamps the tick).
func to_explore() -> ExploreEvent:
	return ExploreEvent.make(ExploreEvent.Type.SEASON, 0, {"kind": "cast", "ev": kind, "seq": seq, "t": t, "who": who,
		"floor": at, "n": n, "m": m})


## Time order of the ticker: earlier first, then the place, the kind's position, the floor, the counts — a total order
## (two collapses Am Stück can share their time), so the numbering never depends on the order of the batch.
static func before(a: CastEvent, b: CastEvent) -> bool:
	if a.t != b.t:
		return a.t < b.t
	if a.who != b.who:
		return a.who < b.who
	if a.kind != b.kind:
		return KINDS.find(a.kind) < KINDS.find(b.kind)
	if a.at != b.at:
		return a.at < b.at
	return a.n < b.n if a.n != b.n else a.m < b.m
