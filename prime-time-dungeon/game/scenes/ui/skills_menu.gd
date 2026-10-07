extends "res://scenes/ui/menu_base.gd"
## Pause tab "Fähigkeiten" (02_TECH §1.6, GDD §14.4): per member the attack skill, the learnset with unlock levels
## (learned = bright, upcoming = "ab Lv X", dimmed) and stunts (success chance, cooldown). Details on focus.

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
