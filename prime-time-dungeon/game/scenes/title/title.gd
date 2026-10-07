# STUB(M0) — owned by M6. Replace completely, keep the public API.
class_name TitleScreen extends Control
## Title screen stub (02_TECH §9.5).


## Same code path as the menu: Game.new_game(...) → goto(SCENE_INTRO) or, if skip_intro,
## goto(SCENE_EXPLORATION, {"spawn": &"start"}).
func request_new_game(slot: int, player_name: String, skip_intro: bool, seed: int = -1,
		difficulty: StringName = &"prime") -> void:
	pass


func _ready() -> void:
	var label: Label = Label.new()
	label.name = "StubTitle"
	label.theme_type_variation = &"LabelTitle"
	label.text = tr("PRIME TIME DUNGEON")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)
