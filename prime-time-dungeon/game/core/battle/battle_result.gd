class_name BattleResult extends RefCounted
## Battle outcome (02_TECH §5.4). Built by BattleState when the battle ends.

const FixedMath := preload("res://core/stats/fixed_math.gd")

enum Outcome { VICTORY, DEFEAT, FLED }
const OUTCOME_NAMES: PackedStringArray = ["victory", "defeat", "fled"]

var outcome: BattleResult.Outcome = Outcome.VICTORY
var encounter_id: String = ""
var group_id: String = ""
var is_boss: bool = false
var boss_id: String = ""               # EnemyDef id of the boss ("" otherwise)
var advantage: int = 0                 # BattleSetup.Advantage
var turns: int = 0                     # number of TURN_START events (all units)
var party_turns: int = 0               # TURN_START of party members
var exp: int = 0                       # sum of exp_reward of defeated non-summoned enemies × exp_mult (VICTORY only)
var credits: int = 0                   # sum of credit_reward (incl. overkill bonus)
var overkill_credits: int = 0          # part of credits that came from overkill × 1.25
var credits_stolen: int = 0            # stolen credits the enemies KEEP (escaped or surviving thieves; every thief
                                       # unless VICTORY) — BattleBridge always deducts them (GDD §3.11)
var credits_refunded: int = 0          # stolen credits given back: VICTORY + refund_on_win + thief KO'd
var credits_delta: int = 0             # gift credits (05 CR-2)
var drops: PackedStringArray = []      # item ids rolled with battle rng at victory
var boss_rewards: Array[Dictionary] = []   # EnemyDef.boss_drops of defeated bosses ({kind, id, amount})
var party_hp: Dictionary = {}          # member def id -> int (final, KO = 0)
var party_mp: Dictionary = {}
var item_delta: Dictionary = {}        # item id -> int (negative used, positive gifts)
var kills: int = 0
var defeated_ids: PackedStringArray = []   # EnemyDef ids of defeated enemies (bestiary)
var weak_found: Dictionary = {}        # EnemyDef id -> PackedStringArray of elements that hit "weak"
var escaped: PackedStringArray = []    # EnemyDef ids that used escape
var damage_taken: int = 0              # total damage to party
var min_party_hp: int = 0              # at battle end: lowest hp among living party members
var min_party_hp_pct: float = 1.0      # at battle end: lowest hp ratio among living party members
var crits: int = 0                     # party crits
var weakness_hits: int = 0             # party hits on weak
var items_used: int = 0
var party_kos: int = 0


func outcome_name() -> String:
	return OUTCOME_NAMES[int(outcome)]


## All fields (JSON-compatible; Packed arrays as Arrays). `min_party_hp_pct` stays a float here; BattleState snapshots
## store it as ppm (canonical JSON, 05 §3.3 Nr. 9).
func to_dict() -> Dictionary:
	var wf: Dictionary = {}
	for k: String in _sorted_keys(weak_found):
		wf[k] = Array(JsonUtil.to_str_array(weak_found[k]))
	var rewards: Array = []
	for r: Dictionary in boss_rewards:
		rewards.append(r.duplicate(true))
	return {
		"outcome": int(outcome), "encounter_id": encounter_id, "group_id": group_id, "is_boss": is_boss,
		"boss_id": boss_id, "advantage": advantage, "turns": turns, "party_turns": party_turns, "exp": exp,
		"credits": credits, "overkill_credits": overkill_credits, "credits_stolen": credits_stolen,
		"credits_refunded": credits_refunded, "credits_delta": credits_delta, "drops": Array(drops),
		"boss_rewards": rewards,
		"party_hp": party_hp.duplicate(true), "party_mp": party_mp.duplicate(true),
		"item_delta": item_delta.duplicate(true), "kills": kills, "defeated_ids": Array(defeated_ids),
		"weak_found": wf, "escaped": Array(escaped), "damage_taken": damage_taken, "min_party_hp": min_party_hp,
		"min_party_hp_pct": min_party_hp_pct, "crits": crits, "weakness_hits": weakness_hits,
		"items_used": items_used, "party_kos": party_kos,
	}


## Inverse of to_dict (also accepts "min_party_hp_pct_ppm" from BattleState snapshots and JSON floats for ints).
static func from_dict(d: Dictionary) -> BattleResult:
	var r: BattleResult = BattleResult.new()
	r.outcome = clampi(JsonUtil.to_int(d.get("outcome", 0)), 0, OUTCOME_NAMES.size() - 1) as BattleResult.Outcome
	r.encounter_id = str(d.get("encounter_id", ""))
	r.group_id = str(d.get("group_id", ""))
	r.is_boss = bool(d.get("is_boss", false))
	r.boss_id = str(d.get("boss_id", ""))
	r.advantage = JsonUtil.to_int(d.get("advantage", 0))
	r.turns = JsonUtil.to_int(d.get("turns", 0))
	r.party_turns = JsonUtil.to_int(d.get("party_turns", 0))
	r.exp = JsonUtil.to_int(d.get("exp", 0))
	r.credits = JsonUtil.to_int(d.get("credits", 0))
	r.overkill_credits = JsonUtil.to_int(d.get("overkill_credits", 0))
	r.credits_stolen = JsonUtil.to_int(d.get("credits_stolen", 0))
	r.credits_refunded = JsonUtil.to_int(d.get("credits_refunded", 0))
	r.credits_delta = JsonUtil.to_int(d.get("credits_delta", 0))
	r.drops = JsonUtil.to_str_array(d.get("drops", []))
	for v: Variant in (d.get("boss_rewards", []) as Array):
		if v is Dictionary:
			var src: Dictionary = v
			r.boss_rewards.append({"kind": str(src.get("kind", "")), "id": str(src.get("id", "")),
				"amount": JsonUtil.to_int(src.get("amount", 1), 1)})
	r.party_hp = _int_dict(d.get("party_hp", {}))
	r.party_mp = _int_dict(d.get("party_mp", {}))
	r.item_delta = _int_dict(d.get("item_delta", {}))
	r.kills = JsonUtil.to_int(d.get("kills", 0))
	r.defeated_ids = JsonUtil.to_str_array(d.get("defeated_ids", []))
	var wf: Variant = d.get("weak_found", {})
	if wf is Dictionary:
		for k: Variant in (wf as Dictionary).keys():
			r.weak_found[str(k)] = JsonUtil.to_str_array((wf as Dictionary)[k])
	r.escaped = JsonUtil.to_str_array(d.get("escaped", []))
	r.damage_taken = JsonUtil.to_int(d.get("damage_taken", 0))
	r.min_party_hp = JsonUtil.to_int(d.get("min_party_hp", 0))
	if d.has("min_party_hp_pct_ppm"):
		r.min_party_hp_pct = FixedMath.from_ppm(JsonUtil.to_int(d["min_party_hp_pct_ppm"]))
	else:
		r.min_party_hp_pct = JsonUtil.to_float(d.get("min_party_hp_pct", 1.0), 1.0)
	r.crits = JsonUtil.to_int(d.get("crits", 0))
	r.weakness_hits = JsonUtil.to_int(d.get("weakness_hits", 0))
	r.items_used = JsonUtil.to_int(d.get("items_used", 0))
	r.party_kos = JsonUtil.to_int(d.get("party_kos", 0))
	return r


static func _int_dict(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		var src: Dictionary = v
		for k: Variant in src.keys():
			out[str(k)] = JsonUtil.to_int(src[k])
	return out


static func _sorted_keys(d: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = []
	for k: Variant in d.keys():
		keys.append(str(k))
	keys.sort()
	return keys
