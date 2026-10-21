class_name SdCardDef extends RefCounted
## One card of the Stempelduell rulebook (data/stempel/cards.json, 10 §2.3/§2.7). Immutable after loading.
## Display fields (name, text, quip, form) live only here; the engine sees the card as the skill `skl_<id>` built
## from the `skill` block (CTB meaning, SkillDef fields, 10 §6.4). `hand` "refresh" marks the Umlaufmappe (whole hand
## onto the discard pile, then draw a new hand) — the only card that changes the hand itself.

const FixedMath := preload("res://core/stats/fixed_math.gd")

const ARTS: PackedStringArray = ["stempel", "eilt", "eiskalt", "rohrpost", "papierkram", "verwaltung"]
## Formular-Art → engine element (10 §1.5).
const ART_ELEMENTS: Dictionary = {"stempel": "physical", "eilt": "fire", "eiskalt": "ice", "rohrpost": "shock",
	"papierkram": "poison", "verwaltung": "none"}
const ORIGINS: PackedStringArray = ["amt", "kandidat", "graf", "gegenstand", "talent", "trophaee"]
const HAND_EFFECTS: PackedStringArray = ["", "refresh"]

var id: String = ""
var name: String = ""
var art: String = "verwaltung"
var origin: String = "amt"
var owner: String = ""                      # talents: "kandidat" | "graf"
var max_copies: int = 2
var show: bool = false                      # Show-Karte (stunt, golden frame, 10 §1.7)
var form: String = ""                       # decorative form number, e.g. "027"
var text: String = ""
var quip: String = ""
var campaign: PackedStringArray = []        # campaign ids (skills, items, talents) that unlock the card (10 §2.5)
var hand: String = ""
var skill: Dictionary = {}                  # SkillDef fields in CTB meaning (without id/name/user/mp_cost)


static func from_dict(d: Dictionary) -> SdCardDef:
	var c: SdCardDef = SdCardDef.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", ""))
	c.art = str(d.get("art", "verwaltung"))
	c.origin = str(d.get("origin", "amt"))
	c.owner = str(d.get("owner", ""))
	c.max_copies = JsonUtil.to_int(d.get("max_copies", 2), 2)
	c.show = bool(d.get("show", false))
	c.form = str(d.get("form", ""))
	c.text = str(d.get("text", ""))
	c.quip = str(d.get("quip", ""))
	c.campaign = JsonUtil.to_str_array(d.get("campaign", []))
	c.hand = str(d.get("hand", ""))
	var sk: Variant = d.get("skill", {})
	c.skill = (sk as Dictionary).duplicate(true) if sk is Dictionary else {}
	return c


## Engine skill id of the card (`skl_<card id>`, 10 §6.4).
func skill_id() -> String:
	return "skl_" + id


## Bearbeitungszeit in Werktagen (= SkillDef.rank).
func rank() -> int:
	return JsonUtil.to_int(skill.get("rank", 3), 3)


func element() -> String:
	return str(skill.get("element", "none"))


## Fixed Ärger per hit (0 for cards without damage).
func power() -> int:
	return JsonUtil.to_int(skill.get("power", 0)) if str(skill.get("damage_type", "none")) == "fixed" else 0


func hits() -> int:
	return maxi(1, JsonUtil.to_int(skill.get("hits", 1), 1))


## Printed Ärger without Zuständigkeiten: power × hits (show cards: on success).
func damage() -> int:
	return power() * hits()


## Printed Geduld the card restores (0 for cards without a heal).
func heal() -> int:
	return JsonUtil.to_int(skill.get("power", 0)) if str(skill.get("damage_type", "none")) == "heal" else 0


## Status ids the card applies to its target (not the fail effect of a show card).
func status_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	var sts: Variant = skill.get("statuses", [])
	for s: Variant in (sts as Array if sts is Array else []):
		if s is Dictionary:
			out.append(str((s as Dictionary).get("id", "")))
	return out


## Turns of status `sid` as the card applies it (0 = the status default).
func status_turns(sid: String) -> int:
	var sts: Variant = skill.get("statuses", [])
	for s: Variant in (sts as Array if sts is Array else []):
		if s is Dictionary and str((s as Dictionary).get("id", "")) == sid:
			return JsonUtil.to_int((s as Dictionary).get("turns", 0))
	return 0


func cleanses() -> PackedStringArray:
	return JsonUtil.to_str_array(skill.get("cleanse", []))


## Heals and Eilvermerke land on the player who plays them (target self / single_ally), everything else on the
## other side.
func targets_self() -> bool:
	var t: String = str(skill.get("target", "single_enemy"))
	return t == "self" or t == "single_ally"


## Show cards: the printed success chance in per-mille (success_base; success_lck is 0 in the duel); else 1000.
func chance_pm() -> int:
	return FixedMath.pm(float(skill.get("success_base", 0.0))) if show else FixedMath.PM
