class_name SdDuel extends RefCounted
## One Stempelduell (10 §1, §6.5): an unchanged BattleState (the CTB engine) plus decks, hands and discard piles.
## Deterministic: same SdSetup + same moves → same events and the same state_hash(). No autoloads, no SceneTree, no
## clock; random only in the shuffle (stream "sd_deck"), the start numbers (engine "ctb"), show cards (engine
## "action") and the opponent's weighted card choice (engine "ai").
##
## How the duel talks to the engine (without a line of engine code):
##   setup   party = one Combatant "p0" (Geduld, Tempo 10, STR/MAG/DEF/RES 1, attack skl_sd_none, no names), the
##           opponent enm_<id> (the Lernduell: enm_sd_lernduell, PREEMPTIVE, tutorial, enemy_dmg_mult 0.5); both decks
##           sorted, then shuffled (Fisher-Yates, SeedUtil.derive(seed, "sd_deck", side × 1000 + k), randi_range
##           only; the Lernduell keeps its fixed order), five cards each, then battle.start()
##   hand    = the skill list: after every change each side's `skills` = its non-show hand cards (skl_sdc_*, without
##           duplicates, hand order) and `stunts` = its show cards, so available_commands, validate and EnemyAI (which
##           only draws usable_skills) see exactly the hand
##   move    {"op": "play", "slot": i} → BattleCommand.skill / stunt with the automatic target (the other side or
##           oneself); {"op": "file", "slot": i} → BattleCommand.defend ("Abheften", rank 2, half Ärger until the next
##           own number) + the card swapped; {"op": "forfeit"} (player only) ends the duel. Afterwards the card goes
##           to the discard pile and one card is drawn (empty pile: the discard pile is shuffled into a new one); the
##           Umlaufmappe discards the whole hand and draws a new one
##   AI      the opponent: battle.choose_ai_command() — EnemyAI on the synced hand; its fallback ATTACK becomes filing
##           with the hand card of the smallest AI weight (ties: the leftmost); the player: SdAi.suggest (hint, auto,
##           harness "gut") or AutoPolicy (harness "einfach", auto_policy_move)
##   end     battle finished → WON / LOST; ticket number `dienstschluss` (80) called → ADJOURNED (Dienstschluss:
##           vertagt, number 80 is not served any more); forfeit → FORFEIT
## Events: SdEvent (ENGINE wraps the engine's ActionEvents; card events in between: the played / filed card before the
## action, the draws after the actor's TURN_END, before the next turn's events). The duel sends no battle signals.

const SD_VERSION: int = 1
const SNAPSHOT_VERSION: int = 1
const PLAYER_ID: String = "p0"
const OPPONENT_ID: String = "e0"
const ORDER_LENGTH: int = 12               # numbers the display gets (desktop shows 10, touch 8; 10 §4.3)
const STATUS_WIEDERVORLAGE: String = "sts_sd_wiedervorlage"

enum Side { PLAYER, OPPONENT }
enum Result { RUNNING, WON, LOST, ADJOURNED, FORFEIT }
const RESULT_NAMES: PackedStringArray = ["running", "won", "lost", "adjourned", "forfeit"]

var setup: SdSetup = null
var book: SdRulebook = null
var battle: BattleState = null
var decks: Array[PackedStringArray] = []    # [player, opponent], index 0 = top of the pile
var hands: Array[PackedStringArray] = []    # slot = index; a drawn card goes to the right end
var discards: Array[PackedStringArray] = []
var shuffles: PackedInt32Array = PackedInt32Array([0, 0])   # per side; stream "sd_deck"
var result: SdDuel.Result = Result.RUNNING
var started: bool = false
var moves: int = 0                          # submitted moves of both sides
## Counters for the summary and the Dienstauszeichnungen (ints only, part of snapshot and hash): played / filed /
## wiedervorlagen / max_chain per side, show_ok, show_fail, durchsage_filed (Durchsagen that hit the filing player),
## run_side / run (the current chain of numbers of one side; 2 = the Durchsage), def (the player is filing).
var stats: Dictionary = {}


func _init(p_setup: SdSetup, p_book: SdRulebook) -> void:
	setup = p_setup if p_setup != null else SdSetup.new()
	book = p_book
	for _i in 2:
		decks.append(PackedStringArray())
		hands.append(PackedStringArray())
		discards.append(PackedStringArray())
	stats = _new_stats()
	battle = BattleState.new(_battle_setup(), book.data if book != null else null)


## Shuffles, deals five cards each and starts the engine (BATTLE_START, CTB_ORDER, the first TURN_START). A setup
## with a problem (SdSetup.problem: other rules, unknown opponent, deck rules) does not start ([]).
func start() -> Array[SdEvent]:
	var out: Array[SdEvent] = []
	var problem: String = setup.problem(book) if not started else "already started"
	if problem != "":
		push_warning("SdDuel.start: %s" % problem)
		return out
	started = true
	if setup.tutorial:
		decks[Side.PLAYER] = JsonUtil.to_str_array(book.tutorial.get("player_deck", []))
		decks[Side.OPPONENT] = JsonUtil.to_str_array(book.tutorial.get("opponent_deck", []))
	else:
		var mine: PackedStringArray = setup.player_deck.duplicate()
		mine.sort()
		decks[Side.PLAYER] = mine
		var opp: SdOpponentDef = book.opponent(setup.opponent_id)
		decks[Side.OPPONENT] = opp.deck_list() if opp != null else PackedStringArray()
		_shuffle(Side.PLAYER)
		_shuffle(Side.OPPONENT)
	for side: int in [Side.PLAYER, Side.OPPONENT]:
		for _i in book.hand_size():
			_draw(side, out)
	var evs: Array[ActionEvent] = battle.start()
	_sync()
	_track(evs)
	for e: ActionEvent in evs:
		out.append(SdEvent.wrap(e))
	_check_end(out)
	return out


## Side of the unit whose number is called (Side value), -1 when the duel is over or not started.
func side_to_move() -> int:
	if not started or result != Result.RUNNING:
		return -1
	var a: Combatant = battle.current_actor()
	if a == null:
		return -1
	return Side.PLAYER if a.is_party() else Side.OPPONENT


func is_finished() -> bool:
	return started and result != Result.RUNNING


## Every legal move of the side to move: play and file for each hand slot, "forfeit" for the player. The Lernduell
## allows only the scripted move at a forced number (forced_move).
func legal_moves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var side: int = side_to_move()
	if side < 0:
		return out
	for op: String in ["play", "file"]:
		for slot in hands[side].size():
			var m: Dictionary = {"op": op, "slot": slot}
			if validate(m) == "":
				out.append(m)
	if side == Side.PLAYER:
		out.append({"op": "forfeit"})
	return out


## "" if `move` may be submitted now, else the reason (English, for logs). Extra keys ("a": auto marker, "hint") are
## ignored.
func validate(move: Dictionary) -> String:
	if not started:
		return "the duel has not started"
	if result != Result.RUNNING:
		return "the duel is over"
	var side: int = side_to_move()
	if side < 0:
		return "nobody is to move"
	var op: String = str(move.get("op", ""))
	if op == "forfeit":
		return "" if side == Side.PLAYER else "only the player forfeits, on the player's turn"
	if op != "play" and op != "file":
		return "unknown op '%s'" % op
	if not JsonUtil.is_integral(move.get("slot", null)):
		return "slot missing"
	var slot: int = int(move["slot"])
	if slot < 0 or slot >= hands[side].size():
		return "slot %d outside the hand (%d cards)" % [slot, hands[side].size()]
	var forced: Dictionary = forced_move()
	if not forced.is_empty():
		if op != str(forced["op"]):
			return "the Lernduell asks for '%s' at number %d" % [str(forced["op"]), ticket()]
		if op == "play" and hands[side][slot] != str(forced["card"]):
			return "the Lernduell asks for %s at number %d" % [str(forced["card"]), ticket()]
	var cmd: BattleCommand = _command(side, op, slot)
	if cmd == null:
		return "unknown card '%s'" % hands[side][slot]
	return battle.validate(cmd)


## Plays `move` for the side to move (player input, AI move or auto move). An invalid move changes nothing ([]).
func submit(move: Dictionary) -> Array[SdEvent]:
	var out: Array[SdEvent] = []
	var reason: String = validate(move)
	if reason != "":
		push_warning("SdDuel.submit: move %s rejected (%s)" % [str(move), reason])
		return out
	var side: int = side_to_move()
	var op: String = str(move["op"])
	moves += 1
	if op == "forfeit":
		result = Result.FORFEIT
		out.append(SdEvent.make(SdEvent.Kind.DUEL_END, -1, -1, "", int(result)))
		return out
	var slot: int = int(move["slot"])
	var card_id: String = hands[side][slot]
	var actor: Combatant = _actor(side)
	var cmd: BattleCommand = _command(side, op, slot)
	var kind: SdEvent.Kind = SdEvent.Kind.CARD_PLAYED if op == "play" else SdEvent.Kind.CARD_FILED
	out.append(SdEvent.make(kind, side, slot, card_id))
	var evs: Array[ActionEvent] = battle.submit(cmd)
	var split: int = _after_turn_end(evs, actor.id)
	for i in split:
		out.append(SdEvent.wrap(evs[i]))
	var hand: PackedStringArray = hands[side]
	hand.remove_at(slot)
	hands[side] = hand
	_discard(side, card_id)
	if not battle.is_finished():
		var c: SdCardDef = book.card(card_id)
		if op == "play" and c != null and c.hand == "refresh":
			var rest: PackedStringArray = hands[side]
			for cid: String in rest:
				_discard(side, cid)
			hands[side] = PackedStringArray()
			out.append(SdEvent.make(SdEvent.Kind.HAND_REFRESHED, side, -1, "", rest.size()))
			for _i in book.hand_size():
				_draw(side, out)
		else:
			_draw(side, out)
	_sync()
	var key: String = "played" if op == "play" else "filed"
	(stats[key] as Array)[side] = int((stats[key] as Array)[side]) + 1
	_track(evs)
	for i in range(split, evs.size()):
		out.append(SdEvent.wrap(evs[i]))
	_check_end(out)
	return out


## The move of the side to move as its AI makes it: the opponent plays EnemyAI on its hand (fallback: filing with the
## card of the smallest weight), the player gets SdAi.suggest (the Graf's hint). {} when nobody is to move.
func ai_move() -> Dictionary:
	var side: int = side_to_move()
	if side == Side.PLAYER:
		return SdAi.suggest(self)
	if side == Side.OPPONENT:
		return opponent_move()
	return {}


## EnemyAI's choice for the opponent as a duel move (pure: the engine reseeds its AI stream for every call).
func opponent_move() -> Dictionary:
	if side_to_move() != Side.OPPONENT:
		return {}
	var cmd: BattleCommand = battle.choose_ai_command()
	if cmd != null and cmd.kind == BattleCommand.Kind.SKILL:
		var slot: int = hands[Side.OPPONENT].find(book.card_of_skill(cmd.skill_id))
		if slot >= 0:
			return {"op": "play", "slot": slot}
	return {"op": "file", "slot": lowest_weight_slot()}


## The engine's AutoPolicy for the player as a duel move (harness profile "einfach", 10 §3.6): a heal or damage skill
## becomes playing that card, DEFEND / ATTACK become filing (SdAi.discard_slot). A forced Lernduell move wins.
func auto_policy_move() -> Dictionary:
	if side_to_move() != Side.PLAYER:
		return {}
	var forced: Dictionary = SdAi.forced(self)
	if not forced.is_empty():
		return forced
	var cmd: BattleCommand = battle.choose_ai_command()
	if cmd != null and (cmd.kind == BattleCommand.Kind.SKILL or cmd.kind == BattleCommand.Kind.STUNT):
		var slot: int = hands[Side.PLAYER].find(book.card_of_skill(cmd.skill_id))
		if slot >= 0:
			return {"op": "play", "slot": slot}
	return {"op": "file", "slot": SdAi.discard_slot(self, Side.PLAYER)}


## The opponent's hand slot with the smallest AI weight (a card's weight: the largest weight of its entries in the
## current action list, conditions ignored; no entry = 0); ties: the leftmost (10 §3.6).
func lowest_weight_slot() -> int:
	var actor: Combatant = _actor(Side.OPPONENT)
	var weights: Dictionary = {}
	for a: Variant in EnemyAI.actions_of(actor):
		if a is Dictionary:
			var cid: String = book.card_of_skill(str((a as Dictionary).get("skill", "")))
			weights[cid] = maxi(int(weights.get(cid, 0)), JsonUtil.to_int((a as Dictionary).get("weight", 1), 1))
	var best: int = 0
	var hand: PackedStringArray = hands[Side.OPPONENT]
	for i in hand.size():
		if int(weights.get(hand[i], 0)) < int(weights.get(hand[best], 0)):
			best = i
	return best


## Dry run of `move` on a copy of the battle (BattleState.from_dict(to_dict()), 10 §6.5 Nr. 5) — the duel and its hash
## stay untouched. {} for show cards (the dry run would reveal their dice), forfeit and illegal moves. Else
## {"order": the next ORDER_LENGTH numbers as combatant ids from the mover (index 0) — numbers the dry run calls on its
## way (the Durchsage, the other side) included; behind the other side's next number it is a forecast with rank 3,
## 10 §1.2 —, "geduld": [player, opponent] after the move, "delta": [player, opponent] change, "weak" / "resist" /
## "immune": Zuständigkeit of the move's Ärger, "blocked": status ids that did not take (Wiedervorlage "nicht doppelt",
## immunity), "ends": the move ends the duel}.
func preview(move: Dictionary) -> Dictionary:
	if validate(move) != "":
		return {}
	var op: String = str(move["op"])
	if op == "forfeit":
		return {}
	var side: int = side_to_move()
	var slot: int = int(move["slot"])
	var c: SdCardDef = book.card(hands[side][slot])
	if op == "play" and (c == null or c.show):
		return {}
	var copy: BattleState = BattleState.from_dict(battle.to_dict(), book.data)
	var actor_id: String = _actor(side).id
	var before: Array[int] = _geduld_of(copy)
	var evs: Array[ActionEvent] = copy.submit(_command(side, op, slot))
	var after: Array[int] = _geduld_of(copy)
	var order: PackedStringArray = PackedStringArray([actor_id])
	var split: int = _after_turn_end(evs, actor_id)
	var weak: bool = false
	var resist: bool = false
	var immune: bool = false
	var blocked: PackedStringArray = []
	for i in evs.size():
		var e: ActionEvent = evs[i]
		if i >= split and e.type == ActionEvent.Type.TURN_START:
			order.append(e.actor_id)
		if i < split and e.type == ActionEvent.Type.DAMAGE and e.actor_id == actor_id:
			weak = weak or e.weak
			resist = resist or e.resist
			immune = immune or e.immune
		if i < split and e.type == ActionEvent.Type.STATUS_BLOCKED:
			blocked.append(e.status_id)
	var rest: PackedStringArray = copy.preview_order(ORDER_LENGTH)
	for i in range(1, rest.size()):
		if order.size() >= ORDER_LENGTH:
			break
		order.append(rest[i])
	return {"order": order, "geduld": after, "delta": [after[0] - before[0], after[1] - before[1]], "weak": weak,
		"resist": resist, "immune": immune, "blocked": blocked, "ends": copy.is_finished()}


# --- read access for the presentation, AI and tests -----------------------------------------------------------------

## The number now called (JETZT 007; BattleState.turn_count: every call counts, the Durchsage's too, from 1).
func ticket() -> int:
	return battle.turn_count


## The next `count` numbers as combatant ids (index 0 = the unit now called; later ones a forecast with rank 3).
func order(count: int = ORDER_LENGTH) -> PackedStringArray:
	return battle.preview_order(count)


## Side of a combatant id ("p…" player, "e…" opponent), -1 for the Durchsage ("u…") and unknown ids.
static func side_of(combatant_id: String) -> int:
	if combatant_id.begins_with("p"):
		return Side.PLAYER
	if combatant_id.begins_with("e"):
		return Side.OPPONENT
	return -1


func combatant(side: int) -> Combatant:
	return _actor(side)


func geduld(side: int) -> int:
	var c: Combatant = _actor(side)
	return maxi(0, c.hp) if c != null else 0


func max_geduld(side: int) -> int:
	var c: Combatant = _actor(side)
	return c.max_hp() if c != null else 0


func hand(side: int) -> PackedStringArray:
	return hands[side].duplicate()


## True from the warning number on (10 §1.8: "Dienstschluss bei Nummer 80" from number 60).
func dienstschluss_near() -> bool:
	return ticket() >= book.constant("dienstschluss_warn")


## The scripted move of the Lernduell at the current number ({"op": "play", "card": id, "step": n} or
## {"op": "file", "step": n}); {} outside the Lernduell, at free numbers and on the opponent's turn.
func forced_move() -> Dictionary:
	if not setup.tutorial or side_to_move() != Side.PLAYER:
		return {}
	for l: Variant in book.tutorial.get("lessons", []):
		var ld: Dictionary = l
		if JsonUtil.to_int(ld.get("ticket", 0)) == ticket() and str(ld.get("move", "")) != "":
			return {"op": str(ld["move"]), "card": str(ld.get("card", "")), "step": JsonUtil.to_int(ld.get("step", 0))}
	return {}


## The Lernduell's lessons at the current number (rules.json → tutorial.lessons entries; [] outside it).
func lessons_now() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not setup.tutorial or not started:
		return out
	for l: Variant in book.tutorial.get("lessons", []):
		if JsonUtil.to_int((l as Dictionary).get("ticket", 0)) == ticket():
			out.append((l as Dictionary).duplicate(true))
	return out


## Numbers in a row of the side now called (the chain of 10 §4.3: "3 × SIE").
func chain() -> int:
	return int(stats["run"])


## End-of-duel facts for the result panel, the collection (SdCollection.record_duel) and the harness.
func summary() -> Dictionary:
	return {"opp": setup.opponent_id, "tut": setup.tutorial, "result": RESULT_NAMES[int(result)],
		"tickets": ticket(), "geduld": [geduld(Side.PLAYER), geduld(Side.OPPONENT)],
		"played": (stats["played"] as Array).duplicate(), "filed": (stats["filed"] as Array).duplicate(),
		"show_ok": int(stats["show_ok"]), "show_fail": int(stats["show_fail"]),
		"wiedervorlagen": (stats["wiedervorlagen"] as Array).duplicate(),
		"durchsage_filed": int(stats["durchsage_filed"]), "max_chain": (stats["max_chain"] as Array).duplicate()}


# --- snapshot and hash ------------------------------------------------------------------------------------------------

## Float-free snapshot (05 CR-14): the setup, BattleState.to_dict() and the duel's piles and counters.
func to_dict() -> Dictionary:
	return {"v": SNAPSHOT_VERSION, "sd_version": SD_VERSION, "setup": setup.to_dict(), "battle": battle.to_dict(),
		"decks": _piles_out(decks), "hands": _piles_out(hands), "discards": _piles_out(discards),
		"shuffles": [shuffles[0], shuffles[1]], "result": int(result), "started": started, "moves": moves,
		"stats": stats.duplicate(true)}


## Inverse of to_dict (also after a JSON round trip): the restored duel continues exactly like the original.
static func from_dict(d: Dictionary, p_book: SdRulebook) -> SdDuel:
	var sd: Variant = d.get("setup", {})
	var duel: SdDuel = SdDuel.new(SdSetup.from_dict(sd if sd is Dictionary else {}), p_book)
	var bd: Variant = d.get("battle", {})
	duel.battle = BattleState.from_dict(bd if bd is Dictionary else {}, p_book.data if p_book != null else null)
	duel.decks = _piles_in(d.get("decks", []))
	duel.hands = _piles_in(d.get("hands", []))
	duel.discards = _piles_in(d.get("discards", []))
	var sh: Variant = d.get("shuffles", [0, 0])
	for i in 2:
		duel.shuffles[i] = JsonUtil.to_int((sh as Array)[i]) if sh is Array and (sh as Array).size() > i else 0
	duel.result = clampi(JsonUtil.to_int(d.get("result", 0)), 0, Result.FORFEIT) as SdDuel.Result
	duel.started = bool(d.get("started", false))
	duel.moves = JsonUtil.to_int(d.get("moves", 0))
	var st: Variant = d.get("stats", {})
	duel.stats = _stats_from(st if st is Dictionary else {})
	return duel


## SHA-256 over {"b": StateHash.battle_hash_input(battle) (no display names), "sd": setup, piles, shuffle counters,
## result, moves, counters} (10 §6.6). Named state_hash, not hash (02_TECH §13.1: no built-in function names).
func state_hash() -> String:
	var d: Dictionary = to_dict()
	d.erase("battle")
	return CanonicalJson.sha256_hex({"b": StateHash.battle_hash_input(battle), "sd": d})


# --- internals ------------------------------------------------------------------------------------------------------

func _battle_setup() -> BattleSetup:
	var bs: BattleSetup = BattleSetup.new()
	if book == null:
		return bs
	bs.encounter_id = setup.opponent_id
	bs.enemy_ids = PackedStringArray([book.enemy_id(setup.opponent_id, setup.tutorial)])
	var block: StatBlock = StatBlock.new()
	block.set_stat(StatBlock.Stat.HP, book.constant("player_geduld"))
	block.set_stat(StatBlock.Stat.SPD, book.constant("tempo"))
	for s: StatBlock.Stat in [StatBlock.Stat.STR, StatBlock.Stat.MAG, StatBlock.Stat.DEF, StatBlock.Stat.RES]:
		block.set_stat(s, 1)
	var geduld_max: int = book.constant("player_geduld")
	bs.party.append(Combatant.create_party(null, PLAYER_ID, 0, "", 1, block, geduld_max, 0, PackedStringArray(),
		PackedStringArray(), SdRulebook.BASIC_ATTACK, {}, PackedStringArray(), Elements.PHYSICAL, 0.0))
	bs.advantage = BattleSetup.Advantage.PREEMPTIVE if setup.tutorial else BattleSetup.Advantage.NORMAL
	bs.seed = setup.seed
	bs.can_flee = false
	bs.tutorial = setup.tutorial
	bs.enemy_dmg_mult = float(book.constant("tutorial_dmg_pct")) / 100.0 if setup.tutorial else 1.0
	return bs


func _actor(side: int) -> Combatant:
	return battle.get_combatant(PLAYER_ID if side == Side.PLAYER else OPPONENT_ID)


## The engine command of a move (play: skill or stunt with the automatic target; file: defend).
func _command(side: int, op: String, slot: int) -> BattleCommand:
	var actor: Combatant = _actor(side)
	if actor == null:
		return null
	if op == "file":
		return BattleCommand.defend(actor.id)
	var c: SdCardDef = book.card(hands[side][slot])
	if c == null:
		return null
	var targets: PackedStringArray = battle.valid_targets(actor, c.skill_id())
	var t: PackedStringArray = PackedStringArray([targets[0]]) if not targets.is_empty() else PackedStringArray()
	if c.show:
		return BattleCommand.stunt(actor.id, c.skill_id(), t)
	return BattleCommand.skill(actor.id, c.skill_id(), t)


## Hand = skill list (see the header): skills = non-show hand cards, stunts = show cards, both without duplicates.
func _sync() -> void:
	for side: int in [Side.PLAYER, Side.OPPONENT]:
		var a: Combatant = _actor(side)
		if a == null:
			continue
		var skills: PackedStringArray = []
		var stunts: PackedStringArray = []
		for cid: String in hands[side]:
			var c: SdCardDef = book.card(cid)
			if c == null:
				continue
			if c.show:
				if not stunts.has(c.skill_id()):
					stunts.append(c.skill_id())
			elif not skills.has(c.skill_id()):
				skills.append(c.skill_id())
		a.skills = skills
		a.stunts = stunts


func _draw(side: int, out: Array[SdEvent]) -> void:
	if decks[side].is_empty():
		if discards[side].is_empty():
			return
		decks[side] = discards[side]
		discards[side] = PackedStringArray()
		_shuffle(side)
		out.append(SdEvent.make(SdEvent.Kind.RESHUFFLED, side, -1, "", decks[side].size()))
	var pile: PackedStringArray = decks[side]
	var cid: String = pile[0]
	pile.remove_at(0)
	decks[side] = pile
	var hand: PackedStringArray = hands[side]
	hand.append(cid)
	hands[side] = hand
	out.append(SdEvent.make(SdEvent.Kind.CARD_DRAWN, side, hand.size() - 1, cid if side == Side.PLAYER else ""))


func _discard(side: int, card_id: String) -> void:
	var pile: PackedStringArray = discards[side]
	pile.append(card_id)
	discards[side] = pile


## Fisher-Yates on decks[side] with SeedUtil.derive(seed, "sd_deck", side × 1000 + k), k = this side's shuffle count.
func _shuffle(side: int) -> void:
	var rng: RandomNumberGenerator = SeedUtil.make_rng(SeedUtil.derive(setup.seed, "sd_deck", side * 1000
		+ shuffles[side]))
	shuffles[side] += 1
	var pile: PackedStringArray = decks[side]
	for i in range(pile.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp
	decks[side] = pile


## Index after the actor's TURN_END (the end of its own action) — the card draws go there.
static func _after_turn_end(evs: Array[ActionEvent], actor_id: String) -> int:
	for i in evs.size():
		if evs[i].type == ActionEvent.Type.TURN_END and evs[i].actor_id == actor_id:
			return i + 1
	return evs.size()


func _check_end(out: Array[SdEvent]) -> void:
	if result != Result.RUNNING:
		return
	if battle.is_finished():
		var won: bool = battle.result != null and battle.result.outcome == BattleResult.Outcome.VICTORY
		result = Result.WON if won else Result.LOST
	elif battle.turn_count >= book.constant("dienstschluss"):
		result = Result.ADJOURNED
	if result != Result.RUNNING:
		out.append(SdEvent.make(SdEvent.Kind.DUEL_END, -1, -1, "", int(result)))


static func _geduld_of(b: BattleState) -> Array[int]:
	var out: Array[int] = []
	for id: String in [PLAYER_ID, OPPONENT_ID]:
		var c: Combatant = b.get_combatant(id)
		out.append(maxi(0, c.hp) if c != null else 0)
	return out


static func _piles_out(piles: Array[PackedStringArray]) -> Array:
	return [Array(piles[0]), Array(piles[1])]


static func _piles_in(v: Variant) -> Array[PackedStringArray]:
	var out: Array[PackedStringArray] = []
	for i in 2:
		out.append(JsonUtil.to_str_array((v as Array)[i]) if v is Array and (v as Array).size() > i
			else PackedStringArray())
	return out


## Counters from the engine events of one move (see `stats`).
func _track(evs: Array[ActionEvent]) -> void:
	var turn_side: int = -1
	for e: ActionEvent in evs:
		match e.type:
			ActionEvent.Type.TURN_START:
				var s: int = side_of(e.actor_id)
				turn_side = s
				var run_side: int = s if s >= 0 else 2
				if run_side == int(stats["run_side"]):
					stats["run"] = int(stats["run"]) + 1
				else:
					stats["run_side"] = run_side
					stats["run"] = 1
				if s >= 0:
					(stats["max_chain"] as Array)[s] = maxi(int((stats["max_chain"] as Array)[s]), int(stats["run"]))
				if s == Side.PLAYER:
					stats["def"] = 0
			ActionEvent.Type.DEFEND:
				if e.actor_id == PLAYER_ID:
					stats["def"] = 1
			ActionEvent.Type.DAMAGE:
				if e.target_id == PLAYER_ID and e.actor_id.begins_with("u") and int(stats["def"]) == 1:
					stats["durchsage_filed"] = int(stats["durchsage_filed"]) + 1
			ActionEvent.Type.STUNT_RESULT:
				var key: String = "show_ok" if e.success else "show_fail"
				stats[key] = int(stats[key]) + 1
			ActionEvent.Type.STATUS_ADDED:
				var target_side: int = side_of(e.target_id)
				if e.status_id == STATUS_WIEDERVORLAGE and turn_side >= 0 and target_side >= 0 \
						and target_side != turn_side:
					(stats["wiedervorlagen"] as Array)[turn_side] = int((stats["wiedervorlagen"] as Array)[turn_side]) + 1


static func _new_stats() -> Dictionary:
	return {"played": [0, 0], "filed": [0, 0], "wiedervorlagen": [0, 0], "max_chain": [0, 0], "show_ok": 0,
		"show_fail": 0, "durchsage_filed": 0, "run_side": -1, "run": 0, "def": 0}


static func _stats_from(d: Dictionary) -> Dictionary:
	var out: Dictionary = _new_stats()
	for k: String in out.keys():
		var v: Variant = d.get(k, out[k])
		if out[k] is Array:
			var arr: Array = []
			for i in 2:
				arr.append(JsonUtil.to_int((v as Array)[i]) if v is Array and (v as Array).size() > i else 0)
			out[k] = arr
		else:
			out[k] = JsonUtil.to_int(v, int(out[k]))
	return out
