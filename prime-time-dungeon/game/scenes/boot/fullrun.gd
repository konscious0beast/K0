extends Node
## Full-run bot (02_TECH §11.4.1), added under root by Boot with --autoplay=full (PROCESS_MODE_ALWAYS). Plays Floor 1
## end to end through the game's public APIs and the real interactions:
## title → new game (slot 1, seed 4242, intro) → tutorial fight → room by room over the layout graph (Kai walks with the
## move actions from door to door; only when he is stuck he is teleported to the next waypoint) → chests, gates and
## floor events through the focused interactable + `action` (ExplorationScene.perform_action), regular groups by field
## strike (fallback force_encounter), real-time combats (levelling naturally) → safe rooms (Mopsula scenes, lootboxes,
## vending purchase, equipment, save; the save of the visit that completes the safe rooms is loaded back through the
## title's "Fortsetzen" and must give the same StateHash) → Der Hausmeister → Generalschlüssel → Gleis 9 → optional Die
## Rattenkönigin (FLOOR_BOSS_ATTEMPTS attempts) → stairs → floor summary → credits "Etage 2 folgt" → title, where
## "Fortsetzen" of the autosave must route straight back into the credits (unplayable floor 2).
## On the way it checks timer pauses, the state after every battle, replay ≡ live (Game.replay_log), the rebuilt map
## after loading and the M.O.D. story beats. Strategies: see `strategy`.
## Deterministic decisions (fixed seed, greedy nearest-objective planner with fixed tie order); run it with
## `--fixed-fps 60` (tools/fullrun.sh) so every frame advances the same game time.
## Output: "FULLRUN: <what>" progress lines, then "FULLRUN: stats {json}" (GDD §13 numbers) and
## "FULLRUN: OK floor_time=<s> battles=<n> level=<kai>/<mopsula> deaths=<n> frames=<n>" + quit(0);
## failure: "Assertion failed: FULLRUN failed in <phase>: <reason>" + quit(1).
## Saves go to SAVE_DIR (cleared before and after the run); settings stay ephemeral.
## Casting (08 §1.1, §10.3, K1): --persona=canon (default) plays the casting with "Rest automatisch" (Esc, then Enter on
## "Sendung starten"); --persona=random|<org_id> fills it in through the casting's controls (on-screen keyboard,
## Vorleben / hobby / traits overlays); --persona=none starts without the casting (no persona). With a persona the run
## also checks the persona lines: said at least once, never during a battle. K2 (08 §6): "random" also rolls a look and
## sets it with the look editor's ◀ ▶ buttons; every run checks that Kai's exploration figure wears DB.party_model.
## 06 package A: --hero=kai|mopsula (default kai) picks the controlled character of the new game. As Graf Mopsula the
## bot engages groups with the bark (dazed group → walk into it → PREEMPTIVE; real time: pull it with key 1) instead of
## the field strike, and on the first safe-room visit it switches to Kai and back ("Figur wechseln", two recorded hero
## commands the replay checks cover).
## Echtzeitkampf (07 §12.5, R5b): the run fights in the world (the campaign fights in real time only since R5b part
## 2b) — the director plays each combat with the RtBotPlayer (tests/tools/rt_bot_player.gd, loaded at run time;
## profile --rt-profile=typical|perfect|sloppy, the hero's variant) as the person: its inputs go through
## Game.combat_submit and are recorded like a player's. A hint card is read for HOLD_FRAMES and closed (recorded
## combat_hint, the ticks stand meanwhile); the results panel continues by itself (autoplay). A lost boss is fought
## again after the game over (the Hausmeister until MAX_DEATHS, the optional Königin FLOOR_BOSS_ATTEMPTS times).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const TitleFlow := preload("res://scenes/title/title_flow.gd")
const CASTING: String = "res://scenes/title/persona_casting.tscn"     # Casting (08, K1)
const CASTING_BUDGET: int = 900
## Names the random persona types on the on-screen keyboard (presentation; one of them has an accent).
const PERSONA_NAMES: PackedStringArray = ["Jana", "Mika", "Ole", "Zoé", "Ilka", "Arne", "Defne", "Lou"]
const RUN_SEED: int = 4242                 # --seed=<int> overrides it (TitleFlow.boot_seed)
const SAVE_SLOT: int = 1
const SAVE_DIR: String = "user://fullrun_saves"
const TIME_SCALE: float = 5.0
const WATCHDOG_FRAMES: int = 90000
const MAX_DEATHS: int = 3
const FLOOR_BOSS_ATTEMPTS: int = 2          # R5b: the optional floor boss once more after a defeat
const RT_BOT_PATH: String = "res://tests/tools/rt_bot_player.gd"
const RT_PROFILES: PackedStringArray = ["typical", "perfect", "sloppy"]
## Frame budgets (60 frames = 1 s × TIME_SCALE of game time).
const BOOT_BUDGET: int = 600
const INTRO_BUDGET: int = 4000
const SETTLE_BUDGET: int = 900
const BATTLE_BUDGET: int = 9000
const WALK_STUCK_SEC: float = 1.5          # game seconds without getting 0.25 m closer → teleport to the waypoint
const WALK_BUDGET: int = 900
const ENGAGE_BUDGET: int = 600
const SAFE_BUDGET: int = 1500
const CREDITS_BUDGET: int = 2400
const STRIKE_RANGE: float = 1.4
const BARK_ENGAGE: float = 3.0             # 06 package A: Mopsula barks at a group within 3 m (cone reach 4 m)
const HEROES: PackedStringArray = ["kai", "mopsula"]
const PERSONAS: PackedStringArray = ["none", "canon", "random"]   # + "org_*" (08 §10.2 Nr. 16)
const TIMER_SLACK_TICKS: int = 15          # timer ticks a pause may lose to its transitions (fade-in 0.25 s + a frame)
const STAIRS_HUB: float = 1.6              # room middle of the stairs room: in front of the well's entry fence
const STAND_OFF: float = 1.0               # stand this far in front of an interactable (+ its extent)
const WALL_STAND: float = 1.3              # 06 package A: in front of a Kulissenwand (strike 1.8 m / bark 4 m reach)
const HEAL_ITEM_BELOW: float = 0.5         # use a heal item on a member below 50 % HP
const SAFE_ROOM_BELOW: float = 0.45        # party HP ratio below this → back to the nearest safe room
const SAFE_ROOM_MAX_DIST: int = 6
const BOSS_HP_MIN: float = 0.9             # before a boss: heal in a safe room below 90 % HP / 70 % MP
const BOSS_MP_MIN: float = 0.7
const WHEEL_RESERVE: int = 60              # spin the wheel only with cost + reserve credits
const BANDAGES_WANTED: int = 3
const NO_PROGRESS_LIMIT: int = 4
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const HEAL_ITEMS: PackedStringArray = ["itm_brutzel_burger", "itm_bandage"]

const STRATEGIES: PackedStringArray = ["thorough", "rush", "dawdle", "typical"]
## typical: thorough, but leaves the side groups a4, b3 and c2 alone (12 of 15 groups = GDD §13 "Bekämpfte Gruppen
## 11–13", the 80 % of the GDD §5.4 EXP plan) and does not hunt strays — the first-time player of the GDD targets.
const TYPICAL_SKIP: PackedStringArray = ["f1_g3", "f1_g7", "f1_g10"]
## After losing a boss battle (game over → last save) the bot grinds this many stray fights before the retry: the same
## save and the same commands would replay the same defeat (deterministic seeds, GDD §9.2 no save scumming).
const GRIND_AFTER_DEFEAT: int = 2
const GRIND_WAIT_SEC: float = 100.0        # countdown seconds to wait for a stray (spawner interval 90 s, GDD §2.7)
const PACES: PackedStringArray = ["fast", "human"]
## --pace=human (GDD §13 floor time; game seconds with the countdown running, i.e. never in dialogs/menus/safe rooms):
## looks around / walks the room on entering it for the first time, decides before every objective, lines up at every
## doorway, sneaks the last metres to a group (preemptive strike), reads every M.O.D. line said in the exploration — a
## model of an attentive first-time player who still walks the bot's door-to-door paths (no dead ends, no map browsing).
const HUMAN_LOOK_SEC: float = 8.0          # look around + walk the room (chests, exits, enemies)
const HUMAN_DECIDE_SEC: float = 3.0
const HUMAN_DOOR_SEC: float = 1.0
const HUMAN_SNEAK_DIST: float = 7.0
const HUMAN_READ_SEC: float = 1.0          # + characters / HUMAN_READ_CPS, per M.O.D. line in the exploration
const HUMAN_READ_CPS: float = 18.0
const TRY_LOCKED: String = "try without key"  # objective "why" of a negative try (locked chest / gate without key)
const REQUIRED_BEATS: PackedStringArray = ["first_fight", "safe_room_enter", "scene:scn_mop_1",
	"boss_intro:enm_boss_hausmeister", "stairs_found", "floor_end"]
const HOLD_FRAMES: int = 24                # dialogs / pause menu stay open this long (2 s of game time)
const IDLE_BUDGET: int = 30000             # dawdle: frames to wait for the floor collapse (1200 s = 14 400 frames)
const MAX_STRAY_FIGHTS: int = 3
const STRAY_HUNT_DIST: int = 2             # strays are hunted only this many rooms away

enum Walk { ARRIVED, INTERRUPTED }

var frames: int = 0
var finished: bool = false
## Test hook: no quit()/print and no save-directory changes; the result stays in result_code / result_line.
var dry_run: bool = false
var result_code: int = -1
var result_line: String = ""
var phase: String = "boot"
## "thorough" (default): every group, chest, event and room, then the bosses. "rush" (--strategy=rush): only safe
## rooms, gates and the bosses — under-levelled. "dawdle" (--strategy=dawdle): after the first save Kai idles in the
## exploration until the floor collapses (timer warnings 600/300/60 → expiry → Sendeschluss "timer"). After the first
## game over the bot always loads the last save ("Letzten Spielstand laden") and continues "thorough".
var strategy: String = "thorough"
## "fast" (default): no waits — the lower bound of the floor time. "human" (--pace=human): HUMAN_* waits (see above).
var pace: String = "fast"
## 06 package A: "kai" (default) | "mopsula" (--hero=mopsula): the controlled character of the run.
var hero: String = "kai"
## Casting (08 §10.2 Nr. 16, K1): --persona=none|canon|random|<org_id> → the candidate persona of the new game; the
## default "canon" is what players get with "Rest automatisch", so the bot measures that.
var persona: String = "canon"
var persona_in_battle: int = 0             # persona lines said during a battle (must stay 0, 08 §4.3 R6)
var barks: int = 0                         # barks the bot used (Mopsula) …
var dazed: int = 0                         # … and groups they dazed
var hero_switches: int = 0                 # "Figur wechseln" in a safe room
## 06 package A, E1 secrets (06 §2.7): Kulissenwände knocked over by the field ability, Regie-Notizen read, fallbacks
## (knock_wall without the ability, counted, Soll 0); shortcut measurement: travels whose shortest path runs through
## an opened wall and the cell changes it saved against the path with every wall standing; travel_cells/_ticks give
## the bot's measured seconds per cell change (gain = saved cells × that).
var walls_knocked: int = 0
var notes_read: int = 0
var wall_fallbacks: int = 0
var shortcut_trips: int = 0
var shortcut_cells: int = 0
var travel_cells: int = 0
var travel_ticks: int = 0
## 06-C (06 §4.3) --liga=0|1|2: the Unterhosen-Liga strategy — 1: the controlled hero never wears armor or an
## accessory (taken off at once), 2: both (Duo-Liga). 0 (default): the bot equips its best gear as before.
var liga: int = 0
var timer_warnings: PackedInt32Array = []
var timer_expired: int = 0
var attempt_floor_boss: bool = true
## R5b: the bot profile of the person who plays the real-time combats (--rt-profile).
var rt_profile: String = "typical"
var rt_combats: int = 0                    # combats the bot played (its stream: SeedUtil.derive(seed, "rt_bot", n))
var hints_read: int = 0                    # hint cards the bot read and closed (07 §2.13)
var _rt_result: BattleResult = null        # Events.combat_finished of the running real-time combat (null: recorded)
var _rt_tl0: int = 0                       # the countdown at Events.combat_started …
var _rt_tl_end: int = 0                    # … and at Events.combat_finished (the clock must stand in between)
var _rt_seed: int = 0
## Measured numbers (see stats()).
var battles: Array[Dictionary] = []
var deaths: int = 0
var teleports: int = 0
var direct_interactions: int = 0
var forced_encounters: int = 0
var boss_levels: Dictionary = {}           # encounter id → [kai level, mopsula level] at battle start
var boss_exp: Dictionary = {}              # encounter id → [kai, mopsula] total EXP (GDD §4.3) at battle start
var boss_kit: Dictionary = {}              # encounter id → {"equipment", "items", "hp", "mp"} at the first battle start
var credits_earned: int = 0
var credits_spent: int = 0
var boxes_earned: int = 0
var boxes_opened: int = 0
var purchases: Array[String] = []
var saves: int = 0
var roundtrip_hash: String = ""
var summary: Dictionary = {}
var floor_boss_attempts: int = 0
var strays_spawned: int = 0
var hype_reasons: Dictionary = {}          # reason → summed hype delta of the running battle (diagnostics)
var talents_picked: PackedStringArray = []  # 06 package B: "<member>@L<level>:<talent id>" in pick order
var credits_by_source: Dictionary = {}     # "battle" | "safe_room" | "explore" → credits earned
var replay_checks: int = 0
var paused_checked: bool = false
var tried: Dictionary = {}                 # negative paths tried once (locked chest / gate, ignore, "Noch nicht")
var mod_tags: PackedStringArray = []       # "<tag>@before|countdown" of every M.O.D./Mopsula line (story beats)
var gifts: Array[String] = []              # sponsor ids of all gifts (Events.sponsor_gift_triggered)
var boxes_by_id: Dictionary = {}           # lootbox id → earned
var credits_lootbox: int = 0               # credits out of lootboxes (incl. duplicates converted to credits)
var human_wait_sec: float = 0.0            # --pace=human: countdown seconds spent in HUMAN_* waits
var grind_fights: int = 0                  # stray fights still to grind before a boss retry (GRIND_AFTER_DEFEAT)
var credits_before_floor_boss: int = -1    # credits earned when the floor boss battle starts (GDD §13 "bei Königin")
var liga_bonus_followers: int = -1         # 06 §4.3 (round 4): the floor's capped Liga follower bonus at the summary
var _retry_boss: bool = false             # the running battle is a boss the bot will fight again after a defeat
var _gifts_battle: int = 0
var _hype_peak_battle: int = 0
var _read_backlog: float = 0.0             # --pace=human: reading time of M.O.D. lines not yet waited for

var _hype_start: int = 0
var _idle_from_ticks: int = -1             # dawdle: countdown when the idling started
var _roundtrip_done: bool = false
var _verify_scene: bool = false            # after the save/load roundtrip: compare the rebuilt map with the state
var _floor_done: bool = false
var _last_sig: String = ""
var _same_sig: int = 0
var _heal_trips: int = 0
var _saved_events: int = 0
var _log: PackedStringArray = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not dry_run:
		prepare_saves()
		strategy = strategy_from_args(OS.get_cmdline_user_args())
		pace = pace_from_args(OS.get_cmdline_user_args())
		hero = hero_from_args(OS.get_cmdline_user_args())
		liga = liga_from_args(OS.get_cmdline_user_args())
		persona = persona_from_args(OS.get_cmdline_user_args())
		rt_profile = rt_profile_from_args(OS.get_cmdline_user_args())
		_season_setup(season_from_args(OS.get_cmdline_user_args()))   # Staffeln (09, ST1-I)
	Events.combat_started.connect(func(_sim: RefCounted) -> void:
		if not Game.replaying:
			_rt_result = null
			_rt_tl0 = Game.state.floor_run.time_left_ticks if Game.state != null and Game.state.floor_run != null \
				else 0)
	Events.combat_finished.connect(func(r: RefCounted) -> void:
		if not Game.replaying:
			_rt_result = r as BattleResult
			_rt_tl_end = Game.state.floor_run.time_left_ticks if Game.state != null and Game.state.floor_run != null \
				else 0)
	# Counters ignore Game.replay_log() (the replay check re-emits the same signals).
	Events.battle_started.connect(_on_battle_started)
	Events.credits_changed.connect(_on_credits_changed)
	Events.lootbox_earned.connect(func(id: String) -> void:
		if not Game.replaying:
			boxes_earned += 1
			boxes_by_id[id] = int(boxes_by_id.get(id, 0)) + 1)
	Events.lootbox_opened.connect(func(_id: String, r: Array) -> void:
		if not Game.replaying:
			boxes_opened += 1
			for lr: Variant in r:
				if lr is LootReward and (lr as LootReward).kind == "credits":
					credits_lootbox += (lr as LootReward).amount)
	Events.sponsor_gift_triggered.connect(func(sid: String) -> void:
		if not Game.replaying:
			gifts.append(sid)
			if Game.in_battle:
				_gifts_battle += 1)
	Events.game_saved.connect(func(_slot: int, ok: bool) -> void:
		if ok:
			_saved_events += 1)
	Events.hype_changed.connect(func(h: float, delta: float, reason: StringName) -> void:
		if Game.in_battle and not Game.replaying:
			hype_reasons[String(reason)] = float(hype_reasons.get(String(reason), 0.0)) + delta
			_hype_peak_battle = maxi(_hype_peak_battle, roundi(h)))
	Events.mod_said.connect(func(text: String, _voice: StringName, tag: String, blocking: bool) -> void:
		if not Game.replaying:
			mod_tags.append("%s@%s" % [tag, "countdown" if Game.state != null and Game.state.floor_run != null
				and Game.state.floor_run.timer_started else "before"])
			if tag.begins_with("persona_") and Game.in_battle:
				persona_in_battle += 1
			if pace == "human" and not blocking and not Game.in_battle and Game.is_timer_ticking():
				_read_backlog += HUMAN_READ_SEC + float(text.length()) / HUMAN_READ_CPS)
	Events.floor_timer_warning.connect(func(sec: int) -> void:
		if not Game.replaying:
			timer_warnings.append(sec))
	Events.floor_timer_expired.connect(func() -> void:
		if not Game.replaying:
			timer_expired += 1)
	Events.stray_spawn_requested.connect(func(_z: String, _g: String, _e: String) -> void:
		if not Game.replaying:
			strays_spawned += 1)
	Events.item_bought.connect(func(p: Dictionary) -> void:
		if not Game.replaying:
			purchases.append("%s×%d" % [str(p.get("item_id", "")), int(p.get("qty", 1))]))
	Events.field_ability_used.connect(func(_h: String, ability: StringName, hits: int) -> void:
		if ability == &"bark" and not Game.replaying:
			barks += 1
			dazed += hits)
	if not dry_run:
		_main.call_deferred()


func _process(delta: float) -> void:
	if finished:
		return
	frames += 1
	var watchdog: int = WATCHDOG_FRAMES if season_def == "" else SEASON_WATCHDOG_FRAMES   # Staffeln (ST1-I)
	if frames > watchdog:
		fail("watchdog (%d frames)" % watchdog)
	if season_def != "":                           # Staffeln (09, ST1-I): play time, the calendar's clock
		_season_process(delta)


## --strategy=rush|dawdle → that strategy; anything else → "thorough".
static func strategy_from_args(args: PackedStringArray) -> String:
	for st: String in STRATEGIES:
		if args.has("--strategy=" + st):
			return st
	return "thorough"


## --pace=human → "human"; anything else → "fast".
static func pace_from_args(args: PackedStringArray) -> String:
	return "human" if args.has("--pace=human") else "fast"


## 06 package A: --hero=mopsula → "mopsula"; anything else → "kai".
static func hero_from_args(args: PackedStringArray) -> String:
	for h: String in HEROES:
		if args.has("--hero=" + h):
			return h
	return "kai"


## Casting (08 §10.2 Nr. 16, K1): --persona=none|canon|random|<org_id> → that choice; anything else → "canon" (what
## players get with "Rest automatisch", so the bot measures that).
static func persona_from_args(args: PackedStringArray) -> String:
	for a: String in args:
		if a.begins_with("--persona="):
			var v: String = a.trim_prefix("--persona=")
			if PERSONAS.has(v) or v.begins_with("org_"):
				return v
	return "canon"


## The profile the bot enters for `persona` (canon: PersonaProfile.canon; random: a valid persona seeded by the run
## seed — name, word form, Vorleben (+ job), hobby, 0–3 traits, a look (K2); org_*: that tile with the canon rest);
## null = none.
func persona_profile() -> PersonaProfile:
	if persona == "none" or DB.data == null:
		return null
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	if persona == "canon":
		return p
	if persona.begins_with("org_"):
		if DB.data.origin(persona).is_empty():
			return p
		p.origin = persona
		p.occupation = ""
		p.source = "offline"
		p.make_beats(DB.data, null)
		return p
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeedUtil.derive(TitleFlow.boot_seed if TitleFlow.boot_seed >= 0 else RUN_SEED, "fullrun_persona", 0)
	p.name = PERSONA_NAMES[rng.randi_range(0, PERSONA_NAMES.size() - 1)]
	p.form = PersonaProfile.FORMS[rng.randi_range(0, PersonaProfile.FORMS.size() - 1)]
	var tiles: Array[Dictionary] = []
	for e: Dictionary in DB.data.all_origins():
		if str(e["id"]) != PersonaProfile.ALLROUND:
			tiles.append(e)
	var o: Dictionary = tiles[rng.randi_range(0, tiles.size() - 1)]
	p.origin = str(o["id"])
	var jobs: Array = o.get("jobs", []) as Array
	p.occupation = str((jobs[rng.randi_range(0, jobs.size() - 1)] as Dictionary)["id"]) if not jobs.is_empty() else ""
	var hobbies: Array[Dictionary] = DB.data.persona_list("hobbies")
	p.hobby = str(hobbies[rng.randi_range(0, hobbies.size() - 1)]["id"])
	var traits: Array[Dictionary] = DB.data.persona_list("traits")
	p.traits = PackedStringArray()
	for i in rng.randi_range(0, 3):
		var t: String = str(traits[rng.randi_range(0, traits.size() - 1)]["id"])
		if not p.traits.has(t):
			p.traits.append(t)
	var look: Dictionary = {}                     # K2 (08 §6.1): one option per kind (drawn last: K1's fields stay)
	for kind: String in PersonaProfile.LOOK_KINDS:
		var opts: Array[Dictionary] = DB.data.looks_of(kind)
		if not opts.is_empty():
			look[kind] = str(opts[rng.randi_range(0, opts.size() - 1)]["id"])
	p.look = PersonaProfile.clean_look(look, DB.data)
	p.source = "offline"
	p.make_beats(DB.data, null)
	return p


## 06-C: --liga=1|2 → that Liga tier; anything else → 0.
static func liga_from_args(args: PackedStringArray) -> int:
	for t: int in [1, 2]:
		if args.has("--liga=%d" % t):
			return t
	return 0


## 06-C: the members the Liga strategy keeps without armor / accessory (tier 1: the controlled hero, 2: both).
func liga_members() -> PackedStringArray:
	var out: PackedStringArray = []
	if liga <= 0 or Game.state == null:
		return out
	for m: PartyMember in Game.state.party:
		if liga >= 2 or m.id == MarottenRules.hero_of(Game.state):
			out.append(m.id)
	return out


## Real saves into a private directory (Boot: --autoplay=full), emptied first.
func prepare_saves() -> void:
	Save.save_dir = SAVE_DIR
	Save.read_only = false
	clear_saves()


static func clear_saves() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for f: String in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))


# ======================================================================================================================
# Main flow
# ======================================================================================================================

func _main() -> void:
	if season_def != "":                           # Staffeln (09, ST1-I): the floors of a season
		await _season_main()
		return
	phase = "boot_to_title"
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, BOOT_BUDGET, "title"):
		return
	phase = "new_game"
	var run_seed: int = TitleFlow.boot_seed if TitleFlow.boot_seed >= 0 else RUN_SEED
	var cast: PersonaProfile = persona_profile()     # Casting (08 §10.2 Nr. 16, K1)
	_note("new game, seed %d, strategy %s, hero %s, persona %s" % [run_seed, strategy, hero,
		persona if cast != null else "none"])
	if cast == null:
		(Router.current as TitleScreen).request_new_game(SAVE_SLOT, "Kai", false, run_seed, &"prime", hero)
	elif not await _casting(run_seed, cast):
		return
	if not await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, INTRO_BUDGET,
			"exploration after the intro"):
		return
	if not check_hero(_ex(), hero) or not check_look(_ex()):
		return
	_rt_seed = run_seed
	if load(RT_BOT_PATH) == null:
		fail("real-time run without %s (the bot is part of the test tools)" % RT_BOT_PATH)
		return
	_note("real-time combat, bot profile %s" % rt_profile)
	_note("floor 1 entered (intro played)")
	while not finished and not _floor_done:
		if not await settle():
			return
		if not paused_checked and Game.state.floor_run.timer_started:
			if not await pause_check(_ex()):
				return
			continue
		var obj: Dictionary = next_objective()
		phase = objective_text(obj)
		if not _check_progress(obj):
			return
		if pace == "human" and str(obj["kind"]) != "idle":
			if not await human_wait(HUMAN_DECIDE_SEC):
				return
			if _interrupted(_ex()):
				continue
		if not await _do(obj):
			return
	if finished:
		return
	if not await _after_stairs():
		return
	if not check_story_beats():
		return
	_finish_ok()


# ======================================================================================================================
# Casting (08 §1, K1): the new game through the casting scene
# ======================================================================================================================

## Plays the casting like a player: the canon persona with "Rest automatisch" (Esc) and Enter on "Sendung starten";
## any other profile through the controls — the name on the on-screen keyboard, the form, the Vorleben / hobby / traits
## overlays, "Weiter" twice, "Sendung starten". Checks the card, the recorded command (persona v2 since 09 ST0: the
## head-start profession, the hobby recipe and the traits' bias — PersonaRules.command_for of the entered profile)
## and the local profile. false = the run failed.
func _casting(run_seed: int, cast: PersonaProfile) -> bool:
	phase = "casting"
	var log_before: RunLog = Game.run_log
	Router.goto(CASTING, {"slot": SAVE_SLOT, "hero": hero, "seed": run_seed})
	if not await _wait(_scene_is.bind(CASTING), CASTING_BUDGET, "the casting"):
		return false
	var scene: Node = Router.current
	await get_tree().process_frame
	if persona == "canon":
		_key(KEY_ESCAPE)                         # "Rest automatisch" (08 §1.5): nothing set → the canon Kai
		if not await _wait(func() -> bool: return int(scene.get("page")) == 3, 120, "casting 3/3 after Esc"):
			return false
		var final: PersonaProfile = scene.get("final") as PersonaProfile
		if final == null or final.name != GameState.DEFAULT_NAME or not final.is_canon(DB.data):
			return fail("\"Rest automatisch\" without input must give the canon Kai")
		await get_tree().process_frame
		if get_viewport().gui_get_focus_owner() != scene.get("start_button"):
			return fail("after \"Rest automatisch\" the focus is not on \"Sendung starten\"")
		_key(KEY_ENTER)                          # the second input: the show starts
	else:
		scene.call("open_keyboard", "name")
		var osk: Node = scene.get("overlay")
		for ch: String in cast.name:
			osk.call("insert", ch)
		osk.call("submit")
		scene.call("set_form", cast.form)
		if not _casting_look(scene, cast.look):
			return false
		scene.call("next")
		if int(scene.get("page")) != 2:
			return fail("the name '%s' was not accepted: %s" % [cast.name, str(scene.get("profile").get("name"))])
		scene.call("open_picker", "origin")
		var picker: Node = scene.get("overlay")
		picker.call("choose", cast.origin)
		if cast.occupation != "":
			picker.call("choose_job", cast.occupation)
		elif is_instance_valid(picker) and scene.get("overlay") == picker:
			picker.call("close")
		scene.call("open_picker", "hobby")
		(scene.get("overlay") as Node).call("choose", cast.hobby)
		scene.call("open_picker", "traits")
		var tp: Node = scene.get("overlay")
		for t: String in cast.traits:
			tp.call("choose", t)
		tp.call("close")
		scene.call("next")
		var final2: PersonaProfile = scene.get("final") as PersonaProfile
		if final2 == null:
			return fail("no card on casting 3/3")
		for f: String in ["name", "form", "origin", "occupation", "hobby"]:
			if str(final2.get(f)) != str(cast.get(f)):
				return fail("casting card %s = '%s', expected '%s'" % [f, str(final2.get(f)), str(cast.get(f))])
		if final2.traits != cast.traits:
			return fail("casting card traits %s, expected %s" % [str(final2.traits), str(cast.traits)])
		if final2.look != cast.look:
			return fail("casting card look %s, expected %s" % [str(final2.look), str(cast.look)])
		scene.call("start_show")
	if not await _wait(func() -> bool: return Game.run_log != null and Game.run_log != log_before, CASTING_BUDGET,
			"the new game after the casting"):
		return false
	var cmd: Dictionary = {}
	for e: Dictionary in Game.run_log.cmds() if Game.run_log != null else ([] as Array[Dictionary]):
		if str((e["c"] as Dictionary).get("t", "")) == "persona":
			cmd = e["c"]
			break
	var want: Dictionary = PersonaRules.command_for(DB.data, cast)
	if cmd != want:
		return fail("the persona command is %s (expected %s)" % [str(cmd), str(want)])
	if Game.persona == null or Game.state.player_name != cast.name:
		return fail("the new game has no persona / name '%s'" % Game.state.player_name)
	if Game.persona.look != cast.look:
		return fail("the new game's look is %s, expected %s" % [str(Game.persona.look), str(cast.look)])
	_note("casting: %s · %s%s · %s · %s" % [cast.name, cast.origin, (" / " + cast.occupation) if cast.occupation != ""
		else "", cast.hobby, ", ".join(cast.traits) if not cast.traits.is_empty() else "ohne Eigenschaften"])
	_note("casting look: %s" % " · ".join(PackedStringArray(PersonaLook.ids(cast.look, DB.data).values())))
	return true


## Casting 1/3 (K2, 08 §6.1): presses the look editor's ▶ (or ◀ when that way is shorter) until every kind shows
## `look`, like a player.
func _casting_look(scene: Node, look: Dictionary) -> bool:
	var rows: Dictionary = scene.get("look_rows")
	for kind: String in PersonaProfile.LOOK_KINDS:
		var ids: PackedStringArray = []
		for e: Dictionary in DB.data.looks_of(kind):
			ids.append(str(e["id"]))
		var want: String = str(look.get(kind, ""))
		var steps: int = posmod(ids.find(want) - ids.find(str(scene.call("look_id", kind))), maxi(1, ids.size()))
		var forward: bool = steps * 2 <= ids.size()
		for i in (steps if forward else ids.size() - steps):
			((rows[kind] as Dictionary)["next" if forward else "prev"] as Button).pressed.emit()
		if str(scene.call("look_id", kind)) != want:
			return fail("the look editor shows %s '%s', expected '%s'" % [kind, str(scene.call("look_id", kind)), want])
	return true


func _scene_is(path: String) -> bool:
	return Router.current != null and Router.current.scene_file_path == path and not Router.busy


## One key press (pressed + released) through the input pipeline, like a player's keyboard.
func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventKey = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Waits until the exploration is calm (no combat / dialog / transition): combats, safe rooms and game overs on the
## way are played through. false = the run failed.
func settle() -> bool:
	var n: int = 0
	while not finished:
		var cur: Node = Router.current
		if not Router.busy and cur != null:
			if cur is SafeRoomScene:
				if not await _safe_room(cur as SafeRoomScene):
					return false
				n = 0
				continue
			if cur.scene_file_path == Router.SCENE_GAME_OVER:
				if not await _game_over(cur):
					return false
				n = 0
				continue
			if cur is ExplorationScene:
				var ex: ExplorationScene = cur as ExplorationScene
				if _rt_arm(ex):
					if not await _rt_combat(ex):
						return false
					n = 0
					continue
				if ex.active_dialog() != null and not ex.is_revealing():
					ex.active_dialog().cancel()             # a dialog the bot did not open: close it
				elif not ex.is_encounter_pending() and not ex.is_modal():
					return true
			elif not (cur is FloorSummary):
				return fail("unexpected screen %s" % _screen_name(cur))
		n += 1
		if n > SETTLE_BUDGET:
			return fail("exploration did not settle within %d frames (%s)" % [SETTLE_BUDGET, state_text()])
		await get_tree().process_frame
	return false


# ======================================================================================================================
# Planner
# ======================================================================================================================

## Next goal from the game state: {"kind": "group"|"chest"|"event"|"gate"|"safe"|"visit"|"boss"|"stairs"|"idle",
## "id": String, "cell": Vector2i, "why": String}. Nearest reachable candidate first (BFS over open doors, living
## bosses block); none left → quarter boss → floor boss (optional) → stairs.
func next_objective() -> Dictionary:
	var ex: ExplorationScene = _ex()
	var layout: FloorLayout = ex.get_layout()
	var fr: FloorRun = Game.state.floor_run
	var here: Vector2i = ex.get_player_cell()
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, _boss_blocks(layout, fr, Vector2i(-99, -99)))
	_use_heal_items()
	equip_best()
	if fr.defeated_groups.is_empty() and layout.enemy_by_id("f1_g0") != null:
		return {"kind": "group", "id": "f1_g0", "cell": layout.enemy_by_id("f1_g0").cell, "why": "tutorial"}
	if strategy == "dawdle" and saves > 0:
		return {"kind": "idle", "id": "", "cell": here, "why": "until the floor collapses"}
	if grind_fights > 0:
		var stray: Dictionary = _nearest_stray(layout, dist)
		if not stray.is_empty():
			return stray
		return {"kind": "wait", "id": "", "cell": here, "why": "for a stray to grind (%d left)" % grind_fights}
	if party_ratio("hp") < SAFE_ROOM_BELOW and _heal_trips < 2:
		var sr: Dictionary = _nearest_safe(layout, dist)
		if not sr.is_empty() and int(dist.get(sr["cell"], 99)) <= SAFE_ROOM_MAX_DIST:
			_heal_trips += 1
			sr["why"] = "heal"
			return sr
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	for c: Dictionary in candidates(layout, fr, dist):
		var d: int = int(dist.get(c["cell"], -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = c
	if not best.is_empty():
		return best
	var boss: Dictionary = _boss_objective(layout, fr)
	if not boss.is_empty():
		var need_heal: bool = party_ratio("hp") < BOSS_HP_MIN or party_ratio("mp") < BOSS_MP_MIN
		if need_heal and _heal_trips < 2:
			var sr2: Dictionary = _nearest_safe(layout, dist)
			if not sr2.is_empty():
				_heal_trips += 1
				sr2["why"] = "heal before " + str(boss["id"])
				return sr2
		return boss
	return {"kind": "stairs", "id": "stairs", "cell": layout.stairs, "why": ""}


## Every open goal in a fixed order (groups, chests, events, gates, safe rooms, unvisited rooms); boss rooms and the
## stairs room are not visited for their own sake.
func candidates(layout: FloorLayout, fr: FloorRun, dist: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rush: bool = strategy == "rush"
	var typical: bool = strategy == "typical"
	for e: EnemySpawn in layout.enemies:
		if typical and TYPICAL_SKIP.has(e.id):
			continue
		if not rush and not e.is_boss and not e.is_stray() and not fr.defeated_groups.has(e.id):
			out.append({"kind": "group", "id": e.id, "cell": e.cell, "why": e.encounter_id})
	# Living strays (GDD §2.7) close by (≤ STRAY_HUNT_DIST rooms), while the budget lasts (they come back every 90 s).
	var ex: ExplorationScene = _ex()
	if not rush and not typical and ex != null and strays_fought() < MAX_STRAY_FIGHTS:
		var sids: Array = fr.strays.keys()
		sids.sort()
		for gid: Variant in sids:
			var a: Node3D = ex.get_enemy(str(gid))
			var sc: Vector2i = layout.world_to_cell(a.global_position) if a != null else Vector2i(-99, -99)
			if a != null and int(dist.get(sc, 99)) <= STRAY_HUNT_DIST:
				out.append({"kind": "group", "id": str(gid), "cell": sc,
					"why": "stray " + str((fr.strays[gid] as Dictionary).get("enc", ""))})
	var has_key: bool = Game.state.inventory.has(RunRules.KEY_MASTER)
	for ch: ChestSpawn in layout.chests:
		if not rush and not fr.opened_chests.has(ch.id) and (ch.type != "locked" or has_key):
			out.append({"kind": "chest", "id": ch.id, "cell": ch.cell, "why": ch.type})
		elif not rush and ch.type == "locked" and not has_key and not tried.has(ch.id):
			out.append({"kind": "chest", "id": ch.id, "cell": ch.cell, "why": TRY_LOCKED})
	for ev: EventSpawn in layout.events:
		var choice: String = event_choice(ev)
		if not rush and choice != "":
			out.append({"kind": "event", "id": ev.id, "cell": ev.cell, "why": choice})
	if not rush and not typical:                  # 06 package A: E1 secrets (thorough / dawdle)
		out.append_array(_secret_candidates(layout, fr, dist))
	for g: Dictionary in layout.gates:
		var req: String = str(g["requires"])
		if Secrets.is_secret_requirement(req):
			continue                              # Kulissenwand: a secret objective, never a gate to try
		if not fr.opened_gates.has(str(g["key"])) and not req.begins_with("event:") and Game.state.inventory.has(req):
			out.append({"kind": "gate", "id": str(g["key"]), "cell": g["cell"], "why": req})
		elif not rush and not fr.opened_gates.has(str(g["key"])) and not tried.has(str(g["key"])):
			out.append({"kind": "gate", "id": str(g["key"]), "cell": g["cell"], "why": TRY_LOCKED})
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		if not fr.visited_safe_rooms.has(str(sid)):
			out.append({"kind": "safe", "id": str(sid), "cell": (layout.safe_room_info[sid] as Dictionary)["cell"],
				"why": "first visit"})
	for c: Vector2i in layout.sorted_cells():
		var rc: RoomCell = layout.cell_at(c)
		if rush or fr.visited.has(c) or rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS \
				or rc.kind == RoomCell.Kind.STAIRS:
			continue
		out.append({"kind": "visit", "id": "", "cell": c, "why": "unvisited"})
	return out


## 06 package A: standing Kulissenwände (goal = the side the bot is closer to) and readable Regie-Notizen.
func _secret_candidates(layout: FloorLayout, fr: FloorRun, dist: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in layout.gates:
		var sid: String = Secrets.id_of_requirement(str(g["requires"]))
		if sid == "" or fr.opened_gates.has(str(g["key"])):
			continue
		var a: Vector2i = g["cell"]
		var b: Vector2i = a + RoomCell.dir_offset(int(g["dir"]))
		var da: int = int(dist.get(a, 1 << 20))
		var db: int = int(dist.get(b, 1 << 20))
		out.append({"kind": "wall", "id": sid, "cell": a if da <= db else b, "why": "Kulissenwand"})
	for sec: Dictionary in Secrets.list(Game.floor_def()):
		var nid: String = str(sec.get("id", ""))
		if str(sec.get("kind", "")) == "note" and Secrets.check_open(Game.state, Game.floor_def(), nid) == "":
			out.append({"kind": "note", "id": nid, "cell": JsonUtil.arr_to_vec2i(sec.get("cell", [])),
				"why": "Regie-Notiz %d" % int(sec.get("n", 0))})
	return out


## The choice the bot makes at a floor event ("" = nothing to do there).
func event_choice(ev: EventSpawn) -> String:
	var fr: FloorRun = Game.state.floor_run
	var avail: PackedStringArray = FloorEvent.choices(ev, Game.state, DB.data)
	if ev.type == "wheel":
		var cost: int = int(ev.params.get("cost", 0))
		if not (avail.has("spin") and Game.state.inventory.credits >= cost + WHEEL_RESERVE):
			return ""
		return "spin" if tried.has(ev.id) else "ignore"            # "Ignorieren" once first: closes, changes nothing
	if fr.completed_events.has(ev.id):
		return ""
	match ev.type:
		"photo_drone":
			return "pose" if avail.has("pose") else ""
		"lost_candidate":
			for c: String in avail:
				if c.begins_with(FloorEvent.GIVE_PREFIX):
					return c
			return ""                     # "Weitergehen" keeps it open (02_TECH §7.4): come back with a heal item
		"lever":
			return "pull" if avail.has("pull") else ""
		"broken_vending":
			return "kick" if avail.has("kick") else ""
	return ""


func _boss_objective(layout: FloorLayout, fr: FloorRun) -> Dictionary:
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated:
		return {"kind": "boss", "id": "f%d_qb" % fr.index, "cell": layout.quarter_boss, "why": "quarter boss"}
	if attempt_floor_boss and layout.floor_boss != Vector2i(-1, -1) and not fr.floor_boss_defeated \
			and floor_boss_attempts < floor_boss_attempts_max():
		return {"kind": "boss", "id": "f%d_fb" % fr.index, "cell": layout.floor_boss, "why": "floor boss"}
	return {}


## Living boss rooms (never walked through unless they are the goal).
func _boss_blocks(layout: FloorLayout, fr: FloorRun, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if layout.quarter_boss != Vector2i(-1, -1) and not fr.quarter_boss_defeated and layout.quarter_boss != goal:
		out.append(layout.quarter_boss)
	if layout.floor_boss != Vector2i(-1, -1) and not fr.floor_boss_defeated and layout.floor_boss != goal:
		out.append(layout.floor_boss)
	return out


func _nearest_safe(layout: FloorLayout, dist: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	var sids: Array = layout.safe_room_info.keys()
	sids.sort()
	for sid: Variant in sids:
		var cell: Vector2i = (layout.safe_room_info[sid] as Dictionary)["cell"]
		var d: int = int(dist.get(cell, -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = {"kind": "safe", "id": str(sid), "cell": cell, "why": ""}
	return best


## Nearest living stray group (any distance) as a "group" objective; {} if none.
func _nearest_stray(layout: FloorLayout, dist: Dictionary) -> Dictionary:
	var ex: ExplorationScene = _ex()
	var fr: FloorRun = Game.state.floor_run
	var best: Dictionary = {}
	var best_d: int = 1 << 20
	var sids: Array = fr.strays.keys()
	sids.sort()
	for gid: Variant in sids:
		var a: Node3D = ex.get_enemy(str(gid)) if ex != null else null
		if a == null:
			continue
		var sc: Vector2i = layout.world_to_cell(a.global_position)
		var d: int = int(dist.get(sc, -1))
		if d >= 0 and d < best_d:
			best_d = d
			best = {"kind": "group", "id": str(gid), "cell": sc,
				"why": "grind " + str((fr.strays[gid] as Dictionary).get("enc", ""))}
	return best


## Grinding after a boss defeat: stands still until a stray exists (or GRIND_WAIT_SEC of countdown passed).
func _wait_for_stray() -> bool:
	var ex: ExplorationScene = _ex()
	var fr: FloorRun = Game.state.floor_run
	var tl0: int = fr.time_left_ticks
	var want: int = roundi(GRIND_WAIT_SEC * Game.TICKS_PER_SEC)
	var budget: int = roundi(GRIND_WAIT_SEC * 60.0 / TIME_SCALE) + 240
	UiUtil.release_move_actions()
	var n: int = 0
	while not finished and not _interrupted(ex) and fr.strays.is_empty() and tl0 - fr.time_left_ticks < want:
		n += 1
		if n > budget:
			return fail("waited %d frames for a stray (%s)" % [budget, state_text()])
		await get_tree().process_frame
	if fr.strays.is_empty() and tl0 - fr.time_left_ticks >= want:
		grind_fights = 0                       # no stray came: retry without grinding
	return not finished


static func objective_text(obj: Dictionary) -> String:
	var c: Vector2i = obj.get("cell", Vector2i.ZERO)
	var why: String = str(obj.get("why", ""))
	return "%s %s (%d,%d)%s" % [str(obj.get("kind", "")), str(obj.get("id", "")), c.x, c.y,
		(" [" + why + "]") if why != "" else ""]


## Fails when the same objective comes back NO_PROGRESS_LIMIT times without any change of the floor state.
func _check_progress(obj: Dictionary) -> bool:
	var fr: FloorRun = Game.state.floor_run
	var uses: int = 0
	for v: Variant in fr.event_uses.values():
		uses += int(v)
	var sig: String = "%s|%d|%d|%d|%d|%d|%d|%s|%s|%d|%d|%d|%d" % [objective_text(obj), fr.visited.size(),
		fr.opened_chests.size(), fr.defeated_groups.size(), fr.completed_events.size(), fr.opened_gates.size(),
		fr.safe_room_visits, str(fr.quarter_boss_defeated), str(fr.floor_boss_defeated), battles.size(), uses,
		tried.size(), Secrets.opened(Game.state).size()]
	if sig == _last_sig:
		_same_sig += 1
		if _same_sig >= NO_PROGRESS_LIMIT:
			return fail("no progress after %d attempts (%s)" % [_same_sig, state_text()])
	else:
		_same_sig = 0
		_last_sig = sig
	return true


# ======================================================================================================================
# Objectives
# ======================================================================================================================

func _do(obj: Dictionary) -> bool:
	var kind: String = str(obj["kind"])
	var cell: Vector2i = obj["cell"]
	if kind == "idle":
		return await _idle_until_collapse()
	if kind == "wait":
		return await _wait_for_stray()
	if kind != "safe" and kind != "boss":
		_heal_trips = 0
	var w: int = await travel(cell)
	if finished:
		return false
	if w == Walk.INTERRUPTED:
		return true
	var ex: ExplorationScene = _ex()
	match kind:
		"group":
			return await _engage(ex, str(obj["id"]))
		"wall":
			return await _knock_wall(ex, str(obj["id"]))
		"chest", "event", "safe", "stairs", "note":
			var it: Node = ex.get_interactable(str(obj["id"]))
			if it == null:
				return fail("no interactable '%s' in the scene" % str(obj["id"]))
			return await _use_interactable(ex, it, obj)
		"gate":
			var gate: Node = ex.get_interactable(str(obj["id"]))
			if gate == null:
				return fail("no gate '%s' in the scene" % str(obj["id"]))
			return await _use_interactable(ex, gate, obj)
		"boss":
			# Walking into the room triggers the boss (5 m around boss_spot); stand on the spot if it did not.
			if await walk_to(ex, ex.get_layout().cell_to_world(cell)) == Walk.INTERRUPTED:
				return true
			if Router.current == ex and not ex.is_encounter_pending():
				forced_encounters += 1
				ex.force_encounter(str(obj["id"]))
			return true
	return true


## Keeps the open dialog / menu up for HOLD_FRAMES: the floor timer must not move meanwhile (GDD §2.9).
func _hold_and_check_timer(what: String) -> bool:
	var tl0: int = Game.state.floor_run.time_left_ticks
	for _i in HOLD_FRAMES:
		await get_tree().process_frame
		if finished:
			return false
	if Game.state.floor_run.time_left_ticks != tl0:
		return fail("the floor timer ran %d ticks while the %s was open" % [tl0 - Game.state.floor_run.time_left_ticks,
			what])
	return true


## Pause menu over the exploration (action `pause` → ExplorationHud → PauseMenu): tree paused, timer stopped; ui_cancel
## closes it and the countdown goes on. Once per run, right after the countdown started.
func pause_check(ex: ExplorationScene) -> bool:
	phase = "pause menu"
	var fr: FloorRun = Game.state.floor_run
	UiUtil.tap_action(&"pause", true)
	await get_tree().process_frame
	UiUtil.tap_action(&"pause", false)
	if not await _wait(func() -> bool: return get_tree().paused, 60, "the pause menu (tree paused)"):
		return false
	if not await _hold_and_check_timer("pause menu"):
		return false
	UiUtil.tap_action(&"ui_cancel", true)
	await get_tree().process_frame
	UiUtil.tap_action(&"ui_cancel", false)
	if not await _wait(func() -> bool: return not get_tree().paused, 60, "the pause menu to close"):
		return false
	var tl1: int = fr.time_left_ticks
	if not await _wait(func() -> bool: return fr.time_left_ticks < tl1, 60, "the countdown after the pause menu"):
		return false
	_note("pause menu: tree paused, timer stopped; closed with ui_cancel, countdown runs again")
	paused_checked = true
	if Router.current != ex:
		return await settle()
	return true


## dawdle: stands still until the countdown expires; checks the warnings (600/300/60 in that order, once each) and that
## the collapse leads to the Sendeschluss screen with reason &"timer".
func _idle_until_collapse() -> bool:
	var ex: ExplorationScene = _ex()
	if _idle_from_ticks < 0:
		_idle_from_ticks = Game.state.floor_run.time_left_ticks     # a stray fight may interrupt the idling
	var tl0: int = _idle_from_ticks
	_note("idling at %s with %d s on the clock" % [str(ex.get_player_cell()), tl0 / Game.TICKS_PER_SEC])
	var n: int = 0
	while not finished and Router.current == ex:
		n += 1
		if n > IDLE_BUDGET:
			return fail("the floor timer did not expire within %d frames (%s)" % [IDLE_BUDGET, state_text()])
		await get_tree().process_frame
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy, 600, "screen after idling"):
		return false
	var cur: Node = Router.current
	if cur.scene_file_path != Router.SCENE_GAME_OVER or StringName(str(cur.get("reason"))) != &"timer":
		return fail("idling ended on %s (reason %s), expected Sendeschluss by timer" % [_screen_name(cur),
			str(cur.get("reason"))])
	var want: PackedInt32Array = []
	for w: int in Game.floor_def().timer_warnings:
		if w * Game.TICKS_PER_SEC < tl0:
			want.append(w)
	want.sort()
	want.reverse()
	if timer_warnings != want or timer_expired != 1:
		return fail("timer warnings %s (expected %s), expired %d×" % [str(timer_warnings), str(want), timer_expired])
	_note("floor collapsed after %d frames (warnings %s)" % [n, str(timer_warnings)])
	return true


## 06 package A: the controlled character is `want` in the state and in the exploration (player body, follower).
func check_hero(ex: ExplorationScene, want: String) -> bool:
	if Game.hero() != want:
		return fail("hero is %s in the state, expected %s" % [Game.hero(), want])
	if ex == null or ex.get_player().hero_id != want or ex.get_companion().member_id != Game.partner():
		return fail("exploration bodies do not follow the hero %s" % want)
	return true


## Casting (08 §6.3, K2): Kai's exploration figure (the player or the companion) wears DB.party_model("kai") — the
## persona's look, or today's Kai without a persona.
func check_look(ex: ExplorationScene) -> bool:
	var rig: Node = ex.get_player().rig if ex.get_player().hero_id == "kai" else ex.get_companion().rig
	if rig == null or rig.get("model") != DB.party_model("kai"):
		return fail("Kai's figure does not wear the persona look")
	return true


## Group fight: walk up to the symbol and hit it with a field strike (preemptive for IDLE/PATROL), else contact; the
## bot falls back to ExplorationScene.force_encounter(group) after ENGAGE_BUDGET frames. As Graf Mopsula (06 §1.3)
## it barks at the group first and walks into the dazed symbol (contact with a dazed group = PREEMPTIVE).
func _engage(ex: ExplorationScene, group_id: String) -> bool:
	var n: int = 0
	while not finished:
		if _interrupted(ex):
			UiUtil.release_move_actions()
			return true
		var a: Node3D = ex.get_enemy(group_id)
		if a == null:
			return true
		var p: Vector3 = ex.get_player_position()
		if Game.hero() == "mopsula":
			await _engage_bark(ex, a)
		elif _flat_dist(p, a.global_position) <= STRIKE_RANGE:
			UiUtil.release_move_actions()
			var body: CharacterBody3D = ex.get_player()
			_face(body, a.global_position)
			await get_tree().physics_frame
			if not _interrupted(ex) and ex.focused_interactable() == null:
				ex.perform_action()
			for _i in 12:
				await get_tree().physics_frame
				if _interrupted(ex):
					return true
		else:
			var sneak: bool = pace == "human" and _flat_dist(p, a.global_position) <= HUMAN_SNEAK_DIST
			_press(&"sneak", 1.0 if sneak else 0.0)
			_steer(ex, a.global_position)
			await get_tree().physics_frame
		n += 1
		if n > ENGAGE_BUDGET:
			UiUtil.release_move_actions()
			forced_encounters += 1
			_note("strike on %s did not start a battle → force_encounter" % group_id)
			ex.force_encounter(group_id)
			return true
	return false


## One engage step as Graf Mopsula: in range and ready → face the group and bark (perform_action, like the key);
## otherwise steer into it — a dazed (or any) symbol starts the battle on contact. In real time contact starts nothing
## (07 §2.2, E7): the dazed group is pulled like a person does it — the lead selected, key 1 (the bar's slot-1 skill,
## ExplorationScene.pull) — and the pull of a dazed group is the Erstschlag (PREEMPTIVE).
func _engage_bark(ex: ExplorationScene, a: Node3D) -> void:
	var body: CharacterBody3D = ex.get_player()
	var d: float = _flat_dist(ex.get_player_position(), a.global_position)
	if bool(a.call("is_dazed")) and ex.pull(str(a.call("group_id")), "skill", _rt_slot1_skill()):
		UiUtil.release_move_actions()
		await get_tree().physics_frame
		return
	var can_daze: bool = a.has_method("daze") and not bool(a.call("is_boss")) and not bool(a.call("is_dazed")) \
		and float(a.call("daze_cooldown")) <= 0.0
	if can_daze and d <= BARK_ENGAGE and bool(body.call("bark_ready")):
		UiUtil.release_move_actions()
		_face(body, a.global_position)
		await get_tree().physics_frame
		if not _interrupted(ex) and ex.focused_interactable() == null:
			ex.perform_action()
		await get_tree().physics_frame
		return
	var sneak: bool = pace == "human" and d <= HUMAN_SNEAK_DIST
	_press(&"sneak", 1.0 if sneak else 0.0)
	_steer(ex, a.global_position)
	await get_tree().physics_frame


## Walks to the stand point in front of `it`, faces it and presses `action` while it is focused (fallback: interact()
## directly). Then plays the follow-up (event dialog choice, stairs confirmation) and checks the effect.
func _use_interactable(ex: ExplorationScene, it: Node, obj: Dictionary) -> bool:
	var kind: String = str(obj["kind"])
	var cell: Vector2i = obj["cell"]
	var layout: FloorLayout = ex.get_layout()
	var center: Vector3 = layout.cell_to_world(cell)
	var rp: Vector3 = it.call("reach_point", center)
	var away: Vector3 = _flat_dir(rp, center)
	if away == Vector3.ZERO:
		away = _flat_forward((it as Node3D).global_transform.basis) * -1.0
	var extent: float = float(it.get("extent"))
	for attempt in 2:
		var stand: Vector3 = rp + away * (extent + (STAND_OFF if attempt == 0 else 0.55))
		if await walk_to(ex, stand, 0.3) == Walk.INTERRUPTED:
			return true
		var body: CharacterBody3D = ex.get_player()
		_face(body, rp)
		for _i in 3:
			await get_tree().physics_frame
		if _interrupted(ex):
			return true
		if ex.focused_interactable() == it:
			ex.perform_action()
			break
		if attempt == 1:
			direct_interactions += 1
			_note("%s not focused (focus: %s) → interact()" % [str(obj["id"]), _focus_name(ex)])
			it.call("interact")
	await get_tree().process_frame
	var fr: FloorRun = Game.state.floor_run
	match kind:
		"chest", "gate":
			var id: String = str(obj["id"])
			var opened: bool = fr.opened_chests.has(id) if kind == "chest" else fr.opened_gates.has(id)
			if str(obj["why"]) == TRY_LOCKED:
				tried[id] = true
				if opened:
					return fail("%s %s opened without its key" % [kind, id])
				if ex.is_modal() or not Game.is_timer_ticking():
					return fail("trying the locked %s %s left the exploration blocked" % [kind, id])
				_note("%s %s stays locked without its key (prompt: %s)" % [kind, id, str(it.call("prompt_text"))])
			elif not opened:
				return fail("%s %s did not open" % [kind, id])
			else:
				_note("%s %s opened" % [kind, id])
		"event":
			return await _event_dialog(ex, str(obj["id"]), str(obj["why"]))
		"note":
			if not Secrets.is_open(Game.state, str(obj["id"])):
				return fail("Regie-Notiz %s was not read" % str(obj["id"]))
			notes_read += 1
			_note("Regie-Notiz %s read (%d/%d)" % [str(obj["id"]), Game.secret_notes().x, Game.secret_notes().y])
		"stairs":
			var dlg: Node = ex.active_dialog()
			if dlg == null:
				return fail("stairs did not ask for confirmation")
			if season_def != "":                   # Staffeln (09, ST1-I): per floor, closed stairs, the summary
				return await _season_stairs(ex, dlg)
			if not await _hold_and_check_timer("stairs dialog"):
				return false
			if not tried.has("stairs"):
				# "Noch nicht" first: the dialog closes, Kai stays on the floor, the countdown goes on.
				tried["stairs"] = true
				dlg.call("choose", "stay")
				if not await _wait(func() -> bool: return not ex.is_modal(), 60, "stairs dialog closed"):
					return false
				var tl: int = fr.time_left_ticks
				if not await _wait(func() -> bool: return fr.time_left_ticks < tl, 60, "countdown after Noch nicht"):
					return false
				if Router.current != ex or Game.state.floor_run.index != 1:
					return fail("\"Noch nicht\" at the stairs left the floor")
				_note("stairs: \"Noch nicht\" keeps Kai on the floor")
				return true
			_note("stairs: descend")
			dlg.call("choose", "descend")
			_floor_done = true
		"safe":
			if not await _wait(func() -> bool: return Router.current is SafeRoomScene and not Router.busy, 300,
					"safe room %s" % str(obj["id"])):
				return false
	return true


## 06 §2.7: stand 1.3 m in front of the Kulissenwand on this side, face it and use the field ability (`action`:
## Kai's strike, the Count's bark) until it falls; fallback after 3 tries: ExplorationScene.knock_wall (counted).
func _knock_wall(ex: ExplorationScene, secret_id: String) -> bool:
	var w: Node3D = ex.get_wall(secret_id)
	if w == null or Secrets.is_open(Game.state, secret_id):
		return true
	var layout: FloorLayout = ex.get_layout()
	var center: Vector3 = layout.cell_to_world(ex.get_player_cell())
	var rp: Vector3 = w.call("reach_point", center)
	var stand: Vector3 = rp + _flat_dir(rp, center) * WALL_STAND
	if await walk_to(ex, stand, 0.3) == Walk.INTERRUPTED:
		return true
	var body: CharacterBody3D = ex.get_player()
	for attempt in 3:
		_face(body, rp)
		if not await _wait(func() -> bool: return bool(body.call("field_ready")) or _interrupted(ex), 240,
				"field ability ready"):
			return false
		if _interrupted(ex):
			return true
		await get_tree().physics_frame
		if ex.focused_interactable() == null:
			ex.perform_action()
		for _i in 40:
			await get_tree().physics_frame
			if Secrets.is_open(Game.state, secret_id):
				break
		if Secrets.is_open(Game.state, secret_id):
			walls_knocked += 1
			_note("Kulissenwand %s knocked over (%s)" % [secret_id, Game.hero()])
			return true
	wall_fallbacks += 1
	_note("Kulissenwand %s did not fall to the field ability → knock_wall()" % secret_id)
	if not ex.knock_wall(secret_id) or not Secrets.is_open(Game.state, secret_id):
		return fail("Kulissenwand %s does not open" % secret_id)
	return true


func _event_dialog(ex: ExplorationScene, event_id: String, choice: String) -> bool:
	var dlg: Node = ex.active_dialog()
	if dlg == null:
		return fail("event %s opened no dialog" % event_id)
	var fr: FloorRun = Game.state.floor_run
	var uses: int = int(fr.event_uses.get(event_id, 0))
	var done_before: bool = fr.completed_events.has(event_id)
	if not await _hold_and_check_timer("event dialog " + event_id):
		return false
	dlg.call("choose", choice)
	if not await _wait(func() -> bool: return Router.current != ex or not ex.is_modal() or ex.is_encounter_pending(),
			300, "event %s outcome" % event_id):
		return false
	var used: bool = int(fr.event_uses.get(event_id, 0)) > uses or (fr.completed_events.has(event_id)
		and not done_before)
	if FloorEvent.PASSIVE_CHOICES.has(choice):
		tried[event_id] = true
		if used:
			return fail("event %s: '%s' should only close the dialog" % [event_id, choice])
		_note("event %s: %s closes the dialog, event stays open" % [event_id, choice])
		return true
	if not used:
		return fail("event %s: choice '%s' changed nothing" % [event_id, choice])
	_note("event %s: %s%s" % [event_id, choice, " → battle" if ex.is_encounter_pending() else ""])
	return true


# ======================================================================================================================
# Walking
# ======================================================================================================================

## Walks door by door to `cell` (shortest path over open doors; living boss rooms only as the goal). Counts the cell
## changes and countdown ticks of finished travels and the shortcuts through opened Kulissenwände (06 package A).
func travel(cell: Vector2i) -> Walk:
	var ex: ExplorationScene = _ex()
	var layout: FloorLayout = ex.get_layout()
	var fr: FloorRun = Game.state.floor_run
	var path: Array[Vector2i] = find_path(layout, ex.get_player_cell(), cell, fr.opened_gates,
		_boss_blocks(layout, fr, cell))
	if path.is_empty():
		fail("no path from %s to %s" % [str(ex.get_player_cell()), str(cell)])
		return Walk.INTERRUPTED
	var t0: int = int(fr.stats.get("time_used_ticks", 0))
	var w: Walk = await _travel_path(ex, layout, fr, path)
	if w == Walk.ARRIVED and fr == Game.state.floor_run and fr.timer_started:
		travel_cells += path.size() - 1
		travel_ticks += int(fr.stats.get("time_used_ticks", 0)) - t0
		_note_shortcut(layout, fr, path, cell)
	return w


## 06 package A: does the shortest path run through an opened Kulissenwand? Saved cell changes = path length with
## every wall standing − this path.
func _note_shortcut(layout: FloorLayout, fr: FloorRun, path: Array[Vector2i], cell: Vector2i) -> void:
	var standing: PackedStringArray = []
	var any_wall: bool = false
	for k: String in fr.opened_gates:
		var g: Dictionary = layout.gate_by_key(k)
		if not g.is_empty() and Secrets.is_secret_requirement(str(g["requires"])):
			any_wall = true
		else:
			standing.append(k)
	if not any_wall or path.size() < 2:
		return
	var alt: Array[Vector2i] = find_path(layout, path[0], cell, standing, _boss_blocks(layout, fr, cell))
	if alt.size() > path.size():
		shortcut_trips += 1
		shortcut_cells += alt.size() - path.size()


## Seconds of countdown per cell change the bot measured on its travels (0 before the countdown ran).
func sec_per_cell() -> float:
	return float(travel_ticks) / Game.TICKS_PER_SEC / travel_cells if travel_cells > 0 else 0.0


func _travel_path(ex: ExplorationScene, layout: FloorLayout, fr: FloorRun, path: Array[Vector2i]) -> Walk:
	var p: Vector3 = ex.get_player_position()
	var here: Vector3 = hub(ex, path[0])
	if path.size() > 1 and _flat_dist(p, here) > 3.0:
		if await walk_to(ex, here, 1.0) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
	for i in range(1, path.size()):
		var a: Vector3 = layout.cell_to_world(path[i - 1])
		var b: Vector3 = hub(ex, path[i])
		if await walk_to(ex, (a + layout.cell_to_world(path[i])) * 0.5, 0.8) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
		if pace == "human":
			if not await human_wait(HUMAN_DOOR_SEC) or _interrupted(ex):
				return Walk.INTERRUPTED
		var last: bool = i == path.size() - 1
		var rc: RoomCell = layout.cell_at(path[i])
		var boss_room: bool = rc.kind == RoomCell.Kind.QUARTER_BOSS or rc.kind == RoomCell.Kind.FLOOR_BOSS
		if last and boss_room:
			return Walk.ARRIVED                    # the boss objective walks in itself
		var new_room: bool = not fr.visited.has(path[i])
		if await walk_to(ex, b, 1.2 if not last else 0.8) == Walk.INTERRUPTED:
			return Walk.INTERRUPTED
		if new_room and pace == "human":
			if not await human_wait(HUMAN_LOOK_SEC) or _interrupted(ex):
				return Walk.INTERRUPTED
	return Walk.ARRIVED


## --pace=human: lets `sec` seconds of countdown (+ the reading time of M.O.D. lines said meanwhile) pass while Kai
## stands still; ends early when the exploration is interrupted (stray, dialog) or the countdown does not run.
## No-op with --pace=fast. false = the run failed.
func human_wait(sec: float) -> bool:
	if season_def != "":                           # Staffeln (09, ST1-I): play time instead of the countdown
		return await _season_human_wait(sec)
	var ex: ExplorationScene = _ex()
	if pace != "human" or ex == null or Game.state.floor_run == null or not Game.state.floor_run.timer_started:
		return not finished
	var fr: FloorRun = Game.state.floor_run
	var want: int = roundi((sec + _read_backlog) * Game.TICKS_PER_SEC)
	_read_backlog = 0.0
	var start: int = fr.time_left_ticks
	var budget: int = roundi(float(want) / Game.TICKS_PER_SEC * 60.0 / TIME_SCALE) + 120
	UiUtil.release_move_actions()
	var n: int = 0
	while not finished and start - fr.time_left_ticks < want and n < budget:
		if _interrupted(ex) or not Game.is_timer_ticking():
			break
		n += 1
		await get_tree().process_frame
	human_wait_sec += float(start - fr.time_left_ticks) / Game.TICKS_PER_SEC
	return not finished


## Walkable middle of a room: its centre, in the stairs room 1.6 m in front of the fenced well (the well sits on the
## centre, EnvKit anchor &"stairs", entry edge at local z 0, well toward local −Z).
func hub(ex: ExplorationScene, cell: Vector2i) -> Vector3:
	var layout: FloorLayout = ex.get_layout()
	if cell == layout.stairs:
		var st: Node3D = ex.get_interactable("stairs") as Node3D
		if st != null:
			var h: Vector3 = st.global_transform * Vector3(0.0, 0.0, STAIRS_HUB)
			return Vector3(h.x, 0.0, h.z)
	return layout.cell_to_world(cell)


## BFS path from → to over the open doors (closed gates and `blocked` cells excluded); [] if unreachable.
static func find_path(layout: FloorLayout, from: Vector2i, to: Vector2i, opened: PackedStringArray,
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


## Steers Kai with the move actions until he is within `tolerance` of `target` (XZ). Stuck (no 0.25 m of progress for
## WALK_STUCK_SEC of game time) or over WALK_BUDGET frames → teleport onto the target (counted).
func walk_to(ex: ExplorationScene, target: Vector3, tolerance: float = 0.5) -> Walk:
	var best: float = INF
	var stuck: float = 0.0
	var n: int = 0
	while not finished:
		if _interrupted(ex):
			UiUtil.release_move_actions()
			return Walk.INTERRUPTED
		var p: Vector3 = ex.get_player_position()
		var d: float = _flat_dist(p, target)
		if d <= tolerance:
			UiUtil.release_move_actions()
			return Walk.ARRIVED
		if d < best - 0.25:
			best = d
			stuck = 0.0
		else:
			stuck += get_physics_process_delta_time()        # already scaled by Engine.time_scale
		n += 1
		if stuck > WALK_STUCK_SEC or n > WALK_BUDGET:
			UiUtil.release_move_actions()
			teleports += 1
			var body: CharacterBody3D = ex.get_player()
			_note("stuck at %s (%.1f m before %s, cell %s) → teleport [input %s vel %s vec %s yaw %.2f floor %s]" % [
				_v(p), d, _v(target), str(ex.get_player_cell()), str(body.get("input_enabled")), str(body.velocity),
				str(Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")),
				ex.get_camera_rig().yaw, str(body.is_on_floor())])
			body.call("teleport", Vector3(target.x, p.y + 0.05, target.z), body.rotation.y)
			await get_tree().physics_frame
			return Walk.INTERRUPTED if _interrupted(ex) else Walk.ARRIVED
		_steer(ex, target)
		await get_tree().physics_frame
	UiUtil.release_move_actions()
	return Walk.INTERRUPTED


## Move actions for the world direction to `target`, relative to the camera yaw like a stick (PlayerController moves
## camera relative: dir = Vector3(input.x, 0, input.y).rotated(UP, camera_yaw)).
func _steer(ex: ExplorationScene, target: Vector3) -> void:
	var dir: Vector3 = _flat_dir(ex.get_player_position(), target)
	var yaw: float = ex.get_camera_rig().yaw if ex.get_camera_rig() != null else 0.0
	var v: Vector2 = steer_input(dir, yaw)
	_press(&"move_right", v.x)
	_press(&"move_left", -v.x)
	_press(&"move_back", v.y)
	_press(&"move_forward", -v.y)


## Input vector (x = right, y = back) that makes the camera-relative movement go along `dir`; length 1.
static func steer_input(dir: Vector3, camera_yaw: float) -> Vector2:
	var local: Vector3 = dir.rotated(Vector3.UP, -camera_yaw)
	var v: Vector2 = Vector2(local.x, local.z)
	return v.normalized() if v.length_squared() > 0.000001 else Vector2.ZERO


static func _press(action: StringName, strength: float) -> void:
	if strength > 0.001:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _face(body: CharacterBody3D, target: Vector3) -> void:
	var d: Vector3 = _flat_dir(body.global_position, target)
	if d != Vector3.ZERO:
		body.call("teleport", body.global_position, _yaw_of(d))


func _interrupted(ex: ExplorationScene) -> bool:
	return finished or not is_instance_valid(ex) or Router.current != ex or Router.busy or not ex.is_inside_tree() \
		or ex.is_encounter_pending() or ex.is_modal() or _rt_running(ex)


# ======================================================================================================================
# Battles, game over
# ======================================================================================================================

## Back in the exploration after a battle: Game out of battle mode, the symbol gone, no member below 1 HP, the timer
## paused during the fight (only the fade-in may tick), the countdown started after the tutorial.
func _check_after_battle(res: BattleResult, tl0: int) -> bool:
	var fr: FloorRun = Game.state.floor_run
	if Game.in_battle:
		return fail("Game.in_battle still true after %s" % res.encounter_id)
	var ex: ExplorationScene = _ex()
	if ex != null and res.group_id != "" and res.outcome == BattleResult.Outcome.VICTORY \
			and ex.get_enemy(res.group_id) != null:
		return fail("the symbol of %s is still on the map after the victory" % res.group_id)
	for m: PartyMember in Game.state.party:
		if m.hp < 1:
			return fail("%s has %d HP after %s" % [m.id, m.hp, res.encounter_id])
	var used: int = tl0 - fr.time_left_ticks
	if used > TIMER_SLACK_TICKS:
		return fail("the floor timer ran %d ticks during the battle %s" % [used, res.encounter_id])
	var def: FloorDef = Game.floor_def()
	if def != null and res.encounter_id == def.timer_start_after and not fr.timer_started:
		return fail("the countdown did not start after %s" % res.encounter_id)
	if ex != null and not ex.is_modal() and fr.timer_started and not Game.is_timer_ticking():
		return fail("the floor timer does not tick in the exploration after %s" % res.encounter_id)
	return true


func _game_over(screen: Node) -> bool:
	deaths += 1
	_note("GAME OVER #%d (%s)" % [deaths, phase])
	if deaths > MAX_DEATHS:
		return fail("%d game overs" % deaths)
	if not await _wait(func() -> bool: return bool(screen.call("buttons_ready")), 300, "game over buttons"):
		return false
	if not bool(screen.call("can_load")):
		return fail("game over without a save to load")
	if _retry_boss and StringName(str(screen.get("reason"))) == &"defeat":
		grind_fights = GRIND_AFTER_DEFEAT
		_note("boss defeat → grind %d stray fights before the retry" % grind_fights)
	screen.call("load_last")
	if strategy != "thorough" and strategy != "typical":
		_note("strategy %s → thorough after the game over" % strategy)
		strategy = "thorough"
	if Game.state.floor_run.time_left_ticks < Save.GRACE_SECONDS * Game.TICKS_PER_SEC:
		return fail("loaded the last save with %d s on the clock (grace %d s)" % [int(Game.time_left()),
			Save.GRACE_SECONDS])
	return await _wait(func() -> bool: return (Router.current is ExplorationScene or Router.current is SafeRoomScene) \
		and not Router.busy, 600, "exploration after loading the last save")


# ======================================================================================================================
# Echtzeitkampf (07 §12.5, R5b): combats in the world, played by the RtBotPlayer
# ======================================================================================================================

## --rt-profile=perfect|sloppy → that bot profile; anything else → "typical".
static func rt_profile_from_args(args: PackedStringArray) -> String:
	for a: String in args:
		if a.begins_with("--rt-profile=") and RT_PROFILES.has(a.trim_prefix("--rt-profile=")):
			return a.trim_prefix("--rt-profile=")
	return "typical"


## The controlled hero's bar slot 1 in real time (party.json rt.bar, the base skill of slot 1 — a person's key 1).
static func _rt_slot1_skill() -> String:
	var def: Variant = DB.party_member(Game.hero()) if DB.has_id("party", Game.hero()) else null
	if def == null:
		return ""
	for e: Variant in ((def.get("rt") as Dictionary).get("bar", []) as Array):
		var b: Dictionary = e
		if int(b.get("slot", 0)) == 1 and not bool(b.get("variant", false)):
			return str(b.get("skill", ""))
	return ""


## Attempts at the optional floor boss (R5b: once more after a defeat).
func floor_boss_attempts_max() -> int:
	return FLOOR_BOSS_ATTEMPTS


## Gives the exploration's director the bot (once per scene instance); true while a combat is being started or runs,
## or one ended that is not recorded yet.
func _rt_arm(ex: ExplorationScene) -> bool:
	var dir: CombatDirector = ex.get_director()
	if dir == null:
		return false
	if not dir.bot_factory.is_valid():
		dir.bot_factory = _rt_make_bot
	return _rt_running(ex) or _rt_result != null


## A real-time combat is being started (boss intro) or runs in `ex` (the bot's walking loops stop for it).
func _rt_running(ex: ExplorationScene) -> bool:
	return Game.combat != null or (ex.get_director() != null and ex.get_director().is_busy())


## The person of the next combat: an RtBotPlayer with the run's profile on its own stream (07 §5.7), submitting through
## Game.combat_submit (recorded).
func _rt_make_bot(sim: RtSim) -> RefCounted:
	var script: GDScript = load(RT_BOT_PATH) as GDScript
	if script == null:
		return null
	var b: RefCounted = script.new(sim, rt_profile, SeedUtil.derive(_rt_seed, "rt_bot", rt_combats)) as RefCounted
	rt_combats += 1
	b.set("submitter", Game.combat_submit)
	return b


static func _rt_results_done(dir: CombatDirector) -> bool:
	var panel: Node = dir.get_node_or_null("CombatResults")
	return panel == null or not panel.has_method("is_done") or bool(panel.call("is_done"))


## A real-time combat from its start (intro included) to the exploration after its results panel — or the game over
## screen after a defeat. Recorded in `battles` (party_turns / turns as the result counts them, plus seconds).
func _rt_combat(ex: ExplorationScene) -> bool:
	var dir: CombatDirector = ex.get_director()
	var max_hp: int = 0
	for m: PartyMember in Game.state.party:
		max_hp += Progression.total_stats(m, DB.data).values[StatBlock.Stat.HP]
	var n: int = 0
	var hold: int = 0
	while not finished:
		if Game.combat != null and Game.combat.setup != null:
			phase = "combat %s" % Game.combat.setup.encounter_id
		# a lost combat leaves the exploration (Router.game_over): the scene and its director are freed meanwhile
		var gone: bool = Router.current != ex or not is_instance_valid(ex) or not is_instance_valid(dir)
		if _rt_result != null and not Router.busy and (gone or (not dir.is_busy() and _rt_results_done(dir)
				and not ex.is_encounter_pending())):
			break
		if not gone and _rt_result == null and not _rt_running(ex) and not ex.is_encounter_pending():
			return true                                # an encounter that started no combat (e.g. no set)
		if not gone and dir.is_paused_for_hint():
			hold += 1
			if hold >= HOLD_FRAMES:                    # read: close the card like the player (its key / any input)
				hold = 0
				hints_read += 1
				var hc: Node = dir.hud.get_node_or_null("HintCards") if dir.hud != null else null
				if hc != null and str(hc.call("current")) != "":
					hc.call("_close")
				else:
					dir.resume()
		n += 1
		if n > BATTLE_BUDGET:
			return fail("real-time combat did not end within %d frames (%s)" % [BATTLE_BUDGET, state_text()])
		await get_tree().process_frame
	if finished:
		return false
	var res: BattleResult = _rt_result
	_rt_result = null
	var rw: BattleRewards = dir.last_rewards if is_instance_valid(dir) else null
	var rec: Dictionary = {"enc": res.encounter_id, "group": res.group_id, "outcome": res.outcome_name(),
		"boss": res.is_boss, "adv": res.advantage, "party_turns": res.party_turns, "turns": res.turns,
		"hp_loss_pct": roundi(100.0 * res.damage_taken / maxf(1.0, float(max_hp))), "frames": n,
		"sec": snappedf(float(res.duration_ticks) / float(RtSim.TICKS_PER_SEC), 0.1), "level": _levels(),
		"followers": rw.followers if rw != null else 0,
		"hype_end": roundi(Game.state.show.hype) if Game.state.show != null else 0, "hype_start": _hype_start,
		"hype_peak": _hype_peak_battle, "gifts": _gifts_battle, "hype_reasons": _reasons_text()}
	battles.append(rec)
	if grind_fights > 0 and res.outcome == BattleResult.Outcome.VICTORY \
			and res.group_id.get_slice("_", 1).begins_with("s"):
		grind_fights -= 1
	_note("combat %d %s %s: %s, adv %d, %.1f s, HP loss %d%%, level %s, +%d followers, hype %d" % [battles.size(),
		res.encounter_id, res.group_id, res.outcome_name(), res.advantage, float(rec["sec"]), int(rec["hp_loss_pct"]),
		str(rec["level"]), int(rec["followers"]), int(rec["hype_end"])])
	if res.outcome == BattleResult.Outcome.DEFEAT:
		return true                                    # settle() takes the game over screen
	if season_def != "" and Game.state.season != null and Game.state.season.result != "":
		return true                                    # Staffeln (09, ST1-I): the finale won — settle takes the Abspann
	if not (Router.current is ExplorationScene):
		return fail("after the combat the screen is %s" % _screen_name(Router.current))
	if res.outcome == BattleResult.Outcome.VICTORY and res.group_id != "" \
			and not Game.state.floor_run.defeated_groups.has(res.group_id):
		return fail("victory over %s but the group is not marked defeated" % res.group_id)
	# the clock stands from the start to the end of the combat (07 §2.2); the "Applaus!" lower third does not hold it
	return _check_after_battle(res, _rt_tl0 + Game.state.floor_run.time_left_ticks - _rt_tl_end)


# ======================================================================================================================
# Safe room
# ======================================================================================================================

func _safe_room(scene: SafeRoomScene) -> bool:
	if season_def != "":                           # Staffeln (09, ST1-I): the season's visit
		return await _season_safe_room(scene)
	phase = "safe room %s" % scene.safe_room_id
	await get_tree().process_frame
	var sid: String = scene.safe_room_id
	var tl0: int = Game.state.floor_run.time_left_ticks
	_note("safe room %s (visit %d)" % [sid, Game.state.floor_run.safe_room_visits])
	if not _replay_check():
		return false
	# Mopsula scenes
	var guard: int = 0
	while scene.pending_scene != null and guard < 4:
		guard += 1
		var played: int = scene.played_scenes.size()
		var scene_id: String = scene.pending_scene.id
		scene.activate("mopsula")
		if not await _wait(func() -> bool: return scene.played_scenes.size() > played, SAFE_BUDGET,
				"Mopsula scene %s" % scene_id):
			return false
		_note("Mopsula scene %s" % scene_id)
	if hero == "mopsula" and hero_switches == 0:
		if not await _switch_hero_twice(scene):
			return false
	if not Game.state.pending_lootboxes.is_empty():
		if not await _open_lootboxes(scene):
			return false
	if not await _pick_pending_talents(scene):
		return false
	equip_best()
	if not await _shop(scene):
		return false
	equip_best()
	if not await _save(scene):
		return false
	var fr: FloorRun = Game.state.floor_run
	if tl0 - fr.time_left_ticks > TIMER_SLACK_TICKS:
		return fail("the floor timer ran %d ticks in the safe room" % (tl0 - fr.time_left_ticks))
	if not _roundtrip_done and fr.visited_safe_rooms.size() >= _layout_safe_rooms():
		_roundtrip_done = true
		return await _save_load_roundtrip()
	scene.activate("leave")
	if not await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, 300,
			"exploration after leaving %s" % sid):
		return false
	if _verify_scene:
		_verify_scene = false
		return check_scene_state(_ex())
	return true


## 06 package B: every open talent choice through the Talent-Show (the safe-room menu's path) — the bot always takes
## the first card of the offer (deterministic: the offer depends only on seed, member, level and ranks).
func _pick_pending_talents(scene: SafeRoomScene) -> bool:
	if not scene.talent_show_available():
		return true
	var layer: Node = scene.open_talent_show()
	var n: int = 0
	while is_instance_valid(layer) and not layer.is_queued_for_deletion():
		var mid: String = str(layer.get("member_id"))
		var offer: PackedStringArray = layer.get("offer")
		if mid == "" or offer.is_empty():
			layer.call("close")
			break
		var lv: int = Talents.pending_levels(Game.state.member(mid))[0]
		if not bool(await layer.call("pick", 0)):
			return fail("Talent-Show: picking %s for %s failed" % [offer[0], mid])
		talents_picked.append("%s@L%d:%s" % [mid, lv, offer[0]])
		_note("talent: %s (L%d) picks %s" % [mid, lv, offer[0]])
		n += 1
		if n > SAFE_BUDGET:
			return fail("the Talent-Show did not finish")
		await get_tree().process_frame
	if Talents.open_choices(Game.state, DB.data) > 0:
		return fail("%d talent choices still open after the Talent-Show" % Talents.open_choices(Game.state, DB.data))
	return true


## 06 §1.6: "Figur wechseln" twice (Mopsula → Kai → Mopsula) through the menu; each switch is a recorded hero command
## (the next replay check covers them) and leaves the run as it was.
func _switch_hero_twice(scene: SafeRoomScene) -> bool:
	for want: String in [Game.partner(), Game.hero()]:
		scene.activate("hero")
		await get_tree().process_frame
		if Game.hero() != want:
			return fail("Figur wechseln did not make %s the hero (is %s)" % [want, Game.hero()])
		hero_switches += 1
		_note("Figur wechseln → %s führt" % want)
		for _i in HOLD_FRAMES:
			await get_tree().process_frame
	return true


## 06 package A: every secret of the current floor (walls and notes) is open.
func _all_secrets_found() -> bool:
	for sec: Dictionary in Secrets.list(Game.floor_def()):
		if not Secrets.is_open(Game.state, str(sec.get("id", ""))):
			return false
	return true


## Number of safe rooms of the current floor (from the floor's layout).
func _layout_safe_rooms() -> int:
	var def: FloorDef = Game.floor_def()
	if def == null or Game.state.floor_run == null:
		return 0
	var layout: FloorLayout = DungeonGenerator.generate(def, Game.state.floor_run.seed)
	return layout.safe_rooms.size() if layout != null else 0


## Game.replay_log(run log) must reproduce the live StateHash with zero verifier errors (Brief §6b, 05 §11.4). A log
## that starts at a loaded save (save/load round trip, load after a game over) is replayed from its anchor (header
## start_state, Save.load_slot) — every segment of the run is verified, also the one after the last load.
func _replay_check() -> bool:
	if Game.run_log == null:
		return true
	var from_save: bool = bool(Game.run_log.header.get("from_save", false))
	var live: String = StateHash.of(Game.state)
	# the run clock keeps ticking in the safe room (idle ticks, Sponsor-Fenster 05 §6.13): replay up to the live tick
	var out: Dictionary = Game.replay_log(Game.run_log, Game.sim.tick() if Game.sim != null else -1)
	replay_checks += 1
	var errors: PackedStringArray = out.get("errors", PackedStringArray())
	if str(out.get("final_hash", "")) != live:
		return fail("replay of the run log (%d commands) does not reproduce the live state (mismatch at checkpoint %d)%s"
			% [Game.run_log.cmds().size(), int(out.get("mismatch_at", -1)), (": " + "; ".join(errors)) if not
			errors.is_empty() else ""])
	if not errors.is_empty():
		return fail("the verifier (Game.replay_log) reports %d error(s): %s" % [errors.size(), "; ".join(errors)])
	_note("replay check: %d commands%s reproduce the live StateHash" % [Game.run_log.cmds().size(),
		" since the load" if from_save else ""])
	return true


## The exploration scene shows what the state says (after loading a save): opened chests open, defeated groups gone,
## living groups and strays present, opened gates open, completed events without prompt.
func check_scene_state(ex: ExplorationScene) -> bool:
	if ex == null:
		return fail("no exploration to verify")
	var fr: FloorRun = Game.state.floor_run
	var layout: FloorLayout = ex.get_layout()
	for ch: ChestSpawn in layout.chests:
		var it: Node = ex.get_interactable(ch.id)
		if it != null and bool(it.get("is_open")) != fr.opened_chests.has(ch.id):
			return fail("chest %s: open %s on the map, %s in the state" % [ch.id, str(it.get("is_open")),
				str(fr.opened_chests.has(ch.id))])
	for e: EnemySpawn in layout.enemies:
		if fr.defeated_groups.has(e.id) and ex.get_enemy(e.id) != null:
			return fail("defeated group %s is back on the map" % e.id)
		if not e.is_boss and not fr.defeated_groups.has(e.id) and ex.get_enemy(e.id) == null:
			return fail("living group %s is missing on the map" % e.id)
	for gid: Variant in fr.strays.keys():
		if ex.get_enemy(str(gid)) == null:
			return fail("living stray %s is missing on the map" % str(gid))
	for g: Dictionary in layout.gates:
		var gate: Node = ex.get_interactable(str(g["key"]))
		if fr.opened_gates.has(str(g["key"])) and gate != null and not bool(gate.get("opened")):
			return fail("gate %s is closed on the map but open in the state" % str(g["key"]))
	for ev: EventSpawn in layout.events:
		var evi: Node = ex.get_interactable(ev.id)
		if evi != null and fr.completed_events.has(ev.id) and ev.type != "wheel" and str(evi.call("prompt_text")) != "":
			return fail("completed event %s still offers an interaction" % ev.id)
	for sec: Dictionary in Secrets.list(Game.floor_def()):          # 06 package A
		var sid: String = str(sec["id"])
		if Secrets.is_open(Game.state, sid) and (ex.get_wall(sid) != null or ex.get_interactable(sid) != null):
			return fail("secret %s is open in the state but still on the map" % sid)
		if not Secrets.is_open(Game.state, sid) and ex.get_interactable(sid) == null:
			return fail("secret %s is closed in the state but missing on the map" % sid)
	_note("scene matches the loaded state (chests, groups, gates, events)")
	return true


func _open_lootboxes(scene: SafeRoomScene) -> bool:
	var layer: Node = scene.open_lootboxes()
	var n: int = 0
	while is_instance_valid(layer) and not layer.is_queued_for_deletion():
		match StringName(str(layer.get("state"))):
			&"select":
				if (layer.call("pending") as Dictionary).is_empty():
					layer.call("finish")
				else:
					layer.call("tap")
			&"tease":
				layer.call("tap")
			&"reveal":
				layer.call("reveal_all")
			&"done":
				if (layer.call("pending") as Dictionary).is_empty():
					layer.call("finish")
				else:
					layer.call("next_box")
		n += 1
		if n > SAFE_BUDGET:
			return fail("lootbox opening did not finish (state %s)" % str(layer.get("state")))
		await get_tree().process_frame
	if not Game.state.pending_lootboxes.is_empty():
		return fail("%d lootboxes still pending after the opening" % Game.state.pending_lootboxes.size())
	_note("lootboxes opened (%d so far)" % boxes_opened)
	return true


## Vending (item button → quantity → confirm, the menu's own path): shopping_list() of this safe room.
func _shop(scene: SafeRoomScene) -> bool:
	var plan: Array[Array] = shopping_list(scene.safe_room_id)
	if plan.is_empty():
		return true
	var layer: Node = scene.open_vending()
	await get_tree().process_frame
	for entry: Array in plan:
		var item_id: String = str(entry[0])
		var b: Button = layer.find_child("Item_" + item_id, true, false) as Button
		if b == null:
			return fail("vending: no button for %s" % item_id)
		b.pressed.emit()
		layer.call("set_qty", int(entry[1]))
		if not bool(layer.call("confirm")):
			return fail("vending: buying %d× %s failed" % [int(entry[1]), item_id])
		_note("bought %d× %s" % [int(entry[1]), item_id])
	layer.call("close")
	return await _wait(func() -> bool: return not is_instance_valid(layer) or layer.is_queued_for_deletion(), 60,
		"vending closed")


## [[item_id, qty], …] the bot buys in `safe_room_id` with the current credits: affordable equipment upgrades in stock
## order, then bandages up to BANDAGES_WANTED.
func shopping_list(safe_room_id: String) -> Array[Array]:
	var out: Array[Array] = []
	var credits: int = Game.state.inventory.credits
	var stock: PackedStringArray = Shop.stock(Game.floor_def(), safe_room_id)
	for item_id: String in stock:
		var def: ItemDef = DB.item(item_id)
		if def.type == "consumable" or def.price <= 0 or def.price > credits:
			continue
		if _upgrade_for(def) != "":
			out.append([item_id, 1])
			credits -= def.price
	if stock.has("itm_bandage"):
		var price: int = Shop.price_of(DB.data, "itm_bandage")
		var want: int = mini(BANDAGES_WANTED - Game.state.inventory.count("itm_bandage"), credits / maxi(1, price))
		if want > 0:
			out.append(["itm_bandage", want])
	return out


## Member id that would equip `def` as an upgrade ("" = nobody).
func _upgrade_for(def: ItemDef) -> String:
	if not EQUIP_SLOTS.has(def.type):
		return ""
	for m: PartyMember in Game.state.party:
		if not def.equip_by.is_empty() and not def.equip_by.has(m.id):
			continue
		if item_score(def.id) > item_score(str(m.equipment.get(def.type, ""))):
			return m.id
	return ""


## Equips the best owned item per member and slot (Game.equip, the equipment menu's path). 06-C --liga: the Liga
## members take armor and accessory off instead (MarottenRules.LIGA_SLOTS).
func equip_best() -> void:
	var bare: PackedStringArray = liga_members()
	for m: PartyMember in Game.state.party:
		for slot: String in EQUIP_SLOTS:
			if bare.has(m.id) and MarottenRules.LIGA_SLOTS.has(slot):
				if str(m.equipment.get(slot, "")) != "" and Game.equip(m.id, slot, ""):
					_note("%s takes off %s (Liga %d)" % [m.id, slot, liga])
				continue
			var best: String = ""
			var best_score: int = item_score(str(m.equipment.get(slot, "")))
			for item_id: String in Game.state.inventory.ids_of_type(DB.data, slot):
				var def: ItemDef = DB.item(item_id) if DB.has_id("items", item_id) else null
				if def == null or def.type != slot or (not def.equip_by.is_empty() and not def.equip_by.has(m.id)):
					continue
				if item_score(item_id) > best_score:
					best_score = item_score(item_id)
					best = item_id
			if best != "" and Game.equip(m.id, slot, best):
				_note("%s equips %s" % [m.id, best])


## Sum of the item's stat bonuses (+1 so a stat-less accessory beats an empty slot); "" = -1.
static func item_score(item_id: String) -> int:
	if item_id == "" or not DB.has_id("items", item_id):
		return -1
	var s: int = 1
	for v: Variant in DB.item(item_id).stats.values():
		s += int(v)
	return s


func _save(scene: SafeRoomScene) -> bool:
	var before: int = _saved_events
	var layer: Node = scene.open_save()
	if layer == null:
		return fail("safe room offers no save")
	await get_tree().process_frame
	var sel: Node = null
	for c: Node in layer.get_children():
		if c.has_method("choose"):
			sel = c
	if sel == null:
		return fail("save: no slot selection")
	sel.call("choose", SAVE_SLOT)
	await get_tree().process_frame
	if _saved_events == before:
		var confirm: Node = _find_method(sel, "answer")
		if confirm == null:
			return fail("save: slot %d neither saved nor asked to overwrite" % SAVE_SLOT)
		confirm.call("answer", true)
	if not await _wait(func() -> bool: return _saved_events > before, 120, "game_saved"):
		return false
	saves += 1
	roundtrip_hash = StateHash.of(Game.state)
	_note("saved slot %d in %s" % [SAVE_SLOT, scene.safe_room_id])
	return true


## "Zum Titel" → "Fortsetzen" (Save.load_slot + routing) right after the save: the loaded state must hash like the
## saved one, and the exploration must bring Kai back into that safe room (check_scene_state after leaving it).
func _save_load_roundtrip() -> bool:
	phase = "save/load roundtrip"
	var want: Dictionary = StateHash.hash_input(Game.state)
	Router.goto(Router.SCENE_TITLE)
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, 300, "title"):
		return false
	var title: TitleScreen = Router.current as TitleScreen
	if not title.menu_ids().has("continue"):
		return fail("the title offers no \"Fortsetzen\" after saving")
	title.activate("continue")
	if StateHash.of(Game.state) != roundtrip_hash:
		return fail("loaded state differs from the saved one: %s" % dict_diff(want, StateHash.hash_input(Game.state)))
	_note("save → title → Fortsetzen: StateHash identical")
	_verify_scene = true
	return await _wait(func() -> bool: return Router.current is SafeRoomScene and not Router.busy, 600,
		"safe room after loading")


static func _find_method(root: Node, method: String) -> Node:
	for c: Node in root.get_children():
		if c.has_method(method):
			return c
		var deeper: Node = _find_method(c, method)
		if deeper != null:
			return deeper
	return null


## "key: a != b" for the differing (nested) keys of two dictionaries.
static func dict_diff(a: Dictionary, b: Dictionary, prefix: String = "") -> String:
	var parts: PackedStringArray = []
	var keys: Array = a.keys()
	for k: Variant in b.keys():
		if not keys.has(k):
			keys.append(k)
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return str(x) < str(y))
	for k: Variant in keys:
		var va: Variant = a.get(k, null)
		var vb: Variant = b.get(k, null)
		if va is Dictionary and vb is Dictionary:
			var sub: String = dict_diff(va, vb, prefix + str(k) + ".")
			if sub != "":
				parts.append(sub)
		elif JSON.stringify(va) != JSON.stringify(vb):
			parts.append("%s%s: %s != %s" % [prefix, str(k), JSON.stringify(va).left(80), JSON.stringify(vb).left(80)])
	return "; ".join(parts)


# ======================================================================================================================
# Stairs → summary → credits → title
# ======================================================================================================================

func _after_stairs() -> bool:
	phase = "floor summary"
	if not await _wait(func() -> bool: return Router.current is FloorSummary and not Router.busy, 300,
			"floor summary"):
		return false
	var fs: FloorSummary = Router.current as FloorSummary
	summary = fs.summary.duplicate()
	_note("floor summary %s" % JSON.stringify(summary))
	var liga_rec: Variant = Game.state.show.marotten.get("liga", {})
	liga_bonus_followers = int((liga_rec as Dictionary).get("followers", 0)) if liga_rec is Dictionary else 0
	if strategy == "thorough" and not _all_secrets_found():
		return fail("thorough run left E1 secrets behind: %s of %s" % [str(Secrets.opened(Game.state)),
			str(Secrets.list(Game.floor_def()).map(func(x: Dictionary) -> String: return str(x["id"])))])
	if int(summary.get("regie_notes_total", 0)) != Game.secret_notes().y \
			or int(summary.get("regie_notes", -1)) != Game.secret_notes().x:
		return fail("floor summary shows Regie-Notizen %s/%s, state %s" % [str(summary.get("regie_notes", "-")),
			str(summary.get("regie_notes_total", "-")), str(Game.secret_notes())])
	# the last segment (last safe room visit incl. its talent picks, floor boss, descent) is replay-verified as well
	if not _replay_check():
		return false
	fs.continue_pressed()
	phase = "credits"
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy \
			and Router.current.scene_file_path == Router.SCENE_CREDITS, 300, "credits"):
		return false
	if Game.state.floor_run == null or Game.state.floor_run.index != 2:
		return fail("after the summary the run is not on floor 2 (autosave stand)")
	var sum2: Dictionary = Save.slot_summary(SAVE_SLOT)
	if int(sum2.get("floor_index", 0)) != 2 or str(sum2.get("location", "")) != "start":
		return fail("autosave of slot %d is not on floor 2: %s" % [SAVE_SLOT, JSON.stringify(sum2)])
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, CREDITS_BUDGET,
			"title after the credits"):
		return false
	phase = "continue into the credits"
	var title: TitleScreen = Router.current as TitleScreen
	if not title.menu_ids().has("continue"):
		return fail("no \"Fortsetzen\" after the autosave")
	title.activate("continue")
	if not await _wait(func() -> bool: return Router.current != null and not Router.busy \
			and Router.current.scene_file_path == Router.SCENE_CREDITS, 300, "credits after Fortsetzen (floor 2)"):
		return false
	Router.current.call("finish")
	return await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, 300, "title")


# ======================================================================================================================
# Party upkeep
# ======================================================================================================================

## Field heal items on members below HEAL_ITEM_BELOW (Game.use_item, the inventory menu's path); Krawumm for MP.
func _use_heal_items() -> void:
	for m: PartyMember in Game.state.party:
		var sb: StatBlock = Progression.total_stats(m, DB.data)
		var max_hp: int = sb.values[StatBlock.Stat.HP]
		for item_id: String in HEAL_ITEMS:
			while m.hp < max_hp * HEAL_ITEM_BELOW and Game.state.inventory.has(item_id):
				if not Game.use_item(item_id, m.id):
					break
				_note("used %s on %s" % [item_id, m.id])
		var max_mp: int = sb.values[StatBlock.Stat.MP]
		if m.mp < max_mp * 0.25 and Game.state.inventory.has("itm_energy_krawumm"):
			if Game.use_item("itm_energy_krawumm", m.id):
				_note("used itm_energy_krawumm on %s" % m.id)


## Party HP or MP ratio (sum / sum of maxima).
static func party_ratio(what: String) -> float:
	var cur: int = 0
	var mx: int = 0
	for m: PartyMember in Game.state.party:
		var sb: StatBlock = Progression.total_stats(m, DB.data)
		if what == "mp":
			cur += m.mp
			mx += sb.values[StatBlock.Stat.MP]
		else:
			cur += m.hp
			mx += sb.values[StatBlock.Stat.HP]
	return float(cur) / float(maxi(1, mx))


## Equipment per member, battle items and party HP/MP ratio (what the party brings into a boss fight).
func _kit() -> Dictionary:
	var eq: Dictionary = {}
	for m: PartyMember in Game.state.party:
		eq[m.id] = m.equipment.duplicate()
	return {"equipment": eq, "items": Game.state.inventory.battle_items(DB.data),
		"hp": snappedf(party_ratio("hp"), 0.01), "mp": snappedf(party_ratio("mp"), 0.01)}


## Total EXP per member (EXP of the levels reached + current EXP, GDD §4.3 table).
func _exps() -> Array[int]:
	var out: Array[int] = []
	for m: PartyMember in Game.state.party:
		var total: int = m.exp
		for l in range(1, m.level):
			total += Progression.exp_to_next(l)
		out.append(total)
	return out


func _levels() -> Array[int]:
	var out: Array[int] = []
	for m: PartyMember in Game.state.party:
		out.append(m.level)
	return out


# ======================================================================================================================
# Report
# ======================================================================================================================

## M.O.D. beats of GDD §1.4 that every run must have heard: floor_start once and only once the countdown runs (B2),
## first_fight, safe_room_enter, Mopsula scene 1 (B3), the Hausmeister intro (B5), stairs_found (B6), floor_end (B8).
func check_story_beats() -> bool:
	phase = "story beats"
	var starts: int = 0
	for t: String in mod_tags:
		if t.begins_with("floor_start@"):
			starts += 1
			if t != "floor_start@countdown":
				return fail("floor_start was said before the countdown started (%s)" % t)
	if starts != 1:
		return fail("floor_start was said %d× (expected once, when the countdown starts)" % starts)
	for tag: String in REQUIRED_BEATS:
		var found: bool = false
		for t: String in mod_tags:
			found = found or t.get_slice("@", 0) == tag
		if not found:
			return fail("M.O.D. beat '%s' never played" % tag)
	# 06-C: M.O.D. announces her preference of the floor once the countdown runs (06 §4.2)
	var announced: bool = false
	for t: String in mod_tags:
		if t.begins_with("marotte_announce:"):
			if not t.ends_with("@countdown"):
				return fail("a preference was announced before the countdown (%s)" % t)
			announced = true
	var show: ShowState = Game.state.show if Game.state != null else null
	if not announced and show != null and not (show.marotten.get("active", []) as Array).is_empty():
		return fail("M.O.D. never announced her preference of the floor")
	if liga > 0 and (show == null or int(show.stats.get("liga_battles", 0)) == 0):
		return fail("--liga=%d: no battle was won in the Liga" % liga)
	if persona != "none":                       # Casting (08 §4.3): persona lines, never in a battle
		var lines: int = 0
		for t: String in mod_tags:
			if t.begins_with("persona_"):
				lines += 1
		if lines == 0:
			return fail("no persona line was said (--persona=%s)" % persona)
		if persona_in_battle > 0:
			return fail("%d persona line(s) during a battle (08 §4.3 R6)" % persona_in_battle)
		_note("persona lines: %d, none in a battle" % lines)
	return true


## The GDD §13 numbers of this run.
func stats() -> Dictionary:
	var regular: Array[Dictionary] = []
	var strays: int = 0
	var groups: PackedStringArray = []
	for b: Dictionary in battles:
		var gid: String = str(b["group"])
		if gid.get_slice("_", 1).begins_with("s"):
			strays += 1
		elif gid != "" and not bool(b["boss"]) and str(b["outcome"]) == "victory" and not groups.has(gid):
			groups.append(gid)
		if not bool(b["boss"]) and gid != "f1_g0":
			regular.append(b)
	var pt: Array[int] = []
	var tt: Array[int] = []
	var hp: Array[int] = []
	for b: Dictionary in regular:
		pt.append(int(b["party_turns"]))
		tt.append(int(b["turns"]))
		hp.append(int(b["hp_loss_pct"]))
	var boss_turns: Dictionary = {}
	var boss_outcomes: Dictionary = {}
	var hype_start: Array[int] = []
	var hype_end: Array[int] = []
	var hype_peak: Array[int] = []
	var gifts_regular: int = 0
	var gifts_boss: int = 0
	for b: Dictionary in battles:
		if bool(b["boss"]):
			boss_turns[str(b["enc"])] = int(b["party_turns"])
			var outs: Array = boss_outcomes.get(str(b["enc"]), [])
			outs.append(str(b["outcome"]))
			boss_outcomes[str(b["enc"])] = outs
			gifts_boss += int(b.get("gifts", 0))
		elif str(b["group"]) != "f1_g0":
			hype_start.append(int(b.get("hype_start", 0)))
			hype_end.append(int(b.get("hype_end", 0)))
			hype_peak.append(int(b.get("hype_peak", 0)))
			gifts_regular += int(b.get("gifts", 0))
	var show: ShowState = Game.state.show if Game.state != null else null
	var ach_followers: int = 0
	if show != null:
		for id: String in show.achievements:
			if DB.has_id("achievements", id):
				var def: AchievementDef = DB.data.achievement(id)
				ach_followers += def.followers if def.followers >= 0 else int(Show.ACH_FOLLOWERS.get(def.box, 0))
	return {
		"pace": pace, "strategy": strategy, "human_wait_sec": roundi(human_wait_sec),
		"hero": hero, "barks": barks, "dazed": dazed, "hero_switches": hero_switches,
		"rt_profile": rt_profile, "hints_read": hints_read,
		"preemptives": int(show.stats.get("preemptives", 0)) if show != null else 0,         # sneaked up first
		"bark_openers": int(show.stats.get("bark_openers", 0)) if show != null else 0,       # opened from a bark
		"secrets": Secrets.opened(Game.state) if Game.state != null else PackedStringArray(),
		"walls_knocked": walls_knocked, "notes_read": notes_read, "wall_fallbacks": wall_fallbacks,
		"shortcut_trips": shortcut_trips, "shortcut_cells": shortcut_cells,
		"sec_per_cell": snappedf(sec_per_cell(), 0.01), "shortcut_gain_sec": roundi(shortcut_cells * sec_per_cell()),
		# gifts of the surviving timeline (state stat, round 4) vs every gift signal incl. segments lost to a Game Over
		"sponsor_gifts": int(show.stats.get("sponsor_gifts", 0)) if show != null else gifts.size(),
		"sponsor_gifts_events": gifts.size(), "gifts_regular": gifts_regular, "gifts_boss": gifts_boss, "gift_ids": gifts,
		"boss_outcomes": boss_outcomes, "boss_exp": boss_exp, "boss_kit": boss_kit,
		"credits_before_floor_boss": credits_before_floor_boss,
		"hype_start_median": median(hype_start), "hype_end_median": median(hype_end),
		"hype_peak_median": median(hype_peak), "followers_achievements": ach_followers,
		"achievement_ids": show.achievements if show != null else PackedStringArray(),
		"boxes_by_id": boxes_by_id, "credits_lootbox": credits_lootbox,
		"milestones": show.milestones if show != null else PackedStringArray(),
		"floor_time_used_sec": int(summary.get("time_used_sec", 0)),
		"floor_time_left_sec": int(summary.get("time_left_sec", 0)),
		"battles": battles.size(), "regular_battles": regular.size(), "strays": strays,
		"groups_defeated": groups.size(), "deaths": deaths,
		"party_turns_median": median(pt), "turns_median": median(tt), "hp_loss_pct_median": median(hp),
		"boss_levels": boss_levels, "boss_party_turns": boss_turns, "level_end": _levels(),
		"credits_earned": credits_earned, "credits_by_source": credits_by_source, "credits_spent": credits_spent,
		"strays_spawned": strays_spawned, "followers_battles": _sum_key("followers"),
		# boxes of the surviving timeline (06 integration round 4): opened + still pending in the final state — a box
		# earned again after a Game-Over reload counts once; boxes_earned_events counts every lootbox_earned signal
		"boxes_earned": (int(show.stats.get("lootboxes_opened", 0)) + Game.state.pending_lootboxes.size())
			if show != null and Game.state != null else boxes_earned,
		"boxes_earned_events": boxes_earned, "boxes_opened": boxes_opened,
		"achievements": show.achievements.size() if show != null else 0,
		"followers": show.followers if show != null else 0,
		"viewers_peak": int(summary.get("viewers_peak", 0)), "kills": int(summary.get("kills", 0)),
		"purchases": purchases, "saves": saves, "teleports": teleports, "direct_interactions": direct_interactions,
		"forced_encounters": forced_encounters, "replay_checks": replay_checks, "frames": frames,
		"mod_tags": mod_tags, "talents_picked": talents_picked,
		# 06-C: M.O.D.'s preferences of the floor and the Unterhosen-Liga (06 §4.10)
		"liga": liga, "marotten": show.marotten.duplicate(true) if show != null else {},
		"bets_won": int(show.stats.get("bets_won", 0)) if show != null else 0,
		"liga_battles": int(show.stats.get("liga_battles", 0)) if show != null else 0,
		"liga_bonus_followers": liga_bonus_followers,
	}


## Battles against stray groups so far.
func strays_fought() -> int:
	var n: int = 0
	for b: Dictionary in battles:
		if str(b["group"]).get_slice("_", 1).begins_with("s"):
			n += 1
	return n


func _sum_key(key: String) -> int:
	var t: int = 0
	for b: Dictionary in battles:
		t += int(b.get(key, 0))
	return t


static func median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var s: Array[int] = values.duplicate()
	s.sort()
	var n: int = s.size()
	return float(s[n / 2]) if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) / 2.0


func ok_line() -> String:
	var lv: Array[int] = _levels() if Game.state != null else [0, 0]
	return "FULLRUN: OK floor_time=%d battles=%d level=%s deaths=%d frames=%d" % [int(summary.get("time_used_sec", 0)),
		battles.size(), "/".join(PackedStringArray(lv.map(func(x: int) -> String: return str(x)))), deaths, frames]


func _finish_ok() -> void:
	if finished:
		return
	finished = true
	result_code = 0
	result_line = ok_line()
	UiUtil.release_move_actions()
	if not dry_run:
		print("FULLRUN: stats ", JSON.stringify(stats()))
		print(result_line)
		clear_saves()
		get_tree().quit(0)


## Ends the run with the failure line (check.sh / fullrun.sh ERR_RE); always returns false.
func fail(reason: String) -> bool:
	if finished:
		return false
	finished = true
	UiUtil.release_move_actions()
	result_code = 1
	result_line = "Assertion failed: FULLRUN failed in %s: %s" % [phase, reason]
	if not dry_run:
		for l: String in _log.slice(maxi(0, _log.size() - 8)):
			print("FULLRUN: (last) ", l)
		printerr(result_line)
		get_tree().quit(1)
	return false


func state_text() -> String:
	var cur: Node = Router.current
	var s: String = "screen=%s busy=%s" % [_screen_name(cur), str(Router.busy)]
	if cur is ExplorationScene:
		var ex: ExplorationScene = cur as ExplorationScene
		s += " cell=%s modal=%s pending=%s" % [str(ex.get_player_cell()), str(ex.is_modal()),
			str(ex.is_encounter_pending())]
	if Game.state != null and Game.state.floor_run != null:
		s += " time_left=%d" % int(Game.time_left())
	if cur is ExplorationScene and (cur as ExplorationScene).get_director() != null:
		var dir: CombatDirector = (cur as ExplorationScene).get_director()
		var hc: Node = dir.hud.get_node_or_null("HintCards") if dir.hud != null and is_instance_valid(dir.hud) else null
		s += " director=%d ticks=%d combat=%s paused=%s hint=%s card=%s" % [int(dir.phase), dir.ticks_run, ("ct %d%s"
			% [Game.combat.tick(), " finished" if Game.combat.is_finished() else ""]) if Game.combat != null else
			"none", str(get_tree().paused), str(dir.is_paused_for_hint()), str(hc.call("current")) if hc != null
			else "-"]
		var md: Node = (load("res://scenes/ui/mod_dialog.gd") as GDScript).get("current") as Node
		if md != null:
			s += " dialog=%s queue=%d hold=%.2f intro=%s" % [str((md.get("_cur") as Dictionary).get("tag", "")),
				(md.get("_queue") as Array).size(), float(md.get("_hold")), dir.intro_line.left(20)]
	return s


func _note(text: String) -> void:
	var line: String = "[%d] %s" % [frames, text]
	_log.append(line)
	if not dry_run:
		print("FULLRUN: ", line)


func _wait(cond: Callable, budget: int, what: String) -> bool:
	var n: int = 0
	while not finished and not bool(cond.call()):
		n += 1
		if n > budget:
			return fail("waited %d frames for %s (%s)" % [budget, what, state_text()])
		await get_tree().process_frame
	return not finished


func _reasons_text() -> String:
	var keys: Array = hype_reasons.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: Variant in keys:
		parts.append("%s %+d" % [str(k), roundi(float(hype_reasons[k]))])
	return ", ".join(parts)


static func _v(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


# --- XZ geometry (the bot's own: M3's encounter_rules.gd is private to the exploration module, 02_TECH §0.3) ----------

static func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Normalized XZ direction from `from` to `to`; Vector3.ZERO if they coincide.
static func _flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length_squared() > 0.000001 else Vector3.ZERO


## Forward (−Z of the basis) flattened to XZ.
static func _flat_forward(basis: Basis) -> Vector3:
	var f: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z)
	return f.normalized() if f.length_squared() > 0.000001 else Vector3.FORWARD


## rotation.y that makes −Z point along `dir`.
static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _ex() -> ExplorationScene:
	return Router.current as ExplorationScene


static func _screen_name(n: Node) -> String:
	if n == null:
		return "null"
	return n.scene_file_path.get_file() if n.scene_file_path != "" else str(n.name)


func _focus_name(ex: ExplorationScene) -> String:
	var f: Node = ex.focused_interactable()
	return str(f.get("interact_id")) if f != null else "none"


func _on_battle_started(encounter_id: String, is_boss: bool) -> void:
	if Game.replaying:
		return
	hype_reasons = {}
	_hype_start = roundi(Game.state.show.hype) if Game.state != null and Game.state.show != null else 0
	_hype_peak_battle = _hype_start
	_gifts_battle = 0
	_retry_boss = false
	if is_boss and Game.state != null:
		boss_levels[encounter_id] = _levels()
		boss_exp[encounter_id] = _exps()
		if not boss_kit.has(encounter_id):
			boss_kit[encounter_id] = _kit()
		var floor_boss: bool = Game.state.floor_run != null and DB.floor_def(Game.state.floor_run.index) != null \
			and DB.floor_def(Game.state.floor_run.index).floor_boss == encounter_id
		if floor_boss:
			floor_boss_attempts += 1
			if credits_before_floor_boss < 0:
				credits_before_floor_boss = credits_earned
		_retry_boss = not floor_boss or floor_boss_attempts < floor_boss_attempts_max()


func _on_credits_changed(_credits: int, delta: int) -> void:
	if Game.replaying:
		return
	if delta > 0:
		credits_earned += delta
		var src: String = "battle" if Game.combat != null else ("safe_room" if Router.current is SafeRoomScene \
			else "explore")
		credits_by_source[src] = int(credits_by_source.get(src, 0)) + delta
	elif delta < 0:
		credits_spent -= delta


# ======================================================================================================================
# Staffeln (09, ST1-I): the full-run bot on the floors of a season
# ======================================================================================================================
# tools/fullrun.sh --season=<ssn id> passes --fullrun-season=<id> with --tempo, --mode, --speed, --sessions, --floors:
# boot leaves the start to the bot (boot's own --season starts at the wall clock), and the bot starts the season through
# the facade of the title's start (FullRunSeasonUi.start → Game.start_season) at a fixed moment — the first session of
# the profile (calendar) or SEASON_START_UTC (Am Stück), UTC offset 0, the run seed: a season run is reproducible like a
# campaign run. It plays every floor of the format: floor 1 (handbuilt, the dress rehearsal) with the campaign's
# candidates, the generator-v2 floors with season_planner.gd (09 §3.6: the Revier-Boss, its key, the key gate, the
# stairs; a programme room once the daily programme opened its door; a safe room per quarter), the Recall on floor 3,
# the class abilities on the bar, the rows of the talent tree, the stairs (Etagen-Bilanz → next floor; closed in the
# calendar: the bot waits), the finale on the last floor. Am Stück it plays straight through (every floor's countdown);
# in the calendar it plays the sessions of a profile (tests/tools/season_profiles.gd): the season clock follows the game
# time (× --speed; one "clock" per SEASON_CLOCK_STEP seconds, a combat's time after it), a session ends with the logout
# (a safe room within SEASON_LOGOUT_DIST rooms, else the corridor), the absence until the next session is the login's
# ("Fortsetzen" → "away" → "Während Sie schliefen …"). Strategies thorough, typical, rush and auto (--strategy=auto,
# seasons only: the play profiles' person — the Pflichtweg, then the rest while the floor has time). Combat strategy for
# the bands (season_planner.gd): nearest goal first, red groups (5+ levels above the hero) after the Revier-Boss, more
# than a level below a boss the other groups first, heal before bosses, the best gear, the class abilities on the bar,
# the first card of every talent row, Mit Netz a boss again after the medics (4 per floor Am Stück, 2 per session).
# Measured per floor (season_floor_log): play / explore / combat seconds, levels at arrival and departure against the
# band, bosses (outcome, seconds, levels), defeats, rescues, credits, how the floor was left — "FULLRUN: season {json}"
# and "FULLRUN: OK season=<result> …". Without --fullrun-season nothing here runs: the campaign run stays bit-identical.

const SeasonUi := preload("res://scenes/boot/fullrun_season_ui.gd")
const SEASON_PROFILES_PATH: String = "res://tests/tools/season_profiles.gd"
const SEASON_PLANNER_PATH: String = "res://tests/tools/season_planner.gd"
const SEASON_DAY0_UTC: int = 1791921600        # day 0 of the bot's seasons: an air time 20:00 UTC (season_core DAY0)
const SEASON_START_UTC: int = SEASON_DAY0_UTC - 5400   # Am Stück: started 90 min before the first air time
const SEASON_AIR: String = "20:00"
const SEASON_WATCHDOG_FRAMES: int = 2400000    # 55 h of game time (calendar runs log out and in for 24 days)
const SEASON_STRATEGIES: PackedStringArray = ["thorough", "typical", "rush", "auto"]
const SEASON_SESSIONS: PackedStringArray = ["typical", "20min", "weekend", "away2w", "none"]
const SEASON_LOGOUT_DIST: int = 4              # session end: a safe room at most this many rooms away → sleep there
const SEASON_CLOCK_STEP: float = 60.0          # 09 §9.1: one "clock" per 60 s (here: game time)
const SEASON_SETTLE_BUDGET: int = 3000
const SEASON_IDLE_FRAMES: int = 600            # one waiting step (Am Stück: until the countdown or a change)
const SEASON_AFTER_END_SEC: int = 3600         # the last login comes this long after the last collapse
const SEASON_NO_CELL: Vector2i = Vector2i(-99, -99)

## --fullrun-season=<ssn id> ("" = the campaign run) and its settings: tempo (binge | calendar), mode (net | no_net),
## speed (calendar: season seconds per second of game time), sessions (calendar: a profile of season_profiles.gd or
## "none" = play on without logouts), floors (0 = the whole format; n = stop after the Etagen-Bilanz of floor n),
## strategy ("auto" — the campaign's --strategy does not know it).
var season_def: String = ""
var season_tempo: String = "binge"
var season_mode: String = "net"
var season_speed: int = 1
var season_sessions: String = "typical"
var season_floors: int = 0
## One record per floor stay (_season_open_floor / _season_close_floor), the logouts and the bot's season result.
var season_floor_log: Array[Dictionary] = []
var season_logouts: Array[Dictionary] = []
var season_stop: String = ""                   # why the run ended: the season's result, "floors", "out"

var _season_ui: RefCounted = null
var _season_planner: GDScript = null           # tests/tools/season_planner.gd (loaded at run time, like the RtBot)
var _season_rec: Dictionary = {}
var _season_plan: Array[Dictionary] = []       # calendar: the sessions of the profile
var _season_session: int = 0
var _season_session_play: float = 0.0          # game seconds of the running session
var _season_session_wall: int = 0              # the person's clock (unix seconds) at the start of the session
var _season_play: float = 0.0                  # game seconds of the whole run in the season views
var _season_in_session: bool = false
var _season_clock_acc: float = 0.0
var _season_fight_acc: float = 0.0
var _season_battles_seen: int = 0
var _season_descended: bool = false
var _season_logout_due: bool = false
var _season_shut: bool = false                 # the stairs of this floor were closed ("Kulissen im Aufbau")
var _season_done: bool = false
var _season_clocks: int = 0                    # clock commands the bot recorded
var _season_talents: PackedStringArray = []


## The season settings of the user args ({} without --fullrun-season; malformed values keep the defaults).
static func season_from_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if not a.begins_with("--") or kv.size() != 2 or kv[1] == "":
			continue
		match kv[0]:
			"fullrun-season":
				out["def"] = kv[1]
			"tempo":
				if SeasonState.TEMPOS.has(kv[1]):
					out["tempo"] = kv[1]
			"mode":
				if SeasonState.MODES.has(kv[1]):
					out["mode"] = kv[1]
			"sessions":
				if SEASON_SESSIONS.has(kv[1]):
					out["sessions"] = kv[1]
			"speed", "floors":
				if kv[1].is_valid_int():
					out[kv[0]] = kv[1].to_int()
			"strategy":
				if kv[1] == "auto":
					out["strategy"] = kv[1]
	return out if out.has("def") else {}


func _season_setup(o: Dictionary) -> void:
	if o.is_empty():
		return
	season_def = str(o["def"])
	season_tempo = str(o.get("tempo", "binge"))
	season_mode = str(o.get("mode", "net"))
	season_speed = clampi(int(o.get("speed", 1)), 1, Game.SEASON_SPEED_MAX)
	season_sessions = str(o.get("sessions", "typical" if season_tempo == "calendar" else "none"))
	season_floors = maxi(0, int(o.get("floors", 0)))
	if str(o.get("strategy", "")) == "auto":
		strategy = "auto"
	if not SEASON_STRATEGIES.has(strategy):
		strategy = "thorough"


## Duck-typed helpers for the season screens (FullRunSeasonUi): wait, note.
func wait_for(cond: Callable, budget: int, what: String) -> bool:
	return await _wait(cond, budget, what)


func note(text: String) -> void:
	_note(text)


# --- the run ----------------------------------------------------------------------------------------------------------

func _season_main() -> void:
	phase = "boot_to_title"
	if not await _wait(func() -> bool: return Router.current is TitleScreen and not Router.busy, BOOT_BUDGET, "title"):
		return
	var run_seed: int = TitleFlow.boot_seed if TitleFlow.boot_seed >= 0 else RUN_SEED
	_rt_seed = run_seed
	if load(RT_BOT_PATH) == null:
		fail("real-time run without %s (the bot is part of the test tools)" % RT_BOT_PATH)
		return
	if not DB.has_id("seasons", season_def):
		fail("unknown season template %s" % season_def)
		return
	var fmt: int = DB.season_def(season_def).format
	_season_planner = load(SEASON_PLANNER_PATH) as GDScript
	if _season_planner == null:
		fail("a season run without %s (the planner is part of the test tools)" % SEASON_PLANNER_PATH)
		return
	if season_tempo == "calendar" and season_sessions != "none":
		var prof: GDScript = load(SEASON_PROFILES_PATH) as GDScript
		_season_plan.assign(prof.call("sessions", season_sessions, run_seed, fmt))
	var start_utc: int = SEASON_START_UTC if _season_plan.is_empty() else SEASON_DAY0_UTC + int(_season_plan[0]["start"])
	phase = "season start"
	_season_ui = SeasonUi.new(self)
	var opts: Dictionary = {"tempo": season_tempo, "mode": season_mode, "unlock": true, "seed": run_seed,
		"now": start_utc, "tz_sec": 0, "air_time": SEASON_AIR, "number": 1}
	_note("season %s (%d floors), %s, %s, strategy %s, pace %s, sessions %s, speed %d, seed %d, hero %s" % [
		season_def, fmt, season_tempo, season_mode, strategy, pace, season_sessions, season_speed, run_seed, hero])
	if not _season_ui.call("start", SAVE_SLOT, season_def, opts, hero):
		return
	if not await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, INTRO_BUDGET,
			"the exploration of floor 1"):
		return
	if Game.state.season == null or Game.state.season.day0_utc != SEASON_DAY0_UTC:
		fail("the season did not start at day 0 = %d" % SEASON_DAY0_UTC)
		return
	_note("real-time combat, bot profile %s" % rt_profile)
	_season_session_wall = start_utc
	_season_in_session = true
	while not finished and not _season_done:
		if not await _season_step():
			return
	if finished:
		return
	_season_finish()


## One step: settle the views, follow the floor, end a session, the next goal.
func _season_step() -> bool:
	if not await _season_settle():
		return false
	if _season_done:
		return true
	_season_track()
	_season_pensum()
	if _season_session_over():
		_season_logout_due = true
	var obj: Dictionary = _season_objective()
	phase = "floor %d: %s" % [Game.state.floor_run.index, objective_text(obj)]
	if not _check_progress(obj):
		return false
	if pace == "human" and not ["wait", "logout"].has(str(obj["kind"])):
		if not await human_wait(HUMAN_DECIDE_SEC):
			return false
		if _interrupted(_ex()):
			return true
	return await _season_do(obj)


## Waits until the season run is calm in the exploration: combats, safe rooms (_season_safe_room), the Etagen-Bilanz,
## the wake summary after a login, the medics' route and a rescue (a new exploration), the end screens.
func _season_settle() -> bool:
	var n: int = 0
	while not finished and not _season_done:
		var cur: Node = Router.current
		_season_count_battles()
		if not Router.busy and cur != null:
			if cur is SafeRoomScene:
				_season_track()
				if not await _season_safe_room(cur as SafeRoomScene):
					return false
				n = 0
				continue
			if cur is FloorSummary:
				if not await _season_floor_summary(cur as FloorSummary):
					return false
				n = 0
				continue
			if cur.scene_file_path == Router.SCENE_CREDITS or cur.scene_file_path == Router.SCENE_GAME_OVER:
				return await _season_end_screen(cur)
			if bool(_season_ui.call("is_wake_summary", cur)):
				if not await _season_ui.call("wake", cur):
					return false
				_season_in_session = true
				n = 0
				continue
			if cur is ExplorationScene:
				var ex: ExplorationScene = cur as ExplorationScene
				if _rt_arm(ex):
					if not await _rt_combat(ex):
						return false
					n = 0
					continue
				if ex.active_dialog() != null and not ex.is_revealing():
					ex.active_dialog().cancel()             # a dialog the bot did not open: close it
				elif not ex.is_encounter_pending() and not ex.is_modal():
					return true
			else:
				return fail("unexpected screen %s in the season run" % _screen_name(cur))
		n += 1
		if n > SEASON_SETTLE_BUDGET:
			return fail("the season run did not settle within %d frames (%s)" % [SEASON_SETTLE_BUDGET, state_text()])
		await get_tree().process_frame
	return not finished


# --- the planner ------------------------------------------------------------------------------------------------------

## The next goal on a season floor: the logout of a finished session (the nearest safe room within SEASON_LOGOUT_DIST,
## else here), the tutorial (floor 1), a heal trip, then the planner's goal (season_planner.gd goal — the same rules as
## the headless harness: the strategy's candidates, level up before a boss, the Revier-Boss, the red groups, the
## Etagenboss, the stairs, else "wait"); a boss with the party below 90 % HP / 70 % MP → a safe room first; closed
## stairs ("Kulissen im Aufbau") are walked to once per floor (the dialog says so), then waited for.
func _season_objective() -> Dictionary:
	var ex: ExplorationScene = _ex()
	var layout: FloorLayout = ex.get_layout()
	var fr: FloorRun = Game.state.floor_run
	var here: Vector2i = ex.get_player_cell()
	var dist: Dictionary = layout.distances(here, fr.opened_gates, false, _boss_blocks(layout, fr, SEASON_NO_CELL))
	_use_heal_items()
	equip_best()
	if _season_logout_due:
		var sr: Dictionary = _nearest_safe(layout, dist)
		if not sr.is_empty() and int(dist.get(sr["cell"], 99)) <= SEASON_LOGOUT_DIST:
			sr["why"] = "logout"
			return sr
		return {"kind": "logout", "id": "", "cell": here, "why": "corridor"}
	if fr.index == 1 and fr.defeated_groups.is_empty() and layout.enemy_by_id("f1_g0") != null:
		return {"kind": "group", "id": "f1_g0", "cell": layout.enemy_by_id("f1_g0").cell, "why": "tutorial"}
	if party_ratio("hp") < SAFE_ROOM_BELOW and _heal_trips < 2:
		var heal: Dictionary = _nearest_safe(layout, dist)
		if not heal.is_empty() and int(dist.get(heal["cell"], 99)) <= SAFE_ROOM_MAX_DIST:
			_heal_trips += 1
			heal["why"] = "heal"
			return heal
	var tries: Dictionary = {"qb": _season_tries("qb"), "fb": _season_tries("fb"),
		"fb_floor": (_season_rec.get("fb", []) as Array).size()}
	var g: Dictionary = {}
	if fr.index == 1 and layout.programme.is_empty():
		var best: Dictionary = _season_floor_one(layout, fr, dist)
		g = best if not best.is_empty() else _season_planner.call("goal", Game.state, DB.data, layout, here,
			strategy, tried, tries)
	else:
		g = _season_planner.call("goal", Game.state, DB.data, layout, here, strategy, tried, tries)
	if str(g["kind"]) == "boss" and bool(g.get("heal", false)) and _heal_trips < 2:
		var sr2: Dictionary = _nearest_safe(layout, dist)
		if not sr2.is_empty():
			_heal_trips += 1
			sr2["why"] = "heal before " + str(g["id"])
			return sr2
	var closed: String = str(_season_planner.get_script_constant_map().get("CLOSED", "?"))
	if str(g["kind"]) == "wait" and str(g["why"]).begins_with(closed) and not _season_shut:
		return {"kind": "stairs", "id": "stairs", "cell": layout.stairs, "why": "closed?"}
	return g


## Floor 1 (handbuilt, no quarters): the campaign's candidates (strays, E1 secrets; `auto` → the planner's
## auto_strategy); {} when none is left (then the planner's bosses and stairs).
func _season_floor_one(layout: FloorLayout, fr: FloorRun, dist: Dictionary) -> Dictionary:
	var keep: String = strategy
	if strategy == "auto":
		strategy = str(_season_planner.call("auto_strategy", Game.state))
	var best: Dictionary = _season_planner.call("nearest", candidates(layout, fr, dist), dist)
	strategy = keep
	return best


## Boss attempts of this floor stay since the last login (kind "qb" | "fb").
func _season_tries(kind: String) -> int:
	var n: int = 0
	for b: Dictionary in (_season_rec.get(kind, []) as Array):
		if int(b.get("session", -1)) == _season_session:
			n += 1
	return n


func _season_do(obj: Dictionary) -> bool:
	match str(obj["kind"]):
		"wait":
			return await _season_wait(str(obj["why"]))
		"logout":
			return await _season_logout(null)
	return await _do(obj)


## Nothing to do now (closed stairs, a boss lost too often, the finale floor done): with sessions the session ends (the
## logout); Am Stück and without sessions the bot stands still for SEASON_IDLE_FRAMES (the countdown or the clock
## brings the collapse, the next floor opens, the next programme point comes).
func _season_wait(why: String) -> bool:
	if season_tempo == "calendar" and not _season_plan.is_empty():
		_note("nothing to do on floor %d (%s): the session ends" % [Game.state.floor_run.index, why])
		_season_logout_due = true
		return true
	var ex: ExplorationScene = _ex()
	var fr: FloorRun = Game.state.floor_run
	UiUtil.release_move_actions()
	var n: int = 0
	while not finished and n < SEASON_IDLE_FRAMES and not _interrupted(ex) and Game.state.floor_run == fr:
		n += 1
		await get_tree().process_frame
	_last_sig = ""                                  # waiting is progress (the clock moved)
	return not finished


# --- floors -----------------------------------------------------------------------------------------------------------

## Follows the candidate's floor: a new floor (stairs or rescue) closes the record of the old one and opens one; a load
## (login) keeps the record and takes the loaded floor run.
func _season_track() -> void:
	var fr: FloorRun = Game.state.floor_run if Game.state != null else null
	if fr == null:
		return
	if not _season_rec.is_empty() and int(_season_rec["floor"]) == fr.index:
		_season_rec["fr"] = fr
		return
	if not _season_rec.is_empty():
		_season_close_floor("stairs" if _season_descended else "rescue")
	_season_descended = false
	_season_open_floor()


func _season_open_floor() -> void:
	var fr: FloorRun = Game.state.floor_run
	var band: Vector2i = LevelBand.band(DB.data, fr.index)
	_season_rec = {"floor": fr.index, "fr": fr, "arrive_play": _season_play, "arrive_day": _season_day(),
		"level_in": _levels(), "band": [band.x, band.y], "combats": 0, "combat_sec": 0.0, "defeats": 0, "qb": [],
		"fb": [], "lost": [], "credits_in": Game.state.inventory.credits, "credits_won": credits_earned,
		"safe_visits": 0, "deaths_in": Game.state.season.deaths, "rescues_in": Game.state.season.rescues}
	tried.clear()
	_heal_trips = 0
	_last_sig = ""
	_same_sig = 0
	_season_shut = false
	var def: FloorDef = Game.floor_def()
	_note("floor %d (%s): band %d–%d, level %s, day %.2f" % [fr.index, def.name if def != null else "?", band.x,
		band.y, str(_levels()), _season_day()])
	if fr.index > 1 and def != null and def.has_zones():
		var layout: FloorLayout = DungeonGenerator.generate(def, fr.seed)
		var open: int = 0
		for p: Dictionary in layout.programme:
			open += 1 if fr.opened_gates.has(str(p["key"])) else 0
		if open != mini(Game.state.season.points(fr.index), layout.programme.size()):
			fail("floor %d: %d programme doors open, %d programme points" % [fr.index, open,
				Game.state.season.points(fr.index)])


func _season_close_floor(how: String) -> void:
	if _season_rec.is_empty():
		return
	var fr: FloorRun = _season_rec["fr"]
	var r: Dictionary = _season_rec.duplicate(true)
	r.erase("fr")
	r["how"] = how
	r["explore_sec"] = int(fr.stats.get("time_used_ticks", 0)) / FloorRun.TICKS_PER_SEC
	r["play_sec"] = roundi(_season_play - float(r["arrive_play"]))
	r["combat_sec"] = roundi(float(r["combat_sec"]))
	r["level_out"] = _levels()
	r["leave_day"] = _season_day()
	r["credits_out"] = Game.state.inventory.credits
	r["credits_won"] = credits_earned - int(r["credits_won"])
	r["groups"] = fr.defeated_groups.size()
	r["chests"] = fr.opened_chests.size()
	r["events"] = fr.completed_events.size()
	r["rooms"] = fr.visited.size()
	r["safe_rooms"] = fr.visited_safe_rooms.size()
	r["programme"] = fr.daily.size()
	r["deaths"] = Game.state.season.deaths - int(r["deaths_in"])
	r["rescued"] = how == "rescue"
	r.erase("deaths_in")
	r.erase("rescues_in")
	season_floor_log.append(r)
	_season_rec = {}
	_note("floor %d left (%s): %d s play, %d s explored, %d combats (%d s), level %s → %s, band %s" % [int(r["floor"]),
		how, int(r["play_sec"]), int(r["explore_sec"]), int(r["combats"]), int(r["combat_sec"]), str(r["level_in"]),
		str(r["level_out"]), str(r["band"])])


## The Pensum marks of the floor stay (season_planner.gd pensum): play seconds since the arrival when the Pflichtweg
## ("pflicht_sec") and vollständig ("full_sec") were done.
func _season_pensum() -> void:
	var ex: ExplorationScene = _ex()
	if _season_rec.is_empty() or ex == null or (_season_rec.has("pflicht_sec") and _season_rec.has("full_sec")):
		return
	var pm: Dictionary = _season_planner.call("pensum", Game.state, DB.data, ex.get_layout(), ex.get_player_cell(),
		tried, (_season_rec["fb"] as Array).size())
	for k: String in ["pflicht", "full"]:
		if bool(pm[k]) and not _season_rec.has(k + "_sec"):
			_season_rec[k + "_sec"] = roundi(_season_play - float(_season_rec["arrive_play"]))


## Days since day 0 in season time (the cast's clock: without the Sendepause).
func _season_day() -> float:
	return float(CastSim.now(Game.state)) / float(SeasonClock.DAY_SEC) if Game.state != null else 0.0


## The combats since the last look go into the floor's record (count, seconds, defeats, the bosses with outcome).
func _season_count_battles() -> void:
	while _season_battles_seen < battles.size():
		var b: Dictionary = battles[_season_battles_seen]
		_season_battles_seen += 1
		if _season_rec.is_empty():
			continue
		_season_rec["combats"] = int(_season_rec["combats"]) + 1
		_season_rec["combat_sec"] = float(_season_rec["combat_sec"]) + float(b["sec"])
		if str(b["outcome"]) == "defeat":
			_season_rec["defeats"] = int(_season_rec["defeats"]) + 1
			if not bool(b["boss"]) and str(b["group"]) != "":   # season_planner.gd GROUP_TRIES
				tried["lost:" + str(b["group"])] = int(tried.get("lost:" + str(b["group"]), 0)) + 1
				(_season_rec["lost"] as Array).append(str(b["enc"]))
		var def: FloorDef = DB.floor_def(int(_season_rec["floor"]))
		if bool(b["boss"]) and def != null:
			var kind: String = "qb" if str(b["enc"]) == def.quarter_boss else "fb"
			(_season_rec[kind] as Array).append({"outcome": str(b["outcome"]), "sec": b["sec"], "level": b["level"],
				"session": _season_session})
			if kind == "qb" and str(b["outcome"]) == "victory" and def.has_zones() \
					and not Game.state.inventory.has(ZoneGenerator.key_item(def)):
				fail("floor %d: the Revier-Boss fell without dropping %s" % [def.index, ZoneGenerator.key_item(def)])


# --- the season's screens --------------------------------------------------------------------------------------------

## A safe-room visit in a season: the replay check, the Mopsula scenes, lootboxes, the Recall (floor 3), the rows of the
## talent tree, the class abilities on the bar, gear and the vending machine — no "Speichern" (a season saves by
## itself); a finished session logs out here (rested); then back into the exploration.
func _season_safe_room(scene: SafeRoomScene) -> bool:
	phase = "safe room %s" % scene.safe_room_id
	await get_tree().process_frame
	var fr: FloorRun = Game.state.floor_run
	_note("safe room %s (visit %d, floor %d)" % [scene.safe_room_id, fr.safe_room_visits, fr.index])
	if not _season_rec.is_empty():
		_season_rec["safe_visits"] = int(_season_rec["safe_visits"]) + 1
	if not _replay_check():
		return false
	var guard: int = 0
	while scene.pending_scene != null and guard < 4:
		guard += 1
		var played: int = scene.played_scenes.size()
		var scene_id: String = scene.pending_scene.id
		scene.activate("mopsula")
		if not await _wait(func() -> bool: return scene.played_scenes.size() > played, SAFE_BUDGET,
				"Mopsula scene %s" % scene_id):
			return false
		_note("Mopsula scene %s" % scene_id)
	if not Game.state.pending_lootboxes.is_empty():
		if not await _open_lootboxes(scene):
			return false
	if fr.index >= 3 and Game.state.member("kai") != null and Game.state.member("kai").class_id == "":
		if not _season_ui.call("recall"):
			return false
		if not SeasonRules.unlocks_no_net(Game.state):
			return fail("the Recall does not unlock Ohne Netz (09 V-7)")
	var picks: PackedStringArray = await _season_ui.call("talent_rows", scene)
	if finished:
		return false
	_season_talents.append_array(picks)
	for p: String in picks:
		_note("talent row: %s" % p)
	_season_ui.call("loadout")
	equip_best()
	if not await _shop(scene):
		return false
	equip_best()
	if _season_logout_due:
		return await _season_logout(scene)
	scene.activate("leave")
	return await _wait(func() -> bool: return Router.current is ExplorationScene and not Router.busy, 300,
		"exploration after leaving %s" % scene.safe_room_id)


## The stairs dialog of a season floor (_use_interactable): "Noch nicht" once per floor (the floor stays, the floor
## time goes on), then "Abstieg" — or, closed in the calendar ("Kulissen im Aufbau", 09 §2.6), "Noch nicht" and wait.
func _season_stairs(ex: ExplorationScene, dlg: Node) -> bool:
	var fr: FloorRun = Game.state.floor_run
	if not await _hold_and_check_timer("stairs dialog"):
		return false
	if not tried.has("stairs"):
		tried["stairs"] = true
		dlg.call("choose", "stay")
		if not await _wait(func() -> bool: return not ex.is_modal(), 60, "stairs dialog closed"):
			return false
		if Router.current != ex or Game.state.floor_run != fr:
			return fail("\"Noch nicht\" at the stairs left floor %d" % fr.index)
		_note("stairs: \"Noch nicht\" keeps the party on floor %d" % fr.index)
		return true
	if str(_season_ui.call("stairs", dlg)) == "closed":
		_season_shut = true
		if not await _wait(func() -> bool: return not ex.is_modal(), 60, "stairs dialog closed"):
			return false
		_note("stairs of floor %d closed: Kulissen im Aufbau (opens in %d s)" % [fr.index,
			SeasonRules.opens_in(Game.state, fr.index + 1)])
		return true
	_note("stairs: descend from floor %d" % fr.index)
	_season_descended = true
	return true


## The Etagen-Bilanz: checked against the floor run (the stairs only — a rescue has none), recorded; "Weiter" (the
## next floor; with --floors the run stops after floor n).
func _season_floor_summary(fs: FloorSummary) -> bool:
	phase = "floor summary"
	var s: Dictionary = fs.summary
	if not _season_descended:
		return fail("an Etagen-Bilanz without the stairs: %s" % JSON.stringify(s))
	if not _season_rec.is_empty():
		_season_rec["summary"] = {"time_used_sec": int(s.get("time_used_sec", 0)), "kills": int(s.get("kills", 0)),
			"credits": int(s.get("credits", 0))}
	_note("floor summary %s" % JSON.stringify(s))
	if not _replay_check():
		return false
	if season_floors > 0 and Game.state.floor_run.index >= season_floors:
		_season_close_floor("stairs")
		season_stop = "floors"
		_season_done = true
		return true
	_season_ui.call("floor_summary", fs)
	var fs_id: int = fs.get_instance_id()          # the summary is freed on the way: no capture of the node
	return await _wait(func() -> bool: return Router.current != null and Router.current.get_instance_id() != fs_id \
		and not Router.busy, 600, "the next floor after the Etagen-Bilanz")


## The end of the candidate's season (the Abspann after the finale or the last collapse; the Sendeschluss Ohne Netz):
## the last floor's record, the replay check, the end screen.
func _season_end_screen(cur: Node) -> bool:
	phase = "season end"
	var s: SeasonState = Game.state.season
	if s.result == "":
		return fail("an end screen (%s) while the season goes on" % _screen_name(cur))
	season_stop = s.result
	var how: String = {"finalist": "finale", "end": "end", "fallen": "out", "buried": "out"}.get(s.result, s.result)
	_season_close_floor(how)
	_note("season over: %s on floor %d (Quote %d, Weste %s)" % [s.result, s.result_floor, SeasonRules.quote(
		Game.state), str(s.vest)])
	if not _replay_check():
		return false
	_season_done = true
	return await _season_ui.call("end_screen", cur)


# --- calendar: the clock, sessions, logout and login ------------------------------------------------------------------

## FullRun._process in a season run: play time (the season views of a session, never while paused) and in the calendar
## the season clock — one "clock" per SEASON_CLOCK_STEP game seconds (× speed), a combat's time right after it.
func _season_process(delta: float) -> void:
	if not _season_in_session or get_tree().paused or Game.state == null or Game.state.season == null:
		return
	_season_play += delta
	_season_session_play += delta
	if season_tempo != "calendar" or Game.state.season.asleep or Game.state.season.result != "":
		return
	if Game.combat != null or Game.in_battle:
		_season_fight_acc += delta
		return
	_season_clock_acc += delta
	if not (Game.timer_running or Game.safe_room_clock):
		return
	if _season_clock_acc + _season_fight_acc < SEASON_CLOCK_STEP and _season_fight_acc <= 0.0:
		return
	var sec: int = floori(_season_clock_acc + _season_fight_acc)
	if sec < 1:
		return
	if Game.season_clock(sec * season_speed):
		_season_clocks += 1
		_season_clock_acc -= float(sec) - _season_fight_acc
		_season_fight_acc = 0.0


## The session of the profile is played (calendar with sessions).
func _season_session_over() -> bool:
	return season_tempo == "calendar" and not _season_plan.is_empty() and _season_session < _season_plan.size() \
		and _season_session_play >= float(_season_plan[_season_session]["sec"])


## The logout of a finished session (in `scene` — a safe room, rested — or where the figure stands, Vorsichtig), the
## absence until the next session of the profile (after the last one: until after the last collapse), the login.
func _season_logout(scene: SafeRoomScene) -> bool:
	phase = "logout"
	var fr: FloorRun = Game.state.floor_run
	var rec: Dictionary = {"session": _season_session, "floor": fr.index, "day": snappedf(_season_day(), 0.01),
		"safe": scene != null, "play_min": snappedf(_season_session_play / 60.0, 0.1), "level": _levels()}
	_note("logout after %.1f min of session %d on floor %d (%s)" % [_season_session_play / 60.0, _season_session,
		fr.index, "safe room" if scene != null else "corridor"])
	var ok: bool = await _season_ui.call("logout_safe_room", scene) if scene != null \
		else await _season_ui.call("logout_exploration", _ex(), "careful")
	if not ok:
		return false
	_season_in_session = false
	_season_logout_due = false
	if not _season_rec.is_empty():
		_season_rec["sleeps"] = int(_season_rec.get("sleeps", 0)) + 1
	var wall: int = _season_session_wall + roundi(_season_session_play)
	_season_session += 1
	var next: int = SEASON_DAY0_UTC + SeasonClock.format_days(Game.state.season.format) * SeasonClock.DAY_SEC \
		+ SEASON_AFTER_END_SEC
	if _season_session < _season_plan.size():
		next = SEASON_DAY0_UTC + int(_season_plan[_season_session]["start"])
	var absence: int = maxi(SeasonClock.COMBAT_GRACE_SEC, next - wall)
	rec["absence"] = absence
	season_logouts.append(rec)
	_season_session_wall = wall + absence
	_season_session_play = 0.0
	_season_clock_acc = 0.0
	_season_fight_acc = 0.0
	phase = "login"
	if not await _season_ui.call("login", absence):
		return false
	var logins: Array = _season_ui.get("logins")
	var away: int = int((logins.back() as Dictionary).get("away", -1)) if not logins.is_empty() else -1
	if away != absence and not bool((logins.back() as Dictionary).get("question", false)):
		_note("the login booked away %d s for an absence of %d s (wall clock second)" % [away, absence])
	return true


## The end of a season run: the report and the OK line (quit 0).
func _season_finish() -> void:
	if finished:
		return
	var s: SeasonState = Game.state.season if Game.state != null else null
	if s == null:
		fail("no season at the end of the run")
		return
	if season_stop != "floors" and s.mode == "net" and (s.result == "fallen" or s.result == "buried"):
		fail("Mit Netz the season ended with %s" % s.result)
		return
	var floors_seen: PackedInt32Array = []
	for r: Dictionary in season_floor_log:
		floors_seen.append(int(r["floor"]))
	for i in floors_seen.size():
		if floors_seen[i] != i + 1:
			fail("the floor records skip a floor: %s" % str(floors_seen))
			return
	finished = true
	result_code = 0
	result_line = "FULLRUN: OK season=%s floor=%d battles=%d level=%s deaths=%d rescues=%d frames=%d" % [
		season_stop, floors_seen[floors_seen.size() - 1] if not floors_seen.is_empty() else 0, battles.size(),
		"/".join(PackedStringArray(_levels().map(func(x: int) -> String: return str(x)))), s.deaths, s.rescues, frames]
	UiUtil.release_move_actions()
	if not dry_run:
		print("FULLRUN: season ", JSON.stringify(season_report()))
		print(result_line)
		clear_saves()
		get_tree().quit(0)


## The numbers of a season run (09 §11.6; the harness compares them, tools/season_harness.sh).
func season_report() -> Dictionary:
	var s: SeasonState = Game.state.season if Game.state != null else null
	var census: Dictionary = CastSim.census(Game.state, DB.data) if s != null else {}
	return {"def": season_def, "tempo": season_tempo, "mode": season_mode, "strategy": strategy, "pace": pace,
		"sessions": season_sessions, "speed": season_speed, "seed": _rt_seed, "hero": hero, "rt_profile": rt_profile,
		"stop": season_stop, "result": s.result if s != null else "", "result_floor": s.result_floor if s != null else 0,
		"vest": s.vest if s != null else false, "deaths": s.deaths if s != null else 0,
		"rescues": s.rescues if s != null else 0, "quote": SeasonRules.quote(Game.state) if s != null else 0,
		"stairs": s.stairs if s != null else 0, "level_end": _levels(), "play_min": snappedf(_season_play / 60.0, 0.1),
		"battles": battles.size(), "credits_earned": credits_earned, "credits_spent": credits_spent,
		"credits_end": Game.state.inventory.credits if Game.state != null else 0, "clocks": _season_clocks,
		"floors": season_floor_log, "logouts": season_logouts, "logins": _season_ui.get("logins"),
		"talents": _season_talents, "teleports": teleports, "direct_interactions": direct_interactions,
		"forced_encounters": forced_encounters, "replay_checks": replay_checks, "hints_read": hints_read,
		"cast": {"vest": int(census.get("vest", 0)), "in": int(census.get("in", 0)),
			"finalists": int(census.get("finalists", 0)), "ai": int(census.get("ai", 0))}, "frames": frames}


## --pace=human in a season: lets `sec` seconds of play time (+ the reading time of M.O.D. lines said meanwhile) pass
## while the figure stands still — the season's play time in both tempos (the calendar has no running countdown).
func _season_human_wait(sec: float) -> bool:
	var ex: ExplorationScene = _ex()
	if pace != "human" or ex == null:
		return not finished
	var until: float = _season_play + sec + _read_backlog
	_read_backlog = 0.0
	var start: float = _season_play
	var budget: int = roundi((sec + 60.0) * 60.0 / TIME_SCALE)
	UiUtil.release_move_actions()
	var n: int = 0
	while not finished and _season_play < until and n < budget:
		if _interrupted(ex):
			break
		n += 1
		await get_tree().process_frame
	human_wait_sec += _season_play - start
	return not finished
