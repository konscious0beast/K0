class_name TalentTree extends RefCounted
## The talent tree (09 §8.4, ST1-D): on fixed levels a row of three talents opens — the base rows 3/5/7/9 (the 24
## talents of 06-B, two ranks merged into one value), the class rows 15/25/35/45 (left = branch A, middle = show /
## allround, right = branch B of the member's class) and the figure rows 20/30/40/50 (attack / show / protection, for
## every class of the figure); a member takes one talent per row and may change it any time in a safe room, for free.
## The command "talent" v2 {"v": 2, "member", "row", "id"} (Game.pick_talent_row) is the pick and the re-pick; a pick
## sits in PartyMember.talent_rows (row as a String → talent id). A pick counts while it names a talent of that row of
## the member's trees (its own for base / figure rows, its current class for class rows): a class change (06 §3.6
## "Umschulung") frees the class rows, the other rows stay. Where the tree governs (governs), the 06-B offer of
## talents.gd stands aside (Talents.open_choices / has_choice / check_pick ask here first).
## V-20 (09 §0.4; ST1-D decision D-1): one talent system for everything — the tree governs every season now; the
## campaign and the SHOWRUN event runs switch together at the ST1 gate (the single SIM_VERSION jump, 09 §11.1) with the
## flag `everywhere`. Until then it stays false: every run without a season keeps the 06-B Talent-Show bit-identically.
## The migration (09 §8.7): old 06-B picks are reset, every reached row is open (migrate_06b).
## Static and pure (core): reads / writes GameState and PartyMember only, integer math, no randomness.

## Kept from ST0 (09 §11.4: the public API stays) — no command is refused with it since ST1-D.
const UNAVAILABLE: String = "season_unavailable"
## Refusal reasons of "talent" v2 (both verifiers report them; Game.pick_talent_row records nothing then).
const REASONS: PackedStringArray = ["unknown_member", "unknown_row", "not_in_row", "row_locked", "not_in_safe_room",
	"same"]
## The 06-B pick ({"t": "talent", "member", "id"}) where the tree governs (Talents.check_pick).
const TREE_RULES: String = "talent_tree"

## The V-20 switch (decision D-1): true = the tree governs every run, not only seasons. Flipped together with
## RunSim.SIM_VERSION at the ST1 gate (09 §11.1); tests turn it on and back off (test_09_talent_tree).
static var everywhere: bool = false


## True where the tree is the talent system: in every season, and everywhere once the V-20 switch is on.
static func governs(state: GameState) -> bool:
	return state != null and (state.season != null or everywhere)


## Is `level` a level a row of the tree opens on (3, 5, 7, 9, 15, 20, 25 … 50)?
static func is_row_level(level: int) -> bool:
	return TalentDef.tree_rows().has(level)


## The tree of `row` for `member`: its class for the class rows ("" before the Recall), else the member itself.
static func tree_for(member: PartyMember, row: int) -> String:
	if member == null:
		return ""
	return member.class_id if TalentDef.CLASS_ROWS.has(row) else member.id


## The three talents of row `row` of tree `tree` by column (left, middle, right); [] when the data have none.
static func row_of_tree(data: GameData, tree: String, row: int) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	if data == null or tree == "" or not is_row_level(row):
		return out
	var cols: Array = [null, null, null]
	for t: TalentDef in data.all_talents():
		if t.row == row and t.tree == tree and t.col >= 1 and t.col <= TalentDef.COLS:
			cols[t.col - 1] = t
	for c: Variant in cols:
		if c == null:
			out.clear()
			return out
		out.append(c as TalentDef)
	return out


## The three talents of `row` for `member` (its class for a class row); [] without them.
static func row_talents(data: GameData, member: PartyMember, row: int) -> Array[TalentDef]:
	return row_of_tree(data, tree_for(member, row), row)


## Every row of the member's tree that has talents (ascending), reached or not.
static func rows(data: GameData, member: PartyMember) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for r: int in TalentDef.tree_rows():
		if not row_talents(data, member, r).is_empty():
			out.append(r)
	return out


## The rows the member has reached (row ≤ level).
static func reached_rows(data: GameData, member: PartyMember) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if member == null:
		return out
	for r: int in rows(data, member):
		if r <= member.level:
			out.append(r)
	return out


## The talent that counts in `row`: the entry of PartyMember.talent_rows when it names a talent of that row of the
## member's tree (a class row: of its current class); "" otherwise.
static func pick_of(data: GameData, member: PartyMember, row: int) -> String:
	if member == null or data == null:
		return ""
	var id: String = str(member.talent_rows.get(str(row), ""))
	if id == "" or not data.has_id("talents", id):
		return ""
	var t: TalentDef = data.talent(id)
	return id if t.row == row and t.tree != "" and t.tree == tree_for(member, row) else ""


## The reached rows without a counting pick (only where the tree governs): the Talent-Show presents them in order.
static func open_rows(state: GameState, data: GameData, member: PartyMember) -> PackedInt32Array:
	var out: PackedInt32Array = []
	if not governs(state) or member == null:
		return out
	for r: int in reached_rows(data, member):
		if pick_of(data, member, r) == "":
			out.append(r)
	return out


## Open rows of the whole party (safe-room badge, party page).
static func open_total(state: GameState, data: GameData) -> int:
	var n: int = 0
	if state == null:
		return n
	for m: PartyMember in state.party:
		n += open_rows(state, data, m).size()
	return n


## The rows that open on the levels old_level+1 … new_level for `member` (the chip "TALENT-SHOW BEREIT").
static func rows_between(data: GameData, member: PartyMember, old_level: int, new_level: int) -> PackedInt32Array:
	var out: PackedInt32Array = []
	for r: int in rows(data, member):
		if r > old_level and r <= new_level:
			out.append(r)
	return out


## The picks that count, in row order.
static func picked(data: GameData, member: PartyMember) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	if member == null or data == null or member.talent_rows.is_empty():
		return out
	for r: int in TalentDef.tree_rows():
		var id: String = pick_of(data, member, r)
		if id != "":
			out.append(data.talent(id))
	return out


## [[effect, rank 1], …] of the picks that count (row order, effect order) — Talents._effects appends them; the rt_mod
## effects among them reach the combat through rt_mods (the Talents kinds ignore them).
static func effects(data: GameData, member: PartyMember) -> Array:
	var out: Array = []
	for t: TalentDef in picked(data, member):
		for fx: Dictionary in t.effects:
			out.append([fx, 1])
	return out


## The RtMods of the member's picks (07 §9.5, source talent:<id>, on the member's own unit `uid`; BattleBridge, after
## the class, before the show boss): one mod per rt_mod effect, its fields as written ("kind" left out).
static func rt_mods(data: GameData, member: PartyMember, uid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: TalentDef in picked(data, member):
		for fx: Dictionary in t.effects:
			if str(fx.get("kind", "")) != "rt_mod":
				continue
			var m: Dictionary = fx.duplicate(true)
			m.erase("kind")
			m["src"] = "talent:" + t.id
			m["unit"] = uid
			out.append(m)
	return out


## The branch (Spezialisierung) of the member's class shown as a badge (09 §8.4: who picks mostly left or mostly right
## gets it; no duty, nothing locked): the spec of the outer column with more class-row picks; "" on a tie or without
## class picks.
static func spec_of(data: GameData, member: PartyMember) -> String:
	var left: int = 0
	var right: int = 0
	var names: PackedStringArray = ["", ""]
	for t: TalentDef in picked(data, member):
		if not TalentDef.CLASS_ROWS.has(t.row):
			continue
		if t.col == 1:
			left += 1
			names[0] = t.spec
		elif t.col == TalentDef.COLS:
			right += 1
			names[1] = t.spec
	if left == right:
		return ""
	return names[0] if left > right else names[1]


# --- the command "talent" v2 ------------------------------------------------------------------------------------------

## "" or why the command `c` ("talent" v2) is refused now (read-only; RunRules asks it where the tree governs, after
## the season gate): unknown member → unknown_member; no tree row with talents for the member → unknown_row; the talent
## is not one of the row → not_in_row; the row above the member's level → row_locked; outside a safe room →
## not_in_safe_room (picks and re-picks, 09 §9.1); the talent already counts in the row → same.
static func refusal(state: GameState, data: GameData, c: Dictionary) -> String:
	var m: PartyMember = state.member(str(c.get("member", ""))) if state != null else null
	if m == null or data == null:
		return "unknown_member"
	var row: int = JsonUtil.to_int(c.get("row", 0))
	var talents: Array[TalentDef] = row_talents(data, m, row)
	if talents.is_empty():
		return "unknown_row"
	var id: String = str(c.get("id", ""))
	var found: bool = false
	for t: TalentDef in talents:
		found = found or t.id == id
	if not found:
		return "not_in_row"
	if row > m.level:
		return "row_locked"
	if not RunRules.in_safe_room(state):
		return "not_in_safe_room"
	if pick_of(data, m, row) == id:
		return "same"
	return ""


## Applies an accepted "talent" v2 (refusal == ""): the row's pick; HP / MP follow a changed maximum like a level-up
## (no full heal; KO stays KO). The SEASON event "talent" {member, row, id, before} (before "" = a first pick).
static func apply(state: GameState, data: GameData, c: Dictionary) -> Array[ExploreEvent]:
	var out: Array[ExploreEvent] = []
	var m: PartyMember = state.member(str(c.get("member", ""))) if state != null else null
	if m == null:
		return out
	var row: int = JsonUtil.to_int(c.get("row", 0))
	var before_id: String = pick_of(data, m, row)
	var before: StatBlock = Progression.total_stats(m, data)
	m.talent_rows[str(row)] = str(c.get("id", ""))
	Progression.follow_max_vitals(m, before, Progression.total_stats(m, data))
	out.append(ExploreEvent.make(ExploreEvent.Type.SEASON, 0, {"kind": "talent", "member": m.id, "row": row,
		"id": str(c.get("id", "")), "before": before_id}))
	return out


# --- migration (09 §8.7) ----------------------------------------------------------------------------------------------

## The migration of 06-B picks where the tree governs (09 §8.7: "Alte Wahlen werden zurückgesetzt, jede erreichte Reihe
## ist offen"): every member's pool talents (PartyMember.talents) go, HP / MP follow the lower maxima. Returns the
## number of reset picks (0: nothing to do — every season, every run while the V-20 switch is off). SaveCodec runs it on
## load, before the save becomes a session's anchor, so the live run and the verifiers start from the migrated state.
static func migrate_06b(state: GameState, data: GameData) -> int:
	var n: int = 0
	if not governs(state):
		return n
	for m: PartyMember in state.party:
		if m == null or m.talents.is_empty():
			continue
		var before: StatBlock = Progression.total_stats(m, data)
		n += Talents.picks(m)
		m.talents = {}
		Progression.follow_max_vitals(m, before, Progression.total_stats(m, data))
	return n
