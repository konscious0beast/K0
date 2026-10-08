extends Control
## Portrait gallery (M5 review tool, `check.sh --shot res://scenes/battle/portrait_gallery.tscn …`): the battle HUD
## portrait of every cast member (party + all enemies of enemies.json) at CTB size (56 px) and panel size (128 px),
## framed exactly like the HUD (BattleHud.make_portrait_viewport / frame_portrait), so every archetype is checked.
## Not part of the game flow. Private M5 helper (no class_name).

const BattleHud := preload("res://scenes/battle/ui/battle_hud.gd")
const HudStyle := preload("res://scenes/battle/ui/hud_style.gd")
const COLS: int = 6

var cells: Array[Dictionary] = []     # {"id", "viewport"}


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#140d1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLS
	grid.position = Vector2(24, 20)
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var models: Array[Dictionary] = []
	for pid: String in DB.data.ids("party"):
		models.append({"id": pid, "name": DB.party_member(pid).name, "model": DB.party_member(pid).model})
	for eid: String in DB.data.ids("enemies"):
		models.append({"id": eid, "name": DB.enemy(eid).name, "model": DB.enemy(eid).model})
	for m: Dictionary in models:
		var vp: SubViewport = BattleHud.make_portrait_viewport(m["model"] as Dictionary)
		add_child(vp)
		BattleHud.frame_portrait(vp)
		cells.append({"id": m["id"], "viewport": vp})
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		cell.add_child(row)
		for px: int in [56, 96]:
			var frame: Panel = Panel.new()
			frame.custom_minimum_size = Vector2(px, px)
			var sb: StyleBoxFlat = HudStyle.show_box(Color(HudStyle.C_ENEMY, 0.28), HudStyle.C_ENEMY, 2, 0.0,
				Vector4(2, 2, 2, 2))
			if DB.data.ids("party").has(str(m["id"])):
				sb.bg_color = Color(HudStyle.C_PARTY, 0.28)
				sb.border_color = HudStyle.C_PARTY
			frame.add_theme_stylebox_override("panel", sb)
			var tex: TextureRect = TextureRect.new()
			tex.texture = vp.get_texture()
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.offset_left = 2
			tex.offset_top = 2
			tex.offset_right = -2
			tex.offset_bottom = -2
			frame.add_child(tex)
			row.add_child(frame)
		var l: Label = HudStyle.label(str(m["name"]), 15, HudStyle.C_PAPER, true, 2)
		l.custom_minimum_size = Vector2(160, 0)
		l.clip_text = true
		cell.add_child(l)
