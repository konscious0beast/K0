extends SceneTree
## Entry of the Staffel-Harness (09 §11.6, ST1-I): tools/season_harness.sh runs
##   godot --headless --path game -s res://tests/tools/season_harness_main.gd -- [options]
## and the headless level (tests/tools/season_harness.gd) plays whole seasons in the core with the core bot. No
## class_name / autoload identifiers here (02_TECH §13.2 rule 4): the harness is loaded with load().
##
## Options: --format=6|12|18 (6; 12 and 18 are refused until ST1-C2, 09 decision I-2) --tempo=calendar|binge (calendar)
##   --profile=typical|20min|weekend|away2w|all (typical; calendar) --mode=net|no_net|both (net)
##   --strategy=auto|thorough|typical|rush (auto in the calendar, thorough Am Stück) --pace=human|fast (human)
##   --fighter=bot|autopilot (bot) --seeds=N (10) --first-seed=K (0) --speed=dev|<n> (accepted for the ST1-gate command
##   of 09 §11.6; the harness's time lapse is the profile's sessions, the speed changes nothing) --time=<key>:<sec>,…
##   (overrides of the time model, calibration) --out=<file.json> --runs (every run's report in the JSON)
##   --part (a worker of season_harness.sh --jobs: run lines and the JSON with every run, no summary)
##   --merge=<file.json>,… (no runs: the summary and the verdicts of the workers' JSON files)
## Output: "HARNESS: run …" per season, "HARNESS: summary …" per series, "HARNESS-BAND: ok|OUT|info …" verdicts against
## the ST1-Gate bands of 09 §11.6 scaled to format 6, "HARNESS: done …". Exit 0; 2 bad arguments; 3 "HARNESS: refused …"
## (formats 12 / 18).

const HARNESS: String = "res://tests/tools/season_harness.gd"
const REPORT: String = "res://tests/tools/season_report.gd"
const PROFILES: PackedStringArray = ["typical", "20min", "weekend", "away2w"]
const DEFS: Dictionary = {6: "ssn_basis", 12: "ssn_akt2", 18: "ssn_akt3"}


func _initialize() -> void:
	var o: Dictionary = {"format": 6, "tempo": "calendar", "profile": "typical", "mode": "net", "strategy": "",
		"pace": "human", "fighter": "bot", "seeds": 10, "first": 0, "time": {}, "out": "", "runs": false, "part": false,
		"merge": ""}
	for a: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		var v: String = kv[1] if kv.size() == 2 else ""
		match kv[0]:
			"format", "seeds", "first-seed":
				if not v.is_valid_int():
					_bad(a)
					return
				o["first" if kv[0] == "first-seed" else kv[0]] = v.to_int()
			"tempo", "profile", "mode", "strategy", "pace", "fighter", "out", "merge":
				o[kv[0]] = v
			"speed":
				pass
			"time":
				for pair: String in v.split(",", false):
					var p: PackedStringArray = pair.split(":")
					if p.size() != 2 or not p[1].is_valid_float():
						_bad(a)
						return
					(o["time"] as Dictionary)[p[0]] = p[1].to_float()
			"runs", "part":
				o[kv[0]] = true
			_:
				_bad(a)
				return
	await process_frame
	var rep: GDScript = load(REPORT)
	var t0: int = Time.get_ticks_msec()
	var series: Array = []
	if str(o["merge"]) != "":
		series = _merged(str(o["merge"]).split(",", false))
		if series.is_empty():
			_bad("--merge=%s (no series)" % str(o["merge"]))
			return
	else:
		var h: GDScript = load(HARNESS)
		var data: Object = (load("res://core/data/game_data.gd") as GDScript).new()
		if not bool(data.call("load_dir", "res://data")):
			printerr("Assertion failed: season_harness_main: data invalid: %s" % str(data.get("errors")))
			quit(1)
			return
		var def_id: String = str(DEFS.get(int(o["format"]), ""))
		if def_id == "" or not ["calendar", "binge"].has(str(o["tempo"])) or not ["net", "no_net", "both"].has(
				str(o["mode"])) or (str(o["profile"]) != "all" and not PROFILES.has(str(o["profile"]))):
			_bad("--format/--tempo/--mode/--profile")
			return
		var profiles: PackedStringArray = PROFILES if str(o["profile"]) == "all" else [str(o["profile"])]
		var modes: PackedStringArray = ["net", "no_net"] if str(o["mode"]) == "both" else [str(o["mode"])]
		if str(o["tempo"]) == "binge":
			profiles = [""]
		for mode: String in modes:
			for prof: String in profiles:
				var runs: Array = []
				for i in int(o["seeds"]):
					var opts: Dictionary = {"def": def_id, "tempo": str(o["tempo"]), "mode": mode, "pace": str(o["pace"]),
						"fighter": str(o["fighter"]), "time": o["time"]}
					if prof != "":
						opts["profile"] = prof
					if str(o["strategy"]) != "":
						opts["strategy"] = str(o["strategy"])
					var r: Dictionary = h.call("run", data, int(o["first"]) + i, opts)
					if bool(r.get("refused", false)):
						print("HARNESS: refused %s" % str(r["error"]))
						quit(3)
						return
					if r.has("error"):
						_bad(str(r["error"]))
						return
					runs.append(r)
					print("HARNESS: run " + str(rep.call("run_line", r)))
					for e: Variant in (r.get("errors", []) as Array):
						print("HARNESS:   error %s" % str(e))
				series.append({"mode": mode, "profile": prof, "runs": runs})
	var verdicts: PackedStringArray = []
	if not bool(o["part"]):
		for se: Dictionary in series:
			se["summary"] = rep.call("summary", se["runs"])
			for line: String in (rep.call("summary_lines", se["summary"]) as PackedStringArray):
				print("HARNESS: summary %s/%s %s" % [str(se["mode"]), str(se["profile"]) if str(se["profile"]) != ""
					else "binge", line])
		verdicts = rep.call("band_report", series)
	var outs: int = 0
	for v: String in verdicts:
		print("HARNESS-BAND: " + v)
		if v.begins_with("OUT"):
			outs += 1
	var sec: float = float(Time.get_ticks_msec() - t0) / 1000.0
	if str(o["out"]) != "":
		var keep: Array = []
		for se: Dictionary in series:
			var c: Dictionary = se.duplicate()
			if not bool(o["runs"]) and not bool(o["part"]):
				c["runs"] = []
			keep.append(c)
		var f: FileAccess = FileAccess.open(str(o["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"options": o, "series": keep, "bands": Array(verdicts), "sec": sec}, "\t")
				+ "\n")
			f.close()
	print("HARNESS: done in %.1f s (%d verdicts, %d off band)" % [sec, verdicts.size(), outs])
	quit(0)


## The series of the workers' JSON files (season_harness.sh --jobs), runs of the same mode and profile together in
## seed order.
func _merged(files: PackedStringArray) -> Array:
	var by_key: Dictionary = {}
	var order: Array[String] = []
	for path: String in files:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var j: Variant = JSON.parse_string(f.get_as_text())
		if not (j is Dictionary):
			continue
		for se: Variant in ((j as Dictionary).get("series", []) as Array):
			var d: Dictionary = se
			var key: String = "%s/%s" % [str(d["mode"]), str(d["profile"])]
			if not by_key.has(key):
				by_key[key] = {"mode": str(d["mode"]), "profile": str(d["profile"]), "runs": []}
				order.append(key)
			(by_key[key]["runs"] as Array).append_array(d.get("runs", []) as Array)
	var out: Array = []
	for key: String in order:
		var se2: Dictionary = by_key[key]
		(se2["runs"] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["seed"]) < int(b["seed"]))
		out.append(se2)
	return out


func _bad(a: String) -> void:
	printerr("season_harness_main: bad argument %s" % a)
	quit(2)
