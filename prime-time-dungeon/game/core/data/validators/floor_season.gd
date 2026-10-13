extends RefCounted
## Validation of the season fields of floors.json (09 §2.4, §3.1, §3.6; CR-27 FloorDef; contract pass 4): the Kulisse a
## floor belongs to (`theme` may name a `thm_` Kulisse of themes.json besides an art theme of DataValidator.THEMES),
## the floor's place in its Kulisse (`variant`), its level band (`level_band`, 09 §2.4) and its quarters (Viertel) for
## the generator v2 (`zones`, core/dungeon/zone_generator.gd). All optional with defaults that change nothing: variant 0
## (no place stated), level_band [] (no band), zones [] (the DungeonGenerator as today). Private helper of
## DataValidator (no class_name; preloaded as FloorSeasonCheck): the frozen validator calls normalize (per floor),
## zone_ids (rule 3) and check (cross-table rules). Contract pass 4 shipped the schema and these rules; ST1-C (the
## owner) extended the quarter schema with the generator v2 (events, programme doors, gather nodes, the safe room) and
## added its rules — one safe room per quarter, the floor's key (itm_key_f<index>, dropped by the Revier-Boss), the
## references of the quarters' events and gather nodes — without touching DataValidator.

## A quarter of a generator-v2 floor (09 §3.2, §3.6): id (zone_, unique like every zone id), name (the login summary
## names it, 09 §5.4), rooms (09 §3.6: 10–14 per quarter), palette (overrides the floor palette in the quarter, keys of
## DataValidator.PALETTE_KEYS / PALETTE_ART_KEYS) and pool (regular encounters of this floor that roam the quarter;
## [] = the floor's pool by depth). ST1-C: events (templates {type, params} of DataValidator.FLOOR_EVENT_PARAMS, each
## placed once in the quarter — no lever, it needs a hand-built gate — and drawn for the programme rooms), spots
## (programme doors in this quarter, 09 §3.3; at most five per floor), nodes (gather node kinds, nod_ of
## professions.json: 4–6 positions per quarter, ST1-E), safe ({name, theme}: the quarter's safe room) and style (the
## dressing of its rooms, a style of the floor's art theme: STYLES; "" = the one its palette is closest to). The danger
## for sleepers follows the position (09 §3.6 Nr. 4), it is no field.
const ZONE_SPEC: Array = [["id", "s"], ["name", "s"], ["rooms", "d", {"min": 10, "max": 14}], ["palette", "d", {}],
	["pool", "sa", []], ["events", "a", []], ["spots", "i", 0], ["nodes", "sa", []], ["safe", "d", {}],
	["style", "s", ""]]
## The dressing styles of a quarter per art theme (RoomSpec.style; the boss and safe-room looks are no quarter style).
const STYLES: Dictionary = {"metro": ["platform", "sewer", "cellar", "track9"], "mall": ["mall"]}
const EVENT_SPEC: Array = [["type", "s"], ["params", "d", {}]]
const SAFE_SPEC: Array = [["name", "s", ""], ["theme", "s", "kiosk"]]
const SPOTS_MAX: int = 5                   # == ZoneGenerator.SPOTS_MAX (09 §3.3: at most five programme points)
const KEY_PREFIX: String = "itm_key_f"     # == ZoneGenerator.KEY_PREFIX: the floor's key itm_key_f<index>
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
		_normalize_v2(v, zctx, z)                # ST1-C: events, spots, nodes, safe room
		zones.append(z)
	var fr: Dictionary = d["rooms"]
	if not zones.is_empty() and (sum_min > int(fr["max"]) or sum_max < int(fr["min"])):
		v._err(ctx + ".zones", "the quarters' rooms (%d..%d) miss the floor's rooms (%d..%d)" % [sum_min, sum_max,
			int(fr["min"]), int(fr["max"])])
	if int(d["safe_rooms"]) > zones.size():
		v._err(ctx + ".safe_rooms", "at most one safe room per quarter (%d quarters)" % zones.size())
	elif not zones.is_empty() and int(d["safe_rooms"]) < zones.size():   # ST1-C: 09 §3.6 Nr. 5
		v._err(ctx + ".safe_rooms", "one safe room in every quarter (09 §3.6; %d quarters)" % zones.size())
	var spots: int = 0
	var templates: int = 0
	for z: Dictionary in zones:
		spots += int(z["spots"])
		templates += (z["events"] as Array).size()
	if spots > SPOTS_MAX:
		v._err(ctx + ".zones", "%d programme doors (at most %d per floor, 09 §3.3)" % [spots, SPOTS_MAX])
	if spots > 0 and templates == 0:
		v._err(ctx + ".zones", "programme doors need event templates (a programme room holds an event)")
	d["zones"] = zones


## ST1-C: the generator-v2 fields of one normalized quarter `z` (in place): event templates, programme doors, gather
## node kinds (references: check), the safe room.
static func _normalize_v2(v: DataValidator, zctx: String, z: Dictionary) -> void:
	var events: Array[Dictionary] = []
	var raw_e: Array = z["events"]
	for i in raw_e.size():
		var ectx: String = "%s.events[%d]" % [zctx, i]
		var e: Dictionary = v._norm(ectx, raw_e[i], EVENT_SPEC)
		if e.is_empty():
			continue
		var etype: String = str(e["type"])
		v._enum(ectx + ".type", etype, ZoneGenerator.EVENT_TYPES)
		if DataValidator.FLOOR_EVENT_PARAMS.has(etype):
			var spec: Array = []
			for f: Array in DataValidator.FLOOR_EVENT_PARAMS[etype]:
				spec.append([f[0], f[1]])
			var params: Dictionary = v._norm(ectx + ".params", e["params"], spec)
			if not params.is_empty():
				v._n_event_params(ectx + ".params", etype, params)
			e["params"] = params
		events.append(e)
	z["events"] = events
	v._range_i(zctx + ".spots", int(z["spots"]), 0, SPOTS_MAX)
	var safe: Dictionary = z["safe"]
	if not safe.is_empty():
		safe = v._norm(zctx + ".safe", safe, SAFE_SPEC)
		if not safe.is_empty():
			v._enum(zctx + ".safe.theme", str(safe["theme"]), DataValidator.SAFE_ROOM_THEMES)
			if str(safe["name"]).length() > NAME_MAX:
				v._err(zctx + ".safe.name", "0..%d characters" % NAME_MAX)
		z["safe"] = safe


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
		if not (d["zones"] as Array).is_empty():
			_check_v2(v, ctx, d)                     # ST1-C: the key, the quarters' events and gather nodes
	banded.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for k in range(1, banded.size()):
		var prev: PackedInt32Array = (banded[k - 1] as Array)[2]
		var cur: PackedInt32Array = (banded[k] as Array)[2]
		if cur.size() == 2 and prev.size() == 2 and (cur[0] < prev[0] or cur[1] < prev[1]):
			v._err(str((banded[k] as Array)[1]) + ".level_band", "falls below the band of floor %d (%s → %s)" % [
				int((banded[k - 1] as Array)[0]), str(Array(prev)), str(Array(cur))])


## ST1-C: the cross-table rules of a generator-v2 floor `d`: the floor's key (itm_key_f<index>, an item of type key)
## drops from the lead of its Revier-Boss; the quarters' events name known items, boxes and regular encounters of this
## floor; the gather nodes are nod_ entries of professions.json.
static func _check_v2(v: DataValidator, ctx: String, d: Dictionary) -> void:
	var idx: int = int(d["index"])
	var qb: String = str(d["quarter_boss"])
	if qb != "" and v._encounters.has(qb):
		var key: String = KEY_PREFIX + str(idx)
		if not v._items.has(key):
			v._err(ctx + ".quarter_boss", "the floor's key '%s' is missing (items.json, type key)" % key)
		elif str((v._items[key] as Dictionary).get("type", "")) != "key":
			v._err(ctx + ".quarter_boss", "'%s' must be an item of type key" % key)
		var lead: String = ""
		var enemies: PackedStringArray = ((v._encounters[qb] as Dictionary)["def"] as Dictionary)["enemies"]
		if not enemies.is_empty():
			lead = enemies[0]
		var drops: bool = false
		if v._enemies.has(lead):
			for bd: Variant in ((v._enemies[lead] as Dictionary).get("boss_drops", []) as Array):
				if bd is Dictionary and str((bd as Dictionary).get("kind", "")) == "item" \
						and str((bd as Dictionary).get("id", "")) == key:
					drops = true
		if not drops:
			v._err(ctx + ".quarter_boss", "the Revier-Boss '%s' must drop the floor's key '%s' (boss_drops)" % [lead,
				key])
	var art: String = str(d["theme"])
	for t: Dictionary in v._out.get("themes", []):
		if str(t["id"]) == art:
			art = str(t["art"])
	var nodes: Dictionary = {}
	for n: Variant in ((v._out.get("profession_extras", {}) as Dictionary).get("nodes", []) as Array):
		nodes[str((n as Dictionary).get("id", ""))] = true
	for z: Dictionary in d["zones"]:
		var zctx: String = "%s.zones[%s]" % [ctx, str(z["id"])]
		var style: String = str(z["style"])
		if style != "" and not (STYLES.get(art, []) as Array).has(style):
			v._err(zctx + ".style", "'%s' is no dressing style of the art theme %s (%s)" % [style, art,
				str(STYLES.get(art, []))])
		for nod: String in z["nodes"]:
			if not nodes.is_empty() and not nodes.has(nod):    # tables without professions.json's nodes: unchecked
				v._err(zctx + ".nodes", "unknown gather node (professions.json nodes) '%s'" % nod)
		var events: Array = z["events"]
		for i in events.size():
			var e: Dictionary = events[i]
			var p: Dictionary = e["params"]
			var ectx: String = "%s.events[%d].params" % [zctx, i]
			if p.has("reward_item"):
				v._ref(ectx + ".reward_item", str(p["reward_item"]), v._items, "item")
			for t: Variant in (p.get("table", []) as Array):
				var te: Dictionary = t
				match str(te.get("kind", "")):
					"item":
						v._ref(ectx + ".table", str(te["id"]), v._items, "item")
					"box":
						v._ref(ectx + ".table", str(te["id"]), v._boxes, "lootbox")
					"encounter":
						var enc: String = str(te["id"])
						if not v._encounters.has(enc) or int((v._encounters[enc] as Dictionary)["floor"]) != idx \
								or bool(((v._encounters[enc] as Dictionary)["def"] as Dictionary)["boss"]):
							v._err(ectx + ".table", "'%s' is no regular encounter of this floor" % enc)
