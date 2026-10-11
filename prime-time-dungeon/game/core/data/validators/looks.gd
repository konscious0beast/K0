# STUB(K0) — owned by 08-K2. Replace completely, keep the public API.
extends RefCounted
## Validation of data/looks.json (08 §6.1): one entry per look option (prefix lk_) with its category `kind` (hair,
## hair_color, skin, beard, glasses, outfit), a name and its value — `style` (hair / beard: ModelSpec.style ids),
## `color` (hair_color, skin: "#rrggbb") or `colors` (outfit: {"primary", "secondary"}). Private helper of DataValidator
## (no class_name; preloaded as LooksCheck). K0: schema + category; K2 adds the per-kind value rules.

const SPEC: Array = [["id", "s"], ["kind", "s"], ["name", "s"], ["style", "s", ""], ["color", "s", ""],
	["colors", "d", {}]]
const KINDS: PackedStringArray = ["hair", "hair_color", "skin", "beard", "glasses", "outfit"]


## One look entry ({} if not an object).
static func normalize(v: DataValidator, ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = v._norm(ctx, raw, SPEC)
	if d.is_empty():
		return d
	v._enum(ctx + ".kind", str(d["kind"]), KINDS)
	return d


## Cross-entry rules (per-kind values, exactly one canon per kind, …). Stub: none (K2).
static func check(_v: DataValidator) -> void:
	pass
