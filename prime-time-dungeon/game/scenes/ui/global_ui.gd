extends Node
## Persistent UI (02_TECH §9.4): ShowOverlay (layer 40), ModDialog + Toasts (45), DebugOverlay (90). Added once under
## root by Boot (and by capture.gd), PROCESS_MODE_ALWAYS, outside the Router stack. Display mode follows
## Events.overlay_mode_requested; the initial mode is derived from the active screen (scenes that requested a mode before
## GlobalUi existed, e.g. in captures). Also caches the last event-run summary (Events.run_finished) for RunResult.

const SHOW_OVERLAY: String = "res://scenes/ui/show_overlay.tscn"
const MOD_DIALOG: String = "res://scenes/ui/mod_dialog.tscn"
const ToastStack := preload("res://scenes/ui/toast_stack.gd")
const DebugOverlay := preload("res://scenes/ui/debug_overlay.gd")
const RunResultScript := preload("res://scenes/ui/run_result.gd")

var show_overlay: CanvasLayer
var mod_dialog: CanvasLayer
var toasts: CanvasLayer
var debug_overlay: CanvasLayer

var _params: Dictionary = {}


## Optional: {"capture": true} → demo still (overlay with sample numbers, a M.O.D. line, a toast).
func setup(params: Dictionary) -> void:
	_params = params


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# Exactly one GlobalUi: a second instance (e.g. capture.gd adding one next to a GlobalUi still) removes itself.
	if get_parent() != null:
		for n: Node in get_parent().get_children():
			if n != self and n.get_script() == get_script():
				queue_free()
				return
	var capture: bool = bool(_params.get("capture", false))
	show_overlay = (load(SHOW_OVERLAY) as PackedScene).instantiate() as CanvasLayer
	show_overlay.name = "ShowOverlay"
	show_overlay.call("setup", {"capture": capture})
	add_child(show_overlay)
	mod_dialog = (load(MOD_DIALOG) as PackedScene).instantiate() as CanvasLayer
	mod_dialog.name = "ModDialog"
	mod_dialog.call("setup", {"capture": capture})
	add_child(mod_dialog)
	toasts = ToastStack.new()
	toasts.name = "Toasts"
	add_child(toasts)
	debug_overlay = DebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)
	Events.run_finished.connect(_on_run_finished)
	if capture:
		toasts.call("push_toast", "Erster Kill", &"achievement")
	else:
		show_overlay.call("set_mode", initial_mode())


## Screen rects (canvas coordinates) the persistent UI currently covers — hype meter, sponsor lower third, viewer-gift
## banner, toasts, M.O.D. box — empty ones left out (M5 CR 1: battle UI places menus/plates around them instead of
## hard-coded positions). The instance under root is found with `get_tree().root.get_node_or_null("GlobalUi")`.
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cands: Array[Rect2] = []
	if show_overlay != null:
		for m: String in ["hype_rect", "lower_third_rect", "gift_banner_rect"]:
			cands.append(show_overlay.call(m) as Rect2)
	if toasts != null:
		cands.append(toasts.call("stack_rect") as Rect2)
	if mod_dialog != null:
		cands.append(mod_dialog.call("box_rect") as Rect2)
	for r: Rect2 in cands:
		if r.size.x > 0.0 and r.size.y > 0.0:
			out.append(r)
	return out


## Overlay mode for the active screen (Router.current): exploration / battle / safe room, else menu.
static func initial_mode() -> StringName:
	var cur: Node = Router.current
	if cur is ExplorationScene:
		return &"explore"
	if cur is BattleScene:
		return &"battle"
	if cur is SafeRoomScene:
		return &"safe_room"
	return &"menu"


func _on_run_finished(summary: Dictionary) -> void:
	RunResultScript.last_summary = summary.duplicate(true)
