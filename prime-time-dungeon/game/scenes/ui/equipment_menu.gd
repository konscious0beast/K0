extends "res://scenes/ui/menu_base.gd"
## Pause tab / safe room "Ausrüstung" (02_TECH §1.6, GDD §10.1): member tabs, three slots, candidate list (inventory
## items of the slot type the member may wear + "Ablegen") with stat preview (green/red), Game.equip(member, slot,
## item). Layout: slots | candidates | stat column (full stat names, same as the party page).
## 06-C (06 §4.3): under the slots the Unterhosen-Liga line of the member ("Liga-bereit" / "Liga blockiert durch: …")
## and the team's current tier — the rule is always phrased "ohne Rüstung & ohne Accessoire".

var member_id: String = "kai"
var slot: String = ""                 # "" = slot level, else candidate level

var _tabs_holder: HBoxContainer
var _slots: VBoxContainer
var _cands: VBoxContainer
var _cand_title: Label
var _preview: GridContainer
var _slot_buttons: Array[Control] = []
var _cand_buttons: Array[Control] = []
var liga_line: Label                   # 06-C: "Liga blockiert durch: Tierheim-Hoodie" / "Liga-bereit: …"
var liga_tier_line: Label              # 06-C: "Aktuell: Unterhosen-Liga (Hype ×1,05)" / "Aktuell: keine Liga"


func _ready() -> void:
	page_title = "Ausrüstung"
	var col: VBoxContainer = UiUtil.vbox(12)
	UiUtil.full_rect(col)
	add_child(col)
	_tabs_holder = UiUtil.hbox(8)
	col.add_child(_tabs_holder)
	var row: HBoxContainer = UiUtil.hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	var left: VBoxContainer = UiUtil.vbox(10)
	left.custom_minimum_size = Vector2(360, 0)
	row.add_child(left)
	_slots = UiUtil.vbox(12)                # 12 px between the 88 px hit areas
	left.add_child(_slots)
	liga_line = UiUtil.label("", &"LabelSmall", 16)
	liga_line.name = "LigaLine"
	liga_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(liga_line)
	liga_tier_line = UiUtil.label("", &"LabelSmall", 15, UiTheme.C_TEXT_DIM)
	liga_tier_line.name = "LigaTierLine"
	left.add_child(liga_tier_line)
	var mid: VBoxContainer = UiUtil.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	_cand_title = UiUtil.label("Slot wählen", &"LabelSmall", 16)
	mid.add_child(_cand_title)
	var sl: Dictionary = scroll_list()
	mid.add_child(sl["scroll"] as Control)
	_cands = sl["list"]
	var stats_panel: PanelContainer = PanelContainer.new()
	stats_panel.custom_minimum_size = Vector2(250, 0)
	stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stats_panel.add_theme_stylebox_override("panel", UiUtil.box_style(Color(UiUtil.C_INK, 0.55), Color(UiTheme.C_ACCENT_2,
		0.35), 1, 0.0, 14, 10))
	row.add_child(stats_panel)
	var right: VBoxContainer = UiUtil.vbox(6)
	stats_panel.add_child(right)
	var ptitle: Label = UiUtil.label("WERTE", &"", 16, UiTheme.C_ACCENT)
	ptitle.add_theme_font_override("font", UiTheme.font_bold())
	right.add_child(ptitle)
	_preview = GridContainer.new()
	_preview.columns = 2
	_preview.add_theme_constant_override("h_separation", 12)
	_preview.add_theme_constant_override("v_separation", 2)
	right.add_child(_preview)
	if Game.state != null and Game.state.member(member_id) == null and not UiUtil.party().is_empty():
		member_id = UiUtil.party()[0].id
	refresh()


func select_member(id: String) -> void:
	member_id = id
	slot = ""
	refresh()
	focus_default()


func refresh() -> void:
	clear(_tabs_holder)
	_tabs_holder.add_child(member_tabs(member_id, select_member))
	var m: PartyMember = _member()
	clear(_slots)
	_slot_buttons.clear()
	for s: String in UiUtil.EQUIP_SLOTS:
		var item_id: String = str(m.equipment.get(s, "")) if m != null else ""
		var b: Button = list_button("%s:  %s" % [str(UiUtil.SLOT_NAMES[s]), UiUtil.item_name(item_id)],
			TYPE_ICONS[s] as StringName, item_color(item_id) if item_id != "" else UiUtil.C_DISABLED)
		b.name = "Slot_" + s
		var sname: String = s
		b.focus_entered.connect(func() -> void: _show_candidates(sname, false))
		b.pressed.connect(func() -> void: _show_candidates(sname, true))
		_slots.add_child(b)
		_slot_buttons.append(b)
	UiUtil.wire_vertical(_slot_buttons)
	_show_preview({})
	_refresh_liga()
	if slot != "":
		_show_candidates(slot, false)


func focus_default() -> void:
	var target: Control = null
	for b: Control in _slot_buttons:
		if slot != "" and b.name == "Slot_" + slot:
			target = b
	if target == null and not _slot_buttons.is_empty():
		target = _slot_buttons[0]
	if target != null:
		UiUtil.focus_later(target)


func handle_cancel() -> bool:
	if not _cand_buttons.is_empty() and _cand_has_focus():
		focus_default()
		return true
	return false


## Candidates for `p_slot`: "" (unequip) + inventory items of that type wearable by the member.
func candidates(p_slot: String) -> PackedStringArray:
	var out: PackedStringArray = [""]
	var counts: Dictionary = UiUtil.inventory_counts()
	var keys: Array = counts.keys()
	keys.sort()
	for k: Variant in keys:
		var id: String = str(k)
		var def: ItemDef = UiUtil.item_def(id)
		if def != null and def.type == p_slot and UiUtil.can_equip(member_id, id):
			out.append(id)
	return out


func equip(p_slot: String, item_id: String) -> bool:
	var ok: bool = Game.equip(member_id, p_slot, item_id)
	if ok:
		Sfx.play_ui(&"ui_confirm")
		say("%s: %s %s." % [UiUtil.member_name(_member()), str(UiUtil.SLOT_NAMES[p_slot]),
			"abgelegt" if item_id == "" else "= " + UiUtil.item_name(item_id)])
	else:
		Sfx.play_ui(&"ui_error")
		say("Das hat nicht geklappt.")
	slot = p_slot
	refresh()
	focus_default()
	return ok


func _member() -> PartyMember:
	return Game.state.member(member_id) if Game.state != null else null


func _cand_has_focus() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for b: Control in _cand_buttons:
		if b == f:
			return true
	return false


func _show_candidates(p_slot: String, focus: bool) -> void:
	slot = p_slot
	clear(_cands)
	_cand_buttons.clear()
	_cand_title.text = "%s wählen" % str(UiUtil.SLOT_NAMES[p_slot])
	var m: PartyMember = _member()
	var current: String = str(m.equipment.get(p_slot, "")) if m != null else ""
	for id: String in candidates(p_slot):
		if id == "" and current == "":
			continue
		var delta: Dictionary = UiUtil.equip_delta(m, p_slot, id)
		var right: String = _delta_text(delta)
		var b: Button = list_button("Ablegen" if id == "" else UiUtil.item_name(id), &"cross" if id == "" else
			TYPE_ICONS[p_slot] as StringName, UiTheme.C_TEXT_DIM if id == "" else item_color(id), right)
		var r: Label = b.find_child("Right", true, false) as Label
		if r != null and not delta.is_empty():
			r.add_theme_color_override("font_color", UiTheme.C_OK if _delta_sum(delta) >= 0 else UiTheme.C_DANGER)
		var iid: String = id
		b.focus_entered.connect(func() -> void: _show_preview(UiUtil.equip_delta(_member(), p_slot, iid)))
		b.pressed.connect(func() -> void: equip(p_slot, iid))
		_cands.add_child(b)
		_cand_buttons.append(b)
	if _cand_buttons.is_empty():
		_cands.add_child(empty_note("Nichts Passendes im Inventar."))
	UiUtil.wire_vertical(_cand_buttons)
	if focus and not _cand_buttons.is_empty():
		UiUtil.focus_later(_cand_buttons[0])


func _show_preview(delta: Dictionary) -> void:
	clear(_preview)
	var m: PartyMember = _member()
	if m == null:
		return
	var stats: Dictionary = UiUtil.member_stats(m)
	for k: String in ["str", "mag", "def", "res", "spd", "lck"]:
		var kl: Label = UiUtil.label(str(UiUtil.STAT_NAMES[k]), &"LabelSmall", 16)
		kl.custom_minimum_size = Vector2(110, 0)
		_preview.add_child(kl)
		var d: int = int(delta.get(k, 0))
		var txt: String = str(int(stats.get(k, 0)))
		if d != 0:
			txt += " %s" % UiUtil.fmt_signed(d)
		var vl: Label = UiUtil.label(txt, &"", 17, UiTheme.C_OK if d > 0 else (UiTheme.C_DANGER if d < 0 else
			Color(0, 0, 0, 0)))
		vl.add_theme_font_override("font", UiTheme.font_mono())
		vl.custom_minimum_size = Vector2(100, 0)
		_preview.add_child(vl)


## 06-C: the Liga lines for the selected member and the team (MarottenRules.liga_blockers / Show.marotten_view).
func _refresh_liga() -> void:
	if liga_line == null or Game.state == null:
		return
	var blockers: PackedStringArray = MarottenRules.liga_blockers(Game.state, member_id)
	if blockers.is_empty():
		liga_line.text = "Liga-bereit: ohne Rüstung & ohne Accessoire"
		liga_line.add_theme_color_override("font_color", UiTheme.C_OK)
	else:
		var names: PackedStringArray = []
		for iid: String in blockers:
			names.append(UiUtil.item_name(iid))
		liga_line.text = UiUtil.glyph_safe("Liga blockiert durch: " + ", ".join(names))
		liga_line.add_theme_color_override("font_color", UiTheme.C_TEXT_DIM)
	var v: Dictionary = Show.marotten_view()
	var tier: int = int(v.get("liga_tier", 0))
	var bonus: String = ""
	if bool(v.get("rewards", true)) and tier > 0:
		bonus = " (Hype ×%s)" % Show.pm_text(int(v.get("liga_hype_pm", 1000)))
	liga_tier_line.text = "Aktuell: " + (["keine Liga", "Unterhosen-Liga", "Duo-Liga"][clampi(tier, 0, 2)]) + bonus


static func _delta_text(delta: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in UiUtil.STAT_KEYS:
		if delta.has(k):
			parts.append("%s %s" % [str(UiUtil.STAT_SHORT[k]), UiUtil.fmt_signed(int(delta[k]))])
	return " ".join(parts)


static func _delta_sum(delta: Dictionary) -> int:
	var s: int = 0
	for v: Variant in delta.values():
		s += int(v)
	return s
