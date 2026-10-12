extends RefCounted
## Private helper of SleepResolver (02_TECH §0.3: no class_name; preloaded as SleepText): the words of a night — the
## logout dialog (09 §5.1 Nr. 5: what happens where the figure lies), the login summary "Während Sie schliefen …" (09
## §5.4: one screen, the title and at most six lines, a rescue or the Sendeschluss first, in plain words), the daily
## summary (09 §2.9: the absence day by day) and the plan of the local notifications (09 §2.9, §5.6: opt-in, at most
## three a day, quiet hours 22–8 local time, neutral words without guilt or threat of loss). Pure (core): reads the
## state and the events of "away"; the local UTC offset is the caller's parameter (no wall clock, no autoloads), the
## news lines come from mod_lines.json, picked by the event's number (the same night reads the same).

const TITLE: String = "WÄHREND SIE SCHLIEFEN …"
const MAX_LINES: int = 6                    # + the title = the seven lines of 09 §5.4
const DAY_LINES: int = 3                    # lines per day of the daily summary
const NEWS_MAX: int = 2
const DAY: int = 86400
const HOUR: int = 3600
const QUIET_FROM: int = 22 * 3600           # 09 §2.9: no notification 22:00–8:00 local time …
const QUIET_TO: int = 8 * 3600
const QUIET_LAST: int = 21 * 3600 + 59 * 60 # … a warning that would fall into it comes at 21:59
const PER_DAY: int = 3                      # at most three notifications per local day
## Collapse warnings before the collapse of the floor the figure stands on (09 §2.9).
const WARN_NET: PackedInt32Array = [86400, 10800]
const WARN_NO_NET: PackedInt32Array = [86400, 10800, 1800]
const TACTIC_NAMES: Dictionary = {"careful": "Vorsichtig", "support": "Unterstützen", "attack": "Angriff"}
const DANGER_NAMES: PackedStringArray = ["ruhig", "unruhig", "gefährlich"]
const WEEKDAYS: PackedStringArray = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
## The order of the summary (09 §5.4: the end of the season and a rescue first, a clock jump right after them).
enum Prio { OUT, RESCUE, DEATH, CLAMP, MEET, CRASH, RESTED, STATUS, QUIET, OFFER, NOTE, NEWS }
## A Rival:in's note (09 §5.3); picked by the night's "note" roll.
const NOTES: PackedStringArray = [
	"Sie schnarchen in Stereo. Ich bin trotzdem vor Ihnen.",
	"War hier, bin weiter. Sie sehen ausgeruht aus. Genießen Sie es, solange es geht.",
	"Ihr Schlafplatz liegt im Fluchtweg. Ich bin trotzdem durchgekommen. Knapp.",
	"Kleiner Tipp unter Kolleg:innen: Die Treppe ist da lang. Ich war schon dort.",
	"Ich habe Sie nicht geweckt. Das war Fairness. Morgen ist wieder Wettbewerb.",
	"Auf Ihrem Kopfkissen lag ein Krümel. Ich habe ihn als Trophäe mitgenommen.",
]
const UNLUCKY_SAYS: String = "(„Entschuldigung! Die wollten zu mir.“)"
## The outcome of one fight in words (SleepFight.ENDS).
const OUTCOME_WORDS: Dictionary = {"won": "besiegt", "retreat": "Rückzug geglückt", "moved_on": "zog weiter",
	"fled": "entkommen", "lost": "verloren"}


# ======================================================================================================================
# The logout dialog (09 §5.1 Nr. 5)
# ======================================================================================================================

## What the logout dialog says for a figure lying at `cell` now (SleepResolver.place_of): {"kind": safe | corridor |
## boss | stairs | binge, "head" (the first sentence), "lines" (what else matters: the encounters, the next safe room,
## the dress rehearsal, the next collapse), "risk" ("Hier können Sie sterben." Ohne Netz in a corridor from floor 2,
## else ""), "tactics" (the sleeping tactic matters: a corridor of a calendar season), "place" (place_of)}.
static func logout_info(state: GameState, data: GameData, place: Dictionary, tz_sec: int) -> Dictionary:
	var s: SeasonState = state.season
	var fr: FloorRun = state.floor_run
	var kind: String = str(place.get("kind", "corridor"))
	var lines: PackedStringArray = []
	var head: String = ""
	var risk: String = ""
	var tactics: bool = false
	if s.tempo == "binge":
		kind = "binge"
		head = "Am Stück steht die Uhr, solange niemand spielt: Ausloggen ist hier immer sicher."
		lines.append("Keine Begegnungen, kein Ausgeruht. Die Etage wartet auf Sie.")
	elif kind == "safe":
		head = "Safe Room%s: sicher, Sie werden ausgeruht." % _quoted(str(place.get("room_name", "")))
		lines.append(_rested_now(state, data))
	elif kind == "boss" or kind == "stairs":
		head = "%s: Hier kommt keine Streife vorbei." % ("Bossraum" if kind == "boss" else "Treppe")
		lines.append("Ausgeruht gibt es nur im Safe Room.")
	else:
		tactics = true
		var d: int = int(place.get("danger", 0))
		head = "Gang%s (%s): bis zu %d Begegnungen." % [
			_quoted(str(place.get("zone_name", ""))), DANGER_NAMES[clampi(d, 0, DANGER_NAMES.size() - 1)],
			SleepResolver.MAX_ENCOUNTERS]
		var next: Dictionary = place.get("next_safe", {})
		if not next.is_empty():
			var rooms: int = int(next.get("rooms", 0))
			lines.append("Nächster Safe Room%s: %s." % [_quoted(str(next.get("name", ""))),
				_unit(rooms, "Raum", "Räume")])
		if fr != null and fr.index == 1:
			lines.append("Etage 1 ist die Generalprobe: Eine Niederlage kostet hier nichts.")
		elif s.mode == "no_net":
			risk = "Hier können Sie sterben."
	if s.tempo != "binge" and s.result == "" and fr != null and fr.index == s.on_air():
		var left: int = SeasonRules.collapse_in(state)
		if left >= 0 and left <= 2 * DAY:
			lines.append("Etage %d stürzt %s ein.%s" % [fr.index, _when_words(s.utc, s.utc + left, tz_sec),
				" Im Safe Room trägt die Regie Sie gratis hinüber." if kind != "safe" and fr.index > 1 else ""])
	return {"kind": kind, "head": head, "lines": lines, "risk": risk, "tactics": tactics, "place": place}


# ======================================================================================================================
# The login summary (09 §5.4) and the daily summary (09 §2.9)
# ======================================================================================================================

## The summary of the night whose events are `events` (those of "away" in order; a pause "clamp" recorded before it
## may lead them). `auto`: the figure was logged out by the app (closed, crashed, in the background). {"title", "sub"
## (duration, place, danger, tactic), "lines" (at most MAX_LINES, the most important first), "kinds" (the Prio name of
## each line, for the icons), "more" (lines left out), "days" ([{"day", "label", "lines"}] — the daily summary),
## "result" (SeasonState.result after the night), "sec" (the whole absence, a clamp included)}.
static func report(state: GameState, data: GameData, events: Array, tz_sec: int, auto: bool) -> Dictionary:
	var s: SeasonState = state.season
	var away: Dictionary = {}
	var clamp: int = 0
	var rows: Array[Array] = []                # [prio, order, text]
	var meets: Array[Dictionary] = []
	var crash: Dictionary = {}
	var rested: Dictionary = {}
	var programme: int = 0
	var opened: Array[int] = []
	var i: int = 0
	for v: Variant in events:
		i += 1
		var d: Dictionary = _data_of(v)
		match str(d.get("kind", "")):
			"away":
				away = d
			"pause":
				if str(d.get("why", "")) == "clamp":
					clamp += int(d.get("sec", 0))
			"rescue":
				rows.append([Prio.RESCUE, i, _rescue_line(state, d, tz_sec)])
			"death":
				rows.append([Prio.DEATH, i, _death_line(state, data, d)])
			"out", "end":
				rows.append([Prio.OUT, i, _end_line(d)])
			"meet":
				meets.append(d)
			"crash":
				crash = d
			"rested":
				rested = d
			"daily":
				if state.floor_run != null and int(d.get("floor", 0)) == state.floor_run.index:
					programme += 1
			"opened":
				opened.append(int(d.get("floor", 0)))
	var binge: bool = s.tempo == "binge"
	var place_kind: String = str(away.get("place", "safe" if str(away.get("room", "")) != "" else "corridor"))
	if not binge and (not meets.is_empty() or place_kind == "corridor"):
		rows.append([Prio.MEET, 0, _meet_line(state, data, meets)])
	for m: Dictionary in meets:
		match str(m.get("what", "")):
			"note":
				rows.append([Prio.NOTE, 0, "Zettel von %s: „%s“" % [str(m.get("label", "")),
					NOTES[absi(int(m.get("note", 0))) % NOTES.size()]]])
			"offer":
				if str(m.get("item", "")) != "":
					rows.append([Prio.OFFER, 0, "%s hat Ihnen eine Probe hingelegt: %s (im Inventar)." % [
						str(m.get("label", "")), _item_name(data, str(m.get("item", "")))]])
	if not crash.is_empty():
		rows.append([Prio.CRASH, 0, _crash_line(state, data, crash)])
	if not rested.is_empty():
		rows.append([Prio.RESTED, 0, _rested_line(state, rested)])
	var status: String = _status_line(state, programme, opened, tz_sec)
	if status != "":
		rows.append([Prio.STATUS, 0, status])
	if clamp > 0:
		rows.append([Prio.CLAMP, 0, _pause_line(away, clamp)])
	else:
		var quiet: String = _pause_line(away, 0)
		if quiet != "":
			rows.append([Prio.QUIET, 0, quiet])
	var n: int = 0
	for item: Dictionary in CastSim.news(state, data, int(away.get("seq", CastSim.last_seq(state)))):
		if n >= NEWS_MAX:
			break
		var text: String = news_text(data, item)
		if text != "":
			rows.append([Prio.NEWS, n, text])
			n += 1
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	var lines: PackedStringArray = []
	var kinds: PackedStringArray = []
	for r: Array in rows:
		if lines.size() < MAX_LINES:
			lines.append(str(r[2]))
			kinds.append(String(Prio.keys()[int(r[0])]).to_lower())
	var sec: int = int(away.get("sec", 0)) + clamp
	return {"title": TITLE, "sub": _sub_line(away, sec, binge, auto), "lines": lines, "kinds": kinds,
		"more": rows.size() - lines.size(), "days": _days(state, data, events, tz_sec), "result": s.result,
		"sec": sec}


## The text of a news item (CastSim.news): its M.O.D. line (mod_lines.json, the line picked by the event's number) with
## its placeholders; "" without a line.
static func news_text(data: GameData, item: Dictionary) -> String:
	var tag: String = str(item.get("tag", ""))
	var pool: Array[ModLineDef] = data.mod_lines(tag) if data != null else ([] as Array[ModLineDef])
	if pool.is_empty():
		return ""
	var line: ModLineDef = pool[absi(int(item.get("seq", 0))) % pool.size()]
	var ctx: Dictionary = {}
	var raw: Dictionary = item.get("ctx", {})
	for k: Variant in raw.keys():
		ctx[str(k)] = str(raw[k])
	return line.text.format(ctx)


## "(3 Tage 4 Stunden · Gang „Rohrgang“, unruhig · Taktik „Vorsichtig“)" without the brackets.
static func _sub_line(away: Dictionary, sec: int, binge: bool, auto: bool) -> String:
	var parts: PackedStringArray = [duration(sec)]
	var kind: String = str(away.get("place", "corridor"))
	if binge:
		parts.append("Am Stück, die Uhr stand")
	elif kind == "safe":
		parts.append("Safe Room%s, sicher" % _quoted(str(away.get("room_name", ""))))
	elif kind == "boss" or kind == "stairs":
		parts.append("%s, sicher" % ("Bossraum" if kind == "boss" else "Treppe"))
	else:
		var d: int = clampi(int(away.get("danger", 0)), 0, DANGER_NAMES.size() - 1)
		parts.append("Gang%s, %s" % [_quoted(str(away.get("zone_name", ""))), DANGER_NAMES[d]])
		parts.append("Taktik „%s“" % tactic_name(str(away.get("tactic", "careful"))))
	if auto:
		parts.append("automatisch ausgeloggt")
	return " · ".join(parts)


## The encounters in one line: "2 Begegnungen: Hanne Hammerschlag (KI) hielt Wache, 1 Streife besiegt (+1.840 EP,
## 120 Credits, Kabelrest ×2)" — the visitors in their order, an aufgebrachte Streife and the Pechvogel's patrol with
## their outcome, the other patrols counted by outcome; the gains of the controlled figure.
static func _meet_line(state: GameState, data: GameData, meets: Array[Dictionary]) -> String:
	if meets.is_empty():
		return "Keine Begegnungen. Der Gang blieb ruhig."
	var parts: PackedStringArray = []
	var ends: Dictionary = {}
	var exp: int = 0
	var credits: int = 0
	var items: Dictionary = {}
	var order: PackedStringArray = []
	var level_from: int = -1
	var level_to: int = -1
	for m: Dictionary in meets:
		var label: String = str(m.get("label", ""))
		var outcome: String = str(OUTCOME_WORDS.get(str(m.get("outcome", "")), ""))
		match str(m.get("what", "")):
			"watch":
				parts.append("%s hielt Wache" % label)
			"pass":
				parts.append("%s ging vorbei" % label)
			"note":
				parts.append("%s hinterließ einen Zettel" % label)
			"offer":
				parts.append("%s legte ein Angebot hin" % label)
			"unlucky":
				parts.append("%s zog eine Streife vorbei %s%s" % [label, UNLUCKY_SAYS,
					": " + outcome if outcome != "" else ""])
			"patrol":
				if bool(m.get("angry", false)):
					parts.append("eine aufgebrachte Streife%s" % (": " + outcome if outcome != "" else ""))
				elif str(m.get("enc", "")) != "":
					var e: String = str(m.get("outcome", ""))
					ends[e] = int(ends.get(e, 0)) + 1
		exp += int((m.get("exp", {}) as Dictionary).get(state.hero, 0))
		credits += int(m.get("credits", 0))
		for it: Variant in (m.get("items", []) as Array):
			if not items.has(str(it)):
				order.append(str(it))
			items[str(it)] = int(items.get(str(it), 0)) + 1
		var lv: Variant = (m.get("levels", {}) as Dictionary).get(state.hero, null)
		if lv is Array and (lv as Array).size() == 2:
			level_from = int((lv as Array)[0]) if level_from < 0 else level_from
			level_to = int((lv as Array)[1])
	var words: Dictionary = {"won": ["Streife besiegt", "Streifen besiegt"], "retreat": ["Rückzug", "Rückzüge"],
		"moved_on": ["Streife zog weiter", "Streifen zogen weiter"], "fled": ["Mal entkommen", "Mal entkommen"],
		"lost": ["Niederlage", "Niederlagen"]}
	for e: String in ["won", "retreat", "moved_on", "fled", "lost"]:
		var k: int = int(ends.get(e, 0))
		if k > 0:
			parts.append("%d %s" % [k, (words[e] as Array)[0 if k == 1 else 1]])
	var gains: PackedStringArray = []
	if exp > 0:
		gains.append("+%s EP" % num(exp))
	if level_to > level_from and level_from >= 0:
		gains.append("Stufe %d auf %d" % [level_from, level_to])
	if credits > 0:
		gains.append("%s Credits" % num(credits))
	for id: String in order:
		var k2: int = int(items[id])
		gains.append(_item_name(data, id) + (" ×%d" % k2 if k2 > 1 else ""))
	var text: String = "%s: %s" % [_unit(meets.size(), "Begegnung", "Begegnungen"), ", ".join(parts)]
	return text + (" (%s)" % ", ".join(gains) if not gains.is_empty() else "")


static func _rescue_line(state: GameState, d: Dictionary, tz_sec: int) -> String:
	var from: int = int(d.get("from", 0))
	match str(d.get("waived", "")):
		"rehearsal":
			return "Etage %d ist eingestürzt. Generalprobe: Die Regie hat Sie gratis auf Etage %d getragen." % [from,
				int(d.get("floor", from + 1))]
		"sleeper":
			return "Etage %d ist eingestürzt. Die Regie hat Sie im Schlaf hinübergetragen, gratis: Sie lagen im Safe Room." \
				% from
		"week":
			return "Etage %d ist eingestürzt. Die Regie hat Sie gerettet, ohne Gebühr: Die letzte ist keine 7 Tage her." \
				% from
	var s: SeasonState = state.season
	return "Etage %d ist eingestürzt. Die Regie hat Sie gerettet: −%d %% Credits, −%d %% Follower (nächste Gebühr " % [
		from, SeasonRules.RESCUE_CREDITS_PCT, SeasonRules.RESCUE_FOLLOWERS_PCT] + "frühestens %s)." % clock_label(
		s.fee_at + SeasonClock.FEE_GAP_SEC, tz_sec)


static func _death_line(state: GameState, data: GameData, d: Dictionary) -> String:
	var loc: String = str(d.get("location", "start"))
	var to: String = "zum Etageneingang"
	if loc != "start":
		to = "in den Safe Room" + _quoted(_room_name(state, data, loc))
	match str(d.get("waived", "")):
		"rehearsal":
			return "Eine Streife hat Sie im Schlaf besiegt. Generalprobe: kostet nichts, die Sanitäter brachten Sie %s." % to
		"week":
			return "Eine Streife hat Sie im Schlaf besiegt. Die Sanitäter brachten Sie %s, ohne Gebühr diese Woche." % to
	return "Eine Streife hat Sie im Schlaf besiegt. Die Sanitäter brachten Sie %s (−%s Credits)." % [to,
		num(int(d.get("credits", 0)))]


static func _end_line(d: Dictionary) -> String:
	var f: int = int(d.get("floor", 0))
	match str(d.get("why", "")):
		"fallen":
			return "Eine Streife hat Sie im Schlaf besiegt. Ohne Netz heißt das: Sendeschluss für Sie auf Etage %d." % f \
				+ " Ab jetzt sitzen Sie als Studiogast in der ersten Reihe."
		"buried":
			return "Etage %d ist eingestürzt, während Sie schliefen. Ohne Netz heißt das: Sendeschluss für Sie." % f \
				+ " Ab jetzt sitzen Sie als Studiogast in der ersten Reihe."
		"content":
			return "Weiter reicht das Programm noch nicht: Ihre Staffel endet auf Etage %d. Sie waren bis zum Ende dabei." \
				% f
	return "Der letzte Einsturz: Ihre Staffel ist zu Ende. Sie waren bis zum Ende dabei."


static func _crash_line(state: GameState, data: GameData, d: Dictionary) -> String:
	var lifted: Dictionary = d.get("members", {})
	var ids: Array = lifted.keys()
	ids.sort()
	var parts: PackedStringArray = []
	for id: Variant in ids:
		var span: Array = lifted[id]
		parts.append("%s Stufe %d auf %d" % [who(state, data, str(id)), int(span[0]), int(span[1])])
	return "Regie-Crashkurs: %s. Das Aufholpaket liegt im Inventar." % ", ".join(parts)


## "Ausgeruht: 40 % (+35 % in 7 Stunden)" — the hero's pool ([before, after, cap] of the event "rested").
static func _rested_line(state: GameState, d: Dictionary) -> String:
	var members: Dictionary = d.get("members", {})
	var v: Variant = members.get(state.hero, members.values()[0] if not members.is_empty() else null)
	if not (v is Array) or (v as Array).size() < 3:
		return ""
	var cap: int = maxi(1, int((v as Array)[2]))
	var before: int = (int((v as Array)[0]) * 300 + cap) / (2 * cap)       # % of a level (the cap is 150 %), rounded
	var after: int = (int((v as Array)[1]) * 300 + cap) / (2 * cap)
	var hours: int = int(d.get("hours", 0))
	if after >= 150:
		return "Ausgeruht: voll (150 %%)%s. Ihre nächsten Kampf-EP zählen doppelt." % (
			"" if before >= 150 else ", nach %s im Safe Room" % _unit(hours, "Stunde", "Stunden"))
	return "Ausgeruht: %d %% (+%d %% in %s). Ihre nächsten Kampf-EP zählen doppelt." % [after, after - before,
		_unit(hours, "Stunde", "Stunden")]


## "Etage 6 ist auf Sendung · Einsturz in 1 T 20 Std. (Mi 20:00) · neu im Programm: 2 Punkte".
static func _status_line(state: GameState, programme: int, opened: Array[int], tz_sec: int) -> String:
	var s: SeasonState = state.season
	var fr: FloorRun = state.floor_run
	if s.result != "" or fr == null:
		return ""
	var parts: PackedStringArray = []
	if s.tempo == "binge":
		parts.append("Am Stück: Etage %d wartet auf Sie" % fr.index)
	else:
		var left: int = SeasonRules.collapse_in(state)
		var when: String = " (%s)" % clock_label(s.utc + left, tz_sec) if left >= 0 else ""
		if fr.index == s.on_air():
			parts.append("Etage %d ist auf Sendung" % fr.index)
			if left >= 0:
				parts.append("Einsturz in %s%s" % [short(left), when])
		else:
			parts.append("Etage %d, Vorlauf" % fr.index)
			if left >= 0:
				parts.append("Etage %d stürzt in %s ein%s" % [s.on_air(), short(left), when])
		if opened.has(fr.index + 1) and SeasonRules.stairs_refusal(state, null) == "":
			parts.append("Etage %d ist offen" % (fr.index + 1))
	if programme > 0:
		parts.append("neu im Programm: %s" % _unit(programme, "Punkt", "Punkte"))
	return " · ".join(parts)


## The Sendepause of the night and a clock jump over seven days (09 §2.9, §5.5).
static func _pause_line(away: Dictionary, clamp: int) -> String:
	if clamp > 0:
		return "Sie waren %s weg: 7 Tage zählen, der Rest ist Sendepause. Alle Termine verschieben sich." % duration(
			int(away.get("sec", 0)) + clamp)
	var quiet: int = int(away.get("quiet", 0))
	if quiet <= 0:
		return ""
	var refund: int = int(away.get("refund", 0))
	return "Sendepause: %s, die Uhr stand.%s" % [duration(quiet - refund),
		" Sie sind früher zurück: %s gehen zurück ins Budget." % duration(refund) if refund > 0 else ""]


## The daily summary (09 §2.9): the night's events day by day (the season day of each event), up to DAY_LINES each —
## a rescue or the end first, the encounters, the programme, the most important news of that day.
static func _days(state: GameState, data: GameData, events: Array, tz_sec: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var by_day: Dictionary = {}
	var first_t: Dictionary = {}
	for v: Variant in events:
		var d: Dictionary = _data_of(v)
		if not d.has("day"):
			continue
		var day: int = int(d["day"])
		if not by_day.has(day):
			by_day[day] = []
			first_t[day] = int(d.get("t", 0))
		var text: String = ""
		match str(d.get("kind", "")):
			"rescue":
				text = _rescue_line(state, d, tz_sec)
			"death":
				text = _death_line(state, data, d)
			"out", "end":
				text = _end_line(d)
			"meet":
				var one: Array[Dictionary] = [d]
				text = _meet_line(state, data, one)
			"daily":
				text = "Neu im Programm auf Etage %d (Punkt %d)." % [int(d.get("floor", 0)), int(d.get("n", 0))]
			"opened":
				text = "Etage %d ist offen." % int(d.get("floor", 0))
		if text != "":
			(by_day[day] as Array).append(text)
	var seq: int = 0
	for v: Variant in events:
		var d2: Dictionary = _data_of(v)
		if str(d2.get("kind", "")) == "away":
			seq = int(d2.get("seq", 0))
	var news_seen: Dictionary = {}
	for item: Dictionary in CastSim.news(state, data, seq):   # cast time: seconds since day 0 without the pauses
		var day2: int = floori(float(int(item.get("t", 0))) / float(DAY))
		if by_day.has(day2) and not news_seen.has(day2):
			var text2: String = news_text(data, item)
			if text2 != "":
				(by_day[day2] as Array).append(text2)
				news_seen[day2] = true
	var days: Array = by_day.keys()
	days.sort()
	for day3: Variant in days:
		var lines: PackedStringArray = []
		for t: Variant in (by_day[day3] as Array):
			if lines.size() < DAY_LINES:
				lines.append(str(t))
		if lines.is_empty():
			continue
		var label: String = "Vorprogramm" if int(day3) < 0 else "Sendetag %d" % (int(day3) + 1)
		out.append({"day": int(day3), "label": "%s · %s" % [label, date_label(int(first_t[day3]), tz_sec)],
			"lines": lines})
	return out


# ======================================================================================================================
# Notifications (09 §2.9, §5.6)
# ======================================================================================================================

## The local notifications from `now_utc` on (season time = unix seconds), oldest first: [{"at", "kind": collapse |
## open, "text"}]. Only a calendar season that is not over and only what `prefs` allows ({"collapse": bool} — the
## opt-in, default off). Collapse warnings 24 h and 3 h (Ohne Netz also 30 min) before the collapse of the floor the
## figure stands on (it is on air); "neue Etage offen" when the next floor opens while the figure waits in the Vorlauf.
## A warning that would fall into the quiet hours (22–8 local) comes at 21:59 before them, an opening at 8:00 after
## them (it cannot come earlier than it happens); at most PER_DAY per local day (the earliest).
static func notice_plan(state: GameState, _data: GameData, now_utc: int, prefs: Dictionary,
		tz_sec: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s: SeasonState = state.season if state != null else null
	var fr: FloorRun = state.floor_run if state != null else null
	if s == null or fr == null or s.tempo == "binge" or s.result != "" or not bool(prefs.get("collapse", false)):
		return out
	var raw: Array[Dictionary] = []
	var left: int = SeasonRules.collapse_in(state)
	if left >= 0 and fr.index == s.on_air():
		var tc: int = s.utc + left
		for off: int in (WARN_NO_NET if s.mode == "no_net" else WARN_NET):
			var at: int = _before_quiet(tc - off, tz_sec)
			if at > now_utc and at < tc:
				raw.append({"at": at, "kind": "collapse", "text": "Etage %d stürzt %s ein." % [fr.index,
					_when_words(at, tc, tz_sec)]})
	if SeasonRules.stairs_refusal(state, null) == "floor_closed":
		var opens: int = SeasonRules.opens_in(state, fr.index + 1)
		if opens > 0:
			var at2: int = _after_quiet(s.utc + opens, tz_sec)
			if at2 > now_utc:
				raw.append({"at": at2, "kind": "open", "text": "Etage %d ist offen. Die Treppe ist frei." % (fr.index + 1)})
	raw.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	var per_day: Dictionary = {}
	for n: Dictionary in raw:
		var day: int = floori(float(int(n["at"]) + tz_sec) / float(DAY))
		if int(per_day.get(day, 0)) < PER_DAY:
			per_day[day] = int(per_day.get(day, 0)) + 1
			out.append(n)
	return out


static func _before_quiet(at: int, tz_sec: int) -> int:
	var local: int = at + tz_sec
	var sod: int = posmod(local, DAY)
	if sod >= QUIET_FROM:
		return at - (sod - QUIET_LAST)
	if sod < QUIET_TO:
		return at - sod - (DAY - QUIET_LAST)
	return at


static func _after_quiet(at: int, tz_sec: int) -> int:
	var sod: int = posmod(at + tz_sec, DAY)
	if sod >= QUIET_FROM:
		return at + (DAY - sod) + QUIET_TO
	if sod < QUIET_TO:
		return at + (QUIET_TO - sod)
	return at


# ======================================================================================================================
# Words
# ======================================================================================================================

## "3 Tage 4 Stunden", "2 Stunden 5 Minuten", "45 Minuten".
static func duration(sec: int) -> String:
	var t: int = maxi(0, sec)
	var d: int = t / DAY
	var h: int = (t % DAY) / HOUR
	var m: int = (t % HOUR) / 60
	if d > 0:
		return _unit(d, "Tag", "Tage") + (" " + _unit(h, "Stunde", "Stunden") if h > 0 else "")
	if h > 0:
		return _unit(h, "Stunde", "Stunden") + (" " + _unit(m, "Minute", "Minuten") if m > 0 and h < 10 else "")
	return _unit(maxi(1, m), "Minute", "Minuten")


## "1 T 20 Std.", "5 Std. 10 Min.", "12 Min."
static func short(sec: int) -> String:
	var t: int = maxi(0, sec)
	var d: int = t / DAY
	var h: int = (t % DAY) / HOUR
	var m: int = (t % HOUR) / 60
	if d > 0:
		return "%d T %d Std." % [d, h]
	if h > 0:
		return "%d Std. %d Min." % [h, m]
	return "%d Min." % maxi(1, m)


## "Mo 20:00" (local time).
static func clock_label(utc: int, tz_sec: int) -> String:
	var local: int = utc + tz_sec
	var sod: int = posmod(local, DAY)
	return "%s %02d:%02d" % [WEEKDAYS[posmod(floori(float(local) / float(DAY)) + 4, 7)], sod / HOUR, (sod % HOUR) / 60]


## "Mo 12.10." (local date).
static func date_label(utc: int, tz_sec: int) -> String:
	var days: int = floori(float(utc + tz_sec) / float(DAY))
	var ymd: PackedInt32Array = _civil(days)
	return "%s %d.%d." % [WEEKDAYS[posmod(days + 4, 7)], ymd[2], ymd[1]]


## "heute um 20:00", "morgen um 20:00", "am Mi um 20:00" — `at` seen from `from` (local dates).
static func _when_words(from: int, at: int, tz_sec: int) -> String:
	var d0: int = floori(float(from + tz_sec) / float(DAY))
	var d1: int = floori(float(at + tz_sec) / float(DAY))
	var sod: int = posmod(at + tz_sec, DAY)
	var hhmm: String = "%02d:%02d" % [sod / HOUR, (sod % HOUR) / 60]
	if d1 == d0:
		return "heute um " + hhmm
	if d1 == d0 + 1:
		return "morgen um " + hhmm
	return "am %s um %s" % [WEEKDAYS[posmod(d1 + 4, 7)], hhmm]


static func tactic_name(tactic: String) -> String:
	return str(TACTIC_NAMES.get(tactic, TACTIC_NAMES["careful"]))


## 12345 → "12.345" (the German thousands separator, like UiUtil.fmt_int).
static func num(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return ("-" if n < 0 else "") + out


## "Graf Mopsula", the candidate's name (the toasts' wording, Game._level_who).
static func who(state: GameState, data: GameData, member_id: String) -> String:
	var m: PartyMember = state.member(member_id)
	var def: PartyMemberDef = data.party_member(member_id) if data != null and data.has_id("party", member_id) else null
	var n: String = m.display_name if m != null and m.display_name != "" else (def.name if def != null else member_id)
	return def.title + " " + n if def != null and def.title != "" and member_id != "kai" else n


## "Ausgeruht jetzt: 40 %, voll nach 22 Stunden im Safe Room." (the hero).
static func _rested_now(state: GameState, data: GameData) -> String:
	var m: PartyMember = state.member(state.hero)
	if m == null:
		return ""
	var pm: int = SleepResolver.rested_pm(state, data, m)
	if pm >= SleepResolver.RESTED_CAP_PM:
		return "Ausgeruht ist schon voll (150 %)."
	var hours: int = (SleepResolver.RESTED_CAP_PM - pm + SleepResolver.RESTED_HOUR_PM - 1) / SleepResolver.RESTED_HOUR_PM
	return "Ausgeruht jetzt: %d %%, voll nach %s im Safe Room." % [pm / 10, _unit(hours, "Stunde", "Stunden")]


static func _room_name(state: GameState, data: GameData, room_id: String) -> String:
	var layout: FloorLayout = SleepResolver.layout_of(state, data)
	if layout == null:
		return ""
	return str((layout.safe_room_info.get(room_id, {}) as Dictionary).get("name", ""))


static func _item_name(data: GameData, id: String) -> String:
	if data != null and data.has_id("items", id):
		return data.item(id).name
	return id


## " „Kiosk“" — a name in German quotes with its leading space; "" without one.
static func _quoted(name: String) -> String:
	return " „%s“" % name if name != "" else ""


## "1 Raum", "2 Räume".
static func _unit(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]


static func _data_of(v: Variant) -> Dictionary:
	if v is ExploreEvent:
		return (v as ExploreEvent).data
	return v as Dictionary if v is Dictionary else {}


## Days since 1970-01-01 → [year, month, day] (proleptic Gregorian; H. Hinnant's civil_from_days, integer math).
static func _civil(days: int) -> PackedInt32Array:
	var z: int = days + 719468
	var era: int = floori(float(z) / 146097.0)
	var doe: int = z - era * 146097
	var yoe: int = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	var doy: int = doe - (365 * yoe + yoe / 4 - yoe / 100)
	var mp: int = (5 * doy + 2) / 153
	var d: int = doy - (153 * mp + 2) / 5 + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	return PackedInt32Array([yoe + era * 400 + (1 if m <= 2 else 0), m, d])
