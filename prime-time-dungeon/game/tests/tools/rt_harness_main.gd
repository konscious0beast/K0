extends SceneTree
## Entry of the real-time balance harness (07 §11.4, R4): tools/rt_balance.sh runs
##   godot --headless --path game -s res://tests/tools/rt_harness_main.gd -- [options]
## and the harness (tests/tools/rt_harness.gd) plays the floor-1 encounters on the real RtSim with RtBotPlayer.
## No class_name / autoload identifiers here (02_TECH §13.2 rule 4): the harness is loaded with load().
##
## Options: --seeds=N (20) --first-seed=K (0) --hero=kai|mopsula|both (both) --liga=0|1|2|all (0)
##   --profile=typical|perfect|sloppy|autopilot|<list>|all (typical; autopilot = the sim's AI plays the hero, the
##   yardstick "a perfect person beats the AI") --encounters=all|regular|bosses|showboss|<id,id,…> (all)
##   --partner-preset=attack|support|careful ("" = the default tactic) --out=<file.json>
##   --sequence (the floor in order, 07 §11.4 "Etagenfolge") --perf (µs per RtSim.step with real data, 07 §3.15)
##   --set=<enemy|skill|bal>:<id>.<path>=<json> (repeatable tuning probe on the loaded data, rt_harness.tune)
##   --strict-bands (exit 1 when a verdict is out of band; R5b turns it on for the nightly once `typical` is
##   calibrated, 07 §11.3)
## Output: one "RT: …" line per series (stdout), "RT-SEQ: …" lines in sequence mode, "RT-PERF: …" in perf mode,
## "RT-BAND: ok|OUT …" verdicts against the 07 §11.1 bands (rt_harness.band_report), "RT: done …" at the end
## ("RT: FAILED …" before it with --strict-bands); the JSON file holds every series with its numbers and seeds.

const HARNESS: String = "res://tests/tools/rt_harness.gd"


func _initialize() -> void:
	var o: Dictionary = {"seeds": 20, "first": 0, "hero": "both", "liga": "0", "profile": "typical", "enc": "all",
		"preset": "", "out": "", "sequence": false, "perf": false, "strict": false}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			o["seeds"] = maxi(1, int(a.trim_prefix("--seeds=")))
		elif a.begins_with("--first-seed="):
			o["first"] = maxi(0, int(a.trim_prefix("--first-seed=")))
		elif a.begins_with("--hero="):
			o["hero"] = a.trim_prefix("--hero=")
		elif a.begins_with("--liga="):
			o["liga"] = a.trim_prefix("--liga=")
		elif a.begins_with("--profile="):
			o["profile"] = a.trim_prefix("--profile=")
		elif a.begins_with("--encounters="):
			o["enc"] = a.trim_prefix("--encounters=")
		elif a.begins_with("--partner-preset="):
			o["preset"] = a.trim_prefix("--partner-preset=")
		elif a.begins_with("--out="):
			o["out"] = a.trim_prefix("--out=")
		elif a == "--sequence":
			o["sequence"] = true
		elif a == "--perf":
			o["perf"] = true
		elif a == "--strict-bands":
			o["strict"] = true
		elif a.begins_with("--set="):
			o["set"] = (o.get("set", []) as Array) + [a.trim_prefix("--set=")]
		else:
			printerr("Assertion failed: rt_harness_main: unknown argument %s" % a)
			quit(2)
			return
	await process_frame
	var h: GDScript = load(HARNESS)
	var data: Object = (load("res://core/data/game_data.gd") as GDScript).new()
	if not bool(data.call("load_dir", "res://data")):
		printerr("Assertion failed: rt_harness_main: data invalid: %s" % str(data.get("errors")))
		quit(1)
		return
	for spec: Variant in (o.get("set", []) as Array):
		var why: String = h.call("tune", data, str(spec))
		if why != "":
			printerr("Assertion failed: rt_harness_main: --set=%s: %s" % [str(spec), why])
			quit(2)
			return
		print("RT: tuned %s" % str(spec))
	var t0: int = Time.get_ticks_msec()
	var heroes: PackedStringArray = ["kai", "mopsula"] if str(o["hero"]) == "both" else [str(o["hero"])]
	var report: Dictionary = {"seeds": o["seeds"], "first_seed": o["first"], "series": [], "sequence": [], "perf": {}}
	if bool(o["perf"]):
		var p: Dictionary = h.call("perf", data, 600)
		report["perf"] = p
		print("RT-PERF: %d steps, %d party + %d enemies, %.1f shapes avg: median %.1f µs, mean %.1f µs, p90 %.1f µs"
			% [int(p["steps"]), int(p["party"]), int(p["enemies"]), float(p["shapes"]), float(p["median_us"]),
			float(p["mean_us"]), float(p["p90_us"])])
	elif bool(o["sequence"]):
		for hero: String in heroes:
			var runs: Array = []
			for i in int(o["seeds"]):
				runs.append(h.call("sequence", data, hero, int(o["first"]) + i, str(o["profile"])))
			var s: Dictionary = h.call("sequence_summary", runs)
			s["hero"] = hero
			s["profile"] = str(o["profile"])
			(report["sequence"] as Array).append(s)
			print("RT-SEQ: " + str(h.call("sequence_line", s)))
	else:
		var ligas: Array = [0, 1, 2] if str(o["liga"]) == "all" else [int(o["liga"])]
		var profiles: PackedStringArray = ["perfect", "typical", "sloppy", "autopilot"] if str(o["profile"]) == "all" \
			else str(o["profile"]).split(",", false)
		var encs: PackedStringArray = h.call("encounter_list", str(o["enc"]))
		for enc_id: String in encs:
			for hero: String in heroes:
				for liga: int in ligas:
					for prof: String in profiles:
						var s: Dictionary = h.call("series", data, enc_id, hero, liga, int(o["seeds"]),
							{"profile": prof, "partner_preset": str(o["preset"]), "autopilot": prof == "autopilot"},
							int(o["first"]))
						(report["series"] as Array).append(s)
						print("RT: " + str(h.call("line", s)))
	var verdicts: PackedStringArray = h.call("band_report", report["series"], report["sequence"])
	var outs: int = 0
	for v: String in verdicts:
		print("RT-BAND: " + v)
		if v.begins_with("OUT"):
			outs += 1
	if not verdicts.is_empty():
		print("RT-BAND: %d checked, %d out of band" % [verdicts.size(), outs])
	report["bands"] = Array(verdicts)
	report["sec"] = float(Time.get_ticks_msec() - t0) / 1000.0
	if str(o["out"]) != "":
		var f: FileAccess = FileAccess.open(str(o["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t") + "\n")
			f.close()
	if bool(o["strict"]) and outs > 0:
		print("RT: FAILED %d verdicts out of band (--strict-bands)" % outs)
	print("RT: done in %.1f s" % float(report["sec"]))
	quit(1 if bool(o["strict"]) and outs > 0 else 0)
