extends RefCounted
## Private M6 flow helpers shared by the title screens (§0.3): the single "new game" path (TitleScreen.request_new_game
## and NameEntry use it), loading a slot with the routing rules of 02_TECH §6.4, and boot arguments (--seed).

## Seed from the boot argument --seed=<int> (-1 = time based), used by "Neues Spiel".
static var boot_seed: int = -1


## Game.new_game(...) → goto(SCENE_INTRO) or, if skip_intro, goto(SCENE_EXPLORATION, {"spawn": &"start"}).
## `hero_id` (06 §1.1): the controlled character, "kai" | "mopsula". `persona` (08 §1.4, K0 → K1): the candidate of the
## casting (null = none; K1's casting scene passes it). Returns false when no game state could be created.
static func start_new_game(slot: int, player_name: String, skip_intro: bool, seed: int = -1,
		difficulty: StringName = &"prime", hero_id: String = "kai", persona: PersonaProfile = null) -> bool:
	var name_clean: String = clean_name(player_name)
	var s: int = seed if seed != -1 else boot_seed
	Game.new_game(slot, name_clean, s, difficulty, hero_id, persona)
	if not Game.has_state():
		push_warning("[Title] new game failed (no state)")
		return false
	if skip_intro:
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": &"start"})
	else:
		Router.goto(Router.SCENE_INTRO)
	return true


## Player name rules (GDD §14.2): trimmed, max 12 characters, empty → "Kai", unsupported glyphs removed.
static func clean_name(player_name: String) -> String:
	var font: Font = ThemeDB.fallback_font
	var out: String = ""
	for i in player_name.strip_edges().length():
		var c: int = player_name.strip_edges().unicode_at(i)
		if c >= 32 and font.has_char(c):
			out += String.chr(c)
	out = out.strip_edges().substr(0, 12)
	return out if out != "" else "Kai"


## Save.load_slot(slot) and route: unplayable floor → credits; else exploration at the saved location (§6.4).
## Returns the load error (OK on success).
static func load_and_route(slot: int) -> Error:
	var err: Error = Save.load_slot(slot)
	if err != OK:
		return err
	if not Game.has_state() or Game.state.floor_run == null:
		return ERR_INVALID_DATA
	var def: FloorDef = DB.floor_def(Game.state.floor_run.index)
	if def == null or not def.playable:
		Router.goto(Router.SCENE_CREDITS)
	else:
		Router.goto(Router.SCENE_EXPLORATION, {"spawn": Game.state.floor_run.location})
	return OK


## Human-readable load error.
static func load_error_text(err: Error) -> String:
	var detail: String = Save.last_error()
	var base: String = "Spielstand konnte nicht geladen werden"
	if err == ERR_FILE_NOT_FOUND or err == ERR_DOES_NOT_EXIST:
		base = "Kein Spielstand in diesem Slot"
	return base + (": " + detail if detail != "" else ".")


## Parses boot user args: {"autoplay": bool, "autoplay_mode": "" | "smoke" | "full", "seed": int (-1), "goto": String}.
## `--autoplay` (and `--autoplay=smoke`) = the check.sh smoke run, `--autoplay=full` = the full Floor-1 bot (02_TECH
## §11.4.1); an unknown mode falls back to the smoke run.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"autoplay": false, "autoplay_mode": "", "seed": -1, "goto": ""}
	for a: String in args:
		if a == "--autoplay" or a.begins_with("--autoplay="):
			out["autoplay"] = true
			out["autoplay_mode"] = "full" if a == "--autoplay=full" else "smoke"
		elif a.begins_with("--seed="):
			var v: String = a.trim_prefix("--seed=")
			if v.is_valid_int():
				out["seed"] = v.to_int()
		elif a.begins_with("--goto="):
			out["goto"] = a.trim_prefix("--goto=")
	return out
