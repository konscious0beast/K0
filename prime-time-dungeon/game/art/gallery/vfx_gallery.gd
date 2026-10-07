extends Node3D
## VFX gallery (02_TECH §1.5, CI screenshot target §12.4): every Vfx kind in a loop on a grid plus all damage-number
## styles. Spawn times are staggered so that a capture after ~2 s (check.sh --shot … 120) shows every effect mid-flight.

const Stage := preload("res://art/gallery/gallery_stage.gd")
const COLS: int = 6
const SPACING: float = 2.6
## Fraction of each effect's duration at which it is frozen for a stable still (capture after ~2 s).
const FREEZE_AT: Dictionary = {&"sponsor": 0.82, &"levelup": 0.5, &"stairs_glow": 0.9, &"confetti": 0.35}

var _params: Dictionary = {}
var _frame: int = 0
var _live: Dictionary = {}           # kind → effect node (frozen after FREEZE_AT)
var _numbers: Array[Label3D] = []
var _anchors: Dictionary = {}        # kind → Vector3


func setup(params: Dictionary) -> void:
	_params = params


func _ready() -> void:
	Stage.add_world(self, "metro", {}, &"battle", &"high", 0.3)
	Stage.add_floor(self, 11.0, {})
	var i: int = 0
	for kind: StringName in Vfx.KINDS:
		var col: int = i % COLS
		var row: int = i / COLS
		var pos := Vector3(-SPACING * (float(COLS) - 1.0) * 0.5 + SPACING * float(col), 0.0, -5.4 + 2.6 * float(row))
		if kind == &"ko":
			pos.y = 1.2
		if kind == &"slash" or kind == &"bite" or kind == &"hit" or kind == &"crit":
			pos.y = 0.9
		_anchors[kind] = pos
		var lbl: Label3D = Stage.label(self, String(kind), Vector3(pos.x, 0.05, pos.z + 0.9), 34, Palette.HYPE_GOLD)
		lbl.no_depth_test = false
		i += 1
	Stage.add_camera(self, Vector3(0, 8.5, 9.5), Vector3(0, 0.3, -1.6), 50.0)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 3:
		for kind: StringName in Vfx.KINDS:
			_live[kind] = Vfx.spawn(kind, self, _anchors[kind] as Vector3)
		var samples: Array = [["127", &"damage"], ["348", &"crit"], ["+45", &"heal"], ["12", &"mp"], ["", &"miss"],
			["96", &"weak"], ["8", &"resist"], ["Gift", &"status"]]
		for k in samples.size():
			var entry: Array = samples[k]
			Vfx.damage_number(self, Vector3(-6.3 + 1.8 * float(k), 0.8, 3.4), str(entry[0]), entry[1] as StringName)
	# freeze every effect at a characteristic moment (deterministic stills, independent of the frame rate)
	for kind: Variant in _live.keys():
		var n: Node3D = _live[kind]
		if n == null or not bool(n.get("active")):
			continue
		if float(n.call("progress")) >= float(FREEZE_AT.get(kind, 0.4)):
			n.call("freeze")
	for c: Node in get_children():
		if c is Label3D and c.has_method("freeze") and bool(c.get("active")) and float(c.get("_t")) >= 0.3:
			c.call("freeze")
