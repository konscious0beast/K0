# STUB(K0) — owned by 08-K1. Replace completely, keep the public API.
class_name PersonaText extends RefCounted
## Pure text helpers of the persona (08 §4.4, §5.6, §7): the placeholder context of M.O.D. lines ({cand}, {job},
## {hobby}, {club}, {trait}, {rival}, {brand}), the card sentence of a talent, name / free-text checks, AI line
## filter. K0: ctx() answers with the fallback values of 08 §4.4 (so a persona line never shows a raw "{job}"); the
## rest are neutral stubs that K1 fills.

## Fallbacks of 08 §4.4 (no persona, canon "Rest automatisch", unknown ids).
const FALLBACK: Dictionary = {"cand": "Kandidat:in", "job": "Tierpfleger:in", "hobby": "Freizeit",
	"club": "Ihr Freundeskreis", "trait": "undurchschaubar"}
## Placeholders the persona context provides ({name} stays Show's: the display name).
const KEYS: PackedStringArray = ["cand", "job", "hobby", "club", "trait", "rival", "brand"]


## Placeholder values for `p` (null = canon). `rng`: a presentation RNG (Show._fx_rng) for the changing values
## ({trait}); null (UiUtil.format_line) → the first value, no draw. Stub: the fallbacks; rival / brand of the canon
## origin.
static func ctx(_p: PersonaProfile, data: GameData, _rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = FALLBACK.duplicate()
	var origin: Dictionary = data.origin(str(data.persona_canon().get("origin", ""))) if data != null else {}
	var rivals: PackedStringArray = JsonUtil.to_str_array(origin.get("rivals", []))
	out["rival"] = str(data.persona_entry("rivals", rivals[0]).get("name", "")) if not rivals.is_empty() else ""
	var brand: String = str(origin.get("brand", ""))
	out["brand"] = str(data.persona_entry("brands", brand).get("name", "")) if brand != "" else ""
	return out


## The card sentence of a talent from its effects (<= 90 characters, 08 §3.3). Stub: "".
static func plain_line(_def: TalentDef) -> String:
	return ""


## "" or the reason sentence why a name cannot be broadcast (08 D-3). Stub: "".
static func check_name(_name: String) -> String:
	return ""


## "" or the reason sentence for a free text (PII patterns, word lists, length; 08 D-4). Stub: "".
static func check_free_text(_text: String, _max_len: int) -> String:
	return ""


## The origin tile closest to a rejected free text (08 §1.2). Stub: "".
static func nearest_tile(_data: GameData, _rejected_text: String, _reason: String) -> String:
	return ""


## AI lines that pass the filters (08 §5.6). Stub: none.
static func filter_ai_lines(_lines: Array, _data: GameData) -> Array:
	return []
