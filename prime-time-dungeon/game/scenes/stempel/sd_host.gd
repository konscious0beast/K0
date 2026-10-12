extends RefCounted
## The duel announcer (10 §4.5): M.O.D. hosts the Stempelduell as a game show in her show, the Graf adds footnotes,
## the opponent speaks its own lines, the chat comments show cards, chains and results. Lines come from
## data/stempel/lines.json (SdRulebook.lines_for, placeholders {opp} {ticket} {card} {count} {name}) and go out over
## Events.mod_said (non-blocking: ModDialog shows mod / mopsula / opp lines in the duel's box) and Events.chat_posted
## (the ShowOverlay ticker, with the invented handles of sd_chat_handle). It does NOT use the campaign's ModAnnouncer:
## campaign lines, cooldowns and priorities stay untouched. At most one M.O.D. line per three numbers (10 §4.5) — the
## intro, phase lines, the Durchsage warning, the end and lesson lines pass (`force`). The line choice uses its own
## display RNG (seeded from the duel seed; never part of a hash).

const UiUtil := preload("res://scenes/ui/ui_util.gd")

const NUMBERS_PER_LINE: int = 3
const VOICES: Dictionary = {"mod": &"mod", "mopsula": &"mopsula", "opp": &"opp", "chat": &"chat"}

var book: SdRulebook = null
var ctx: Dictionary = {}                            # {"opp": "Ferdi Durchschlag", "name": "Kai", "ticket": 7}
var said: Array[Dictionary] = []                    # every line said: {"tag", "voice", "text"} (tests)
var mute: bool = false                              # captures / perf: nothing is emitted (said still records)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_ticket: int = -100
var _handles: PackedStringArray = []


func _init(p_book: SdRulebook, seed: int) -> void:
	book = p_book
	_rng.seed = seed
	for l: Dictionary in book.lines_for("sd_chat_handle"):
		_handles.append(str(l["text"]))


## Says a line of `tag` (falls back from "sd_x:y" to "sd_x"). Rate limit: one M.O.D. line per NUMBERS_PER_LINE
## numbers unless `force`; Graf, opponent and chat lines are not limited. Returns the text ("" if none / held back).
func say(tag: String, extra: Dictionary = {}, force: bool = false) -> String:
	var lines: Array[Dictionary] = _lines(tag)
	if lines.is_empty():
		return ""
	var line: Dictionary = lines[_rng.randi_range(0, lines.size() - 1)]
	var voice: String = str(line.get("voice", "mod"))
	var ticket: int = int(extra.get("ticket", ctx.get("ticket", 0)))
	if voice == "mod" and not force and ticket - _last_ticket < NUMBERS_PER_LINE:
		return ""
	if voice == "mod":
		_last_ticket = ticket
	var full: Dictionary = ctx.duplicate()
	full.merge(extra, true)
	full["ticket"] = "%03d" % ticket
	var text: String = UiUtil.glyph_safe(str(line.get("text", "")).format(full))
	said.append({"tag": tag, "voice": voice, "text": text})
	if mute:
		return text
	if voice == "chat":
		var handle: String = _handles[_rng.randi_range(0, _handles.size() - 1)] if not _handles.is_empty() else "chat"
		Events.chat_posted.emit(handle, text, &"hype")
	else:
		Events.mod_said.emit(text, VOICES.get(voice, &"mod") as StringName, tag.trim_prefix("sd_"), false)
	return text


## A line without the rate limit (lessons, the Graf's footnote on request).
func say_now(tag: String, extra: Dictionary = {}) -> String:
	return say(tag, extra, true)


func has(tag: String) -> bool:
	return not _lines(tag).is_empty()


## Tags said so far (tests).
func tags() -> PackedStringArray:
	var out: PackedStringArray = []
	for s: Dictionary in said:
		out.append(str(s["tag"]))
	return out


func _lines(tag: String) -> Array[Dictionary]:
	var t: String = tag
	while t != "":
		var lines: Array[Dictionary] = book.lines_for(t)
		if not lines.is_empty():
			return lines
		var cut: int = t.rfind(":")
		t = t.substr(0, cut) if cut > 0 else ""
	return []
