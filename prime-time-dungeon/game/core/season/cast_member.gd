class_name CastMember extends RefCounted
## One place of the cast (09 §4.2): its roster — name and word form from the name catalog of data/cast.json, profile,
## skill, pace, Vorleben and hobby from the 08 catalog, the hour of its daily session — and its state in the
## population model: floor, work on the floor, level, flags (vest, out, finalist, end, übernommen …), counters, times
## (cast seconds since day 0, CastSim.now) and species and class from the Recall. Places 0 .. humans − 1 are the
## humans of the season (F_HUMAN: the model does not play them) until the AI takes one over (F_TAKEN, "übernommen",
## 09 §2.2). Pure data with the compact text form of the season block (one string per place: the state hash stays
## cheap); the rules are CastSim's.

const F_VEST: int = 1          # weiße Weste: never rescued, never died (from floor 2 on, 09 §2.3)
const F_OUT: int = 2           # Ohne Netz: out (F_BURIED: by a collapse, else fallen)
const F_FINAL: int = 4         # the Große Finale won
const F_ENDED: int = 8         # "Bis zum Ende dabei": the last collapse (Am Stück: the candidate's season ended)
const F_TAKEN: int = 16        # "übernommen": a human's place played on by the AI (skill 55, 09 §4.2)
const F_HELPED: int = 32       # the Pechvogel remembers the help (09 §4.4)
const F_QBOSS: int = 64        # the Revier-Boss of the finale floor counted (once)
const F_HUMAN: int = 128       # a human place — the model does not play it
const F_BURIED: int = 256      # out by a collapse ("verschüttet"); without it "gefallen"
## A place the model does not move any more.
const F_DONE: int = F_OUT | F_FINAL | F_ENDED | F_HUMAN
const ROSTER_SEP: String = "|"
const STATE_FIELDS: int = 16
## "No time yet": times are cast seconds since day 0 and negative in the Vorprogramm, so -1 is a real time.
const NO_TIME: int = -(1 << 30)

# --- the roster (fixed at the start of the season) -----------------------------------------------------------------
var place: int = 0
var name: String = ""
var form: String = "n"         # word form of the name catalog: f | m | n (the job title of the Vorleben, 08 §3)
var profile: String = "extra"  # cast.json profile: extra | rival | helper | trader | unlucky
var skill: int = 55            # Können 20–95 (09 §4.2)
var pace: int = 10             # Tempo in tenths of play hours per day (3–30 = 0.3–3.0 h)
var org: String = ""           # Vorleben (origins.json, org_)
var hob: String = ""           # hobby (origins.json → hobbies, hob_)
var sess: int = 0              # the daily session starts this many hours after the air time (0–23)
# --- the state -------------------------------------------------------------------------------------------------------
var fl: int = 1                # the floor
var wk: int = 0                # work done on the floor (‰-minutes: the floor needs CastSim work × 1000)
var lv: int = 1                # Stufe (follows the band of the floor, 09 §2.4)
var fx: int = F_VEST           # flags (F_*)
var rs: int = 0                # rescues from floor 2 on (the Quote)
var dt: int = 0                # deaths from floor 2 on (the Quote)
var st: int = 0                # floors left by the stairs (the Quote)
var qb: int = 0                # Revier-Bosse (the Quote)
var fb: int = 0                # Etagenbosse incl. the finale (the Quote)
var t: int = 0                 # the next hour the model plays (hours since day 0)
var ar: int = 0                # arrival on the current floor (cast seconds)
var ds: int = NO_TIME          # the last descent by the stairs (cast seconds; tie-break of the ranking)
var fa: int = NO_TIME          # the finale won (cast seconds; tie-break of the ranking)
var rf: int = 0                # the floor of the result (out, finale, end)
var sp: String = ""            # species from the Recall (floor 3; "" before)
var cl: String = ""            # class from the Recall
# --- derived, never stored (CastSim's model sets them when it reads or draws the place) ------------------------------
var base: int = 0              # SeedUtil.derive(season seed, "cast", place): the roll stream of the place
var per_day: int = 60          # minutes played a day (pace × 6)
var risk: int = 1000           # ‰ of the death chance of skill 55
var eff: int = 1000            # ‰ of the Pflichtweg per played minute before floor and mode
var rival: bool = false        # profile "rival" (keeps close to the candidate)


func has(flag: int) -> bool:
	return fx & flag != 0


## The model plays this place now (an AI place — or one taken over — that is neither out, finished nor at its end).
func in_play() -> bool:
	return fx & F_DONE == 0


## An AI place (also a human's place taken over by the AI).
func is_ai() -> bool:
	return fx & F_HUMAN == 0


## Out of the season (Ohne Netz: fallen or buried).
func is_out() -> bool:
	return fx & F_OUT != 0


## "name|form|profile|skill|pace|org|hob|sess" (human places: "").
func roster_text() -> String:
	if fx & F_HUMAN != 0 and fx & F_TAKEN == 0:
		return ""
	return ROSTER_SEP.join(PackedStringArray([name, form, profile, str(skill), str(pace), org, hob, str(sess)]))


## "fl,wk,lv,fx,rs,dt,st,qb,fb,t,ar,ds,fa,rf,sp,cl".
func state_text() -> String:
	return "%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%s" % [fl, wk, lv, fx, rs, dt, st, qb, fb, t, ar, ds, fa,
		rf, sp, cl]


## A place from its two texts; a malformed roster leaves the defaults (a human place), a malformed state as well.
static func from_texts(p_place: int, roster: String, state: String) -> CastMember:
	var mb: CastMember = CastMember.new()
	mb.place = p_place
	var r: PackedStringArray = roster.split(ROSTER_SEP)
	if r.size() == 8:
		mb.name = r[0]
		mb.form = r[1]
		mb.profile = r[2]
		mb.skill = r[3].to_int()
		mb.pace = r[4].to_int()
		mb.org = r[5]
		mb.hob = r[6]
		mb.sess = r[7].to_int()
	var s: PackedStringArray = state.split(",")
	if s.size() == STATE_FIELDS:
		var v: PackedInt64Array = []
		for i in 14:
			v.append(s[i].to_int())
		mb.fl = int(v[0])
		mb.wk = int(v[1])
		mb.lv = int(v[2])
		mb.fx = int(v[3])
		mb.rs = int(v[4])
		mb.dt = int(v[5])
		mb.st = int(v[6])
		mb.qb = int(v[7])
		mb.fb = int(v[8])
		mb.t = int(v[9])
		mb.ar = int(v[10])
		mb.ds = int(v[11])
		mb.fa = int(v[12])
		mb.rf = int(v[13])
		mb.sp = s[14]
		mb.cl = s[15]
	return mb
