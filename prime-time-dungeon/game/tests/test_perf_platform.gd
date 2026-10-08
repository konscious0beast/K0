extends TestCase
## Platform readiness (02_TECH §2.1, §10.3–10.5, §12.2, §12.3): mobile project settings, export presets (all five,
## shared filters, launcher icons that exist and have the store sizes), the startup chain not compiling screens early.

const PRESETS: String = "res://export_presets.cfg"
const PLATFORMS: Dictionary = {"Windows": "Windows Desktop", "Linux": "Linux", "macOS": "macOS", "Android": "Android",
	"iOS": "iOS"}
const ICONS: Dictionary = {
	"Android": {"launcher_icons/main_192x192": 192, "launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432},
	"iOS": {"icons/icon_1024x1024": 1024},
}


func test_mobile_project_settings() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 4, "sensor landscape")
	assert_false(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")),
		"touch emulation off by default")
	assert_true(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")), "buttons get touch")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "mobile")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")), "mobile")
	assert_true(bool(ProjectSettings.get_setting("rendering/rendering_device/fallback_to_opengl3")), "GL fallback")
	assert_true(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")), "ETC2/ASTC")
	assert_false(bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "Android back → ui_cancel")
	assert_true(bool(ProjectSettings.get_setting("display/window/energy_saving/keep_screen_on")))
	assert_ne(int(ProjectSettings.get_setting("display/window/vsync/vsync_mode")), DisplayServer.VSYNC_DISABLED,
		"vsync stays on")
	# 60 FPS cap on phones (90/120 Hz panels would otherwise render at 120 FPS: battery/heat, §12.1 target 60).
	assert_true(ProjectSettings.has_setting("application/run/max_fps.mobile"), "mobile FPS cap set")
	assert_eq(int(ProjectSettings.get_setting("application/run/max_fps.mobile", 0)), 60)
	assert_eq(int(ProjectSettings.get_setting("application/run/max_fps")), 0, "PC: uncapped, vsync limits")
	assert_eq(str(ProjectSettings.get_setting("application/config/icon")), "res://icon.svg")
	assert_true(ResourceLoader.exists("res://icon.svg"), "app icon present")


func test_export_presets_are_complete() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(PRESETS), OK, "export_presets.cfg parses")
	var seen: Dictionary = {}
	for section: String in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		var preset_name: String = str(cfg.get_value(section, "name", ""))
		seen[preset_name] = section
		assert_eq(str(cfg.get_value(section, "platform", "")), str(PLATFORMS.get(preset_name, "?")),
			"platform of " + preset_name)
		assert_eq(str(cfg.get_value(section, "export_filter", "")), "all_resources", preset_name)
		assert_eq(str(cfg.get_value(section, "include_filter", "")), "data/*.json", preset_name + ": JSON included")
		assert_eq(str(cfg.get_value(section, "exclude_filter", "")), "tests/*, art/gallery/*", preset_name)
		assert_true(str(cfg.get_value(section, "export_path", "")).begins_with("../build/"), preset_name + " → build/")
	for p: String in PLATFORMS.keys():
		assert_true(seen.has(p), "preset %s present" % p)
	if not seen.has("Android"):
		return
	var android: String = str(seen["Android"]) + ".options"
	assert_true(bool(cfg.get_value(android, "architectures/arm64-v8a", false)), "arm64")
	assert_true(bool(cfg.get_value(android, "screen/immersive_mode", false)), "immersive")


func test_launcher_icons_exist_with_store_sizes() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PRESETS)
	for section: String in cfg.get_sections():
		if section.ends_with(".options"):
			continue
		var preset_name: String = str(cfg.get_value(section, "name", ""))
		if not ICONS.has(preset_name):
			continue
		var wanted: Dictionary = ICONS[preset_name]
		for key: String in wanted.keys():
			var path: String = str(cfg.get_value(section + ".options", key, ""))
			assert_true(path.begins_with("res://art/icons/"), "%s %s set (%s)" % [preset_name, key, path])
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path)) if path != "" else null
			assert_not_null(img, "%s loads" % path)
			if img != null:
				var px: int = int(wanted[key])
				assert_eq(img.get_size(), Vector2i(px, px), "%s is %d×%d" % [path, px, px])
				if key == "icons/icon_1024x1024":
					assert_eq(img.detect_alpha(), Image.ALPHA_NONE, "iOS icon must be opaque")


func test_boot_does_not_compile_the_screens_early() -> void:
	# GlobalUi is loaded by Boot before the first frame: a class_name check of a screen there compiled every screen
	# with its dependency tree (1.1 s of 2.7 s, §12.1 "Start"). Source-level guard for that rule.
	for path: String in ["res://scenes/ui/global_ui.gd", "res://scenes/boot/boot.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		for cls: String in ["ExplorationScene", "BattleScene", "SafeRoomScene"]:
			var code_lines: PackedStringArray = []
			for line: String in src.split("\n"):
				if not line.strip_edges().begins_with("#"):
					code_lines.append(line)
			assert_false("\n".join(code_lines).contains(cls), "%s must not reference %s" % [path.get_file(), cls])
		assert_false(src.contains('preload("res://scenes/boot/autoplay.gd")'), path.get_file() + ": autoplay lazy")
		assert_false(src.contains('preload("res://scenes/boot/fullrun.gd")'), path.get_file() + ": full-run bot lazy")
