class_name Command extends RefCounted
## Schema check of recorded commands (02_TECH §3.4 "t" types, 05 §10.6). Commands are the "Befehle rein" half of the
## live contract (Brief §6b.2): plain JSON dictionaries; after a JSON round trip every number is a float, so integer
## fields accept integral floats. Shapes recorded by Game: floor {"floor"}, encounter {"enc", "adv", "group"}, battle
## {"cmd", "auto"}, lootbox {"box"}, buy {"item", "qty", "safe_room"}, sell {"item", "qty"}, equip {"member", "slot",
## "item"}, use_item {"item", "member"}, rest {}, event {"id", "choice"}, chest {"id"}, gate {"key"}, room {"cell": [x,
## y]}, safe_room {"id"}, safe_room_exit {}, scene {"id"}, flag {"key" ∈ FLAG_KEYS, "value"}, difficulty {"to"}, descend
## {}, gift {"gift"} (external input, cmd id 0), sponsor_window {"op": "dev_open", "sec", "slots"} (QA Sponsor-Fenster,
## SponsorWindows.dev_open, 05 §6.13), hero {"id": "kai" | "mopsula"} (06 §1.7: the controlled character; the choice
## of a new run right after "floor", later switches in a safe room — HeroRules.check), talent {"member", "id"}
## (Talent-Show pick, 06 §2.2), casting {"member", "species", "class"} (06 §3.4), secret {"id": "sec_…"} (06 §2.7:
## Kulissenwand knocked over / Regie-Notiz read — Secrets.check_open), twist {"twist": {"schema": 1, "id", "n", "src",
## "params", "duration", "tick", "req"?, "vote_id"?}} (06 §5.7, external input, cmd id 0; TwistApplier decides whether
## it applies).
## battle.cmd = BattleCommand.to_dict(): {"kind": attack|skill|stunt|item|defend|flee, "actor", "skill", "item",
## "targets": [String]}. Additional unknown fields are allowed (additive protocol versions, 05 §4.3).
## Echtzeitkampf (07 §10.1, R1a): the real-time combat types (RtCommand.TYPES: ability_use, target_change, move_sample,
## combat_item, partner_preset, partner_special, auto_attack, autopilot, combat_hint, move_input, combat_speed,
## move_batch) and the optional "rt" block of "encounter" are checked by RtCommand.validate. Until R5a builds the
## real-time combat path both verifiers refuse them (RunRules.rt_refusal → "rt_unavailable").
## Casting (08 §2.3, K0): persona {"v": 1, "talent", "bias": [≤ 3 Strings]} (start, once per run) or {"v": 1,
## "talent", "swap": true} (first Talent-Show) — ids only; the rules are PersonaRules.check's.

const TYPES: PackedStringArray = ["floor", "encounter", "battle", "lootbox", "buy", "sell", "equip", "use_item", "rest",
	"event", "chest", "gate", "room", "safe_room", "safe_room_exit", "scene", "flag", "difficulty", "descend", "gift",
	"sponsor_window",
	"hero", "talent", "casting", "secret",   # 06 packages A (hero, secret) and B (talent, casting)
	"twist",                                 # 06-D (external input like "gift")
	# Echtzeitkampf (07, R1a, §10.1): == RtCommand.TYPES — schema in RtCommand.validate
	"ability_use", "target_change", "move_sample", "combat_item", "partner_preset", "partner_special", "auto_attack",
	"autopilot", "combat_hint", "move_input", "combat_speed", "move_batch",
	"persona"]                               # Casting (08, K0): start talent + bias / swap (PersonaRules)
const SPONSOR_WINDOW_OPS: PackedStringArray = ["dev_open"]
## Inputs from outside the player (cmd id 0, 05 §10.6; == Game.EXTERNAL_CMDS): viewer gifts and M.O.D. twists (06-D).
const EXTERNAL: PackedStringArray = ["gift", "twist"]
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const DIFFICULTIES: PackedStringArray = ["prime", "vorabend"]
## Flag keys a player command may set (Game.set_flag: only the intro). Every other flag is a reaction of the core
## (scene_*, defeated_*, title_*, mop_pep_talk, "live" — the gift counters) and never a recorded write (05 §11.4).
const FLAG_KEYS: PackedStringArray = ["intro_seen"]
const ADVANTAGE_MAX: int = 2           # BattleSetup.Advantage NORMAL 0 / PREEMPTIVE 1 / AMBUSH 2
const PERSONA_VERSION: int = 1         # Casting (08 §2.3, K0) == PersonaRules.VERSION
const PERSONA_MAX_BIAS: int = 3        # == PersonaRules.MAX_BIAS

static var _gate_key: RegEx = null


## "" = valid, else a message "<t>: <problem>".
static func validate(d: Dictionary) -> String:
	if not d.has("t") or not (d["t"] is String or d["t"] is StringName):
		return "missing command type 't'"
	var t: String = str(d["t"])
	if not TYPES.has(t):
		return "unknown command type '%s'" % t
	var err: String = _validate_fields(t, d)
	return "" if err == "" else "%s: %s" % [t, err]


static func _validate_fields(t: String, d: Dictionary) -> String:
	match t:
		"floor":
			return _int_min(d, "floor", 1)
		"encounter":
			var e: String = _id(d, "enc")
			if e != "":
				return e
			e = _int_min(d, "adv", 0)
			if e != "":
				return e
			if int(d["adv"]) > ADVANTAGE_MAX:
				return "adv must be 0..%d" % ADVANTAGE_MAX
			if d.has("opener") and (not (d["opener"] is String) or str(d["opener"]) != "bark" \
					or int(d["adv"]) != BattleSetup.Advantage.PREEMPTIVE):
				return "opener must be \"bark\" (only with adv 1)"      # 06 integration: BattleSetup.opener
			if d.has("rt"):                                            # Echtzeitkampf (07, R1a): the rt block
				var rt_err: String = RtCommand.validate(d)
				if rt_err != "":
					return rt_err
			return _str(d, "group")
		"battle":
			if not (d.get("auto", null) is bool):
				return "auto must be a bool"
			return _battle_cmd(d.get("cmd", null))
		"lootbox":
			return _id(d, "box")
		"buy":
			var e2: String = _first([_id(d, "item"), _int_min(d, "qty", 1)])
			return e2 if e2 != "" else _str(d, "safe_room")
		"sell":
			return _first([_id(d, "item"), _int_min(d, "qty", 1)])
		"equip":
			var e3: String = _first([_id(d, "member"), _str(d, "item")])
			if e3 != "":
				return e3
			if not EQUIP_SLOTS.has(str(d.get("slot", ""))):
				return "slot must be weapon|armor|accessory"
			return ""
		"use_item":
			return _first([_id(d, "item"), _str(d, "member")])
		"rest", "safe_room_exit", "descend":
			return ""
		"event":
			return _first([_id(d, "id"), _id(d, "choice")])
		"chest", "safe_room", "scene":
			return _id(d, "id")
		"gate":
			var e4: String = _id(d, "key")
			if e4 != "":
				return e4
			if _gate_key == null:
				_gate_key = RegEx.create_from_string("^-?\\d+,-?\\d+,[NESW]$")
			return "" if _gate_key.search(str(d["key"])) != null else "key must be \"x,y,N|E|S|W\""
		"room":
			var cell: Variant = d.get("cell", null)
			if not (cell is Array) or (cell as Array).size() != 2 or not _is_int((cell as Array)[0]) \
					or not _is_int((cell as Array)[1]):
				return "cell must be [x, y] (integers)"
			return ""
		"flag":
			var e5: String = _id(d, "key")
			if e5 != "":
				return e5
			if not FLAG_KEYS.has(str(d["key"])):
				return "key '%s' is not a player flag (%s)" % [str(d["key"]), ", ".join(FLAG_KEYS)]
			if not d.has("value"):
				return "missing 'value'"
			var v: Variant = d["value"]
			if not (v is bool or v is String or _is_int(v)):
				return "value must be bool, int or String"
			return ""
		"difficulty":
			return "" if DIFFICULTIES.has(str(d.get("to", ""))) else "to must be prime|vorabend"
		"sponsor_window":
			if not SPONSOR_WINDOW_OPS.has(str(d.get("op", ""))):
				return "op must be one of %s" % ", ".join(SPONSOR_WINDOW_OPS)
			var e6: String = _first([_int_min(d, "sec", 1), _int_min(d, "slots", 1)])
			if e6 != "":
				return e6
			if int(d["sec"]) > SponsorWindows.DEV_MAX_SEC or int(d["slots"]) > SponsorWindows.DEV_MAX_SLOTS:
				return "sec must be <= %d, slots <= %d" % [SponsorWindows.DEV_MAX_SEC, SponsorWindows.DEV_MAX_SLOTS]
			return ""
		"hero":                                    # 06 package A
			var e7: String = _id(d, "id")
			if e7 != "":
				return e7
			return "" if HeroRules.HEROES.has(str(d["id"])) else "id must be one of %s" % ", ".join(HeroRules.HEROES)
		"secret":                                  # 06 package A
			var e8: String = _id(d, "id")
			if e8 != "":
				return e8
			return "" if str(d["id"]).begins_with("sec_") else "id must start with sec_"
		"talent":                            # 06 package B
			return _first([_id(d, "member"), _id(d, "id")])
		"casting":
			return _first([_id(d, "member"), _id(d, "species"), _id(d, "class")])
		"twist":
			return _twist(d.get("twist", null))
		"persona":                                 # Casting (08, K0)
			return _persona(d)
		"ability_use", "target_change", "move_sample", "combat_item", "partner_preset", "partner_special", \
				"auto_attack", "autopilot", "combat_hint", "move_input", "combat_speed", "move_batch":
			return RtCommand.validate(d)                     # Echtzeitkampf (07, R1a): delegated (07 §10.1)
		"gift":
			if not (d.get("gift", null) is Dictionary):
				return "gift must be a Dictionary"
			var reason: String = Gift.validate(d["gift"])
			return "" if reason == "" else "%s (%s)" % [reason, Gift.last_detail]
	return ""


static func _battle_cmd(v: Variant) -> String:
	if not (v is Dictionary):
		return "cmd must be a Dictionary (BattleCommand.to_dict)"
	var c: Dictionary = v
	if not BattleCommand.KIND_NAMES.has(str(c.get("kind", ""))):
		return "cmd.kind must be one of %s" % ", ".join(BattleCommand.KIND_NAMES)
	if not (c.get("actor", null) is String) or str(c["actor"]) == "":
		return "cmd.actor must be a non-empty String"
	if not (c.get("skill", "") is String) or not (c.get("item", "") is String):
		return "cmd.skill / cmd.item must be Strings"
	var targets: Variant = c.get("targets", [])
	if not (targets is Array or targets is PackedStringArray):
		return "cmd.targets must be an Array of Strings"
	for tid: Variant in Array(targets):
		if not (tid is String or tid is StringName):
			return "cmd.targets must be an Array of Strings"
	return ""


## 06-D: the shape of a recorded twist (the rules are TwistApplier.validate's).
static func _twist(v: Variant) -> String:
	if not (v is Dictionary):
		return "twist must be a Dictionary"
	var tw: Dictionary = v
	if not _is_int(tw.get("schema", null)) or int(tw["schema"]) != 1:
		return "twist.schema must be 1"
	var e: String = _first([_id(tw, "id"), _int_min(tw, "n", 1), _int_min(tw, "duration", 0), _int_min(tw, "tick", 0)])
	if e != "":
		return "twist." + e
	if not TwistApplier.SOURCES.has(str(tw.get("src", ""))):
		return "twist.src must be one of %s" % ", ".join(TwistApplier.SOURCES)
	if not (tw.get("params", null) is Dictionary):
		return "twist.params must be a Dictionary"
	for k: Variant in (tw["params"] as Dictionary).keys():
		if not _is_int((tw["params"] as Dictionary)[k]):
			return "twist.params.%s must be an integer" % str(k)
	for k: String in ["req", "vote_id"]:
		if tw.has(k) and not (tw[k] is String):
			return "twist.%s must be a String" % k
	return ""


## Casting (08 §2.3, K0): the shape of a persona command (the rules are PersonaRules.check's).
static func _persona(d: Dictionary) -> String:
	if not _is_int(d.get("v", null)) or int(d["v"]) != PERSONA_VERSION:
		return "v must be %d" % PERSONA_VERSION
	var e: String = _id(d, "talent")
	if e != "":
		return e
	if not str(d["talent"]).begins_with("tal_org_"):
		return "talent must start with tal_org_"
	if d.has("swap"):
		if d.has("bias") or not (d["swap"] is bool) or not bool(d["swap"]):
			return "a swap is {v, talent, swap: true} (no bias)"
		return ""
	var bias: Variant = d.get("bias", null)
	if not (bias is Array) or (bias as Array).size() > PERSONA_MAX_BIAS:
		return "bias must be an array of at most %d marotte ids" % PERSONA_MAX_BIAS
	for b: Variant in (bias as Array):
		if not (b is String) or str(b) == "":
			return "bias must contain non-empty Strings"
	return ""


## True for command types that come from outside the player (cmd id 0).
static func is_external(d: Dictionary) -> bool:
	return EXTERNAL.has(str(d.get("t", "")))


static func _id(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if not (v is String or v is StringName) or str(v) == "":
		return "%s must be a non-empty String" % key
	return ""


static func _str(d: Dictionary, key: String) -> String:
	var v: Variant = d.get(key, null)
	if not (v is String or v is StringName):
		return "%s must be a String" % key
	return ""


static func _int_min(d: Dictionary, key: String, lo: int) -> String:
	var v: Variant = d.get(key, null)
	if not _is_int(v) or int(v) < lo:
		return "%s must be an integer >= %d" % [key, lo]
	return ""


static func _first(errors: Array) -> String:
	for e: Variant in errors:
		if str(e) != "":
			return str(e)
	return ""


static func _is_int(v: Variant) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and is_finite(float(v)) and float(v) == floorf(float(v))
