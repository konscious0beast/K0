extends "res://scenes/ui/menu_base.gd"
## Pause tab "Fähigkeiten" (02_TECH §1.6, GDD §14.4; 07 §4.1): per member the combat bar (slots 1–5 + variants +
## FINALE, unlock levels: learned = bright, upcoming = "ab Stufe X", dimmed), the Partner-Spezial, the auto attack and
## the partner tactic — see the section at the end; R5b: variants and the tactic are chosen there (the recorded loadout
## command). Details on focus. The CTB learnset page is gone with the CTB campaign (R5b part 2b). 09 ST1-A: a level
## reads "Stufe", never "Lv" / "Level" (09 §1.2).

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


func refresh() -> void:
	if _rt_refresh():                            # Echtzeitkampf (07, R3): the combat bar
		return
	clear(_tabs_holder)
	clear(_list)
	_buttons.clear()
	_list.add_child(empty_note("Keine Fähigkeiten."))


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


## Detail of a bar row: real-time MP, cooldown and cast time, statuses in seconds, the party's SHOW cooldown (R5b-2a
## text pass).
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
	var mp: int = RtView.skill_mp(sd)
	if mp > 0:
		parts.append("%d MP" % mp)
	if int(sd.rt.get("cast_ms", 0)) > 0:
		parts.append("Zauberzeit " + RtView.seconds_text(int(sd.rt["cast_ms"])))
	if int(sd.rt.get("cooldown_ms", 0)) > 0:
		parts.append("Abklingzeit " + RtView.seconds_text(int(sd.rt["cooldown_ms"])))
	sub.text = "  ·  ".join(parts)
	var lines: PackedStringArray = []
	var desc: String = RtView.skill_text(sd)
	if desc != "":
		lines.append(desc)
	var power: int = int(sd.rt.get("power", sd.power))
	if sd.damage_type in ["physical", "magical"]:
		lines.append("Stärke %d %%%s" % [power, " × %d Treffer" % sd.hits if sd.hits > 1 else ""])
	elif sd.damage_type == "heal":
		lines.append("Heilung (%s)" % {"mag": "Magie", "pct": "% MaxHP", "fixed": "fest"}.get(sd.heal_mode, sd.heal_mode))
	if sd.is_stunt():
		lines.append("Erfolg %d %% + %s %% je Glück (max. %d %%), %s" % [roundi(sd.success_base * 100.0),
			str(snappedf(sd.success_lck * 100.0, 0.1)).replace(".", ","), roundi(sd.success_cap * 100.0),
			"SHOW-Abklingzeit 30 s (ganze Party)"])
	if not bool(e.get("learned", true)):
		lines.append("Wird mit Stufe %d gelernt." % int(e.get("level", 1)))
	body.text = UiUtil.glyph_safe("\n".join(lines))


# --- Echtzeitkampf (07, R3): the combat bar of a real-time run (07 §4.1–4.3) ------------------------------------------

const RtView := preload("res://scenes/combat/ui/combat_view.gd")

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
const RT_PRESET_HINTS: Dictionary = {"attack": "Drauf und dran: greift dein Ziel an, nutzt Fähigkeiten offensiv.",
	"support": "Heilt, hilft, hält Abstand.", "careful": "Weicht früh aus und nutzt Tränke."}
const RT_TOGGLE_NAMES: Dictionary = {"interrupt": "Unterbrechen", "show": "Show-Einlagen", "potions": "Tränke"}
const RT_TOGGLE_HINTS: Dictionary = {"interrupt": "Unterbricht Zauber mit goldenem Rand, wenn es geht.",
	"show": "Nutzt SHOW-Fähigkeiten für die Show.", "potions": "Trinkt Tränke aus dem Inventar, wenn es knapp wird."}


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


## The combat bar (07 §4.1: "das Fähigkeiten-Menü liest rt.bar"); false without a running game.
## R5b: the page is the loadout outside a combat — a learned variant of slot 2–4 (or the base ability back) and the
## partner tactic with its three switches. Every choice is ONE recorded loadout command with the member's complete
## choice (RunRules.loadout_cmd → Game.apply_loadout; refused during a combat or for a variant above the level).
func _rt_refresh() -> bool:
	if Game.state == null:
		return false
	clear(_tabs_holder)
	_tabs_holder.add_child(member_tabs(member_id, select_member))
	clear(_list)
	_buttons.clear()
	var m: PartyMember = Game.state.member(member_id)
	var level: int = m.level if m != null else 1
	var rows: Array[Dictionary] = rt_bar_rows(member_id)
	var choosable: Dictionary = rt_variant_slots(rows)
	var last_slot: int = -1
	var first: Dictionary = {}
	for r: Dictionary in rows:
		var slot: int = int(r["slot"])
		if slot != last_slot:
			last_slot = slot
			_rt_header(str(RT_SLOT_NAMES.get(slot, "SLOT %d" % slot)))
		var kind: String = str(r["kind"])
		var e: Dictionary = {"skill": str(r["skill"]), "level": int(r["level"]), "learned": int(r["level"]) <= level,
			"kind": kind, "slot": slot, "choice": choosable.has(slot) and (kind == "" or kind == "variant")}
		if bool(e["choice"]):
			e["equipped"] = rt_equipped(m, slot, str(r["skill"]), kind)
		_rt_button(e, str(RT_KIND_TEXT.get(kind, "")))
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
		_rt_tactic(m, def)
	UiUtil.wire_vertical(_buttons)
	if not first.is_empty():
		_rt_show(first)
	return true


## Slots of `rows` with a variant (07 §4.1: slots 2–4) → true: their base row and variants are a choice.
static func rt_variant_slots(rows: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for r: Dictionary in rows:
		if str(r["kind"]) == "variant" and RunRules.LOADOUT_SLOTS.has(str(int(r["slot"]))):
			out[int(r["slot"])] = true
	return out


## Whether the bar row (slot, skill, kind "" | "variant") is what the member's slot holds (PartyMember.rt_loadout;
## no entry = the base ability).
static func rt_equipped(m: PartyMember, slot: int, skill: String, kind: String) -> bool:
	var chosen: String = str(m.rt_loadout.get(str(slot), "")) if m != null else ""
	return chosen == skill if kind == "variant" else chosen == ""


## The partner tactic of the member: the current one, the three tactics and switches as buttons (R5b: chosen here,
## in a combat at the Taktik-Chip — that choice is kept as well, BattleBridge.write_presets).
func _rt_tactic(m: PartyMember, def: PartyMemberDef) -> void:
	_rt_header("TAKTIK ALS PARTNER")
	var preset: String = rt_preset_of(m, def)
	var note: Label = UiUtil.label("Gilt, wenn die KI %s spielt · im Kampf am Taktik-Chip änderbar"
		% UiUtil.tr_text(def.name), &"LabelSmall", 16, UiTheme.C_TEXT_DIM)
	note.name = "RtTactic"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(note)
	for p: String in RtVocab.RT_PRESETS:
		var on: bool = p == preset
		var b: Button = list_button(str(RT_PRESET_NAMES.get(p, p)), &"dot", UiTheme.C_ACCENT if on else
			UiTheme.C_TEXT_DIM, "aktiv" if on else "", Color(0, 0, 0, 0))
		b.name = "RtPreset_" + p
		var pick: String = p
		b.pressed.connect(func() -> void: _rt_set_tactic(pick, ""))
		b.focus_entered.connect(func() -> void: _rt_show_tactic(pick, ""))
		_list.add_child(b)
		_buttons.append(b)
	var tog: Dictionary = rt_toggles_of(m)
	for k: String in RtVocab.RT_TOGGLES:
		var on_t: bool = bool(tog[k])
		var b: Button = list_button("%s: %s" % [str(RT_TOGGLE_NAMES.get(k, k)), "an" if on_t else "aus"], &"dot",
			UiTheme.C_ACCENT if on_t else UiTheme.C_TEXT_DIM, "", Color(0, 0, 0, 0))
		b.name = "RtToggle_" + k
		var key: String = k
		b.pressed.connect(func() -> void: _rt_set_tactic("", key))
		b.focus_entered.connect(func() -> void: _rt_show_tactic("", key))
		_list.add_child(b)
		_buttons.append(b)


## The member's tactic: PartyMember.rt_preset, else party.json rt.default_preset, else attack / support.
static func rt_preset_of(m: PartyMember, def: PartyMemberDef) -> String:
	var preset: String = m.rt_preset if m != null else ""
	if preset == "" and def != null and not def.rt.is_empty():
		preset = str(def.rt.get("default_preset", ""))
	if not RtVocab.RT_PRESETS.has(preset):
		preset = "support" if def != null and def.id == "mopsula" else "attack"
	return preset


## The member's switches: RtVocab defaults overlaid with PartyMember.rt_toggles.
static func rt_toggles_of(m: PartyMember) -> Dictionary:
	var tog: Dictionary = RtVocab.RT_TOGGLE_DEFAULTS.duplicate()
	if m != null:
		for k: Variant in m.rt_toggles.keys():
			if RtVocab.RT_TOGGLES.has(str(k)):
				tog[str(k)] = bool(m.rt_toggles[k])
	return tog


## A bar row pressed: a learned variant (or the base ability back) of a slot with variants → loadout command.
func _rt_choose(e: Dictionary) -> void:
	if not bool(e.get("choice", false)) or bool(e.get("equipped", false)):
		return
	if not bool(e["learned"]):
		say("Wird mit Stufe %d gelernt." % int(e["level"]))
		return
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	if m == null:
		return
	var bar: Dictionary = m.rt_loadout.duplicate()
	if str(e["kind"]) == "variant":
		bar[str(int(e["slot"]))] = str(e["skill"])
	else:
		bar.erase(str(int(e["slot"])))
	var sd: SkillDef = UiUtil.skill_def(str(e["skill"]))
	if _rt_apply(bar, m.rt_preset, m.rt_toggles, "RtSkill_" + str(e["skill"])):
		say("Slot %d: %s" % [int(e["slot"]), UiUtil.tr_text(sd.name) if sd != null else str(e["skill"])])


## A tactic (`preset`) or a switch (`toggle`) pressed → loadout command with the member's complete choice.
func _rt_set_tactic(preset: String, toggle: String) -> void:
	var m: PartyMember = Game.state.member(member_id) if Game.state != null else null
	if m == null:
		return
	var def: PartyMemberDef = UiUtil.member_def(member_id)
	var tog: Dictionary = rt_toggles_of(m)
	var p: String = rt_preset_of(m, def)
	if preset != "":
		if preset == p:
			return
		p = preset
	if toggle != "":
		tog[toggle] = not bool(tog[toggle])
	var focus: String = "RtPreset_" + preset if preset != "" else "RtToggle_" + toggle
	if _rt_apply(m.rt_loadout, p, tog, focus):
		say("Taktik: %s" % str(RT_PRESET_NAMES.get(p, p)) if preset != "" else "%s: %s" % [
			str(RT_TOGGLE_NAMES.get(toggle, toggle)), "an" if bool(tog[toggle]) else "aus"])


## Game.apply_loadout of the complete choice; on success the page shows it with the focus on `focus_name`.
func _rt_apply(bar: Dictionary, preset: String, tog: Dictionary, focus_name: String) -> bool:
	if not Game.apply_loadout(RunRules.loadout_cmd(member_id, bar, preset, tog)):
		say("Während eines Kampfes nicht änderbar." if Game.rt_party_lock() != "" else "Nicht möglich.")
		return false
	refresh()
	var b: Control = _list.get_node_or_null(focus_name) as Control
	if b != null:
		UiUtil.focus_later(b)
	return true


## Detail of a tactic / switch button.
func _rt_show_tactic(preset: String, toggle: String) -> void:
	(_detail["title"] as Label).text = str(RT_PRESET_NAMES.get(preset, preset)) if preset != "" else \
		str(RT_TOGGLE_NAMES.get(toggle, toggle))
	(_detail["sub"] as Label).text = "Taktik als Partner" if preset != "" else "Schalter der Taktik"
	(_detail["body"] as Label).text = UiUtil.glyph_safe(str(RT_PRESET_HINTS.get(preset, "")) if preset != "" else
		str(RT_TOGGLE_HINTS.get(toggle, "")))


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
	var right: String = ("%d MP" % mp if mp > 0 else "") if learned else "ab Stufe %d" % int(e["level"])
	if bool(e.get("equipped", false)):
		right = "belegt"
	var col: Color = UiUtil.ELEMENT_COLORS.get(sd.element if sd != null else "none", UiTheme.C_TEXT) as Color
	var icon: StringName = &"star" if str(e["kind"]) == "finale" or (sd != null and sd.is_stunt()) else _element_icon(sd)
	var b: Button = list_button(name_text, icon, col if learned else UiUtil.C_DISABLED, right,
		Color(0, 0, 0, 0) if learned else UiTheme.C_TEXT_DIM)
	b.name = "RtSkill_" + str(e["skill"])
	var entry: Dictionary = e
	b.focus_entered.connect(func() -> void: _rt_show(entry))
	b.pressed.connect(func() -> void: _rt_choose(entry))
	_list.add_child(b)
	_buttons.append(b)


## Detail of a bar row: the CTB detail text plus the real-time slot rule.
func _rt_show(e: Dictionary) -> void:
	_show(e)
	var body: Label = _detail["body"]
	var extra: String = ""
	match str(e.get("kind", "")):
		"variant":
			extra = ("Belegt Slot %d statt der Grundfähigkeit." % int(e["slot"]) if bool(e.get("equipped", false)) else
				"Variante für Slot %d (ab Stufe %d): auswählen, um sie statt der Grundfähigkeit zu belegen." % [int(
				e["slot"]), int(e["level"])])
		"":
			if bool(e.get("choice", false)) and not bool(e.get("equipped", false)):
				extra = "Auswählen, um wieder die Grundfähigkeit in Slot %d zu belegen." % int(e["slot"])
		"context":
			extra = "Ersetzt den Slot automatisch, wenn das Ziel K.O. ist (ab Stufe %d)." % int(e["level"])
		"finale":
			extra = "Das FINALE ersetzt die SHOW, sobald dein Ziel unter 30 % HP hat (ab Stufe %d)." % int(e["level"])
		"special":
			extra = "Mit Taste R (Pad: Steuerkreuz links) befiehlst du sie deinem Partner sofort."
	if extra != "":
		body.text = UiUtil.glyph_safe((body.text + "\n" if body.text != "" else "") + extra)
