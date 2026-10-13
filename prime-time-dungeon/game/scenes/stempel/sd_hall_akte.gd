extends RefCounted
## The Akte of an opponent in the Schalterhalle (10 §4.7): left the file (sd_akte.gd: symbol, Geduld,
## Zuständigkeiten, the one new rule, what the first victory brings, the opponent's Mappe), right "Mappe wählen" —
## Mappe A / B / C with the Aktenschrank's sentence when a Mappe cannot be chosen (SdCollection.deck_problem) —, the
## Graf's tip "Passend zur Akte" (10 §2.6: his line sd_akte:<opponent> and a button that writes the suggestion into
## a copy: the first empty other Mappe, else the next one after a confirmation) and "Duell starten". A locked
## opponent shows the way there instead. Private helper: open(hall, opponent id) → the modal.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdAkte := preload("res://scenes/stempel/sd_akte.gd")
const SdSession := preload("res://scenes/stempel/sd_session.gd")
const SdScreen := preload("res://scenes/stempel/sd_screen.gd")

const MAX_SWAPS: int = 4                            # wanted cards the tip swaps in for weaker ones (besides removals)
const LEFT_W: float = 556.0
const RIGHT_W: float = 480.0


static func open(hall: Node, opp_id: String) -> Node:
	var book: SdRulebook = SdSession.book()
	var c: SdCollection = SdSession.collection()
	var opp: SdOpponentDef = book.opponent(opp_id)
	var m: Node = SdModal.new()
	m.call("setup", "", 0.0, UiTheme.C_ACCENT_2, 0.6, false)
	m.name = "Akte"
	var row: HBoxContainer = UiUtil.hbox(24)
	(m.get("content") as VBoxContainer).add_child(row)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "File"
	scroll.custom_minimum_size = Vector2(LEFT_W, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	row.add_child(scroll)
	var left: VBoxContainer = UiUtil.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left)
	SdAkte.build(left, book, opp, {"first_win": c.wins_against(opp_id) == 0})
	var right: VBoxContainer = UiUtil.vbox(12)
	right.name = "Choice"
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
	row.add_child(right)
	var locked: String = lock_reason(c, book, opp_id)
	if locked != "":
		_head(m, right, "NOCH GESPERRT")
		var why: Label = SdStyle.label(locked, 20, SdStyle.TEXT)
		why.name = "Locked"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size = Vector2(RIGHT_W, 0)
		right.add_child(why)
		hall.add_child(m)
		return m
	_build_choice(hall, m, right, book, c, opp)
	hall.add_child(m)
	return m


## "" when the opponent can be chosen, else the way there ("Erst nach einem Sieg gegen Ulla Umlauf.").
static func lock_reason(c: SdCollection, book: SdRulebook, opp_id: String) -> String:
	if c.is_unlocked(opp_id, book):
		return ""
	if not c.tutorial:
		return "Erst nach dem Lernduell."
	var o: SdOpponentDef = book.opponent(opp_id)
	var pre: SdOpponentDef = book.opponent(o.unlock_after) if o != null else null
	return "Erst nach einem Sieg gegen %s." % (pre.name if pre != null else "das vorige Gegenüber")


static func _build_choice(hall: Node, m: Node, right: VBoxContainer, book: SdRulebook, c: SdCollection,
		opp: SdOpponentDef) -> void:
	var close: Button = _head(m, right, "MAPPE WÄHLEN")
	var mrow: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	mrow.name = "Mappen"
	right.add_child(mrow)
	var group: ButtonGroup = ButtonGroup.new()
	var buttons: Array[Control] = []
	for name: String in SdCollection.MAPPEN:
		var b: Button = UiUtil.button("Mappe " + name.to_upper(), &"ButtonFlat")
		b.name = "Mappe" + name.to_upper()
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiUtil.touch_pad(b)
		mrow.add_child(b)
		buttons.append(b)
	var info: Label = SdStyle.label("", 18, SdStyle.TEXT)
	info.name = "Info"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_child(info)
	var tip: Label = SdStyle.label("", 18, SdStyle.GOLD)
	tip.name = "Tip"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(RIGHT_W, 0)
	right.add_child(tip)
	right.add_child(UiUtil.spacer(0, 0, true))
	var trow: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	right.add_child(trow)
	var take: Button = UiUtil.button("", &"ButtonFlat")
	take.name = "TakeTip"
	take.alignment = HORIZONTAL_ALIGNMENT_CENTER
	take.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(take)
	trow.add_child(take)
	var cab: Button = UiUtil.button("Aktenschrank", &"ButtonFlat")
	cab.name = "Cabinet"
	cab.alignment = HORIZONTAL_ALIGNMENT_CENTER
	cab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiUtil.touch_pad(cab)
	trow.add_child(cab)
	var start: Button = SdScreen.big_button("Duell starten", "Start")
	right.add_child(start)
	var state: Dictionary = {"mappe": c.active}
	var refresh: Callable = func() -> void:
		var name2: String = str(state["mappe"])
		var cards: PackedStringArray = c.deck(name2)
		var problem: String = c.deck_problem(cards, book)
		for b2: Control in buttons:
			(b2 as Button).set_pressed_no_signal(b2.name == "Mappe" + name2.to_upper())
		var head: String = "Mappe %s · %d / %d Karten%s" % [name2.to_upper(), cards.size(), book.deck_size(),
			" · aktive Mappe" if name2 == c.active else ""]
		info.text = head + ("\nNicht wählbar: " + problem if problem != "" else "\nBereit für das Duell.")
		info.add_theme_color_override("font_color", SdStyle.TEXT if problem == "" else SdStyle.DANGER)
		start.disabled = problem != ""
		var sug: PackedStringArray = passend(c, book, opp, cards)
		var line: String = _tip_line(book, opp)
		var same: bool = _same(sug, cards)
		tip.text = ("Graf Mopsula: " + line if line != "" else "Graf Mopsula:") + ("\nIhre Mappe passt schon zur Akte."
			if same else "\nVorschlag: " + change_text(book, cards, sug))
		take.disabled = same
		take.text = "In Mappe %s übernehmen" % _target(c, name2).to_upper()
		state["suggestion"] = sug
	for b3: Control in buttons:
		(b3 as Button).pressed.connect(func() -> void:
			state["mappe"] = b3.name.trim_prefix("Mappe").to_lower()
			refresh.call())
	take.pressed.connect(func() -> void:
		var target: String = _target(c, str(state["mappe"]))
		var apply: Callable = func() -> void:
			c.set_deck(target, state["suggestion"] as PackedStringArray)
			SdSession.save()
			state["mappe"] = target
			refresh.call()
			Events.toast_requested.emit("Vorschlag des Grafen in Mappe %s übernommen." % target.to_upper(), &"info")
			UiUtil.focus_later(start if not start.disabled else take)
		if c.deck(target).is_empty():
			apply.call()
			return
		var d: Node = (load("res://scenes/ui/confirm_dialog.tscn") as PackedScene).instantiate()
		d.call("setup", {"title": "Mappe %s überschreiben?" % target.to_upper(), "text": "Alle drei Mappen sind belegt. "
			+ "Der Vorschlag ersetzt Mappe %s." % target.to_upper(), "yes": "Überschreiben", "no": "Lieber nicht",
			"default_no": true})
		d.connect("closed", func(yes: bool) -> void:
			if yes:
				apply.call())
		m.add_child(d))
	start.pressed.connect(func() -> void:
		var chosen: String = str(state["mappe"])
		if c.deck_problem(c.deck(chosen), book) != "":
			return
		c.set_active(chosen)
		SdSession.save()
		m.call("close")
		hall.call("start_duel", opp.id, chosen))
	cab.pressed.connect(func() -> void:
		m.call("close")
		hall.call("open_cabinet", str(state["mappe"])))
	refresh.call()
	SdScreen.wire_grid([[close], buttons, [take, cab], [start]])
	UiUtil.focus_later(start if not start.disabled else buttons[0])


## The right column's head: a caption and the visible close button (the touch way out, 02_TECH §10.3).
static func _head(m: Node, right: VBoxContainer, caption: String) -> Button:
	var h: HBoxContainer = UiUtil.hbox(SdScreen.GAP)
	right.add_child(h)
	var l: Label = SdStyle.label(caption, 20, SdStyle.GOLD, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var close: Button = UiUtil.close_button()
	close.pressed.connect(func() -> void: m.call("close"))
	h.add_child(close)
	return close


## The Mappe the tip writes into: the first empty one other than `chosen`, else the next one after it.
static func _target(c: SdCollection, chosen: String) -> String:
	for name: String in SdCollection.MAPPEN:
		if name != chosen and c.deck(name).is_empty():
			return name
	var i: int = SdCollection.MAPPEN.find(chosen)
	return SdCollection.MAPPEN[(i + 1) % SdCollection.MAPPEN.size()]


static func _tip_line(book: SdRulebook, opp: SdOpponentDef) -> String:
	var lines: Array[Dictionary] = book.lines_for("sd_akte:" + opp.lines)
	return str(lines[0]["text"]) if not lines.is_empty() else ""


# --- "Passend zur Akte" (10 §2.6) ---------------------------------------------------------------------------------

## The Graf's suggestion for `cards` against `opp` (deterministic, owned cards only, never more copies than allowed):
## drops cards that do nothing here (an art the opponent is not responsible for, a status it is immune to), swaps up
## to MAX_SWAPS weaker cards for wanted ones (its Wunder Punkt; against an opponent with phases also the Dienst nach
## Vorschrift that lifts the Feierabend-Eilvermerk), fills the gaps with the best remaining cards — the poor ones
## last, Ärger an art it resists before a status it is immune to — and finally with SdCollection.auto_fill.
static func passend(c: SdCollection, book: SdRulebook, opp: SdOpponentDef,
		cards: PackedStringArray) -> PackedStringArray:
	var size: int = book.deck_size()
	var out: PackedStringArray = []
	for cid: String in cards:
		var card: SdCardDef = book.card(cid)
		if card != null and c.owns(cid) and not poor(card, opp) and out.size() < size and _room(book, out, cid):
			out.append(cid)
	var ranked: Array[Dictionary] = []
	var weak: Array[Dictionary] = []                      # poor cards: only to fill up, best (resisted Ärger) first
	for i in book.card_ids.size():
		var cid2: String = book.card_ids[i]
		var card2: SdCardDef = book.card(cid2)
		if not c.owns(cid2):
			continue
		var row: Dictionary = {"id": cid2, "score": score(card2, opp), "wanted": wanted(card2, opp), "i": i}
		if poor(card2, opp):
			weak.append(row)
		else:
			ranked.append(row)
	var by_score: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		if float(a["score"]) != float(b["score"]):
			return float(a["score"]) > float(b["score"])
		return int(a["i"]) < int(b["i"])
	ranked.sort_custom(by_score)
	weak.sort_custom(by_score)
	var swaps: int = 0
	for d: Dictionary in ranked:
		if not bool(d["wanted"]):
			continue
		var wid: String = str(d["id"])
		while _room(book, out, wid) and swaps < MAX_SWAPS:
			if out.size() < size:
				out.append(wid)
				swaps += 1
				continue
			var j: int = _weakest(book, opp, out)
			if j < 0 or score(book.card(out[j]), opp) >= float(d["score"]):
				break
			out.remove_at(j)
			out.append(wid)
			swaps += 1
	for d2: Dictionary in ranked + weak:
		while out.size() < size and _room(book, out, str(d2["id"])):
			out.append(str(d2["id"]))
	if out.size() < size:
		out = c.auto_fill(out, book)
	return out


## Does nothing useful against `opp`: Ärger of an art it is not responsible for (and nothing else), or only statuses
## it is immune to.
static func poor(card: SdCardDef, opp: SdOpponentDef) -> bool:
	if card.targets_self():
		return false
	var sts: PackedStringArray = card.status_ids()
	var useful_status: bool = false
	for sid: String in sts:
		useful_status = useful_status or not opp.status_immune.has(sid)
	if card.damage() > 0:
		return opp.element_mult(card.element()) < 1.0 and not useful_status
	return not sts.is_empty() and not useful_status


## Hits the Wunder Punkt, or (against an opponent with phases) brings Dienst nach Vorschrift.
static func wanted(card: SdCardDef, opp: SdOpponentDef) -> bool:
	if card.damage() > 0 and opp.element_mult(card.element()) > 1.0:
		return true
	return not opp.phases.is_empty() and card.status_ids().has("sts_sd_vorschrift")


## Value per Werktag against `opp`: Ärger (with Zuständigkeit and show chance), Geduld, a status counts 3.
static func score(card: SdCardDef, opp: SdOpponentDef) -> float:
	var v: float = float(card.damage()) * opp.element_mult(card.element()) * float(card.chance_pm()) / 1000.0
	v += float(card.heal()) * 0.8
	for sid: String in card.status_ids():
		if not opp.status_immune.has(sid):
			v += 3.0
	return v / float(maxi(1, card.rank()))


## Index of the weakest card in `deck` that may be swapped out (no heal, not wanted); -1 if none.
static func _weakest(book: SdRulebook, opp: SdOpponentDef, deck: PackedStringArray) -> int:
	var best: int = -1
	var best_v: float = INF
	for i in deck.size():
		var card: SdCardDef = book.card(deck[i])
		if card == null or card.heal() > 0 or wanted(card, opp):
			continue
		var v: float = score(card, opp)
		if v < best_v:
			best_v = v
			best = i
	return best


static func _room(book: SdRulebook, deck: PackedStringArray, cid: String) -> bool:
	var card: SdCardDef = book.card(cid)
	if card == null:
		return false
	var cap: int = mini(card.max_copies, book.constant("max_copies_show") if card.show else book.constant("max_copies"))
	return deck.count(cid) < cap


static func _same(a: PackedStringArray, b: PackedStringArray) -> bool:
	var x: PackedStringArray = a.duplicate()
	var y: PackedStringArray = b.duplicate()
	x.sort()
	y.sort()
	return x == y


## "4 Karten tauschen: mehr Eiskalt, weniger Stempel" (per Formular-Art; never colour only — words).
static func change_text(book: SdRulebook, before: PackedStringArray, after: PackedStringArray) -> String:
	var delta: Dictionary = {}
	var moved: int = 0
	var rest: PackedStringArray = after.duplicate()
	for cid: String in before:
		var k: int = rest.find(cid)
		if k >= 0:
			rest.remove_at(k)
		else:
			moved += 1
	for cid2: String in before:
		var a: String = book.card(cid2).art
		delta[a] = int(delta.get(a, 0)) - 1
	for cid3: String in after:
		var a2: String = book.card(cid3).art
		delta[a2] = int(delta.get(a2, 0)) + 1
	var more: PackedStringArray = []
	var less: PackedStringArray = []
	for art: String in SdStyle.ARTS.keys():
		var d: int = int(delta.get(art, 0))
		if d > 0:
			more.append(SdStyle.art_name(art))
		elif d < 0:
			less.append(SdStyle.art_name(art))
	var parts: PackedStringArray = []
	if not more.is_empty():
		parts.append("mehr " + ", ".join(more))
	if not less.is_empty():
		parts.append("weniger " + ", ".join(less))
	var n: int = maxi(moved, rest.size())
	return "%d %s tauschen%s" % [n, "Karte" if n == 1 else "Karten", (": " + "; ".join(parts)) if not parts.is_empty()
		else ""]
