class_name GameSettings extends RefCounted
## Player settings, persisted in user://settings.cfg (02_TECH §3.4). Ephemeral runs (tests, autoplay, capture)
## keep the defaults and never touch the disk.

const PATH: String = "user://settings.cfg"
const MOD_LIVE_MODES: Array[StringName] = [&"off", &"lines", &"lines_twists"]   # 06-D

var master_volume: float = 0.8              # audio/master, 0..1
var music_volume: float = 0.6               # audio/music
var sfx_volume: float = 0.8                 # audio/sfx
var battle_speed: float = 1.0               # game/battle_speed ∈ {1.0, 2.0}
var text_speed: int = 1                     # game/text_speed: 0 slow / 1 normal / 2 instant
var auto_battle_default: bool = false       # game/auto_battle_default
var fullscreen: bool = false                # display/fullscreen
var quality: StringName = &"high"           # display/quality: &"high" | &"low" (mobile default &"low")
var touch_controls: StringName = &"auto"    # display/touch_controls: &"auto" | &"on" | &"off"
var show_fps: bool = false                  # display/show_fps
var camera_invert_x: bool = false           # input/camera_invert_x
var camera_invert_y: bool = false           # input/camera_invert_y
var camera_sensitivity: float = 1.0         # input/camera_sensitivity, 0.25..3.0
# --- 06-D (KI-Admin) ---
var regie_twists: bool = true               # game/regie_twists: offline Regie twists from floor 2 (06 §5.7a)
var mod_live: StringName = &"off"           # live/mod_live: &"off" | &"lines" | &"lines_twists" (06 §5.3, opt-in)
var mod_live_url: String = ""               # live/mod_live_url: mod-brain base URL (debug builds / --mod-live-url=)
# true: save_to_disk() is a no-op returning OK, load_from_disk() keeps defaults
var ephemeral: bool = false


func _init() -> void:
	reset_defaults()


## Restores all defaults (platform dependent quality).
func reset_defaults() -> void:
	master_volume = 0.8
	music_volume = 0.6
	sfx_volume = 0.8
	battle_speed = 1.0
	text_speed = 1
	auto_battle_default = false
	fullscreen = false
	quality = &"low" if OS.has_feature("mobile") else &"high"
	touch_controls = &"auto"
	show_fps = false
	camera_invert_x = false
	camera_invert_y = false
	camera_sensitivity = 1.0
	regie_twists = true
	mod_live = &"off"
	mod_live_url = ""


## Reads user://settings.cfg (missing file → defaults). No-op when ephemeral.
func load_from_disk() -> void:
	if ephemeral:
		return
	var cfg: ConfigFile = ConfigFile.new()
	if not FileAccess.file_exists(PATH):
		return
	if cfg.load(PATH) != OK:
		push_warning("[GameSettings] could not read %s, using defaults" % PATH)
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	battle_speed = 2.0 if float(cfg.get_value("game", "battle_speed", battle_speed)) >= 1.5 else 1.0
	text_speed = clampi(int(cfg.get_value("game", "text_speed", text_speed)), 0, 2)
	auto_battle_default = bool(cfg.get_value("game", "auto_battle_default", auto_battle_default))
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	var q: StringName = StringName(str(cfg.get_value("display", "quality", quality)))
	quality = q if (q == &"high" or q == &"low") else quality
	var tc: StringName = StringName(str(cfg.get_value("display", "touch_controls", touch_controls)))
	touch_controls = tc if (tc == &"auto" or tc == &"on" or tc == &"off") else touch_controls
	show_fps = bool(cfg.get_value("display", "show_fps", show_fps))
	camera_invert_x = bool(cfg.get_value("input", "camera_invert_x", camera_invert_x))
	camera_invert_y = bool(cfg.get_value("input", "camera_invert_y", camera_invert_y))
	camera_sensitivity = clampf(float(cfg.get_value("input", "camera_sensitivity", camera_sensitivity)), 0.25, 3.0)
	regie_twists = bool(cfg.get_value("game", "regie_twists", regie_twists))
	var ml: StringName = StringName(str(cfg.get_value("live", "mod_live", mod_live)))
	mod_live = ml if MOD_LIVE_MODES.has(ml) else &"off"
	mod_live_url = str(cfg.get_value("live", "mod_live_url", mod_live_url)) if OS.is_debug_build() else ""


## Writes user://settings.cfg. Ephemeral: returns OK without writing.
func save_to_disk() -> Error:
	if ephemeral:
		return OK
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "battle_speed", battle_speed)
	cfg.set_value("game", "text_speed", text_speed)
	cfg.set_value("game", "auto_battle_default", auto_battle_default)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "quality", String(quality))
	cfg.set_value("display", "touch_controls", String(touch_controls))
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("input", "camera_invert_x", camera_invert_x)
	cfg.set_value("input", "camera_invert_y", camera_invert_y)
	cfg.set_value("input", "camera_sensitivity", camera_sensitivity)
	cfg.set_value("game", "regie_twists", regie_twists)
	cfg.set_value("live", "mod_live", String(mod_live))
	cfg.set_value("live", "mod_live_url", mod_live_url)
	return cfg.save(PATH)


func to_dict() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"battle_speed": battle_speed,
		"text_speed": text_speed,
		"auto_battle_default": auto_battle_default,
		"fullscreen": fullscreen,
		"quality": quality,
		"touch_controls": touch_controls,
		"show_fps": show_fps,
		"camera_invert_x": camera_invert_x,
		"camera_invert_y": camera_invert_y,
		"camera_sensitivity": camera_sensitivity,
		"regie_twists": regie_twists,
		"mod_live": mod_live,
		"mod_live_url": mod_live_url,
	}
