extends TestCase
## 11-L1 (11 §1.2, §1.7, §1.12): every Tx.fmt_* in both languages — German character for character what UiUtil and
## SleepText wrote before 11-L1 (references copied below), English as SP-6 says ("1,700", "1.5", "36%", "8:00 PM",
## "Mon, Oct 12", “…”). And the text helpers without a catalog: the msgid, gettext's plural, the data contexts.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SleepText := preload("res://core/season/sleep_text.gd")

var _lang_was: String = "de"


func before_each() -> void:
	_lang_was = Tx.lang()


func after_each() -> void:
	LocaleLoader.apply(_lang_was)                 # the next tests read German again


# --- the references: the formatting before 11-L1 (UiUtil.fmt_int / fmt_signed / fmt_pct, cffb177) -----------------

static func _old_fmt_int(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


static func _old_fmt_signed(n: int) -> String:
	return "+" + _old_fmt_int(n) if n > 0 else _old_fmt_int(n)


static func _old_fmt_pct(p: float, decimals: int = 1) -> String:
	var v: float = clampf(p, 0.0, 1.0) * 100.0
	var s: String = ("%." + str(decimals) + "f") % v
	return s.replace(".", ",") + " %"


func _ints() -> Array[int]:
	var out: Array[int] = [0, 1, -1, 9, 99, 999, 1000, -1000, 1001, 9999, 12345, -12345, 99999, 100000, 999999,
		1000000, 1234567, -7654321, 2147483647, -2147483648, 9007199254740991]
	var rng: RandomNumberGenerator = make_rng(1107)
	for i in 400:
		out.append(rng.randi_range(-3000000, 3000000))
	return out


# --- German: identical ------------------------------------------------------------------------------------------------

func test_german_numbers_are_unchanged() -> void:
	assert_eq(Tx.lang(), "de", "the test runner plays German")
	for v: int in _ints():
		assert_eq(Tx.fmt_int(v), _old_fmt_int(v), "fmt_int(%d)" % v)
		assert_eq(UiUtil.fmt_int(v), _old_fmt_int(v), "UiUtil.fmt_int(%d)" % v)
		assert_eq(Tx.fmt_signed(v), _old_fmt_signed(v), "fmt_signed(%d)" % v)
		assert_eq(UiUtil.fmt_signed(v), _old_fmt_signed(v), "UiUtil.fmt_signed(%d)" % v)
		assert_eq(Tx.fmt_int(v), SleepText.num(v), "SleepText.num(%d)" % v)
	var rng: RandomNumberGenerator = make_rng(36)
	var ps: Array[float] = [0.0, 0.36, 0.174468, 1.5, -0.2, 0.0005, 0.00049, 0.99995, 1.0, 0.125, 0.0125]
	for i in 300:
		ps.append(rng.randf_range(-0.1, 1.1))
	for p: float in ps:
		for d: int in [0, 1, 2, 3]:
			assert_eq(UiUtil.fmt_pct(p, d), _old_fmt_pct(p, d), "UiUtil.fmt_pct(%s, %d)" % [str(p), d])
	assert_eq([UiUtil.fmt_pct(0.36), UiUtil.fmt_pct(0.174468, 2), UiUtil.fmt_pct(1.5)], ["36,0 %", "17,45 %",
		"100,0 %"], "the vectors of test_m6_overlay")


func test_german_times_match_sleep_text() -> void:
	var rng: RandomNumberGenerator = make_rng(2026)
	var secs: Array[int] = [0, 1, 59, 60, 61, 3599, 3600, 3660, 36000, 86399, 86400, 86400 + 20 * 3600, 3 * 86400 + 59,
		-5, 400000]
	for i in 200:
		secs.append(rng.randi_range(0, 9 * 86400))
	for s: int in secs:
		assert_eq(Tx.fmt_duration(s), SleepText.short(s), "fmt_duration(%d) = SleepText.short" % s)
	for i in 300:
		var utc: int = 1760000000 + rng.randi_range(-40000000, 40000000)
		var tz: int = rng.randi_range(-12, 14) * 3600
		var local: int = utc + tz
		var days: int = floori(float(local) / 86400.0)
		var sod: int = posmod(local, 86400)
		var wd: int = posmod(days + 4, 7)
		assert_eq(Tx.fmt_weekday(wd) + " " + Tx.fmt_clock(sod / 60), SleepText.clock_label(utc, tz),
			"clock_label(%d, %d)" % [utc, tz])
		var dt: Dictionary = Time.get_datetime_dict_from_unix_time(days * 86400)
		assert_eq(int(dt["weekday"]), wd, "0 = Sunday, as Time")
		assert_eq(Tx.fmt_wday_date(wd, int(dt["day"]), int(dt["month"])), SleepText.date_label(utc, tz),
			"date_label(%d, %d)" % [utc, tz])
	assert_eq(Tx.quote("Kiosk"), SleepText._quoted("Kiosk").strip_edges(), "„Kiosk“ like SleepText._quoted")


func test_german_vectors() -> void:
	assert_eq([Tx.fmt_int(12345), Tx.fmt_signed(12), Tx.fmt_signed(-3), Tx.fmt_signed(0)], ["12.345", "+12", "-3", "0"])
	assert_eq([Tx.fmt_dec(1500), Tx.fmt_dec(1500, 2), Tx.fmt_dec(1449, 1), Tx.fmt_dec(1450, 1), Tx.fmt_dec(-1450, 1)],
		["1,5", "1,50", "1,4", "1,5", "-1,5"], "per mille, half away from zero")
	assert_eq([Tx.fmt_dec(1234567, 1), Tx.fmt_dec(500, 0), Tx.fmt_dec(499, 0), Tx.fmt_dec(-4, 2), Tx.fmt_dec(7, 4)],
		["1.234,6", "1", "0", "0,00", "0,0070"])
	assert_eq([Tx.fmt_pct(360), Tx.fmt_pct(1000), Tx.fmt_pct(5, 0), Tx.fmt_pct(1234, 2), Tx.fmt_pct(-5)],
		["36,0 %", "100,0 %", "1 %", "123,40 %", "-0,5 %"])
	assert_eq([Tx.fmt_float(1.25, 2), Tx.fmt_float(1234.5, 1), Tx.fmt_float(-0.5, 1), Tx.fmt_float(3.0, 0)],
		["1,25", "1.234,5", "-0,5", "3"])
	assert_eq([Tx.fmt_clock(20 * 60), Tx.fmt_clock(8 * 60 + 5), Tx.fmt_clock(0), Tx.fmt_clock(24 * 60 + 61)],
		["20:00", "08:05", "00:00", "01:01"])
	assert_eq([Tx.fmt_weekday(1), Tx.fmt_weekday(0), Tx.fmt_weekday(7), Tx.fmt_date(12, 10), Tx.fmt_date(5, 3)],
		["Mo", "So", "So", "12.10.", "5.3."])
	assert_eq([Tx.fmt_wday_date(1, 12, 10), Tx.fmt_duration(86400 + 20 * 3600), Tx.fmt_duration(5 * 3600 + 600),
		Tx.fmt_duration(30)], ["Mo 12.10.", "1 T 20 Std.", "5 Std. 10 Min.", "1 Min."])
	assert_eq(Tx.quote("Hallo"), "„Hallo“")


# --- English (SP-6) ---------------------------------------------------------------------------------------------------

func test_english_formats() -> void:
	Tx.use_language("en", null, {})
	assert_eq(Tx.lang(), "en")
	assert_eq([Tx.fmt_int(1700), Tx.fmt_int(12345), Tx.fmt_int(-1234567), Tx.fmt_signed(12), Tx.fmt_signed(-3),
		Tx.fmt_signed(0)], ["1,700", "12,345", "-1,234,567", "+12", "-3", "0"])
	assert_eq([Tx.fmt_dec(1500), Tx.fmt_dec(1234567, 2), Tx.fmt_pct(360), Tx.fmt_pct(1000, 0), Tx.fmt_float(1234.5, 1)],
		["1.5", "1,234.57", "36.0%", "100%", "1,234.5"])
	assert_eq([UiUtil.fmt_int(12345), UiUtil.fmt_signed(1234), UiUtil.fmt_pct(0.36), UiUtil.fmt_pct(0.174468, 2)],
		["12,345", "+1,234", "36.0%", "17.45%"], "UiUtil delegates to Tx")
	assert_eq([Tx.fmt_clock(20 * 60), Tx.fmt_clock(8 * 60 + 5), Tx.fmt_clock(0), Tx.fmt_clock(12 * 60),
		Tx.fmt_clock(12 * 60 + 30), Tx.fmt_clock(23 * 60 + 59), Tx.fmt_clock(60)],
		["8:00 PM", "8:05 AM", "12:00 AM", "12:00 PM", "12:30 PM", "11:59 PM", "1:00 AM"])
	assert_eq([Tx.fmt_weekday(1), Tx.fmt_weekday(6), Tx.fmt_date(12, 10), Tx.fmt_date(1, 1), Tx.fmt_wday_date(1, 12, 10)],
		["Mon", "Sat", "Oct 12", "Jan 1", "Mon, Oct 12"])
	assert_eq([Tx.fmt_duration(86400 + 20 * 3600), Tx.fmt_duration(5 * 3600 + 600), Tx.fmt_duration(720)],
		["1 d 20 h", "5 h 10 min", "12 min"])
	assert_eq(Tx.quote("Hello"), "“Hello”")


func test_formats_cover_every_language() -> void:
	var keys: Array = Tx.FORMATS_DE.keys()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Tx.FORMATS_PATH))
	assert_true(parsed is Dictionary, "locale/formats.json parses")
	if not parsed is Dictionary:
		return
	for code: String in LocaleLoader.codes():
		assert_true((parsed as Dictionary).has(code), "formats.json has a block for " + code)
		var block: Dictionary = (parsed as Dictionary).get(code, {})
		for k: Variant in keys:
			assert_true(block.has(k), "%s: format key %s" % [code, str(k)])
		for k: Variant in block.keys():
			assert_true(keys.has(k), "%s: unknown format key %s" % [code, str(k)])
		assert_len(block.get("weekdays", []), 7, code + ": seven weekdays, Sunday first")
		assert_len(block.get("months", []), 12, code + ": twelve months")
		assert_len(block.get("am_pm", []), 2, code + ": am_pm")
		assert_len(block.get("quotes", []), 2, code + ": opening and closing quote")
		assert_has(Tx.PLURAL_RULES, str(block.get("plural", "")), code + ": a known plural rule")
		assert_has(["24h", "12h"], str(block.get("clock", "")), code + ": clock")
		assert_true(str(block.get("thousands", "")) != str(block.get("decimal", "")), code + ": two separators")
	var de: Dictionary = (parsed as Dictionary).get("de", {})
	for k: Variant in keys:
		assert_eq(de.get(k), Tx.FORMATS_DE[k], "the German block = Tx.FORMATS_DE (the file-free fallback): " + str(k))


# --- texts without a catalog ------------------------------------------------------------------------------------------

func test_texts_without_catalog_are_the_msgids() -> void:
	assert_eq(Tx.t("Gift"), "Gift")
	assert_eq(Tx.t("Gift", "items"), "Gift")
	assert_eq(Tx.t(""), "")
	assert_eq(UiUtil.tr_text("Schließen"), "Schließen")
	assert_eq(Tx.m("Erstschlag!"), "Erstschlag!", "a marker only")
	assert_eq([Tx.n("{count} Kampf", "{count} Kämpfe", 1), Tx.n("{count} Kampf", "{count} Kämpfe", 0),
		Tx.n("{count} Kampf", "{count} Kämpfe", 2)], ["{count} Kampf", "{count} Kämpfe", "{count} Kämpfe"],
		"gettext without a catalog: msgid for 1, msgid_plural otherwise")
	assert_eq([Tx.plural_index(1), Tx.plural_index(0), Tx.plural_index(2), Tx.plural_index(-1)], [0, 1, 1, 1])
	assert_eq([Tx.data_ctx("statuses", "sts_taunt"), Tx.data_ctx("statuses", "sts_taunted"),
		Tx.data_ctx("statuses", "sts_poison"), Tx.data_ctx("origins.hobbies", "hob_cooking")],
		["statuses:sts_taunt", "statuses:sts_taunted", "statuses", "origins.hobbies"], "contexts.json (SP-2)")
	assert_eq(Tx.data("statuses", "sts_taunt", "Provoziert"), "Provoziert")
