extends Node
## Autoload `Show` (02_TECH §3.5): hype/viewers/followers, achievements, sponsors, M.O.D.
##
## State lives only in Game.state.show (ShowState) — plus the volatile battle context (`_rules`, gift queue,
## thresholds) and two RNGs: `_rng` (game logic, ONLY sponsor selection, seeded Game.next_seed("show") in
## begin_battle) and `_fx_rng` (chat, viewer noise, M.O.D. line choice; never game-relevant).
## Every game-relevant change happens synchronously in the calling method (never in _process), so replays
## (Game.replay_log) reproduce it exactly; while Game.replaying only pure presentation (lines, chat) is skipped.
##
## Sponsor-Fenster (05 §6.13): external gifts need an open window (GiftPolicy.check → SponsorWindows.check, with the
## gifts still waiting in the queue counted as reservations); an accepted gift is stamped with its window id
## ("sponsor_window") and books its slot when it is applied (GiftPolicy.note_applied). M.O.D. announces windows only
## in event/live runs (sponsor_presentation() == &"live"); the campaign keeps them to the subtle overlay badge.
##
## Hype is kept in whole points: positive gains are scaled by GameState.hype_gain_pm (equipment × talents, integer
## per mille) and rounded half up (deterministic, integral state hash, 05 §3.3 Nr. 5/9). A battle delta applies its
## positive parts scaled and its negative parts unscaled as one change (ShowDelta.hype_gain / hype_loss, GDD §7.3).
##
## 06-C (06 §4): M.O.D.'s preferences and the Unterhosen-Liga are Show reactions like the achievements — MarottenRules
## (static, ShowState.marotten) decides, this facade applies hype / followers / boxes / show_bet triggers and says the
## lines. The Liga tier is frozen in begin_battle and scales that battle's hype gains and followers (campaign only) on
## top of the equipment × talent factors (integer per mille, each step half up).

const CHAT_MIN_INTERVAL: float = 2.5         # GDD §7.5: max. 1 chat line per 2.5 s
const CHAT_INTERVAL: float = 6.0             # exploration chat every 6 ± 2 s by hype band
const CHAT_JITTER: float = 2.0
const CHAT_BAND_HIGH: float = 70.0
const CHAT_BAND_LOW: float = 30.0
const DISPLAY_SMOOTH_SEC: float = 1.5        # display viewers: 1 - exp(-delta / 1.5)
const NOISE_INTERVAL: float = 2.0            # display noise ±1.5 % every 2 s
const NOISE_PCT: float = 0.015
const PRIORITY_WINDOW_SEC: float = 3.0       # a line of lower priority is dropped while a higher one is this fresh
const HYPE_ACHIEVEMENT: float = 5.0
const HYPE_CHEST: float = 2.0
const HYPE_EVENT: float = 5.0
const HYPE_TIMER_300: float = 10.0
const HYPE_TIMER_60: float = 15.0
const ACH_FOLLOWERS: Dictionary = {"box_bronze": 20, "box_silver": 40, "box_gold": 80}
const FAN_PACK_HYPE: int = 5                 # 05 §6.10: (5 × effect_pm + 500) // 1000
## Battle reasons in announcement order (one M.O.D. line per event, GDD §11).
const ANNOUNCE_ORDER: Array[StringName] = [&"mopsula_ko", &"kai_ko", &"kill_streak", &"overkill", &"stunt_success",
	&"stunt_fail", &"low_hp", &"revive", &"flee", &"flee_fail", &"boring_fight", &"crit", &"weakness"]
const CHAT_FOR_REASON: Dictionary = {&"crit": "chat_crit", &"stunt_fail": "chat_stunt_fail",
	&"boring_fight": "chat_boring"}

var _rules: ShowRules = null
var _setup: BattleSetup = null
var _queue: Array[Dictionary] = []           # accepted, not yet delivered gifts
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()      # game logic: sponsor selection only
var _fx_rng: RandomNumberGenerator = RandomNumberGenerator.new()   # presentation only
var _announcer: ModAnnouncer = null
var _announcer_data: GameData = null
var _battle_active: bool = false
var _battle_closing: bool = false            # end_battle past its last turn boundary: no new threshold reservations
var _battle_n: int = 0                       # deterministic battle number for system gift ids (Game.next_seed index)
var _gift_k: int = 0
var _fired: PackedInt32Array = []            # thresholds crossed in this battle
var _open_thresholds: PackedInt32Array = []  # crossed thresholds whose system gift is still due
var _gifts_given: int = 0                    # gifts delivered in this battle (system + external)
var _external_given: int = 0
var _peak_battle: int = 0                    # viewers_peak_battle (noise-free maximum)
var _unlocked_battle: PackedStringArray = []
var _first_fight_said: bool = false
var _tutorial_turns: int = 0                 # party turns of a tutorial battle (stunt hint after the 2nd, GDD §1.4 B2)
var _hype_seen: float = -1.0                 # last hype value sent with hype_changed
var _synced_state: GameState = null
var _display: float = 0.0
var _noise: float = 0.0
var _noise_t: float = 0.0
var _chat_t: float = CHAT_INTERVAL
var _last_chat_at: float = -INF
var _now: float = 0.0                        # presentation clock (pauses with the tree)
var _last_line_prio: int = -1
var _last_line_at: float = -INF
## "floor_start" waits for the countdown to run in the exploration (GDD §1.4 B2: "Die Uhr läuft …" after the tutorial
## victory, never over the title / intro / credits); said on the next explore tick, retried while a fresher line of
## higher priority suppresses it.
var _floor_start_pending: bool = false
# --- 06-C: M.O.D.-Marotten / Unterhosen-Liga: volatile battle context + presentation pacing (never game state) --------
var _marotten: MarottenTracker = null       # tally of the running battle (like _rules)
var _liga_hype_pm: int = 1000               # Liga factors of the running battle, frozen in begin_battle
var _liga_follower_pm: int = 1000
var _last_marotten: Dictionary = {}         # the last battle's hearts / won bets / Liga tier (results screen)
var _announce_queue: PackedStringArray = [] # preferences M.O.D. still announces (after the "floor_start" line)
var _liga_said: Dictionary = {}             # "<floor>:<tag>" → true: Liga lines once per floor
var _last_liga_tier: int = -1
# --- 06-D (KI-Admin) ---
const EXTERNAL_GAP_SEC: float = 8.0          # live (AI) lines only in pauses: 8 s after the last M.O.D. line
var _twist_hype_pm: int = 1000               # tw_party_hats factor of the running battle (taken at begin_battle)
var external_refused: Dictionary = {}        # ModLineFilter reason → count (live lines dropped by the client filter)


func _ready() -> void:
	_fx_rng.randomize()
	Events.chest_opened.connect(_on_chest_opened)
	Events.lootbox_opened.connect(_on_lootbox_opened)
	Events.level_up.connect(_on_level_up)
	Events.floor_completed.connect(_on_floor_completed)
	Events.room_entered.connect(_on_room_entered)
	Events.floor_timer_warning.connect(_on_timer_warning)
	Events.floor_timer_expired.connect(_on_timer_expired)
	Events.event_completed.connect(_on_event_completed)
	Events.item_bought.connect(_on_item_bought)
	Events.explore_tick.connect(_on_explore_tick)
	Events.sponsor_gift_triggered.connect(_on_sponsor_gift_triggered)
	Events.floor_entered.connect(_on_floor_entered)
	Events.new_game_started.connect(_on_new_run)
	Events.game_loaded.connect(_on_new_run)
	Events.floor_timer_started.connect(_on_floor_timer_started)
	Events.sponsor_window_opened.connect(_on_sponsor_window_opened)
	Events.sponsor_window_closed.connect(_on_sponsor_window_closed)
	Events.twist_applied.connect(_on_twist_applied)        # 06-D


## Display only: smoothing, noise, exploration chat. No game-relevant state changes here.
func _process(delta: float) -> void:
	_now += delta
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var target: float = float(viewers())
	if _display <= 0.0:
		_display = target
	else:
		_display += (target - _display) * (1.0 - exp(-delta / DISPLAY_SMOOTH_SEC))
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = NOISE_INTERVAL
		_noise = _fx_rng.randf_range(-NOISE_PCT, NOISE_PCT)
	if Game.timer_running and not Game.in_battle and not Game.replaying:
		_chat_t -= delta
		if _chat_t <= 0.0:
			_chat_t = CHAT_INTERVAL + _fx_rng.randf_range(-CHAT_JITTER, CHAT_JITTER)
			chat(_band_tag())


# ======================================================================================================================
# Values
# ======================================================================================================================

## Noise-free ShowModel.viewers_for(...) — deterministic, used by stats/achievements.
func viewers() -> int:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return 0
	return ShowModel.viewers_for(_floor_mult(), st.show.hype, st.show.followers)


## Smoothed + noise, UI only.
func display_viewers() -> int:
	if _display <= 0.0:
		return viewers()
	return maxi(0, roundi(_display * (1.0 + _noise)))


func followers() -> int:
	var st: GameState = Game.state
	return st.show.followers if st != null and st.show != null else 0


func hype() -> float:
	var st: GameState = Game.state
	return st.show.hype if st != null and st.show != null else 0.0


## amount > 0 → × GameState.hype_gain_pm (equipment × talents); clamp 0..100; emits hype_changed.
func add_hype(amount: float, reason: StringName = &"") -> void:
	if amount > 0.0:
		_add_hype_parts(amount, 0.0, reason)
	else:
		_add_hype_parts(0.0, amount, reason)


## Emits followers_changed; checks milestones (§4.4.11).
func add_followers(n: int, reason: StringName = &"") -> void:
	var st: GameState = Game.state
	if st == null or st.show == null or n == 0:
		return
	var prev: int = st.show.followers
	var now: int = maxi(0, prev + n)
	var delta: int = now - prev
	if delta == 0:
		return
	if delta > 0:
		# CR-13: counters before the signal
		st.show.stats["followers_gained_run"] = int(st.show.stats.get("followers_gained_run", 0)) + delta
		if st.floor_run != null:
			st.floor_run.stats["followers_gained"] = int(st.floor_run.stats.get("followers_gained", 0)) + delta
	st.show.followers = now
	Events.followers_changed.emit(now, delta)
	_update_viewers(false)
	_check_milestones()


func bump_stat(stat_id: String, amount: int = 1) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null or not _known_stat(stat_id):
		return
	st.show.stats[stat_id] = int(st.show.stats.get(stat_id, 0)) + amount


func set_stat(stat_id: String, value: int) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null or not _known_stat(stat_id):
		return
	st.show.stats[stat_id] = value


func set_stat_max(stat_id: String, value: int) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null or not _known_stat(stat_id):
		return
	if value > int(st.show.stats.get(stat_id, 0)):
		st.show.stats[stat_id] = value


## AchievementTracker.evaluate → unlock handling.
func trigger(trigger_id: String, payload: Dictionary) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var unlocked: PackedStringArray = AchievementTracker.new(DB.data, st.show, st.flags).evaluate(trigger_id, payload)
	for id: String in unlocked:
		_unlock(id)


func is_unlocked(achievement_id: String) -> bool:
	var st: GameState = Game.state
	return st != null and st.show != null and st.show.achievements.has(achievement_id)


## ModAnnouncer.pick → format → emits mod_said(text, voice, tag, blocking); returns text ("" if none/suppressed).
## Lines of lower priority are dropped while a higher-priority line is fresh (PRIORITY_WINDOW_SEC) — except the
## ModAnnouncer.always_said tags (player actions / floor beats): they queue behind it and leave the window unchanged.
func say(tag: String, ctx: Dictionary = {}, blocking: bool = false) -> String:
	if Game.replaying or tag == "":
		return ""
	var prio: int = ModAnnouncer.priority(tag)
	var outranked: bool = _now - _last_line_at < PRIORITY_WINDOW_SEC and prio < _last_line_prio
	if outranked and not ModAnnouncer.always_said(tag):
		return ""
	var line: ModLineDef = _get_announcer().pick(tag, _floor_index(), hype(), _now)
	if line == null:
		return ""
	var text: String = _get_announcer().format(line, _full_ctx(ctx))
	if not outranked:
		_last_line_prio = prio
		_last_line_at = _now
	var voice: StringName = StringName(line.voice)
	if voice == &"mod" and Game.twist_effect_pm("mod_voice_mopsula", 0) > 0:
		voice = &"mopsula"                         # 06-D tw_mopsula_moderates: the Graf reads M.O.D.'s lines
	Events.mod_said.emit(text, voice, tag, blocking)
	return text


## 06-D: a live line from a ModVoiceProvider (M.O.D. live, 06 §5.8) — presentation only, never recorded. Shown only
## when it passes ModLineFilter.check (reasons counted in external_refused), the voice is mod | mopsula | chat, no
## replay / boss battle runs and EXTERNAL_GAP_SEC passed since the last M.O.D. line (lowest priority: it never
## pushes a scripted line aside). {name} is filled in here — the service never knows the player name.
## Emits mod_said(text, voice, "live:" + tag, false). true = shown.
func say_external(text: String, voice: StringName, tag: String) -> bool:
	var st: GameState = Game.state
	if Game.replaying or st == null:
		return false
	var reason: String = ModLineFilter.check(text)
	if reason == "" and not ModLineFilter.VOICES.has(String(voice)):
		reason = "voice"
	if reason != "":
		external_refused[reason] = int(external_refused.get(reason, 0)) + 1
		return false
	if _now - _last_line_at < EXTERNAL_GAP_SEC or (_setup != null and _setup.is_boss):
		return false
	_last_line_at = _now
	_last_line_prio = 0
	Events.mod_said.emit(text.strip_edges().format({"name": st.player_name}), voice, "live:" + tag, false)
	return true


## voice &"chat" line → emits chat_posted (max. one chat line per CHAT_MIN_INTERVAL).
func chat(tag: String, ctx: Dictionary = {}) -> void:
	if Game.replaying or tag == "" or _now - _last_chat_at < CHAT_MIN_INTERVAL:
		return
	var line: ModLineDef = _get_announcer().pick(tag, _floor_index(), hype(), _now)
	if line == null:
		return
	var text: String = _get_announcer().format(line, _full_ctx(ctx))
	var user: String = line.user if line.user != "" else _random_handle()
	_last_chat_at = _now
	Events.chat_posted.emit(user, text, _mood())


## hype := Balance.HYPE_START (30). The "floor_start" line is not said here (the floor may still be behind the intro,
## the tutorial or — unplayable — the credits) but once its countdown runs in the exploration: Events.floor_entered
## with the timer already started, or Events.floor_timer_started (Floor 1 after the tutorial victory), then on the next
## Events.explore_tick (GDD §1.4 B2).
func start_floor(floor_index: int) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	if not Game.replaying:
		_floor_start_pending = false
	_set_hype(ShowModel.HYPE_START, &"floor_start")
	_update_viewers(true)
	_check_milestones()
	_marotten_floor_start(floor_index)                # 06-C: today's preferences (from the seed)


## Re-emit hype/viewers/followers after load or RunSim tick (RunSim changes ShowState.hype directly).
func sync_from_state() -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	if _synced_state != st:
		_synced_state = st
		_display = float(viewers())
	var h: float = st.show.hype
	var delta: float = h - _hype_seen if _hype_seen >= 0.0 else 0.0
	_hype_seen = h
	Events.hype_changed.emit(h, delta, &"sync")
	Events.followers_changed.emit(st.show.followers, 0)
	_update_viewers(true)


func begin_battle(setup: BattleSetup) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null or setup == null:
		return
	_setup = setup
	_rules = ShowRules.new(DB.data, setup)
	_rng.seed = Game.next_seed("show")
	_battle_n = st.rng_counter
	_twist_hype_pm = Game.twist_effect_pm("hype_gain_pm", 1000)   # 06-D tw_party_hats, fixed for this battle
	_gift_k = 0
	_fired = PackedInt32Array()
	_open_thresholds = PackedInt32Array()
	_gifts_given = 0
	_external_given = 0
	_unlocked_battle = PackedStringArray()
	_battle_active = true
	_battle_closing = false
	_peak_battle = viewers()
	set_stat("explore_seconds_since_battle", 0)
	if setup.advantage == BattleSetup.Advantage.PREEMPTIVE:
		bump_stat("bark_openers" if setup.opener == "bark" else "preemptives")   # a bark is no sneaking (round 4)
	trigger("battle_started", {"encounter_id": setup.encounter_id,
		"encounter_type": _encounter_type(setup.advantage, setup.opener), "is_boss": setup.is_boss})
	if not _first_fight_said and st.show.stats.get("battles_won", 0) == 0 and st.show.stats.get("battles_fled", 0) == 0:
		_first_fight_said = true
		say("first_fight")
	_tutorial_turns = 0
	if setup.tutorial:
		say("tutorial_battle")                     # GDD §1.4 B2 guided hints
	var story: String = "story_battle:" + setup.encounter_id
	if _get_announcer().has_lines(story):
		say(story)                                 # GDD §1.4 story banners (B4: "Die Königin hört von euch.")
	_marotten_begin(setup)                         # 06-C: tally + Liga tier of this battle


func on_battle_event(e: ActionEvent) -> void:
	if e == null or _rules == null:
		return
	_apply_delta(_rules.feed(e))
	if _marotten != null:
		_marotten.on_battle_event(e)               # 06-C
	if e.type == ActionEvent.Type.MOD_LINE and e.text != "":
		say(e.text)
	_emit_boss_hp(e)
	if _setup != null and _setup.tutorial and e.type == ActionEvent.Type.TURN_END and e.actor_id.begins_with("p"):
		_tutorial_turns += 1
		if _tutorial_turns == 2:
			say("tutorial_stunt")                  # GDD §1.4 B2: stunt hint after turn 2


## THE single gift entry (Brief §6b.4) → {"accepted": bool, "reason": String} (+ "ok", "gift_id", "apply": "now" |
## "queued", 05 §6.5). In battle (Game.in_battle) accepted gifts wait in the queue (take_pending_gift); outside they
## are applied at once (external gifts recorded as {"t": "gift"} at that moment).
func receive_gift(gift: Dictionary) -> Dictionary:
	var g: Dictionary = gift.duplicate(true)
	var gid: String = str(g.get("gift_id", ""))
	var st: GameState = Game.state
	if st == null or not Game.accepts_gifts():
		return _rejected(gid, "run_not_active")           # no run, its floor is done or the event run finished
	var reason: String = Gift.validate(g)
	if reason != "":
		return _rejected(gid, reason)
	if str(g.get("source", "")) == "dev" and not OS.is_debug_build():
		return _rejected(gid, "not_accepting")            # QA gifts only in debug builds (05 §6.3)
	if not _is_system(g):
		if _is_duplicate(gid):
			return _rejected(gid, "duplicate")
		var extra: Dictionary = _gift_extra()
		reason = GiftPolicy.refusal(st, DB.data, g, _event_rules(), extra)
		if reason != "":
			return _rejected(gid, reason)
		var run: Dictionary = _live_counters(st).duplicate()
		run.merge(extra, true)
		var wid: String = SponsorWindows.window_for(run, g)
		if wid != "" and str(g.get("sponsor_window", "")) == "":
			g["sponsor_window"] = wid               # 05 §6.13: the window that holds the gift's slot (recorded with it)
	if Game.in_battle:
		_queue.append(g)
		return _accepted(gid, "queued")
	_apply_outside(g)
	return _accepted(gid, "now")


## {} = none; battle gives the party situation for weight_mods. (1) first waiting external gift — checked AGAIN now
## (application_refusal; "too_soon" stays in the queue for a later boundary, any other refusal leaves the queue with
## gift_rejected), recorded, remembered and booked into the run counters (GiftPolicy.note_applied — the one booking of
## an in-battle gift) — while fewer than rules.gifts.max_per_battle external gifts were delivered in this battle;
## else (2) an open hype threshold → SponsorSystem.pick → Gift.make_system → receive_gift → returned.
## The controller applies the result with battle.apply_gift and then calls note_battle_gift(g, events).
func take_pending_gift(battle: BattleState = null) -> Dictionary:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return {}
	if _gifts_given < _max_gifts() and GiftPolicy.can_deliver_in_battle(_external_given, _gift_rules_now(st)):
		var i: int = 0
		while i < _queue.size():
			var ext: Dictionary = _queue[i]
			if _is_system(ext):
				i += 1
				continue
			_queue.remove_at(i)                            # checked without its own window reservation
			var refusal: String = application_refusal(ext)
			if refusal == "too_soon":
				_queue.insert(i, ext)                      # min_interval_sec: hold it for a later boundary
				i += 1
				continue
			if refusal != "":
				_rejected(str(ext.get("gift_id", "")), refusal)
				continue
			Game.record({"t": "gift", "gift": ext})
			GiftPolicy.remember(st, str(ext.get("gift_id", "")))
			GiftPolicy.note_applied(GiftApplier.live_counters(st), ext, {}, _tick())
			_gifts_given += 1
			_external_given += 1
			# the external gift may have taken the slot a reserved threshold was waiting for
			_drop_unservable_thresholds(_max_gifts() - _gifts_given)
			_after_delivery(ext)
			return ext
	while not _open_thresholds.is_empty():
		var t: int = _open_thresholds[0]
		_open_thresholds.remove_at(0)
		var g: Dictionary = {}
		if _gifts_given < _max_gifts():
			var sid: String = SponsorSystem.pick(DB.data, {"floor_index": _floor_index(),
				"is_boss": _setup != null and _setup.is_boss, "party": _battle_party(battle)}, _rng)
			if sid != "":
				g = _system_gift(sid)
		if not g.is_empty():
			var res: Dictionary = receive_gift(g)
			if not bool(res.get("accepted", false)):
				g = {}
			elif str(res.get("apply", "")) == "now":
				g = {}   # outside a battle the gift was applied right away
			else:
				_take_from_queue(str(g.get("gift_id", "")))
				_gifts_given += 1
		if t == _top_threshold():
			_reset_after_top()
		if not g.is_empty():
			_after_delivery(g)
			return g
	return {}


## Followers gained (negative on flight); stats; battle_won/battle_fled/boss_defeated. Gifts still waiting are
## applied outside the battle as the last step.
func end_battle(result: BattleResult) -> int:
	var st: GameState = Game.state
	if st == null or st.show == null or result == null:
		_reset_battle()
		return 0
	var gained: int = 0
	var enc_type: String = _encounter_type(result.advantage, result.opener)
	if result.outcome == BattleResult.Outcome.VICTORY and _rules != null:
		_apply_delta(_rules.end_delta(result))
	# Thresholds still open can no longer be served (no turn boundary left); an open top threshold resets hype to 80
	# now, before the follower conversion — hype_end and the peak are then the same whether a gift slot was free
	# when 100 was crossed (reset here) or not (reset at once in _check_thresholds).
	_drop_unservable_thresholds(0)
	# No turn boundary is left: crossings from here on (achievement hype of battle_won / boss_defeated / milestones)
	# can never get their gift — they take the "no gift possible" path (top threshold → reset to 80, GDD §7.4).
	_battle_closing = true
	match result.outcome:
		BattleResult.Outcome.VICTORY:
			bump_stat("battles_won")
			if result.advantage == BattleSetup.Advantage.AMBUSH:
				bump_stat("ambushes_won")
			var mres: Dictionary = _marotten_battle_end(result)   # 06-C: hearts → hit hype before the conversion
			var peak: int = maxi(_peak_battle, viewers())
			gained = ShowModel.followers_for_battle_pm(peak, hype(), result.is_boss, _battle_follower_pm(st, mres, 1000))
			if _liga_follower_pm != 1000:                         # the Liga part, capped per floor (06 §4.3)
				var full: int = ShowModel.followers_for_battle_pm(peak, hype(), result.is_boss,
					_battle_follower_pm(st, mres, _liga_follower_pm))
				gained += MarottenRules.take_liga_followers(st, DB.data, _marotten.liga_tier if _marotten != null else 0,
					full - gained)
			add_followers(gained, &"battle")
			var payload: Dictionary = {"party_turns": result.party_turns, "min_party_hp": result.min_party_hp,
				"min_party_hp_pct": result.min_party_hp_pct, "crits": result.crits, "weakness_hits": result.weakness_hits,
				"items_used": result.items_used, "party_kos": result.party_kos, "damage_taken": result.damage_taken,
				"is_boss": result.is_boss, "boss_id": result.boss_id, "encounter_type": enc_type,
				"group_id": result.group_id}
			Events.battle_won.emit(payload)
			trigger("battle_won", payload)
			if result.is_boss:
				var boss_payload: Dictionary = {"boss_id": result.boss_id, "party_turns": result.party_turns}
				Events.boss_defeated.emit(boss_payload)
				trigger("boss_defeated", boss_payload)
				say("boss_defeated")
			_marotten_rewards(mres, result)             # 06-C: won bets, Liga, show_bet achievements
		BattleResult.Outcome.FLED:
			bump_stat("battles_fled")
			var lost: int = ShowModel.followers_lost_on_flee(st.show.followers)
			add_followers(-lost, &"flee")
			gained = -lost
			var fled_payload: Dictionary = {"encounter_id": result.encounter_id, "is_boss": result.is_boss}
			Events.battle_fled.emit(fled_payload)
			trigger("battle_fled", fled_payload)
	var waiting: Array[Dictionary] = _queue.duplicate()
	_reset_battle()
	for g: Dictionary in waiting:
		if _is_system(g):
			continue
		var refusal: String = application_refusal(g)
		if refusal != "":
			_rejected(str(g.get("gift_id", "")), refusal)
			continue
		_apply_outside(g)
	return gained


func unlocked_this_battle() -> PackedStringArray:
	return _unlocked_battle.duplicate()


## How the Sponsor-Fenster are presented: &"off" (no windows: Pur-Liga, gifts disabled, no run), &"subtle" (campaign:
## dim badge only, no M.O.D. lines), &"live" (event/live runs that take viewer gifts: badge + M.O.D. lines).
func sponsor_presentation() -> StringName:
	if Game.state == null or not SponsorWindows.tracked(Game.state):
		return &"off"
	return &"subtle" if Game.mode == &"campaign" else &"live"


## Game.sponsor_window() (SponsorWindows.view) + "mode" (sponsor_presentation) + "pending" (accepted gifts of the open
## window still waiting for a turn boundary — they hold a slot). For the overlay badge, the debug tool and a shop UI.
func sponsor_window_view() -> Dictionary:
	var v: Dictionary = Game.sponsor_window()
	v["mode"] = String(sponsor_presentation())
	var pending: int = 0
	for q: Dictionary in _queue:
		if str(q.get("sponsor_window", "")) != "" and str(q.get("sponsor_window", "")) == str(v.get("id", "")):
			pending += 1
	v["pending"] = pending
	if bool(v.get("open", false)):
		v["free"] = maxi(0, int(v.get("slots", 0)) - int(v.get("used", 0)) - pending)
		v["full"] = int(v["free"]) == 0
	return v


## Run bookkeeping of a gift the controller applied IN battle (`events` = the ActionEvents of battle.apply_gift):
## GiftApplier.count_battle_items — gift items into flags.live.gift_items; the load/caps were booked once at the
## hand-out (take_pending_gift) — the same end state as RunSim's note_battle_gift (05 §6.9: run statistics must not
## depend on where the gift arrived). System gifts: nothing.
func note_battle_gift(g: Dictionary, events: Array[ActionEvent]) -> void:
	var st: GameState = Game.state
	if st == null or g.is_empty():
		return
	GiftApplier.count_battle_items(st, g, events)


## A battle torn down before its end (BattleScene freed early: tests, debug, scene change) — the battle context is
## dropped without end_battle (no followers, no stats); accepted gifts still waiting are refused (gift_rejected
## "run_not_active"), never applied. No-op without a running battle.
func abort_battle() -> void:
	if not _battle_active and _queue.is_empty():
		return
	var waiting: Array[Dictionary] = _queue.duplicate()
	_reset_battle()
	for g: Dictionary in waiting:
		if not _is_system(g):
			_rejected(str(g.get("gift_id", "")), "run_not_active")


## "" or why the external gift `g` may not be applied NOW (05 §6.10: the check at application is authoritative):
## GiftPolicy.refusal — the same function RunSim.gift_refusal runs, so live run and verifier agree (duplicate id,
## unknown content items, league, run binding, deadline, effect factor, interval, caps, Sponsor-Fenster) with the run
## clock and identity of Game.gift_context. No run / floor done → run_not_active. System gifts: "". Read-only.
func application_refusal(g: Dictionary) -> String:
	if _is_system(g):
		return ""
	var st: GameState = Game.state
	if st == null or not Game.accepts_gifts():
		return "run_not_active"
	return GiftPolicy.refusal(st, DB.data, g, _event_rules(), _gift_extra())


# ======================================================================================================================
# Internals
# ======================================================================================================================

func _set_hype(value: float, reason: StringName) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var prev: float = st.show.hype
	var now: float = ShowModel.clamp_hype(value)
	if now == prev:
		return
	st.show.hype = now
	if prev < 100.0 and now >= 100.0:
		# CR-13: counter before the signal
		st.show.stats["hype_100_count"] = int(st.show.stats.get("hype_100_count", 0)) + 1
	_hype_seen = now
	Events.hype_changed.emit(now, now - prev, reason)
	# Viewers (battle peak, viewers_max, floor peak, trigger) first: the value at this hype is recorded even when the
	# top threshold resets hype to 80 at once (no gift slot left) — the peak must not depend on the gift slots.
	_update_viewers(false)
	if _battle_active and now > prev:
		_check_thresholds(prev, now)


## Whole hype points from raw parts: gain × GameState.hype_gain_pm (equipment × talents), then in battle × the Liga
## factor (06-C) and × the tw_party_hats factor (06-D), both frozen at begin_battle — every step integer per mille,
## half up (06 §8.0 Nr. 4; no float path); loss unscaled; one clamped change.
func _add_hype_parts(gain: float, loss: float, reason: StringName) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var points: int = roundi(loss)
	var gain_points: int = roundi(gain)
	if gain_points > 0:
		var mult_pm: int = st.hype_gain_pm(DB.data)          # equipment × talents (06 §8.0 Nr. 4)
		if _battle_active and _liga_hype_pm != 1000:           # 06-C: Liga tier of the running battle
			mult_pm = (mult_pm * _liga_hype_pm + 500) / 1000
		if _battle_active and _twist_hype_pm != 1000:          # 06-D: tw_party_hats of the running battle
			mult_pm = (mult_pm * _twist_hype_pm + 500) / 1000
		points += (gain_points * mult_pm + 500) / 1000
	if points == 0:
		return
	_set_hype(ShowModel.clamp_hype(st.show.hype + points), reason)


## Upward threshold crossings in battle: a system gift is due while fewer than max gifts were (or will be) given;
## without gift the top threshold still resets hype to 80.
func _check_thresholds(prev: float, now: float) -> void:
	for t: int in SponsorSystem.crossed(prev, now, _fired):
		_fired.append(t)
		if not _battle_closing and _gifts_given + _open_thresholds.size() < _max_gifts():
			_open_thresholds.append(t)
			_open_thresholds.sort()   # ascending even when a nested change (achievement hype) crossed a higher one first
		elif t == _top_threshold():
			_reset_after_top()


## Reserved thresholds beyond the gift slots still free are dropped (highest first, so the top threshold goes first);
## a dropped top threshold resets hype to 80 at once — as if no slot had been free when it was crossed.
func _drop_unservable_thresholds(free_slots: int) -> void:
	var dropped_top: bool = false
	while _open_thresholds.size() > maxi(0, free_slots):
		var last: int = _open_thresholds.size() - 1
		dropped_top = dropped_top or _open_thresholds[last] == _top_threshold()
		_open_thresholds.remove_at(last)
	if dropped_top:
		_reset_after_top()


func _reset_after_top() -> void:
	if hype() > SponsorSystem.HYPE_AFTER_TOP:
		_set_hype(SponsorSystem.HYPE_AFTER_TOP, &"sponsor")


static func _top_threshold() -> int:
	return SponsorSystem.THRESHOLDS[SponsorSystem.THRESHOLDS.size() - 1]


## Noise-free viewers: when the value changed → ShowState.viewers, viewers_max / viewers_target_peak (before the
## signal, CR-13), floor and battle peak, viewers_changed, trigger viewers_changed. force_emit re-sends unchanged.
func _update_viewers(force_emit: bool) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var v: int = viewers()
	if v == st.show.viewers and not force_emit:
		return
	var changed: bool = v != st.show.viewers
	st.show.viewers = v
	if _battle_active:
		_peak_battle = maxi(_peak_battle, v)
	if st.floor_run != null:
		st.floor_run.stats["viewers_peak"] = maxi(int(st.floor_run.stats.get("viewers_peak", 0)), v)
	if changed:
		set_stat_max("viewers_max", v)
		set_stat_max("viewers_target_peak", v)
	Events.viewers_changed.emit(v)
	if changed:
		trigger("viewers_changed", {"viewers": v})


func _apply_delta(d: ShowDelta) -> void:
	if d == null:
		return
	var keys: Array = d.stats.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for k: Variant in keys:
		bump_stat(str(k), int(d.stats[k]))
	var gain: float = d.hype_gain
	var loss: float = d.hype_loss
	if gain == 0.0 and loss == 0.0:            # delta built without parts: the net value is all there is
		gain = maxf(d.hype, 0.0)
		loss = minf(d.hype, 0.0)
	_add_hype_parts(gain, loss, d.reasons[0] if not d.reasons.is_empty() else &"battle")
	var mopsula_moment: bool = false
	for t: Dictionary in d.triggers:
		var id: String = str(t.get("trigger", ""))
		var payload: Dictionary = t.get("payload", {})
		match id:
			"enemy_killed":
				Events.enemy_killed.emit(payload)
				mopsula_moment = mopsula_moment or str(payload.get("member", "")) == "mopsula"
			"stunt_resolved":
				Events.stunt_resolved.emit(payload)
				mopsula_moment = mopsula_moment or (bool(payload.get("success", false))
					and str(payload.get("member", "")) == "mopsula")
			"combo":
				Events.combo.emit(payload)
			"party_ko":
				Events.party_ko.emit(payload)
		trigger(id, payload)
	_announce(d.reasons, mopsula_moment)


## One M.O.D. line per event (most important reason) + chat reactions.
func _announce(reasons: Array[StringName], mopsula_moment: bool) -> void:
	if Game.replaying:
		return
	for r: StringName in ANNOUNCE_ORDER:
		if reasons.has(r) and say(String(r)) != "":
			break
	for r: StringName in reasons:
		if CHAT_FOR_REASON.has(r):
			chat(str(CHAT_FOR_REASON[r]))
			return
	if mopsula_moment:
		chat("chat_mopsula")


func _unlock(id: String) -> void:
	var st: GameState = Game.state
	if st == null or not DB.data.has_id("achievements", id):
		return
	var def: AchievementDef = DB.data.achievement(id)
	if _battle_active:
		_unlocked_battle.append(id)
	if st.floor_run != null:
		st.floor_run.stats["achievements"] = int(st.floor_run.stats.get("achievements", 0)) + 1
	Events.achievement_unlocked.emit(id)
	if def.box != "" and DB.data.has_id("lootboxes", def.box):
		st.pending_lootboxes.append(def.box)
		Events.lootbox_earned.emit(def.box)
	var f: int = def.followers if def.followers >= 0 else int(ACH_FOLLOWERS.get(def.box, 0))
	if f > 0:
		add_followers(f, &"achievement")
	add_hype(HYPE_ACHIEVEMENT, &"achievement")
	var tag: String = def.mod_tag if def.mod_tag != "" else "achievement:" + id
	var ctx: Dictionary = {"achievement": tr(def.name)}
	say(tag if _get_announcer().has_lines(tag) else "achievement_generic", ctx)
	Events.toast_requested.emit(tr(def.name), &"achievement")


## Milestones (followers ≥ value and floor ≥ min_floor), each once: box / credits / item / title flag
## (state.flags directly — a reaction, not the recording Game.set_flag), milestone_reached, M.O.D. line.
func _check_milestones() -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var floor_index: int = _floor_index()
	for ms: MilestoneDef in DB.data.all_milestones():
		if st.show.milestones.has(ms.id) or st.show.followers < ms.followers or floor_index < ms.min_floor:
			continue
		st.show.milestones.append(ms.id)
		if ms.reward_box != "" and DB.data.has_id("lootboxes", ms.reward_box):
			st.pending_lootboxes.append(ms.reward_box)
			Events.lootbox_earned.emit(ms.reward_box)
		var rewards: Array[LootReward] = []
		if ms.credits > 0:
			rewards.append(_loot("credits", "", ms.credits))
		if ms.item != "" and DB.data.has_id("items", ms.item):
			rewards.append(_loot("item", ms.item, 1))
		if not rewards.is_empty():
			Game.add_rewards(rewards)
		if ms.title != "":
			st.flags["title_" + ms.id] = true
		Events.milestone_reached.emit(ms.id)
		say(ms.mod_tag, {"followers": ms.followers})


# --- gifts ------------------------------------------------------------------------------------------------------------

func _apply_outside(g: Dictionary) -> void:
	var st: GameState = Game.state
	if st == null:
		return
	if not _is_system(g):
		Game.record({"t": "gift", "gift": g})
		GiftPolicy.remember(st, str(g.get("gift_id", "")))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(Game.next_seed("gift"))
	var rewards: Array[LootReward] = GiftApplier.apply(st, DB.data, g, rng, _tick())
	if not rewards.is_empty():
		Game.add_rewards(rewards)
	if str(g.get("kind", "")) == "sponsor_buff":
		Game.emit_party_changed()   # heals / MP outside a battle (Game is the party_changed emitter, §3.2)
	_after_delivery(g)


## Show side of a delivered gift: sponsor bookkeeping + line, fan-pack hype, gift_received.
func _after_delivery(g: Dictionary) -> void:
	var st: GameState = Game.state
	if st == null:
		return
	var kind: String = str(g.get("kind", ""))
	var effect_pm: int = JsonUtil.to_int(g.get("effect_pm", 1000), 1000)
	if kind == "sponsor_buff":
		var sid: String = str(g.get("sponsor_id", ""))
		if sid != "":
			st.show.sponsor_uses[sid] = int(st.show.sponsor_uses.get(sid, 0)) + 1
			Events.sponsor_gift_triggered.emit(sid)
			if _is_system(g) and DB.data.has_id("sponsors", sid):
				var def: SponsorDef = DB.data.sponsor(sid)
				say(def.mod_tag if def.mod_tag != "" else "sponsor_gift", {"sponsor": tr(def.name)})
	elif kind == "fan_pack":
		add_hype(float(GiftPolicy.scale(FAN_PACK_HYPE, effect_pm)), &"gift")
	if not _is_system(g):
		var sender: Variant = g.get("sender", {})
		var anon: bool = not (sender is Dictionary) or bool((sender as Dictionary).get("anon", true))
		var tag: String = "gift_received:anon" if anon else "gift_received"
		if kind == "gold":
			tag = "gift_received:credits"
		elif kind == "fan_pack" and not anon:
			tag = "fan_pack_received"
		# 05 §6.12: {sender} only by opt-in (display_name of a non-anonymous sender), {amount} = credits applied
		var shown_name: String = str((sender as Dictionary).get("display_name", "")) if sender is Dictionary else ""
		say(tag, {"sender": shown_name if not anon and shown_name != "" else "einem anonymen Fan",
			"amount": GiftPolicy.scale(maxi(0, JsonUtil.to_int(g.get("amount", 0))), effect_pm)})
		if effect_pm < 1000:
			say("gift_diminished", {"pct": effect_pm / 10})
		_after_window_booking(g)
	Events.gift_received.emit(g)


## The external gift took a slot of the open Sponsor-Fenster: sponsor_window_updated; the last slot → M.O.D. line
## (live presentation only).
func _after_window_booking(g: Dictionary) -> void:
	var wid: String = str(g.get("sponsor_window", ""))
	if wid == "":
		return
	var v: Dictionary = Game.sponsor_window()
	if not bool(v.get("open", false)) or str(v.get("id", "")) != wid:
		return
	Events.sponsor_window_updated.emit(v)
	if bool(v.get("full", false)) and sponsor_presentation() == &"live":
		say("sponsor_window_full")


## Gift.make_system for the k-th system gift of this battle (05 §6.5: g_sys_<battle_n>_<k>).
func _system_gift(sponsor_id: String) -> Dictionary:
	var k: int = _gift_k
	_gift_k += 1
	return Gift.make_system(sponsor_id, _battle_n, k)


func _take_from_queue(gift_id: String) -> void:
	for i in range(_queue.size() - 1, -1, -1):
		if str(_queue[i].get("gift_id", "")) == gift_id:
			_queue.remove_at(i)
			return


## External gift ids already applied in this run (GameState.flags["live"]["gift_ids"]) or waiting in the queue.
func _is_duplicate(gift_id: String) -> bool:
	if gift_id == "":
		return false
	for q: Dictionary in _queue:
		if str(q.get("gift_id", "")) == gift_id:
			return true
	var live: Dictionary = _live_counters(Game.state)
	var seen: Variant = live.get("gift_ids", [])
	return seen is Array and (seen as Array).has(gift_id)


static func _live_counters(st: GameState) -> Dictionary:
	if st == null:
		return {}
	var live: Variant = st.flags.get("live", {})
	return live if live is Dictionary else {}


## The `extra` of GiftPolicy.refusal: Game.gift_context ("tick" = the run clock, run identity — the same input
## RunSim.gift_refusal uses) plus the Sponsor-Fenster reservations of the gifts waiting in the queue
## ([[window id, sender_ref], …]; RunSim applies at once and has none, so a live acceptance is never looser than the
## replay's).
func _gift_extra() -> Dictionary:
	var run: Dictionary = Game.gift_context()
	if not run.has("tick"):
		run["tick"] = _tick()
	var pending: Array = []
	for q: Dictionary in _queue:
		if not _is_system(q) and str(q.get("sponsor_window", "")) != "":
			var s: Variant = q.get("sender", {})
			pending.append([str(q["sponsor_window"]), str((s as Dictionary).get("sender_ref", "")) if s is Dictionary
				else ""])
	run[SponsorWindows.PENDING_KEY] = pending
	return run


## Rules for the per-battle cap: the event rules, else the run's stored gift rules (RunSim), else the standard.
func _gift_rules_now(st: GameState) -> Dictionary:
	var rules: Dictionary = _event_rules()
	if not rules.is_empty():
		return rules
	var gr: Variant = _live_counters(st).get("gift_rules", {})
	return {"gifts": gr} if gr is Dictionary else {}


## boss_hp_changed for quest progress before the victory (05 §1.3): an event with hp_after on a boss enemy unit —
## the same rule as RunSim._quest_feed_battle.
func _emit_boss_hp(e: ActionEvent) -> void:
	if e.hp_after < 0 or e.max_hp <= 0 or not e.target_id.begins_with("e") or not DB.has_id("enemies", e.def_id):
		return
	if DB.enemy(e.def_id).boss:
		Events.boss_hp_changed.emit({"boss_id": e.def_id, "hp": e.hp_after, "max_hp": e.max_hp})


## Event-run gift rules (05 §6.10); campaign → {}.
func _event_rules() -> Dictionary:
	return Game.event_rules()


## The run clock (Game.sim): last_delivery_tick of the gift bookings.
func _tick() -> int:
	return Game.sim.tick() if Game.sim != null else 0


static func _is_system(g: Dictionary) -> bool:
	return str(g.get("source", "")) == "system"


func _accepted(gift_id: String, apply: String) -> Dictionary:
	return {"accepted": true, "ok": true, "reason": "", "gift_id": gift_id, "apply": apply}


func _rejected(gift_id: String, reason: String) -> Dictionary:
	Events.gift_rejected.emit(gift_id, reason)
	# 05 §6.12: tell the audience why (never for the Pur-Liga, duplicates or malformed gifts)
	match reason:
		"cap_reached", "chest_blocked":
			say("gift_capped")
		"not_accepting":
			say("gift_declined")
	return {"accepted": false, "ok": false, "reason": reason, "gift_id": gift_id, "apply": ""}


func _max_gifts() -> int:
	if _setup != null and _setup.is_boss:
		return SponsorSystem.MAX_GIFTS_PER_BOSS_BATTLE
	return SponsorSystem.MAX_GIFTS_PER_BATTLE


## Living party situation for weight_mods: BattleState.party(), falling back to the setup's combatants.
func _battle_party(battle: BattleState) -> Array:
	var party: Array = []
	if battle != null:
		party = battle.party()
	if party.is_empty() and _setup != null:
		party = _setup.party
	return party


func _reset_battle() -> void:
	_rules = null
	_setup = null
	_marotten = null                               # 06-C
	_liga_hype_pm = 1000
	_liga_follower_pm = 1000
	_twist_hype_pm = 1000
	_battle_active = false
	_battle_closing = false
	_open_thresholds = PackedInt32Array()
	_fired = PackedInt32Array()
	_queue.clear()


# --- signal handlers --------------------------------------------------------------------------------------------------

func _on_chest_opened(chest_id: String, _rewards: Array) -> void:
	add_hype(HYPE_CHEST, &"chest")
	bump_stat("chests_opened")
	trigger("chest_opened", {"chest_id": chest_id, "type": _chest_type(chest_id)})


func _on_lootbox_opened(box_id: String, rewards: Array) -> void:
	bump_stat("lootboxes_opened")
	var typed: Array[LootReward] = []
	for r: Variant in rewards:
		if r is LootReward:
			typed.append(r)
	trigger("lootbox_opened", {"box_id": box_id, "best_rarity": LootRoller.best_rarity(typed)})


func _on_level_up(payload: Dictionary) -> void:
	trigger("level_up", payload)
	say("level_up", {"level": payload.get("level", 1)})


func _on_floor_completed(floor_index: int) -> void:
	var st: GameState = Game.state
	var left: int = st.floor_run.time_left_ticks / FloorRun.TICKS_PER_SEC if st != null and st.floor_run != null else 0
	trigger("floor_completed", {"floor": floor_index, "timer_left": left})
	say("floor_end")
	_marotten_floor_end(floor_index)               # 06-C: Liga floor bonus, missed preferences, Liga hint


func _on_room_entered(_cell: Vector2i, room_kind: int, first_visit: bool) -> void:
	if first_visit and room_kind == RoomCell.Kind.STAIRS:
		say("stairs_found")


func _on_timer_warning(seconds_left: int) -> void:
	match seconds_left:
		600:
			chat("timer_warn_600")
		300:
			add_hype(HYPE_TIMER_300, &"timer")
			say("timer_warn_300")
		60:
			add_hype(HYPE_TIMER_60, &"timer")
			say("timer_warn_60")
		_:
			say("timer_warn_%d" % seconds_left)


func _on_timer_expired() -> void:
	say("timer_expired")


func _on_event_completed(payload: Dictionary) -> void:
	add_hype(HYPE_EVENT, &"event")
	bump_stat("events_completed")
	trigger("event_completed", payload)


func _on_item_bought(payload: Dictionary) -> void:
	bump_stat("credits_spent_vendor", JsonUtil.to_int(payload.get("cost", 0)))
	var item_id: String = str(payload.get("item_id", ""))
	var item_name: String = tr(DB.data.item(item_id).name) if DB.data.has_id("items", item_id) else item_id
	say("vendor_buy", {"item": item_name})
	trigger("item_bought", payload)


func _on_explore_tick(payload: Dictionary) -> void:
	trigger("explore_tick", payload)
	if _floor_start_pending and not Game.replaying and Game.state != null and Game.state.floor_run != null:
		if say("floor_start", {"floor": Game.state.floor_run.index}) != "":
			_floor_start_pending = false
	elif not _announce_queue.is_empty() and not Game.replaying and Game.state != null \
			and Game.state.floor_run != null and Game.state.floor_run.timer_started:
		if say("marotte_announce:" + _announce_queue[0]) != "":   # 06-C: after "floor_start", one per tick
			_announce_queue.remove_at(0)


func _on_floor_timer_started() -> void:
	if not Game.replaying:
		_floor_start_pending = true


## M.O.D. announces a window (live presentation only; L13/L16, 06 §6 decision 1: no purchase pressure — the lines name
## neither seconds nor slots, a price or a call to buy): "sponsor_window_open:<kind>" (the comeback window after a lost
## boss attempt: "sponsor_window_open:boss_comeback") → "sponsor_window_open".
func _on_sponsor_window_opened(window: Dictionary) -> void:
	if Game.replaying or sponsor_presentation() != &"live":
		return
	var kind: String = str(window.get("kind", ""))
	if bool(window.get("comeback", false)):
		kind = SponsorWindows.COMEBACK_TAG
	say("sponsor_window_open:" + kind)


## Only the natural end ("time") gets a line; "superseded" is followed by the next window's own line, "left" / "floor"
## end with the scene.
func _on_sponsor_window_closed(_window_id: String, reason: String) -> void:
	if Game.replaying or reason != "time" or sponsor_presentation() != &"live":
		return
	say("sponsor_window_closed")


## A floor whose countdown already runs (load, descent) queues "floor_start"; one whose countdown waits for its
## tutorial battle gets the GDD §1.4 B1 tutorial hints instead.
func _on_floor_entered(floor_index: int) -> void:
	var st: GameState = Game.state
	if not Game.replaying and st != null and st.floor_run != null and st.floor_run.timer_started:
		_floor_start_pending = true
	var def: FloorDef = DB.data.floor_def(floor_index) if DB.data != null else null
	if def == null or def.timer_start_after == "" or st == null or st.floor_run == null or st.floor_run.timer_started:
		return
	# 06 package A: with Graf Mopsula as hero the B1 hints explain the bark (`<tag>:mopsula`, fallback the base tag)
	var hero_suffix: String = ":mopsula" if st.hero == "mopsula" else ""
	say("tutorial_explore" + hero_suffix)
	say("tutorial_sneak" + hero_suffix)


## 06-D: a twist started → its M.O.D. line (the first Regie twist of a floor is announced with "regie_cut_in", the
## one-sentence explanation of 06 §0.5); tw_mopsula_monologue → params.lines Mopsula lines.
func _on_twist_applied(tv: Dictionary) -> void:
	if Game.replaying:
		return
	var id: String = str(tv.get("id", ""))
	if not DB.data.has_id("twists", id):
		return
	if str(tv.get("src", "")) == "regie" and int(TwistApplier.state_of(Game.state).get("floor_regie", 0)) == 1:
		say("regie_cut_in")
	var def: TwistDef = DB.data.twist(id)
	if def.mod_tag != "":
		say(def.mod_tag)
	if id == "tw_mopsula_monologue":
		var n: int = clampi(int((tv.get("params", {}) as Dictionary).get("lines", 3)), 1, 3)
		for i in n:
			say("regie_monologue_%d" % (i + 1))


func _on_sponsor_gift_triggered(sponsor_id: String) -> void:
	bump_stat("sponsor_gifts")
	trigger("sponsor_gift", {"sponsor_id": sponsor_id})


## New game / loaded save: fresh battle context, fresh presentation pacing (cooldowns, chat spacing).
func _on_new_run(_slot: int) -> void:
	_reset_battle()
	_floor_start_pending = false
	_marotten_new_run()                            # 06-C
	_first_fight_said = false
	_unlocked_battle = PackedStringArray()
	_synced_state = null
	_hype_seen = Game.state.show.hype if Game.state != null and Game.state.show != null else -1.0
	_announcer = null
	_last_chat_at = -INF
	_last_line_at = -INF
	_last_line_prio = -1
	_chat_t = CHAT_INTERVAL


# --- helpers ----------------------------------------------------------------------------------------------------------

func _get_announcer() -> ModAnnouncer:
	if _announcer == null or _announcer_data != DB.data:
		_announcer_data = DB.data
		_announcer = ModAnnouncer.new(DB.data, _fx_rng)
	return _announcer


func _floor_index() -> int:
	var st: GameState = Game.state
	return st.floor_run.index if st != null and st.floor_run != null else 1


func _floor_mult() -> float:
	var def: FloorDef = DB.data.floor_def(_floor_index()) if DB.data != null else null
	return def.floor_mult if def != null else 1.0


## Always adds name (player), floor, level (Kai), viewers, followers.
func _full_ctx(ctx: Dictionary) -> Dictionary:
	var st: GameState = Game.state
	var kai: PartyMember = st.member("kai") if st != null else null
	var full: Dictionary = {"name": st.player_name if st != null else "Kai", "floor": _floor_index(),
		"level": kai.level if kai != null else 1, "viewers": viewers(), "followers": followers()}
	full.merge(ctx, true)
	return full


func _random_handle() -> String:
	var line: ModLineDef = _get_announcer().pick("chat_handle", _floor_index(), hype(), _now)
	return line.text if line != null else "Zuschauer"


func _mood() -> StringName:
	var h: float = hype()
	if h >= CHAT_BAND_HIGH:
		return &"hype"
	if h < CHAT_BAND_LOW:
		return &"bored"
	return &"neutral"


func _band_tag() -> String:
	var h: float = hype()
	if h >= CHAT_BAND_HIGH:
		return "chat_hype_high"
	if h < CHAT_BAND_LOW:
		return "chat_hype_low"
	return "chat_hype_mid"


func _chest_type(chest_id: String) -> String:
	var def: FloorDef = DB.data.floor_def(_floor_index()) if DB.data != null else null
	if def != null:
		var chests: Variant = def.layout.get("chests", [])
		if chests is Array:
			for c: Variant in chests:
				if c is Dictionary and str((c as Dictionary).get("id", "")) == chest_id:
					return str((c as Dictionary).get("type", "wood"))
	return "wood"


## "preemptive" | "ambush" | "normal"; a PREEMPTIVE opened from Mopsula's bark is "bark" (integration round 4: the
## sneak-themed achievement "Leise Sohle" and the bet "Schleichwerbung" ask for "preemptive").
static func _encounter_type(advantage: int, opener: String = "") -> String:
	match advantage:
		BattleSetup.Advantage.PREEMPTIVE:
			return "bark" if opener == "bark" else "preemptive"
		BattleSetup.Advantage.AMBUSH:
			return "ambush"
	return "normal"


static func _loot(kind: String, item_id: String, amount: int) -> LootReward:
	var r: LootReward = LootReward.new()
	r.kind = kind
	r.id = item_id
	r.amount = amount
	return r


static func _known_stat(stat_id: String) -> bool:
	if StatIds.ALL.has(stat_id):
		return true
	push_warning("[Show] unknown stat id '%s'" % stat_id)
	return false


# ======================================================================================================================
# 06-C: M.O.D.-Marotten (show bets) and the Unterhosen-Liga (06 §4) — MarottenRules decides, Show applies and presents
# ======================================================================================================================

## Today's preferences and the Liga for the HUD chip / pause tab "Show" (MarottenRules.view with the run's rules):
## {"floor", "items": [{"id", "name", "desc", "hits", "goal", "won"}], "liga_tier", "liga_hype_pm",
## "liga_follower_pm", "rewards"}.
func marotten_view() -> Dictionary:
	return MarottenRules.view(Game.state, DB.data, _marotten_rules())


## The last won battle's part (results screen): {"hits": [{"id", "name", "hits", "goal", "won"}], "liga_tier"}; {}
## after a battle without hearts and outside the Liga.
func last_marotten() -> Dictionary:
	return _last_marotten.duplicate(true)


## Game.visit_room (first visit, recorded "room" command): the pacifist counter / explore preferences — only while the
## countdown runs and never for safe room cells (06 §4.4 mar_pacifist).
func on_room_visited(room_kind: int, zone: String) -> void:
	var st: GameState = Game.state
	if st == null or st.floor_run == null or not st.floor_run.timer_started or room_kind == RoomCell.Kind.SAFE:
		return
	var res: Dictionary = MarottenRules.on_zone(st, DB.data, zone, _marotten_rules())
	if int(res["hype"]) > 0:
		add_hype(float(res["hype"]), &"marotte")
	_marotten_apply(res)


## Event runs pass their rules (no rewards, rules.marotten / rules.liga switches); the campaign {}.
func _marotten_rules() -> Dictionary:
	return Game.event_rules()


func _marotten_floor_start(floor_index: int) -> void:
	var res: Dictionary = MarottenRules.on_floor(Game.state, DB.data, floor_index, _marotten_rules())
	var ids: PackedStringArray = res["announce"]
	Events.marotten_announced.emit(ids)
	if not Game.replaying:
		_announce_queue = ids.duplicate()
		_liga_said = {}


## New game / loaded save: old saves get the floor's preferences (deterministic from the seed); M.O.D. announces them
## only while the floor's countdown has not started yet (Floor 1: after the tutorial battle, GDD §1.4 B2).
func _marotten_new_run() -> void:
	_announce_queue = PackedStringArray()
	_liga_said = {}
	_last_liga_tier = -1
	_last_marotten = {}
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	MarottenRules.ensure_floor(st, DB.data, _marotten_rules())
	if st.floor_run != null and not st.floor_run.timer_started:
		_announce_queue = JsonUtil.to_str_array(st.show.marotten.get("active", []))


## begin_battle: pacifist counter reset, tally, the Liga tier of this battle (tutorial: none) and its factors.
func _marotten_begin(setup: BattleSetup) -> void:
	var st: GameState = Game.state
	var rules: Dictionary = _marotten_rules()
	MarottenRules.on_battle_start(st)
	var tier: int = 0 if setup.tutorial else MarottenRules.liga_tier(st, rules)
	_marotten = MarottenTracker.new()
	_marotten.begin(setup, tier)
	var paid: bool = MarottenRules.rewards_on(rules)
	_liga_hype_pm = MarottenRules.liga_pm(DB.data, tier, &"hype") if paid else 1000
	_liga_follower_pm = MarottenRules.liga_pm(DB.data, tier, &"follower") if paid else 1000
	if tier != _last_liga_tier:
		var left: bool = tier == 0 and _last_liga_tier > 0
		_last_liga_tier = tier
		Events.liga_changed.emit(tier)
		if tier > 0:
			_liga_line("liga_enter:%d" % tier + (":" + MarottenRules.hero_of(st) if tier == 1 else ""), tier)
		elif left:
			_liga_line("liga_leave", 0)


## Victory, before the follower conversion: hearts of this battle (MarottenRules.on_battle_end), their hit hype.
func _marotten_battle_end(result: BattleResult) -> Dictionary:
	var tally: Dictionary = _marotten.tally() if _marotten != null else {}
	tally["gifts"] = _gifts_given
	var res: Dictionary = MarottenRules.on_battle_end(Game.state, DB.data, result, tally, _marotten_rules())
	if int(res["hype"]) > 0:
		add_hype(float(res["hype"]), &"marotte")
	return res


## GameState.follower_pm (equipment × talents) × the Liga factor `liga_pm` (this battle's, or 1000 for the part without
## it) × the hearts' follower factor, integer per mille with each step rounded half up (06 §8.0 Nr. 4) — without
## talents bit-identical to package C's float path.
func _battle_follower_pm(st: GameState, mres: Dictionary, liga_pm: int) -> int:
	var pm: int = st.follower_pm(DB.data)
	var extra: int = (liga_pm * int(mres.get("follower_pm", 1000)) + 500) / 1000
	return pm if extra == 1000 else (pm * extra + 500) / 1000


## After battle_won: won bets (boxes, followers, hype, show_bet achievements), the Liga battle payload; lines.
func _marotten_rewards(mres: Dictionary, result: BattleResult) -> void:
	var tier: int = int(mres.get("liga_tier", 0))
	_last_marotten = {"hits": _marotten_items(mres["hits"] as Array), "liga_tier": tier}
	_marotten_apply(mres)
	if tier > 0 and result.is_boss and not Game.replaying:
		say("liga_win")


## Shared by battles and room visits: boxes → pending_lootboxes, followers / hype of won bets, show_bet triggers,
## signals; presentation: hit / won lines and toasts.
func _marotten_apply(res: Dictionary) -> void:
	var st: GameState = Game.state
	for box: Variant in (res["boxes"] as Array):
		st.pending_lootboxes.append(str(box))
		Events.lootbox_earned.emit(str(box))
	if int(res["followers"]) > 0:
		add_followers(int(res["followers"]), &"marotte")
	if int(res["won_hype"]) > 0:
		add_hype(float(res["won_hype"]), &"marotte")
	var hits: Dictionary = st.show.marotten.get("hits", {}) if st.show.marotten.get("hits", {}) is Dictionary else {}
	for id: Variant in (res["hits"] as Array):
		var def: MarotteDef = DB.data.marotte(str(id)) if DB.data.has_id("marotten", str(id)) else null
		Events.marotte_progress.emit(str(id), int(hits.get(str(id), 0)), def.goal if def != null else 0)
	for id: Variant in (res["won"] as Array):
		Events.marotte_won.emit(str(id))
	for p: Variant in (res["show_bet"] as Array):
		trigger("show_bet", p as Dictionary)
	if Game.replaying:
		return
	if str(res.get("bonus", "")) != "":                       # 06 B × C: "Kamera 3 kennt mich" (marotte_heart)
		Events.toast_requested.emit("Talent: Extra-Herz für M.O.D.s Vorliebe!", &"marotte")
	for item: Dictionary in _marotten_items(res["hits"] as Array):
		if bool(item["won"]):
			say("marotte_won:" + str(item["id"]))
			Events.toast_requested.emit("Wette gewonnen: %s! Ein Fanpost-Paket ist unterwegs." % str(item["name"]),
				&"marotte")
		else:
			say("marotte_hit:" + str(item["id"]))
			Events.toast_requested.emit("M.O.D. mag das: %s (%d/%d)" % [str(item["name"]), int(item["hits"]),
				int(item["goal"])], &"marotte")


## Floor done: the Liga floor bonus (box + show_bet "floor"), then the lines: a whole Duo-Liga floor, one sulk for
## missed preferences, and the Liga hint at the end of floor 1 for those who never tried it (06 §4.3).
func _marotten_floor_end(floor_index: int) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var res: Dictionary = MarottenRules.on_floor_end(st, DB.data, floor_index, _marotten_rules())
	for box: Variant in (res["boxes"] as Array):
		st.pending_lootboxes.append(str(box))
		Events.lootbox_earned.emit(str(box))
	for p: Variant in (res["show_bet"] as Array):
		trigger("show_bet", p as Dictionary)
	if Game.replaying:
		return
	if int(res["floor_tier"]) == 2 and int(res["battles"]) >= MarottenRules.DUO_FLOOR_MIN_BATTLES:
		say("liga_floor")
	elif not (res["missed"] as Array).is_empty():
		say("marotte_missed")
	if floor_index == 1 and int(res["liga_battles"]) == 0 and MarottenRules.liga_enabled(_marotten_rules()):
		say("liga_hint")


## Hit ids → [{"id", "name", "hits", "goal", "won"}] with the current hearts.
func _marotten_items(ids: Array) -> Array:
	var out: Array = []
	var st: GameState = Game.state
	var m: Dictionary = st.show.marotten if st != null and st.show != null else {}
	var hits: Dictionary = m.get("hits", {}) if m.get("hits", {}) is Dictionary else {}
	var won: PackedStringArray = JsonUtil.to_str_array(m.get("won", []))
	for id: Variant in ids:
		var sid: String = str(id)
		if not DB.data.has_id("marotten", sid):
			continue
		var def: MarotteDef = DB.data.marotte(sid)
		out.append({"id": sid, "name": tr(def.name), "hits": mini(int(hits.get(sid, 0)), def.goal), "goal": def.goal,
			"won": won.has(sid)})
	return out


## Liga lines once per floor (presentation only) + a toast with the rule in its one sentence (06 §0.5).
func _liga_line(tag: String, tier: int) -> void:
	if Game.replaying:
		return
	var key: String = "%d:%s" % [_floor_index(), tag.get_slice(":", 0) + str(tier)]
	if _liga_said.has(key):
		return
	_liga_said[key] = true
	say(tag)
	if tier <= 0:
		return
	var who: String = "Beide ohne" if tier == 2 else "Ohne"
	var text: String = "%s Rüstung & ohne Accessoire" % who
	if MarottenRules.rewards_on(_marotten_rules()):
		text += ": Hype ×%s · Follower ×%s" % [pm_text(MarottenRules.liga_pm(DB.data, tier, &"hype")),
			pm_text(MarottenRules.liga_pm(DB.data, tier, &"follower"))]
	Events.toast_requested.emit(text, &"liga_duo" if tier == 2 else &"liga")


## 1250 → "1,25", 1500 → "1,5", 1000 → "1" (German decimal comma, trailing zeros dropped).
static func pm_text(pm: int) -> String:
	var whole: int = pm / 1000
	var frac: int = pm % 1000
	if frac == 0:
		return str(whole)
	var f: String = ("%03d" % frac).rstrip("0")
	return "%d,%s" % [whole, f]
