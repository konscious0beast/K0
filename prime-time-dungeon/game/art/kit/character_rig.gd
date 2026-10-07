# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name CharacterRig extends Node3D
## Standard animation interface of all characters (02_TECH §8.4).

signal impact                                  # contact moment of attack/cast/stunt/item
signal anim_finished(anim: StringName)

const ANIMS: Array[StringName] = [&"idle", &"walk", &"run", &"attack", &"cast", &"hit", &"die", &"victory", &"defend", &"stunt", &"item"]
const LOOPING: Array[StringName] = [&"idle", &"walk", &"run", &"victory", &"defend"]

var model: Dictionary = {}
var height: float = 1.0                        # top of head in local Y (for UI/number anchors)


func play(anim: StringName, speed: float = 1.0) -> void:
	pass


## Coroutine; loops return immediately; outside the tree: end pose at once, impact + anim_finished, push_warning.
func play_and_wait(anim: StringName, speed: float = 1.0) -> void:
	if not LOOPING.has(anim):
		if anim == &"attack" or anim == &"cast" or anim == &"stunt" or anim == &"item":
			impact.emit()
		anim_finished.emit(anim)


func current_anim() -> StringName:
	return &"idle"


## < 0.2 idle, < 5.5 walk (cadence scales), else run
func set_locomotion(speed_mps: float) -> void:
	pass


func flash(color: Color = Color.WHITE, duration: float = 0.12) -> void:
	pass


func set_highlight(on: bool) -> void:
	pass


func set_dissolve(amount: float) -> void:
	pass


## Instant KO pose (no anim), for loading/standalone states.
func set_dead(dead: bool) -> void:
	pass


## &"head", &"center", &"overhead", &"hand_r", &"hand_l", &"feet"
func anchor(anchor_name: StringName) -> Node3D:
	return self


func face_towards(world_pos: Vector3) -> void:
	pass


func reset_pose() -> void:
	pass


## Emits impact; called by procedural tweens and AnimationPlayer method tracks.
func emit_impact() -> void:
	impact.emit()
