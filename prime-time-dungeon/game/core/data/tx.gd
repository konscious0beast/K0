class_name Tx extends RefCounted
## Every player-facing text goes through Tx (11 §1.2). msgid = the German source text; "" context = none.
## Static and free of autoloads (core/data, 02_TECH §0.4): LocaleLoader.apply() hands it the language, the merged
## catalog (base PO + pack PO) and the plural forms; the number, time and date formats come from
## res://locale/formats.json (11 §1.7, SP-6). Without an applied language Tx answers with the msgids and the German
## formats — exactly the output before 11-L1 (gate "deutsch bitgleich", 11 §5.9). Display only (SP-4): nothing Tx
## returns may reach the state, a command, a log or a hash.

const SOURCE_LANG: String = "de"
const FORMATS_PATH: String = "res://locale/formats.json"
const CONTEXTS_PATH: String = "res://locale/contexts.json"
## The separator of msgctxt and msgid in a catalog key (gettext's EOT).
const CTX_SEP: String = "\u0004"
## Plural rules by name (formats.json → "plural"); one_other: form 0 for n = 1, else form 1 (German and English).
const PLURAL_RULES: PackedStringArray = ["one_other"]
## The German formats (11 §1.7): the fallback for every key a language block lacks, and the whole answer when
## formats.json cannot be read — German output never depends on a file.
const FORMATS_DE: Dictionary = {
	"thousands": ".", "decimal": ",", "pct": " %", "clock": "24h", "am_pm": ["", ""],
	"weekdays": ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"],
	"months": ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
	"date": "{day}.{month}.", "weekday_date": "{weekday} {date}",
	"duration": {"days": "{d} T {h} Std.", "hours": "{h} Std. {m} Min.", "minutes": "{m} Min."},
	"quotes": ["„", "“"], "plural": "one_other",
}
const DAY: int = 86400
const HOUR: int = 3600

static var _lang: String = SOURCE_LANG
static var _catalog: Translation = null      # the merged catalog of _lang; null = msgids only
static var _plurals: Dictionary = {}         # "<ctx>\u0004<msgid>" → PackedStringArray (msgstr[n])
static var _all_formats: Dictionary = {}     # formats.json (read once)
static var _fmt: Dictionary = {}             # the block of _lang over FORMATS_DE ({} = not built yet)
static var _thousands: String = "."
static var _decimal: String = ","
static var _pct: String = " %"
static var _contexts: Dictionary = {}        # contexts.json: table → {id: true}
static var _contexts_read: bool = false


# --- texts ------------------------------------------------------------------------------------------------------------

## The translated text (msgid if the catalog has none).
static func t(msgid: String, ctx: String = "") -> String:
	if _catalog == null or msgid == "":
		return msgid
	var s: String = String(_catalog.get_message(msgid, ctx))
	return s if s != "" else msgid


## The plural form for `count` (11 §1.5): msgstr[n] of the catalog, else msgid (n = 1) or `plural` like gettext.
static func n(msgid: String, plural: String, count: int, ctx: String = "") -> String:
	var forms: PackedStringArray = _plurals.get(ctx + CTX_SEP + msgid, PackedStringArray())
	var i: int = plural_index(count)
	if i < forms.size() and forms[i] != "":
		return forms[i]
	return msgid if count == 1 else plural


## A data text (11 §1.4, SP-2): context = the table ("origins.hobbies" for a sublist), "<table>:<id>" for the homonyms
## listed in contexts.json.
static func data(table: String, id: String, text: String) -> String:
	return t(text, data_ctx(table, id))


## The msgctxt of a data text (the extractor writes the same).
static func data_ctx(table: String, id: String) -> String:
	if not _contexts_read:
		_read_contexts()
	var ids: Dictionary = _contexts.get(table, {})
	return table + ":" + id if ids.has(id) else table


## Marker only (11 §1.10): returns the msgid unchanged. Core code marks the German texts it emits (event texts), the
## extractor collects them, the display translates them with t().
static func m(msgid: String) -> String:
	return msgid


## The language of the run: "de" | "en".
static func lang() -> String:
	return _lang


## The plural form index of `count` under the language's rule (formats.json → "plural", one of PLURAL_RULES): so far
## only one_other (German, English); a language with another rule adds its branch here.
static func plural_index(count: int) -> int:
	return 0 if count == 1 else 1


# --- numbers, times, dates (11 §1.7) ----------------------------------------------------------------------------------

## 12345 → de "12.345", en "12,345".
static func fmt_int(v: int) -> String:
	_formats()
	return ("-" if v < 0 else "") + _group(str(absi(v)), _thousands)


## "+12" / "-3" / "0" (a sign for positive values; the minus of fmt_int).
static func fmt_signed(v: int) -> String:
	return ("+" if v > 0 else "") + fmt_int(v)


## Per-mille input (integers in the logic, 02_TECH §13) → de "1,5", en "1.5"; rounded half away from zero.
static func fmt_dec(v_pm: int, decimals: int = 1) -> String:
	return _fixed(v_pm, 3, decimals)


## Per mille of the whole (360 → 36 %) → de "36,0 %", en "36.0%".
static func fmt_pct(p_pm: int, decimals: int = 1) -> String:
	return _fixed(p_pm, 1, decimals) + _pct


## A display-only float with fixed decimals (C rounding of "%.Nf") and the language's separators — for values that are
## floats already (UiUtil.fmt_pct, the replace(".", ",") spots L2 converts).
static func fmt_float(v: float, decimals: int = 1) -> String:
	_formats()
	var s: String = ("%." + str(maxi(decimals, 0)) + "f") % v
	var neg: bool = s.begins_with("-")
	if neg:
		s = s.substr(1)
	var dot: int = s.find(".")
	var whole: String = s if dot < 0 else s.substr(0, dot)
	var out: String = _group(whole, _thousands) if whole.is_valid_int() else whole
	if dot >= 0:
		out += _decimal + s.substr(dot + 1)
	return ("-" if neg else "") + out


## A ratio as a display float (0.36 → de "36,0 %", en "36.0%"); UiUtil.fmt_pct clamps before.
static func fmt_pct_f(ratio: float, decimals: int = 1) -> String:
	return fmt_float(ratio * 100.0, decimals) + _pct


## Minutes of the day → de "20:00", en "8:00 PM".
static func fmt_clock(minutes: int) -> String:
	var mins: int = posmod(minutes, 24 * 60)
	var h: int = mins / 60
	if str(_formats().get("clock", "24h")) == "12h":
		var ap: Array = _formats().get("am_pm", ["AM", "PM"])
		var h12: int = h % 12
		return "%d:%02d %s" % [12 if h12 == 0 else h12, mins % 60, str(ap[0 if h < 12 else 1])]
	return "%02d:%02d" % [h, mins % 60]


## Day of the week, 0 = Sunday (Time.WEEKDAY_SUNDAY) → de "Mo", en "Mon".
static func fmt_weekday(wd: int) -> String:
	var days: Array = _formats().get("weekdays", FORMATS_DE["weekdays"])
	return str(days[posmod(wd, days.size())])


## Day and month (1–12) → de "12.10.", en "Oct 12".
static func fmt_date(day: int, month: int) -> String:
	var months: Array = _formats().get("months", FORMATS_DE["months"])
	return str(_formats().get("date", "{day}.{month}.")).format({"day": day, "month": month,
		"month_name": str(months[clampi(month, 1, 12) - 1])})


## Weekday and date → de "Mo 12.10.", en "Mon, Oct 12" (SP-6).
static func fmt_wday_date(wd: int, day: int, month: int) -> String:
	return str(_formats().get("weekday_date", "{weekday} {date}")).format({"weekday": fmt_weekday(wd),
		"date": fmt_date(day, month)})


## Seconds → de "1 T 20 Std.", "5 Std. 10 Min.", "12 Min."; en "1 d 20 h", "5 h 10 min", "12 min" (at least 1 min).
static func fmt_duration(sec: int) -> String:
	var t_sec: int = maxi(0, sec)
	var d: int = t_sec / DAY
	var h: int = (t_sec % DAY) / HOUR
	var mins: int = (t_sec % HOUR) / 60
	var pat: Dictionary = _formats().get("duration", FORMATS_DE["duration"])
	if d > 0:
		return str(pat.get("days", "{d} T {h} Std.")).format({"d": d, "h": h})
	if h > 0:
		return str(pat.get("hours", "{h} Std. {m} Min.")).format({"h": h, "m": mins})
	return str(pat.get("minutes", "{m} Min.")).format({"m": maxi(1, mins)})


## A quotation in the language's marks: de „s“, en “s”.
static func quote(s: String) -> String:
	var q: Array = _formats().get("quotes", FORMATS_DE["quotes"])
	return str(q[0]) + s + str(q[1])


# --- LocaleLoader's side ----------------------------------------------------------------------------------------------

## Sets the language of the run (LocaleLoader.apply): its merged catalog (null = msgids) and plural forms.
static func use_language(code: String, catalog: Translation, plurals: Dictionary) -> void:
	_lang = code if code != "" else SOURCE_LANG
	_catalog = catalog
	_plurals = plurals
	_fmt = {}
	_formats()


## The formats of a language: its formats.json block over the German ones (tests, i18n tools).
static func formats_of(code: String) -> Dictionary:
	if _all_formats.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FORMATS_PATH)) \
			if FileAccess.file_exists(FORMATS_PATH) else null
		_all_formats = parsed if parsed is Dictionary else {"schema": 1}
	var block: Variant = _all_formats.get(code, {})
	return FORMATS_DE.merged(block if block is Dictionary else {}, true)


# --- internals --------------------------------------------------------------------------------------------------------

static func _formats() -> Dictionary:
	if _fmt.is_empty():
		_fmt = formats_of(_lang)
		_thousands = str(_fmt.get("thousands", "."))
		_decimal = str(_fmt.get("decimal", ","))
		_pct = str(_fmt.get("pct", " %"))
	return _fmt


static func _read_contexts() -> void:
	_contexts_read = true
	_contexts = {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTEXTS_PATH)) \
		if FileAccess.file_exists(CONTEXTS_PATH) else null
	if not parsed is Dictionary:
		return
	for table: Variant in (parsed as Dictionary).keys():
		var ids: Variant = (parsed as Dictionary)[table]
		if str(table) == "schema" or not ids is Array:
			continue
		var id_set: Dictionary = {}
		for id: Variant in ids:
			id_set[str(id)] = true
		_contexts[str(table)] = id_set


## "1234567" → "1.234.567" (thousands separators from the right).
static func _group(digits: String, sep: String) -> String:
	var count: int = digits.length()
	if count <= 3 or sep == "":
		return digits
	var out: String = ""
	for i in count:
		if i > 0 and (count - i) % 3 == 0:
			out += sep
		out += digits[i]
	return out


## v / 10^scale with `decimals` decimals, integer math, rounded half away from zero; separators of the language.
static func _fixed(v: int, scale: int, decimals: int) -> String:
	_formats()
	var d: int = maxi(decimals, 0)
	var mag: int = absi(v)
	var q: int = 0                               # |v| / 10^scale × 10^d
	if d >= scale:
		q = mag * _pow10(d - scale)
	else:
		var div: int = _pow10(scale - d)
		q = (mag + div / 2) / div
	var p: int = _pow10(d)
	var out: String = _group(str(q / p), _thousands)
	if d > 0:
		out += _decimal + str(q % p).pad_zeros(d)
	return ("-" if v < 0 and q != 0 else "") + out


static func _pow10(e: int) -> int:
	var r: int = 1
	for i in e:
		r *= 10
	return r
