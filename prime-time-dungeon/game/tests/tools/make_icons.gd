extends SceneTree
## Renders the export launcher icons from res://icon.svg (02_TECH §12.3, tools/make_icons.sh). No class_name / autoload
## identifiers (§13.2 rule 4); needs no renderer (SVG → Image in software, works headless).
## godot --headless --path game -s res://tests/tools/make_icons.gd -- --out=<abs dir>
## Writes: icon_1024.png (iOS App Store, opaque: iOS rejects alpha and masks the corners itself), icon_192.png
## (Android legacy launcher), icon_fg_432.png (Android adaptive foreground: artwork inside the 66 dp safe circle,
## transparent around it), icon_bg_432.png (Android adaptive background: ink), icon_macos_1024.png (macOS: the badge
## on Apple's 1024 grid, 824 px body with a transparent margin like every Dock icon; the export would otherwise upscale
## the 128 px SVG import), launch_384.png / launch_576.png (iOS launch screen @2x / @3x: the badge at 192 pt, centred
## on the boot-splash colour).

const SVG: String = "res://icon.svg"
const SVG_SIZE: float = 128.0
const SVG_BODY: float = 120.0       # the badge (rounded rect 4..124) inside the 128 canvas
const INK: Color = Color("#140d1c")
const FG_ART_PX: int = 256          # 432 px canvas, safe circle Ø 264 px → artwork 256 px centred
const MACOS_BODY_PX: float = 824.0  # Apple macOS icon grid: 824 × 824 body on the 1024 canvas
const LAUNCH_PT: int = 192          # launch-screen badge size in points (UIImageView content mode "center")


func _initialize() -> void:
	var out_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir == "":
		printerr("Assertion failed: make_icons: missing --out=<dir>")
		quit(1)
		return
	var svg: String = FileAccess.get_file_as_string(SVG)
	if svg == "":
		printerr("Assertion failed: make_icons: cannot read %s" % SVG)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ok: bool = true
	ok = _save(_on_ink(_render(svg, 1024), 1024), out_dir.path_join("icon_1024.png")) and ok
	ok = _save(_render(svg, 192), out_dir.path_join("icon_192.png")) and ok
	var fg: Image = Image.create(432, 432, false, Image.FORMAT_RGBA8)
	fg.fill(Color(0, 0, 0, 0))
	var art: Image = _render(svg, FG_ART_PX)
	fg.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i((432 - FG_ART_PX) / 2, (432 - FG_ART_PX) / 2))
	ok = _save(fg, out_dir.path_join("icon_fg_432.png")) and ok
	var bg: Image = Image.create(432, 432, false, Image.FORMAT_RGB8)
	bg.fill(INK)
	ok = _save(bg, out_dir.path_join("icon_bg_432.png")) and ok
	var mac: Image = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	mac.fill(Color(0, 0, 0, 0))
	var mac_art: Image = _render(svg, roundi(MACOS_BODY_PX * SVG_SIZE / SVG_BODY))
	mac.blend_rect(mac_art, Rect2i(Vector2i.ZERO, mac_art.get_size()), (Vector2i(1024, 1024) - mac_art.get_size()) / 2)
	ok = _save(mac, out_dir.path_join("icon_macos_1024.png")) and ok
	for scale: int in [2, 3]:
		var px: int = LAUNCH_PT * scale
		ok = _save(_render(svg, px), out_dir.path_join("launch_%d.png" % px)) and ok
	quit(0 if ok else 1)


static func _render(svg: String, px: int) -> Image:
	var img: Image = Image.new()
	img.load_svg_from_string(svg, float(px) / SVG_SIZE)
	if img.get_width() != px:
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGBA8)
	return img


## Opaque copy: the transparent corners of the badge become ink (iOS app icons must not have an alpha channel).
static func _on_ink(img: Image, px: int) -> Image:
	var out: Image = Image.create(px, px, false, Image.FORMAT_RGBA8)
	out.fill(INK)
	out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	out.convert(Image.FORMAT_RGB8)
	return out


static func _save(img: Image, path: String) -> bool:
	var err: Error = img.save_png(path)
	if err != OK:
		printerr("Assertion failed: make_icons: cannot write %s (%d)" % [path, err])
		return false
	print("ICON: %s %dx%d" % [path, img.get_width(), img.get_height()])
	return true
