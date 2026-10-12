extends RefCounted
## The goals of a season floor (09 §3.2, §3.6; ST1-I) — one planner for both levels of the Staffel-Harness: the
## full-run bot in the world (scenes/boot/fullrun.gd, generator-v2 floors; floor 1 keeps the campaign's planner) and the
## core bot of the headless harness (tests/tools/season_harness.gd, every floor). Pure: reads GameState, GameData and
## the floor's FloorLayout; private test helper (no class_name, load() / preload it).
##
## A goal is {"kind": "group" | "chest" | "event" | "gate" | "safe" | "visit" | "boss", "id", "cell": Vector2i,
## "why"}. Strategies (09 §3.3): thorough = vollständig (every group, chest, event, room and safe room, the Etagenboss),
## typical = the Pflichtweg (groups, chests and events on the way start → stairs and one room off it — no show boss, no
## red side group —, the safe rooms within two rooms of it, the Revier-Boss; the Etagenboss only as the finale; floor 1:
## the campaign's typical), rush = safe rooms, the key gate and the bosses, auto = the play profiles' person (the
## Pflichtweg first, then the rest while the floor has time). Combat strategy for the bands: a group RED levels or more
## above the controlled figure waits until the Revier-Boss fell (09 §3.4 colours); below a boss's level − BOSS_GAP the
## other groups come first; boss attempts per floor (Am Stück) or per session (calendar); the programme rooms' events
## count once the daily programme opened their door (09 §3.3); a programme door itself is never a goal.

const STRATEGIES: PackedStringArray = ["thorough", "typical", "rush", "auto"]
const RED: int = 5
## Boss attempts: per floor Am Stück, per session in the calendar (a person tries twice an evening); the optional
## Etagenboss (thorough) at most FLOOR_BOSS_TRIES times per floor stay; a group that won GROUP_TRIES times against the
## party stays alone for the rest of the floor stay (tried["lost:<group id>"], counted by the bots).
const BOSS_TRIES_BINGE: int = 4
const BOSS_TRIES_SESSION: int = 2
const FLOOR_BOSS_TRIES: int = 2
const GROUP_TRIES: int = 2
## Level up before a boss: below its level − BOSS_GAP the other goals of the floor come first (typical, auto) — groups
## up to YELLOW levels above the hero (09 §3.4: yellow ±2), no show boss.
const BOSS_GAP: int = 1
const YELLOW: int = 2
## Before a boss: a safe room first below 90 % party HP or 70 % MP (the caller decides; "heal" in the goal).
const BOSS_HP_MIN: float = 0.9
const BOSS_MP_MIN: float = 0.7
## "auto" (the play profiles' person): the rest of the floor only while its collapse is more than HURRY_SEC away
## (calendar) or more than HURRY_PM of its countdown is left (Am Stück).
const HURRY_SEC: int = 86400
const HURRY_PM: int = 250
## Floor 1 (handbuilt): typical leaves the side groups a4, b3, c2 alone like the campaign's typical (GDD §13).
const FLOOR1_SKIP: PackedStringArray = ["f1_g3", "f1_g7", "f1_g10"]
const WHEEL_RESERVE: int = 60              # spin the wheel only with cost + reserve credits (the full-run bot's rule)
const TRY_LOCKED: String = "try without key"
const CLOSED: String = "Kulissen im Aufbau"   # the "wait" of closed stairs (09 §2.6)
const NO_CELL: Vector2i = Vector2i(-99, -99)


## The open goals besides the bosses, in a fixed order (groups, chests, events, gates, safe rooms, unvisited rooms);
## `red`: only the red groups (after the Revier-Boss). `tried`: the negative probes done (gate keys; the wheel's
## "Ignorieren" under its event id). Locked chests (floor 1) with the Generalschlüssel. Groups never include strays.
static func candidates(state: GameState, data: GameData, layout: FloorLayout, strategy: String, tried: Dictionary,
		red: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fr: FloorRun = state.floor_run
	var rush: bool = strategy == "rush"
	var floor_one: bool = layout.programme.is_empty() and fr.index == 1
	var near: Dictionary = corridor(layout, 1) if strategy == "typical" and not floor_one else {}
	var lv: int = hero_level(state)
	for e: EnemySpawn in layout.enemies:
		if rush or e.is_boss or e.is_stray() or fr.defeated_groups.has(e.id):
			continue
		var level: int = group_level(data, e)
		var is_red: bool = level - lv >= RED
		var rc: RoomCell = layout.cell_at(e.cell)
		if strategy == "typical" and floor_one and FLOOR1_SKIP.has(e.id):
			continue
		if strategy == "typical" and not floor_one and (not near.has(e.cell) or is_show_boss(data, e)
				or (is_red and (rc == null or not rc.on_path))):
			continue
		if is_red != red or int(tried.get("lost:" + e.id, 0)) >= GROUP_TRIES:
			continue
		out.append({"kind": "group", "id": e.id, "cell": e.cell, "why": "%s L%d" % [e.encounter_id, level]})
	if red:
		return out
	var has_master: bool = state.inventory.has(RunRules.KEY_MASTER)
	for ch: ChestSpawn in layout.chests:
		if rush or fr.opened_chests.has(ch.id) or (not near.is_empty() and not near.has(ch.cell)):
			continue
		if ch.type != "locked" or has_master:
			out.append({"kind": "chest", "id": ch.id, "cell": ch.cell, "why": ch.type})
	for ev: EventSpawn in layout.events:
		var choice: String = event_choice(state, data, ev, tried)
		if rush or choice == "" or (not near.is_empty() and not near.has(ev.cell) and not programme_cell(layout, ev.cell)):
			continue
		out.append({"kind": "event", "id": ev.id, "cell": ev.cell, "why": choice})
	for g: Dictionary in layout.gates:
		var req: String = str(g["requires"])
		var key: String = str(g["key"])
		if fr.opened_gates.has(key) or ZoneGenerator.programme_number(req) > 0 or req.begins_with("event:") \
				or Secrets.is_secret_requirement(req):
			continue
		if state.inventory.has(req):
			out.append({"kind": "gate", "id": key, "cell": g["cell"], "why": req})
		elif not rush and not tried.has(key):
			out.append({"kind": "gate", "id": key, "cell": g["cell"], "why": TRY_LOCKED})
	var path: Dictionary = corridor(layout, 2) if strategy == "typical" else {}
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		var cell: Vector2i = (layout.safe_room_info[sid] as Dictionary)["cell"]
		if not fr.visited_safe_rooms.has(str(sid)) and (path.is_empty() or path.has(cell)):
			out.append({"kind": "safe", "id": str(sid), "cell": cell, "why": "first visit"})
	if strategy == "thorough":
		for c: Vector2i in layout.sorted_cells():
			var rc2: RoomCell = layout.cell_at(c)
			if fr.visited.has(c) or rc2.kind == RoomCell.Kind.QUARTER_BOSS or rc2.kind == RoomCell.Kind.FLOOR_BOSS \
					or rc2.kind == RoomCell.Kind.STAIRS:
				continue
			out.append({"kind": "visit", "id": "", "cell": c, "why": "unvisited"})
	return out


## The next goal of a season floor after the bot's own ones (a heal trip, the logout, the tutorial): the nearest
## candidate of the strategy (`auto`: auto_strategy) — while the hero is more than BOSS_GAP levels below the next boss,
## every other goal of the floor first (level_up; "before" = the boss) —, the Revier-Boss, the red groups, the
## Etagenboss (thorough; the finale always), the stairs; else {"kind": "wait", "why"} (a boss lost too often, the stairs
## closed — CLOSED —, the finale floor done). A boss goal carries "heal" = true below BOSS_HP_MIN / BOSS_MP_MIN (the
## caller decides on the safe room). `tries`: {"qb", "fb"} attempts of this floor stay (calendar: of this session),
## "fb_floor" the Etagenboss's attempts of the floor stay.
static func goal(state: GameState, data: GameData, layout: FloorLayout, here: Vector2i, strategy: String,
		tried: Dictionary, tries: Dictionary) -> Dictionary:
	var fr: FloorRun = state.floor_run
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, boss_blocks(layout, fr, NO_CELL))
	var strat: String = auto_strategy(state) if strategy == "auto" else strategy
	var best: Dictionary = nearest(candidates(state, data, layout, strat, tried, false), dist)
	if not best.is_empty():
		return best
	var qb_tries: int = int(tries.get("qb", 0))
	var fb_tries: int = int(tries.get("fb", 0))
	var fb_floor: int = int(tries.get("fb_floor", 0))
	var b: Dictionary = boss(state, layout, strat, qb_tries, fb_tries, true)
	if b.is_empty():
		best = nearest(candidates(state, data, layout, strat, tried, true), dist)
		if not best.is_empty():
			return best
		b = boss(state, layout, strat, qb_tries, fb_tries, false, fb_floor)
	if not b.is_empty() and strat != "thorough" and strat != "rush":
		var spawn: EnemySpawn = layout.enemy_by_id(str(b["id"]))
		if spawn != null and hero_level(state) < group_level(data, spawn) - BOSS_GAP:
			best = nearest(level_up(state, data, layout, tried), dist)
			if not best.is_empty():
				best["before"] = str(b["id"])         # a level-up goal ("why" stays the choice of an event)
				return best
	if not b.is_empty():
		b["heal"] = party_ratio(state, data, "hp") < BOSS_HP_MIN or party_ratio(state, data, "mp") < BOSS_MP_MIN
		return b
	if fr.index >= (state.season.format if state.season != null else 0):
		return {"kind": "wait", "id": "", "cell": here, "why": "the finale floor"}
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated:
		return {"kind": "wait", "id": "", "cell": here, "why": "the Revier-Boss won %d×" % qb_tries}
	if SeasonRules.stairs_refusal(state, data) != "":
		return {"kind": "wait", "id": "", "cell": here, "why": "%s (öffnet in %d s)" % [CLOSED,
			SeasonRules.opens_in(state, fr.index + 1)]}
	return {"kind": "stairs", "id": "stairs", "cell": layout.stairs, "why": ""}


## The Pensum marks of 09 §3.3 (the records of both bots, the report): "pflicht" — the Pflichtweg is done (the
## Revier-Boss fell, no reachable goal of `typical` is left); "full" — vollständig (also no reachable goal of
## `thorough`, red groups included, and the Etagenboss fell or was given up after FLOOR_BOSS_TRIES, `fb_floor`).
static func pensum(state: GameState, data: GameData, layout: FloorLayout, here: Vector2i, tried: Dictionary,
		fb_floor: int) -> Dictionary:
	var fr: FloorRun = state.floor_run
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, boss_blocks(layout, fr, NO_CELL))
	var qb_done: bool = layout.quarter_boss == Vector2i(-1, -1) or fr.quarter_boss_defeated
	var pflicht: bool = qb_done and nearest(candidates(state, data, layout, "typical", tried, false), dist).is_empty()
	var fb_done: bool = layout.floor_boss == Vector2i(-1, -1) or fr.floor_boss_defeated or fb_floor >= FLOOR_BOSS_TRIES
	var full: bool = pflicht and fb_done \
		and nearest(candidates(state, data, layout, "thorough", tried, false), dist).is_empty() \
		and nearest(candidates(state, data, layout, "thorough", tried, true), dist).is_empty()
	return {"pflicht": pflicht, "full": full}


## The goals of a level-up before a boss: thorough's, without show bosses and groups above the hero + YELLOW.
static func level_up(state: GameState, data: GameData, layout: FloorLayout, tried: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lv: int = hero_level(state)
	for c: Dictionary in candidates(state, data, layout, "thorough", tried, false):
		if str(c["kind"]) == "group":
			var e: EnemySpawn = layout.enemy_by_id(str(c["id"]))
			if e == null or is_show_boss(data, e) or group_level(data, e) > lv + YELLOW:
				continue
		out.append(c)
	return out


## "auto" (the play profiles' person): the Pflichtweg (typical) while the Revier-Boss lives, then the rest of the floor
## (thorough) while the floor has time — its collapse more than HURRY_SEC away (calendar), more than HURRY_PM of its
## countdown left (Am Stück) —, else the stairs (typical).
static func auto_strategy(state: GameState) -> String:
	var fr: FloorRun = state.floor_run
	var s: SeasonState = state.season
	if not fr.quarter_boss_defeated or s == null:
		return "typical"
	if s.tempo == "binge":
		return "thorough" if fr.time_left_ticks * 1000 > SeasonClock.binge_ticks(fr.index) * HURRY_PM else "typical"
	var at: int = s.collapse_utc[fr.index - 1] if fr.index >= 1 and fr.index <= s.collapse_utc.size() else 0
	return "thorough" if at - s.utc > HURRY_SEC else "typical"


## The boss to fight now ({} none): the Revier-Boss while its attempts last; unless `qb_only` the Etagenboss — thorough
## (FLOOR_BOSS_TRIES per floor stay: `fb_floor`) or the finale of the format's last floor. Attempts of the Revier-Boss
## and the finale: BOSS_TRIES_BINGE Am Stück (per floor), else BOSS_TRIES_SESSION (per session).
static func boss(state: GameState, layout: FloorLayout, strategy: String, qb_tries: int, fb_tries: int,
		qb_only: bool, fb_floor: int = 0) -> Dictionary:
	var fr: FloorRun = state.floor_run
	var most: int = BOSS_TRIES_BINGE if state.season == null or state.season.tempo == "binge" else BOSS_TRIES_SESSION
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated:
		if qb_tries >= most:
			return {}
		return {"kind": "boss", "id": "f%d_qb" % fr.index, "cell": layout.quarter_boss, "why": "Revier-Boss"}
	if qb_only or layout.floor_boss == Vector2i(-1, -1) or fr.floor_boss_defeated:
		return {}
	var finale: bool = state.season != null and fr.index >= state.season.format
	if not finale and strategy != "thorough":
		return {}
	if (finale and fb_tries >= most) or (not finale and fb_floor >= FLOOR_BOSS_TRIES):
		return {}
	return {"kind": "boss", "id": "f%d_fb" % fr.index, "cell": layout.floor_boss,
		"why": "Großes Finale" if finale else "Etagenboss"}


## Party HP or MP ratio (sum / sum of the maxima).
static func party_ratio(state: GameState, data: GameData, what: String) -> float:
	var cur: int = 0
	var mx: int = 0
	for m: PartyMember in state.party:
		var sb: StatBlock = Progression.total_stats(m, data)
		if what == "mp":
			cur += m.mp
			mx += sb.values[StatBlock.Stat.MP]
		else:
			cur += m.hp
			mx += sb.values[StatBlock.Stat.HP]
	return float(cur) / float(maxi(1, mx))


## The choice at a floor event ("" = nothing to do): the full-run bot's (photo drone: pose; lost candidate: a heal item;
## wheel: "Ignorieren" once — tried[<event id>] —, then spin while the credits keep WHEEL_RESERVE; lever: pull;
## broken vending machine: kick).
static func event_choice(state: GameState, data: GameData, ev: EventSpawn, tried: Dictionary) -> String:
	var fr: FloorRun = state.floor_run
	var avail: PackedStringArray = FloorEvent.choices(ev, state, data)
	if ev.type == "wheel":
		var cost: int = int(ev.params.get("cost", 0))
		if not (avail.has("spin") and state.inventory.credits >= cost + WHEEL_RESERVE):
			return ""
		return "spin" if tried.has(ev.id) else "ignore"
	if fr.completed_events.has(ev.id):
		return ""
	match ev.type:
		"photo_drone":
			return "pose" if avail.has("pose") else ""
		"lost_candidate":
			for c: String in avail:
				if c.begins_with(FloorEvent.GIVE_PREFIX):
					return c
			return ""
		"lever":
			return "pull" if avail.has("pull") else ""
		"broken_vending":
			return "kick" if avail.has("kick") else ""
	return ""


## The cells of the Pflichtweg (FloorLayout.path, start → stairs) and those at most `rooms` door steps off it.
static func corridor(layout: FloorLayout, rooms: int) -> Dictionary:
	var out: Dictionary = {}
	var front: Array[Vector2i] = []
	for c: Vector2i in layout.path:
		out[c] = true
		front.append(c)
	for _step in rooms:
		var next: Array[Vector2i] = []
		for c: Vector2i in front:
			for n: Vector2i in layout.linked(c):
				if not out.has(n):
					out[n] = true
					next.append(n)
		front = next
	return out


## The cell is a programme room (09 §3.3: an event room behind a "daily:<n>" door).
static func programme_cell(layout: FloorLayout, cell: Vector2i) -> bool:
	for p: Dictionary in layout.programme:
		if p.get("cell", NO_CELL) == cell:
			return true
	return false


static func is_show_boss(data: GameData, e: EnemySpawn) -> bool:
	return data.has_id("encounters", e.encounter_id) and not data.encounter(e.encounter_id).show_boss.is_empty()


## A group's level: its band level on a season floor (ST1-C), else the highest data level of its enemies.
static func group_level(data: GameData, e: EnemySpawn) -> int:
	if e.level > 0:
		return e.level
	var lv: int = 1
	if data.has_id("encounters", e.encounter_id):
		for id: String in data.encounter(e.encounter_id).enemies:
			if data.has_id("enemies", id):
				lv = maxi(lv, data.enemy(id).level)
	return lv


## The controlled figure's level.
static func hero_level(state: GameState) -> int:
	var m: PartyMember = state.member(state.hero) if state.hero != "" else state.member("kai")
	return m.level if m != null else 1


## The nearest reachable goal of `cands` by `dist` (FloorLayout.distances; ties: the first in order); {} if none.
static func nearest(cands: Array[Dictionary], dist: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	for c: Dictionary in cands:
		var d: int = int(dist.get(c["cell"], -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = c
	return best


## Living boss rooms (never walked through unless they are the goal).
static func boss_blocks(layout: FloorLayout, fr: FloorRun, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated and layout.quarter_boss != goal:
		out.append(layout.quarter_boss)
	if layout.floor_boss != Vector2i(-1, -1) and not fr.floor_boss_defeated and layout.floor_boss != goal:
		out.append(layout.floor_boss)
	return out


## BFS path from → to over the open doors (closed gates and `blocked` cells excluded); [] if unreachable.
static func path(layout: FloorLayout, from: Vector2i, to: Vector2i, opened: PackedStringArray,
		blocked: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout == null or layout.cell_at(from) == null or layout.cell_at(to) == null:
		return out
	var parent: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == to:
			break
		for n: Vector2i in layout.neighbors(cur, opened):
			if parent.has(n) or (blocked.has(n) and n != to):
				continue
			parent[n] = cur
			queue.append(n)
	if not parent.has(to):
		return out
	var c: Vector2i = to
	while c != from:
		out.push_front(c)
		c = parent[c]
	out.push_front(from)
	return out
