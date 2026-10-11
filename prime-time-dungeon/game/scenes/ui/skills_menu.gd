extends "res://scenes/ui/menu_base.gd"
## Pause tab "Fähigkeiten" (02_TECH §1.6, GDD §14.4): per member the attack skill, the learnset with unlock levels
## (learned = bright, upcoming = "ab Lv X", dimmed) and stunts (success chance, cooldown). Details on focus.
## Echtzeitkampf (07 §4.1, R3): a real-time run shows the combat bar instead (slots 1–5 + variants + FINALE, the
## Partner-Spezial, the auto attack and the partner tactic) — see the section at the end.

var member_id: String = "kai"

var _tabs_holder: HBoxContainer
var _list: VBoxContainer
var _detail: Dictionary = {}
var _buttons: Array[Control] = []


func _ready() -> void:
	page_title = "Fähigkeiten"
	var col: VBoxContainer = UiUtil.vbox(12)
	UiUtil.full_rect(col)
	add_child(col)
	_tabs_holder = UiUtil.hbox(8)
	col.add_child(_tabs_holder)
	var row: HBoxContainer = UiUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var sl: Dictionary = scroll_list()
	(sl["scroll"] as Control).custom_minimum_size = Vector2(420, 0)
	(sl["scroll"] as Control).size_flags_horizontal = Control.SIZE_FILL
	row.add_child(sl["scroll"] as Control)
	_list = sl["list"]
	_detail = detail_panel()
	row.add_child(_detail["panel"] as Control)
	if Game.state != null and Game.state.member(member_id) == null and not UiUtil.party().is_empty():
		member_id = UiUtil.party()[0].id
	refresh()


func select_member(id: String) -> void:
	member_id = id
	refresh()
	focus_default()


## [{skill, level, learned, kind}] for the member: attack, learnset (sorted), stunts.
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var def: PartyMemberDef = UiUtil.member_def(member_id)
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	if def == null:
		return out
	var level: int = m.level if m != null else 1
	out.append({"skill": def.attack_skill, "level": 1, "learned": true, "kind": "attack"})
	var ls: Array[Dictionary] = []
	for e: Dictionary in def.learnset:
		ls.append(e)
	ls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("level", 0)) < int(b.get("level", 0)))
	for e: Dictionary in ls:
		var sid: String = str(e.get("skill", ""))
		var lv: int = int(e.get("level", 1))
		var learned: bool = (m != null and m.skills.has(sid)) or lv <= level
		out.append({"skill": sid, "level": lv, "learned": learned, "kind": "skill"})
	for sid: String in def.stunts:
		out.append({"skill": sid, "level": 1, "learned": true, "kind": "stunt"})
	return out


func refresh() -> void:
	if _rt_refresh():                            # Echtzeitkampf (07, R3): the combat bar of a real-time run
		return
	clear(_tabs_holder)
	_tabs_holder.add_child(member_tabs(member_id, select_member))
	clear(_list)
	_buttons.clear()
	var last_kind: String = ""
	for e: Dictionary in entries():
		var kind: String = str(e["kind"])
		if kind != last_kind:
			last_kind = kind
			var h: Label = UiUtil.label({"attack": "BASISANGRIFF", "skill": "FÄHIGKEITEN", "stunt": "STUNTS"}.get(kind,
				"") as String, &"", 13, UiTheme.C_ACCENT)
			h.add_theme_font_override("font", UiTheme.font_bold())
			_list.add_child(h)
		var sd: SkillDef = UiUtil.skill_def(str(e["skill"]))
		var learned: bool = bool(e["learned"])
		var name_text: String = UiUtil.tr_text(sd.name) if sd != null else str(e["skill"])
		var right: String = ("%d MP" % sd.mp_cost if sd != null and sd.mp_cost > 0 else "") if learned else \
			"ab Lv %d" % int(e["level"])
		var icon: StringName = &"star" if kind == "stunt" else (&"fist" if kind == "attack" else _element_icon(sd))
		var col: Color = UiUtil.ELEMENT_COLORS.get(sd.element if sd != null else "none", UiTheme.C_TEXT) as Color
		var b: Button = list_button(name_text, icon, col if learned else UiUtil.C_DISABLED, right,
			Color(0, 0, 0, 0) if learned else UiTheme.C_TEXT_DIM)
		b.name = "Skill_" + str(e["skill"])
		var entry: Dictionary = e
		b.focus_entered.connect(func() -> void: _show(entry))
		_list.add_child(b)
		_buttons.append(b)
	if _buttons.is_empty():
		_list.add_child(empty_note("Keine Fähigkeiten."))
	UiUtil.wire_vertical(_buttons)
	var all: Array[Dictionary] = entries()
	if not all.is_empty():
		_show(all[0])


func focus_default() -> void:
	if not _buttons.is_empty():
		UiUtil.focus_later(_buttons[0])


static func _element_icon(sd: SkillDef) -> StringName:
	if sd == null:
		return &"dot"
	if sd.damage_type == "heal" or sd.category == "heal":
		return &"heart"
	match sd.element:
		"fire":
			return &"flame"
		"ice":
			return &"snow"
		"shock":
			return &"bolt"
		"poison":
			return &"bubble"
		"physical":
			return &"fist"
	return &"star"


func _show(e: Dictionary) -> void:
	var sd: SkillDef = UiUtil.skill_def(str(e.get("skill", "")))
	var title: Label = _detail["title"]
	var sub: Label = _detail["sub"]
	var body: Label = _detail["body"]
	if sd == null:
		title.text = str(e.get("skill", "–"))
		sub.text = ""
		body.text = ""
		return
	title.text = UiUtil.tr_text(sd.name) if bool(e.get("learned", true)) else UiUtil.tr_text(sd.name) + "  (gesperrt)"
	var parts: PackedStringArray = [str(UiUtil.CATEGORY_NAMES.get(sd.category, sd.category)),
		str(UiUtil.TARGET_NAMES.get(sd.target, sd.target))]
	if sd.element != "none":
		parts.append(str(UiUtil.ELEMENT_NAMES.get(sd.element, sd.element)))
	if sd.mp_cost > 0:
		parts.append("%d MP" % sd.mp_cost)
	parts.append("Rang %d" % sd.rank)
	sub.text = "  ·  ".join(parts)
	var lines: PackedStringArray = []
	if sd.desc != "":
		lines.append(UiUtil.tr_text(sd.desc))
	if sd.damage_type in ["physical", "magical"]:
		lines.append("Stärke %d %%%s" % [sd.power, " × %d Treffer" % sd.hits if sd.hits > 1 else ""])
	elif sd.damage_type == "heal":
		lines.append("Heilung (%s)" % {"mag": "Magie", "pct": "% MaxHP", "fixed": "fest"}.get(sd.heal_mode, sd.heal_mode))
	if sd.is_stunt():
		lines.append("Erfolg %d %% + %s %% je Glück (max. %d %%), Abklingzeit %d Züge" % [roundi(sd.success_base * 100.0),
			str(snappedf(sd.success_lck * 100.0, 0.1)).replace(".", ","), roundi(sd.success_cap * 100.0),
			maxi(sd.cooldown, 1)])
	if not bool(e.get("learned", true)):
		lines.append("Wird mit Level %d gelernt." % int(e.get("level", 1)))
	body.text = UiUtil.glyph_safe("\n".join(lines))


# --- Echtzeitkampf (07, R3): the combat bar of a real-time run (07 §4.1–4.3) ------------------------------------------

## 07 §4.2 / §4.3 as long as party.json has no rt.bar yet (R4 writes it; rt.bar wins): [slot, skill, level, kind] with
## kind "" (base), "variant", "context" or "finale".
const RT_BARS: Dictionary = {
	"kai": [[1, "skl_kai_heavy_swing", 1, ""], [2, "skl_kai_taunt", 2, ""], [2, "skl_kai_first_aid", 4, "variant"],
		[3, "skl_kai_leash_trip", 3, ""], [3, "skl_kai_cable_whip", 7, "variant"], [4, "skl_kai_sweep", 4, ""],
		[4, "skl_kai_deo_torch", 6, "variant"], [5, "skl_stunt_kai_suplex", 1, ""],
		[5, "skl_kai_prime_finisher", 6, "finale"]],
	"mopsula": [[1, "skl_mop_noble_flame", 1, ""], [2, "skl_mop_holy_lick", 1, ""], [2, "skl_mop_mass_lick", 6, "variant"],
		[2, "skl_mop_revive", 7, "context"], [3, "skl_mop_frost_sneeze", 2, ""], [3, "skl_mop_royal_decree", 4, "variant"],
		[4, "skl_mop_thunder_bark", 3, ""], [5, "skl_stunt_mop_entrance", 1, ""], [5, "skl_mop_inferno", 6, "finale"]],
}
## Partner-Spezial (07 §4.1): [skill, level] when party.json has no rt.partner_special yet.
const RT_SPECIALS: Dictionary = {"kai": ["skl_kai_taunt", 2], "mopsula": ["skl_mop_holy_lick", 1]}
const RT_SLOT_NAMES: Dictionary = {1: "SLOT 1 · HAUPTFÄHIGKEIT", 2: "SLOT 2", 3: "SLOT 3", 4: "SLOT 4",
	5: "SLOT 5 · SHOW"}
const RT_KIND_TEXT: Dictionary = {"variant": "Variante: ", "context": "Auf K.O.-Ziel: ", "finale": "FINALE: "}
const RT_PRESET_NAMES: Dictionary = {"attack": "Angriff", "support": "Unterstützen", "careful": "Vorsichtig"}


## The bar rows of `def_id`: party.json rt.bar (+ rt.context), else RT_BARS — [{slot, skill, level, kind}] by slot.
static func rt_bar_rows(def_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var def: PartyMemberDef = UiUtil.member_def(def_id)
	var bar: Array = def.rt.get("bar", []) as Array if def != null and not def.rt.is_empty() else []
	if not bar.is_empty():
		for e: Variant in bar:
			var d: Dictionary = e as Dictionary
			var kind: String = "finale" if bool(d.get("finale", false)) else ("variant" if bool(d.get("variant", false))
				else "")
			out.append({"slot": int(d.get("slot", 0)), "skill": str(d.get("skill", "")), "level": int(d.get("level", 1)),
				"kind": kind})
		for c: Variant in (def.rt.get("context", []) as Array):
			var cd: Dictionary = c as Dictionary
			out.append({"slot": int(cd.get("slot", 0)), "skill": str(cd.get("skill", "")),
				"level": int(cd.get("level", 1)), "kind": "context"})
	else:
		for row: Variant in (RT_BARS.get(def_id, []) as Array):
			var r: Array = row as Array
			out.append({"slot": int(r[0]), "skill": str(r[1]), "level": int(r[2]), "kind": str(r[3])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["slot"]) != int(b["slot"]):
			return int(a["slot"]) < int(b["slot"])
		return str(a["kind"]) == "" and str(b["kind"]) != "")
	return out


## [skill, level] of the member's Partner-Spezial (party.json rt.partner_special, else RT_SPECIALS).
static func rt_special(def_id: String) -> Array:
	var def: PartyMemberDef = UiUtil.member_def(def_id)
	if def != null and not def.rt.is_empty() and str(def.rt.get("partner_special", "")) != "":
		var sid: String = str(def.rt["partner_special"])
		for r: Dictionary in rt_bar_rows(def_id):
			if str(r["skill"]) == sid:
				return [sid, int(r["level"])]
		return [sid, 1]
	return RT_SPECIALS.get(def_id, ["", 99]) as Array


## Real-time runs list the combat bar instead of the CTB learnset (07 §4.1: "das Fähigkeiten-Menü liest rt.bar").
## Read-only: choosing a variant (PartyMember.rt_loadout) and the partner tactic outside combat need a recorded
## command that the contract does not have yet — the page names the base skill as equipped (the default, 07 §4.1).
func _rt_refresh() -> bool:
	if Game.state == null or Game.state.combat_mode != &"realtime":
		return false
	clear(_tabs_holder)
	_tabs_holder.add_child(member_tabs(member_id, select_member))
	clear(_list)
	_buttons.clear()
	var m: PartyMember = Game.state.member(member_id)
	var level: int = m.level if m != null else 1
	var last_slot: int = -1
	var first: Dictionary = {}
	for r: Dictionary in rt_bar_rows(member_id):
		var slot: int = int(r["slot"])
		if slot != last_slot:
			last_slot = slot
			_rt_header(str(RT_SLOT_NAMES.get(slot, "SLOT %d" % slot)))
		var e: Dictionary = {"skill": str(r["skill"]), "level": int(r["level"]), "learned": int(r["level"]) <= level,
			"kind": str(r["kind"]), "slot": slot}
		_rt_button(e, str(RT_KIND_TEXT.get(str(r["kind"]), "")))
		if first.is_empty():
			first = e
	var sp: Array = rt_special(member_id)
	if str(sp[0]) != "":
		_rt_header("PARTNER-SPEZIAL · WENN DU DEN ANDEREN SPIELST")
		_rt_button({"skill": str(sp[0]), "level": int(sp[1]), "learned": int(sp[1]) <= level, "kind": "special"}, "")
	var def: PartyMemberDef = UiUtil.member_def(member_id)
	if def != null:
		_rt_header("AUTO-ANGRIFF")
		var auto_id: String = str(def.rt.get("auto_skill", "")) if not def.rt.is_empty() else ""
		_rt_button({"skill": auto_id if auto_id != "" else def.attack_skill, "level": 1, "learned": true,
			"kind": "attack"}, "")
		_rt_header("TAKTIK ALS PARTNER")
		var preset: String = m.rt_preset if m != null else ""
		if preset == "" and not def.rt.is_empty():
			preset = str(def.rt.get("default_preset", ""))
		if preset == "":
			preset = "support" if member_id == "mopsula" else "attack"
		var note: Label = UiUtil.label("%s · im Kampf am Taktik-Chip änderbar (ab Stufe 3)" %
			str(RT_PRESET_NAMES.get(preset, preset)), &"LabelSmall", 16, UiTheme.C_TEXT_DIM)
		note.name = "RtTactic"
		_list.add_child(note)
	UiUtil.wire_vertical(_buttons)
	if not first.is_empty():
		_rt_show(first)
	return true


func _rt_header(text: String) -> void:
	var h: Label = UiUtil.label(text, &"", 13, UiTheme.C_ACCENT)
	h.add_theme_font_override("font", UiTheme.font_bold())
	_list.add_child(h)


func _rt_button(e: Dictionary, prefix: String) -> void:
	var sd: SkillDef = UiUtil.skill_def(str(e["skill"]))
	var learned: bool = bool(e["learned"])
	var name_text: String = prefix + (UiUtil.tr_text(sd.name) if sd != null else str(e["skill"]))
	var mp: int = int(sd.rt.get("mp", sd.mp_cost)) if sd != null and not sd.rt.is_empty() else (sd.mp_cost if sd != null
		else 0)
	var right: String = ("%d MP" % mp if mp > 0 else "") if learned else "ab Lv %d" % int(e["level"])
	var col: Color = UiUtil.ELEMENT_COLORS.get(sd.element if sd != null else "none", UiTheme.C_TEXT) as Color
	var icon: StringName = &"star" if str(e["kind"]) == "finale" or (sd != null and sd.is_stunt()) else _element_icon(sd)
	var b: Button = list_button(name_text, icon, col if learned else UiUtil.C_DISABLED, right,
		Color(0, 0, 0, 0) if learned else UiTheme.C_TEXT_DIM)
	b.name = "RtSkill_" + str(e["skill"])
	var entry: Dictionary = e
	b.focus_entered.connect(func() -> void: _rt_show(entry))
	_list.add_child(b)
	_buttons.append(b)


## Detail of a bar row: the CTB detail text plus the real-time slot rule.
func _rt_show(e: Dictionary) -> void:
	_show(e)
	var body: Label = _detail["body"]
	var extra: String = ""
	match str(e.get("kind", "")):
		"variant":
			extra = "Variante für diesen Slot (ab Lv %d). Die Wahl im Safe Room folgt — bis dahin bleibt die " % int(
				e["level"]) + "Grundfähigkeit belegt."
		"context":
			extra = "Ersetzt den Slot automatisch, wenn das Ziel K.O. ist (ab Lv %d)." % int(e["level"])
		"finale":
			extra = "Das FINALE ersetzt die SHOW, sobald dein Ziel unter 30 % HP hat (ab Lv %d)." % int(e["level"])
		"special":
			extra = "Mit Taste R (Pad: Steuerkreuz links) befiehlst du sie deinem Partner sofort."
	if extra != "":
		body.text = UiUtil.glyph_safe((body.text + "\n" if body.text != "" else "") + extra)
