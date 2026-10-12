extends RefCounted
## Static texts of the Stempelduell screens (10 §0.1, §4.6, §4.7): the five sentences, the glossary of the rules page
## and the controls per input scheme. German, "Sie", drawn symbols only (03_ART F8); test_sd_ui checks them against
## the rulebook's text rules (IP words, glyphs). Private helper (no class_name).

const FIVE: PackedStringArray = [
	"Ziel: Bringen Sie die Geduld Ihres Gegenübers auf 0, bevor Ihre eigene aufgebraucht ist.",
	"Wer dran ist, zeigt die Wartenummern-Anzeige — manchmal sind Sie mehrmals hintereinander dran.",
	"Sind Sie dran, spielen Sie eine Karte aus Ihrer Hand von fünf und ziehen sofort eine neue.",
	"Jede Karte hat eine Bearbeitungszeit in Werktagen: Je länger sie dauert, desto später kommt Ihre nächste Nummer.",
	"Statt einer Karte dürfen Sie abheften: Sie tauschen eine Karte, sind schnell wieder dran und nehmen bis dahin "
		+ "nur halben Ärger.",
]
const GLOSSARY: Array[Array] = [
	["Geduld", "Ihre Ausdauer am Schalter. Fällt sie auf 0, ist der Antrag abgelehnt."],
	["Ärger", "„9 Ärger“ heißt: 9 Geduld weniger. Jede Zahl steht genau so auf der Karte."],
	["Werktag", "Die Bearbeitungszeit einer Karte. Ein Werktag ist für alle gleich lang."],
	["Wartenummer", "Wer zuerst aufgerufen wird, ist dran. Sicher ist der vordere Teil der Anzeige, dahinter steht "
		+ "eine Prognose."],
	["Abheften", "Eine Karte tauschen, nach 2 Werktagen wieder dran — bis dahin nur halber Ärger."],
	["Wiedervorlage", "Die nächste Nummer des Gegenübers rutscht 3 Werktage nach hinten. Nicht doppelt."],
	["Dienst nach Vorschrift", "Die nächsten 2 Nummern des Gegenübers dauern 50 % länger."],
	["Eilvermerk", "Ihre Karten sind 40 % schneller bearbeitet. Hebt Dienst nach Vorschrift auf."],
	["Kleingedrucktes", "Zu Beginn seiner nächsten 3 Nummern verliert das Gegenüber je 2 Geduld."],
	["Formular-Arten", "Stempel, Eilt, Eiskalt, Rohrpost, Papierkram und Verwaltung — Symbol und Wort stehen auf "
		+ "jeder Karte."],
	["Zuständigkeiten", "Wunder Punkt: diese Art trifft 1,5-fach. Nicht zuständig: sie prallt halb ab. Die Akte "
		+ "nennt beides."],
	["Show-Karten", "Goldrahmen, großer Ärger mit der aufgedruckten Erfolgschance. Ein Patzer kostet etwas, nie die "
		+ "letzte Geduld."],
	["Durchsage", "Beim Stempelmeister: 4 Ärger, wenn ihre Nummer kommt — wer vorher abheftet, hört nur die Hälfte."],
	["Dienstschluss", "Bei Nummer 80 wird vertagt: unentschieden, nichts verloren."],
	["Kundschaft geht vor", "Bei Gleichstand sind Sie vor dem Gegenüber dran; die Durchsage kommt zuletzt."],
]
## Controls (10 §4.6): [what, keyboard, gamepad, touch].
const CONTROLS: Array[Array] = [
	["Karte markieren", "Links / Rechts oder 1–5", "Steuerkreuz links / rechts", "Karte antippen"],
	["Karte spielen", "Enter, Leertaste, F", "A", "erneut antippen, STEMPELN oder auf den Schalter ziehen"],
	["Abheften", "X oder Rücktaste, dann Karte", "X, dann Karte", "ABLAGE, dann Karte — oder Karte auf ABLAGE ziehen"],
	["Großansicht", "Tab oder M", "Select", "Karte lang drücken"],
	["Bereich wechseln", "Q / E", "LB / RB", "Plakette antippen: Akte"],
	["Der Graf übernimmt", "T", "Y", "Menü: Hilfen"],
	["Tempo × 1 / × 2", "R", "R3", "Menü: Hilfen"],
	["Menü", "Esc oder P", "Start", "Menü-Knopf"],
]


## The rules page as [heading, text] rows (the five sentences, then the glossary).
static func rules_rows() -> Array[Array]:
	var out: Array[Array] = []
	for i in FIVE.size():
		out.append(["%d." % (i + 1), FIVE[i]])
	for g: Array in GLOSSARY:
		out.append([str(g[0]), str(g[1])])
	return out


## Every static text of this file (tests).
static func all_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	out.append_array(FIVE)
	for g: Array in GLOSSARY:
		out.append(str(g[0]))
		out.append(str(g[1]))
	for c: Array in CONTROLS:
		for t: Variant in c:
			out.append(str(t))
	return out
