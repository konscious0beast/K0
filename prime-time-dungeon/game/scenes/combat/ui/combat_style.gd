extends RefCounted
## Look of the real-time combat HUD (07 §8, 03_ART §9 TV broadcast: ink panels, magenta / gold / cyan accents, skewed
## lower thirds) and the small text helpers every R3 script shares. Private R3 helper (no class_name, 02_TECH §0.3):
## `const CombatStyle := preload("res://scenes/combat/ui/combat_style.gd")`.
## Labels are created WITHOUT outline (07 §8.2: an outlined Label costs ≈ 2 canvas draw calls, plain ones batch) and
## always sit on dark ground. Texts are German, symbols are drawn (03_ART F8), dynamic text goes through glyph_safe.

const C_INK: Color = Color("#140d1c")
const C_PAPER: Color = Color("#f5f0e6")
const C_TEXT: Color = Color("#f5f0ff")
const C_TEXT_DIM: Color = Color("#b3a7c9")
const C_PANEL: Color = Color(0.0784, 0.051, 0.1098, 0.86)
const C_PANEL_SOLID: Color = Color(0.0784, 0.051, 0.1098, 0.94)
const C_SLOT: Color = Color(0.11, 0.075, 0.16, 0.92)
const C_PARTY: Color = Color("#4aa8ff")           # ui_party: party HP
const C_ENEMY: Color = Color("#e8455a")           # ui_enemy: enemy HP
const C_HP_LOW: Color = Color("#ff4d4d")
const C_HEAL: Color = Color("#4ade80")
const C_MANA: Color = Color("#60a5fa")
const C_GOLD: Color = Color("#ffc93c")            # HYPE_GOLD
const C_MAGENTA: Color = Color("#ff2e88")         # NOVA magenta (FINALE)
const C_CYAN: Color = Color("#22d3ee")            # NOVA cyan (C_ACCENT_2)
const C_DANGER: Color = Color("#ff4d4d")
const C_GREY: Color = Color("#8a8494")
const C_TRAIL: Color = Color("#ff4d4d")
const C_DISABLED: Color = Color("#5a5266")
## Status colours (03_ART palette for the CTB statuses, new real-time statuses in the same family).
const STATUS_COLORS: Dictionary = {"poison": "#7cc242", "stun": "#f5d90a", "slow": "#5b8def", "haste": "#ff7a1a",
	"guard": "#9aa7b8", "taunted": "#e8455a", "taunt": "#e8455a", "dazed": "#c9b8ff", "regen": "#4ade80",
	"burn": "#ff7a1a", "admonished": "#ffc93c", "dizzy": "#c084fc", "enrage": "#ff4d4d"}
const ELEMENT_COLORS: Dictionary = {"physical": "#f2ebdd", "fire": "#ff6a2b", "ice": "#7fd8ff", "shock": "#f5e642",
	"poison": "#7cc242", "none": "#c9b8ff"}
## ACTION_REFUSED / can_use reasons (RtCommand.REASONS) → the short text above the bar (07 §8.2 "abgelehnt").
const REFUSALS: Dictionary = {"mp": "Nicht genug MP", "range": "Zu weit weg", "cooldown": "Abklingzeit",
	"item_cd": "Abklingzeit", "target": "Kein Ziel", "locked": "Gesperrt", "forbidden": "Gesperrt",
	"target_hp": "Ziel noch zu fit", "gcd": "Gleich bereit", "casting": "Zauber läuft", "drinking": "Trinkpause",
	"stunned": "Betäubt", "dead": "K.O.", "not_learned": "Noch nicht gelernt", "items_max": "Max. 3 Tränke je Kampf",
	"no_item": "Kein Trank dabei", "not_available": "Partner kann gerade nicht", "los": "Keine Sicht",
	"not_controlled": "Gerade nicht deins", "finished": "Kampf vorbei"}
## Item → icon id of RtVocab.ICON_IDS (items carry no icon field; 07 §4.5 "Symbol-Idee").
const ITEM_ICONS: Dictionary = {"itm_bandage": "bandage", "itm_brutzel_burger": "burger", "itm_antidote": "antidote",
	"itm_energy_krawumm": "can", "itm_smelling_salts": "salts", "itm_molotov": "molotov", "itm_ice_spray": "ice_spray",
	"itm_smoke": "smoke", "itm_hype_megaphone": "megaphone", "itm_elixir": "elixir"}
## Skill → icon id after the "Symbol-Idee" columns of 07 §4.2 / §4.3: the fallback while a skill has no rt.icon yet
## (R4 writes the rt blocks; rt.icon always wins).
const SKILL_ICONS: Dictionary = {"skl_attack_kai": "mop_swing", "skl_kai_heavy_swing": "mop_swing",
	"skl_kai_taunt": "megaphone_notes", "skl_kai_first_aid": "paw_plaster", "skl_kai_leash_trip": "leash_lasso",
	"skl_kai_cable_whip": "cable_sparks", "skl_kai_sweep": "mop_circle", "skl_kai_deo_torch": "spray_flame",
	"skl_stunt_kai_suplex": "wrestler_stars", "skl_kai_prime_finisher": "studio_camera",
	"skl_attack_mopsula": "monocle_beam", "skl_rt_auto_mopsula": "monocle_beam", "skl_mop_noble_flame": "seal_flame",
	"skl_mop_holy_lick": "tongue_glitter", "skl_mop_revive": "drool_halo", "skl_mop_mass_lick": "two_tongues",
	"skl_mop_frost_sneeze": "pug_nose_ice", "skl_mop_royal_decree": "scroll_seal", "skl_mop_thunder_bark": "bark_bolt",
	"skl_stunt_mop_entrance": "cape_spotlight", "skl_mop_inferno": "monocle_flames"}
## Interrupters of 07 §4.2 / §4.3 (Kai slot 3 and its variant, Graf Mopsula slot 4) — the fallback while a skill has
## no rt.interrupt yet.
const INTERRUPTERS: PackedStringArray = ["skl_kai_leash_trip", "skl_kai_cable_whip", "skl_mop_thunder_bark"]
const TICKS_PER_SEC: int = 30
const UiUtilRef := preload("res://scenes/ui/ui_util.gd")

## The GameData the bound sim was built from (tests / captures use fixture data); null = DB.data.
static var data: GameData = null
static var _bold: FontVariation = null


## Defs of the bound combat (names, icons, rt blocks).
static func gd() -> GameData:
	return data if data != null else DB.data


## Bold variant of the default font (headers, banners, key caps).
static func font_bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.6
	return _bold


## Label without outline (07 §8.2), mouse ignored. `size` in px (the HUD keeps 07's 12 px key caps on PC).
static func label(text: String, size: int, color: Color = C_TEXT, bold: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l


## Broadcast panel stylebox: ink, optional 12° skew (lower thirds), border.
static func panel_box(bg: Color = C_PANEL, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		skew: float = 0.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.skew = Vector2(skew, 0.0)
	sb.set_content_margin_all(0.0)
	return sb


## Remaining time for a sweep label: whole seconds from 1 s on, one decimal below ("0,4"), "" at 0 (07 §8.2).
static func secs(ticks: int) -> String:
	if ticks <= 0:
		return ""
	if ticks >= TICKS_PER_SEC:
		return str(ceili(float(ticks) / float(TICKS_PER_SEC)))
	return ("%.1f" % (float(ticks) / float(TICKS_PER_SEC))).replace(".", ",")


## "0:42" for countdowns.
static func clock(ticks: int) -> String:
	var s: int = maxi(0, ceili(float(ticks) / float(TICKS_PER_SEC)))
	return "%d:%02d" % [s / 60, s % 60]


static func refusal_text(reason: String) -> String:
	return str(REFUSALS.get(reason, "Geht gerade nicht"))


static func hex(s: String, fallback: Color = Color.WHITE) -> Color:
	return Color.html(s) if s != "" and Color.html_is_valid(s) else fallback


static func status_color(def: StatusDef) -> Color:
	if def == null:
		return C_GREY
	var key: String = status_icon(def)
	if STATUS_COLORS.has(key):
		return hex(str(STATUS_COLORS[key]))
	return hex(def.color, C_GREY)


## Icon id of a status: StatusDef.icon when it is a known id, else the id without "sts_" (07 §8.4).
static func status_icon(def: StatusDef) -> String:
	if def == null:
		return "generic"
	if def.icon != "" and (RtVocab.ICON_IDS.has(def.icon) or def.icon == "taunt"):
		return def.icon
	var bare: String = def.id.trim_prefix("sts_")
	return bare if RtVocab.ICON_IDS.has(bare) else "generic"


## Icon id of a skill: rt.icon (07 §4.6), else SKILL_ICONS, else a fallback from category / element.
static func skill_icon(def: SkillDef) -> String:
	if def == null:
		return "generic"
	var ic: String = str(def.rt.get("icon", "")) if not def.rt.is_empty() else ""
	if ic != "" and RtVocab.ICON_IDS.has(ic):
		return ic
	if SKILL_ICONS.has(def.id):
		return str(SKILL_ICONS[def.id])
	if def.is_stunt():
		return "wrestler_stars"
	if def.category == "heal":
		return "tongue_glitter"
	match def.element:
		"fire":
			return "fire"
		"ice":
			return "ice"
		"shock":
			return "bolt"
		"poison":
			return "toxic"
	return "claw" if def.category == "attack" else "generic"


static func item_icon(item_id: String) -> String:
	return str(ITEM_ICONS.get(item_id, "potion"))


static func element_color(element: String) -> Color:
	return hex(str(ELEMENT_COLORS.get(element, "#f2ebdd")))


## Display name of a unit: party members through UiUtil.member_name (persona-safe, 07 §12.9 Nr. 16), enemies by their
## def name; equal enemies get " A", " B", … in unit order (like the CTB plates).
static func unit_name(u: RtUnit, all_units: Array[RtUnit] = []) -> String:
	if u == null:
		return ""
	if u.side == Combatant.Side.PARTY:
		var m: PartyMember = Game.state.member(u.def_id) if Game.state != null else null
		if m != null:
			return UiUtilRef.member_name(m)
		var pdef: PartyMemberDef = gd().party_member(u.def_id) if gd().has_id("party", u.def_id) else null
		return TranslationServer.translate(pdef.name) if pdef != null else u.def_id
	var n: String = u.display_name
	if gd().has_id("enemies", u.def_id):
		n = TranslationServer.translate(gd().enemy(u.def_id).name)
	elif n == "":
		n = u.def_id
	if u.is_boss or all_units.is_empty():
		return n
	var same: Array[RtUnit] = []
	for o: RtUnit in all_units:
		if o.side == Combatant.Side.ENEMY and o.def_id == u.def_id:
			same.append(o)
	if same.size() <= 1:
		return n
	return "%s %s" % [n, char(65 + clampi(same.find(u), 0, 25))]


## Party colour of a member (party.json portrait_color), for threat dots and frames.
static func member_color(def_id: String) -> Color:
	return UiUtilRef.member_color(def_id)

