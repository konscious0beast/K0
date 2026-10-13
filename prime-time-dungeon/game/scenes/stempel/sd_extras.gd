extends RefCounted
## The title's Extras menu (10 §4.7: "Extras ist ein kleines Untermenü, das später auch Ruhmeshalle und Galerien
## aufnehmen kann"): a modal over the title with "Stempelduell (Vorschau)" → the Schalterhalle (Router.push, FADE).
## The title's marked section (scenes/title/title.gd) only calls open(); everything else lives in scenes/stempel/.
## Private helper: open(title) → the modal (SdModal: closed signal, ui_cancel / B / "Schließen" close it).

const UiUtil := preload("res://scenes/ui/ui_util.gd")
const SdStyle := preload("res://scenes/stempel/sd_style.gd")
const SdModal := preload("res://scenes/stempel/sd_modal.gd")

const HALL: String = "res://scenes/stempel/sd_hall.tscn"


static func open(parent: Node) -> Node:
	var m: Node = SdModal.new()
	m.call("setup", "EXTRAS", 640.0)
	m.name = "Extras"
	var box: VBoxContainer = m.get("content") as VBoxContainer
	var b: Button = UiUtil.button("Stempelduell (Vorschau)", &"ButtonBig")
	b.name = "Stempelduell"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UiUtil.touch_pad(b)
	b.pressed.connect(func() -> void:
		m.call("close")
		Router.push(HALL, {}, Router.Transition.FADE))
	box.add_child(b)
	var sub: Label = SdStyle.label("Das Kartenspiel vom Schalter 3: Wartenummern, Formulare und ein Graf mit "
		+ "Fußnoten. Eine Vorschau — die Sammlung bleibt.", 18, SdStyle.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(580, 0)
	box.add_child(sub)
	parent.add_child(m)
	return m
