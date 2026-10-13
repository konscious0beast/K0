class_name Gift extends RefCounted
## THE gift format (05 §6.5, schema 1) for system, fan, bits, shop and dev gifts: validate, make_system, make_dev.
## Show.receive_gift() takes exactly this dictionary; GiftApplier (outside battles) and BattleState.apply_gift (in
## battle) apply it. No floats anywhere (effect factors are per mille, loads in half points; 05 §3.3 Nr. 9).
##
## validate() checks the schema only (types, required fields, value ranges, kind ↔ source and gold amounts of 05 §6.3,
## buyer pseudonym sender_ref of fan/shop/bits gifts, contents bounds (fan_pack: one common entry), paid chests with
## the server roll and its contents, league, signature format). Run-dependent rules (caps,
## duplicates, effect factor against the run's load, league of the run) are GiftPolicy.check() / Show / RunSim.
## Unknown additional fields are allowed (protocol minor versions are additive, 05 §4.3); they must still be
## canonically serializable. `last_detail` explains the last rejection (diagnostics only, never game logic).

const SCHEMA: int = 1
const SOURCES: PackedStringArray = ["system", "fan", "bits", "shop", "dev"]
const PAID_SOURCES: PackedStringArray = ["bits", "shop"]
const KINDS: PackedStringArray = ["sponsor_buff", "gold", "chest", "fan_pack", "cheer"]
const RANDOM_KINDS: PackedStringArray = ["chest", "fan_pack"]
## Sources each kind may come from (05 §6.3); "dev" (QA, debug builds) may send every kind. "bits" is reserved
## (decision 2026-10-08, L11: Bits only for free interaction, revenue only to the operator) — cosmetic "cheer" only,
## never a gift with game effect.
const KIND_SOURCES: Dictionary = {
	"sponsor_buff": ["system", "shop", "dev"],
	"gold": ["shop", "dev"],
	"chest": ["shop", "dev"],
	"fan_pack": ["fan", "dev"],
	"cheer": ["fan", "bits", "shop", "dev"],
}
## Sources whose gifts come from the gift service: they carry the buyer's pseudonym sender_ref = "b_" + 12 hex
## characters (05 §7.5) — the per-buyer caps (per_buyer_per_target, Sponsor-Fenster per_viewer) depend on it.
const BUYER_SOURCES: PackedStringArray = ["fan", "bits", "shop"]
## Bounds of every contents entry (05 §6.5): qty 1..MAX_CONTENT_QTY (max stack), credits 1..MAX_CONTENT_CREDITS (the
## largest pool entry is 600). A fan_pack carries no contents or exactly one "common" entry (05 §6.3: one common roll).
const MAX_CONTENT_QTY: int = 9
const MAX_CONTENT_CREDITS: int = 1000
## Credit amounts a gold gift may carry (05 §6.3: 100 or 250); dev gifts may carry any positive amount.
const GOLD_AMOUNTS: PackedInt32Array = [100, 250]
## Rolls of a chest tier at full effect (05 §6.6); paid chests carry rolls = GiftPolicy.rolls_for(base, effect_pm).
const CHEST_BASE_ROLLS: Dictionary = {"bronze": 2, "silver": 3, "gold": 4}
const TIERS: PackedStringArray = ["bronze", "silver", "gold"]
const LEAGUES: PackedStringArray = ["show", "pur"]
const RARITIES: PackedStringArray = ["common", "rare", "epic"]
const GUARANTEES: PackedStringArray = ["", "rare", "epic"]
const MAX_DISPLAY_NAME: int = 24
const MESSAGE_PREFIX: String = "gift_msg_"
const SIG_PREFIX: String = "hmac-sha256:"
const REQUIRED: PackedStringArray = ["schema", "gift_id", "source", "kind", "tier", "amount", "sponsor_id", "sender",
	"message_key", "target", "event_id", "window_id", "league", "effect_pm", "load_half", "run_bound",
	"deliver_by_tick", "issued_at"]
## Reason codes of Show.receive_gift (05 §6.5); window_* = Sponsor-Fenster (SponsorWindows, 05 §6.13).
## wrong_target: the gift names another run / player / event / window (05 §6.9 Lauf-Bindung); too_soon: less than
## rules.gifts.min_interval_sec since the last service delivery to this run (05 §6.10).
const REASONS: PackedStringArray = ["", "invalid_schema", "duplicate", "league_pur", "not_accepting", "cap_reached",
	"run_not_active", "effect_mismatch", "bad_signature", "chest_blocked", "deadline_missed", "window_closed",
	"window_full", "window_sender_limit", "wrong_target", "too_soon"]
## Optional field "sponsor_window": "" or the id of the Sponsor-Fenster the gift was accepted into ("sw_<n>", stamped by
## Show at acceptance / by the gift service at its reservation, 05 §6.4).
const SPONSOR_WINDOW_PREFIX: String = "sw_"

static var last_detail: String = ""
static var _dev_counter: int = 0          # roll nonce of dev chests / fan packs (independent of the gift id)
static var _crypto: Crypto = null
static var _hex16: RegEx = null
static var _hex64: RegEx = null
static var _log_id: RegEx = null
static var _sender_ref: RegEx = null


## Reason codes 05 §6.5, "" = valid. (invalid_schema | league_pur | bad_signature)
static func validate(g: Dictionary) -> String:
	last_detail = ""
	if CanonicalJson.stringify(g) == "" and CanonicalJson.last_error != "":
		return _bad("not canonical JSON: " + CanonicalJson.last_error)
	for key: String in REQUIRED:
		if not g.has(key):
			return _bad("missing field '%s'" % key)
	if not _is_int(g["schema"]) or int(g["schema"]) != SCHEMA:
		return _bad("schema must be %d" % SCHEMA)
	var gid: Variant = g["gift_id"]
	if not (gid is String) or not (gid as String).begins_with("g_") or (gid as String).length() < 3:
		return _bad("gift_id must be a String 'g_…'")
	var source: String = _str(g["source"])
	if not SOURCES.has(source):
		return _bad("unknown source '%s'" % source)
	var kind: String = _str(g["kind"])
	if not KINDS.has(kind):
		return _bad("unknown kind '%s'" % kind)
	var reason: String = _check_kind_fields(g, kind, source)
	if reason != "":
		return reason
	reason = _check_sender(g.get("sender"), source)
	if reason != "":
		return reason
	var msg: Variant = g["message_key"]
	if not (msg is String) or ((msg as String) != "" and not (msg as String).begins_with(MESSAGE_PREFIX)):
		return _bad("message_key must be '' or a predefined '%s*' key (no free text)" % MESSAGE_PREFIX)
	var target: Variant = g["target"]
	if not (target is Dictionary) or not ((target as Dictionary).get("player_id") is String) \
			or not ((target as Dictionary).get("run_id") is String):
		return _bad("target must be {player_id: String, run_id: String}")
	for key: String in ["event_id", "window_id", "issued_at"]:
		if not (g[key] is String):
			return _bad("%s must be a String" % key)
	var league: String = _str(g["league"])
	if not LEAGUES.has(league):
		return _bad("league must be show|pur")
	if not _is_int(g["effect_pm"]) or int(g["effect_pm"]) < 1 or int(g["effect_pm"]) > 1000:
		return _bad("effect_pm must be an int 1..1000")
	if not _is_int(g["load_half"]) or int(g["load_half"]) < 0:
		return _bad("load_half must be an int >= 0")
	if source == "system" and (int(g["effect_pm"]) != 1000 or int(g["load_half"]) != 0):
		return _bad("system gifts have effect_pm 1000 and load_half 0")
	if not (g["run_bound"] is bool) or not bool(g["run_bound"]):
		return _bad("run_bound must be true")
	if not _is_int(g["deliver_by_tick"]) or int(g["deliver_by_tick"]) < 0:
		return _bad("deliver_by_tick must be an int >= 0")
	if g.has("payload") and not (g["payload"] is Dictionary):
		return _bad("payload must be a Dictionary")
	if g.has("sponsor_window"):
		var sw: Variant = g["sponsor_window"]
		if not (sw is String) or ((sw as String) != "" and (not (sw as String).begins_with(SPONSOR_WINDOW_PREFIX)
				or not (sw as String).trim_prefix(SPONSOR_WINDOW_PREFIX).is_valid_int())):
			return _bad("sponsor_window must be '' or 'sw_<n>'")
		if source == "system" and (sw as String) != "":
			return _bad("system gifts need no Sponsor-Fenster")
	if g.has("sig"):
		var sig: Variant = g["sig"]
		if not (sig is String) or not (sig as String).begins_with(SIG_PREFIX) \
				or _hex(64).search((sig as String).substr(SIG_PREFIX.length())) == null:
			last_detail = "sig must be 'hmac-sha256:' + 64 hex characters"
			return "bad_signature"
	if source != "system" and league == "pur":
		last_detail = "external gifts are not allowed in the Pur-Liga"
		return "league_pur"
	return ""


## Deterministic system gift of a hype threshold (05 §6.5: gift_id g_sys_<battle_n>_<k>); the sponsor was picked by
## Show's game rng ("show" stream with index battle_n). "" sponsor → {}.
static func make_system(sponsor_id: String, battle_n: int, k: int) -> Dictionary:
	if sponsor_id == "":
		return {}
	var g: Dictionary = _base("g_sys_%d_%d" % [battle_n, k], "system", "sponsor_buff")
	g["sponsor_id"] = sponsor_id
	g["league"] = "pur"          # system gifts exist in both leagues; the field only gates external gifts
	g["roll"] = {"seed_stream": "show", "nonce": battle_n}
	return g


## Debug/QA gift (source "dev", league "show", effect 1000 ‰, load basis 0). The id is g_dev_ + 16 random hex
## characters (CSPRNG): unique across launches, so a dev gift is never a "duplicate" of a gift id stored in a loaded
## save (flags.live.gift_ids). Not game logic: the applied gift is recorded with its id in the run log.
## kind "gold": `amount` credits (≤ 0 → 100); "chest": `tier` bronze|silver|gold (else bronze), contents empty →
## the core rolls from the "gift" seed stream; "fan_pack": one common roll + hype; "sponsor_buff": `tier` carries the
## sponsor id (e.g. make_dev("sponsor_buff", "spn_gluckwasser", 0)); "cheer": cosmetic.
## `sender_ref` (optional): a pseudonymous test viewer — the Sponsor-Fenster allow rules.sponsor_windows.per_viewer
## gifts per viewer and window ("" = unknown sender, no per-viewer limit).
static func make_dev(kind: String, tier: String, amount: int, sender_ref: String = "") -> Dictionary:
	_dev_counter += 1
	var g: Dictionary = _base("g_dev_" + _random_hex(8), "dev", kind)
	g["league"] = "show"
	if sender_ref != "":
		(g["sender"] as Dictionary)["sender_ref"] = sender_ref
	match kind:
		"gold":
			g["amount"] = amount if amount > 0 else 100
		"chest":
			g["tier"] = tier if TIERS.has(tier) else "bronze"
			g["roll"] = {"seed_stream": "gift", "nonce": _dev_counter}
		"fan_pack":
			g["roll"] = {"seed_stream": "gift", "nonce": _dev_counter}
		"sponsor_buff":
			g["sponsor_id"] = tier
	return g


## True for gifts that come from outside the core (everything except source "system").
static func is_external(g: Dictionary) -> bool:
	return str(g.get("source", "")) != "system"


# --- internals --------------------------------------------------------------------------------------------------------

static func _base(gift_id: String, source: String, kind: String) -> Dictionary:
	return {
		"schema": SCHEMA, "gift_id": gift_id, "source": source, "kind": kind, "tier": "", "amount": 0,
		"sponsor_id": "", "sender": {"display_name": "", "anon": true, "sender_ref": ""}, "message_key": "",
		"target": {"player_id": "local", "run_id": ""}, "event_id": "", "window_id": "", "league": "pur",
		"effect_pm": 1000, "load_half": 0, "roll": {}, "contents": [], "run_bound": true, "deliver_by_tick": 0,
		"issued_at": "", "payload": {},
	}


static func _check_kind_fields(g: Dictionary, kind: String, source: String) -> String:
	var tier: String = _str(g["tier"])
	if not (g["tier"] is String):
		return _bad("tier must be a String")
	if kind == "chest":
		if not TIERS.has(tier):
			return _bad("chest tier must be bronze|silver|gold")
	elif tier != "":
		return _bad("tier must be '' for kind %s" % kind)
	if not _is_int(g["amount"]):
		return _bad("amount must be an int")
	var amount: int = int(g["amount"])
	if not (KIND_SOURCES[kind] as Array).has(source):
		return _bad("kind %s is not sent by source %s (05 §6.3)" % [kind, source])
	if kind == "gold":
		if amount <= 0:
			return _bad("gold amount must be > 0")
		if source != "dev" and not GOLD_AMOUNTS.has(amount):
			return _bad("gold amount must be 100 or 250 (05 §6.3)")
	elif amount != 0:
		return _bad("amount must be 0 for kind %s" % kind)
	if not (g["sponsor_id"] is String):
		return _bad("sponsor_id must be a String")
	var sponsor: String = g["sponsor_id"]
	if kind == "sponsor_buff":
		if sponsor == "":
			return _bad("sponsor_buff needs a sponsor_id")
	elif sponsor != "":
		return _bad("sponsor_id must be '' for kind %s" % kind)
	var roll: Variant = g.get("roll", {})
	if not (roll is Dictionary):
		return _bad("roll must be a Dictionary")
	if RANDOM_KINDS.has(kind) and not g.has("roll"):
		return _bad("random kinds need a roll")
	var paid_chest: bool = kind == "chest" and PAID_SOURCES.has(source)
	var reason: String = _check_roll(roll, paid_chest)
	if reason != "":
		return reason
	var contents: Variant = g.get("contents", [])
	if not (contents is Array):
		return _bad("contents must be an Array")
	if not RANDOM_KINDS.has(kind) and not (contents as Array).is_empty():
		return _bad("contents only for chest/fan_pack")
	for c: Variant in (contents as Array):
		reason = _check_content(c)
		if reason != "":
			return reason
	if kind == "fan_pack" and not (contents as Array).is_empty():
		if (contents as Array).size() != 1 or str(((contents as Array)[0] as Dictionary).get("rarity", "")) != "common":
			return _bad("fan_pack contents: none or exactly one common entry (05 §6.3)")
	if paid_chest:
		return _check_paid_chest(g, tier, roll, contents)
	return ""


## Paid chests are rolled by the server (05 §6.4 step 4, §7.4): the delivered contents are exactly that roll — one entry
## per roll — and the roll count is the normative one for the gift's effect factor (05 §6.10, verify_fair.py):
## rolls == GiftPolicy.rolls_for(CHEST_BASE_ROLLS[tier], effect_pm). Empty contents would let the client roll locally
## from the public "gift" stream and bypass the provably fair roll.
static func _check_paid_chest(g: Dictionary, tier: String, roll: Dictionary, contents: Array) -> String:
	var rolls: int = int(roll["rolls"])
	if contents.is_empty():
		return _bad("paid chests carry the server contents (05 §7.4)")
	if contents.size() != rolls:
		return _bad("paid chest contents must have one entry per roll (%d != %d)" % [contents.size(), rolls])
	var eff: Variant = g.get("effect_pm")
	if _is_int(eff) and int(eff) >= 1 and int(eff) <= 1000:
		var want: int = GiftPolicy.rolls_for(int(CHEST_BASE_ROLLS[tier]), int(eff))
		if rolls != want:
			return _bad("paid %s chest at effect_pm %d has %d rolls, not %d (05 §6.10)" % [tier, int(eff), rolls, want])
	return ""


## Paid chests need the full server roll (05 §6.5, §7): commit, 16-hex client_seed, nonce, log_id, table_id,
## tables_hash, rolls, guarantee, pity_forced. Offline/system/dev rolls ({"seed_stream", "nonce"}) are checked by
## field when present.
static func _check_roll(roll: Dictionary, paid_chest: bool) -> String:
	if paid_chest:
		for key: String in ["commit", "client_seed", "nonce", "log_id", "table_id", "tables_hash", "rolls", "guarantee",
				"pity_forced"]:
			if not roll.has(key):
				return _bad("paid chest roll needs '%s'" % key)
	if roll.has("client_seed"):
		var cs: Variant = roll["client_seed"]
		if not (cs is String) or (cs as String).length() != 16 or _hex(16).search(cs as String) == null:
			return _bad("client_seed must be exactly 16 characters [0-9a-f]")
	if roll.has("log_id"):
		var lid: Variant = roll["log_id"]
		if _log_id == null:
			_log_id = RegEx.create_from_string("^l_[0-9a-f]{16}$")
		if not (lid is String) or _log_id.search(lid as String) == null:
			return _bad("log_id must be 'l_' + 16 hex characters")
	for key: String in ["commit", "tables_hash"]:
		if roll.has(key) and not (roll[key] is String):
			return _bad("roll.%s must be a hex String" % key)
	if roll.has("table_id") and not (roll["table_id"] is String):
		return _bad("roll.table_id must be a String")
	if roll.has("seed_stream") and not (roll["seed_stream"] is String):
		return _bad("roll.seed_stream must be a String")
	if roll.has("nonce") and (not _is_int(roll["nonce"]) or int(roll["nonce"]) < 0):
		return _bad("roll.nonce must be an int >= 0")
	if roll.has("rolls") and (not _is_int(roll["rolls"]) or int(roll["rolls"]) < 1):
		return _bad("roll.rolls must be an int >= 1")
	for key: String in ["guarantee", "pity_forced"]:
		if roll.has(key) and (not (roll[key] is String) or not GUARANTEES.has(str(roll[key]))):
			return _bad("roll.%s must be ''|rare|epic" % key)
	return ""


## {"rarity", "item_id", "qty" >= 1} or {"rarity", "credits" > 0}.
static func _check_content(c: Variant) -> String:
	if not (c is Dictionary):
		return _bad("contents entries must be Dictionaries")
	var d: Dictionary = c
	if not RARITIES.has(_str(d.get("rarity", ""))):
		return _bad("content rarity must be common|rare|epic")
	if d.has("credits"):
		if not _is_int(d["credits"]) or int(d["credits"]) <= 0 or int(d["credits"]) > MAX_CONTENT_CREDITS \
				or d.has("item_id"):
			return _bad("credits content needs 1..%d credits and no item_id" % MAX_CONTENT_CREDITS)
		return ""
	if not (d.get("item_id") is String) or str(d.get("item_id")) == "":
		return _bad("item content needs an item_id")
	if not _is_int(d.get("qty", null)) or int(d["qty"]) < 1 or int(d["qty"]) > MAX_CONTENT_QTY:
		return _bad("item content needs qty 1..%d" % MAX_CONTENT_QTY)
	return ""


static func _check_sender(sender: Variant, source: String) -> String:
	if not (sender is Dictionary):
		return _bad("sender must be a Dictionary")
	var s: Dictionary = sender
	if not (s.get("display_name") is String) or not (s.get("anon") is bool) or not (s.get("sender_ref") is String):
		return _bad("sender needs display_name: String, anon: bool, sender_ref: String")
	var display: String = s["display_name"]
	if display.length() > MAX_DISPLAY_NAME:
		return _bad("sender.display_name longer than %d" % MAX_DISPLAY_NAME)
	if bool(s["anon"]) and display != "":
		return _bad("anonymous senders have no display_name")
	if source == "system" and (display != "" or not bool(s["anon"]) or str(s["sender_ref"]) != ""):
		return _bad("system gifts have an empty anonymous sender")
	if BUYER_SOURCES.has(source):
		if _sender_ref == null:
			_sender_ref = RegEx.create_from_string("^b_[0-9a-f]{12}$")
		if _sender_ref.search(str(s["sender_ref"])) == null:
			return _bad("%s gifts need sender.sender_ref 'b_' + 12 hex characters (05 §7.5)" % source)
	return ""


static func _random_hex(n_bytes: int) -> String:
	if _crypto == null:
		_crypto = Crypto.new()
	return _crypto.generate_random_bytes(n_bytes).hex_encode()


static func _hex(n: int) -> RegEx:
	if n == 16:
		if _hex16 == null:
			_hex16 = RegEx.create_from_string("^[0-9a-f]{16}$")
		return _hex16
	if _hex64 == null:
		_hex64 = RegEx.create_from_string("^[0-9a-f]{64}$")
	return _hex64


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))


static func _str(v: Variant) -> String:
	return str(v) if v is String or v is StringName else ""


static func _bad(detail: String) -> String:
	last_detail = detail
	return "invalid_schema"
