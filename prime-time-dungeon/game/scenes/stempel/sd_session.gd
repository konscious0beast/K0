extends RefCounted
## Session glue of the Stempelduell screens (10 §2.5, §6.6, §6.7): the rulebook (SdRulebook.shared, once per session),
## the account collection through the save hook (Save.load_sd_collection → SdCollection.from_dict; the account seed is
## rolled here once — outside core/, which has no randomness of its own), the campaign unlocks read from the save
## slots (ids only: abilities the figures have reached, items held, talents chosen — 10 §2.5) and saving after every
## change. One collection object per session, shared by the hall, the Aktenschrank, the album and the table; tests
## inject their own (use) and drop it again (reset). Presentation layer: reads Save, DB and Game, never writes
## Game.state. Private (no class_name): `const SdSession := preload("res://scenes/stempel/sd_session.gd")`.

const MSG_RESET: String = "Stempelakte neu angelegt"

static var _collection: SdCollection = null
static var _book: SdRulebook = null
static var _reset_notice: bool = false
static var _new_cards: PackedStringArray = []
## Saving off (captures, perf probe): changes stay in memory.
static var ephemeral: bool = false


static func book() -> SdRulebook:
	if _book == null:
		_book = SdRulebook.shared()
	return _book


## The collection of this session (loaded on first use).
static func collection() -> SdCollection:
	if _collection == null:
		_collection = _load()
	return _collection


## Opening the Stempelduell (Titel → Extras): loads the collection if needed and reads the campaign unlocks again (new
## cards are saved at once and reported once through take_new_cards).
static func open() -> SdCollection:
	var c: SdCollection = collection()
	var fresh: PackedStringArray = c.apply_campaign(campaign_ids(), book())
	if not fresh.is_empty():
		_new_cards.append_array(fresh)
		save()
	return c


## Tests / captures: this collection for the session (null = load from the file again on next use).
static func use(c: SdCollection) -> void:
	_collection = c


static func reset() -> void:
	_collection = null
	_reset_notice = false
	_new_cards = PackedStringArray()


## Captures and the perf probe (params "capture"): a fixed sample collection in memory, never saved — the Lernduell
## done, Ferdi beaten twice and the Graf once (their first-win cards), four Stempelheft stamps (Frostniesen), two
## Dienstauszeichnungen, Mappe B half built (the Aktenschrank's sentence shows).
static func use_sample() -> SdCollection:
	ephemeral = true
	var b: SdRulebook = book()
	var c: SdCollection = SdCollection.create(20261012)
	c.complete_tutorial(b)
	var extra: PackedStringArray = []
	var cos: PackedStringArray = c.cosmetics["owned"]
	for oid: String in ["sdo_ferdi", "sdo_graf"]:
		extra.append_array(b.opponent(oid).first_win_cards())
		cos.append_array(b.opponent(oid).first_win_cosmetics())
	c.cosmetics["owned"] = cos
	extra.append("sdc_frostniesen")
	c.unlock_cards(extra, b)
	c.beaten = {"sdo_ferdi": 2, "sdo_graf": 1}
	c.heft = 4
	c.stats["duels"] = 5
	c.stats["wins"] = 4
	var aw: PackedStringArray = c.awards
	aw.append_array(PackedStringArray([SdCollection.AWARD_FIRST_WIN, SdCollection.AWARD_CHAIN]))
	c.awards = aw
	c.set_deck("b", PackedStringArray(["sdc_ablehnung", "sdc_ablehnung", "sdc_frostniesen", "sdc_frostniesen",
		"sdc_kaeltespray", "sdc_adelsflamme", "sdc_adelsflamme", "sdc_schlabbern", "sdc_gutachten", "sdc_durchatmen",
		"sdc_durchatmen", "sdc_kleingedrucktes", "sdc_stereo"]))
	_collection = c
	return c


static func save() -> void:
	if _collection == null or ephemeral:
		return
	var err: Error = Save.save_sd_collection(_collection.to_dict())
	if err != OK:
		push_warning("[Stempelduell] collection not saved: %s" % Save.last_error())


## True once after a broken collection file was replaced by an empty one (the screen toasts MSG_RESET).
static func take_reset_notice() -> bool:
	var r: bool = _reset_notice
	_reset_notice = false
	return r


## Cards the campaign unlocked since the last call (the hall announces them once).
static func take_new_cards() -> PackedStringArray:
	var out: PackedStringArray = _new_cards.duplicate()
	_new_cards = PackedStringArray()
	return out


## A fresh account seed (31 bit, never 0).
static func roll_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return maxi(1, rng.randi() & 0x7FFFFFFF)


static func _load() -> SdCollection:
	var file: Dictionary = Save.load_sd_collection()
	var c: SdCollection = null
	if not bool(file.get("found", false)):
		c = SdCollection.create(roll_seed())
	else:
		c = SdCollection.from_dict(file.get("data", null), book())
		_reset_notice = c.was_reset
		if c.seed == 0:
			c.seed = roll_seed()
	_collection = c
	save()
	return c


# --- campaign unlocks (10 §2.5) --------------------------------------------------------------------------------------

## Campaign ids of every save slot (and the running campaign): the abilities each figure has reached (party.json
## rt.bar / rt.context up to its level, plus the learned list of older saves), held and equipped items, chosen talents.
static func campaign_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for slot in range(1, Save.SLOT_COUNT + 1):
		for f: String in [Save.slot_path(slot), Save.slot_path(slot) + ".bak"]:
			if not FileAccess.file_exists(f):
				continue
			var raw: Variant = JsonUtil.read_file(f)
			if raw is Dictionary:
				var d: Dictionary = SaveCodec.migrate(raw as Dictionary)
				if d.get("state", null) is Dictionary:
					ids_of_state(d["state"] as Dictionary, out)
			break
	if Game.state != null and Game.mode == &"campaign":
		ids_of_state(Game.state.to_dict(), out)
	return out


## Appends the unlock-relevant ids of one state dictionary (SaveCodec / GameState.to_dict format) to `out`.
static func ids_of_state(st: Dictionary, out: PackedStringArray) -> void:
	var party: Variant = st.get("party", [])
	for mv: Variant in (party as Array if party is Array else []):
		if not mv is Dictionary:
			continue
		var m: Dictionary = mv
		var level: int = JsonUtil.to_int(m.get("level", 1), 1)
		var mid: String = str(m.get("id", ""))
		if DB.has_id("party", mid):
			var rt: Dictionary = DB.party_member(mid).rt
			for key: String in ["bar", "context"]:
				var rows: Variant = rt.get(key, [])
				for row: Variant in (rows as Array if rows is Array else []):
					if row is Dictionary and JsonUtil.to_int((row as Dictionary).get("level", 1), 1) <= level:
						_add(out, str((row as Dictionary).get("skill", "")))
		for s: String in JsonUtil.to_str_array(m.get("skills", [])):
			_add(out, s)
		var tal: Variant = m.get("talents", {})
		for k: Variant in ((tal as Dictionary).keys() if tal is Dictionary else []):
			_add(out, str(k))
		var rows2: Variant = m.get("talent_rows", {})
		for v: Variant in ((rows2 as Dictionary).values() if rows2 is Dictionary else []):
			_add(out, str(v))
		var eq: Variant = m.get("equipment", {})
		for v2: Variant in ((eq as Dictionary).values() if eq is Dictionary else []):
			_add(out, str(v2))
	var inv: Variant = st.get("inventory", {})
	var counts: Variant = (inv as Dictionary).get("counts", {}) if inv is Dictionary else {}
	for k2: Variant in ((counts as Dictionary).keys() if counts is Dictionary else []):
		if JsonUtil.to_int((counts as Dictionary)[k2]) > 0:
			_add(out, str(k2))


static func _add(out: PackedStringArray, id: String) -> void:
	if id != "" and not out.has(id):
		out.append(id)
