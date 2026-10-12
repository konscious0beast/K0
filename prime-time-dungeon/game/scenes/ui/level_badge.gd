extends RefCounted
## The level plaque (09 §1.2 Nr. 1, ST1-A): where space is tight — party frames, target frames, name plates — a level
## shows as its bare number in a round plaque, never as "Lv 12"; its tooltip reads "Stufe 12". Two forms of the same
## look: a Control for container layouts (party menu, exploration HUD, the combat's credits panel) and a draw helper
## for the frames that submit one triangle array (IconMesh: the pull target frame and the combat's unit frames, 09
## §11.7 CR-32 i). Private helper (no class_name; preloaded). The difference number and the WoW colours of enemy
## plaques ("+3" in orange, 09 §3.4, 03_ART CR-28) come with ST1-C/H and extend this file.

const IconMesh := preload("res://scenes/ui/icon_mesh.gd")
const UiUtilRef := preload("res://scenes/ui/ui_util.gd")

const TOOLTIP: String = "Stufe %d"
## Plaque diameter = the number's font size × DIAMETER_PER_PX + DIAMETER_PAD: two digits ("48") keep about 2 px to
## the ring at every size from 12 to 24 px (CR-32 i; 1.6 × the size alone let two digits touch the ring).
const DIAMETER_PER_PX: float = 1.5
const DIAMETER_PAD: float = 5.0
## Radius of a drawn plaque around the 12 px number of a HUD frame = diameter(12) / 2.
const FRAME_RADIUS: float = 11.5
const BORDER_PX: int = 2
const FILL_ALPHA: float = 0.88                         # UiTheme.C_BG behind the number


## "Stufe 12": the plaque's tooltip and the long form wherever the word fits (09 §1.2 Nr. 1).
static func tooltip(level: int) -> String:
	return TOOLTIP % level


## Diameter of the plaque around a number of `font_size` px.
static func diameter(font_size: int) -> float:
	return roundf(float(font_size) * DIAMETER_PER_PX + DIAMETER_PAD)


## The plaque as a Control: a round panel (border `color`) around the bold number. Mouse filter PASS so the tooltip
## shows in menus while a click still reaches the card underneath; HUD callers set MOUSE_FILTER_IGNORE.
static func make(level: int, font_size: int = 15, color: Color = UiTheme.C_GOLD) -> PanelContainer:
	var px: int = maxi(font_size, UiUtilRef.MIN_FONT)
	var d: float = diameter(px)
	var p: PanelContainer = PanelContainer.new()
	p.name = "LevelBadge"
	p.custom_minimum_size = Vector2(d, d)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.tooltip_text = tooltip(level)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.C_BG, FILL_ALPHA)
	sb.border_color = color
	sb.set_border_width_all(BORDER_PX)
	sb.set_corner_radius_all(int(d))
	sb.set_content_margin_all(0.0)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	var l: Label = UiUtilRef.label(str(level), &"", px, color)
	l.name = "Number"
	l.add_theme_font_override("font", UiTheme.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## The plaque into an IconMesh frame: the dark disc with its ring (the caller centres the number label on `center`).
static func draw(m: IconMesh, center: Vector2, radius: float, color: Color = UiTheme.C_GOLD) -> void:
	m.circle(center, radius, Color(UiTheme.C_BG, FILL_ALPHA), true)
	m.ring(center, radius - 1.0, color, float(BORDER_PX), true)
