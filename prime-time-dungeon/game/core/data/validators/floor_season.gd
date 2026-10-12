extends RefCounted
## Validation of the season fields of floors.json (09 §2.4, §3.1, §3.6; CR-27 FloorDef; contract pass 4): the Kulisse a
## floor belongs to (`theme` may name a `thm_` Kulisse of themes.json besides an art theme of DataValidator.THEMES),
## the floor's place in its Kulisse (`variant`), its level band (`level_band`, 09 §2.4) and its quarters (Viertel) for
## the generator v2 (`zones`, core/dungeon/zone_generator.gd). All optional with defaults that change nothing: variant 0
## (no place stated), level_band [] (no band), zones [] (the DungeonGenerator as today). Private helper of
## DataValidator (no class_name; preloaded as FloorSeasonCheck): the frozen validator calls normalize (per floor),
## zone_ids (rule 3) and check (cross-table rules). Contract pass 4 ships the schema and these rules; owned by
## 09-ST1-C, which may extend the zone schema with the generator v2 without touching DataValidator.

## A quarter of a generator-v2 floor (09 §3.2, §3.6): id (zone_, unique like every zone id), name (the login summary
## names it, 09 §5.4), rooms (09 §3.6: 10–14 per quarter), palette (overrides the floor palette in the quarter, keys of
## DataValidator.PALETTE_KEYS / PALETTE_ART_KEYS) and pool (regular encounters of this floor that roam the quarter;
## [] = the floor's pool by depth). The danger for sleepers follows the position (09 §3.6 Nr. 4), it is no field.
const ZONE_SPEC: Array = [["id", "s"], ["name", "s"], ["rooms", "d", {"min": 10, "max": 14}], ["palette", "d", {}],
	["pool", "sa", []]]
const VARIANT_MAX: int = 3                 # a Kulisse spans one to three floors (09 §3.1)
const ZONES_MIN: int = 2                   # floor 2: two quarters; floors 3–18: three or four (09 §3.1)
const ZONES_MAX: int = 4
const ZONE_ROOMS_MAX: int = 30
const NAME_MAX: int = 32
## Grid and safe rooms of a generator-v2 floor (09 §3.6: grids up to 13 × 13, one safe room per quarter, at most 4);
## the DungeonGenerator floors keep DataValidator's 12 and 3.
const ZONE_GRID_MAX: int = 13
const ZONE_SAFE_ROOMS_MAX: int = 4
const KULISSE_PREFIX: String = "thm_"


## `theme` names a Kulisse of themes.json (else an art theme of DataValidator.THEMES).
static func is_kulisse(theme: String) -> bool:
	return theme.begins_with(KULISSE_PREFIX)


## A floor with quarters for the generator v2 (normalized or raw `zones`).
static func is_zone_floor(d: Dictionary) -> bool:
	return d.get("zones", []) is Array and not (d.get("zones", []) as Array).is_empty()


## Per-entry rules of one normalized floor `d` (its raw entry `_raw`, for rules on given keys): variant, level band,
## quarters; `d["zones"]` becomes the normalized quarters. Called by DataValidator._n_floor after rooms and layout.
static func normalize(v: DataValidator, ctx: String, d: Dictionary, _raw: Dictionary) -> void:
	v._range_i(ctx + ".variant", int(d["variant"]), 0, VARIANT_MAX)
	var band: PackedInt32Array = d["level_band"]
	if not band.is_empty():
		if band.size() != 2:
			v._err(ctx + ".level_band", "[] or [from, to] (got %d numbers)" % band.size())
		elif band[0] < 1 or band[0] > band[1] or band[1] > DataValidator.SEASON_LEVEL_CAP:
			v._err(ctx + ".level_band", "needs 1 <= from <= to <= %d (got %s)" % [DataValidator.SEASON_LEVEL_CAP,
				str(Array(band))])
	var zones: Array[Dictionary] = []
	var raw_z: Array = d["zones"]
	if raw_z.is_empty():
		d["zones"] = zones
		return
	if not (d["layout"] as Dictionary).is_empty():
		v._err(ctx + ".zones", "only for procedural floors (a hand-built layout has its own zones)")
	if raw_z.size() < ZONES_MIN or raw_z.size() > ZONES_MAX:
		v._err(ctx + ".zones", "needs %d..%d quarters (got %d)" % [ZONES_MIN, ZONES_MAX, raw_z.size()])
	var seen: Dictionary = {}
	var sum_min: int = 0
	var sum_max: int = 0
	for i in raw_z.size():
		var zctx: String = DataValidator._ctx(ctx + ".zones", i, raw_z[i])
		var z: Dictionary = v._norm(zctx, raw_z[i], ZONE_SPEC)
		if z.is_empty():
			continue
		var zid: String = str(z["id"])
		if seen.has(zid):
			v._err(zctx + ".id", "'%s' twice on this floor" % zid)
		seen[zid] = true
		var zname: String = str(z["name"])
		if zname == "" or zname.length() > NAME_MAX:
			v._err(zctx + ".name", "1..%d characters" % NAME_MAX)
		var rooms: Dictionary = v._norm(zctx + ".rooms", z["rooms"], DataValidator.SPEC_MINMAX)
		if rooms.is_empty():
			rooms = {"min": 10, "max": 14}
		elif int(rooms["min"]) < 1 or int(rooms["min"]) > int(rooms["max"]) or int(rooms["max"]) > ZONE_ROOMS_MAX:
			v._err(zctx + ".rooms", "needs 1 <= min <= max <= %d" % ZONE_ROOMS_MAX)
		z["rooms"] = rooms
		sum_min += int(rooms["min"])
		sum_max += int(rooms["max"])
		z["palette"] = v._n_palette(zctx + ".palette", z["palette"])
		zones.append(z)
	var fr: Dictionary = d["rooms"]
	if not zones.is_empty() and (sum_min > int(fr["max"]) or sum_max < int(fr["min"])):
		v._err(ctx + ".zones", "the quarters' rooms (%d..%d) miss the floor's rooms (%d..%d)" % [sum_min, sum_max,
			int(fr["min"]), int(fr["max"])])
	if int(d["safe_rooms"]) > zones.size():
		v._err(ctx + ".safe_rooms", "at most one safe room per quarter (%d quarters)" % zones.size())
	d["zones"] = zones


## The quarter ids of a normalized floor (rule 3: zone ids are global).
static func zone_ids(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for z: Variant in d.get("zones", []) as Array:
		if z is Dictionary and (z as Dictionary).has("id"):
			out.append(str((z as Dictionary)["id"]))
	return out


## Cross-table rules: a Kulisse theme exists and lists the floor; a variant is the floor's place in its Kulisse (the
## Kulisse's floors in ascending order, themes.json); quarter pools are regular encounters of the floor; the level
## bands never fall from one floor to the next.
static func check(v: DataValidator) -> void:
	var kulisse_of: Dictionary = {}                 # floor index → [thm id, place 1..]
	var themes: Dictionary = {}
	for t: Dictionary in v._out.get("themes", []):
		themes[str(t["id"])] = true
		var floors: Array = Array(t["floors"] as PackedInt32Array)
		floors.sort()
		for k in floors.size():
			if not kulisse_of.has(int(floors[k])):
				kulisse_of[int(floors[k])] = [str(t["id"]), k + 1]
	var banded: Array = []
	for i in (v._out["floors"] as Array).size():
		var d: Dictionary = v._out["floors"][i]
		var ctx: String = DataValidator._ctx("floors", i, d)
		var idx: int = int(d["index"])
		var theme: String = str(d["theme"])
		if is_kulisse(theme):
			if not themes.has(theme):
				v._err(ctx + ".theme", "unknown Kulisse (themes.json) '%s'" % theme)
			elif not kulisse_of.has(idx) or str((kulisse_of[idx] as Array)[0]) != theme:
				v._err(ctx + ".theme", "Kulisse '%s' does not list floor %d (themes.json floors)" % [theme, idx])
		var variant: int = int(d["variant"])
		if variant > 0:
			if not kulisse_of.has(idx):
				v._err(ctx + ".variant", "floor %d is in no Kulisse (themes.json floors)" % idx)
			elif int((kulisse_of[idx] as Array)[1]) != variant:
				v._err(ctx + ".variant", "floor %d is place %d of its Kulisse '%s' (got %d)" % [idx,
					int((kulisse_of[idx] as Array)[1]), str((kulisse_of[idx] as Array)[0]), variant])
		for z: Dictionary in d["zones"]:
			for enc: String in z["pool"]:
				var zctx: String = "%s.zones[%s].pool" % [ctx, str(z["id"])]
				if not v._encounters.has(enc) or int((v._encounters[enc] as Dictionary)["floor"]) != idx:
					v._err(zctx, "'%s' is no encounter of this floor" % enc)
				elif bool(((v._encounters[enc] as Dictionary)["def"] as Dictionary)["boss"]):
					v._err(zctx, "'%s' is a boss (bosses have their own rooms)" % enc)
		if not (d["level_band"] as PackedInt32Array).is_empty():
			banded.append([idx, ctx, d["level_band"]])
	banded.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for k in range(1, banded.size()):
		var prev: PackedInt32Array = (banded[k - 1] as Array)[2]
		var cur: PackedInt32Array = (banded[k] as Array)[2]
		if cur.size() == 2 and prev.size() == 2 and (cur[0] < prev[0] or cur[1] < prev[1]):
			v._err(str((banded[k] as Array)[1]) + ".level_band", "falls below the band of floor %d (%s → %s)" % [
				int((banded[k - 1] as Array)[0]), str(Array(prev)), str(Array(cur))])
