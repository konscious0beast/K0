extends RefCounted
## The report of the Staffel-Harness (09 §11.6, ST1-I): one line per season run, the summary of a series (per floor:
## minutes, levels against the band, bosses, defeats, rescues; finale rate, credits, logins), and the verdicts against
## the ST1-Gate bands of 09 §11.6 scaled to format 6 (09 Kap. 11.3 decision I-3). Reads the reports of
## tests/tools/season_harness.gd (and the full-run bot's "FULLRUN: season", the same per-floor records). Pure; private
## test helper (no class_name, load() it).

## §3.3 Pensum (minutes): Pflichtweg ≈ x (band x × 0.75 … x × 1.25 for the check), vollständig [from, to].
const PFLICHT_MIN: Dictionary = {1: 20, 2: 30, 3: 45, 4: 60, 5: 60, 6: 60}
const FULL_MIN: Dictionary = {1: [25, 30], 2: [40, 50], 3: [60, 75], 4: [90, 120], 5: [90, 120], 6: [90, 120]}
const PFLICHT_TOL_PM: int = 250            # "≈ x" = x ± 25 %
## 09 §11.6 (Startbänder): typical finale ≥ 80 %, median descent level in band ± 1; 20min ≥ 90 % floors by the stairs,
## descent level ≥ band start − 1; weekend level after each login ≥ band start − 2, ≥ 50 % floors by the stairs, credits
## ≥ 50 % of typical; away2w back in the band within 2 sessions, finale ≥ 60 %.
const TYPICAL_FINALE_PM: int = 800
const SHORT_STAIRS_PM: int = 900
const WEEKEND_STAIRS_PM: int = 500
const WEEKEND_CREDITS_PM: int = 500
const AWAY_FINALE_PM: int = 600


## One line of a run: seed, profile, result, deaths / rescues, the floors (how, minutes, level at departure).
static func run_line(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for f: Dictionary in (r.get("floors", []) as Array):
		parts.append("%d:%s %dm L%d" % [int(f["floor"]), _how_short(str(f["how"])), roundi(float(f["play_sec"]) / 60.0),
			int((f["level_out"] as Array)[0])])
	return "seed %d %s/%s %s %s: %s, deaths %d, rescues %d, level %s, play %d min, credits %d, %s%s" % [
		int(r["seed"]), str(r["tempo"]), str(r["mode"]), str(r["profile"]) if str(r["profile"]) != "" else "-",
		str(r["strategy"]), str(r["result"]) if str(r["result"]) != "" else "—", int(r["deaths"]), int(r["rescues"]),
		str(r["level_end"]), roundi(float(r["play_min"])), int(r["credits_end"]), " ".join(parts),
		(", %d errors" % (r["errors"] as Array).size()) if not (r.get("errors", []) as Array).is_empty() else ""]


## The summary of a series of runs (same options, several seeds).
static func summary(runs: Array) -> Dictionary:
	var n: int = runs.size()
	var finals: int = 0
	var results: Dictionary = {}
	var deaths: Array[int] = []
	var rescues: Array[int] = []
	var credits: Array[int] = []
	var play: Array[int] = []
	var stairs: int = 0
	var left: int = 0
	var errors: int = 0
	var logins_low: int = 0
	var logins: int = 0
	var back_in_band: int = 0
	var away_runs: int = 0
	var ai_first: int = 0
	var compared: int = 0
	var floors: Dictionary = {}
	for r: Dictionary in runs:
		if str(r["result"]) == "finalist":
			finals += 1
		results[str(r["result"])] = int(results.get(str(r["result"]), 0)) + 1
		deaths.append(int(r["deaths"]))
		rescues.append(int(r["rescues"]))
		credits.append(int(r["credits_end"]))
		play.append(roundi(float(r["play_min"])))
		errors += (r.get("errors", []) as Array).size()
		ai_first += int((r.get("cast", {}) as Dictionary).get("ai_first", 0))
		compared += int((r.get("cast", {}) as Dictionary).get("compared", 0))
		for f: Dictionary in (r["floors"] as Array):
			var fi: int = int(f["floor"])
			if not floors.has(fi):
				floors[fi] = {"n": 0, "play": [] as Array[int], "explore": [] as Array[int], "combat": [] as Array[int],
					"combats": [] as Array[int], "lv_in": [] as Array[int], "lv_out": [] as Array[int], "stairs": 0,
					"rescue": 0, "qb_first": 0, "qb_n": 0, "qb_sec": [] as Array[int], "fb_won": 0, "fb_n": 0,
					"fb_sec": [] as Array[int], "defeats": 0, "band": f["band"], "credits": [] as Array[int],
					"pflicht": [] as Array[int], "full": [] as Array[int]}
			var a: Dictionary = floors[fi]
			a["n"] = int(a["n"]) + 1
			(a["play"] as Array[int]).append(roundi(float(f["play_sec"]) / 60.0))
			(a["explore"] as Array[int]).append(roundi(float(f["explore_sec"]) / 60.0))
			(a["combat"] as Array[int]).append(roundi(float(f["combat_sec"]) / 60.0))
			(a["combats"] as Array[int]).append(int(f["combats"]))
			(a["lv_in"] as Array[int]).append(int((f["level_in"] as Array)[0]))
			(a["lv_out"] as Array[int]).append(int((f["level_out"] as Array)[0]))
			(a["credits"] as Array[int]).append(int(f.get("credits_won", 0)))
			for k: String in ["pflicht", "full"]:
				if f.has(k + "_sec"):
					(a[k] as Array[int]).append(roundi(float(f[k + "_sec"]) / 60.0))
			a["defeats"] = int(a["defeats"]) + int(f["defeats"])
			var how: String = str(f["how"])
			if how == "stairs":
				a["stairs"] = int(a["stairs"]) + 1
			elif how == "rescue":
				a["rescue"] = int(a["rescue"]) + 1
			if fi < 6:
				left += 1 if how == "stairs" or how == "rescue" else 0
				stairs += 1 if how == "stairs" else 0
			var qb: Array = f["qb"]
			if not qb.is_empty():
				a["qb_n"] = int(a["qb_n"]) + 1
				a["qb_first"] = int(a["qb_first"]) + (1 if str((qb[0] as Dictionary)["outcome"]) == "victory" else 0)
				for b: Variant in qb:
					(a["qb_sec"] as Array[int]).append(roundi(float((b as Dictionary)["sec"])))
			for b2: Variant in (f["fb"] as Array):
				a["fb_n"] = int(a["fb_n"]) + 1
				a["fb_won"] = int(a["fb_won"]) + (1 if str((b2 as Dictionary)["outcome"]) == "victory" else 0)
				(a["fb_sec"] as Array[int]).append(roundi(float((b2 as Dictionary)["sec"])))
		var away_seen: bool = false
		var after_away: int = 0
		for l: Dictionary in (r.get("logins", []) as Array):
			logins += 1
			var lo: int = int((l["band"] as Array)[0])
			if int((l["level"] as Array)[0]) < lo - 2:
				logins_low += 1
			if int(l["absence"]) >= 7 * 86400:
				away_seen = true
				after_away = 0
			elif away_seen:
				after_away += 1
				if after_away == 2 and int((l["level"] as Array)[0]) >= lo:
					back_in_band += 1
		if away_seen:
			away_runs += 1
	var fl: Dictionary = {}
	for fi: Variant in floors.keys():
		var a: Dictionary = floors[fi]
		fl[fi] = {"n": a["n"], "play_min": median(a["play"]), "explore_min": median(a["explore"]),
			"combat_min": median(a["combat"]), "combats": median(a["combats"]), "level_in": median(a["lv_in"]),
			"level_out": median(a["lv_out"]), "level_out_min": _min(a["lv_out"]), "band": a["band"],
			"stairs": a["stairs"], "rescue": a["rescue"], "defeats": a["defeats"],
			"qb_first_pm": int(a["qb_first"]) * 1000 / maxi(1, int(a["qb_n"])), "qb_sec": median(a["qb_sec"]),
			"fb": "%d/%d" % [int(a["fb_won"]), int(a["fb_n"])], "fb_sec": median(a["fb_sec"]),
			"credits": median(a["credits"]), "pflicht_min": median(a["pflicht"]), "pflicht_n": (a["pflicht"] as Array).size(),
			"full_min": median(a["full"]), "full_n": (a["full"] as Array).size()}
	return {"n": n, "finale_pm": finals * 1000 / maxi(1, n), "results": results, "deaths": median(deaths),
		"deaths_sum": _sum(deaths), "rescues": median(rescues), "rescues_sum": _sum(rescues),
		"credits_end": median(credits), "play_min": median(play), "stairs_pm": stairs * 1000 / maxi(1, left),
		"logins": logins, "logins_low": logins_low, "away_runs": away_runs, "back_in_band": back_in_band,
		"ai_first_pm": ai_first * 1000 / maxi(1, compared), "errors": errors, "floors": fl}


## The lines of a summary: the season, then one per floor.
static func summary_lines(s: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append(("%d runs: finale %.0f %%, %s, deaths %s (Σ %d), rescues %s (Σ %d), floors by stairs %.0f %%, "
		+ "credits %s, play %s min, logins %d (%d below band − 2), AI first %.0f %%, errors %d") % [int(s["n"]),
		float(s["finale_pm"]) / 10.0, JSON.stringify(s["results"]), str(s["deaths"]),
		int(s["deaths_sum"]), str(s["rescues"]), int(s["rescues_sum"]), float(s["stairs_pm"]) / 10.0,
		str(s["credits_end"]), str(s["play_min"]), int(s["logins"]), int(s["logins_low"]),
		float(s["ai_first_pm"]) / 10.0, int(s["errors"])])
	var keys: Array = (s["floors"] as Dictionary).keys()
	keys.sort()
	for fi: Variant in keys:
		var f: Dictionary = s["floors"][fi]
		out.append(("  floor %d (band %d–%d, n %d): play %s min (explore %s, combat %s), Pflichtweg %s min (%d), "
			+ "vollständig %s min (%d), combats %s, level %s → %s (min %d), stairs %d rescue %d, defeats %d, "
			+ "Revier-Boss first try %.0f %% (%s s), Etagenboss %s (%s s), credits %s") % [int(fi),
			int((f["band"] as Array)[0]), int((f["band"] as Array)[1]), int(f["n"]), str(f["play_min"]),
			str(f["explore_min"]), str(f["combat_min"]), str(f["pflicht_min"]), int(f["pflicht_n"]), str(f["full_min"]),
			int(f["full_n"]), str(f["combats"]), str(f["level_in"]), str(f["level_out"]), int(f["level_out_min"]),
			int(f["stairs"]), int(f["rescue"]), int(f["defeats"]), float(f["qb_first_pm"]) / 10.0, str(f["qb_sec"]),
			str(f["fb"]), str(f["fb_sec"]), str(f["credits"])])
	return out


## Verdicts "ok|OUT <series> <check>: <value> (band)" for the series of a harness call (09 §11.6, format 6).
static func band_report(series: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	var typical_credits: float = -1.0
	for se: Dictionary in series:
		if str(se["profile"]) == "typical" and str(se["mode"]) == "net":
			typical_credits = float((se["summary"] as Dictionary)["credits_end"])
	for se: Dictionary in series:
		var s: Dictionary = se["summary"]
		var name: String = "%s/%s" % [str(se["mode"]), str(se["profile"]) if str(se["profile"]) != "" else "binge"]
		var fl: Dictionary = s["floors"]
		match str(se["profile"]):
			"typical":
				if str(se["mode"]) == "net":
					out.append(_v(int(s["finale_pm"]) >= TYPICAL_FINALE_PM, name, "Finale Mit Netz",
						"%.0f %%" % (float(s["finale_pm"]) / 10.0), "≥ 80 %"))
				for fi: Variant in _sorted(fl):
					var f: Dictionary = fl[fi]
					if int(fi) >= 6 or int(f["stairs"]) == 0:
						continue
					var b: Array = f["band"]
					var lv: float = float(f["level_out"])
					out.append(_v(lv >= float(b[0]) - 1.0 and lv <= float(b[1]) + 1.0, name,
						"Median-Stufe beim Abstieg, Etage %d" % int(fi), str(lv), "%d–%d" % [int(b[0]) - 1, int(b[1]) + 1]))
				out.append_array(pensum_report(fl, name, true))
			"20min":
				out.append(_v(int(s["stairs_pm"]) >= SHORT_STAIRS_PM, name, "Etagen per Treppe",
					"%.0f %%" % (float(s["stairs_pm"]) / 10.0), "≥ 90 %"))
				for fi: Variant in _sorted(fl):
					var f2: Dictionary = fl[fi]
					if int(fi) >= 6 or int(f2["stairs"]) == 0:
						continue
					out.append(_v(int(f2["level_out_min"]) >= int((f2["band"] as Array)[0]) - 1, name,
						"Stufe beim Abstieg (min), Etage %d" % int(fi), str(f2["level_out_min"]),
						"≥ %d" % (int((f2["band"] as Array)[0]) - 1)))
			"weekend":
				out.append(_v(int(s["logins_low"]) == 0, name, "Stufe nach jedem Login ≥ Bandanfang − 2",
					"%d von %d darunter" % [int(s["logins_low"]), int(s["logins"])], "0"))
				out.append(_v(int(s["stairs_pm"]) >= WEEKEND_STAIRS_PM, name, "Etagen per Treppe",
					"%.0f %%" % (float(s["stairs_pm"]) / 10.0), "≥ 50 %"))
				if typical_credits > 0.0:
					var ratio: float = float(s["credits_end"]) / typical_credits
					out.append(_v(ratio * 1000.0 >= WEEKEND_CREDITS_PM, name, "Credits am Staffelende / typical",
						"%.0f %%" % (ratio * 100.0), "≥ 50 %"))
			"away2w":
				out.append(_v(int(s["back_in_band"]) == int(s["away_runs"]) and int(s["away_runs"]) > 0, name,
					"nach der Rückkehr binnen 2 Sitzungen im Band", "%d von %d" % [int(s["back_in_band"]),
					int(s["away_runs"])], "alle"))
				if str(se["mode"]) == "net":
					out.append(_v(int(s["finale_pm"]) >= AWAY_FINALE_PM, name, "Finale",
						"%.0f %%" % (float(s["finale_pm"]) / 10.0), "≥ 60 %"))
			"":
				out.append_array(pensum_report(fl, name, false))
		if int(s["errors"]) > 0:
			out.append("OUT %s: %d errors of the core bot (refused commands, unreachable goals)" % [name,
				int(s["errors"])])
	return out


## The Pensum of a series against 09 §3.3 per floor (the medians of the marks "pflicht_sec" / "full_sec" of the runs
## that reached them): Pflichtweg ≈ x (± 25 %), vollständig [from, to]. `verdict`: ok/OUT lines (the typical profile's
## gate), else "info" lines (Am Stück, the other profiles).
static func pensum_report(fl: Dictionary, name: String, verdict: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	for fi: Variant in _sorted(fl):
		var f: Dictionary = fl[fi]
		var x: float = float(PFLICHT_MIN.get(int(fi), 60))
		var tol: float = x * float(PFLICHT_TOL_PM) / 1000.0
		var r: Array = FULL_MIN.get(int(fi), [90, 120])
		for k: String in ["pflicht", "full"]:
			var what: String = "Pflichtweg" if k == "pflicht" else "vollständig"
			if int(f[k + "_n"]) == 0:
				out.append("info %s %s Etage %d: von keinem Lauf erreicht" % [name, what, int(fi)])
				continue
			var m: float = float(f[k + "_min"])
			var ok: bool = (m >= x - tol and m <= x + tol) if k == "pflicht" else (m >= float(r[0]) and m <= float(r[1]))
			var check: String = "%s Etage %d (%d von %d Läufen)" % [what, int(fi), int(f[k + "_n"]), int(f["n"])]
			var band: String = ("≈ %d ± 25 %%" % int(x)) if k == "pflicht" else ("%d–%d" % [int(r[0]), int(r[1])])
			if verdict:
				out.append(_v(ok, name, check, "%.0f min" % m, band))
			else:
				out.append("info %s %s: %.0f min (§3.3: %s)" % [name, check, m, band])
	return out


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s: Array = values.duplicate()
	s.sort()
	var n: int = s.size()
	return float(s[n / 2]) if n % 2 == 1 else (float(s[n / 2 - 1]) + float(s[n / 2])) / 2.0


static func _v(ok: bool, name: String, check: String, value: String, band: String) -> String:
	return "%s %s %s: %s (Band %s)" % ["ok" if ok else "OUT", name, check, value, band]


static func _how_short(how: String) -> String:
	return {"stairs": "T", "rescue": "R", "finale": "F", "end": "E", "out": "X"}.get(how, how)


static func _sorted(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k


static func _sum(a: Array[int]) -> int:
	var s: int = 0
	for x: int in a:
		s += x
	return s


static func _min(a: Array) -> int:
	var m: int = 1 << 30
	for x: Variant in a:
		m = mini(m, int(x))
	return m if not a.is_empty() else 0
