# STUB(R1a) — owned by R1b. Replace completely, keep the public API.
class_name RtStatus extends StatusEffect
## Real-time status (07 §3.4, §3.8): ends at a tick, optional period, stacks, frozen tick amount. The CTB fields
## turns_left / fresh stay 0 / false.

var ends_at: int = -1                       # ct of expiry (-1 = until combat end)
var period: int = 0                         # ticks between periodic effects (0 = none)
var next_tick_at: int = -1                  # phase is kept on refresh (§3.8)
var stacks: int = 1
var applied_at: int = 0
var amount: int = 0                         # tick_power statuses: damage per tick and stack, frozen at application


func _init(p_def: StatusDef = null, p_ends_at: int = -1, p_source_id: String = "") -> void:
	super(p_def, 0, p_source_id)
	ends_at = p_ends_at


## A copy with every real-time field (Combatant.duplicate_combatant keeps the RtStatus type).
func duplicate_effect() -> StatusEffect:
	var s: RtStatus = RtStatus.new(def, ends_at, source_id)
	s.period = period
	s.next_tick_at = next_tick_at
	s.stacks = stacks
	s.applied_at = applied_at
	s.amount = amount
	return s


## {"id", "source_id", "ends_at", "period", "next_tick_at", "stacks", "applied_at", "amount"} (07 §3.4).
func to_dict() -> Dictionary:
	return {"id": id(), "source_id": source_id, "ends_at": ends_at, "period": period, "next_tick_at": next_tick_at,
		"stacks": stacks, "applied_at": applied_at, "amount": amount}


## Inverse of to_dict; unknown status id → null (like StatusEffect.from_dict).
static func from_rt_dict(d: Dictionary, data: GameData) -> RtStatus:
	var sid: String = str(d.get("id", ""))
	if data == null or not data.has_id("statuses", sid):
		push_warning("RtStatus.from_rt_dict: unknown status '%s'" % sid)
		return null
	var s: RtStatus = RtStatus.new(data.status(sid), JsonUtil.to_int(d.get("ends_at", -1), -1),
		str(d.get("source_id", "")))
	s.period = JsonUtil.to_int(d.get("period", 0))
	s.next_tick_at = JsonUtil.to_int(d.get("next_tick_at", -1), -1)
	s.stacks = JsonUtil.to_int(d.get("stacks", 1), 1)
	s.applied_at = JsonUtil.to_int(d.get("applied_at", 0))
	s.amount = JsonUtil.to_int(d.get("amount", 0))
	return s
