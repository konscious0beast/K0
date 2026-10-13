extends SceneTree
## The Godot side of tools/i18n.sh (11 §1.11). An -s entry script: no class_name or autoload identifiers here
## (02_TECH §13.2 rule 4) — the tool scripts are loaded after the first frame.
## Usage: godot --headless --path game -s res://tests/tools/i18n/i18n_tool.gd -- <command> [options]
##   extract [--out=<dir>]          the four POT files (default res://locale/pot) + the report (dynamic calls, msgids in
##                                  several domains or contexts)
##   check-pot [--pot=<dir>]        the POT files are what extract writes now (exit 1 with the first differences)
##   rules [--lang=en] [--dir=<d>]  the PO rules (validators/po.gd) over <d>/<lang>/*.po (default res://locale)
##   pack-rules [--packs=<dir>]     the same rules over every <packs>/<id>/locale/<lang>.po (default res://packs; an
##                                  override keeps the limit of its base entry; the header names the file's language)
##   sync [--lang=en] [--pot=<dir>] every POT msgid is in the PO (merged) and the PO has no active entry the POT lacks
##   stats [--lang=en] [--pack=<dir>]  coverage per domain and context; with a pack (a folder with data/*.json and
##                                  locale/<lang>.po): the base msgids that still name what the pack renamed (11 §3.6)
##   lint [--file=<res path>]       the German literals outside Tx per file (test_11_literals) and its PENDING table
## Exit code 0 = fine, 1 = findings, 2 = usage.

const EXTRACTOR: String = "res://tests/tools/i18n/extractor.gd"
const RULES: String = "res://core/data/validators/po.gd"
const PO_FILE: String = "res://core/data/po_file.gd"
const LINT: String = "res://tests/tools/i18n/literal_lint.gd"
const POT_DIR: String = "res://locale/pot"
const LOCALE_DIR: String = "res://locale"
const PACKS_DIR: String = "res://packs"


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cmd: String = args[0] if not args.is_empty() else ""
	var opts: Dictionary = {}
	for a: String in args.slice(1):
		if a.begins_with("--") and a.contains("="):
			opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var code: int = 2
	match cmd:
		"extract":
			code = _extract(str(opts.get("out", POT_DIR)))
		"check-pot":
			code = _check_pot(str(opts.get("pot", POT_DIR)))
		"rules":
			code = _rules(str(opts.get("lang", "en")), str(opts.get("dir", LOCALE_DIR)))
		"pack-rules":
			code = _pack_rules(str(opts.get("packs", PACKS_DIR)))
		"sync":
			code = _sync(str(opts.get("lang", "en")), str(opts.get("pot", POT_DIR)), str(opts.get("dir", LOCALE_DIR)))
		"stats":
			code = _stats(str(opts.get("lang", "en")), str(opts.get("pack", "")), str(opts.get("dir", LOCALE_DIR)))
		"lint":
			code = _lint(str(opts.get("file", "")))
		_:
			printerr("i18n_tool: unknown command '%s' (extract | check-pot | rules | pack-rules | sync | stats | lint)"
				% cmd)
	quit(code)


func _run_extractor() -> RefCounted:
	var ex: RefCounted = (load(EXTRACTOR) as GDScript).new() as RefCounted
	ex.call("extract")
	return ex


func _domains() -> PackedStringArray:
	return (load(EXTRACTOR) as GDScript).get_script_constant_map()["DOMAINS"]


# --- extract / check-pot ----------------------------------------------------------------------------------------------

func _extract(out_dir: String) -> int:
	var ex: RefCounted = _run_extractor()
	var all: Dictionary = ex.call("entries")
	var script: GDScript = load(EXTRACTOR) as GDScript
	DirAccess.make_dir_recursive_absolute(out_dir)
	for d: String in _domains():
		var list: Array = all[d]
		var path: String = out_dir.path_join(d + ".pot")
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			printerr("i18n_tool: cannot write %s" % path)
			return 1
		f.store_string(str(script.call("pot_text", d, list)))
		f.close()
		print("I18N: %s.pot %d msgids, %d places" % [d, list.size(), _places(list)])
	_report(ex, all)
	var errors: PackedStringArray = ex.get("errors")
	for e: String in errors:
		printerr("i18n_tool: " + e)
	return 1 if not errors.is_empty() else 0


func _check_pot(pot_dir: String) -> int:
	var ex: RefCounted = _run_extractor()
	var all: Dictionary = ex.call("entries")
	var script: GDScript = load(EXTRACTOR) as GDScript
	var stale: int = 0
	for d: String in _domains():
		var want: String = str(script.call("pot_text", d, all[d]))
		var path: String = pot_dir.path_join(d + ".pot")
		var have: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		if want == have:
			print("I18N: %s.pot is current (%d msgids)" % [d, (all[d] as Array).size()])
			continue
		stale += 1
		var a: PackedStringArray = have.split("\n")
		var b: PackedStringArray = want.split("\n")
		for i in maxi(a.size(), b.size()):
			var x: String = a[i] if i < a.size() else "<end>"
			var y: String = b[i] if i < b.size() else "<end>"
			if x != y:
				print("I18N: %s.pot is stale from line %d: have '%s', extract writes '%s'" % [d, i + 1, x.left(90),
					y.left(90)])
				break
	if stale > 0:
		print("I18N: %d POT file(s) stale — run tools/i18n.sh extract (then merge)" % stale)
	return 1 if stale > 0 else 0


func _places(list: Array) -> int:
	var n: int = 0
	for e: Dictionary in list:
		n += (e["refs"] as PackedStringArray).size()
	return n


## The report of the extractor (11 §1.5, §1.11): dynamic calls, and msgids in several domains or contexts.
func _report(ex: RefCounted, all: Dictionary) -> void:
	var dyn: PackedStringArray = ex.get("dynamic")
	print("I18N: %d calls without a literal text (dynamisch — their texts come from the data or need Tx.m):" % dyn.size())
	for line: String in dyn:
		print("I18N:   " + line)
	var seen: Dictionary = {}                     # msgid → ["<domain>/<ctx>"]
	for d: String in _domains():
		for e: Dictionary in all[d]:
			var id: String = str(e["id"])
			var where: PackedStringArray = seen.get(id, PackedStringArray())
			where.append("%s/%s" % [d, str(e["ctx"]) if str(e["ctx"]) != "" else "-"])
			seen[id] = where
	var multi: int = 0
	for id: String in seen:
		multi += 1 if (seen[id] as PackedStringArray).size() > 1 else 0
	print("I18N: %d msgids in several domains or contexts (check that they mean the same; else a context):" % multi)
	for id: String in seen:
		var where2: PackedStringArray = seen[id]
		if where2.size() > 1:
			print("I18N:   \"%s\": %s" % [id.left(60).replace("\n", "\\n"), ", ".join(where2)])


# --- rules / sync / stats ---------------------------------------------------------------------------------------------

func _rules(lang: String, dir: String) -> int:
	var rules: GDScript = load(RULES) as GDScript
	var bad: int = 0
	for d: String in _domains():
		var path: String = dir.path_join(lang).path_join(d + ".po")
		if not FileAccess.file_exists(path):
			print("I18N: missing %s" % path)
			bad += 1
			continue
		var res: Dictionary = rules.call("check_text", FileAccess.get_file_as_string(path), path)
		var counts: Dictionary = res["counts"]
		print("I18N: %s: %d entries, %d translated, %d fuzzy, %d empty — %d errors, %d warnings" % [path,
			int(counts["total"]), int(counts["translated"]), int(counts["fuzzy"]), int(counts["empty"]),
			(res["errors"] as PackedStringArray).size(), (res["warnings"] as PackedStringArray).size()])
		for e: String in res["errors"]:
			print("I18N:   ERROR " + e)
		for w: String in res["warnings"]:
			print("I18N:   warning " + w)
		bad += (res["errors"] as PackedStringArray).size()
	return 1 if bad > 0 else 0


func _pack_rules(packs: String) -> int:
	var rules: GDScript = load(RULES) as GDScript
	var limits: Dictionary = rules.call("base_limits", POT_DIR)
	var bad: int = 0
	var files: PackedStringArray = rules.call("pack_po_files", packs)
	for path: String in files:
		var res: Dictionary = rules.call("check_pack_po", FileAccess.get_file_as_string(path), path,
			path.get_file().get_basename(), limits)
		var counts: Dictionary = res["counts"]
		print("I18N: %s: %d entries, %d translated — %d errors, %d warnings" % [path, int(counts["total"]),
			int(counts["translated"]), (res["errors"] as PackedStringArray).size(),
			(res["warnings"] as PackedStringArray).size()])
		for e: String in res["errors"]:
			print("I18N:   ERROR " + e)
		for w: String in res["warnings"]:
			print("I18N:   warning " + w)
		bad += (res["errors"] as PackedStringArray).size()
	if files.is_empty():
		print("I18N: no pack PO files under %s" % packs)
	return 1 if bad > 0 else 0


func _sync(lang: String, pot_dir: String, dir: String) -> int:
	var po_file: GDScript = load(PO_FILE) as GDScript
	var bad: int = 0
	for d: String in _domains():
		var pot_path: String = pot_dir.path_join(d + ".pot")
		var po_path: String = dir.path_join(lang).path_join(d + ".po")
		var pot: Dictionary = po_file.call("parse", FileAccess.get_file_as_string(pot_path), pot_path)
		var po: Dictionary = po_file.call("parse", FileAccess.get_file_as_string(po_path), po_path)
		var want: Dictionary = {}
		for e: Dictionary in pot["entries"]:
			want[str(e["ctx"]) + "\u0004" + str(e["id"])] = true
		var have: Dictionary = {}
		for e: Dictionary in po["entries"]:
			have[str(e["ctx"]) + "\u0004" + str(e["id"])] = true
		var missing: int = 0
		var extra: int = 0
		for k: String in want:
			missing += 0 if have.has(k) else 1
		for k: String in have:
			extra += 0 if want.has(k) else 1
		print("I18N: %s: %d msgids of the POT missing, %d entries the POT no longer has" % [po_path, missing, extra])
		bad += missing + extra
	if bad > 0:
		print("I18N: run tools/i18n.sh merge")
	return 1 if bad > 0 else 0


func _stats(lang: String, pack: String, dir: String) -> int:
	var po_file: GDScript = load(PO_FILE) as GDScript
	var total_open_words: int = 0
	print("I18N: coverage of '%s' (translated / fuzzy / empty, words still open)" % lang)
	for d: String in _domains():
		var po_path: String = dir.path_join(lang).path_join(d + ".po")
		var po: Dictionary = po_file.call("parse", FileAccess.get_file_as_string(po_path), po_path)
		var by_ctx: Dictionary = {}
		for e: Dictionary in po["entries"]:
			var ctx: String = str(e["ctx"]).get_slice(":", 0)
			ctx = ctx if ctx != "" else "(code)"
			if not by_ctx.has(ctx):
				by_ctx[ctx] = [0, 0, 0, 0]
			var row: Array = by_ctx[ctx]
			var done: bool = not bool(e["fuzzy"]) and (e["str"] as PackedStringArray).size() > 0 \
				and (e["str"] as PackedStringArray)[0] != ""
			var slot: int = 1 if bool(e["fuzzy"]) else (0 if done else 2)
			row[slot] = int(row[slot]) + 1
			if not done:
				row[3] = int(row[3]) + str(e["id"]).split(" ", false).size()
		var sums: Array = [0, 0, 0, 0]
		var keys: Array = by_ctx.keys()
		keys.sort()
		for ctx: Variant in keys:
			var row2: Array = by_ctx[ctx]
			for i in 4:
				sums[i] = int(sums[i]) + int(row2[i])
		total_open_words += int(sums[3])
		print("I18N: %-10s %5d / %4d / %5d  (%d words open)" % [d, sums[0], sums[1], sums[2], sums[3]])
		for ctx2: Variant in keys:
			var r: Array = by_ctx[ctx2]
			print("I18N:     %-22s %5d / %4d / %5d  (%d words)" % [str(ctx2), r[0], r[1], r[2], r[3]])
	print("I18N: %d words open in '%s'" % [total_open_words, lang])
	if pack != "":
		return _pack_names(pack, lang)
	return 0


## 11 §3.6 "Namensprüfung": the base msgids that contain a name the pack changed per patch and that the pack's PO does
## not override — warnings, so no old name stays.
func _pack_names(pack: String, lang: String) -> int:
	var po_file: GDScript = load(PO_FILE) as GDScript
	var renamed: Dictionary = {}                  # old text → new text
	for f: String in DirAccess.get_files_at(pack.path_join("data")):
		if not f.ends_with(".json"):
			continue
		var table: String = f.get_basename()
		var overlay: Variant = JSON.parse_string(FileAccess.get_file_as_string(pack.path_join("data").path_join(f)))
		var base: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % table))
		if not overlay is Dictionary or not base is Dictionary:
			continue
		var by_id: Dictionary = {}
		for e: Variant in ((base as Dictionary).get("entries", []) as Array):
			if e is Dictionary:
				by_id[str((e as Dictionary).get("id", ""))] = e
		var patches: Variant = (overlay as Dictionary).get("patch", {})
		for id: Variant in ((patches as Dictionary).keys() if patches is Dictionary else []):
			var p: Variant = (patches as Dictionary)[id]
			var old: Variant = by_id.get(str(id), null)
			if not p is Dictionary or not old is Dictionary:
				continue
			for field: String in ["name", "title"]:
				if (p as Dictionary).has(field) and (old as Dictionary).has(field):
					renamed[str((old as Dictionary)[field])] = str((p as Dictionary)[field])
	var pack_po: String = pack.path_join("locale").path_join(lang + ".po")
	var overridden: Dictionary = {}
	if FileAccess.file_exists(pack_po):
		for e: Dictionary in po_file.call("messages", po_file.call("parse", FileAccess.get_file_as_string(pack_po),
				pack_po)):
			overridden[str(e["id"])] = true
	var ex: RefCounted = _run_extractor()
	var all: Dictionary = ex.call("entries")
	var hits: int = 0
	for old_name: String in renamed:
		for d: String in _domains():
			for e: Dictionary in all[d]:
				var id: String = str(e["id"])
				if id.contains(old_name) and id != old_name and not overridden.has(id):
					hits += 1
					print("I18N: warning %s: \"%s\" still names \"%s\" (the pack says \"%s\")" % [d, id.left(70),
						old_name, str(renamed[old_name])])
	print("I18N: %d base texts name what the pack renamed and its %s.po does not override" % [hits, lang])
	return 0


# --- lint -------------------------------------------------------------------------------------------------------------

## The findings of test_11_literals: per file (or the lines of one file) and the PENDING table to paste.
func _lint(only: String) -> int:
	var lint: GDScript = load(LINT) as GDScript
	var total: int = 0
	var rows: PackedStringArray = []
	for path: String in lint.call("files"):
		if only != "" and path != only:
			continue
		var found: PackedStringArray = lint.call("findings", FileAccess.get_file_as_string(path))
		if found.is_empty():
			continue
		total += found.size()
		rows.append("\t\"%s\": %d," % [path, found.size()])
		if only != "":
			for f: String in found:
				print("I18N: %s:%s" % [path.trim_prefix("res://"), f])
	print("I18N: %d German literals outside Tx in %d files" % [total, rows.size()])
	print("I18N: const PENDING: Dictionary = {")
	for r: String in rows:
		print("I18N: " + r)
	print("I18N: }")
	return 0
