extends RefCounted
## Validator rules of the show-boss block of encounters (06 §2.6, 07 §9.6, E26): `floors.json → encounters[].show_boss`
## = {"elite_pm", "banner_tag", "reward": {"kind", "id"}, "rule": RtRule}. Private helper (no class_name), called from
## validators/rt.gd (the frozen data_validator.gd gets no further hook). RtMods.from_show_boss maps a valid block to
## the static mods of the combat (stat_pm max_hp / str × elite_pm, the shared add_rule), rt_result.gd pays the reward.
##
## Rules: only the four keys; elite_pm 1000…2000; banner_tag a "showboss_" tag with M.O.D. lines; reward exactly one
## Fanpost box of lootboxes.json ({"kind": "box", "id"}); the rule a valid enemy RtRule (skill with an rt block, a
## known target, conditions, every_ms ≥ 1000); never on a boss, tutorial or story-less encounter without enemies.

const KEYS: PackedStringArray = ["elite_pm", "banner_tag", "reward", "rule"]
const ELITE_PM: Vector2i = Vector2i(1000, 2000)
const TAG_PREFIX: String = "showboss_"
const REWARD_KINDS: PackedStringArray = ["box"]


## Appends every problem of the show-boss blocks to v.errors.
static func check(v: DataValidator) -> void:
	for f: Dictionary in v._out["floors"]:
		var encs: Array = f["encounters"]
		for j in encs.size():
			var e: Dictionary = encs[j]
			var sb: Variant = e.get("show_boss", {})
			if not (sb is Dictionary) or (sb as Dictionary).is_empty():
				continue
			check_block(v, DataValidator._ctx("floors[%d].encounters" % int(f["index"]), j, e) + ".show_boss", e, sb)


## The rules of one block `sb` of encounter `enc` (normalized encounter dict).
static func check_block(v: DataValidator, ctx: String, enc: Dictionary, sb: Dictionary) -> void:
	for k: Variant in sb.keys():
		if not KEYS.has(str(k)):
			v._err(ctx + "." + str(k), "unknown key (elite_pm, banner_tag, reward, rule)")
	for k: String in KEYS:
		if not sb.has(k):
			v._err(ctx + "." + k, "missing")
	if bool(enc.get("boss", false)) or bool(enc.get("tutorial", false)):
		v._err(ctx, "a show boss is an optional regular group (no boss, no tutorial)")
	var pm: Variant = sb.get("elite_pm", 1000)
	if not JsonUtil.is_integral(pm) or int(pm) < ELITE_PM.x or int(pm) > ELITE_PM.y:
		v._err(ctx + ".elite_pm", "an integer %d…%d (got %s)" % [ELITE_PM.x, ELITE_PM.y, str(pm)])
	var tag: String = str(sb.get("banner_tag", ""))
	if not tag.begins_with(TAG_PREFIX):
		v._err(ctx + ".banner_tag", "a '%s…' M.O.D. tag (got '%s')" % [TAG_PREFIX, tag])
	elif int(v._mod_tags.get(tag, 0)) <= 0:                # the HUD shows the banner only with a line (R3)
		v.warnings.append("%s.banner_tag: tag '%s' has no M.O.D. line" % [ctx, tag])
	var rw: Variant = sb.get("reward", {})
	if not (rw is Dictionary):
		v._err(ctx + ".reward", "an object {kind, id}")
	else:
		var r: Dictionary = rw
		for k: Variant in r.keys():
			if str(k) != "kind" and str(k) != "id":
				v._err(ctx + ".reward." + str(k), "unknown key (kind, id)")
		v._enum(ctx + ".reward.kind", str(r.get("kind", "")), REWARD_KINDS)
		v._ref(ctx + ".reward.id", str(r.get("id", "")), v._boxes, "lootbox")
		if str(r.get("id", "")) == "":
			v._err(ctx + ".reward.id", "a lootbox id")
	var rule: Variant = sb.get("rule", {})
	if not (rule is Dictionary) or (rule as Dictionary).is_empty():
		v._err(ctx + ".rule", "the one extra rule of the show boss (an RtRule)")
		return
	var problems: PackedStringArray = RtMods.validate([{"src": "showboss:" + str(enc.get("id", "")), "op": "add_rule",
		"unit": "enemies", "shared": true, "rule": rule}])
	for p: String in problems:
		v._err(ctx + ".rule", p)
	var sid: String = str((rule as Dictionary).get("skill", ""))
	if sid == "" or not v._skills.has(sid):
		v._err(ctx + ".rule.skill", "unknown skill '%s'" % sid)
	elif ((v._skills[sid] as Dictionary).get("rt", {}) as Dictionary).is_empty():
		v._err(ctx + ".rule.skill", "skill '%s' has no rt block" % sid)
	elif str((v._skills[sid] as Dictionary).get("user", "")) == "party":
		v._err(ctx + ".rule.skill", "an enemy skill (got the party skill '%s')" % sid)
	var every: Variant = (rule as Dictionary).get("every_ms", 0)
	if not JsonUtil.is_integral(every) or int(every) < 1000 or int(every) % 100 != 0:
		v._err(ctx + ".rule.every_ms", "≥ 1000 and a multiple of 100 (V9)")
	var first: Variant = (rule as Dictionary).get("first_ms", 0)
	if not JsonUtil.is_integral(first) or int(first) < 0 or int(first) % 100 != 0:
		v._err(ctx + ".rule.first_ms", "≥ 0 and a multiple of 100 (V2)")
