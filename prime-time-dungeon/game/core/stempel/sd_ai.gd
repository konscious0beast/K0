class_name SdAi extends RefCounted
## The player's adviser (10 §3.6): the Graf's hint (paw), "Der Graf übernimmt" (auto) and the harness profile "gut".
## Pure and deterministic — no dice, integer arithmetic, reads only what the player sees (the own hand, both Geduld
## values and statuses, the ticket display, the opponent's file and deck — never its hand) and returns only legal
## moves (a forced Lernduell move first).
##
## Every hand card is valued as Ärger-equivalents per tick of the own waiting time (10 §3.6: "Ärger bzw. Geduld je
## Werktag plus Tempo-Wert"): Ärger after Zuständigkeiten (capped at the remaining Geduld; a card that ends the duel
## wins outright), time effects in ticks × TICK_VALUE (1 Werktag ≈ 3 Ärger, 10 §2.3: Wiedervorlage, Dienst nach
## Vorschrift — worth most against a Feierabend-Eilvermerk —, Eilvermerk), Kleingedrucktes as its later Ärger, heals
## only by need (the lower the Geduld, the more a point counts), cleansing, the Umlaufmappe when the hand is poor.
## Filing ("Abheften") is valued by the Ärger it halves until the own next number — from the ticket forecast with the
## move applied (Durchsage included) — plus the swapped card. A move that leaves the own Geduld below the Ärger
## expected before the own next number is penalized (keep the initiative, heal or file first).

const FixedMath := preload("res://core/stats/fixed_math.gd")

## Hint tags (lines.json: sd_hint:<reason>, the Graf's footnote for the suggestion).
const HINTS: PackedStringArray = ["kill", "file", "durchsage", "heal", "damage", "tempo", "weak", "status", "counter",
	"refresh", "show", "deck"]
const TICK_VALUE_PM: int = 180              # Ärger per tick in per-mille: 3 Ärger per Werktag (16.7 ticks)
const KILL_SCORE: int = 1000000000
const DANGER_PENALTY_PM: int = 250          # score factor when the move leaves the player exposed to a KO
const FORECAST: int = 8                     # ticket numbers looked at for the incoming Ärger
const URGENCY: Array = [[40, 1000], [60, 600], [80, 250], [101, 60]]   # [Geduld % ≤, per-mille a healed point counts]
const SWAP_VALUE: int = 1500                # milli-Ärger: a filed card swapped for a fresh one
const REFRESH_VALUE: int = 2500             # milli-Ärger: a whole new hand when the current one is poor
const POOR_HAND_PM: int = 90                # best rate (milli-Ärger per tick) below which a hand counts as poor


## The suggested move of the side to move with a "hint" (HINTS entry; "" for a forced Lernduell move) — {} when nobody
## is to move.
static func suggest(duel: SdDuel) -> Dictionary:
	var side: int = duel.side_to_move()
	if side < 0:
		return {}
	var f: Dictionary = forced(duel)
	if not f.is_empty():
		f["hint"] = ""
		return f
	var ctx: Dictionary = _context(duel, side)
	var best: Dictionary = {}
	var best_score: int = -KILL_SCORE
	var hand: PackedStringArray = duel.hands[side]
	var rates: Array[int] = []
	for slot in hand.size():
		var ev: Array = _play_value(duel, ctx, slot)
		rates.append(int(ev[0]))
		if int(ev[0]) > best_score:
			best_score = int(ev[0])
			best = {"op": "play", "slot": slot, "hint": str(ev[1])}
	var file_ev: Array = _file_value(duel, ctx, rates)
	if int(file_ev[0]) > best_score:
		best = {"op": "file", "slot": int(file_ev[2]), "hint": str(file_ev[1])}
	return best


## The forced move of the Lernduell as a legal duel move ({} if none): the leftmost copy of the forced card, or filing
## the card the discard rule picks.
static func forced(duel: SdDuel) -> Dictionary:
	var f: Dictionary = duel.forced_move()
	if f.is_empty():
		return {}
	var side: int = duel.side_to_move()
	if str(f["op"]) == "play":
		return {"op": "play", "slot": duel.hands[side].find(str(f["card"]))}
	return {"op": "file", "slot": discard_slot(duel, side)}


## The hand slot to file (the card worth least now; ties: the leftmost). The player side only uses it — the opponent
## files the card of its smallest AI weight (SdDuel.lowest_weight_slot).
static func discard_slot(duel: SdDuel, side: int) -> int:
	if side != SdDuel.Side.PLAYER:
		return duel.lowest_weight_slot()
	var ctx: Dictionary = _context(duel, side)
	var worst: int = 0
	var worst_score: int = KILL_SCORE
	for slot in duel.hands[side].size():
		var s: int = int(_play_value(duel, ctx, slot)[0])
		if s < worst_score:
			worst_score = s
			worst = slot
	return worst


# --- valuation -----------------------------------------------------------------------------------------------------

## What every valuation of one decision needs.
static func _context(duel: SdDuel, side: int) -> Dictionary:
	var me: Combatant = duel.combatant(side)
	var foe: Combatant = duel.combatant(1 - side)
	return {"side": side, "me": me, "foe": foe, "base": CTBQueue.base_delay(me.stat(StatBlock.Stat.SPD)),
		"foe_hit": _foe_hit(duel, side), "foe_delay": _foe_delay(duel, side)}


## [score (milli-Ärger per tick × 1000), hint] of playing the card in `slot`.
static func _play_value(duel: SdDuel, ctx: Dictionary, slot: int) -> Array:
	var c: SdCardDef = duel.book.card(duel.hands[int(ctx["side"])][slot])
	var me: Combatant = ctx["me"]
	var foe: Combatant = ctx["foe"]
	var base: int = int(ctx["base"])
	var speed: int = _speed_after(duel, me, c)
	var delay: int = maxi(1, FixedMath.div_round(base * c.rank() * speed, 3 * FixedMath.PM))
	var dmg: int = _damage(c, foe)
	if not c.show and dmg >= maxi(1, foe.hp) and dmg > 0:
		return [KILL_SCORE - delay, "kill"]
	var gain: int = mini(dmg, maxi(0, foe.hp)) * FixedMath.PM
	var hint: String = "weak" if dmg > 0 and _mult_pm(foe, c.element()) > FixedMath.PM else "damage"
	if c.show:
		var chance: int = c.chance_pm()
		gain = FixedMath.div_round(gain * chance, FixedMath.PM)
		var fe: Dictionary = c.skill.get("fail_effect", {})
		var fail_self: int = FixedMath.div_round(me.max_hp() * JsonUtil.to_int(fe.get("self_dmg_pct", 0)), 100)
		gain -= FixedMath.div_round(fail_self * (FixedMath.PM - chance), FixedMath.PM) * FixedMath.PM
		delay += FixedMath.div_round(_fail_delay(duel, c, base) * (FixedMath.PM - chance), FixedMath.PM)
		hint = "show"
	var status_gain: Array = _status_value(duel, ctx, c, delay)
	if int(status_gain[0]) > 0:
		gain += int(status_gain[0])
		if dmg == 0 or int(status_gain[0]) > gain / 2:
			hint = str(status_gain[1])
	var heal: int = c.heal()
	if heal > 0:
		var healed: int = mini(heal, me.max_hp() - maxi(0, me.hp))
		gain += healed * _urgency_pm(me)
		if healed * _urgency_pm(me) >= 4 * FixedMath.PM:
			hint = "heal"
	for sid: String in c.cleanses():
		var st: StatusEffect = me.get_status(sid)
		if st != null and st.def != null and st.def.tick_pct < 0:
			gain += st.turns_left * maxi(st.def.tick_min, 1) * FixedMath.PM
	if c.hand == "refresh":
		gain += REFRESH_VALUE if _hand_is_poor(duel, ctx, slot) else 0
		hint = "refresh"
	var score: int = FixedMath.div_round(gain * FixedMath.PM, delay)
	if _exposed(duel, ctx, c, delay):
		score = FixedMath.div_round(score * DANGER_PENALTY_PM, FixedMath.PM) - KILL_SCORE / 1000
	return [score, hint]


## [score, hint, slot] of filing (the slot the discard rule picks).
static func _file_value(duel: SdDuel, ctx: Dictionary, rates: Array[int]) -> Array:
	var me: Combatant = ctx["me"]
	var base: int = int(ctx["base"])
	var delay: int = maxi(1, FixedMath.div_round(base * CTBQueue.RANK_QUICK * me.speed_pm(), 3 * FixedMath.PM))
	var counts: Array[int] = _before_next(duel, ctx, delay, 0)
	var incoming: int = counts[0] * int(ctx["foe_hit"]) + counts[1] * _durchsage_hit(duel, me)
	var saved: int = incoming * FixedMath.PM / 2
	var worst: int = 0
	for i in rates.size():
		if rates[i] < rates[worst]:
			worst = i
	var gain: int = saved + SWAP_VALUE
	var hint: String = "durchsage" if counts[1] > 0 else "file"
	return [FixedMath.div_round(gain * FixedMath.PM, delay), hint, worst]


## [value in milli-Ärger, hint] of the card's statuses.
static func _status_value(duel: SdDuel, ctx: Dictionary, c: SdCardDef, delay: int) -> Array:
	var me: Combatant = ctx["me"]
	var foe: Combatant = ctx["foe"]
	var value: int = 0
	var hint: String = ""
	for sid: String in c.status_ids():
		var def: StatusDef = duel.battle.status_def(sid)
		if def == null:
			continue
		var on_self: bool = c.targets_self()
		var target: Combatant = me if on_self else foe
		if target.status_immune.has(sid):
			continue
		var turns: int = c.status_turns(sid) if c.status_turns(sid) > 0 else def.default_turns
		if def.has_flag("delay_on_apply"):
			if not target.has_status(sid):
				value += CTBQueue.base_delay(target.stat(StatBlock.Stat.SPD)) * TICK_VALUE_PM
				hint = "status"
		elif FixedMath.pm(def.tick_speed_mult) > FixedMath.PM and not on_self:
			var slow_pm: int = FixedMath.pm(def.tick_speed_mult) - FixedMath.PM
			value += (turns - 1) * FixedMath.div_round(int(ctx["foe_delay"]) * slow_pm, FixedMath.PM) * TICK_VALUE_PM
			hint = "status"
			for ex: String in def.excludes:
				var hasted: StatusEffect = target.get_status(ex)
				if hasted != null and hasted.def != null:
					var gone: int = FixedMath.PM - FixedMath.pm(hasted.def.tick_speed_mult)
					value += mini(hasted.turns_left, 6) * FixedMath.div_round(int(ctx["foe_delay"]) * gone,
						FixedMath.PM) * TICK_VALUE_PM
					hint = "counter"
		elif FixedMath.pm(def.tick_speed_mult) < FixedMath.PM and on_self:
			var have: StatusEffect = me.get_status(sid)
			var extra: int = turns - 1 - (have.turns_left if have != null else 0)
			if extra > 0:
				var fast_pm: int = FixedMath.PM - FixedMath.pm(def.tick_speed_mult)
				value += extra * FixedMath.div_round(_my_delay(duel, ctx) * fast_pm, FixedMath.PM) * TICK_VALUE_PM
				hint = "tempo"
		elif def.tick_pct < 0 and not on_self:
			var left: int = target.get_status(sid).turns_left if target.has_status(sid) else 0
			value += maxi(0, turns - left) * maxi(def.tick_min, 1) * FixedMath.PM
			hint = "status"
	return [value, hint]


## Speed (per-mille) of the player's follow-up delay after playing `c`: an Eilvermerk the card gives oneself counts for
## this card already (fresh, 10 §1.6) and removes Dienst nach Vorschrift.
static func _speed_after(duel: SdDuel, me: Combatant, c: SdCardDef) -> int:
	if not c.targets_self():
		return me.speed_pm()
	var speed: int = FixedMath.PM
	var removed: PackedStringArray = []
	var added: Array[StatusDef] = []
	for sid: String in c.status_ids():
		var def: StatusDef = duel.battle.status_def(sid)
		if def != null and FixedMath.pm(def.tick_speed_mult) != FixedMath.PM:
			added.append(def)
			removed.append_array(def.excludes)
			removed.append(sid)
	for st: StatusEffect in me.statuses:
		if st.def != null and not removed.has(st.id()):
			speed = FixedMath.mul_pm(speed, FixedMath.pm(st.def.tick_speed_mult))
	for def: StatusDef in added:
		speed = FixedMath.mul_pm(speed, FixedMath.pm(def.tick_speed_mult))
	return maxi(1, speed)


## Ärger the card deals to `foe` now (Zuständigkeiten and filing included; show cards: on success).
static func _damage(c: SdCardDef, foe: Combatant) -> int:
	if c.power() <= 0:
		return 0
	var one: int = DamageCalc.fixed(foe, c.power(), c.element()).amount
	return one * c.hits()


static func _mult_pm(foe: Combatant, element: String) -> int:
	return Elements.multiplier_pm(foe.element_mods, element)


## Expected extra delay of a show card's Patzer (delay_pct of the base delay, or a Wiedervorlage on oneself).
static func _fail_delay(duel: SdDuel, c: SdCardDef, base: int) -> int:
	var fe: Dictionary = c.skill.get("fail_effect", {})
	var extra: int = FixedMath.div_round(base * JsonUtil.to_int(fe.get("delay_pct", 0)), 100)
	var sid: String = str(fe.get("status", ""))
	var def: StatusDef = duel.battle.status_def(sid) if sid != "" else null
	if def != null and def.has_flag("delay_on_apply"):
		extra += base
	return extra


## Per-mille a healed point counts at the player's Geduld (URGENCY).
static func _urgency_pm(me: Combatant) -> int:
	var pct: int = FixedMath.div_round(maxi(0, me.hp) * 100, maxi(1, me.max_hp()))
	for row: Variant in URGENCY:
		if pct <= int((row as Array)[0]):
			return int((row as Array)[1])
	return 0


## The player's typical delay (rank 3 at the current speed).
static func _my_delay(duel: SdDuel, ctx: Dictionary) -> int:
	var me: Combatant = ctx["me"]
	return CTBQueue.delay_for(me, CTBQueue.RANK_NORMAL)


## Expected Ärger of one action of the other side against the player: the mean over its deck (public in the file;
## heals and time cards count 0), with Zuständigkeiten and the Lernduell's half Ärger.
static func _foe_hit(duel: SdDuel, side: int) -> int:
	var deck: PackedStringArray = []
	if duel.setup.tutorial:
		deck = JsonUtil.to_str_array(duel.book.tutorial.get("opponent_deck", []))
	else:
		var o: SdOpponentDef = duel.book.opponent(duel.setup.opponent_id)
		deck = o.deck_list() if o != null else PackedStringArray()
	if deck.is_empty():
		return 0
	var me: Combatant = duel.combatant(side)
	var mult: float = duel.battle.setup.enemy_dmg_mult if side == SdDuel.Side.PLAYER else 1.0
	var total: int = 0
	for cid: String in deck:
		var c: SdCardDef = duel.book.card(cid)
		if c != null and c.power() > 0:
			total += DamageCalc.fixed(me, c.power(), c.element(), mult).amount * c.hits()
	return FixedMath.div_round(total, deck.size())


## The other side's typical delay (rank 3 at its current speed).
static func _foe_delay(duel: SdDuel, side: int) -> int:
	return CTBQueue.delay_for(duel.combatant(1 - side), CTBQueue.RANK_NORMAL)


## Ärger of the Durchsage on the player (8 % of the full Geduld; filing halves it — the caller halves).
static func _durchsage_hit(duel: SdDuel, me: Combatant) -> int:
	var pct: int = JsonUtil.to_int((duel.book.durchsage.get("action", {}) as Dictionary).get("fixed_pct_maxhp", 0))
	return FixedMath.div_round(me.max_hp() * pct, 100)


## [numbers of the other side, numbers of the Durchsage] before the player's next number when the player waits
## `delay` ticks after this move and the other side `extra` ticks longer (a Wiedervorlage) — the ticket forecast.
static func _before_next(duel: SdDuel, ctx: Dictionary, delay: int, extra: int) -> Array[int]:
	var me: Combatant = ctx["me"]
	var foe: Combatant = ctx["foe"]
	var over: Dictionary = {me.id: delay}
	if extra > 0:
		over[foe.id] = foe.ctb_counter + extra
	var order: PackedStringArray = duel.battle.preview_order(FORECAST, -1, over)
	var out: Array[int] = [0, 0]
	for i in range(1, order.size()):
		if order[i] == me.id:
			break
		if order[i] == foe.id:
			out[0] += 1
		elif order[i].begins_with("u"):
			out[1] += 1
	return out


## The move leaves the player exposed: the Ärger expected before the own next number reaches the Geduld left.
static func _exposed(duel: SdDuel, ctx: Dictionary, c: SdCardDef, delay: int) -> bool:
	var me: Combatant = ctx["me"]
	var foe: Combatant = ctx["foe"]
	var extra: int = 0
	for sid: String in c.status_ids():
		var def: StatusDef = duel.battle.status_def(sid)
		if def != null and def.has_flag("delay_on_apply") and not c.targets_self() and not foe.has_status(sid) \
				and not foe.status_immune.has(sid):
			extra = CTBQueue.base_delay(foe.stat(StatBlock.Stat.SPD))
	var counts: Array[int] = _before_next(duel, ctx, delay, extra)
	var incoming: int = counts[0] * int(ctx["foe_hit"]) * 3 / 2 + counts[1] * _durchsage_hit(duel, me)
	var geduld: int = maxi(0, me.hp) + mini(c.heal(), me.max_hp() - maxi(0, me.hp))
	return incoming > 0 and incoming >= geduld


## The hand is poor: no other card reaches POOR_HAND_PM milli-Ärger per tick.
static func _hand_is_poor(duel: SdDuel, ctx: Dictionary, skip: int) -> bool:
	var hand: PackedStringArray = duel.hands[int(ctx["side"])]
	for slot in hand.size():
		if slot == skip or duel.book.card(hand[slot]).hand == "refresh":
			continue
		if int(_play_value_plain(duel, ctx, slot)) >= POOR_HAND_PM * FixedMath.PM:
			return false
	return true


## The plain rate of a card (Ärger and time effects per tick, no danger check) — used by _hand_is_poor.
static func _play_value_plain(duel: SdDuel, ctx: Dictionary, slot: int) -> int:
	var c: SdCardDef = duel.book.card(duel.hands[int(ctx["side"])][slot])
	var me: Combatant = ctx["me"]
	var foe: Combatant = ctx["foe"]
	var delay: int = maxi(1, FixedMath.div_round(int(ctx["base"]) * c.rank() * _speed_after(duel, me, c),
		3 * FixedMath.PM))
	var gain: int = mini(_damage(c, foe), maxi(0, foe.hp)) * FixedMath.PM
	gain += int(_status_value(duel, ctx, c, delay)[0])
	gain += mini(c.heal(), me.max_hp() - maxi(0, me.hp)) * _urgency_pm(me)
	return FixedMath.div_round(gain * FixedMath.PM, delay)
