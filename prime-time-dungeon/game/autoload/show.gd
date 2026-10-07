extends Node
## Autoload `Show` (02_TECH §3.5): hype/viewers/followers, achievements, sponsors, M.O.D.
##
## State lives only in Game.state.show (ShowState) — plus the volatile battle context (`_rules`, gift queue,
## thresholds) and two RNGs: `_rng` (game logic, ONLY sponsor selection, seeded Game.next_seed("show") in
## begin_battle) and `_fx_rng` (chat, viewer noise, M.O.D. line choice; never game-relevant).
## Every game-relevant change happens synchronously in the calling method (never in _process), so replays
## (Game.replay_log) reproduce it exactly; while Game.replaying only pure presentation (lines, chat) is skipped.
##
## Hype is kept in whole points: positive gains are scaled by hype_gain_mult in integer per-mille and rounded half
## up (deterministic, integral state hash, 05 §3.3 Nr. 5/9).

const CHAT_MIN_INTERVAL: float = 2.5         # GDD §7.5: max. 1 chat line per 2.5 s
const CHAT_INTERVAL: float = 6.0             # exploration chat every 6 ± 2 s by hype band
const CHAT_JITTER: float = 2.0
const CHAT_BAND_HIGH: float = 70.0
const CHAT_BAND_LOW: float = 30.0
const DISPLAY_SMOOTH_SEC: float = 1.5        # display viewers: 1 - exp(-delta / 1.5)
const NOISE_INTERVAL: float = 2.0            # display noise ±1.5 % every 2 s
const NOISE_PCT: float = 0.015
const PRIORITY_WINDOW_SEC: float = 3.0       # a line of lower priority is dropped while a higher one is this fresh
const HYPE_ACHIEVEMENT: float = 8.0
const HYPE_CHEST: float = 3.0
const HYPE_EVENT: float = 5.0
const HYPE_TIMER_300: float = 10.0
const HYPE_TIMER_60: float = 15.0
const ACH_FOLLOWERS: Dictionary = {"box_bronze": 25, "box_silver": 50, "box_gold": 100}
const MAX_EXTERNAL_PER_BATTLE: int = 1       # 05 §6.10; further external gifts wait for the end of the battle
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
var _battle_n: int = 0                       # deterministic battle number for system gift ids (Game.next_seed index)
var _gift_k: int = 0
var _fired: PackedInt32Array = []            # thresholds crossed in this battle
var _open_thresholds: PackedInt32Array = []  # crossed thresholds whose system gift is still due
var _gifts_given: int = 0                    # gifts delivered in this battle (system + external)
var _external_given: int = 0
var _peak_battle: int = 0                    # viewers_peak_battle (noise-free maximum)
var _unlocked_battle: PackedStringArray = []
var _first_fight_said: bool = false
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
	Events.new_game_started.connect(_on_new_run)
	Events.game_loaded.connect(_on_new_run)


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


## amount > 0 → × hype_gain_mult (equipment); clamp 0..100; emits hype_changed.
func add_hype(amount: float, reason: StringName = &"") -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	var points: int = roundi(amount)
	if points > 0:
		var mult_pm: int = roundi(st.hype_gain_mult(DB.data) * 1000.0)
		points = (points * mult_pm + 500) / 1000
	if points == 0:
		return
	_set_hype(ShowModel.clamp_hype(st.show.hype + points), reason)


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
## Lines of lower priority are dropped while a higher-priority line is fresh (PRIORITY_WINDOW_SEC).
func say(tag: String, ctx: Dictionary = {}, blocking: bool = false) -> String:
	if Game.replaying or tag == "":
		return ""
	var prio: int = ModAnnouncer.priority(tag)
	if _now - _last_line_at < PRIORITY_WINDOW_SEC and prio < _last_line_prio:
		return ""
	var line: ModLineDef = _get_announcer().pick(tag, _floor_index(), hype(), _now)
	if line == null:
		return ""
	var text: String = _get_announcer().format(line, _full_ctx(ctx))
	_last_line_prio = prio
	_last_line_at = _now
	Events.mod_said.emit(text, StringName(line.voice), tag, blocking)
	return text


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


## hype := Balance.HYPE_START (30); say("floor_start").
func start_floor(floor_index: int) -> void:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return
	_set_hype(ShowModel.HYPE_START, &"floor_start")
	_update_viewers(true)
	_check_milestones()
	say("floor_start", {"floor": floor_index})


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
	_gift_k = 0
	_fired = PackedInt32Array()
	_open_thresholds = PackedInt32Array()
	_gifts_given = 0
	_external_given = 0
	_unlocked_battle = PackedStringArray()
	_battle_active = true
	_peak_battle = viewers()
	set_stat("explore_seconds_since_battle", 0)
	if setup.advantage == BattleSetup.Advantage.PREEMPTIVE:
		bump_stat("preemptives")
	trigger("battle_started", {"encounter_id": setup.encounter_id, "encounter_type": _encounter_type(setup.advantage),
		"is_boss": setup.is_boss})
	if not _first_fight_said and st.show.stats.get("battles_won", 0) == 0 and st.show.stats.get("battles_fled", 0) == 0:
		_first_fight_said = true
		say("first_fight")


func on_battle_event(e: ActionEvent) -> void:
	if e == null or _rules == null:
		return
	_apply_delta(_rules.feed(e))
	if e.type == ActionEvent.Type.MOD_LINE and e.text != "":
		say(e.text)


## THE single gift entry (Brief §6b.4) → {"accepted": bool, "reason": String} (+ "ok", "gift_id", "apply": "now" |
## "queued", 05 §6.5). In battle (Game.in_battle) accepted gifts wait in the queue (take_pending_gift); outside they
## are applied at once (external gifts recorded as {"t": "gift"} at that moment).
func receive_gift(gift: Dictionary) -> Dictionary:
	var g: Dictionary = gift.duplicate(true)
	var gid: String = str(g.get("gift_id", ""))
	var st: GameState = Game.state
	if st == null:
		return _rejected(gid, "run_not_active")
	var reason: String = Gift.validate(g)
	if reason != "":
		return _rejected(gid, reason)
	if not _is_system(g):
		if _is_duplicate(gid):
			return _rejected(gid, "duplicate")
		reason = GiftPolicy.check(_live_counters(st), g, _event_rules())
		if reason != "":
			return _rejected(gid, reason)
	if Game.in_battle:
		_queue.append(g)
		return _accepted(gid, "queued")
	_apply_outside(g)
	return _accepted(gid, "now")


## {} = none; battle gives the party situation for weight_mods. (1) first waiting external gift (recorded now),
## else (2) an open hype threshold → SponsorSystem.pick → Gift.make_system → receive_gift → returned.
## The controller applies the result with battle.apply_gift.
func take_pending_gift(battle: BattleState = null) -> Dictionary:
	var st: GameState = Game.state
	if st == null or st.show == null:
		return {}
	if _gifts_given < _max_gifts() and _external_given < MAX_EXTERNAL_PER_BATTLE:
		for i in _queue.size():
			var ext: Dictionary = _queue[i]
			if _is_system(ext):
				continue
			_queue.remove_at(i)
			Game.record({"t": "gift", "gift": ext})
			_remember_gift(str(ext.get("gift_id", "")))
			_gifts_given += 1
			_external_given += 1
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
		if t == SponsorSystem.THRESHOLDS[SponsorSystem.THRESHOLDS.size() - 1] and hype() > SponsorSystem.HYPE_AFTER_TOP:
			_set_hype(SponsorSystem.HYPE_AFTER_TOP, &"sponsor")
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
	var enc_type: String = _encounter_type(result.advantage)
	match result.outcome:
		BattleResult.Outcome.VICTORY:
			if _rules != null:
				_apply_delta(_rules.end_delta(result))
			bump_stat("battles_won")
			if result.advantage == BattleSetup.Advantage.AMBUSH:
				bump_stat("ambushes_won")
			var peak: int = maxi(_peak_battle, viewers())
			gained = ShowModel.followers_for_battle(peak, hype(), result.is_boss, st.follower_mult(DB.data))
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
		BattleResult.Outcome.FLED:
			bump_stat("battles_fled")
			var lost: int = ShowModel.followers_lost_on_flee(st.show.followers)
			add_followers(-lost, &"flee")
			gained = -lost
			var fled_payload: Dictionary = {"encounter_id": result.encounter_id, "is_boss": result.is_boss}
			Events.battle_fled.emit(fled_payload)
			trigger("battle_fled", fled_payload)
	# Thresholds crossed by the last action can no longer be served (no turn boundary left); crossing 100 still
	# resets hype to 80.
	var top: int = SponsorSystem.THRESHOLDS[SponsorSystem.THRESHOLDS.size() - 1]
	if _open_thresholds.has(top) and hype() > SponsorSystem.HYPE_AFTER_TOP:
		_set_hype(SponsorSystem.HYPE_AFTER_TOP, &"sponsor")
	var waiting: Array[Dictionary] = _queue.duplicate()
	_reset_battle()
	for g: Dictionary in waiting:
		if not _is_system(g):
			_apply_outside(g)
	return gained


func unlocked_this_battle() -> PackedStringArray:
	return _unlocked_battle.duplicate()


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
	if _battle_active and now > prev:
		_check_thresholds(prev, now)
	_update_viewers(false)


## Upward threshold crossings in battle: a system gift is due while fewer than max gifts were (or will be) given;
## without gift the top threshold still resets hype to 80.
func _check_thresholds(prev: float, now: float) -> void:
	var top: int = SponsorSystem.THRESHOLDS[SponsorSystem.THRESHOLDS.size() - 1]
	for t: int in SponsorSystem.crossed(prev, now, _fired):
		_fired.append(t)
		if _gifts_given + _open_thresholds.size() < _max_gifts():
			_open_thresholds.append(t)
		elif t == top and hype() > SponsorSystem.HYPE_AFTER_TOP:
			_set_hype(SponsorSystem.HYPE_AFTER_TOP, &"sponsor")


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
	if d.hype != 0.0:
		add_hype(d.hype, d.reasons[0] if not d.reasons.is_empty() else &"battle")
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
		_remember_gift(str(g.get("gift_id", "")))
	var rng: RandomNumberGenerator = SeedUtil.make_rng(Game.next_seed("gift"))
	var rewards: Array[LootReward] = GiftApplier.apply(st, DB.data, g, rng)
	if not rewards.is_empty():
		Game.add_rewards(rewards)
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
		var tag: String = "gift_received:credits" if kind == "gold" else ("gift_received:anon" if anon else "gift_received")
		say(tag)
	Events.gift_received.emit(g)


## Gift.make_system with a schema-complete local fallback (05 §6.5) while the M8 builder returns nothing.
func _system_gift(sponsor_id: String) -> Dictionary:
	var k: int = _gift_k
	_gift_k += 1
	var g: Dictionary = Gift.make_system(sponsor_id, _battle_n, k)
	if not g.is_empty():
		return g
	return {
		"schema": 1, "gift_id": "g_sys_%d_%d" % [_battle_n, k], "source": "system", "kind": "sponsor_buff",
		"tier": "", "amount": 0, "sponsor_id": sponsor_id,
		"sender": {"display_name": "", "anon": true, "sender_ref": ""}, "message_key": "",
		"target": {"player_id": "local", "run_id": ""}, "event_id": "", "window_id": "", "league": "pur",
		"effect_pm": 1000, "load_half": 0, "roll": {}, "contents": [], "run_bound": true, "deliver_by_tick": 0,
		"issued_at": "", "payload": {},
	}


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


## Records an applied external gift id (reaction at application time; replays reach the same state).
func _remember_gift(gift_id: String) -> void:
	var st: GameState = Game.state
	if st == null or gift_id == "":
		return
	if not (st.flags.get("live", null) is Dictionary):
		st.flags["live"] = {}
	var live: Dictionary = st.flags["live"]
	if not (live.get("gift_ids", null) is Array):
		live["gift_ids"] = []
	(live["gift_ids"] as Array).append(gift_id)


static func _live_counters(st: GameState) -> Dictionary:
	if st == null:
		return {}
	var live: Variant = st.flags.get("live", {})
	return live if live is Dictionary else {}


## Event-run gift rules (05 §6.10) if Game exposes them; campaign → {}.
func _event_rules() -> Dictionary:
	if Game.has_method("event_rules"):
		var rules: Variant = Game.call("event_rules")
		if rules is Dictionary:
			return rules
	return {}


static func _is_system(g: Dictionary) -> bool:
	return str(g.get("source", "")) == "system"


func _accepted(gift_id: String, apply: String) -> Dictionary:
	return {"accepted": true, "ok": true, "reason": "", "gift_id": gift_id, "apply": apply}


func _rejected(gift_id: String, reason: String) -> Dictionary:
	Events.gift_rejected.emit(gift_id, reason)
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
	_battle_active = false
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


func _on_sponsor_gift_triggered(sponsor_id: String) -> void:
	bump_stat("sponsor_gifts")
	trigger("sponsor_gift", {"sponsor_id": sponsor_id})


## New game / loaded save: fresh battle context, fresh presentation pacing (cooldowns, chat spacing).
func _on_new_run(_slot: int) -> void:
	_reset_battle()
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


static func _encounter_type(advantage: int) -> String:
	match advantage:
		BattleSetup.Advantage.PREEMPTIVE:
			return "preemptive"
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
