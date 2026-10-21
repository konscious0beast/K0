extends RefCounted
## The results panel of a duel (10 §4.2 "Ergebnis-Panel", §5.2): layer 60, gold frame like the combat's credits panel,
## a big slanted stamp — BEWILLIGT (red), ABGELEHNT (grey), VERTAGT (Dienstschluss) —, below it what the duel brought:
## new cards (into the album), the Stempelheft stamp, cosmetics, Dienstauszeichnungen; after two defeats in a row the
## Graf's Mappe tip (10 §5.5). Buttons Revanche (focus) · Andere Mappe · Zurück; the Lernduell ends with "Zur
## Schalterhalle". Private helper: open(table, summary, rewards) → the modal.

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")
const SdAkte := preload("res://scenes/stempel/sd_akte.gd")

const STAMPS: Dictionary = {"won": ["BEWILLIGT", Color("#c8102e")], "lost": ["ABGELEHNT", Color("#8a8494")],
	"forfeit": ["ABGELEHNT", Color("#8a8494")], "adjourned": ["VERTAGT", Color("#4f8dff")],
	"skipped": ["EINGEARBEITET", Color("#c8102e")]}


## A slanted rubber stamp with a word (scales in from 1.3; the ink colour of the result).
class Stamp extends Control:
	const Style := preload("res://scenes/stempel/sd_style.gd")
	var word: String = "BEWILLIGT"
	var ink: Color = Color("#c8102e")
	var size_px: int = 64

	func _draw() -> void:
		var f: Font = Style.bold()
		var tw: float = f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var c: Vector2 = size * 0.5
		draw_set_transform(c, deg_to_rad(-7.0), Vector2.ONE)
		var r: Rect2 = Rect2(Vector2(-tw * 0.5 - 22.0, -size_px * 0.62), Vector2(tw + 44.0, size_px * 1.2))
		draw_rect(r, ink, false, 6.0)
		draw_rect(r.grow(-10.0), Color(ink, 0.6), false, 2.0)
		draw_string(f, Vector2(-tw * 0.5, size_px * 0.34), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func open(table: Node, summary: Dictionary, rewards: Dictionary) -> Node:
	var book: SdRulebook = table.get("book") as SdRulebook
	var collection: SdCollection = table.get("collection") as SdCollection
	var res: String = str(summary.get("result", "lost"))
	var tut: bool = bool(summary.get("tut", false))
	var m: Node = SdModal.new()
	m.call("setup", "", 720.0, SdStyle.GOLD, 0.6, false)
	m.set("closable", false)
	m.name = "Results"
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var st: Array = STAMPS.get(res, STAMPS["lost"]) as Array
	var stamp: Stamp = Stamp.new()
	stamp.name = "Stamp"
	stamp.word = str(st[0])
	stamp.ink = st[1] as Color
	stamp.custom_minimum_size = Vector2(660, 110)
	box.add_child(stamp)
	var opp: SdOpponentDef = book.opponent(str(summary.get("opp", "")))
	var sub: String = ""
	if res == "skipped":
		sub = "Lernduell übersprungen — die Grundakte liegt bereit."
	elif opp != null:
		var g: Array = summary.get("geduld", [0, 0]) as Array
		sub = "%s · Nummer %03d · Ihre Geduld %d" % [opp.name, int(summary.get("tickets", 0)), int(g[0]) if not g.is_empty()
			else 0]
		if res == "forfeit":
			sub = "%s · Antrag zurückgezogen. Kostet nichts." % opp.name
		elif res == "adjourned":
			sub = "Dienstschluss bei Nummer %d: vertagt, nichts verloren." % book.constant("dienstschluss")
	var subl: Label = SdStyle.label(sub, 20, SdStyle.TEXT_DIM)
	subl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subl)
	for line: String in reward_lines(book, collection, rewards, tut):
		var l: Label = SdStyle.label(line, 20, SdStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(660, 0)
		box.add_child(l)
	if not tut and res != "won" and collection.wants_deck_tip():
		var tip: Array[Dictionary] = book.lines_for("sd_hint:deck")
		if not tip.is_empty():
			var t: Label = SdStyle.label("Graf Mopsula: " + str(tip[0]["text"]), 19, SdStyle.GOLD)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.custom_minimum_size = Vector2(660, 0)
			box.add_child(t)
	var row: HBoxContainer = UiUtil.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var buttons: Array[Control] = []
	if tut:
		buttons.append(_button(row, "Zur Schalterhalle", func() -> void: table.call("leave")))
	else:
		buttons.append(_button(row, "Revanche", func() -> void: table.call("rematch")))
		buttons.append(_button(row, "Andere Mappe", func() -> void: table.call("other_mappe")))
		buttons.append(_button(row, "Zurück", func() -> void: table.call("leave")))
	UiUtil.wire_horizontal(buttons)
	table.add_child(m)
	if not bool(table.get("instant")) and not bool(table.get("reduce_motion")):
		stamp.pivot_offset = stamp.custom_minimum_size * 0.5
		stamp.scale = Vector2.ONE * 1.3
		stamp.create_tween().tween_property(stamp, "scale", Vector2.ONE, 0.18)
	return m


static func _button(row: HBoxContainer, text: String, cb: Callable) -> Button:
	var b: Button = UiUtil.button(text, &"ButtonBig")
	b.name = text.replace(" ", "")
	b.custom_minimum_size = Vector2(200, 0)
	UiUtil.touch_pad(b)
	b.pressed.connect(cb)
	row.add_child(b)
	return b


## The reward lines of a booked duel (SdCollection.record_duel / complete_tutorial result).
static func reward_lines(book: SdRulebook, collection: SdCollection, rewards: Dictionary,
		tut: bool) -> PackedStringArray:
	var out: PackedStringArray = []
	var cards: PackedStringArray = rewards.get("cards", PackedStringArray())
	if tut and not cards.is_empty():
		out.append("Grundakte: %d Karten im Stempelalbum, die Startmappe liegt als Mappe A bereit." % cards.size())
	elif not cards.is_empty():
		var names: PackedStringArray = []
		for cid: String in cards:
			names.append(book.card(cid).name if book.card(cid) != null else cid)
		out.append("Neue Karten im Stempelalbum: " + ", ".join(names))
	if bool(rewards.get("heft", false)):
		var every: int = maxi(1, book.constant("heft_every"))
		var left: int = every - collection.heft % every
		var next_id: String = collection.next_heft_reward(book)
		out.append("Stempelheft: Feld %d gestempelt%s" % [collection.heft, (" — noch %d bis zur nächsten Belohnung"
			% left) if next_id != "" and left < every else (" — Belohnung erhalten" if left == every else "")])
	var cos: PackedStringArray = rewards.get("cosmetics", PackedStringArray())
	if not cos.is_empty():
		var cn: PackedStringArray = []
		for kid: String in cos:
			cn.append(SdAkte.cosmetic_name(book, kid))
		out.append("Kosmetik: " + ", ".join(cn))
	var aw: PackedStringArray = rewards.get("awards", PackedStringArray())
	if not aw.is_empty():
		var an: PackedStringArray = []
		for aid: String in aw:
			an.append(str((book.awards.get(aid, {}) as Dictionary).get("name", aid)))
		out.append("Dienstauszeichnung: " + ", ".join(an))
	return out
