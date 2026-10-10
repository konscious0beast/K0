extends RefCounted
## Player-facing texts and icons of talents (06 §2.2) for the Talent-Show, the party page and the battle results.
## Private helper (no class_name, §0.3), used via preload. The numbers always come from the effects in talents.json,
## so a card can never promise something else than the rule does.

const UiUtil := preload("res://scenes/ui/ui_util.gd")

## TalentDef.ICONS → UiIcon kind.
const ICON_KINDS: Dictionary = {"hp": &"heart", "mp": &"potion", "atk": &"fist", "mag": &"bolt", "def": &"shield",
	"res": &"ring", "spd": &"clock", "lck": &"diamond", "crit": &"star", "element": &"snow", "show": &"camera",
	"field": &"hand", "stunt": &"mic", "liga": &"person"}
const VALUE_COLOR: Color = Color("#4ade80")      # numbers (UiTheme.C_OK)
const BEHAVIOUR_COLOR: Color = Color("#22d3ee")  # "plays differently" (UiTheme.C_ACCENT_2)
const ROMAN: PackedStringArray = ["", "", " II", " III"]
const FIELD_ABILITY: Dictionary = {"kai": "Feldschlag", "mopsula": "Bellen"}


## UiIcon kind of a talent icon id.
static func icon_kind(icon: String) -> StringName:
	return ICON_KINDS.get(icon, &"star") as StringName


## Green for value talents, cyan for behaviour talents.
static func color_of(def: TalentDef) -> Color:
	return BEHAVIOUR_COLOR if def != null and def.is_behaviour() else VALUE_COLOR


## "VERHALTEN" (plays differently) or "WERT" (a number grows) — the small tag on a card.
static func kind_tag(def: TalentDef) -> String:
	return "VERHALTEN" if def != null and def.is_behaviour() else "WERT"


## One readable line per effect, e.g. "Stärke +2", "HP +5 %", "Feldschlag reicht 25 % weiter".
static func effect_text(fx: Dictionary, member_id: String = "") -> String:
	var pm: int = int(fx.get("pm", 1000))
	var stat: String = str(UiUtil.STAT_NAMES.get(str(fx.get("stat", "")), str(fx.get("stat", ""))))
	var ability: String = str(FIELD_ABILITY.get(member_id, "Feldfähigkeit"))
	match str(fx.get("kind", "")):
		"stat_flat":
			return "%s +%d" % [stat, int(fx.get("value", 0))]
		"stat_pct":
			return "%s +%s %%" % [stat, _pct(pm)]
		"crit_add_pm":
			return "Kritische Treffer +%s %%" % _pct(pm)
		"element_pm":
			var el: String = str(UiUtil.ELEMENT_NAMES.get(str(fx.get("element", "")), "?"))
			return "%s-Schaden -%s %%" % [el, _pct(1000 - pm)]
		"post_battle_mp_pm":
			return "+%s %% MP nach jedem Sieg" % _pct(pm)
		"field_range_pm":
			return "%s reicht %s %% weiter" % [ability, _pct(pm - 1000)]
		"field_cd_pm":
			return "%s %s %% schneller wieder bereit" % [ability, _pct(1000 - pm)]
		"preemptive_dmg_pm":
			return "Nach Präventivschlag: 1. Zug +%s %% Schaden" % _pct(pm - 1000)
		"stunt_window_pm":
			return "Stunts gelingen %s %% öfter" % _pct(pm - 1000)
		"marotte_heart":
			return "1× je Etage: +%d Herz für M.O.D.s Vorliebe" % int(fx.get("per_floor", 1))
		"liga_stat_pct":
			return "Ohne Rüstung & ohne Accessoire: %s +%s %%" % [stat, _pct(pm)]
		"hype_gain_pm":
			return "Hype +%s %%" % _pct(pm - 1000)
		"follower_pm":
			return "Follower +%s %%" % _pct(pm - 1000)
	return str(fx.get("kind", ""))


## All effects of a talent joined with " · ".
static func effects_line(def: TalentDef, member_id: String = "") -> String:
	if def == null:
		return ""
	var parts: PackedStringArray = []
	for fx: Dictionary in def.effects:
		parts.append(effect_text(fx, member_id))
	return " · ".join(parts)


## "Wischtechnik II" (rank 2), "Wischtechnik" (rank 1).
static func ranked_name(def: TalentDef, rank: int) -> String:
	if def == null:
		return ""
	return UiUtil.tr_text(def.name) + ROMAN[clampi(rank, 0, ROMAN.size() - 1)]


## Picked talents of a member in id order: ["Wischtechnik II", "Bissfest"].
static func member_talents(member: PartyMember) -> PackedStringArray:
	var out: PackedStringArray = []
	if member == null:
		return out
	var ids: Array = member.talents.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for id: Variant in ids:
		if DB.has_id("talents", str(id)):
			out.append(ranked_name(DB.talent(str(id)), int(member.talents[id])))
	return out


## 50 ‰ → "5", 250 → "25", 15 → "1,5" (German decimal comma).
static func _pct(pm: int) -> String:
	var tenths: int = absi(pm)
	if tenths % 10 == 0:
		return str(tenths / 10)
	return "%d,%d" % [tenths / 10, tenths % 10]
