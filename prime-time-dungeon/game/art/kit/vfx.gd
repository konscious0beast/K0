# STUB(M0) — owned by M4. Replace completely, keep the public API.
class_name Vfx extends RefCounted
## Effects + damage numbers (02_TECH §8.6).

const KINDS: Array[StringName] = [&"hit", &"crit", &"slash", &"bite", &"magic", &"fire", &"ice", &"shock", &"toxic",
	&"light", &"dark", &"heal", &"buff", &"debuff", &"ko", &"levelup", &"sponsor", &"confetti", &"smoke", &"sparkle",
	&"stairs_glow", &"chest_open"]


## Pooled (4 instances per kind per parent); callers NEVER free the returned node. color.a == 0 → kind default.
static func spawn(kind: StringName, parent: Node, at: Vector3, color: Color = Color(0, 0, 0, 0), scale: float = 1.0) -> Node3D:
	return null


## 0.3 .. 1.5 s
static func duration(kind: StringName) -> float:
	return 0.3


## skill.vfx or element default (see 02_TECH §8.6).
static func for_skill(skill: SkillDef) -> StringName:
	return &"hit"


## Label3D billboard; style &"damage", &"crit", &"heal", &"mp", &"miss", &"weak", &"resist", &"status"
static func damage_number(parent: Node, at: Vector3, text: String, style: StringName) -> void:
	pass
