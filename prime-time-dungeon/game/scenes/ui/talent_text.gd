extends RefCounted
## Player-facing texts and icons of talents (06 §2.2) for the Talent-Show, the party page and the battle results.
## Private helper (no class_name, §0.3), used via preload. The numbers always come from the effects in talents.json,
## so a card can never promise something else than the rule does. Staffeln (09 §8.4, ST1-D): the talent tree — the
## rt_mod effects (RtMods of the own unit), the kinds of the rows, the captions of the columns (branches of a class
## row, Angriff / Show / Schutz of a figure row) and the picks of the tree in the member's list.

const UiUtil := preload("res://scenes/ui/ui_util.gd")

## TalentDef.ICONS → UiIcon kind.
const ICON_KINDS: Dictionary = {"hp": &"heart", "mp": &"potion", "atk": &"fist", "mag": &"bolt", "def": &"shield",
	"res": &"ring", "spd": &"clock", "lck": &"diamond", "crit": &"star", "element": &"snow", "show": &"camera",
	"field": &"hand", "stunt": &"mic", "liga": &"person"}
const VALUE_COLOR: Color = Color("#4ade80")      # numbers (UiTheme.C_OK)
const BEHAVIOUR_COLOR: Color = Color("#22d3ee")  # "plays differently" (UiTheme.C_ACCENT_2)
const ROMAN: PackedStringArray = ["", "", " II", " III"]
const FIELD_ABILITY: Dictionary = {"kai": "Feldschlag", "mopsula": "Bellen"}
## The branches (Spezialisierungen) of the class rows (09 §8.4, working titles) by their id in talents.json `spec`.
const SPEC_NAMES: Dictionary = {"bollwerk": "Bollwerk", "abriss": "Abrissunternehmen", "schnellzug": "Schnellzug",
	"weiche": "Weichensteller:in", "bastelbude": "Bastelbude", "kurzschluss": "Kurzschluss",
	"publikum": "Publikumsmagnet", "stuntdouble": "Stuntdouble", "feuerwerk": "Feuerwerk", "gewitter": "Gewitterzelle",
	"notaufnahme": "Notaufnahme", "kurkonzert": "Kurkonzert", "fluchkanzlei": "Fluchkanzlei",
	"spukschloss": "Spukschloss", "protokoll": "Protokoll", "gala": "Mitternachtsgala"}
## The columns of a figure row (09 §8.4: Angriff / Show / Schutz) and the middle column of a class row.
const FIGURE_COLS: PackedStringArray = ["Angriff", "Show", "Schutz"]
## rt_mod "on" events → the start of the sentence ("Je besiegtem Gegner: +4 MP").
const MOD_EVENT_TEXT: Dictionary = {"kill": "Je besiegtem Gegner", "show_success": "Gelungene SHOW",
	"interrupt": "Je Unterbrechung", "ko_ally": "Fällt ein Verbündeter", "combat_start": "Zu Kampfbeginn",
	"dodge": "Je Ausweichen", "crit": "Je kritischem Treffer"}
const MOD_FIELD_TEXT: Dictionary = {"cooldown": "Abklingzeit", "cast": "Zauberzeit", "mp": "MP"}


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
		"preemptive_dmg_pm":                     # R5b-2a: worded for both combat modes (07 §9.6)
			return "Nach Präventivschlag: erste Treffer +%s %% Schaden" % _pct(pm - 1000)
		"stunt_window_pm":
			return "Stunts und SHOW gelingen %s %% öfter" % _pct(pm - 1000)
		"marotte_heart":
			return "1× je Etage: +%d Herz für M.O.D.s Vorliebe" % int(fx.get("per_floor", 1))
		"liga_stat_pct":
			return "Ohne Rüstung & ohne Accessoire: %s +%s %%" % [stat, _pct(pm)]
		"hype_gain_pm":
			return "Hype +%s %%" % _pct(pm - 1000)
		"follower_pm":
			return "Follower +%s %%" % _pct(pm - 1000)
		"rt_mod":                                # Staffeln (09 §8.4, ST1-D): the tree's modifiers of the own unit
			return mod_text(fx)
	return str(fx.get("kind", ""))


## One line for an rt_mod effect (07 §9.5): "Schaden +5 %", "Abrissbirne +15 % Kraft", "Spott: Abklingzeit -20 %",
## "Je besiegtem Gegner: +4 MP".
static func mod_text(fx: Dictionary) -> String:
	var pm: int = int(fx.get("pm", 1000))
	match str(fx.get("op", "")):
		"dmg_dealt_pm":
			return "Schaden +%s %%" % _pct(pm - 1000)
		"dmg_taken_pm":
			return "Erlittener Schaden -%s %%" % _pct(1000 - pm)
		"heal_taken_pm":
			return "Heilung an Ihnen +%s %%" % _pct(pm - 1000)
		"first_hit_taken_pm":
			return "Erster Treffer je Kampf -%s %%" % _pct(1000 - pm)
		"move_pm":
			return "Lauftempo +%s %%" % _pct(pm - 1000)
		"swing_pm":
			return "Auto-Angriff %s %% schneller" % _pct(1000 - pm)
		"threat_pm":
			return "Bedrohung %s%s %%" % ["+" if pm >= 1000 else "-", _pct(absi(pm - 1000))]
		"stat_pm":
			var st: String = str(fx.get("stat", ""))
			var key: String = st.trim_prefix("max_")
			return "%s +%s %%" % [str(UiUtil.STAT_NAMES.get(key, key)), _pct(pm - 1000)]
		"skill_pm":
			var sid: String = str(fx.get("skill", ""))
			var sd: SkillDef = UiUtil.skill_def(sid) if sid != "*" else null
			var who: String = "Alle Fähigkeiten" if sid == "*" else (UiUtil.tr_text(sd.name) if sd != null else sid)
			var field: String = str(fx.get("field", "power"))
			if field == "power":
				return "%s +%s %% Kraft" % [who, _pct(pm - 1000)]
			return "%s: %s -%s %%" % [who, str(MOD_FIELD_TEXT.get(field, field)), _pct(1000 - pm)]
		"on":
			var when: String = str(MOD_EVENT_TEXT.get(str(fx.get("event", "")), str(fx.get("event", ""))))
			var eff: Dictionary = fx.get("effect", {}) as Dictionary if fx.get("effect", {}) is Dictionary else {}
			if eff.has("mp"):
				return "%s: +%d MP" % [when, int(eff["mp"])]
			if eff.has("heal_pct"):
				return "%s: +%d %% HP" % [when, int(eff["heal_pct"])]
			if eff.has("status"):
				var sts: String = str(eff["status"])
				var nm: String = DB.status(sts).name if DB.has_id("statuses", sts) else sts
				return "%s: %s %s" % [when, nm, _seconds(int(eff.get("ms", 0)))]
			return when
	return str(fx.get("op", ""))


## "Grundreihe" (3/5/7/9), "Klassenreihe" (15/25/35/45), "Figurenreihe" (20/30/40/50) — 09 §8.4.
static func row_kind(row: int) -> String:
	if TalentDef.CLASS_ROWS.has(row):
		return "Klassenreihe"
	if TalentDef.FIGURE_ROWS.has(row):
		return "Figurenreihe"
	return "Grundreihe"


## The caption of a tree talent's column: the branch of an outer class column, "Show" in the middle of a class row,
## Angriff / Show / Schutz in a figure row; "" in a base row.
static func col_caption(def: TalentDef) -> String:
	if def == null or not def.is_tree():
		return ""
	if TalentDef.CLASS_ROWS.has(def.row):
		return spec_name(def.spec) if def.spec != "" else "Show"
	if TalentDef.FIGURE_ROWS.has(def.row):
		return FIGURE_COLS[clampi(def.col - 1, 0, FIGURE_COLS.size() - 1)]
	return ""


## Display name of a branch id ("bollwerk" → "Bollwerk").
static func spec_name(spec: String) -> String:
	return str(SPEC_NAMES.get(spec, spec.capitalize()))


## All effects of a talent joined with " · "; rt_mod skill_pm effects with the same field and factor name their skills
## together ("Wuchtschlag und Abrissbirne +15 % Kraft", ST1-D).
static func effects_line(def: TalentDef, member_id: String = "") -> String:
	if def == null:
		return ""
	var parts: PackedStringArray = []
	var merged: Dictionary = {}                  # "field:pm" → index into parts
	var names: Dictionary = {}                   # "field:pm" → skill names
	for fx: Dictionary in def.effects:
		if str(fx.get("kind", "")) == "rt_mod" and str(fx.get("op", "")) == "skill_pm" and str(fx.get("skill", "")) != "*":
			var key: String = "%s:%d" % [str(fx.get("field", "power")), int(fx.get("pm", 1000))]
			var sd: SkillDef = UiUtil.skill_def(str(fx.get("skill", "")))
			var nm: String = UiUtil.tr_text(sd.name) if sd != null else str(fx.get("skill", ""))
			if merged.has(key):
				var all: PackedStringArray = names[key]   # a value type: append to the copy, store it back
				all.append(nm)
				names[key] = all
				var who: String = ", ".join(all.slice(0, all.size() - 1)) + " und " + all[all.size() - 1]
				var probe: Dictionary = fx.duplicate()
				probe["skill"] = "*"
				parts[int(merged[key])] = mod_text(probe).replace("Alle Fähigkeiten", who)
				continue
			merged[key] = parts.size()
			names[key] = PackedStringArray([nm])
		parts.append(effect_text(fx, member_id))
	return " · ".join(parts)


## "Wischtechnik II" (rank 2), "Wischtechnik" (rank 1).
static func ranked_name(def: TalentDef, rank: int) -> String:
	if def == null:
		return ""
	return UiUtil.tr_text(def.name) + ROMAN[clampi(rank, 0, ROMAN.size() - 1)]


## Picked talents of a member in id order: ["Wischtechnik II", "Bissfest"]; then the picks of the talent tree in row
## order (09 §8.4; only a season has them).
static func member_talents(member: PartyMember) -> PackedStringArray:
	var out: PackedStringArray = []
	if member == null:
		return out
	var ids: Array = member.talents.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for id: Variant in ids:
		if DB.has_id("talents", str(id)):
			out.append(ranked_name(DB.talent(str(id)), int(member.talents[id])))
	for t: TalentDef in TalentTree.picked(DB.data, member):
		out.append(UiUtil.tr_text(t.name))
	return out


## 3000 ms → "3 s", 1500 → "1,5 s".
static func _seconds(ms: int) -> String:
	return "%s s" % _pct(ms / 100)


## 50 ‰ → "5", 250 → "25", 15 → "1,5" (German decimal comma).
static func _pct(pm: int) -> String:
	var tenths: int = absi(pm)
	if tenths % 10 == 0:
		return str(tenths / 10)
	return "%d,%d" % [tenths / 10, tenths % 10]
