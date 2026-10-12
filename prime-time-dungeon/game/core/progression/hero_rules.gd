class_name HeroRules extends RefCounted
## Who leads the duo (06 §1, package A): GameState.hero is the controlled character in the exploration ("kai" or
## "mopsula"); the other one follows. Pure rules, no autoloads; Game.set_hero records {"t": "hero", "id"} and applies
## set_hero(), RunSim and both replays apply the same check.
##
## Two checks, one command (06 §1.7): the choice of a new run passes check_initial() — only before the run has
## started (no exploration tick and no encounter yet) — every later change passes check_set() (safe room only).
## check() picks one of them by run_started(), so the live run, Game.replay_log and RunSim.replay decide the same
## command identically.

const HEROES: PackedStringArray = ["kai", "mopsula"]
const DEFAULT_HERO: String = "kai"
## Field ability of the controlled character (06 §1.3): Kai strikes, the Count barks.
const FIELD_ABILITIES: Dictionary = {"kai": &"strike", "mopsula": &"bark"}


## true once the run has started: an encounter / lootbox drew from the run RNG (rng_counter) or the countdown of the
## current floor ran for at least one tick.
static func run_started(state: GameState) -> bool:
	if state == null:
		return true
	if state.rng_counter > 0:
		return true
	return state.floor_run != null and int(state.floor_run.stats.get("time_used_ticks", 0)) > 0


## Choice of a new run: "" | "unknown_hero" | "run_started".
static func check_initial(state: GameState, hero_id: String) -> String:
	if not HEROES.has(hero_id):
		return "unknown_hero"
	if run_started(state):
		return "run_started"
	return ""


## Switch later in the run: "" | "unknown_hero" | "not_in_safe_room" | "same".
static func check_set(state: GameState, hero_id: String) -> String:
	if not HEROES.has(hero_id):
		return "unknown_hero"
	if not RunRules.in_safe_room(state):
		return "not_in_safe_room"
	if state.hero == hero_id:
		return "same"
	return ""


## The check that applies right now (check_initial before the run started, check_set afterwards).
static func check(state: GameState, hero_id: String) -> String:
	if state == null:
		return "not_in_safe_room" if HEROES.has(hero_id) else "unknown_hero"
	return check_initial(state, hero_id) if not run_started(state) else check_set(state, hero_id)


## Applies a choice that passed check(); false (nothing changes) otherwise.
static func set_hero(state: GameState, hero_id: String) -> bool:
	if check(state, hero_id) != "":
		return false
	state.hero = hero_id
	return true


## The character that follows (and, with "Partner automatisch", fights on its own).
static func partner_of(state: GameState) -> String:
	var hero: String = state.hero if state != null else DEFAULT_HERO
	return "mopsula" if hero == "kai" else "kai"


## &"strike" (Kai) | &"bark" (Graf Mopsula); unknown ids → &"strike".
static func field_ability(hero_id: String) -> StringName:
	return FIELD_ABILITIES.get(hero_id, &"strike")


## Talent factors (06 §2.2, package B) on the field ability of the character that leads: {"range_pm", "cd_pm"}
## (integer per-mille, 1000 = neutral). Always the LEADER's own talents — Kai's change the Feldschlag, Graf Mopsula's
## the Bellen; a follower's field talents rest until it leads ("Wirkt, wenn … die Gruppe anführt."). Derived from
## the state (talent ranks + hero), never recorded: what the ability causes (encounter, secret) is.
static func field_mods(state: GameState, data: GameData) -> Dictionary:
	var m: PartyMember = state.member(state.hero) if state != null else null
	return {"range_pm": Talents.field_range_pm(m, data), "cd_pm": Talents.field_cd_pm(m, data)}


## "kai" for anything that is not a known hero id (old saves, hand-edited files).
static func sanitize(hero_id: String) -> String:
	return hero_id if HEROES.has(hero_id) else DEFAULT_HERO
