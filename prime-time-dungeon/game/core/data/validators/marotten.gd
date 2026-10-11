extends RefCounted
## Private helper of DataValidator (02_TECH §0.3; 06 §8.0 Nr. 7 "validators/<table>.gd", package C): rules of
## marotten.json (06 §4.9) — normalization (rule 2/4), references (rule 5), required M.O.D. tags (rule 9), conditions
## (rule 10) and the distance rule of 06 §0.3 (no foot / barefoot words in marotten texts and liga_/marotte_ lines).
## Called only from DataValidator, which passes itself (`v`) for its normalization primitives and error list.

## kind → the context its condition is evaluated in (MarottenRules.battle_context / zone payload).
const KIND_TRIGGERS: Dictionary = {"battle": "marotte_battle", "explore": "explore_zone", "liga": "marotte_battle"}
const KINDS: PackedStringArray = ["battle", "explore", "liga"]
const TRIGGERS: PackedStringArray = ["marotte_battle", "explore_zone"]
## e-keys of the two contexts (06 §4.6; MarottenRules.BATTLE_KEYS / ZONE_KEYS are the same lists).
const BATTLE_KEYS: PackedStringArray = ["won", "hero", "party_turns", "items_used", "gifts", "defends",
	"flee_attempts", "distinct_actions", "stunts_success", "weakness_hits", "min_party_hp_pct", "party_kos",
	"last_kill_member", "encounter_type", "is_boss", "is_floor_boss", "boss_id", "kai_weapon", "equip_all_common",
	"hero_armor_empty", "hero_acc_empty", "party_armor_empty", "party_acc_empty", "liga_tier"]
const ZONE_KEYS: PackedStringArray = ["zones_since_battle", "zone", "floor"]
## Rotating preferences: reward key → [min, max] (integers; won_box is a lootbox id or "").
const BET_REWARD_RANGES: Dictionary = {"hit_hype": [0, 50], "hit_follower_pm": [1000, 2000], "won_followers": [0, 500],
	"won_hype": [0, 50]}
const TIER_RANGES: Dictionary = {"tier": [1, 2], "hype_pm": [1000, 2000], "follower_pm": [1000, 2000]}
## Optional per tier: followers the follower factor may add per floor (06 §4.3, integration round 4; absent = no cap).
const TIER_OPTIONAL_RANGES: Dictionary = {"floor_follower_cap": [0, 2000]}
const MAX_NAME: int = 28                    # HUD chip "M.O.D. mag heute: <name>"
const MAX_DESC: int = 80
## 06 §0.3 (distance to Dungeon Crawler Carl): the Liga is "ohne Rüstung & ohne Accessoire" — never feet or shoes.
## Lower-case substrings, checked case-insensitively.
const FOOT_WORDS: PackedStringArray = ["barfuß", "barfuss", "schuh", "füße", "füsse", "fuesse", "socke", "zehen"]
## Lines every rotating preference needs (06 §4.4) and the liga lines (06 §4.3).
const BET_TAGS: PackedStringArray = ["marotte_announce:%s", "marotte_hit:%s"]
const LIGA_TAGS: PackedStringArray = ["liga_hint", "liga_enter:1", "liga_enter:2", "liga_leave", "liga_floor"]
const SHARED_TAGS: PackedStringArray = ["marotte_won", "marotte_missed"]
const SPEC: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["kind", "s"], ["trigger", "s"],
	["condition", "s"], ["goal", "i", 3], ["rotation", "b", true], ["starter", "b", false], ["min_floor", "i", 1],
	["weight", "i", 1], ["reward", "d", {}], ["mod_tag", "s", ""]]


## Rules 2/4 of one entry: schema, vocabularies, ranges, text lengths, foot words, reward shape.
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	var kind: String = str(d["kind"])
	v._enum(ctx + ".kind", kind, KINDS)
	v._enum(ctx + ".trigger", str(d["trigger"]), TRIGGERS)
	if KIND_TRIGGERS.has(kind) and str(d["trigger"]) != str(KIND_TRIGGERS[kind]):
		v._err(ctx + ".trigger", "kind %s needs trigger %s" % [kind, str(KIND_TRIGGERS[kind])])
	if str(d["name"]).length() > MAX_NAME:
		v._err(ctx + ".name", "longer than %d characters (HUD chip)" % MAX_NAME)
	if str(d["desc"]).length() > MAX_DESC:
		v._err(ctx + ".desc", "longer than %d characters" % MAX_DESC)
	for field: String in ["name", "desc"]:
		var bad: String = foot_word(str(d[field]))
		if bad != "":
			v._err(ctx + "." + field, "'%s' is not allowed (06 §0.3: no foot/shoe words)" % bad)
	if kind == "liga":
		v._range_i(ctx + ".goal", int(d["goal"]), 0, 0)
		if bool(d["rotation"]) or bool(d["starter"]):
			v._err(ctx + ".rotation", "the liga is always on (rotation/starter must be false)")
		_check_liga_reward(v, ctx + ".reward", d["reward"])
	else:
		v._range_i(ctx + ".goal", int(d["goal"]), 1, 9)
		_check_bet_reward(v, ctx + ".reward", d["reward"])
	v._range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	v._range_i(ctx + ".weight", int(d["weight"]), 1, 10)
	return d


## Rules 3 (cross-entry), 5 (lootbox references) and 9 (required lines): `boxes` = lootbox lookup of the validator.
static func check_refs(v: DataValidator, entries: Array, boxes: Dictionary) -> void:
	var ligas: int = 0
	var starters: int = 0
	for i in entries.size():
		var d: Dictionary = entries[i]
		var ctx: String = DataValidator._ctx("marotten", i, d)
		var rw: Dictionary = d["reward"]
		for key: String in ["won_box", "floor_box"]:
			if str(rw.get(key, "")) != "":
				v._ref(ctx + ".reward." + key, str(rw[key]), boxes, "lootbox")
		if str(d["kind"]) == "liga":
			ligas += 1
			for tag: String in LIGA_TAGS:
				v._referenced_tags[tag] = ctx + ".kind"
		else:
			if bool(d["starter"]) and bool(d["rotation"]):
				starters += 1
			for pattern: String in BET_TAGS:
				v._referenced_tags[pattern % str(d["id"])] = ctx + ".id"
	if ligas > 1:
		v._err("marotten", "at most one entry of kind liga (got %d)" % ligas)
	if v.strict and not entries.is_empty():
		if starters == 0:
			v._err("marotten", "needs at least one rotating starter preference (floor 1)")
		for tag: String in SHARED_TAGS:
			v._referenced_tags[tag] = "marotten"


## Rule 9 addition (06 §0.3): liga_* / marotte_* lines never mention feet or shoes.
static func check_lines(v: DataValidator, mod_lines: Array) -> void:
	for i in mod_lines.size():
		var tag: String = str(mod_lines[i]["tag"])
		if not (tag.begins_with("liga_") or tag.begins_with("marotte_")):
			continue
		var bad: String = foot_word(str(mod_lines[i]["text"]))
		if bad != "":
			v._err(DataValidator._ctx("mod_lines", i, mod_lines[i]) + ".text",
				"'%s' is not allowed in %s lines (06 §0.3)" % [bad, tag.get_slice(":", 0)])


## Rule 10: the condition parses and uses only the e-keys of its trigger's context (s. = StatIds as usual).
static func check_conditions(v: DataValidator, entries: Array) -> void:
	for i in entries.size():
		var d: Dictionary = entries[i]
		var keys: PackedStringArray = context_keys(str(d["trigger"]))
		v._check_condition(DataValidator._ctx("marotten", i, d) + ".condition", str(d["condition"]), keys,
			str(d["trigger"]))


## e-keys of a marotten trigger ([] for unknown triggers).
static func context_keys(trigger: String) -> PackedStringArray:
	match trigger:
		"marotte_battle":
			return BATTLE_KEYS
		"explore_zone":
			return ZONE_KEYS
	return PackedStringArray()


## The first forbidden foot/shoe word in `text` ("" = none), case-insensitive.
static func foot_word(text: String) -> String:
	var low: String = text.to_lower()
	for w: String in FOOT_WORDS:
		if low.contains(w):
			return w
	return ""


static func _check_bet_reward(v: DataValidator, ctx: String, raw: Dictionary) -> void:
	for k: Variant in raw.keys():
		var key: String = str(k)
		if key == "won_box":
			if typeof(raw[k]) != TYPE_STRING:
				v._err(ctx + ".won_box", "expected a lootbox id string")
			continue
		if not BET_REWARD_RANGES.has(key):
			v._err(ctx + "." + key, "unknown key (allowed: won_box, %s)" % ", ".join(BET_REWARD_RANGES.keys()))
			continue
		if not JsonUtil.is_integral(raw[k]):
			v._err(ctx + "." + key, "expected integer")
			continue
		var r: Array = BET_REWARD_RANGES[key]
		v._range_i(ctx + "." + key, int(raw[k]), int(r[0]), int(r[1]))


static func _check_liga_reward(v: DataValidator, ctx: String, raw: Dictionary) -> void:
	for k: Variant in raw.keys():
		if not ["tiers", "floor_box"].has(str(k)):
			v._err(ctx + "." + str(k), "unknown key (allowed: tiers, floor_box)")
	if raw.has("floor_box") and typeof(raw["floor_box"]) != TYPE_STRING:
		v._err(ctx + ".floor_box", "expected a lootbox id string")
	var tiers: Variant = raw.get("tiers", [])
	if not (tiers is Array) or (tiers as Array).is_empty() or (tiers as Array).size() > 2:
		v._err(ctx + ".tiers", "needs 1..2 tier entries {tier, hype_pm, follower_pm[, floor_follower_cap]}")
		return
	var seen: Dictionary = {}
	for j in (tiers as Array).size():
		var t: Variant = (tiers as Array)[j]
		var tctx: String = "%s.tiers[%d]" % [ctx, j]
		if not (t is Dictionary):
			v._err(tctx, "expected object")
			continue
		for key: String in TIER_RANGES:
			var val: Variant = (t as Dictionary).get(key, null)
			if not JsonUtil.is_integral(val):
				v._err(tctx + "." + key, "missing or not an integer")
				continue
			var r: Array = TIER_RANGES[key]
			v._range_i(tctx + "." + key, int(val), int(r[0]), int(r[1]))
		for key: String in TIER_OPTIONAL_RANGES:
			if not (t as Dictionary).has(key):
				continue
			var oval: Variant = (t as Dictionary)[key]
			if not JsonUtil.is_integral(oval):
				v._err(tctx + "." + key, "expected integer")
				continue
			var orange: Array = TIER_OPTIONAL_RANGES[key]
			v._range_i(tctx + "." + key, int(oval), int(orange[0]), int(orange[1]))
		for k2: Variant in (t as Dictionary).keys():
			if not TIER_RANGES.has(str(k2)) and not TIER_OPTIONAL_RANGES.has(str(k2)):
				v._err(tctx + "." + str(k2), "unknown key")
		var tier: int = JsonUtil.to_int((t as Dictionary).get("tier", 0))
		if seen.has(tier):
			v._err(tctx + ".tier", "duplicate tier %d" % tier)
		seen[tier] = true
