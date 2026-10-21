class_name PersonaLook extends RefCounted
## The persona's look on the kai model (08 §6.1–6.3, K2): a pure merge of the look ids (data/looks.json — hair style,
## hair colour, skin tone, beard, glasses, outfit and, 11-A1, wear; {kind: lk id}) into a ModelSpec: style {"hair",
## "beard"} (humanoid only), the "glasses" prop, the clothing prop of `wear` (jacket, bathrobe, shorts or sandals —
## at most one; "none" takes them all off), and the colour slots accent (hair, also headscarf and beard), skin and
## primary / secondary (outfit). A missing or unknown id — or the id of another kind — counts as that kind's canon
## option (08 §2.5: shown as canon). The canon look leaves Kai's model exactly as party.json has it (no style key,
## the same colour strings), so its meshes are the cached canon meshes. Callers: DB.party_model (the running
## persona) and the casting / card previews (scenes/ui/scene_kit.gd look_figure). The persona's wear and glasses
## combine freely: the heaviest combination stays within CR-22 (≤ 3 000 tris, 7 meshes; test_11_art_kit). 11-A1:
## the persona file and the casting carry the six kinds of 08 §6.1 (PersonaProfile.LOOK_KINDS); `wear` is OPTIONAL —
## a look without it wears the canon option, and ids() lists it only when the look names it.

const KINDS: PackedStringArray = ["hair", "hair_color", "skin", "beard", "glasses", "outfit",
	"wear"]                                     # 11-A1 (11 §4.10)
const GLASSES_PROP: String = "glasses"
const GLASSES_ON: String = "round"
const DEFAULT_HAIR: String = "short"
const DEFAULT_BEARD: String = "none"
## 11-A1: the clothing props a `wear` option puts on (its style; "none" = none of them).
const WEAR_PROPS: PackedStringArray = ["jacket", "bathrobe", "shorts", "sandals"]
const WEAR_NONE: String = "none"
## 11-A1: kinds a look may leave out — ids() lists them only when the look names them (the persona file, the casting and
## the full run's casting line keep their six kinds until a casting package offers wear).
const OPTIONAL_KINDS: PackedStringArray = ["wear"]


## A copy of `model` with the look applied (non-humanoid models and a data set without looks: an unchanged copy).
static func apply(model: Dictionary, look: Dictionary, data: GameData) -> Dictionary:
	var out: Dictionary = model.duplicate(true)
	if data == null or str(out.get("base", "humanoid")) != "humanoid":
		return out
	var colors: Dictionary = (out.get("colors", {}) as Dictionary).duplicate() if out.get("colors", {}) is Dictionary \
		else {}
	var style: Dictionary = (out.get("style", {}) as Dictionary).duplicate() if out.get("style", {}) is Dictionary \
		else {}
	var props: PackedStringArray = PackedStringArray(Array(out.get("props", [])))
	var changed: bool = false
	for kind: String in KINDS:
		var e: Dictionary = entry(data, kind, str(look.get(kind, "")))
		if e.is_empty():
			continue
		changed = true
		match kind:
			"hair", "beard":
				style[kind] = str(e.get("style", ""))
			"glasses":
				var on: bool = str(e.get("style", "")) == GLASSES_ON
				if on and not props.has(GLASSES_PROP):
					props.append(GLASSES_PROP)
				elif not on and props.has(GLASSES_PROP):
					props.remove_at(props.find(GLASSES_PROP))
			"wear":
				var wear: String = str(e.get("style", WEAR_NONE))
				for w: String in WEAR_PROPS:
					if w != wear and props.has(w):
						props.remove_at(props.find(w))
				if WEAR_PROPS.has(wear) and not props.has(wear):
					props.append(wear)
			"hair_color":
				colors["accent"] = _hex(e.get("color", ""))
			"skin":
				colors["skin"] = _hex(e.get("color", ""))
			"outfit":
				var c: Dictionary = e.get("colors", {})
				colors["primary"] = _hex(c.get("primary", ""))
				colors["secondary"] = _hex(c.get("secondary", ""))
	if not changed:
		return out
	out["colors"] = colors
	if out.get("props", []) is PackedStringArray:
		out["props"] = props
	else:
		out["props"] = Array(props)
	if str(style.get("hair", DEFAULT_HAIR)) == DEFAULT_HAIR and str(style.get("beard", DEFAULT_BEARD)) == DEFAULT_BEARD:
		out.erase("style")                       # the canon style is no style (the def model's exact form)
	else:
		out["style"] = {"hair": str(style.get("hair", DEFAULT_HAIR)), "beard": str(style.get("beard", DEFAULT_BEARD))}
	return out


## The entry of `id` if it is a look of `kind`, else the canon option of the kind ({} if the data has none).
static func entry(data: GameData, kind: String, id: String) -> Dictionary:
	if data == null:
		return {}
	var e: Dictionary = data.look(id) if id != "" else {}
	if not e.is_empty() and str(e.get("kind", "")) == kind:
		return e
	return data.look_canon(kind)


## The ids of `look` (one per kind; an OPTIONAL_KINDS kind only when `look` has it) with every missing / unknown /
## foreign id replaced by its kind's canon id.
static func ids(look: Dictionary, data: GameData) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in KINDS:
		if OPTIONAL_KINDS.has(kind) and not look.has(kind):
			continue
		var e: Dictionary = entry(data, kind, str(look.get(kind, "")))
		if not e.is_empty():
			out[kind] = str(e["id"])
	return out


## The display colour of a look option (hair colour / skin: its colour, outfit: primary; else transparent).
static func swatch(e: Dictionary) -> Color:
	if str(e.get("color", "")) != "":
		return Color(str(e["color"]))
	var c: Dictionary = e.get("colors", {})
	return Color(str(c["primary"])) if c.has("primary") else Color(0, 0, 0, 0)


static func _hex(v: Variant) -> String:
	return str(v).to_lower()
