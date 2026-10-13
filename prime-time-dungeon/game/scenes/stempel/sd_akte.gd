extends RefCounted
## The opponent's file ("Akte", 10 §1.1, §4.7): symbol, name, role, Geduld, Zuständigkeiten (Wunder Punkt / Nicht
## zuständig with symbol + word), immunities, the one new rule in one sentence, the file text and the public deck; in
## the hall also what the first victory brings, during a duel the open hand (Gegnerhand offen) and the discard pile.
## Builds Controls into a container (the hall's Akte panel, the table's Akte modal). Private helper.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdIcons := preload("res://scenes/stempel/sd_icons.gd")

const KINDS: Dictionary = {"back": "Kartenrücken", "ink": "Stempelfarbe", "mat": "Tischunterlage", "title": "Titel"}
const NAME_IMMUNE: Dictionary = {"sts_sd_wiedervorlage": "Wiedervorlage", "sts_sd_vorschrift": "Dienst nach Vorschrift",
	"sts_sd_eilvermerk": "Eilvermerk", "sts_sd_kleingedrucktes": "Kleingedrucktes"}


## Header row (symbol, name, role, Geduld) + facts. `extra`: {"first_win": bool, "open_hand": PackedStringArray,
## "discard": PackedStringArray, "geduld": int (current, during a duel)}.
static func build(into: Control, book: SdRulebook, opp: SdOpponentDef, extra: Dictionary = {}) -> void:
	var head: HBoxContainer = UiUtil.hbox(16)
	into.add_child(head)
	var sym: Control = SdIcons.icon(SdStyle.OPPONENT_ICONS.get(opp.symbol, &"person") as StringName, SdStyle.PAPER, 72)
	sym.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(sym)
	var col: VBoxContainer = UiUtil.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	col.add_child(SdStyle.label(opp.name, 30, SdStyle.TEXT, true))
	col.add_child(SdStyle.label(opp.role, 18, SdStyle.TEXT_DIM))
	var g: int = int(extra.get("geduld", opp.geduld))
	col.add_child(SdStyle.label("Geduld %d / %d" % [g, opp.geduld] if extra.has("geduld") else "Geduld %d"
		% opp.geduld, 20, SdStyle.TEXT, true))
	var text: Label = SdStyle.label(opp.akte, 19, SdStyle.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(540, 0)
	into.add_child(text)
	var duties: Array[Dictionary] = SdStyle.duties(opp.element_mods)
	var drow: HFlowContainer = HFlowContainer.new()
	drow.add_theme_constant_override("h_separation", 18)
	drow.add_theme_constant_override("v_separation", 6)
	into.add_child(drow)
	for d: Dictionary in duties:
		drow.add_child(duty_chip(str(d["label"]), str(d["art"]), bool(d["weak"])))
	for sid: String in opp.status_immune:
		var chip: HBoxContainer = UiUtil.hbox(6)
		chip.add_child(SdIcons.icon(&"clock_arrow", SdStyle.GOLD, 22))
		chip.add_child(SdStyle.label("Immun: " + str(NAME_IMMUNE.get(sid, sid)), 18, SdStyle.GOLD, true))
		drow.add_child(chip)
	if duties.is_empty() and opp.status_immune.is_empty():
		drow.add_child(SdStyle.label("Keine Zuständigkeiten.", 18, SdStyle.TEXT_DIM))
	var rule: Label = SdStyle.label("Neue Regel: " + opp.rule, 19, SdStyle.GOLD)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(540, 0)
	into.add_child(rule)
	if bool(extra.get("first_win", false)):
		var gifts: PackedStringArray = []
		for cid: String in opp.first_win_cards():
			gifts.append(book.card(cid).name if book.card(cid) != null else cid)
		for kid: String in opp.first_win_cosmetics():
			gifts.append(cosmetic_name(book, kid))
		var fw: Label = SdStyle.label("Erster Sieg bringt: " + ", ".join(gifts), 18, SdStyle.TEXT)
		fw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fw.custom_minimum_size = Vector2(540, 0)
		into.add_child(fw)
	var open: PackedStringArray = extra.get("open_hand", PackedStringArray())
	if not open.is_empty():
		into.add_child(_list_label("Hand (offen): ", open, book))
	var disc: PackedStringArray = extra.get("discard", PackedStringArray())
	if extra.has("discard"):
		into.add_child(_list_label("Ablage: ", disc, book) if not disc.is_empty() else SdStyle.label("Ablage: leer",
			18, SdStyle.TEXT_DIM))
	into.add_child(_list_label("Mappe des Gegenübers: ", opp.deck_list(), book, true))


## "Tischunterlage „Umlaufmappe“" — a cosmetic with its kind (the card Umlaufmappe is something else).
static func cosmetic_name(book: SdRulebook, id: String) -> String:
	var c: Dictionary = book.cosmetics.get(id, {})
	return "%s „%s“" % [str(KINDS.get(str(c.get("kind", "")), "Kosmetik")), str(c.get("name", id))]


## "WUNDER PUNKT: [flame] Eilt" — word, symbol and art name; gold for the weak spot, grey for not responsible.
static func duty_chip(label_text: String, art: String, weak: bool) -> HBoxContainer:
	var chip: HBoxContainer = UiUtil.hbox(6)
	chip.add_child(SdStyle.label(label_text.to_upper() + ":", 18, SdStyle.GOLD if weak else SdStyle.TEXT_DIM, true))
	var ic: Control = SdIcons.icon(SdStyle.art_icon(art), SdStyle.art_band(art), 22)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(ic)
	chip.add_child(SdStyle.label(SdStyle.art_name(art) + (" × 1,5" if weak else " × 0,5"), 18, SdStyle.TEXT))
	return chip


## "Prefix: 2 × Stempel, Formular 27b, …" (counted, deck order kept).
static func _list_label(prefix: String, ids: PackedStringArray, book: SdRulebook, counted: bool = false) -> Label:
	var parts: PackedStringArray = []
	if counted:
		var counts: Dictionary = {}
		var order: PackedStringArray = []
		for cid: String in ids:
			if not counts.has(cid):
				order.append(cid)
			counts[cid] = int(counts.get(cid, 0)) + 1
		for cid2: String in order:
			var n: String = book.card(cid2).name if book.card(cid2) != null else cid2
			parts.append(("%d × %s" % [int(counts[cid2]), n]) if int(counts[cid2]) > 1 else n)
	else:
		for cid3: String in ids:
			parts.append(book.card(cid3).name if book.card(cid3) != null else cid3)
	var l: Label = SdStyle.label(prefix + ", ".join(parts), 18, SdStyle.TEXT_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	return l
