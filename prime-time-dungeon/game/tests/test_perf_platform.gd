extends TestCase
## Platform readiness (02_TECH §2.1, §10.3–10.5, §12.2–12.4): mobile project settings, export presets (all five,
## shared filters, launcher icons that exist and have the store sizes, the Apple export modes, one displayed version,
## the Apple release values patched in only at export time), the startup chain not compiling screens early.

const ApplePreset := preload("res://tests/tools/apple_preset.gd")
const PRESETS: String = "res://export_presets.cfg"
const PLATFORMS: Dictionary = {"Windows": "Windows Desktop", "Linux": "Linux", "macOS": "macOS", "Android": "Android",
	"iOS": "iOS"}
const ICONS: Dictionary = {
	"Android": {"launcher_icons/main_192x192": 192, "launcher_icons/adaptive_foreground_432x432": 432,
		"launcher_icons/adaptive_background_432x432": 432},
	"iOS": {"icons/icon_1024x1024": 1024, "storyboard/custom_image@2x": 384, "storyboard/custom_image@3x": 576},
	"macOS": {"application/icon": 1024},
}
## User-visible version of each preset (Windows product version, Apple CFBundleShortVersionString, Android versionName):
## empty (= application/config/version) or equal to it, so every build of a release shows the version of the title
## screen and the save files. Build numbers (file_version, Apple application/version, version/code) may count up.
const VERSION_KEYS: PackedStringArray = ["application/product_version", "application/short_version", "version/name"]


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


func test_apple_presets_export_playable_builds() -> void:
	# 02_TECH §12.3, README "Spielbare Builds": macOS = universal .app with the built-in ad-hoc signature; iOS = the
	# Xcode project only (CI runs on Linux, signing happens in Xcode on the Mac).
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PRESETS)
	var mac: String = _preset_section(cfg, "macOS")
	var ios: String = _preset_section(cfg, "iOS")
	assert_ne(mac, "", "macOS preset")
	assert_ne(ios, "", "iOS preset")
	if mac == "" or ios == "":
		return
	assert_eq(str(cfg.get_value(mac + ".options", "binary_format/architecture", "")), "universal")
	assert_eq(int(cfg.get_value(mac + ".options", "codesign/codesign", -1)), 1, "built-in ad-hoc signature")
	assert_true(bool(cfg.get_value(ios + ".options", "application/export_project_only", false)), "no xcodebuild")
	assert_eq(str(cfg.get_value(ios, "export_path", "")).get_extension(), "xcodeproj")
	# 4.7.2 refuses an empty Team ID even for the project-only export: a placeholder, the real team is chosen in Xcode.
	assert_ne(str(cfg.get_value(ios + ".options", "application/app_store_team_id", "")), "", "Team ID placeholder")
	# Xcode's Run uses the exported (Release) configuration; a free Apple ID has no distribution certificate.
	assert_eq(str(cfg.get_value(ios + ".options", "application/code_sign_identity_release", "")), "Apple Development")
	# App Store Connect rejects a build whose binary references camera / microphone / photo APIs (the engine does)
	# without a purpose string (ITMS-90683); the game never asks for them, the strings say so.
	for key: String in ["privacy/camera_usage_description", "privacy/microphone_usage_description",
			"privacy/photolibrary_usage_description"]:
		assert_ne(str(cfg.get_value(ios + ".options", key, "")), "", "iOS " + key)


func test_apple_release_values_reach_the_presets_only_at_export_time() -> void:
	# 02_TECH §12.4: the CI jobs apple-macos / apple-ios-testflight patch a temp copy (tests/tools/apple_preset.gd);
	# the committed presets keep the placeholders, so local and unsigned builds stay as they are.
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(PRESETS), OK, "export_presets.cfg parses")
	var mac: String = _preset_section(cfg, "macOS") + ".options"
	var ios: String = _preset_section(cfg, "iOS") + ".options"
	assert_eq(str(cfg.get_value(ios, "application/app_store_team_id", "")), "XXXXXXXXXX", "committed: placeholder")
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	var values: Dictionary = {"team_id": "AB12CD34EF", "bundle_id": "de.example.primetime", "build": "57.2",
		"short_version": version, "sign_identity": "Apple Distribution: Example GmbH (AB12CD34EF)",
		"profile_uuid": "0F1E2D3C-4B5A-6978-8796-A5B4C3D2E1F0"}
	assert_eq(ApplePreset.patch(cfg, "ios", values), "", "iOS values accepted")
	assert_eq(str(cfg.get_value(ios, "application/app_store_team_id")), "AB12CD34EF")
	assert_eq(str(cfg.get_value(ios, "application/bundle_identifier")), "de.example.primetime")
	assert_eq(str(cfg.get_value(ios, "application/short_version")), version, "CFBundleShortVersionString")
	assert_eq(str(cfg.get_value(ios, "application/version")), "57.2", "build number = CFBundleVersion")
	assert_eq(str(cfg.get_value(ios, "application/code_sign_identity_release")), str(values["sign_identity"]))
	assert_eq(str(cfg.get_value(ios, "application/provisioning_profile_uuid_release")), str(values["profile_uuid"]))
	assert_eq(int(cfg.get_value(ios, "application/export_method_release")), 0, "App Store")
	assert_true(bool(cfg.get_value(ios, "application/export_project_only")), "xcodebuild runs in release.sh")
	assert_eq(str(cfg.get_value(mac, "application/bundle_identifier")), "org.primetimedungeon.game", "macOS untouched")
	assert_eq(ApplePreset.patch(cfg, "macos", values), "", "macOS values accepted")
	assert_eq(str(cfg.get_value(mac, "application/bundle_identifier")), "de.example.primetime")
	assert_eq(str(cfg.get_value(mac, "application/version")), "57.2")
	assert_eq(int(cfg.get_value(mac, "codesign/codesign")), 0, "Developer ID signature after the export")
	# Wrong values are refused before anything is written.
	var fresh: ConfigFile = ConfigFile.new()
	fresh.load(PRESETS)
	for bad: Dictionary in [{"team_id": "AB12CD34E"}, {"bundle_id": "de.example.prime_time"}, {"build": "57b"},
			{"sign_identity": "Apple Development: Example GmbH (AB12CD34EF)"},
			{"sign_identity": "Apple Distribution: Example GmbH (ZZ12CD34EF)"}, {"profile_uuid": "Prime Time"}]:
		assert_ne(ApplePreset.patch(fresh, "ios", values.merged(bad, true)), "", "refused: " + str(bad))
	assert_ne(ApplePreset.patch(fresh, "tvos", values), "", "unknown platform")
	assert_eq(str(fresh.get_value(ios, "application/app_store_team_id")), "XXXXXXXXXX", "nothing written")
	assert_eq(str(fresh.get_value(ios, "application/bundle_identifier")), "org.primetimedungeon.game")


func test_preset_versions_follow_the_project_version() -> void:
	var project_version: String = str(ProjectSettings.get_setting("application/config/version"))
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PRESETS)
	for section: String in cfg.get_sections():
		if not section.ends_with(".options"):
			continue
		for key: String in VERSION_KEYS:
			var value: String = str(cfg.get_value(section, key, ""))
			assert_true(value == "" or value == project_version,
				"%s %s = \"%s\", project version %s" % [section, key, value, project_version])


static func _preset_section(cfg: ConfigFile, preset_name: String) -> String:
	for section: String in cfg.get_sections():
		if not section.ends_with(".options") and str(cfg.get_value(section, "name", "")) == preset_name:
			return section
	return ""


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
