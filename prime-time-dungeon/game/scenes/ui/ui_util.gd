extends RefCounted
## Private M6 UI helpers (02_TECH §0.3: no class_name). Usage: `const UiUtil := preload("res://scenes/ui/ui_util.gd")`.
## Formatting, colors (03_ART §2), widget factories, focus wiring (§10.2), display-only fallbacks for party stats,
## inventory and safe rooms (they read Game/DB, never write Game.state).

const STUB_HEADER: String = "# STUB(M0)"
const UiIconU := preload("res://scenes/ui/ui_icon.gd")

# --- Art palette extras (03_ART §2.1 / §2.4) -------------------------------------------------------------------------
const C_LIVE: Color = Color("#ff3b30")
const C_SODIUM: Color = Color("#ff9a2e")
const C_EXIT: Color = Color("#2bd66b")
const C_PAPER: Color = Color("#f5f0e6")
const C_SHADE: Color = Color("#5a4e8c")
const C_PARTY: Color = Color("#4aa8ff")
const C_ENEMY: Color = Color("#e8455a")
const C_DISABLED: Color = Color("#5a5266")
const C_INK: Color = Color("#140d1c")

const RARITY_COLORS: Dictionary = {"common": Color("#bfc5cc"), "rare": Color("#4aa8ff"), "epic": Color("#b05cff")}
const RARITY_NAMES: Dictionary = {"common": "Gewöhnlich", "rare": "Selten", "epic": "Episch"}
const RARITY_ORDER: PackedStringArray = ["common", "rare", "epic"]
const TIER_COLORS: Dictionary = {"box_bronze": Color("#cd7f32"), "box_silver": Color("#c0c8d2"),
	"box_gold": Color("#ffc83d"), "box_fan": Color("#ff5fa2")}
const ELEMENT_COLORS: Dictionary = {"physical": Color("#f2ebdd"), "fire": Color("#ff6a2b"), "ice": Color("#7fd8ff"),
	"shock": Color("#f5e642"), "poison": Color("#7cc242"), "none": Color("#6bffb0")}
const ELEMENT_NAMES: Dictionary = {"physical": "Physisch", "fire": "Feuer", "ice": "Eis", "shock": "Schock",
	"poison": "Gift", "none": "Neutral"}
const STAT_KEYS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]
const STAT_NAMES: Dictionary = {"hp": "HP", "mp": "MP", "str": "Stärke", "mag": "Magie", "def": "Abwehr",
	"res": "Resistenz", "spd": "Tempo", "lck": "Glück"}
const STAT_SHORT: Dictionary = {"hp": "HP", "mp": "MP", "str": "STÄ", "mag": "MAG", "def": "ABW", "res": "RES",
	"spd": "TMP", "lck": "GLÜ"}
const SLOT_NAMES: Dictionary = {"weapon": "Waffe", "armor": "Rüstung", "accessory": "Accessoire"}
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const TYPE_NAMES: Dictionary = {"consumable": "Verbrauch", "weapon": "Waffe", "armor": "Rüstung",
	"accessory": "Accessoire", "key": "Schlüssel"}
const CATEGORY_NAMES: Dictionary = {"attack": "Angriff", "magic": "Magie", "heal": "Heilung", "buff": "Stärkung",
	"debuff": "Schwächung", "stunt": "Stunt", "item": "Item", "summon": "Beschwörung", "special": "Spezial"}
const TARGET_NAMES: Dictionary = {"single_enemy": "1 Gegner", "all_enemies": "Alle Gegner",
	"random_enemy": "Zufälliger Gegner", "single_ally": "1 Verbündeter", "all_allies": "Alle Verbündeten",
	"self": "Selbst", "single_ally_ko": "1 KO-Verbündeter", "none": "–"}
const CHAT_NAME_COLORS: Array[Color] = [Color("#ff2e88"), Color("#22d3ee"), Color("#ffc93c"), Color("#4ade80"),
	Color("#b05cff"), Color("#ff9a2e"), Color("#7fd8ff")]
## Replacements for characters the default font lacks (03_ART F8).
const GLYPH_FALLBACKS: Dictionary = {"→": "-", "←": "-", "↑": "+", "↓": "-", "●": "•", "★": "*", "♥": "<3",
	"▼": "v", "▲": "^", "☰": "=", "✓": "OK", "✔": "OK", "✗": "x", "✘": "x", "⌫": "<"}


# --- formatting
# --------------------------------------------------------------------------------------------------------

## 12345 → "12.345" (German thousands separator).
static func fmt_int(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if neg else "") + out


## +12 / -3 / ±0 style (always with sign).
static func fmt_signed(n: int) -> String:
	if n > 0:
		return "+" + fmt_int(n)
	return fmt_int(n)


## Seconds → "mm:ss" ("h:mm:ss" from one hour); negative → "00:00".
static func fmt_time(sec: int) -> String:
	var s: int = maxi(sec, 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


## Percentage with one decimal, German comma ("36,0 %"). Values in 0..1.
static func fmt_pct(p: float, decimals: int = 1) -> String:
	var v: float = clampf(p, 0.0, 1.0) * 100.0
	var s: String = ("%." + str(decimals) + "f") % v
	return s.replace(".", ",") + " %"


## Hex string → Color with fallback (no dependency on Palette, which may be an M4 stub).
static func hex(s: String, fallback: Color = Color.WHITE) -> Color:
	if s.is_valid_html_color():
		return Color.from_string(s, fallback)
	return fallback


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"]) as Color


static func rarity_name(rarity: String) -> String:
	return str(RARITY_NAMES.get(rarity, rarity))


static func box_color(box_id: String) -> Color:
	if TIER_COLORS.has(box_id):
		return TIER_COLORS[box_id] as Color
	var def: LootboxDef = DB.lootbox(box_id) if DB.has_id("lootboxes", box_id) else null
	return hex(def.color, Color("#cd7f32")) if def != null else Color("#cd7f32")


static func chat_color(user: String) -> Color:
	var h: int = absi(user.hash())
	return CHAT_NAME_COLORS[h % CHAT_NAME_COLORS.size()]


# --- glyphs (03_ART F8)
# ------------------------------------------------------------------------------------------------

## Characters of `text` the default font cannot render (empty = all fine).
static func missing_glyphs(text: String) -> String:
	var font: Font = ThemeDB.fallback_font
	var out: String = ""
	for i in text.length():
		var c: int = text.unicode_at(i)
		if c < 32:
			continue
		if not font.has_char(c) and not out.contains(text[i]):
			out += text[i]
	return out


## Replaces characters without a glyph (data texts may contain them).
static func glyph_safe(text: String) -> String:
	if missing_glyphs(text) == "":
		return text
	var out: String = text
	for k: String in GLYPH_FALLBACKS.keys():
		out = out.replace(k, str(GLYPH_FALLBACKS[k]))
	var font: Font = ThemeDB.fallback_font
	var res: String = ""
	for i in out.length():
		var c: int = out.unicode_at(i)
		res += out[i] if (c < 32 or font.has_char(c)) else "?"
	return res


# --- widgets
# -----------------------------------------------------------------------------------------------------------

## Stylebox states of a Button that touch_pad() insets (LTR layouts; the *_mirrored states are only drawn for RTL).
const BUTTON_STATES: PackedStringArray = ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]
const TOUCH_META: StringName = &"touch_visible_h"
const MIN_FONT: int = 15                    # 03_ART §9.3: no UI text below 15 px

static func label(text: String, variation: StringName = &"", font_size: int = 0,
	color: Color = Color(0, 0, 0, 0)) -> Label:
	var l: Label = Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if font_size > 0:
		l.add_theme_font_size_override("font_size", maxi(font_size, MIN_FONT))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Word-wraps l at max_width while a short text keeps its natural width, so a long data text (quest, event name)
## cannot widen its container past the safe rect. Call once l is in the tree (measured with the inherited theme font)
## and again after changing its text.
static func wrap_label(l: Label, max_width: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 0.0
	var natural: float = ceilf(l.get_minimum_size().x)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(natural, max_width)
	return l


static func button(text: String, variation: StringName = &"", min_height: int = 0) -> Button:
	var b: Button = Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	if min_height > 0:
		b.custom_minimum_size.y = min_height
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT if variation == &"ButtonFlat" else HORIZONTAL_ALIGNMENT_CENTER
	add_sounds(b)
	return b


## 02_TECH §10.2 rule 5 / 03_ART §9.4 for buttons inside rows and lists: the button rect is the hit area (>= TOUCH_HIT
## high) and every state stylebox is drawn inset (negative expand margins), so the visible part is `visible_h`
## (>= MIN_TOUCH) high. Width follows the container. Lists keep >= 12 px separation (gap between hit areas).
## Idempotent; meta `touch_visible_h` = visible height (tests).
static func touch_pad(b: BaseButton, visible_h: float = 64.0) -> BaseButton:
	if b == null or b.has_meta(TOUCH_META):
		return b
	var vis: float = maxf(visible_h, float(UiTheme.MIN_TOUCH))
	var hit: float = maxf(float(UiTheme.TOUCH_HIT), vis)
	var inset: float = (hit - vis) * 0.5
	for st: String in BUTTON_STATES:
		var sb: StyleBox = _state_box(b, st)
		if sb == null:
			continue
		var d: StyleBox = sb.duplicate() as StyleBox
		if d is StyleBoxFlat:
			(d as StyleBoxFlat).expand_margin_top -= inset
			(d as StyleBoxFlat).expand_margin_bottom -= inset
		elif d is StyleBoxTexture:
			(d as StyleBoxTexture).expand_margin_top -= inset
			(d as StyleBoxTexture).expand_margin_bottom -= inset
		b.add_theme_stylebox_override(st, d)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, hit)
	b.set_meta(TOUCH_META, vis)
	return b


## Sets the vertical content margins of every state stylebox (compact fixed-height buttons, e.g. the title menu).
static func set_vmargin(b: Control, v: float) -> void:
	for st: String in BUTTON_STATES:
		var sb: StyleBox = _state_box(b, st)
		if sb == null:
			continue
		var d: StyleBox = sb.duplicate() as StyleBox
		d.content_margin_top = v
		d.content_margin_bottom = v
		b.add_theme_stylebox_override(st, d)


## Visible height of a control for the touch rules: touch_pad meta, the HitVisual of UiTheme.ensure_hit_area, else
## the rect height.
static func visible_height(c: Control) -> float:
	if c.has_meta(TOUCH_META):
		return float(c.get_meta(TOUCH_META))
	var v: Control = c.get_node_or_null("HitVisual") as Control
	if v != null:
		return v.size.y
	return c.size.y


static func _state_box(b: Control, state: String) -> StyleBox:
	if b.has_theme_stylebox_override(state):
		return b.get_theme_stylebox(state)
	var th: Theme = UiTheme.get_theme()
	var t: StringName = b.theme_type_variation if b.theme_type_variation != &"" else StringName(b.get_class())
	while t != &"":
		if th.has_stylebox(state, t):
			return th.get_stylebox(state, t)
		t = th.get_type_variation_base(t)
	return th.get_stylebox(state, "Button") if th.has_stylebox(state, "Button") else null


## Visible close button (X icon + caption) for modals: the touch way out (02_TECH §10.3 "reine Button-UI"; on touch the
## Esc/B glyph hints are hidden). 64 px visible, 88 px hit area.
static func close_button(caption: String = "Schließen") -> Button:
	var b: Button = button("", &"")
	b.name = "Close"
	b.custom_minimum_size = Vector2(176, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(row)
	b.add_child(row)
	var ic: Control = UiIconU.make(&"cross", UiTheme.C_TEXT, 20.0)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l: Label = label(caption, &"", 20)
	l.name = "Text"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	touch_pad(b)
	return b


## UI sounds: move on focus change (not the very first grab), confirm on press.
static func add_sounds(b: BaseButton) -> void:
	b.focus_entered.connect(func() -> void:
		if b.has_meta("_ptd_focused_once"):
			Sfx.play_ui(&"ui_move")
		b.set_meta("_ptd_focused_once", true))
	b.pressed.connect(func() -> void: Sfx.play_ui(&"ui_confirm"))


static func panel(variation: StringName = &"PanelMenu") -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func vbox(sep: int = 8) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 8) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h: float = 0.0, w: float = 0.0, expand: bool = false) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func bar(variation: StringName, value: float, max_value: float, height: float = 8.0) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.theme_type_variation = variation
	b.show_percentage = false
	b.max_value = maxf(max_value, 1.0)
	b.value = clampf(value, 0.0, b.max_value)
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Solid colored StyleBox (optionally skewed like broadcast lower thirds, 03_ART §9.1).
static func box_style(bg: Color, border: Color = Color(0, 0, 0, 0), border_w: int = 0, skew: float = 0.0,
		margin_h: float = 12.0, margin_v: float = 6.0) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.skew = Vector2(skew, 0.0)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


## Controls below a CanvasLayer/Node3D do not inherit the root theme (measured 4.7.2) → assign explicitly.
static func apply_theme(c: Control) -> void:
	c.theme = UiTheme.get_theme()


## Vertical focus chain with wrap (02_TECH §10.2 rule 2). Disabled/hidden controls are skipped.
static func wire_vertical(controls: Array[Control], wrap: bool = true) -> void:
	var list: Array[Control] = []
	for c: Control in controls:
		if c != null and c.visible and c.focus_mode != Control.FOCUS_NONE:
			list.append(c)
	var n: int = list.size()
	for i in n:
		var c: Control = list[i]
		var prev: Control = list[i - 1] if i > 0 else (list[n - 1] if wrap else c)
		var nxt: Control = list[i + 1] if i < n - 1 else (list[0] if wrap else c)
		c.focus_neighbor_top = c.get_path_to(prev)
		c.focus_neighbor_bottom = c.get_path_to(nxt)
		c.focus_previous = c.get_path_to(prev)
		c.focus_next = c.get_path_to(nxt)


## Horizontal chain with wrap.
static func wire_horizontal(controls: Array[Control], wrap: bool = true) -> void:
	var list: Array[Control] = []
	for c: Control in controls:
		if c != null and c.visible and c.focus_mode != Control.FOCUS_NONE:
			list.append(c)
	var n: int = list.size()
	for i in n:
		var c: Control = list[i]
		var prev: Control = list[i - 1] if i > 0 else (list[n - 1] if wrap else c)
		var nxt: Control = list[i + 1] if i < n - 1 else (list[0] if wrap else c)
		c.focus_neighbor_left = c.get_path_to(prev)
		c.focus_neighbor_right = c.get_path_to(nxt)


## Panels glide in + fade in 0.18 s (03_ART §9.1). Animates scale/modulate only (never `position`, which a parent
## container owns), so layouts stay intact. Safe outside the tree (no-op).
static func slide_in(c: Control, dur: float = 0.18) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	c.scale = Vector2(0.97, 0.97)
	var start: Callable = func() -> void:
		if not is_instance_valid(c):
			return
		c.pivot_offset = c.size * 0.5
		var tw: Tween = c.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, dur)
		tw.tween_property(c, "modulate:a", 1.0, dur)
	start.call_deferred()


static func fade_in(c: CanvasItem, dur: float = 0.18) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, dur)


# --- game data views (display only)
# ------------------------------------------------------------------------------------

static func has_state() -> bool:
	return Game.state != null


static func player_name() -> String:
	return Game.state.player_name if Game.state != null else "Kai"


static func item_name(item_id: String) -> String:
	if item_id == "":
		return "–"
	if DB.has_id("items", item_id):
		return tr_text(DB.item(item_id).name)
	return item_id


static func item_def(item_id: String) -> ItemDef:
	return DB.item(item_id) if item_id != "" and DB.has_id("items", item_id) else null


static func skill_def(skill_id: String) -> SkillDef:
	return DB.skill(skill_id) if skill_id != "" and DB.has_id("skills", skill_id) else null


static func tr_text(s: String) -> String:
	return TranslationServer.translate(s)


## Price of an item in the vending machine (Shop, else ItemDef.price).
static func price_of(item_id: String) -> int:
	var p: int = Shop.price_of(DB.data, item_id)
	if p <= 0:
		var def: ItemDef = item_def(item_id)
		p = def.price if def != null else 0
	return p


## Sell value (Shop, else ItemDef rule: sell −1 → floor(price / 2)).
static func sell_value(item_id: String) -> int:
	var v: int = Shop.sell_value(DB.data, item_id)
	if v <= 0:
		var def: ItemDef = item_def(item_id)
		if def == null:
			return 0
		v = def.sell_value() if def.sell != 0 else 0
	return v


## Item id → count of the current inventory (copy; equipped items are not counted).
static func inventory_counts() -> Dictionary:
	if Game.state == null or Game.state.inventory == null:
		return {}
	var out: Dictionary = {}
	var counts: Dictionary = Game.state.inventory.counts
	for k: Variant in counts.keys():
		var n: int = int(counts[k])
		if n > 0:
			out[str(k)] = n
	return out


static func credits() -> int:
	if Game.state == null or Game.state.inventory == null:
		return 0
	return Game.state.inventory.credits


static func party() -> Array[PartyMember]:
	var out: Array[PartyMember] = []
	if Game.state == null:
		return out
	for m: PartyMember in Game.state.party:
		if m != null:
			out.append(m)
	return out


static func member_def(member_id: String) -> PartyMemberDef:
	return DB.party_member(member_id) if DB.has_id("party", member_id) else null


## "Graf Mopsula" / player name for Kai.
static func member_name(m: PartyMember) -> String:
	if m == null:
		return ""
	var def: PartyMemberDef = member_def(m.id)
	var n: String = m.display_name if m.display_name != "" else (tr_text(def.name) if def != null else m.id)
	if def != null and def.title != "" and m.id != "kai":
		return tr_text(def.title) + " " + n
	return n


static func member_color(member_id: String) -> Color:
	var def: PartyMemberDef = member_def(member_id)
	return hex(def.portrait_color, UiTheme.C_ACCENT_2) if def != null else UiTheme.C_ACCENT_2


## Total stats (stat key → int): Progression.total_stats when implemented, else base + growth + equipment.
static func member_stats(m: PartyMember) -> Dictionary:
	var out: Dictionary = {}
	if m == null:
		return out
	var sb: StatBlock = Progression.total_stats(m, DB.data)
	if sb != null and sb.values.size() == 8:
		var total: int = 0
		for v: int in sb.values:
			total += v
		if total > 0:
			for i in 8:
				out[STAT_KEYS[i]] = sb.values[i]
			return out
	return computed_stats(m, m.equipment)


## Fallback/preview: floori(base + growth × (level − 1)) + equipment stats (GDD §4.1).
static func computed_stats(m: PartyMember, equipment: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var def: PartyMemberDef = member_def(m.id)
	for k: String in STAT_KEYS:
		var base: float = float(def.base_stats.get(k, 0)) if def != null else 0.0
		var growth: float = float(def.growth.get(k, 0.0)) if def != null else 0.0
		out[k] = floori(base + growth * float(maxi(m.level, 1) - 1))
	for slot: String in EQUIP_SLOTS:
		var it: ItemDef = item_def(str(equipment.get(slot, "")))
		if it == null:
			continue
		for k: Variant in it.stats.keys():
			out[str(k)] = int(out.get(str(k), 0)) + int(it.stats[k])
	return out


## Stat delta when `item_id` replaces the current item of `slot` ("" = unequip). Keys with change only.
static func equip_delta(m: PartyMember, slot: String, item_id: String) -> Dictionary:
	if m == null:
		return {}
	var before: Dictionary = computed_stats(m, m.equipment)
	var eq: Dictionary = m.equipment.duplicate()
	eq[slot] = item_id
	var after: Dictionary = computed_stats(m, eq)
	var out: Dictionary = {}
	for k: String in STAT_KEYS:
		var d: int = int(after.get(k, 0)) - int(before.get(k, 0))
		if d != 0:
			out[k] = d
	return out


static func can_equip(member_id: String, item_id: String) -> bool:
	var it: ItemDef = item_def(item_id)
	if it == null or not it.is_equipment():
		return false
	return it.equip_by.is_empty() or it.equip_by.has(member_id)


static func max_hp(m: PartyMember) -> int:
	return maxi(int(member_stats(m).get("hp", 1)), maxi(m.hp, 1)) if m != null else 1


static func max_mp(m: PartyMember) -> int:
	return maxi(int(member_stats(m).get("mp", 0)), m.mp) if m != null else 0


## EXP needed for the next level (Progression, else GDD §4.3 curve).
static func exp_to_next(level: int) -> int:
	var v: int = Progression.exp_to_next(level)
	if v <= 0 and level < Balance.LEVEL_CAP:
		v = floori(Balance.EXP_A * pow(float(level), Balance.EXP_B) + Balance.EXP_C)
	return v


## Safe rooms of the current floor: [{"id", "name", "theme", "shop": PackedStringArray, "cell"}] (layout data).
static func floor_safe_rooms(def: FloorDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null:
		return out
	for sr: Variant in def.layout.get("safe_rooms", []):
		if typeof(sr) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = sr
		var shop: PackedStringArray = []
		for s: Variant in d.get("shop", []):
			shop.append(str(s))
		out.append({"id": str(d.get("id", "")), "name": str(d.get("name", "")), "theme": str(d.get("theme", "kiosk")),
			"shop": shop, "cell": d.get("cell", [0, 0])})
	return out


static func safe_room_info(safe_room_id: String) -> Dictionary:
	for sr: Dictionary in floor_safe_rooms(Game.floor_def()):
		if str(sr["id"]) == safe_room_id:
			return sr
	return {}


## Vending stock: Shop.stock, else the layout safe room shop, else FloorDef.shop.
static func shop_stock(safe_room_id: String) -> PackedStringArray:
	var def: FloorDef = Game.floor_def()
	var stock: PackedStringArray = Shop.stock(def, safe_room_id)
	if stock.is_empty():
		var info: Dictionary = safe_room_info(safe_room_id)
		if not info.is_empty():
			stock = info["shop"] as PackedStringArray
		elif def != null:
			stock = def.shop
	var out: PackedStringArray = []
	for id: String in stock:
		if DB.has_id("items", id):
			out.append(id)
	return out


## Display line for a tag from mod_lines (fallback "a:b:c" → "a:b" → "a"), formatted; "" if none.
## Presentation only (game over, floor summary): the live announcer path stays Show.say().
static func mod_line(tag: String, ctx: Dictionary = {}, pick: int = 0) -> String:
	var t: String = tag
	while t != "":
		var lines: Array[ModLineDef] = DB.mod_lines(t)
		if not lines.is_empty():
			var line: ModLineDef = lines[absi(pick) % lines.size()]
			return format_line(line.text, ctx)
		var cut: int = t.rfind(":")
		t = t.substr(0, cut) if cut > 0 else ""
	return ""


## Fills name/floor/level + ctx placeholders; unknown placeholders stay visible (like ModAnnouncer.format).
static func format_line(text: String, ctx: Dictionary = {}) -> String:
	var full: Dictionary = {"name": player_name(), "floor": Game.state.floor_run.index if (Game.state != null
		and Game.state.floor_run != null) else 1}
	var kai: PartyMember = Game.state.member("kai") if Game.state != null else null
	full["level"] = kai.level if kai != null else 1
	full["viewers"] = fmt_int(Show.viewers())
	full["followers"] = fmt_int(Show.followers())
	for k: Variant in ctx.keys():
		full[k] = ctx[k]
	return glyph_safe(tr_text(text).format(full))


# --- misc
# --------------------------------------------------------------------------------------------------------------

## True if the script source at `path` is still a Phase-A stub (first line "# STUB(M0)"). Missing source (export) →
## false.
## Deferred grab_focus that tolerates the control being removed/freed before the deferred call runs (lists rebuilt in
## the same frame, dialogs closing) — a plain grab_focus.call_deferred() would log "!is_inside_tree()".
static func focus_later(c: Control) -> void:
	if c == null:
		return
	var ref: WeakRef = weakref(c)
	(func() -> void:
		var target: Control = ref.get_ref() as Control
		if target != null and target.is_inside_tree() and target.focus_mode != Control.FOCUS_NONE:
			target.grab_focus()).call_deferred()


static func is_stub(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	return f.get_line().begins_with(STUB_HEADER)


static func stubs_of(paths: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	for p: String in paths:
		if is_stub(p):
			out.append(p)
	return out


static func is_mobile() -> bool:
	return OS.has_feature("mobile")


## Releases all held move/sneak actions (touch joystick, autoplay).
static func release_move_actions() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sneak"]:
		if InputMap.has_action(a):
			Input.action_release(a)


## Sends a press + release of `action` through the input pipeline (touch buttons, 02_TECH §10.3).
static func tap_action(action: StringName, pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
