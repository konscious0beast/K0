class_name SdEvent extends RefCounted
## One event of a Stempelduell (10 §6.5 Nr. 6). The presentation only plays events (Brief §6b.2) and reads the duel's
## state afterwards. ENGINE wraps an ActionEvent of the CTB engine (DAMAGE, STATUS_ADDED, CTB_ORDER, TURN_START …);
## the card events are the duel's own:
##   CARD_PLAYED     side, slot (hand slot before the play), card_id
##   CARD_FILED      side, slot, card_id (the filed card lies open on the discard pile)
##   CARD_DRAWN      side, slot (new hand slot), card_id ("" on the opponent's side: its hand is hidden)
##   RESHUFFLED      side, value = cards in the new pile ("Die Ablage wird neu sortiert")
##   HAND_REFRESHED  side, value = cards put onto the discard pile (Umlaufmappe; the draws follow as CARD_DRAWN)
##   DUEL_END        value = SdDuel.Result
## `side` is an SdDuel.Side value (-1 for ENGINE and DUEL_END).

enum Kind { ENGINE, CARD_PLAYED, CARD_FILED, CARD_DRAWN, RESHUFFLED, HAND_REFRESHED, DUEL_END }

var kind: SdEvent.Kind = Kind.ENGINE
var side: int = -1
var slot: int = -1
var card_id: String = ""
var value: int = 0
var engine: ActionEvent = null


static func make(p_kind: SdEvent.Kind, p_side: int = -1, p_slot: int = -1, p_card: String = "",
		p_value: int = 0) -> SdEvent:
	var e: SdEvent = SdEvent.new()
	e.kind = p_kind
	e.side = p_side
	e.slot = p_slot
	e.card_id = p_card
	e.value = p_value
	return e


static func wrap(ev: ActionEvent) -> SdEvent:
	var e: SdEvent = SdEvent.new()
	e.kind = Kind.ENGINE
	e.engine = ev
	return e


static func kind_name(k: SdEvent.Kind) -> String:
	var names: Array = Kind.keys()
	var i: int = int(k)
	return str(names[i]) if i >= 0 and i < names.size() else ""


## {"kind": "CARD_PLAYED", …} with the non-default fields; ENGINE events carry "engine": ActionEvent.to_dict().
func to_dict() -> Dictionary:
	var d: Dictionary = {"kind": kind_name(kind)}
	if side != -1:
		d["side"] = side
	if slot != -1:
		d["slot"] = slot
	if card_id != "":
		d["card"] = card_id
	if value != 0:
		d["value"] = value
	if engine != null:
		d["engine"] = engine.to_dict()
	return d


## Inverse of to_dict (unknown kind → null).
static func from_dict(d: Dictionary) -> SdEvent:
	var idx: int = Kind.keys().find(str(d.get("kind", "")))
	if idx < 0:
		return null
	var e: SdEvent = make(idx as SdEvent.Kind, JsonUtil.to_int(d.get("side", -1), -1),
		JsonUtil.to_int(d.get("slot", -1), -1), str(d.get("card", "")), JsonUtil.to_int(d.get("value", 0)))
	var ev: Variant = d.get("engine", null)
	if ev is Dictionary:
		e.engine = ActionEvent.from_dict(ev)
	return e


## The engine event type, or -1 for the duel's own events.
func engine_type() -> int:
	return int(engine.type) if engine != null else -1
