class_name ModAnnouncer extends RefCounted
## Picks and formats M.O.D. / chat lines (02_TECH §6.1, §4.4.12, GDD §11).
##
## Presentation only: the rng is Show's effect rng (`_fx_rng`), never the game rng. `now_sec` is the caller's clock.
## Chat tags (`chat_*`) are paced by Show (one chat line per CHAT_MIN_INTERVAL) and therefore exempt from the key
## cooldown, like boss_*, death, timer_* and intro.

const KEY_COOLDOWN_SEC: float = 20.0
const NO_COOLDOWN_PREFIXES: PackedStringArray = ["boss_", "timer_", "chat_", "persona_"]   # 08 K0: persona_*
const NO_COOLDOWN_TAGS: PackedStringArray = ["death", "intro"]
## Lines that answer the player's own action or mark a one-off floor beat (purchase, safe room, stairs found, descent;
## GDD §1.4 B3/B6/B8, §11.1): never dropped by Show's priority window — they queue behind the running line (ModDialog)
## and leave the window as it is. (Measured with the full-run bot: a purchase right after the lootbox lines and the
## descent right after an achievement line — ach_speedrun / ach_last_minute fire on floor_completed — were swallowed.)
## 06-B: the one-sentence rule of the first Talent-Show. 06-C: M.O.D. announcing her preferences, a won bet and the
## one-off Liga hint queue the same way (06 §4.2/§4.3); a tag matches by its base ("marotte_won:mar_mop_only" →
## "marotte_won").
const ALWAYS_SAID_TAGS: PackedStringArray = ["vendor_buy", "safe_room_enter", "stairs_found", "floor_end",
	"talent_show_open",                         # 06 package B
	"marotte_announce", "marotte_won", "liga_hint"]   # 06 package C
## 08 K0: every persona line (08 §4.3) queues behind the running line instead of being dropped; the broadcast plan
## limits their number. They also skip the key cooldown (NO_COOLDOWN_PREFIXES).
const ALWAYS_SAID_PREFIXES: PackedStringArray = ["persona_"]
## 08 K0 (R15): a line returned by the set_extra_lines provider counts with this draw weight.
const EXTRA_WEIGHT: int = 2

var _data: GameData = null
var _rng: RandomNumberGenerator = null
var _last_line: Dictionary = {}              # resolved tag → id of the line picked last time
var _cooldown_until: Dictionary = {}         # base tag → now_sec until which it is cooling down
## Casting (08 K0 hook, K3 provider): extra lines per tag (the candidate's AI lines) and the ones it returned.
var _extra: Callable = Callable()
var _extra_ids: Dictionary = {}              # instance id of a provider line → true (drawn with EXTRA_WEIGHT)


func _init(p_data: GameData, p_rng: RandomNumberGenerator) -> void:
	_data = p_data
	_rng = p_rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()


## Fallback "a:b:c" → "a:b" → "a"; filters floor/hype range; never the same line twice in a row per tag;
## key cooldown 20 s per base tag except boss_*, death, timer_*, intro (null while cooling down).
func pick(tag: String, floor_index: int, hype: float, now_sec: float) -> ModLineDef:
	if _data == null or tag == "":
		return null
	var base: String = tag.get_slice(":", 0)
	var cooled: bool = _has_cooldown(base)
	if cooled and now_sec < float(_cooldown_until.get(base, -INF)):
		return null
	var resolved: String = ""
	var candidates: Array[ModLineDef] = []
	for t: String in fallback_chain(tag):
		candidates = _fitting(t, floor_index, hype)
		if not candidates.is_empty():
			resolved = t
			break
	if candidates.is_empty():
		return null
	if candidates.size() > 1 and _last_line.has(resolved):
		var last_id: String = str(_last_line[resolved])
		var filtered: Array[ModLineDef] = []
		for l: ModLineDef in candidates:
			if l.id != last_id:
				filtered.append(l)
		if not filtered.is_empty():
			candidates = filtered
	var line: ModLineDef = _weighted(candidates)
	_last_line[resolved] = line.id
	if cooled:
		_cooldown_until[base] = now_sec + KEY_COOLDOWN_SEC
	return line


## death 5 > boss_* 4 > timer_* 3 > achievement* 2 > lootbox_* 1 > rest 0
static func priority(tag: String) -> int:
	if tag == "death":
		return 5
	if tag.begins_with("boss_"):
		return 4
	if tag.begins_with("timer_"):
		return 3
	if tag.begins_with("achievement"):
		return 2
	if tag.begins_with("lootbox_"):
		return 1
	return 0


## ALWAYS_SAID_TAGS / ALWAYS_SAID_PREFIXES: exempt from Show's priority window (and they never suppress anything
## themselves).
static func always_said(tag: String) -> bool:
	if ALWAYS_SAID_TAGS.has(tag) or ALWAYS_SAID_TAGS.has(tag.get_slice(":", 0)):
		return true
	for p: String in ALWAYS_SAID_PREFIXES:
		if tag.begins_with(p):
			return true
	return false


## text.format(ctx); missing keys stay visible. Show always adds ctx name, floor, level, viewers, followers.
## Integral floats are shown without ".0" (JSON numbers are floats).
func format(line: ModLineDef, ctx: Dictionary) -> String:
	if line == null:
		return ""
	var clean: Dictionary = {}
	for k: Variant in ctx.keys():
		var v: Variant = ctx[k]
		if typeof(v) == TYPE_FLOAT and JsonUtil.is_integral(v):
			v = int(v)
		clean[str(k)] = v
	return line.text.format(clean)


## "a:b:c" → ["a:b:c", "a:b", "a"].
static func fallback_chain(tag: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var t: String = tag
	while t != "":
		out.append(t)
		var cut: int = t.rfind(":")
		if cut < 0:
			break
		t = t.substr(0, cut)
	return out


## True if any line exists for the tag or one of its fallbacks (independent of floor, hype and cooldown).
func has_lines(tag: String) -> bool:
	if _data == null:
		return false
	for t: String in fallback_chain(tag):
		if not _data.mod_lines(t).is_empty():
			return true
	return false


static func _has_cooldown(base: String) -> bool:
	if NO_COOLDOWN_TAGS.has(base):
		return false
	for p: String in NO_COOLDOWN_PREFIXES:
		if base.begins_with(p):
			return false
	return true


func _fitting(tag: String, floor_index: int, hype: float) -> Array[ModLineDef]:
	var out: Array[ModLineDef] = []
	for l: ModLineDef in _data.mod_lines(tag):
		if l != null and l.fits(floor_index, hype):
			out.append(l)
	_append_extra(out, tag, floor_index, hype)     # 08 K0: the line-pool hook (no provider → nothing)
	return out


func _weighted(lines: Array[ModLineDef]) -> ModLineDef:
	var total: int = 0
	for l: ModLineDef in lines:
		total += _line_weight(l)
	var r: int = _rng.randi_range(0, total - 1)
	for l: ModLineDef in lines:
		r -= _line_weight(l)
		if r < 0:
			return l
	return lines[lines.size() - 1]


# --- Casting (08, K0): the line-pool hook (08 §4.3, R15; K3 provides the candidate's AI lines) ---------------------

## provider.call(tag) -> Array[ModLineDef]: extra lines for a resolved tag, drawn with EXTRA_WEIGHT next to the data
## lines (same floor / hype filter, same "not twice in a row" rule). Callable() removes the provider. K0: nobody sets
## one, so pick() is unchanged.
func set_extra_lines(provider: Callable) -> void:
	_extra = provider
	_extra_ids.clear()


func _append_extra(out: Array[ModLineDef], tag: String, floor_index: int, hype: float) -> void:
	if not _extra.is_valid():
		return
	_extra_ids.clear()                         # only the lines of the current draw count (the provider may build new ones)
	var more: Variant = _extra.call(tag)
	if not (more is Array):
		return
	for l: Variant in (more as Array):
		if l is ModLineDef and (l as ModLineDef).fits(floor_index, hype):
			_extra_ids[(l as ModLineDef).get_instance_id()] = true
			out.append(l as ModLineDef)


func _line_weight(l: ModLineDef) -> int:
	return EXTRA_WEIGHT if _extra_ids.has(l.get_instance_id()) else maxi(1, l.weight)
