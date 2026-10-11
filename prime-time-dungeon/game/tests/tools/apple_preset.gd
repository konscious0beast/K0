extends SceneTree
## Writes the Apple release values into the macOS or iOS export preset (02_TECH §12.4, README "Mit
## Apple-Entwicklerkonto"). The CI jobs apple-macos / apple-ios-testflight run it on a temp copy of the project right
## before the export (tools/apple/release.sh export); the committed export_presets.cfg keeps its placeholders, so local
## and unsigned builds stay as they are. No class_name / autoload identifiers (§13.2 rule 4).
## godot --headless --path <copy of game> -s res://tests/tools/apple_preset.gd -- --platform=macos|ios
## Env (both): APPLE_TEAM_ID, APPLE_BUNDLE_ID, PTD_BUILD_NUMBER (CFBundleVersion); iOS also PTD_SIGN_IDENTITY (common
## name of the distribution certificate) and PTD_PROFILE_UUID (App Store provisioning profile). The marketing version
## (CFBundleShortVersionString) is application/config/version.
## Prints "APPLE_PRESET: <platform> <bundle id> <version> (<build>)", or "Assertion failed: apple_preset: …" and
## exits with 1.

const PRESETS: String = "res://export_presets.cfg"
const PRESET_NAMES: Dictionary = {"macos": "macOS", "ios": "iOS"}
const TEAM_RE: String = "^[A-Z0-9]{10}$"
const BUNDLE_RE: String = "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$"
const VERSION_RE: String = "^[0-9]{1,9}(\\.[0-9]{1,9}){0,2}$"   # CFBundleVersion / ShortVersionString: 1-3 integers
const UUID_RE: String = "^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$"
const IDENTITY_RE: String = "^(Apple|iPhone|iOS) Distribution: [^\"]+ \\(([A-Z0-9]{10})\\)$"


func _initialize() -> void:
	var platform: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--platform="):
			platform = a.trim_prefix("--platform=")
	var values: Dictionary = {
		"team_id": OS.get_environment("APPLE_TEAM_ID"),
		"bundle_id": OS.get_environment("APPLE_BUNDLE_ID"),
		"build": OS.get_environment("PTD_BUILD_NUMBER"),
		"short_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"sign_identity": OS.get_environment("PTD_SIGN_IDENTITY"),
		"profile_uuid": OS.get_environment("PTD_PROFILE_UUID"),
	}
	var cfg: ConfigFile = ConfigFile.new()
	var problem: String = "" if cfg.load(PRESETS) == OK else "cannot read " + PRESETS
	if problem == "":
		problem = patch(cfg, platform, values)
	if problem == "" and cfg.save(PRESETS) != OK:
		problem = "cannot write " + PRESETS
	if problem != "":
		printerr("Assertion failed: apple_preset: " + problem)
		quit(1)
		return
	print("APPLE_PRESET: %s %s %s (%s)" % [platform, values["bundle_id"], values["short_version"], values["build"]])
	quit(0)


## Sets the release values in the preset of `platform` ("macos" | "ios"). `values`: team_id, bundle_id, build,
## short_version, for iOS also sign_identity, profile_uuid. Returns "" or what is wrong (then nothing is written).
static func patch(cfg: ConfigFile, platform: String, values: Dictionary) -> String:
	if not PRESET_NAMES.has(platform):
		return "unknown --platform=\"%s\" (macos | ios)" % platform
	var team: String = str(values.get("team_id", ""))
	var bundle: String = str(values.get("bundle_id", ""))
	var build: String = str(values.get("build", ""))
	var short_version: String = str(values.get("short_version", ""))
	var identity: String = str(values.get("sign_identity", ""))
	var profile: String = str(values.get("profile_uuid", ""))
	var problems: PackedStringArray = []
	if not _matches(TEAM_RE, team):
		problems.append("APPLE_TEAM_ID must be the 10-character team ID (A-Z, 0-9)")
	if not _matches(BUNDLE_RE, bundle):
		problems.append("APPLE_BUNDLE_ID must be a reverse-DNS identifier (A-Z, a-z, 0-9, '-', '.')")
	if not _matches(VERSION_RE, build):
		problems.append("PTD_BUILD_NUMBER must be 1-3 period-separated integers")
	if not _matches(VERSION_RE, short_version):
		problems.append("application/config/version must be 1-3 period-separated integers")
	if platform == "ios":
		var m: RegExMatch = RegEx.create_from_string(IDENTITY_RE).search(identity)
		if m == null:
			problems.append("PTD_SIGN_IDENTITY must be an 'Apple Distribution: Name (TEAMID)' certificate")
		elif m.get_string(2) != team:
			problems.append("PTD_SIGN_IDENTITY belongs to another team than APPLE_TEAM_ID")
		if not _matches(UUID_RE, profile):
			problems.append("PTD_PROFILE_UUID must be the UUID of the provisioning profile")
	var section: String = _preset_section(cfg, str(PRESET_NAMES[platform]))
	if section == "":
		problems.append("export_presets.cfg has no %s preset" % PRESET_NAMES[platform])
	if not problems.is_empty():
		return "; ".join(problems)
	var opts: String = section + ".options"
	cfg.set_value(opts, "application/bundle_identifier", bundle)
	cfg.set_value(opts, "application/short_version", short_version)
	cfg.set_value(opts, "application/version", build)
	if platform == "macos":
		# The job signs with the Developer ID certificate (hardened runtime, timestamp) and notarizes afterwards; the
		# certificate carries the team (checked against APPLE_TEAM_ID by release.sh).
		cfg.set_value(opts, "codesign/codesign", 0)
		cfg.set_value(opts, "notarization/notarization", 0)
	else:
		cfg.set_value(opts, "application/app_store_team_id", team)
		cfg.set_value(opts, "application/export_method_release", 0)          # App Store
		cfg.set_value(opts, "application/code_sign_identity_release", identity)  # → CODE_SIGN_STYLE = Manual
		cfg.set_value(opts, "application/provisioning_profile_uuid_release", profile)
		cfg.set_value(opts, "application/provisioning_profile_specifier_release", profile)
		cfg.set_value(opts, "application/export_project_only", true)          # xcodebuild runs in release.sh
	return ""


static func _matches(pattern: String, value: String) -> bool:
	return RegEx.create_from_string(pattern).search(value) != null


static func _preset_section(cfg: ConfigFile, preset_name: String) -> String:
	for section: String in cfg.get_sections():
		if not section.ends_with(".options") and str(cfg.get_value(section, "name", "")) == preset_name:
			return section
	return ""
