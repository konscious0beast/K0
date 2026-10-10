class_name DataValidator extends RefCounted
## Schema / reference / value-range validation and normalization of the data tables (02_TECH §4.3–§4.5).
## Holds the binding vocabularies for all modules (§4.3).
##
## Usage (GameData): `var v := DataValidator.new(); var norm := v.validate(raw_tables, strict)`.
## `raw_tables` maps table name → parsed file object ({"schema": 1, "entries": [...], ...}).
## Result: {"<table>": Array[Dictionary] (normalized entries), "party_start": Dictionary, "lootbox_pools": Dictionary,
## "lootbox_pity": Dictionary, "pseudo_units": Array[Dictionary]}. Every problem is appended to `errors`
## (format "<table>[<index>|<id>].<field>: <message>"), nothing is printed. `strict == false` skips rules 7–9.

# --- Vocabularies (§4.3, binding for all modules) -----------------------------------------------------------------
const STATS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]
const ELEMENTS: PackedStringArray = ["none", "physical", "fire", "ice", "shock", "poison"]
const DAMAGE_TYPES: PackedStringArray = ["physical", "magical", "fixed", "heal", "none"]
const HEAL_MODES: PackedStringArray = ["", "mag", "pct", "fixed"]
const SKILL_CATEGORIES: PackedStringArray = ["attack", "magic", "heal", "buff", "debuff", "stunt", "item", "summon",
	"special"]
const TARGETS: PackedStringArray = ["single_enemy", "all_enemies", "random_enemy", "single_ally", "all_allies", "self",
	"single_ally_ko", "none"]
const SKILL_USERS: PackedStringArray = ["party", "enemy", "item", "any"]
const SKILL_SPECIALS: PackedStringArray = ["steal_credits", "escape"]
const ANIMS: PackedStringArray = ["attack", "cast", "stunt", "item"]
const SHOW_TAGS: PackedStringArray = ["flashy", "finisher", "cute", "gross", "risky"]
const ITEM_TYPES: PackedStringArray = ["consumable", "weapon", "armor", "accessory", "key"]
const ITEM_TAGS: PackedStringArray = ["heal", "cure", "revive", "mp", "damage", "show", "escape"]
const EQUIP_SLOTS: PackedStringArray = ["weapon", "armor", "accessory"]
const RARITIES: PackedStringArray = ["common", "rare", "epic"]
const USABLE: PackedStringArray = ["battle", "field", "both", "none"]
const STATUS_KINDS: PackedStringArray = ["buff", "debuff"]
const STATUS_FLAGS: PackedStringArray = ["delay_on_apply", "guard", "taunt", "no_magic", "no_stunt"]
const TICK_TIMINGS: PackedStringArray = ["turn_start", "turn_end"]
const AI_TYPES: PackedStringArray = ["weighted", "phased"]
const AI_CONDITIONS: PackedStringArray = ["self_hp_below", "self_hp_above", "ally_hp_below", "turn_mod",
	"allies_alive_below", "once"]
const AI_TARGETS: PackedStringArray = ["random", "lowest_hp_pct", "highest_hp", "not_status", "self", "all_enemies",
	"all_allies", "ally_lowest_hp_pct"]
const PHASE_OPS: PackedStringArray = ["say", "status_self", "summon", "fixed_damage_self", "add_pseudo",
	"remove_pseudo"]
const MODEL_BASES: PackedStringArray = ["humanoid", "pug", "rodent", "blob", "insect", "robot", "brute", "specter",
	"swarm"]
const MODEL_PROPS: PackedStringArray = ["cape", "crown", "monocle", "top_hat", "cap", "bandana", "apron", "mop",
	"broom", "knife", "staff", "key_ring", "glasses", "lamp_helmet", "backpack", "mask", "wings", "antennae",
	"newspaper_head", "briefcase", "bottlecap_chain", "cable_tangle", "spray_cap", "escalator_back", "claws", "helmet",
	"shield", "halberd", "rat_king_tail", "ticket_crown", "wrench", "axe", "crowbar", "cart", "discount_tag"]
const MODEL_POSES: PackedStringArray = ["auto", "quadruped", "upright"]
const THEMES: PackedStringArray = ["metro", "mall"]
const SAFE_ROOM_THEMES: PackedStringArray = ["kiosk", "pumphouse", "signalbox"]
const CELL_KINDS: PackedStringArray = ["start", "normal", "safe", "quarter_boss", "floor_boss", "stairs", "gate"]
const CHEST_TYPES: PackedStringArray = ["wood", "metal", "locked"]
const FLOOR_EVENT_TYPES: PackedStringArray = ["photo_drone", "lost_candidate", "wheel", "lever", "broken_vending"]
const ENEMY_START_STATES: PackedStringArray = ["IDLE", "PATROL"]
const QUEST_TYPES: PackedStringArray = ["reach_stairs", "defeat_boss", "bounty", "hype_peak", "pacifist",
	"achievement_hunt", "all_of"]
# box/nothing/encounter only in fev_wheel tables
const LOOT_KINDS: PackedStringArray = ["item", "credits", "box", "nothing", "encounter"]
const GIFT_KINDS: PackedStringArray = ["heal_party_pct", "heal_party_flat", "mp_party_pct", "status_party",
	"status_enemies", "item", "revive_or_heal_lowest"]
const SPONSOR_WEIGHT_CONDS: PackedStringArray = ["ally_hp_below", "ally_mp_below", "ally_ko", "is_boss"]
const ACH_TRIGGERS: PackedStringArray = ["enemy_killed", "battle_won", "battle_fled", "battle_started",
	"stunt_resolved", "combo", "party_ko", "boss_defeated", "sponsor_gift", "viewers_changed", "chest_opened",
	"item_bought", "lootbox_opened", "level_up", "event_completed", "explore_tick", "floor_completed"]
const VOICES: PackedStringArray = ["mod", "mopsula", "kai", "chat"]
# sender/amount/pct/min: 05 §6.12
const TEXT_PLACEHOLDERS: PackedStringArray = ["name", "floor", "level", "enemy", "item", "achievement", "viewers",
	"followers", "sponsor", "count", "member", "seconds", "sender", "amount", "pct", "min"]
const REQUIRED_MOD_TAGS: PackedStringArray = ["intro", "floor_start", "first_fight", "achievement_generic", "low_hp",
	"kill_streak", "crit", "weakness", "overkill", "stunt_success", "stunt_fail", "boring_fight", "flee", "flee_fail",
	"sponsor_gift", "timer_warn_300", "timer_warn_60", "timer_expired", "lootbox_open_bronze", "lootbox_open_silver",
	"lootbox_open_gold", "lootbox_open_fan", "lootbox_pity", "death", "mopsula_ko", "kai_ko", "revive", "boss_defeated",
	"level_up", "follower_milestone", "safe_room_enter", "vendor_buy", "stairs_found", "floor_end",
	"chat_hype_high", "chat_hype_mid", "chat_hype_low", "chat_crit", "chat_boring", "chat_mopsula", "chat_handle"]
## Optional tags: live tags of 05 CR-9 / §6.12 (event_*, gift_*, fan_pack_*, live_*, vote_*, twist_applied_*), the
## Sponsor-Fenster lines of 05 §6.13 (sponsor_window_open[:periodic|safe_room|boss|dev], sponsor_window_closed,
## sponsor_window_full) and the story beats of GDD §1.4 (tutorial_* hints B1/B2, story_battle:<encounter_id> banners
## B4).
const OPTIONAL_MOD_TAG_PREFIXES: PackedStringArray = ["achievement:", "boss_intro:", "boss_phase:", "event_",
	"gift_received", "mopsula_idle", "chat_", "gift_", "fan_pack_", "live_", "vote_", "twist_applied_", "tutorial_",
	"story_", "sponsor_window_"]

## Copy of StatIds.ALL (§6.3); test_m2_achievements asserts equality.
const STAT_IDS: PackedStringArray = ["kills_total", "kills_skill", "battles_won", "battles_fled", "preemptives",
	"ambushes_won", "crits_total", "stunts_success", "stunts_fail", "chests_opened", "sponsor_gifts",
	"credits_spent_vendor", "lootboxes_opened", "events_completed", "game_overs", "ko_mopsula",
	"explore_seconds_since_battle", "viewers_max", "viewers_target_peak", "followers_gained_run", "hype_100_count"]

## Trigger payload keys (§6.3) — the `e.` vocabulary of achievement conditions.
const TRIGGER_PAYLOAD_KEYS: Dictionary = {
	"enemy_killed": ["enemy_id", "overkill", "by", "member"],
	"battle_won": ["party_turns", "min_party_hp", "min_party_hp_pct", "crits", "weakness_hits", "items_used", "party_kos",
		"damage_taken", "is_boss", "boss_id", "encounter_type", "group_id"],
	"battle_fled": ["encounter_id", "is_boss"],
	"battle_started": ["encounter_id", "encounter_type", "is_boss"],
	"stunt_resolved": ["success", "member", "skill_id"],
	"combo": ["member", "enemy_id"],
	"party_ko": ["member"],
	"boss_defeated": ["boss_id", "party_turns"],
	"sponsor_gift": ["sponsor_id"],
	"viewers_changed": ["viewers"],
	"chest_opened": ["chest_id", "type"],
	"item_bought": ["item_id", "qty", "cost", "safe_room_id"],
	"lootbox_opened": ["box_id", "best_rarity"],
	"level_up": ["member", "level"],
	"event_completed": ["event_id", "choice"],
	"explore_tick": ["seconds_since_battle"],
	"floor_completed": ["floor", "timer_left"],
}

## Safe-room context of scene conditions (§4.4.13, Game.enter_safe_room).
const SCENE_CONTEXT_KEYS: PackedStringArray = ["safe_room_id", "first_visit", "safe_room_visits", "kai_level"]

## ID regex per table / embedded id kind (§4.2).
const ID_PATTERNS: Dictionary = {
	"statuses": "^sts_[a-z0-9_]+$",
	"skills": "^skl_[a-z0-9_]+$",
	"items": "^itm_[a-z0-9_]+$",
	"classes": "^cls_[a-z0-9_]+$",
	"party": "^[a-z][a-z0-9_]*$",
	"enemies": "^enm_[a-z0-9_]+$",
	"pseudo_units": "^pu_[a-z0-9_]+$",
	"floors": "^floor_[0-9]+$",
	"encounters": "^enc_[a-z0-9_]+$",
	"floor_events": "^fev_[a-z0-9_]+$",
	"zones": "^zone_[a-z0-9_]+$",
	"safe_rooms": "^sr_[a-z0-9_]+$",
	"lootboxes": "^box_[a-z0-9_]+$",
	"achievements": "^ach_[a-z0-9_]+$",
	"sponsors": "^spn_[a-z0-9_]+$",
	"milestones": "^ms_[0-9]+$",
	"mod_lines": "^mod_[a-z0-9_]+$",
	"scenes": "^scn_[a-z0-9_]+$",
	"passives": "^pas_[a-z0-9_]+$",
	"events": "^evt_[a-z0-9_]+$",
}

const TABLES: PackedStringArray = ["statuses", "skills", "items", "classes", "party", "enemies", "floors",
	"lootboxes", "achievements", "sponsors", "milestones", "mod_lines", "scenes"]
## Allowed extra top-level keys per file (§4.1); everything else is an error.
const TABLE_EXTRA_KEYS: Dictionary = {"party": ["start"], "enemies": ["pseudo_units"], "lootboxes": ["pools", "pity"]}
const REQUIRED_BOXES: PackedStringArray = ["box_bronze", "box_silver", "box_gold", "box_fan"]
const LEVEL_CAP: int = 10                    # copy of Balance.LEVEL_CAP (core/data must not depend on core/stats)
const MAX_TEXT_LEN: int = 110
const MAX_OFFSET: float = 4.5
const PALETTE_KEYS: PackedStringArray = ["floor", "wall", "accent", "light", "fog", "ambient"]
## Art keys allowed in zone/floor palettes in addition to PALETTE_KEYS (03_ART §2.2).
const PALETTE_ART_KEYS: PackedStringArray = ["shade", "rim", "grout", "key", "neon2"]
## Theme default palettes (03_ART §2.2/§2.3); FloorDef.palette is filled with these.
const THEME_PALETTES: Dictionary = {
	"metro": {"floor": "#3a3f4b", "wall": "#1f5f66", "accent": "#ff2e88", "light": "#ffd59e", "fog": "#1a1430",
		"ambient": "#2a2440"},
	"mall": {"floor": "#9a9080", "wall": "#2a3a44", "accent": "#ff4fa0", "light": "#fff0f5", "fog": "#2a1a2a",
		"ambient": "#3a2a3a"},
}
const MODEL_COLOR_KEYS: PackedStringArray = ["primary", "secondary", "accent", "skin", "eyes"]
## Copies of the fixed presentation vocabularies (Vfx.KINDS §8.6, Sfx ids §3.8) — core/data must not depend on
## art/autoload.
const VFX_KINDS: PackedStringArray = ["hit", "crit", "slash", "bite", "magic", "fire", "ice", "shock", "toxic",
	"light", "dark", "heal", "buff", "debuff", "ko", "levelup", "sponsor", "confetti", "smoke", "sparkle",
	"stairs_glow", "chest_open"]
const SFX_IDS: PackedStringArray = ["ui_move", "ui_confirm", "ui_cancel", "ui_error", "step", "swing", "hit",
	"hit_crit", "hit_weak", "miss", "magic", "fire", "ice", "shock", "toxic", "light", "dark", "heal", "buff", "debuff",
	"ko", "defend", "flee", "stunt_success", "stunt_fail", "level_up", "chest_open", "coin", "lootbox_shake",
	"lootbox_open", "lootbox_rare", "sponsor", "achievement", "timer_warn", "stairs", "swirl", "door", "mod_blip",
	"chat_pop", "vending"]
const MUSIC_IDS: PackedStringArray = ["title", "explore", "battle", "boss", "safe_room", "victory", "game_over",
	"credits"]
## Exact `params` keys of floor events (§7.4).
const FLOOR_EVENT_PARAMS: Dictionary = {
	"photo_drone": [["pose_hype", "i"], ["pose_followers", "i"], ["smash_credits", "i"], ["smash_hype", "i"]],
	"lost_candidate": [["tag", "s"], ["reward_item", "s"], ["followers", "i"]],
	"wheel": [["cost", "i"], ["max_spins", "i"], ["table", "a"]],
	"lever": [["success", "f"], ["gate", "s"], ["flood_pct", "i"], ["encounter", "s"]],
	"broken_vending": [["base", "f"], ["per_lck", "f"], ["reward_item", "s"], ["reward_amount", "i"], ["fail_pct", "i"],
		["fail_hype", "i"]],
}
const DIR_OFFSETS: Dictionary = {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const DIR_OPPOSITE: Dictionary = {"N": "S", "E": "W", "S": "N", "W": "E"}

const REQ: String = "<required>"   # spec marker: field has no default

# --- Field specs: [name, type(, default)] — no default = required. Types: s i f b d a sa ia c2 v2 ---------------------
const SPEC_STATUS: Array = [["id", "s"], ["name", "s"], ["kind", "s"], ["default_turns", "i", 3],
	["stat_mult", "d", {}],
	["tick_timing", "s", "turn_end"], ["tick_pct", "i", 0], ["tick_min", "i", 0], ["tick_speed_mult", "f", 1.0],
	["flags", "sa", []], ["excludes", "sa", []], ["element", "s", "none"], ["color", "s", "#ffffff"], ["icon", "s", ""]]
const SPEC_SKILL: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["user", "s", "any"], ["category", "s"],
	["target", "s"], ["damage_type", "s", "none"], ["element", "s", "none"], ["power", "i", 100], ["heal_mode", "s", ""],
	["hits", "i", 1], ["mp_cost", "i", 0], ["rank", "i", 3], ["accuracy", "i", -1], ["crit_bonus", "f", 0.0],
	["statuses", "a", []], ["cleanse", "sa", []], ["mp_restore", "i", 0], ["mp_restore_pct", "i", 0], ["summon", "sa", []],
	["flee_guaranteed", "b", false], ["special", "d", {}], ["success_base", "f", 0.0], ["success_lck", "f", 0.01],
	["success_cap", "f", 0.85], ["success_boss_mod", "f", -0.15], ["fail_effect", "d", {}], ["cooldown", "i", 0],
	["anim", "s", "attack"], ["vfx", "s", ""], ["sfx", "s", ""], ["hype", "i", 0], ["kill_hype", "i", 0],
	["show_tags", "sa", []]]
const SPEC_SKILL_STATUS: Array = [["id", "s"], ["chance", "f", 1.0], ["turns", "i", 0]]
const SPEC_SKILL_FAIL: Array = [["self_dmg_pct", "i", 0], ["delay_pct", "i", 0], ["status", "s", ""],
	["status_turns", "i", 0]]
const SPEC_SKILL_SPECIAL: Array = [["kind", "s"], ["max", "i", 0], ["refund_on_win", "b", false]]
const SPEC_ITEM: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["type", "s"], ["rarity", "s", "common"],
	["price", "i", 0], ["sell", "i", -1], ["max_stack", "i", 9], ["tags", "sa", []], ["use_skill", "s", ""],
	["usable", "s", "none"], ["stats", "d", {}], ["crit_bonus", "f", 0.0], ["element_mods", "d", {}],
	["status_immune", "sa", []], ["show_mods", "d", {}], ["equip_by", "sa", []], ["attack_element", "s", "physical"],
	["icon", "s", ""], ["color", "s", "#ffffff"]]
const SPEC_ITEM_SHOW_MODS: Array = [["hype_gain_mult", "f", 1.0], ["follower_mult", "f", 1.0]]
const SPEC_CLASS: Array = [["id", "s"], ["name", "s"], ["desc", "s", ""], ["for", "sa", []], ["min_floor", "i", 3],
	["stat_mult", "d", {}], ["growth_add", "d", {}], ["passives", "a", []], ["learnset", "a", []], ["show_mods", "d", {}]]
const SPEC_CLASS_SHOW_MODS: Array = [["hype_gain_mult", "f", 1.0], ["stunt_success_add", "f", 0.0],
	["stunt_cooldown", "i", 3],
	["sponsor_thresholds", "ia", [70, 85, 100]]]
const SPEC_PASSIVE: Array = [["id", "s"], ["params", "d", {}]]
const SPEC_LEARN: Array = [["level", "i"], ["skill", "s"]]
const SPEC_PARTY: Array = [["id", "s"], ["name", "s"], ["title", "s", ""], ["base_stats", "d"], ["growth", "d"],
	["attack_skill", "s"], ["learnset", "a", []], ["stunts", "sa", []], ["equipment", "d", {}], ["element_mods", "d", {}],
	["status_immune", "sa", []], ["status_resist", "d", {}], ["battle_slot", "i"], ["model", "d"],
	["portrait_color", "s", "#ffffff"]]
const SPEC_EQUIPMENT: Array = [["weapon", "s", ""], ["armor", "s", ""], ["accessory", "s", ""]]
const SPEC_MODEL: Array = [["base", "s"], ["scale", "f", 1.0], ["pose", "s", "auto"], ["colors", "d"],
	["props", "sa", []],
	["seed", "i", 0], ["gltf", "s", ""]]
const SPEC_ENEMY: Array = [["id", "s"], ["name", "s"], ["level", "i", 1], ["stats", "d"], ["exp", "i", 0],
	["credits", "i", 0],
	["attack_skill", "s"], ["ai", "d", {"type": "weighted", "actions": []}], ["phases", "a", []], ["element_mods", "d",
		{}],
	["status_immune", "sa", []], ["status_resist", "d", {}], ["drops", "a", []], ["boss_drops", "a", []], ["tags", "sa",
		[]],
	["boss", "b", false], ["model", "d"], ["explore", "d"]]
const SPEC_AI: Array = [["type", "s", "weighted"], ["actions", "a", []]]
const SPEC_AI_ACTION: Array = [["skill", "s"], ["weight", "i"], ["target", "s", "random"], ["cond", "d", {}]]
const SPEC_PHASE: Array = [["hp_above", "f"], ["on_enter", "a", []], ["actions", "a", []]]
const SPEC_OPS: Dictionary = {
	"say": [["op", "s"], ["tag", "s"]],
	"status_self": [["op", "s"], ["status", "s"], ["turns", "i"]],
	"summon": [["op", "s"], ["enemy", "s"], ["count", "i", 1]],
	"fixed_damage_self": [["op", "s"], ["amount", "i"], ["min_hp", "i", 1]],
	"add_pseudo": [["op", "s"], ["unit", "s"], ["ctr", "i"]],
	"remove_pseudo": [["op", "s"], ["unit", "s"]],
}
const SPEC_DROP: Array = [["item", "s"], ["chance", "f"]]
const SPEC_BOSS_DROP: Array = [["kind", "s"], ["id", "s"], ["amount", "i", 1]]
const SPEC_EXPLORE: Array = [["field_speed", "f"], ["patrol_speed", "f", 1.8], ["sight_range", "f", 10.0],
	["sight_angle_deg", "f", 110.0], ["hear_run", "f", 4.0], ["hear_sneak", "f", 1.5], ["giveup_no_sight", "f", 4.0],
	["leash", "f", 20.0], ["max_chase", "f", 8.0]]
const SPEC_PSEUDO: Array = [["id", "s"], ["name", "s"], ["icon", "s"], ["action", "d"], ["ctr_after", "i"],
	["warn_tag", "s", ""], ["warn_at", "i", 2]]
const SPEC_PSEUDO_ACTION: Array = [["fixed_pct_maxhp", "i"], ["element", "s"], ["ignores_guard", "b", false],
	["target", "s", "all_party"]]
const SPEC_FLOOR: Array = [["id", "s"], ["index", "i"], ["name", "s"], ["playable", "b", true], ["theme", "s"],
	["timer_seconds", "i"], ["timer_warnings", "ia", [600, 300, 60]], ["timer_start_after", "s", ""], ["floor_mult", "f",
		1.0],
	["grid", "d"], ["layout", "d", {}], ["rooms", "d", {}], ["safe_rooms", "i", 1], ["chests", "d", {}],
	["enemy_groups", "d", {}], ["chest_table", "a", []], ["shop", "sa", []], ["quarter_boss", "s", ""],
	["floor_boss", "s", ""], ["encounters", "a"], ["palette", "d", {}], ["music", "s", "explore"], ["quest", "d", {}],
	["window", "d", {}]]
const SPEC_GRID: Array = [["w", "i"], ["h", "i"]]
const SPEC_MINMAX: Array = [["min", "i"], ["max", "i"]]
const SPEC_CHEST_TABLE: Array = [["kind", "s"], ["id", "s", ""], ["weight", "i"], ["min", "i"], ["max", "i"]]
const SPEC_QUEST: Array = [["type", "s"], ["label", "s", ""], ["params", "d", {}]]
const SPEC_WINDOW: Array = [["open_at", "s", ""], ["close_at", "s", ""], ["duration_sec", "i", 0]]
const SPEC_ENCOUNTER: Array = [["id", "s"], ["enemies", "sa"], ["weight", "i", 10], ["min_depth", "f", 0.0],
	["max_depth", "f", 1.0], ["boss", "b", false], ["can_flee", "b", true], ["tutorial", "b", false], ["music", "s", ""]]
const SPEC_LAYOUT: Array = [["cells", "a"], ["zones", "a"], ["gates", "a", []], ["encounters_placed", "a", []],
	["chests", "a", []], ["events", "a", []], ["spawners", "a", []], ["safe_rooms", "a", []], ["stairs", "d"]]
const SPEC_CELL: Array = [["x", "i"], ["y", "i"], ["zone", "s"], ["kind", "s"], ["doors", "s", ""]]
const SPEC_ZONE: Array = [["id", "s"], ["name", "s"], ["palette", "d", {}]]
const SPEC_GATE: Array = [["cell", "c2"], ["dir", "s"], ["requires", "s"]]
const SPEC_PLACED: Array = [["group_id", "s"], ["enc_id", "s"], ["cell", "c2"], ["offset", "v2", [0.0, 0.0]],
	["state", "s", "PATROL"], ["turn", "b", true], ["waypoints", "a", []]]
const SPEC_CHEST: Array = [["id", "s"], ["cell", "c2"], ["offset", "v2", [0.0, 0.0]], ["type", "s"],
	["contents", "a", []]]
const SPEC_CONTENT: Array = [["kind", "s"], ["id", "s", ""], ["amount", "i"]]
const SPEC_EVENT: Array = [["id", "s"], ["type", "s"], ["cell", "c2"], ["offset", "v2", [0.0, 0.0]],
	["params", "d", {}]]
const SPEC_WHEEL_ENTRY: Array = [["weight", "i"], ["kind", "s"], ["id", "s", ""], ["amount", "i", 1]]
const SPEC_SPAWNER: Array = [["zone", "s"], ["pool", "sa"], ["interval_sec", "i", 90]]
const SPEC_SAFE_ROOM: Array = [["id", "s"], ["cell", "c2"], ["name", "s"], ["theme", "s"], ["shop", "sa", []]]
const SPEC_STAIRS: Array = [["cell", "c2"]]
const SPEC_LOOTBOX: Array = [["id", "s"], ["name", "s"], ["tier", "i"], ["color", "s"], ["rolls", "i", 2],
	["rarity_weights", "d"], ["guarantee", "s", ""], ["fixed_pool", "s", ""], ["mod_tag", "s", ""]]
const SPEC_RARITY_WEIGHTS: Array = [["common", "i"], ["rare", "i"], ["epic", "i"]]
const SPEC_POOL_ENTRY: Array = [["kind", "s"], ["id", "s", ""], ["amount", "i"], ["weight", "i"]]
const SPEC_PITY: Array = [["rare", "i"], ["epic", "i"]]
const SPEC_ACHIEVEMENT: Array = [["id", "s"], ["name", "s"], ["desc", "s"], ["trigger", "s"], ["condition", "s"],
	["box", "s", ""], ["followers", "i", -1], ["hidden", "b", false], ["mod_tag", "s", ""]]
const SPEC_SPONSOR: Array = [["id", "s"], ["name", "s"], ["slogan", "s", ""], ["color", "s"], ["gift", "a"],
	["weight", "i", 1], ["weight_mods", "a", []], ["min_floor", "i", 1], ["max_floor", "i", 0],
	["mod_tag", "s", "sponsor_gift"]]
const SPEC_GIFT_EFFECT: Array = [["kind", "s"], ["value", "i", 0], ["status", "s", ""], ["turns", "i", 0],
	["item", "s", ""],
	["target", "s", ""], ["ignore_resist", "b", false]]
const SPEC_WEIGHT_MOD: Array = [["cond", "s"], ["value", "f", 0.0], ["mult", "f"]]
const SPEC_MILESTONE: Array = [["id", "s"], ["followers", "i"], ["reward_box", "s", ""], ["credits", "i", 0],
	["item", "s", ""],
	["title", "s", ""], ["min_floor", "i", 1], ["mod_tag", "s", "follower_milestone"]]
const SPEC_MOD_LINE: Array = [["id", "s"], ["tag", "s"], ["voice", "s", "mod"], ["text", "s"], ["user", "s", ""],
	["weight", "i", 1], ["min_floor", "i", 1], ["max_floor", "i", 0], ["min_hype", "i", 0], ["max_hype", "i", 100]]
const SPEC_SCENE: Array = [["id", "s"], ["name", "s"], ["condition", "s"], ["lines", "a"], ["set_flag", "s", ""],
	["once", "b", true], ["priority", "i", 0]]
const SPEC_SCENE_LINE: Array = [["voice", "s"], ["text", "s"]]

var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var strict: bool = true

var _out: Dictionary = {}
var _regex: Dictionary = {}                 # pattern → RegEx
var _skills: Dictionary = {}                # id → normalized dict (lookup tables for reference checks)
var _statuses: Dictionary = {}
var _items: Dictionary = {}
var _classes: Dictionary = {}
var _party: Dictionary = {}
var _enemies: Dictionary = {}
var _pseudo: Dictionary = {}
var _floors: Dictionary = {}
var _encounters: Dictionary = {}            # enc id → {"def": Dictionary, "floor": int}
var _boxes: Dictionary = {}
var _achievements: Dictionary = {}
var _sponsors: Dictionary = {}
var _milestones: Dictionary = {}
var _mod_tags: Dictionary = {}              # tag → line count
var _referenced_tags: Dictionary = {}       # tag → ctx (rule 9)


# ======================================================================================================================
# Public API
# ======================================================================================================================

## Validates + normalizes `raw` (table → parsed file object). `read_errors` (table → message) marks unreadable files.
func validate(raw: Dictionary, p_strict: bool = true, read_errors: Dictionary = {}) -> Dictionary:
	strict = p_strict
	errors.clear()
	warnings.clear()
	_mod_tags.clear()
	_referenced_tags.clear()
	_out = {"party_start": {"inventory": {}, "credits": 0}, "lootbox_pools": {}, "lootbox_pity": {"rare": 4, "epic": 8},
		"pseudo_units": []}
	for t: String in TABLES:
		_out[t] = []
	# Rule 1 + rules 2/4 per entry.
	for t: String in TABLES:
		var entries: Array = _file_entries(t, raw, read_errors)
		var normalized: Array[Dictionary] = []
		for i in entries.size():
			var e: Dictionary = _normalize_entry(t, i, entries[i])
			if not e.is_empty():
				normalized.append(e)
		_out[t] = normalized
	_build_lookups()
	_check_ids()                                   # rule 3
	_check_references()                            # rules 5, 6 (+ value rules needing other tables)
	if strict:
		_check_content_rules()                     # rule 7 (+ required lootboxes / non-empty pools)
		_check_floor_rules()                       # rule 8
		_check_mod_line_rules()                    # rule 9
	_check_conditions()                            # rule 10
	return _out


## "#rrggbb" (case-insensitive).
static func is_hex_color(s: String) -> bool:
	if s.length() != 7 or not s.begins_with("#"):
		return false
	return s.substr(1).is_valid_hex_number(false)


## Placeholder names `{name}` used in a text (regex \{([a-z_]+)\}).
static func placeholders_in(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var re: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for m: RegExMatch in re.search_all(text):
		out.append(m.get_string(1))
	return out


## Is `tag` a valid mod_lines tag (§4.4.12)? Tags referenced elsewhere in the data (`extra`) are valid too.
static func is_valid_mod_tag(tag: String, extra: Dictionary = {}) -> bool:
	if tag == "":
		return false
	if REQUIRED_MOD_TAGS.has(tag) or extra.has(tag):
		return true
	if tag.begins_with("timer_warn_") and tag.trim_prefix("timer_warn_").is_valid_int():
		return true
	for p: String in OPTIONAL_MOD_TAG_PREFIXES:
		if tag.begins_with(p) and tag.length() > p.length():
			return true
		if tag == p:
			return true
	return false


## Payload keys of an achievement trigger (§6.3); [] for unknown triggers.
static func payload_keys(trigger_id: String) -> PackedStringArray:
	if not TRIGGER_PAYLOAD_KEYS.has(trigger_id):
		return PackedStringArray()
	return PackedStringArray(TRIGGER_PAYLOAD_KEYS[trigger_id])


# ======================================================================================================================
# Rule 1: file structure
# ======================================================================================================================

func _file_entries(t: String, raw: Dictionary, read_errors: Dictionary) -> Array:
	if read_errors.has(t):
		_err(t, str(read_errors[t]))
		return []
	if not raw.has(t) or raw[t] == null:
		_err(t, "file missing")
		return []
	if typeof(raw[t]) != TYPE_DICTIONARY:
		_err(t, "file must contain a JSON object")
		return []
	var f: Dictionary = raw[t]
	if not f.has("schema"):
		_err(t + ".schema", "missing (expected 1)")
	elif not JsonUtil.is_integral(f["schema"]) or int(f["schema"]) != 1:
		_err(t + ".schema", "must be 1 (got %s)" % str(f["schema"]))
	var extras: Array = TABLE_EXTRA_KEYS.get(t, [])
	for k: Variant in f.keys():
		var key: String = str(k)
		if key == "schema" or key == "entries" or extras.has(key):
			continue
		_err(t + "." + key, "unknown top-level key")
	if t == "party":
		_read_party_start(f)
	elif t == "enemies":
		_read_pseudo_units(f)
	elif t == "lootboxes":
		_read_lootbox_extras(f)
	if not f.has("entries"):
		_err(t + ".entries", "missing")
		return []
	if typeof(f["entries"]) != TYPE_ARRAY:
		_err(t + ".entries", "must be an array")
		return []
	return f["entries"]


func _read_party_start(f: Dictionary) -> void:
	if not f.has("start"):
		_err("party.start", "missing (required: {inventory, credits})")
		return
	var ctx: String = "party.start"
	var s: Dictionary = _norm(ctx, f["start"], [["inventory", "d"], ["credits", "i"]])
	if s.is_empty():
		return
	var inv: Dictionary = {}
	var raw_inv: Dictionary = s["inventory"]
	for k: Variant in raw_inv.keys():
		var v: Variant = raw_inv[k]
		if not JsonUtil.is_integral(v):
			_err(ctx + ".inventory." + str(k), "count must be an integer")
			continue
		inv[str(k)] = int(v)
	if int(s["credits"]) < 0:
		_err(ctx + ".credits", "must be >= 0")
	_out["party_start"] = {"inventory": inv, "credits": int(s["credits"])}


func _read_pseudo_units(f: Dictionary) -> void:
	if not f.has("pseudo_units"):
		return
	if typeof(f["pseudo_units"]) != TYPE_ARRAY:
		_err("enemies.pseudo_units", "must be an array")
		return
	var list: Array = f["pseudo_units"]
	var out: Array[Dictionary] = []
	for i in list.size():
		var ctx: String = _ctx("enemies.pseudo_units", i, list[i])
		var d: Dictionary = _norm(ctx, list[i], SPEC_PSEUDO)
		if d.is_empty():
			continue
		d["action"] = _norm(ctx + ".action", d["action"], SPEC_PSEUDO_ACTION)
		var act: Dictionary = d["action"]
		if not act.is_empty():
			_range_i(ctx + ".action.fixed_pct_maxhp", int(act["fixed_pct_maxhp"]), 1, 100)
			_enum(ctx + ".action.element", str(act["element"]), ELEMENTS)
			_enum(ctx + ".action.target", str(act["target"]), ["all_party"])
		_range_i(ctx + ".ctr_after", int(d["ctr_after"]), 1, 999)
		_range_i(ctx + ".warn_at", int(d["warn_at"]), 1, 99)
		if str(d["warn_tag"]) != "":
			_referenced_tags[str(d["warn_tag"])] = ctx + ".warn_tag"
		out.append(d)
	_out["pseudo_units"] = out


func _read_lootbox_extras(f: Dictionary) -> void:
	if not f.has("pools"):
		if strict:
			_err("lootboxes.pools", "missing (required)")
	elif typeof(f["pools"]) != TYPE_DICTIONARY:
		_err("lootboxes.pools", "must be an object")
	else:
		_out["lootbox_pools"] = _norm_pools(f["pools"])
	if not f.has("pity"):
		if strict:
			_err("lootboxes.pity", "missing (required)")
	else:
		var p: Dictionary = _norm("lootboxes.pity", f["pity"], SPEC_PITY)
		if not p.is_empty():
			_range_i("lootboxes.pity.rare", int(p["rare"]), 1, 999)
			_range_i("lootboxes.pity.epic", int(p["epic"]), 1, 999)
			_out["lootbox_pity"] = p


func _norm_pools(raw_pools: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw_pools.keys():
		var key: String = str(k)
		var ctx: String = "lootboxes.pools." + key
		if not _matches("^f[0-9]+$", key):
			_err(ctx, "pool key must be f<floor index>")
			continue
		if typeof(raw_pools[k]) != TYPE_DICTIONARY:
			_err(ctx, "must be an object")
			continue
		var pool: Dictionary = raw_pools[k]
		var npool: Dictionary = {"common": [], "rare": [], "epic": [], "fan": []}
		for r: Variant in pool.keys():
			var rarity: String = str(r)
			if not ["common", "rare", "epic", "fan"].has(rarity):
				_err(ctx + "." + rarity, "unknown rarity (common/rare/epic/fan)")
				continue
			if typeof(pool[r]) != TYPE_ARRAY:
				_err(ctx + "." + rarity, "must be an array")
				continue
			var entries: Array[Dictionary] = []
			var list: Array = pool[r]
			for i in list.size():
				var ectx: String = "%s.%s[%d]" % [ctx, rarity, i]
				var e: Dictionary = _norm(ectx, list[i], SPEC_POOL_ENTRY)
				if e.is_empty():
					continue
				_enum(ectx + ".kind", str(e["kind"]), ["item", "credits"])
				if str(e["kind"]) == "item" and str(e["id"]) == "":
					_err(ectx + ".id", "item entry needs an item id")
				if str(e["kind"]) == "credits" and str(e["id"]) != "":
					_err(ectx + ".id", "credits entry must have id \"\"")
				_range_i(ectx + ".amount", int(e["amount"]), 1, 99999)
				_range_i(ectx + ".weight", int(e["weight"]), 1, 100000)
				entries.append(e)
			npool[rarity] = entries
		out[key] = npool
	return out


# ======================================================================================================================
# Rules 2 + 4: per-entry normalization
# ======================================================================================================================

func _normalize_entry(t: String, i: int, raw: Variant) -> Dictionary:
	var ctx: String = _ctx(t, i, raw)
	match t:
		"statuses":
			return _n_status(ctx, raw)
		"skills":
			return _n_skill(ctx, raw)
		"items":
			return _n_item(ctx, raw)
		"classes":
			return _n_class(ctx, raw)
		"party":
			return _n_party(ctx, raw)
		"enemies":
			return _n_enemy(ctx, raw)
		"floors":
			return _n_floor(ctx, raw)
		"lootboxes":
			return _n_lootbox(ctx, raw)
		"achievements":
			return _n_achievement(ctx, raw)
		"sponsors":
			return _n_sponsor(ctx, raw)
		"milestones":
			return _n_milestone(ctx, raw)
		"mod_lines":
			return _n_mod_line(ctx, raw)
		"scenes":
			return _n_scene(ctx, raw)
	return {}


func _n_status(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_STATUS)
	if d.is_empty():
		return d
	_enum(ctx + ".kind", str(d["kind"]), STATUS_KINDS)
	_range_i(ctx + ".default_turns", int(d["default_turns"]), 1, 99)
	var sm_keys: PackedStringArray = STATS.duplicate()
	sm_keys.remove_at(sm_keys.find("hp"))
	sm_keys.remove_at(sm_keys.find("mp"))
	d["stat_mult"] = _num_dict(ctx + ".stat_mult", d["stat_mult"], sm_keys, false, 0.25, 4.0)
	_enum(ctx + ".tick_timing", str(d["tick_timing"]), TICK_TIMINGS)
	_range_i(ctx + ".tick_pct", int(d["tick_pct"]), -50, 50)
	_range_i(ctx + ".tick_min", int(d["tick_min"]), 0, 999)
	_range_f(ctx + ".tick_speed_mult", float(d["tick_speed_mult"]), 0.25, 4.0)
	_subset(ctx + ".flags", d["flags"], STATUS_FLAGS)
	_enum(ctx + ".element", str(d["element"]), ELEMENTS)
	_hex(ctx + ".color", str(d["color"]))
	return d


func _n_skill(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_SKILL)
	if d.is_empty():
		return d
	var raw_d: Dictionary = raw
	var cat: String = str(d["category"])
	if not raw_d.has("rank"):
		d["rank"] = 4 if cat == "stunt" else (2 if cat == "item" else 3)
	if not raw_d.has("cooldown"):
		d["cooldown"] = 3 if cat == "stunt" else 0
	_enum(ctx + ".user", str(d["user"]), SKILL_USERS)
	_enum(ctx + ".category", cat, SKILL_CATEGORIES)
	_enum(ctx + ".target", str(d["target"]), TARGETS)
	_enum(ctx + ".damage_type", str(d["damage_type"]), DAMAGE_TYPES)
	_enum(ctx + ".element", str(d["element"]), ELEMENTS)
	_range_i(ctx + ".power", int(d["power"]), 0, 1000)
	_enum(ctx + ".heal_mode", str(d["heal_mode"]), HEAL_MODES)
	_range_i(ctx + ".hits", int(d["hits"]), 1, 8)
	_range_i(ctx + ".mp_cost", int(d["mp_cost"]), 0, 999)
	_range_i(ctx + ".rank", int(d["rank"]), 1, 6)
	var acc: int = int(d["accuracy"])
	if acc != -1 and (acc < 1 or acc > 100):
		_err(ctx + ".accuracy", "must be -1 or 1..100 (got %d)" % acc)
	_range_f(ctx + ".crit_bonus", float(d["crit_bonus"]), 0.0, 1.0)
	var sts: Array[Dictionary] = []
	var raw_sts: Array = d["statuses"]
	for i in raw_sts.size():
		var sctx: String = "%s.statuses[%d]" % [ctx, i]
		var s: Dictionary = _norm(sctx, raw_sts[i], SPEC_SKILL_STATUS)
		if s.is_empty():
			continue
		_range_f(sctx + ".chance", float(s["chance"]), 0.0, 1.0)
		_range_i(sctx + ".turns", int(s["turns"]), 0, 99)
		sts.append(s)
	d["statuses"] = sts
	_range_i(ctx + ".mp_restore", int(d["mp_restore"]), 0, 999)
	_range_i(ctx + ".mp_restore_pct", int(d["mp_restore_pct"]), 0, 100)
	var sp: Dictionary = d["special"]
	if not sp.is_empty():
		sp = _norm(ctx + ".special", sp, SPEC_SKILL_SPECIAL)
		if not sp.is_empty():
			_enum(ctx + ".special.kind", str(sp["kind"]), SKILL_SPECIALS)
			if str(sp["kind"]) == "steal_credits" and int(sp["max"]) < 1:
				_err(ctx + ".special.max", "steal_credits needs max >= 1")
		d["special"] = sp
	_range_f(ctx + ".success_base", float(d["success_base"]), 0.0, 1.0)
	_range_f(ctx + ".success_lck", float(d["success_lck"]), 0.0, 0.05)
	_range_f(ctx + ".success_cap", float(d["success_cap"]), 0.0, 1.0)
	_range_f(ctx + ".success_boss_mod", float(d["success_boss_mod"]), -1.0, 0.0)
	var fe: Dictionary = d["fail_effect"]
	if not fe.is_empty():
		fe = _norm(ctx + ".fail_effect", fe, SPEC_SKILL_FAIL)
		if not fe.is_empty():
			_range_i(ctx + ".fail_effect.self_dmg_pct", int(fe["self_dmg_pct"]), 0, 100)
			_range_i(ctx + ".fail_effect.delay_pct", int(fe["delay_pct"]), 0, 200)
			_range_i(ctx + ".fail_effect.status_turns", int(fe["status_turns"]), 0, 99)
		d["fail_effect"] = fe
	_range_i(ctx + ".cooldown", int(d["cooldown"]), 0, 9)
	_enum(ctx + ".anim", str(d["anim"]), ANIMS)
	if str(d["vfx"]) != "":
		_enum(ctx + ".vfx", str(d["vfx"]), VFX_KINDS)
	if str(d["sfx"]) != "":
		_enum(ctx + ".sfx", str(d["sfx"]), SFX_IDS)
	_range_i(ctx + ".hype", int(d["hype"]), -20, 50)
	_range_i(ctx + ".kill_hype", int(d["kill_hype"]), 0, 50)
	_subset(ctx + ".show_tags", d["show_tags"], SHOW_TAGS)
	# Rule 6 (local type consistency).
	var dt: String = str(d["damage_type"])
	if dt == "heal" and str(d["heal_mode"]) == "":
		_err(ctx + ".heal_mode", "required for damage_type heal")
	if dt != "heal" and str(d["heal_mode"]) != "":
		_err(ctx + ".heal_mode", "only allowed with damage_type heal")
	if (dt == "physical" or dt == "magical" or dt == "fixed") and str(d["element"]) == "none":
		_err(ctx + ".element", "damage skills need an element other than none")
	if cat == "stunt" and float(d["success_base"]) < 0.05:
		_err(ctx + ".success_base", "stunts need success_base 0.05..1.0")
	if not (d["summon"] as PackedStringArray).is_empty() and cat != "summon":
		_err(ctx + ".summon", "only allowed for category summon")
	return d


func _n_item(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_ITEM)
	if d.is_empty():
		return d
	var type: String = str(d["type"])
	_enum(ctx + ".type", type, ITEM_TYPES)
	_enum(ctx + ".rarity", str(d["rarity"]), RARITIES)
	_range_i(ctx + ".price", int(d["price"]), 0, 99999)
	_range_i(ctx + ".sell", int(d["sell"]), -1, 99999)
	if type == "key" and int(d["sell"]) != 0:
		_err(ctx + ".sell", "key items must have sell 0")
	_range_i(ctx + ".max_stack", int(d["max_stack"]), 1, 99)
	_subset(ctx + ".tags", d["tags"], ITEM_TAGS)
	_enum(ctx + ".usable", str(d["usable"]), USABLE)
	if type == "consumable":
		if str(d["use_skill"]) == "":
			_err(ctx + ".use_skill", "required for consumables")
		if str(d["usable"]) == "none":
			_err(ctx + ".usable", "consumables must be usable (battle/field/both)")
	d["stats"] = _num_dict(ctx + ".stats", d["stats"], STATS, true, -99.0, 999.0)
	_range_f(ctx + ".crit_bonus", float(d["crit_bonus"]), 0.0, 0.5)
	d["element_mods"] = _num_dict(ctx + ".element_mods", d["element_mods"], ELEMENTS, false, 0.0, 3.0)
	var sm: Dictionary = _norm(ctx + ".show_mods", d["show_mods"], SPEC_ITEM_SHOW_MODS)
	if sm.is_empty():
		sm = {"hype_gain_mult": 1.0, "follower_mult": 1.0}
	_range_f(ctx + ".show_mods.hype_gain_mult", float(sm["hype_gain_mult"]), 0.5, 3.0)
	_range_f(ctx + ".show_mods.follower_mult", float(sm["follower_mult"]), 0.5, 3.0)
	d["show_mods"] = sm
	_enum(ctx + ".attack_element", str(d["attack_element"]), ELEMENTS)
	_hex(ctx + ".color", str(d["color"]))
	return d


func _n_class(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_CLASS)
	if d.is_empty():
		return d
	_range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	d["stat_mult"] = _num_dict(ctx + ".stat_mult", d["stat_mult"], STATS, false, 0.5, 2.0)
	d["growth_add"] = _num_dict(ctx + ".growth_add", d["growth_add"], STATS, false, 0.0, 20.0)
	var passives: Array[Dictionary] = []
	var raw_p: Array = d["passives"]
	for i in raw_p.size():
		var pctx: String = "%s.passives[%d]" % [ctx, i]
		var p: Dictionary = _norm(pctx, raw_p[i], SPEC_PASSIVE)
		if p.is_empty():
			continue
		if not _matches(str(ID_PATTERNS["passives"]), str(p["id"])):
			_err(pctx + ".id", "invalid passive id '%s' (pas_…)" % str(p["id"]))
		passives.append(p)
	d["passives"] = passives
	d["learnset"] = _n_learnset(ctx, d["learnset"], 99)
	var sm: Dictionary = _norm(ctx + ".show_mods", d["show_mods"], SPEC_CLASS_SHOW_MODS)
	if sm.is_empty():
		sm = {"hype_gain_mult": 1.0, "stunt_success_add": 0.0, "stunt_cooldown": 3,
			"sponsor_thresholds": PackedInt32Array([70, 85, 100])}
	_range_f(ctx + ".show_mods.hype_gain_mult", float(sm["hype_gain_mult"]), 0.5, 3.0)
	_range_f(ctx + ".show_mods.stunt_success_add", float(sm["stunt_success_add"]), -1.0, 1.0)
	_range_i(ctx + ".show_mods.stunt_cooldown", int(sm["stunt_cooldown"]), 0, 9)
	d["show_mods"] = sm
	return d


func _n_learnset(ctx: String, raw: Array, max_level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in raw.size():
		var lctx: String = "%s.learnset[%d]" % [ctx, i]
		var l: Dictionary = _norm(lctx, raw[i], SPEC_LEARN)
		if l.is_empty():
			continue
		_range_i(lctx + ".level", int(l["level"]), 1, max_level)
		out.append(l)
	return out


func _n_party(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_PARTY)
	if d.is_empty():
		return d
	d["base_stats"] = _num_dict(ctx + ".base_stats", d["base_stats"], STATS, true, 0.0, 9999.0, true)
	if (d["base_stats"] as Dictionary).has("hp") and int(d["base_stats"]["hp"]) < 1:
		_err(ctx + ".base_stats.hp", "must be >= 1")
	d["growth"] = _num_dict(ctx + ".growth", d["growth"], STATS, false, 0.0, 50.0, true)
	d["learnset"] = _n_learnset(ctx, d["learnset"], LEVEL_CAP)
	var eq: Dictionary = _norm(ctx + ".equipment", d["equipment"], SPEC_EQUIPMENT)
	if eq.is_empty():
		eq = {"weapon": "", "armor": "", "accessory": ""}
	d["equipment"] = eq
	d["element_mods"] = _num_dict(ctx + ".element_mods", d["element_mods"], ELEMENTS, false, 0.0, 3.0)
	d["status_resist"] = _num_dict(ctx + ".status_resist", d["status_resist"], [], false, 0.0, 1.0)
	_range_i(ctx + ".battle_slot", int(d["battle_slot"]), 0, 3)
	d["model"] = _n_model(ctx + ".model", d["model"])
	_hex(ctx + ".portrait_color", str(d["portrait_color"]))
	return d


func _n_model(ctx: String, raw: Variant) -> Dictionary:
	var m: Dictionary = _norm(ctx, raw, SPEC_MODEL)
	if m.is_empty():
		return m
	_enum(ctx + ".base", str(m["base"]), MODEL_BASES)
	_range_f(ctx + ".scale", float(m["scale"]), 0.3, 4.0)
	_enum(ctx + ".pose", str(m["pose"]), MODEL_POSES)
	var colors: Dictionary = m["colors"]
	var nc: Dictionary = {}
	for k: Variant in colors.keys():
		var key: String = str(k)
		if not MODEL_COLOR_KEYS.has(key):
			_err(ctx + ".colors." + key, "unknown color key (%s)" % ", ".join(MODEL_COLOR_KEYS))
			continue
		if typeof(colors[k]) != TYPE_STRING or not is_hex_color(str(colors[k])):
			_err(ctx + ".colors." + key, "must be a hex color \"#rrggbb\"")
			continue
		nc[key] = str(colors[k])
	if not nc.has("primary"):
		_err(ctx + ".colors.primary", "missing required field")
	m["colors"] = nc
	_subset(ctx + ".props", m["props"], MODEL_PROPS)
	var gltf: String = str(m["gltf"])
	if gltf != "" and not gltf.begins_with("res://"):
		_err(ctx + ".gltf", "must be a res:// path or \"\"")
	return m


func _n_enemy(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_ENEMY)
	if d.is_empty():
		return d
	_range_i(ctx + ".level", int(d["level"]), 1, 99)
	d["stats"] = _num_dict(ctx + ".stats", d["stats"], STATS, true, 0.0, 99999.0, true)
	if (d["stats"] as Dictionary).has("hp") and int(d["stats"]["hp"]) < 1:
		_err(ctx + ".stats.hp", "must be >= 1")
	_range_i(ctx + ".exp", int(d["exp"]), 0, 999999)
	_range_i(ctx + ".credits", int(d["credits"]), 0, 999999)
	var ai: Dictionary = _norm(ctx + ".ai", d["ai"], SPEC_AI)
	if ai.is_empty():
		ai = {"type": "weighted", "actions": []}
	_enum(ctx + ".ai.type", str(ai["type"]), AI_TYPES)
	ai["actions"] = _n_ai_actions(ctx + ".ai.actions", ai["actions"])
	d["ai"] = ai
	var phases: Array[Dictionary] = []
	var raw_ph: Array = d["phases"]
	for i in raw_ph.size():
		var pctx: String = "%s.phases[%d]" % [ctx, i]
		var p: Dictionary = _norm(pctx, raw_ph[i], SPEC_PHASE)
		if p.is_empty():
			continue
		_range_f(pctx + ".hp_above", float(p["hp_above"]), 0.0, 1.0)
		var ops: Array[Dictionary] = []
		var raw_ops: Array = p["on_enter"]
		for j in raw_ops.size():
			var o: Dictionary = _n_phase_op("%s.on_enter[%d]" % [pctx, j], raw_ops[j])
			if not o.is_empty():
				ops.append(o)
		p["on_enter"] = ops
		p["actions"] = _n_ai_actions(pctx + ".actions", p["actions"])
		phases.append(p)
	d["phases"] = phases
	# Rule 6: phased ⇔ phases non-empty; hp_above strictly descending, last 0.0.
	var phased: bool = str(ai["type"]) == "phased"
	if phased and phases.is_empty():
		_err(ctx + ".phases", "ai.type phased needs phases")
	if not phased and not phases.is_empty():
		_err(ctx + ".phases", "phases only allowed with ai.type phased")
	if phased and not (ai["actions"] as Array).is_empty():
		_err(ctx + ".ai.actions", "must be empty for ai.type phased (actions live in phases)")
	for i in phases.size():
		if i > 0 and float(phases[i]["hp_above"]) >= float(phases[i - 1]["hp_above"]):
			_err("%s.phases[%d].hp_above" % [ctx, i], "must be strictly descending")
	if not phases.is_empty() and float(phases[phases.size() - 1]["hp_above"]) != 0.0:
		_err("%s.phases[%d].hp_above" % [ctx, phases.size() - 1], "last phase must have hp_above 0.0")
	d["element_mods"] = _num_dict(ctx + ".element_mods", d["element_mods"], ELEMENTS, false, 0.0, 3.0)
	d["status_resist"] = _num_dict(ctx + ".status_resist", d["status_resist"], [], false, 0.0, 1.0)
	var drops: Array[Dictionary] = []
	var raw_dr: Array = d["drops"]
	for i in raw_dr.size():
		var dctx: String = "%s.drops[%d]" % [ctx, i]
		var dr: Dictionary = _norm(dctx, raw_dr[i], SPEC_DROP)
		if dr.is_empty():
			continue
		_range_f(dctx + ".chance", float(dr["chance"]), 0.0, 1.0)
		drops.append(dr)
	d["drops"] = drops
	var bdrops: Array[Dictionary] = []
	var raw_bd: Array = d["boss_drops"]
	for i in raw_bd.size():
		var bctx: String = "%s.boss_drops[%d]" % [ctx, i]
		var bd: Dictionary = _norm(bctx, raw_bd[i], SPEC_BOSS_DROP)
		if bd.is_empty():
			continue
		_enum(bctx + ".kind", str(bd["kind"]), ["item", "box"])
		_range_i(bctx + ".amount", int(bd["amount"]), 1, 99)
		bdrops.append(bd)
	d["boss_drops"] = bdrops
	d["model"] = _n_model(ctx + ".model", d["model"])
	var ex: Dictionary = _norm(ctx + ".explore", d["explore"], SPEC_EXPLORE)
	for f: Array in SPEC_EXPLORE:
		if ex.has(f[0]):
			_range_f(ctx + ".explore." + str(f[0]), float(ex[f[0]]), 0.0, 1000.0)
	if ex.has("sight_angle_deg"):
		_range_f(ctx + ".explore.sight_angle_deg", float(ex["sight_angle_deg"]), 0.0, 360.0)
	d["explore"] = ex
	return d


func _n_ai_actions(ctx: String, raw: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in raw.size():
		var actx: String = "%s[%d]" % [ctx, i]
		var a: Dictionary = _norm(actx, raw[i], SPEC_AI_ACTION)
		if a.is_empty():
			continue
		_range_i(actx + ".weight", int(a["weight"]), 1, 1000)
		var target: String = str(a["target"])
		if target.begins_with("not_status:"):
			if target.trim_prefix("not_status:") == "":
				_err(actx + ".target", "not_status needs a status id (not_status:<sts_id>)")
		elif target == "not_status" or not AI_TARGETS.has(target):
			_err(actx + ".target", "'%s' not in %s (or not_status:<sts_id>)" % [target, ", ".join(AI_TARGETS)])
		a["cond"] = _n_ai_cond(actx + ".cond", a["cond"])
		out.append(a)
	return out


func _n_ai_cond(ctx: String, raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw.keys():
		var key: String = str(k)
		var v: Variant = raw[k]
		var kctx: String = ctx + "." + key
		match key:
			"self_hp_below", "self_hp_above", "ally_hp_below":
				if not JsonUtil.is_number(v):
					_err(kctx, "expected number 0..1")
					continue
				_range_f(kctx, float(v), 0.0, 1.0)
				out[key] = float(v)
			"turn_mod":
				if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2 or not JsonUtil.is_integral((v as Array)[0]) \
						or not JsonUtil.is_integral((v as Array)[1]):
					_err(kctx, "expected [n, r] (integers)")
					continue
				var n: int = int((v as Array)[0])
				var r: int = int((v as Array)[1])
				if n < 1 or r < 0 or r >= n:
					_err(kctx, "needs n >= 1 and 0 <= r < n")
				out[key] = [n, r]
			"allies_alive_below":
				if not JsonUtil.is_integral(v) or int(v) < 1:
					_err(kctx, "expected integer >= 1")
					continue
				out[key] = int(v)
			"once":
				if typeof(v) != TYPE_BOOL:
					_err(kctx, "expected bool")
					continue
				out[key] = bool(v)
			_:
				_err(kctx, "unknown AI condition (%s)" % ", ".join(AI_CONDITIONS))
	return out


func _n_phase_op(ctx: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		_err(ctx, "expected object")
		return {}
	var rd: Dictionary = raw
	var op: String = str(rd.get("op", ""))
	if not SPEC_OPS.has(op):
		_err(ctx + ".op", "'%s' not in %s" % [op, ", ".join(PHASE_OPS)])
		return {}
	var o: Dictionary = _norm(ctx, raw, SPEC_OPS[op])
	if o.is_empty():
		return o
	match op:
		"say":
			_referenced_tags[str(o["tag"])] = ctx + ".tag"
		"status_self":
			_range_i(ctx + ".turns", int(o["turns"]), 1, 99)
		"summon":
			_range_i(ctx + ".count", int(o["count"]), 1, 3)
		"fixed_damage_self":
			_range_i(ctx + ".amount", int(o["amount"]), 1, 99999)
			_range_i(ctx + ".min_hp", int(o["min_hp"]), 1, 99999)
		"add_pseudo":
			_range_i(ctx + ".ctr", int(o["ctr"]), 0, 9999)
	return o


func _n_floor(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_FLOOR)
	if d.is_empty():
		return d
	var raw_d: Dictionary = raw
	var idx: int = int(d["index"])
	_range_i(ctx + ".index", idx, 1, 99)
	if str(d["id"]) != "floor_%d" % idx:
		_err(ctx + ".id", "must be floor_<index> (floor_%d)" % idx)
	var theme: String = str(d["theme"])
	_enum(ctx + ".theme", theme, THEMES)
	var timer: int = int(d["timer_seconds"])
	_range_i(ctx + ".timer_seconds", timer, 60, 7200)
	var tw: PackedInt32Array = d["timer_warnings"]
	for i in tw.size():
		if tw[i] <= 0 or tw[i] >= timer:
			_err("%s.timer_warnings[%d]" % [ctx, i], "must be > 0 and < timer_seconds")
		if i > 0 and tw[i] >= tw[i - 1]:
			_err("%s.timer_warnings[%d]" % [ctx, i], "must be strictly descending")
	_range_f(ctx + ".floor_mult", float(d["floor_mult"]), 0.1, 100.0)
	var grid: Dictionary = _norm(ctx + ".grid", d["grid"], SPEC_GRID)
	if grid.is_empty():
		grid = {"w": 3, "h": 3}
	_range_i(ctx + ".grid.w", int(grid["w"]), 3, 12)
	_range_i(ctx + ".grid.h", int(grid["h"]), 3, 12)
	d["grid"] = grid
	var has_layout: bool = not (d["layout"] as Dictionary).is_empty()
	for key: String in ["rooms", "chests", "enemy_groups"]:
		if not has_layout and not raw_d.has(key):
			_err(ctx + "." + key, "required for procedural floors (no layout)")
		var mm: Dictionary = {"min": 0, "max": 0}
		if raw_d.has(key):
			mm = _norm(ctx + "." + key, d[key], SPEC_MINMAX)
			if mm.is_empty():
				mm = {"min": 0, "max": 0}
			elif int(mm["min"]) > int(mm["max"]):
				_err(ctx + "." + key, "min must be <= max")
		d[key] = mm
	if not has_layout:
		var cells_max: int = int(grid["w"]) * int(grid["h"]) - 2
		var rooms: Dictionary = d["rooms"]
		if int(rooms["min"]) < 6 or int(rooms["max"]) > cells_max:
			_err(ctx + ".rooms", "needs 6 <= min <= max <= w*h-2 (%d)" % cells_max)
		for key: String in ["chests", "enemy_groups"]:
			var mm2: Dictionary = d[key]
			_range_i(ctx + "." + key + ".min", int(mm2["min"]), 0, 20)
			_range_i(ctx + "." + key + ".max", int(mm2["max"]), 0, 20)
		if not raw_d.has("chest_table"):
			_err(ctx + ".chest_table", "required for procedural floors (no layout)")
	_range_i(ctx + ".safe_rooms", int(d["safe_rooms"]), 0, 3)
	var ct: Array[Dictionary] = []
	var raw_ct: Array = d["chest_table"]
	for i in raw_ct.size():
		var cctx: String = "%s.chest_table[%d]" % [ctx, i]
		var c: Dictionary = _norm(cctx, raw_ct[i], SPEC_CHEST_TABLE)
		if c.is_empty():
			continue
		_enum(cctx + ".kind", str(c["kind"]), ["item", "credits"])
		if str(c["kind"]) == "item" and str(c["id"]) == "":
			_err(cctx + ".id", "item entry needs an item id")
		_range_i(cctx + ".weight", int(c["weight"]), 1, 100000)
		_range_i(cctx + ".min", int(c["min"]), 1, 99999)
		if int(c["max"]) < int(c["min"]):
			_err(cctx + ".max", "must be >= min")
		ct.append(c)
	d["chest_table"] = ct
	# Encounters.
	var encs: Array[Dictionary] = []
	var raw_enc: Array = d["encounters"]
	var non_boss: int = 0
	for i in raw_enc.size():
		var ectx: String = _ctx(ctx + ".encounters", i, raw_enc[i])
		var e: Dictionary = _norm(ectx, raw_enc[i], SPEC_ENCOUNTER)
		if e.is_empty():
			continue
		var raw_e: Dictionary = raw_enc[i]
		var boss: bool = bool(e["boss"])
		if not raw_e.has("can_flee"):
			e["can_flee"] = not boss
		if not raw_e.has("weight"):
			e["weight"] = 0 if (boss or has_layout) else 10
		var ne: int = (e["enemies"] as PackedStringArray).size()
		if ne < 1 or ne > 4:
			_err(ectx + ".enemies", "needs 1..4 enemy ids (got %d)" % ne)
		_range_i(ectx + ".weight", int(e["weight"]), 0, 100000)
		_range_f(ectx + ".min_depth", float(e["min_depth"]), 0.0, 1.0)
		_range_f(ectx + ".max_depth", float(e["max_depth"]), 0.0, 1.0)
		if float(e["min_depth"]) > float(e["max_depth"]):
			_err(ectx + ".min_depth", "must be <= max_depth")
		if str(e["music"]) != "":
			_enum(ectx + ".music", str(e["music"]), MUSIC_IDS)
		if not boss:
			non_boss += 1
		encs.append(e)
	if non_boss < 1:
		_err(ctx + ".encounters", "needs at least one non-boss encounter")
	d["encounters"] = encs
	# Palette: given keys over theme defaults.
	var pal: Dictionary = (THEME_PALETTES.get(theme, THEME_PALETTES["metro"]) as Dictionary).duplicate()
	var given: Dictionary = _n_palette(ctx + ".palette", d["palette"])
	for k: Variant in given.keys():
		pal[k] = given[k]
	d["palette"] = pal
	_enum(ctx + ".music", str(d["music"]), MUSIC_IDS)
	var q: Dictionary = d["quest"]
	if not q.is_empty():
		q = _norm(ctx + ".quest", q, SPEC_QUEST)
		if not q.is_empty():
			_enum(ctx + ".quest.type", str(q["type"]), QUEST_TYPES)
		d["quest"] = q
	var w: Dictionary = d["window"]
	if not w.is_empty():
		w = _norm(ctx + ".window", w, SPEC_WINDOW)
		if not w.is_empty():
			for key: String in ["open_at", "close_at"]:
				var ts: String = str(w[key])
				if ts != "" and not _matches("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", ts):
					_err(ctx + ".window." + key, "must be ISO-8601 UTC (YYYY-MM-DDThh:mm:ssZ)")
			_range_i(ctx + ".window.duration_sec", int(w["duration_sec"]), 0, 604800)
		d["window"] = w
	if has_layout:
		d["layout"] = _n_layout(ctx + ".layout", d["layout"], idx)
	return d


func _n_palette(ctx: String, raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw.keys():
		var key: String = str(k)
		if not PALETTE_KEYS.has(key) and not PALETTE_ART_KEYS.has(key):
			_err(ctx + "." + key, "unknown palette key")
			continue
		if typeof(raw[k]) != TYPE_STRING or not is_hex_color(str(raw[k])):
			_err(ctx + "." + key, "must be a hex color \"#rrggbb\"")
			continue
		out[key] = str(raw[k])
	return out


func _n_layout(ctx: String, raw: Dictionary, floor_index: int) -> Dictionary:
	var l: Dictionary = _norm(ctx, raw, SPEC_LAYOUT)
	if l.is_empty():
		return l
	var cells: Array[Dictionary] = []
	var raw_cells: Array = l["cells"]
	for i in raw_cells.size():
		var cctx: String = "%s.cells[%d]" % [ctx, i]
		var c: Dictionary = _norm(cctx, raw_cells[i], SPEC_CELL)
		if c.is_empty():
			continue
		_enum(cctx + ".kind", str(c["kind"]), CELL_KINDS)
		var doors: String = str(c["doors"])
		var seen: Dictionary = {}
		for ch: String in doors:
			if not DIR_OFFSETS.has(ch) or seen.has(ch):
				_err(cctx + ".doors", "must be a subset of \"NESW\" without repeats (got \"%s\")" % doors)
				break
			seen[ch] = true
		cells.append(c)
	l["cells"] = cells
	var zones: Array[Dictionary] = []
	var raw_zones: Array = l["zones"]
	for i in raw_zones.size():
		var zctx: String = _ctx(ctx + ".zones", i, raw_zones[i])
		var z: Dictionary = _norm(zctx, raw_zones[i], SPEC_ZONE)
		if z.is_empty():
			continue
		z["palette"] = _n_palette(zctx + ".palette", z["palette"])
		zones.append(z)
	l["zones"] = zones
	var gates: Array[Dictionary] = []
	var raw_gates: Array = l["gates"]
	for i in raw_gates.size():
		var gctx: String = "%s.gates[%d]" % [ctx, i]
		var g: Dictionary = _norm(gctx, raw_gates[i], SPEC_GATE)
		if g.is_empty():
			continue
		_enum(gctx + ".dir", str(g["dir"]), ["N", "E", "S", "W"])
		gates.append(g)
	l["gates"] = gates
	var placed: Array[Dictionary] = []
	var raw_placed: Array = l["encounters_placed"]
	for i in raw_placed.size():
		var pctx: String = "%s.encounters_placed[%d]" % [ctx, i]
		var p: Dictionary = _norm(pctx, raw_placed[i], SPEC_PLACED)
		if p.is_empty():
			continue
		_enum(pctx + ".state", str(p["state"]), ENEMY_START_STATES)
		var wps: Array = []
		var raw_wp: Array = p["waypoints"]
		for j in raw_wp.size():
			var conv: Array = _convert(raw_wp[j], "v2")
			if not bool(conv[0]):
				_err("%s.waypoints[%d]" % [pctx, j], "expected [x, z] numbers")
				continue
			wps.append(conv[1])
		p["waypoints"] = wps
		placed.append(p)
	l["encounters_placed"] = placed
	var chests: Array[Dictionary] = []
	var raw_chests: Array = l["chests"]
	for i in raw_chests.size():
		var cctx: String = _ctx(ctx + ".chests", i, raw_chests[i])
		var c: Dictionary = _norm(cctx, raw_chests[i], SPEC_CHEST)
		if c.is_empty():
			continue
		var ctype: String = str(c["type"])
		_enum(cctx + ".type", ctype, CHEST_TYPES)
		var contents: Array[Dictionary] = []
		var raw_ct: Array = c["contents"]
		for j in raw_ct.size():
			var ictx: String = "%s.contents[%d]" % [cctx, j]
			var it: Dictionary = _norm(ictx, raw_ct[j], SPEC_CONTENT)
			if it.is_empty():
				continue
			_enum(ictx + ".kind", str(it["kind"]), ["item", "credits"])
			if str(it["kind"]) == "item" and str(it["id"]) == "":
				_err(ictx + ".id", "item entry needs an item id")
			_range_i(ictx + ".amount", int(it["amount"]), 1, 99999)
			contents.append(it)
		c["contents"] = contents
		if (ctype == "metal" or ctype == "locked") and contents.is_empty():
			_err(cctx + ".contents", "required for metal/locked chests")
		if ctype == "wood" and not contents.is_empty():
			_err(cctx + ".contents", "must be empty for wood chests (rolled from pools)")
		chests.append(c)
	l["chests"] = chests
	var events: Array[Dictionary] = []
	var raw_events: Array = l["events"]
	for i in raw_events.size():
		var ectx: String = _ctx(ctx + ".events", i, raw_events[i])
		var e: Dictionary = _norm(ectx, raw_events[i], SPEC_EVENT)
		if e.is_empty():
			continue
		var etype: String = str(e["type"])
		if not FLOOR_EVENT_TYPES.has(etype):
			_enum(ectx + ".type", etype, FLOOR_EVENT_TYPES)
		else:
			var spec: Array = []
			for f: Array in FLOOR_EVENT_PARAMS[etype]:
				spec.append([f[0], f[1]])
			var params: Dictionary = _norm(ectx + ".params", e["params"], spec)
			if not params.is_empty():
				_n_event_params(ectx + ".params", etype, params)
			e["params"] = params
		events.append(e)
	l["events"] = events
	var spawners: Array[Dictionary] = []
	var raw_sp: Array = l["spawners"]
	for i in raw_sp.size():
		var sctx: String = "%s.spawners[%d]" % [ctx, i]
		var s: Dictionary = _norm(sctx, raw_sp[i], SPEC_SPAWNER)
		if s.is_empty():
			continue
		if (s["pool"] as PackedStringArray).is_empty():
			_err(sctx + ".pool", "must not be empty")
		_range_i(sctx + ".interval_sec", int(s["interval_sec"]), 10, 600)
		spawners.append(s)
	l["spawners"] = spawners
	var srs: Array[Dictionary] = []
	var raw_sr: Array = l["safe_rooms"]
	if raw_sr.size() > 3:
		_err(ctx + ".safe_rooms", "at most 3 safe rooms")
	for i in raw_sr.size():
		var sctx: String = _ctx(ctx + ".safe_rooms", i, raw_sr[i])
		var s: Dictionary = _norm(sctx, raw_sr[i], SPEC_SAFE_ROOM)
		if s.is_empty():
			continue
		_enum(sctx + ".theme", str(s["theme"]), SAFE_ROOM_THEMES)
		srs.append(s)
	l["safe_rooms"] = srs
	var st: Dictionary = _norm(ctx + ".stairs", l["stairs"], SPEC_STAIRS)
	l["stairs"] = st
	return l


func _n_event_params(ctx: String, etype: String, p: Dictionary) -> void:
	match etype:
		"lost_candidate":
			_enum(ctx + ".tag", str(p["tag"]), ITEM_TAGS)
			_range_i(ctx + ".followers", int(p["followers"]), 0, 100000)
		"wheel":
			_range_i(ctx + ".cost", int(p["cost"]), 0, 99999)
			_range_i(ctx + ".max_spins", int(p["max_spins"]), 1, 99)
			var table: Array[Dictionary] = []
			var raw_t: Array = p["table"]
			if raw_t.is_empty():
				_err(ctx + ".table", "must not be empty")
			for i in raw_t.size():
				var tctx: String = "%s.table[%d]" % [ctx, i]
				var e: Dictionary = _norm(tctx, raw_t[i], SPEC_WHEEL_ENTRY)
				if e.is_empty():
					continue
				_enum(tctx + ".kind", str(e["kind"]), LOOT_KINDS)
				_range_i(tctx + ".weight", int(e["weight"]), 1, 100000)
				var k: String = str(e["kind"])
				# GDD §2.6 wheel table: "nothing" carries amount 0 (any amount is ignored); every other kind ≥ 1
				_range_i(tctx + ".amount", int(e["amount"]), 0 if k == "nothing" else 1, 99999)
				if (k == "item" or k == "box" or k == "encounter") and str(e["id"]) == "":
					_err(tctx + ".id", "required for kind %s" % k)
				table.append(e)
			p["table"] = table
		"lever":
			_range_f(ctx + ".success", float(p["success"]), 0.0, 1.0)
			_range_i(ctx + ".flood_pct", int(p["flood_pct"]), 0, 100)
			if not _matches("^-?[0-9]+,-?[0-9]+,[NESW]$", str(p["gate"])):
				_err(ctx + ".gate", "must be \"x,y,D\"")
		"broken_vending":
			_range_f(ctx + ".base", float(p["base"]), 0.0, 1.0)
			_range_f(ctx + ".per_lck", float(p["per_lck"]), 0.0, 1.0)
			_range_i(ctx + ".reward_amount", int(p["reward_amount"]), 1, 99)
			_range_i(ctx + ".fail_pct", int(p["fail_pct"]), 0, 100)
			_range_i(ctx + ".fail_hype", int(p["fail_hype"]), -100, 100)
		"photo_drone":
			_range_i(ctx + ".pose_hype", int(p["pose_hype"]), -100, 100)
			_range_i(ctx + ".pose_followers", int(p["pose_followers"]), 0, 100000)
			_range_i(ctx + ".smash_credits", int(p["smash_credits"]), 0, 99999)
			_range_i(ctx + ".smash_hype", int(p["smash_hype"]), -100, 100)


func _n_lootbox(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_LOOTBOX)
	if d.is_empty():
		return d
	_range_i(ctx + ".tier", int(d["tier"]), 1, 4)
	_hex(ctx + ".color", str(d["color"]))
	_range_i(ctx + ".rolls", int(d["rolls"]), 1, 10)
	var rw: Dictionary = _norm(ctx + ".rarity_weights", d["rarity_weights"], SPEC_RARITY_WEIGHTS)
	if rw.is_empty():
		rw = {"common": 1, "rare": 0, "epic": 0}
	var total: int = 0
	for k: String in ["common", "rare", "epic"]:
		if int(rw[k]) < 0:
			_err(ctx + ".rarity_weights." + k, "must be >= 0")
		total += int(rw[k])
	if total <= 0:
		_err(ctx + ".rarity_weights", "sum must be > 0")
	d["rarity_weights"] = rw
	_enum(ctx + ".guarantee", str(d["guarantee"]), ["", "rare", "epic"])
	_enum(ctx + ".fixed_pool", str(d["fixed_pool"]), ["", "fan"])
	var tag: String = str(d["mod_tag"])
	if tag == "":
		tag = "lootbox_open_" + str(d["id"]).trim_prefix("box_")
	_referenced_tags[tag] = ctx + ".mod_tag"
	return d


func _n_achievement(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_ACHIEVEMENT)
	if d.is_empty():
		return d
	_enum(ctx + ".trigger", str(d["trigger"]), ACH_TRIGGERS)
	if int(d["followers"]) < -1:
		_err(ctx + ".followers", "must be -1 (by box tier) or >= 0")
	if str(d["mod_tag"]) != "":
		_referenced_tags[str(d["mod_tag"])] = ctx + ".mod_tag"
	return d


func _n_sponsor(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_SPONSOR)
	if d.is_empty():
		return d
	_hex(ctx + ".color", str(d["color"]))
	var gifts: Array[Dictionary] = []
	var raw_g: Array = d["gift"]
	if raw_g.size() < 1 or raw_g.size() > 3:
		_err(ctx + ".gift", "needs 1..3 effects (got %d)" % raw_g.size())
	for i in raw_g.size():
		var gctx: String = "%s.gift[%d]" % [ctx, i]
		var g: Dictionary = _norm(gctx, raw_g[i], SPEC_GIFT_EFFECT)
		if g.is_empty():
			continue
		var kind: String = str(g["kind"])
		_enum(gctx + ".kind", kind, GIFT_KINDS)
		if str(g["target"]) == "":
			g["target"] = "enemies" if kind == "status_enemies" else "party"
		var want_target: String = "enemies" if kind == "status_enemies" else "party"
		if str(g["target"]) != want_target:
			_err(gctx + ".target", "must be \"%s\" for kind %s" % [want_target, kind])
		match kind:
			"heal_party_pct", "mp_party_pct", "revive_or_heal_lowest":
				_range_i(gctx + ".value", int(g["value"]), 1, 100)
			"heal_party_flat":
				_range_i(gctx + ".value", int(g["value"]), 1, 9999)
			"status_party", "status_enemies":
				if str(g["status"]) == "":
					_err(gctx + ".status", "required for kind " + kind)
				_range_i(gctx + ".turns", int(g["turns"]), 1, 99)
			"item":
				if str(g["item"]) == "":
					_err(gctx + ".item", "required for kind item")
				_range_i(gctx + ".value", int(g["value"]), 1, 99)
		gifts.append(g)
	d["gift"] = gifts
	_range_i(ctx + ".weight", int(d["weight"]), 1, 100000)
	var mods: Array[Dictionary] = []
	var raw_m: Array = d["weight_mods"]
	for i in raw_m.size():
		var mctx: String = "%s.weight_mods[%d]" % [ctx, i]
		var m: Dictionary = _norm(mctx, raw_m[i], SPEC_WEIGHT_MOD)
		if m.is_empty():
			continue
		_enum(mctx + ".cond", str(m["cond"]), SPONSOR_WEIGHT_CONDS)
		if float(m["mult"]) <= 0.0:
			_err(mctx + ".mult", "must be > 0")
		mods.append(m)
	d["weight_mods"] = mods
	_range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	_range_i(ctx + ".max_floor", int(d["max_floor"]), 0, 99)
	if int(d["max_floor"]) > 0 and int(d["max_floor"]) < int(d["min_floor"]):
		_err(ctx + ".max_floor", "must be 0 (unlimited) or >= min_floor")
	_referenced_tags[str(d["mod_tag"])] = ctx + ".mod_tag"
	return d


func _n_milestone(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_MILESTONE)
	if d.is_empty():
		return d
	_range_i(ctx + ".followers", int(d["followers"]), 1, 100000000)
	if str(d["id"]) != "ms_%d" % int(d["followers"]):
		_err(ctx + ".id", "must be ms_<followers> (ms_%d)" % int(d["followers"]))
	_range_i(ctx + ".credits", int(d["credits"]), 0, 999999)
	_range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	_referenced_tags[str(d["mod_tag"])] = ctx + ".mod_tag"
	return d


func _n_mod_line(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_MOD_LINE)
	if d.is_empty():
		return d
	var voice: String = str(d["voice"])
	_enum(ctx + ".voice", voice, VOICES)
	_text_len(ctx + ".text", str(d["text"]))
	if str(d["user"]) != "" and voice != "chat":
		_err(ctx + ".user", "only allowed for voice chat")
	_range_i(ctx + ".weight", int(d["weight"]), 1, 1000)
	_range_i(ctx + ".min_floor", int(d["min_floor"]), 1, 99)
	_range_i(ctx + ".max_floor", int(d["max_floor"]), 0, 99)
	_range_i(ctx + ".min_hype", int(d["min_hype"]), 0, 100)
	_range_i(ctx + ".max_hype", int(d["max_hype"]), 0, 100)
	if int(d["min_hype"]) > int(d["max_hype"]):
		_err(ctx + ".min_hype", "must be <= max_hype")
	var tag: String = str(d["tag"])
	_mod_tags[tag] = int(_mod_tags.get(tag, 0)) + 1
	return d


func _n_scene(ctx: String, raw: Variant) -> Dictionary:
	var d: Dictionary = _norm(ctx, raw, SPEC_SCENE)
	if d.is_empty():
		return d
	var lines: Array[Dictionary] = []
	var raw_l: Array = d["lines"]
	if raw_l.size() < 1 or raw_l.size() > 40:
		_err(ctx + ".lines", "needs 1..40 lines (got %d)" % raw_l.size())
	for i in raw_l.size():
		var lctx: String = "%s.lines[%d]" % [ctx, i]
		var l: Dictionary = _norm(lctx, raw_l[i], SPEC_SCENE_LINE)
		if l.is_empty():
			continue
		_enum(lctx + ".voice", str(l["voice"]), ["mopsula", "kai", "mod"])
		_text_len(lctx + ".text", str(l["text"]))
		lines.append(l)
	d["lines"] = lines
	return d


# ======================================================================================================================
# Rule 3: ids
# ======================================================================================================================

func _build_lookups() -> void:
	_statuses = _index(_out["statuses"])
	_skills = _index(_out["skills"])
	_items = _index(_out["items"])
	_classes = _index(_out["classes"])
	_party = _index(_out["party"])
	_enemies = _index(_out["enemies"])
	_pseudo = _index(_out["pseudo_units"])
	_floors = {}
	_encounters = {}
	for f: Dictionary in _out["floors"]:
		_floors[int(f["index"])] = f
		for e: Dictionary in f["encounters"]:
			if not _encounters.has(str(e["id"])):
				_encounters[str(e["id"])] = {"def": e, "floor": int(f["index"])}
	_boxes = _index(_out["lootboxes"])
	_achievements = _index(_out["achievements"])
	_sponsors = _index(_out["sponsors"])
	_milestones = _index(_out["milestones"])


func _index(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for d: Dictionary in list:
		var id: String = str(d.get("id", ""))
		if id != "" and not out.has(id):
			out[id] = d
	return out


func _check_ids() -> void:
	var seen: Dictionary = {}
	for t: String in TABLES:
		var list: Array = _out[t]
		for i in list.size():
			var d: Dictionary = list[i]
			var ctx: String = _ctx(t, i, d)
			_check_id(seen, t, str(d["id"]), ctx + ".id")
			if t == "floors":
				var encs: Array = d["encounters"]
				for j in encs.size():
					_check_id(seen, "encounters", str(encs[j]["id"]), _ctx(ctx + ".encounters", j, encs[j]) + ".id")
				var lay: Dictionary = d["layout"]
				if not lay.is_empty():
					for key: String in ["events", "zones", "safe_rooms"]:
						if not lay.has(key):
							continue
						var kind: String = "floor_events" if key == "events" else key
						var sub: Array = lay[key]
						for j in sub.size():
							_check_id(seen, kind, str(sub[j]["id"]), _ctx(ctx + ".layout." + key, j, sub[j]) + ".id")
	var pus: Array = _out["pseudo_units"]
	for i in pus.size():
		_check_id(seen, "pseudo_units", str(pus[i]["id"]), _ctx("enemies.pseudo_units", i, pus[i]) + ".id")


func _check_id(seen: Dictionary, kind: String, id: String, ctx: String) -> void:
	var pattern: String = str(ID_PATTERNS.get(kind, ""))
	if pattern != "" and not _matches(pattern, id):
		_err(ctx, "invalid id '%s' (pattern %s)" % [id, pattern])
	if seen.has(id):
		_err(ctx, "duplicate id '%s' (already used at %s)" % [id, str(seen[id])])
	else:
		seen[id] = ctx


# ======================================================================================================================
# Rules 5 + 6: references and cross-table type consistency
# ======================================================================================================================

func _check_references() -> void:
	_refs_statuses()
	_refs_skills()
	_refs_items()
	_refs_classes()
	_refs_party()
	_refs_enemies()
	_refs_floors()
	_refs_lootboxes()
	_refs_misc()


func _ref(ctx: String, id: String, table: Dictionary, what: String) -> bool:
	if id == "":
		return false
	if not table.has(id):
		_err(ctx, "unknown %s '%s'" % [what, id])
		return false
	return true


func _refs_statuses() -> void:
	var list: Array = _out["statuses"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("statuses", i, d)
		for s: String in d["excludes"]:
			_ref(ctx + ".excludes", s, _statuses, "status")


func _refs_skills() -> void:
	var list: Array = _out["skills"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("skills", i, d)
		var sts: Array = d["statuses"]
		for j in sts.size():
			_ref("%s.statuses[%d].id" % [ctx, j], str(sts[j]["id"]), _statuses, "status")
		for s: String in d["cleanse"]:
			_ref(ctx + ".cleanse", s, _statuses, "status")
		for e: String in d["summon"]:
			_ref(ctx + ".summon", e, _enemies, "enemy")
		var fe: Dictionary = d["fail_effect"]
		if not fe.is_empty() and str(fe.get("status", "")) != "":
			_ref(ctx + ".fail_effect.status", str(fe["status"]), _statuses, "status")


func _refs_items() -> void:
	var list: Array = _out["items"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("items", i, d)
		var us: String = str(d["use_skill"])
		if us != "" and _ref(ctx + ".use_skill", us, _skills, "skill"):
			if str(_skills[us]["user"]) != "item":
				_err(ctx + ".use_skill", "skill '%s' must have user \"item\"" % us)
		for s: String in d["status_immune"]:
			_ref(ctx + ".status_immune", s, _statuses, "status")
		for m: String in d["equip_by"]:
			_ref(ctx + ".equip_by", m, _party, "party member")


func _refs_classes() -> void:
	var list: Array = _out["classes"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("classes", i, d)
		for m: String in d["for"]:
			_ref(ctx + ".for", m, _party, "party member")
		var ls: Array = d["learnset"]
		for j in ls.size():
			var sk: String = str(ls[j]["skill"])
			if not _skills.has(sk):
				var msg: String = "%s.learnset[%d].skill: unknown skill '%s'" % [ctx, j, sk]
				if int(d["min_floor"]) > 1:
					warnings.append(msg)
				else:
					errors.append(msg)
			else:
				_check_party_user("%s.learnset[%d].skill" % [ctx, j], sk)


## Skills of party members (learnset, stunts, attack_skill, class learnset) need user "party" or "any".
func _check_party_user(ctx: String, skill_id: String) -> void:
	var user: String = str(_skills[skill_id]["user"])
	if user != "party" and user != "any":
		_err(ctx, "skill '%s' has user \"%s\" (party skills need user party or any)" % [skill_id, user])


func _refs_party() -> void:
	var list: Array = _out["party"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("party", i, d)
		_check_attack_skill(ctx + ".attack_skill", str(d["attack_skill"]), "party")
		if _skills.has(str(d["attack_skill"])):
			_check_party_user(ctx + ".attack_skill", str(d["attack_skill"]))
		var ls: Array = d["learnset"]
		for j in ls.size():
			var lctx: String = "%s.learnset[%d].skill" % [ctx, j]
			if _ref(lctx, str(ls[j]["skill"]), _skills, "skill"):
				_check_party_user(lctx, str(ls[j]["skill"]))
		for s: String in d["stunts"]:
			if not _ref(ctx + ".stunts", s, _skills, "skill"):
				continue
			_check_party_user(ctx + ".stunts", s)
			if str(_skills[s]["category"]) != "stunt":
				_err(ctx + ".stunts", "skill '%s' must have category stunt" % s)
		var eq: Dictionary = d["equipment"]
		for slot: String in EQUIP_SLOTS:
			var item_id: String = str(eq.get(slot, ""))
			if item_id == "":
				continue
			if not _ref("%s.equipment.%s" % [ctx, slot], item_id, _items, "item"):
				continue
			var it: Dictionary = _items[item_id]
			if str(it["type"]) != slot:
				_err("%s.equipment.%s" % [ctx, slot], "item '%s' has type %s" % [item_id, str(it["type"])])
			var eb: PackedStringArray = it["equip_by"]
			if not eb.is_empty() and not eb.has(str(d["id"])):
				_err("%s.equipment.%s" % [ctx, slot], "item '%s' is not equippable by %s" % [item_id, str(d["id"])])
		for s: String in d["status_immune"]:
			_ref(ctx + ".status_immune", s, _statuses, "status")
		for s: Variant in (d["status_resist"] as Dictionary).keys():
			_ref(ctx + ".status_resist", str(s), _statuses, "status")
	var start: Dictionary = _out["party_start"]
	var inv: Dictionary = start.get("inventory", {})
	for k: Variant in inv.keys():
		var id: String = str(k)
		if _ref("party.start.inventory." + id, id, _items, "item"):
			_range_i("party.start.inventory." + id, int(inv[k]), 1, int(_items[id]["max_stack"]))


func _check_attack_skill(ctx: String, skill_id: String, side: String) -> void:
	if skill_id == "":
		_err(ctx, "required (attack skill id)")
		return
	if not _ref(ctx, skill_id, _skills, "skill"):
		return
	var s: Dictionary = _skills[skill_id]
	if str(s["category"]) != "attack" or str(s["damage_type"]) != "physical" or str(s["element"]) != "physical" \
			or str(s["target"]) != "single_enemy":
		_err(ctx, "attack skill '%s' needs category attack, damage_type/element physical, target single_enemy" % skill_id)
	if int(s["power"]) != 100 or int(s["rank"]) != 3:
		warnings.append("%s: attack skill '%s' should have power 100 and rank 3 (%s)" % [ctx, skill_id, side])


func _refs_enemies() -> void:
	var list: Array = _out["enemies"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("enemies", i, d)
		_check_attack_skill(ctx + ".attack_skill", str(d["attack_skill"]), "enemy")
		_refs_ai_actions(ctx + ".ai.actions", (d["ai"] as Dictionary).get("actions", []))
		var phases: Array = d["phases"]
		for j in phases.size():
			var pctx: String = "%s.phases[%d]" % [ctx, j]
			_refs_ai_actions(pctx + ".actions", phases[j]["actions"])
			var ops: Array = phases[j]["on_enter"]
			for k in ops.size():
				var o: Dictionary = ops[k]
				var octx: String = "%s.on_enter[%d]" % [pctx, k]
				match str(o["op"]):
					"status_self":
						_ref(octx + ".status", str(o["status"]), _statuses, "status")
					"summon":
						_ref(octx + ".enemy", str(o["enemy"]), _enemies, "enemy")
					"add_pseudo", "remove_pseudo":
						_ref(octx + ".unit", str(o["unit"]), _pseudo, "pseudo unit")
		for s: String in d["status_immune"]:
			_ref(ctx + ".status_immune", s, _statuses, "status")
		for s: Variant in (d["status_resist"] as Dictionary).keys():
			_ref(ctx + ".status_resist", str(s), _statuses, "status")
		var drops: Array = d["drops"]
		for j in drops.size():
			_ref("%s.drops[%d].item" % [ctx, j], str(drops[j]["item"]), _items, "item")
		var bd: Array = d["boss_drops"]
		for j in bd.size():
			var bctx: String = "%s.boss_drops[%d].id" % [ctx, j]
			if str(bd[j]["kind"]) == "box":
				_ref(bctx, str(bd[j]["id"]), _boxes, "lootbox")
			else:
				_ref(bctx, str(bd[j]["id"]), _items, "item")


func _refs_ai_actions(ctx: String, actions: Array) -> void:
	for i in actions.size():
		var a: Dictionary = actions[i]
		var actx: String = "%s[%d]" % [ctx, i]
		var sk: String = str(a["skill"])
		var target: String = str(a["target"])
		if target.begins_with("not_status:"):
			_ref(actx + ".target", target.trim_prefix("not_status:"), _statuses, "status")
		if not _ref(actx + ".skill", sk, _skills, "skill"):
			continue
		var st: String = str(_skills[sk]["target"])
		var rule: String = "not_status" if target.begins_with("not_status:") else target
		var allowed: PackedStringArray = []
		match st:
			"single_enemy":
				allowed = ["random", "lowest_hp_pct", "highest_hp", "not_status"]
			"single_ally":
				allowed = ["ally_lowest_hp_pct", "self"]
			"all_enemies", "all_allies", "self":
				allowed = [st]
		if not allowed.is_empty() and not allowed.has(rule):
			_err(actx + ".target", "rule '%s' does not fit skill target %s (allowed: %s)" % [target, st, ", ".join(allowed)])


func _refs_floors() -> void:
	var list: Array = _out["floors"]
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("floors", i, d)
		var encs: Array = d["encounters"]
		var own: Dictionary = {}
		for j in encs.size():
			var e: Dictionary = encs[j]
			own[str(e["id"])] = e
			var ectx: String = _ctx(ctx + ".encounters", j, e)
			for en: String in e["enemies"]:
				_ref(ectx + ".enemies", en, _enemies, "enemy")
		var tsa: String = str(d["timer_start_after"])
		if tsa != "" and not own.has(tsa):
			_err(ctx + ".timer_start_after", "unknown encounter '%s' on this floor" % tsa)
		for key: String in ["quarter_boss", "floor_boss"]:
			var enc_id: String = str(d[key])
			if enc_id == "":
				continue
			if not own.has(enc_id):
				_err(ctx + "." + key, "unknown encounter '%s' on this floor" % enc_id)
			elif not bool(own[enc_id]["boss"]):
				_err(ctx + "." + key, "encounter '%s' must have boss: true" % enc_id)
		var ct: Array = d["chest_table"]
		for j in ct.size():
			if str(ct[j]["kind"]) == "item":
				_ref("%s.chest_table[%d].id" % [ctx, j], str(ct[j]["id"]), _items, "item")
		_refs_shop(ctx + ".shop", d["shop"])
		var lay: Dictionary = d["layout"]
		if lay.is_empty():
			continue
		var lctx: String = ctx + ".layout"
		var fev: Dictionary = {}
		for ev: Dictionary in lay.get("events", []):
			fev[str(ev["id"])] = ev
		var gates: Array = lay.get("gates", [])
		for j in gates.size():
			var req: String = str(gates[j]["requires"])
			var gctx: String = "%s.gates[%d].requires" % [lctx, j]
			if req.begins_with("event:"):
				_ref(gctx, req.trim_prefix("event:"), fev, "floor event of this floor")
			else:
				_ref(gctx, req, _items, "item")
		var placed: Array = lay.get("encounters_placed", [])
		for j in placed.size():
			_ref("%s.encounters_placed[%d].enc_id" % [lctx, j], str(placed[j]["enc_id"]), own, "encounter of this floor")
		var chests: Array = lay.get("chests", [])
		for j in chests.size():
			var contents: Array = chests[j]["contents"]
			for k in contents.size():
				if str(contents[k]["kind"]) == "item":
					_ref("%s.contents[%d].id" % [_ctx(lctx + ".chests", j, chests[j]), k], str(contents[k]["id"]), _items, "item")
		var events: Array = lay.get("events", [])
		for j in events.size():
			_refs_event(_ctx(lctx + ".events", j, events[j]), events[j], own, gates)
		var spawners: Array = lay.get("spawners", [])
		var zone_ids: Dictionary = {}
		for z: Dictionary in lay.get("zones", []):
			zone_ids[str(z["id"])] = true
		for j in spawners.size():
			var sctx: String = "%s.spawners[%d]" % [lctx, j]
			_ref(sctx + ".zone", str(spawners[j]["zone"]), zone_ids, "zone")
			for enc_id: String in spawners[j]["pool"]:
				if _ref(sctx + ".pool", enc_id, own, "encounter of this floor") and bool(own[enc_id]["boss"]):
					_err(sctx + ".pool", "boss encounter '%s' cannot be a stray" % enc_id)
		var srs: Array = lay.get("safe_rooms", [])
		for j in srs.size():
			_refs_shop(_ctx(lctx + ".safe_rooms", j, srs[j]) + ".shop", srs[j]["shop"])


func _refs_shop(ctx: String, shop: PackedStringArray) -> void:
	for id: String in shop:
		if _ref(ctx, id, _items, "item") and int(_items[id]["price"]) <= 0:
			_err(ctx, "item '%s' has no price (> 0 required in shops)" % id)


func _refs_event(ctx: String, ev: Dictionary, own_encs: Dictionary, gates: Array) -> void:
	var p: Dictionary = ev["params"]
	if p.is_empty():
		return
	match str(ev["type"]):
		"lost_candidate":
			_ref(ctx + ".params.reward_item", str(p["reward_item"]), _items, "item")
		"broken_vending":
			_ref(ctx + ".params.reward_item", str(p["reward_item"]), _items, "item")
		"wheel":
			var table: Array = p["table"]
			for i in table.size():
				var e: Dictionary = table[i]
				var tctx: String = "%s.params.table[%d].id" % [ctx, i]
				match str(e["kind"]):
					"item":
						_ref(tctx, str(e["id"]), _items, "item")
					"box":
						_ref(tctx, str(e["id"]), _boxes, "lootbox")
					"encounter":
						_ref(tctx, str(e["id"]), own_encs, "encounter of this floor")
		"lever":
			_ref(ctx + ".params.encounter", str(p["encounter"]), own_encs, "encounter of this floor")
			var parts: PackedStringArray = str(p["gate"]).split(",")
			if parts.size() == 3:
				# Either side of the door may be named; normalized to the side the gate is defined on (= runtime key).
				var want: String = door_key(Vector2i(parts[0].to_int(), parts[1].to_int()), parts[2])
				var found: bool = false
				for g: Dictionary in gates:
					var gcell: Vector2i = _cell_of(g["cell"])
					if door_key(gcell, str(g["dir"])) != want:
						continue
					found = true
					p["gate"] = "%d,%d,%s" % [gcell.x, gcell.y, str(g["dir"])]
					if str(g["requires"]) != "event:" + str(ev["id"]):
						_err(ctx + ".params.gate", "gate %s must require \"event:%s\"" % [str(p["gate"]), str(ev["id"])])
					break
				if not found:
					_err(ctx + ".params.gate", "no layout gate at %s (either side of the door)" % str(p["gate"]))


func _refs_lootboxes() -> void:
	var pools: Dictionary = _out["lootbox_pools"]
	for key: Variant in pools.keys():
		var pool: Dictionary = pools[key]
		for rarity: Variant in pool.keys():
			var entries: Array = pool[rarity]
			for i in entries.size():
				if str(entries[i]["kind"]) == "item":
					_ref("lootboxes.pools.%s.%s[%d].id" % [str(key), str(rarity), i], str(entries[i]["id"]), _items, "item")


func _refs_misc() -> void:
	var achs: Array = _out["achievements"]
	for i in achs.size():
		var box: String = str(achs[i]["box"])
		if box != "":
			_ref(_ctx("achievements", i, achs[i]) + ".box", box, _boxes, "lootbox")
	var sps: Array = _out["sponsors"]
	for i in sps.size():
		var gifts: Array = sps[i]["gift"]
		for j in gifts.size():
			var gctx: String = "%s.gift[%d]" % [_ctx("sponsors", i, sps[i]), j]
			if str(gifts[j]["status"]) != "":
				_ref(gctx + ".status", str(gifts[j]["status"]), _statuses, "status")
			if str(gifts[j]["item"]) != "":
				_ref(gctx + ".item", str(gifts[j]["item"]), _items, "item")
	var mss: Array = _out["milestones"]
	var followers_seen: Dictionary = {}
	for i in mss.size():
		var ctx: String = _ctx("milestones", i, mss[i])
		if str(mss[i]["reward_box"]) != "":
			_ref(ctx + ".reward_box", str(mss[i]["reward_box"]), _boxes, "lootbox")
		if str(mss[i]["item"]) != "":
			_ref(ctx + ".item", str(mss[i]["item"]), _items, "item")
		var fol: int = int(mss[i]["followers"])
		if followers_seen.has(fol):
			_err(ctx + ".followers", "duplicate followers value %d" % fol)
		followers_seen[fol] = true
	var mls: Array = _out["mod_lines"]
	for i in mls.size():
		var tag: String = str(mls[i]["tag"])
		if not is_valid_mod_tag(tag, _referenced_tags):
			_err(_ctx("mod_lines", i, mls[i]) + ".tag", "unknown tag '%s'" % tag)


# ======================================================================================================================
# Rule 7: party (+ strict content checks: required lootboxes, non-empty pools)
# ======================================================================================================================

func _check_content_rules() -> void:
	for req: String in ["kai", "mopsula"]:
		if not _party.has(req):
			_err("party", "required member '%s' missing" % req)
	var slots: Dictionary = {}
	var list: Array = _out["party"]
	for i in list.size():
		var slot: int = int(list[i]["battle_slot"])
		if slots.has(slot):
			_err(_ctx("party", i, list[i]) + ".battle_slot", "duplicate battle_slot %d" % slot)
		slots[slot] = true
	for box: String in REQUIRED_BOXES:
		if not _boxes.has(box):
			_err("lootboxes", "required lootbox '%s' missing" % box)
	var pools: Dictionary = _out["lootbox_pools"]
	var needs_fan: bool = false
	for b: Dictionary in _out["lootboxes"]:
		if str(b["fixed_pool"]) == "fan":
			needs_fan = true
	if pools.is_empty():
		_err("lootboxes.pools", "needs at least one pool (f1)")
	for key: Variant in pools.keys():
		var pool: Dictionary = pools[key]
		for rarity: String in ["common", "rare", "epic"]:
			if (pool[rarity] as Array).is_empty():
				_err("lootboxes.pools.%s.%s" % [str(key), rarity], "must not be empty")
		if needs_fan and (pool["fan"] as Array).is_empty():
			_err("lootboxes.pools.%s.fan" % str(key), "must not be empty (a lootbox uses fixed_pool fan)")


# ======================================================================================================================
# Rule 8: floors + layout
# ======================================================================================================================

func _check_floor_rules() -> void:
	var list: Array = _out["floors"]
	if list.is_empty():
		_err("floors", "needs at least floor_1")
		return
	var indices: Array = _floors.keys()
	indices.sort()
	for k in indices.size():
		if int(indices[k]) != k + 1:
			_err("floors", "floor indices must be contiguous from 1 (missing floor_%d)" % (k + 1))
			break
	var seen_idx: Dictionary = {}
	for i in list.size():
		var d: Dictionary = list[i]
		var ctx: String = _ctx("floors", i, d)
		var idx: int = int(d["index"])
		if seen_idx.has(idx):
			_err(ctx + ".index", "duplicate floor index %d" % idx)
		seen_idx[idx] = true
		if idx == 1 and not bool(d["playable"]):
			_err(ctx + ".playable", "floor_1 must be playable")
		var lay: Dictionary = d["layout"]
		if not lay.is_empty():
			_check_layout(ctx + ".layout", d, lay)


func _check_layout(ctx: String, floor_d: Dictionary, lay: Dictionary) -> void:
	var idx: int = int(floor_d["index"])
	var w: int = int(floor_d["grid"]["w"])
	var h: int = int(floor_d["grid"]["h"])
	var cells: Dictionary = {}       # Vector2i → cell dict
	var zone_ids: Dictionary = {}
	for z: Dictionary in lay.get("zones", []):
		zone_ids[str(z["id"])] = true
	var starts: Array[Vector2i] = []
	var stairs_cells: int = 0
	var cell_list: Array = lay.get("cells", [])
	for i in cell_list.size():
		var c: Dictionary = cell_list[i]
		var cctx: String = "%s.cells[%d]" % [ctx, i]
		var pos: Vector2i = Vector2i(int(c["x"]), int(c["y"]))
		if pos.x < 0 or pos.y < 0 or pos.x >= w or pos.y >= h:
			_err(cctx, "cell %s outside grid %dx%d" % [str(pos), w, h])
		if cells.has(pos):
			_err(cctx, "duplicate cell %s" % str(pos))
		cells[pos] = c
		if not zone_ids.has(str(c["zone"])):
			_err(cctx + ".zone", "unknown zone '%s'" % str(c["zone"]))
		match str(c["kind"]):
			"start":
				starts.append(pos)
			"stairs":
				stairs_cells += 1
	if starts.size() != 1:
		_err(ctx + ".cells", "needs exactly 1 start cell (got %d)" % starts.size())
	if stairs_cells != 1:
		_err(ctx + ".cells", "needs exactly 1 stairs cell (got %d)" % stairs_cells)
	# Door symmetry.
	for pos: Vector2i in cells.keys():
		var doors: String = str(cells[pos]["doors"])
		for ch: String in doors:
			if not DIR_OFFSETS.has(ch):
				continue
			var n: Vector2i = pos + (DIR_OFFSETS[ch] as Vector2i)
			if not cells.has(n):
				_err(ctx + ".cells", "cell %s has door %s into empty cell %s" % [str(pos), ch, str(n)])
			elif not str(cells[n]["doors"]).contains(str(DIR_OPPOSITE[ch])):
				_err(ctx + ".cells", "door %s of cell %s is not mirrored by cell %s" % [ch, str(pos), str(n)])
	# Reachability (gates count as open).
	if starts.size() == 1:
		var reached: Dictionary = {starts[0]: true}
		var queue: Array[Vector2i] = [starts[0]]
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for ch: String in str(cells[cur]["doors"]):
				if not DIR_OFFSETS.has(ch):
					continue
				var n: Vector2i = cur + (DIR_OFFSETS[ch] as Vector2i)
				if cells.has(n) and not reached.has(n):
					reached[n] = true
					queue.append(n)
		for pos: Vector2i in cells.keys():
			if not reached.has(pos):
				_err(ctx + ".cells", "cell %s is not reachable from start" % str(pos))
	# Stairs.
	var st: Dictionary = lay.get("stairs", {})
	if st.has("cell"):
		var sp: Vector2i = _cell_of(st["cell"])
		if not cells.has(sp):
			_err(ctx + ".stairs.cell", "no cell at %s" % str(sp))
		elif str(cells[sp]["kind"]) != "stairs":
			_err(ctx + ".stairs.cell", "cell %s must have kind stairs" % str(sp))
	# Gates (one gate per door; both sides of a door are the same door).
	var gates: Array = lay.get("gates", [])
	var doors_gated: Dictionary = {}     # door key → gate index
	for i in gates.size():
		var g: Dictionary = gates[i]
		var gp: Vector2i = _cell_of(g["cell"])
		var gctx: String = "%s.gates[%d]" % [ctx, i]
		if not cells.has(gp):
			_err(gctx + ".cell", "no cell at %s" % str(gp))
		elif not str(cells[gp]["doors"]).contains(str(g["dir"])):
			_err(gctx + ".dir", "cell %s has no door %s" % [str(gp), str(g["dir"])])
		var dk: String = door_key(gp, str(g["dir"]))
		if doors_gated.has(dk):
			_err(gctx, "closes the same door as gates[%d] (door %s)" % [int(doors_gated[dk]), dk])
		else:
			doors_gated[dk] = i
	# Placements: cells exist, offsets, runtime id formats, uniqueness.
	var group_re: String = "^f%d_(g[0-9]+|qb|fb)$" % idx
	var chest_re: String = "^f%d_c[0-9]+$" % idx
	var group_ids: Dictionary = {}
	var placed: Array = lay.get("encounters_placed", [])
	for i in placed.size():
		var p: Dictionary = placed[i]
		var pctx: String = "%s.encounters_placed[%d]" % [ctx, i]
		_check_placement(pctx, p, cells)
		var wps: Array = p.get("waypoints", [])
		for j in wps.size():
			var wp: Array = wps[j]
			if absf(float(wp[0])) > MAX_OFFSET or absf(float(wp[1])) > MAX_OFFSET:
				_err("%s.waypoints[%d]" % [pctx, j], "|x|, |z| must be <= %.1f (room-local, got %s)" % [MAX_OFFSET, str(wp)])
		var gid: String = str(p["group_id"])
		if not _matches(group_re, gid):
			_err(pctx + ".group_id", "must match f%d_g<k> / f%d_qb / f%d_fb (got '%s')" % [idx, idx, idx, gid])
		if group_ids.has(gid):
			_err(pctx + ".group_id", "duplicate group id '%s'" % gid)
		group_ids[gid] = true
	_check_boss_placements(ctx, floor_d, placed, cells)
	var chest_ids: Dictionary = {}
	var chests: Array = lay.get("chests", [])
	for i in chests.size():
		var c: Dictionary = chests[i]
		var cctx: String = _ctx(ctx + ".chests", i, c)
		_check_placement(cctx, c, cells)
		var cid: String = str(c["id"])
		if not _matches(chest_re, cid):
			_err(cctx + ".id", "must match f%d_c<k> (got '%s')" % [idx, cid])
		if chest_ids.has(cid):
			_err(cctx + ".id", "duplicate chest id '%s'" % cid)
		chest_ids[cid] = true
	var events: Array = lay.get("events", [])
	for i in events.size():
		_check_placement(_ctx(ctx + ".events", i, events[i]), events[i], cells)
	var srs: Array = lay.get("safe_rooms", [])
	for i in srs.size():
		var s: Dictionary = srs[i]
		var sctx: String = _ctx(ctx + ".safe_rooms", i, s)
		var sp: Vector2i = _cell_of(s["cell"])
		if not cells.has(sp):
			_err(sctx + ".cell", "no cell at %s" % str(sp))
		elif str(cells[sp]["kind"]) != "safe":
			_err(sctx + ".cell", "cell %s must have kind safe" % str(sp))
	# Boss cells ↔ FloorDef boss encounters.
	for key: String in ["quarter_boss", "floor_boss"]:
		var n_cells: int = 0
		for pos: Vector2i in cells.keys():
			if str(cells[pos]["kind"]) == key:
				n_cells += 1
		var has_enc: bool = str(floor_d[key]) != ""
		if has_enc and n_cells != 1:
			_err(ctx + ".cells", "floor has %s but %d cells of kind %s (needs exactly 1)" % [key, n_cells, key])
		if not has_enc and n_cells > 0:
			_err(ctx + ".cells", "cells of kind %s but FloorDef.%s is empty" % [key, key])


## Bosses (§4.4.7): group f<i>_qb / f<i>_fb ⇔ encounter FloorDef.quarter_boss / floor_boss ⇔ cell kind quarter_boss /
## floor_boss; a non-empty quarter_boss / floor_boss needs exactly one such placement (BattleBridge relies on it).
func _check_boss_placements(ctx: String, floor_d: Dictionary, placed: Array, cells: Dictionary) -> void:
	var idx: int = int(floor_d["index"])
	for key: String in ["quarter_boss", "floor_boss"]:
		var suffix: String = "qb" if key == "quarter_boss" else "fb"
		var gid_want: String = "f%d_%s" % [idx, suffix]
		var enc_want: String = str(floor_d[key])
		var count: int = 0
		for i in placed.size():
			var p: Dictionary = placed[i]
			var pctx: String = "%s.encounters_placed[%d]" % [ctx, i]
			var gid: String = str(p["group_id"])
			var enc_id: String = str(p["enc_id"])
			if gid == gid_want:
				count += 1
				if enc_want == "":
					_err(pctx + ".group_id", "group %s but FloorDef.%s is empty" % [gid, key])
				elif enc_id != enc_want:
					_err(pctx + ".enc_id", "group %s must use FloorDef.%s '%s' (got '%s')" % [gid, key, enc_want, enc_id])
				var pos: Vector2i = _cell_of(p["cell"])
				if cells.has(pos) and str(cells[pos]["kind"]) != key:
					_err(pctx + ".cell", "group %s must stand in a cell of kind %s (cell %s is %s)"
						% [gid, key, str(pos), str(cells[pos]["kind"])])
			elif enc_want != "" and enc_id == enc_want:
				_err(pctx + ".group_id", "FloorDef.%s '%s' may only be placed as group %s (got '%s')"
					% [key, enc_want, gid_want, gid])
		if enc_want != "" and count != 1:
			_err(ctx + ".encounters_placed", "FloorDef.%s '%s' needs exactly 1 placement with group %s (got %d)"
				% [key, enc_want, gid_want, count])


func _check_placement(ctx: String, p: Dictionary, cells: Dictionary) -> void:
	var pos: Vector2i = _cell_of(p["cell"])
	if not cells.has(pos):
		_err(ctx + ".cell", "no cell at %s" % str(pos))
	var off: Array = p.get("offset", [0.0, 0.0])
	if absf(float(off[0])) > MAX_OFFSET or absf(float(off[1])) > MAX_OFFSET:
		_err(ctx + ".offset", "|x|, |z| must be <= %.1f (got %s)" % [MAX_OFFSET, str(off)])


static func _cell_of(v: Variant) -> Vector2i:
	return JsonUtil.arr_to_vec2i(v, Vector2i(-999, -999))


## Canonical key of the door between `cell` and its neighbor in `dir` ("x,y,D" of the side that comes first in
## (y, x) order): both sides of one door give the same key.
static func door_key(cell: Vector2i, dir: String) -> String:
	if not DIR_OFFSETS.has(dir):
		return "%d,%d,%s" % [cell.x, cell.y, dir]
	var n: Vector2i = cell + (DIR_OFFSETS[dir] as Vector2i)
	if n.y < cell.y or (n.y == cell.y and n.x < cell.x):
		return "%d,%d,%s" % [n.x, n.y, str(DIR_OPPOSITE[dir])]
	return "%d,%d,%s" % [cell.x, cell.y, dir]


# ======================================================================================================================
# Rule 9: mod lines
# ======================================================================================================================

func _check_mod_line_rules() -> void:
	for tag: String in REQUIRED_MOD_TAGS:
		if not _mod_tags.has(tag):
			_err("mod_lines", "required tag '%s' has no line" % tag)
	for f: Dictionary in _out["floors"]:
		for v: int in (f["timer_warnings"] as PackedInt32Array):
			var tag: String = "timer_warn_%d" % v
			if not _mod_tags.has(tag):
				_err("mod_lines", "tag '%s' (floor_%d timer warning) has no line" % [tag, int(f["index"])])
	var ref_keys: Array = _referenced_tags.keys()
	ref_keys.sort()
	for tag: Variant in ref_keys:
		if not _mod_tags.has(str(tag)):
			_err(str(_referenced_tags[tag]), "referenced tag '%s' has no line in mod_lines" % str(tag))
	var mls: Array = _out["mod_lines"]
	for i in mls.size():
		var ctx: String = _ctx("mod_lines", i, mls[i])
		_check_placeholders(ctx + ".text", str(mls[i]["text"]))
		_check_tag_params(ctx + ".tag", str(mls[i]["tag"]))
	var scs: Array = _out["scenes"]
	for i in scs.size():
		var lines: Array = scs[i]["lines"]
		for j in lines.size():
			_check_placeholders("%s.lines[%d].text" % [_ctx("scenes", i, scs[i]), j], str(lines[j]["text"]))


func _check_placeholders(ctx: String, text: String) -> void:
	for ph: String in placeholders_in(text):
		if not TEXT_PLACEHOLDERS.has(ph):
			_err(ctx, "unknown placeholder {%s}" % ph)
	# Every other brace is malformed ({Name}, "{name", "}"): String.format would leave it visible in the HUD.
	var rest: String = RegEx.create_from_string("\\{[a-z_]+\\}").sub(text, "", true)
	if rest.contains("{") or rest.contains("}"):
		_err(ctx, "malformed placeholder (only {name} tokens with lowercase letters/underscores; no other braces)")


func _check_tag_params(ctx: String, tag: String) -> void:
	var parts: PackedStringArray = tag.split(":")
	match parts[0]:
		"achievement":
			if parts.size() != 2:
				_err(ctx, "expected achievement:<ach_id>")
			else:
				_ref(ctx, parts[1], _achievements, "achievement")
		"boss_intro":
			if parts.size() != 2:
				_err(ctx, "expected boss_intro:<enemy_id>")
			else:
				_ref(ctx, parts[1], _enemies, "enemy")
		"boss_phase":
			if parts.size() != 3 or not parts[2].is_valid_int():
				_err(ctx, "expected boss_phase:<enemy_id>:<n>")
			else:
				_ref(ctx, parts[1], _enemies, "enemy")
		"story_battle":
			# format only: test fixtures replace floor tables (and their encounters); test_m7_text_content checks that
			# every story_battle tag of the real data names an existing encounter
			if parts.size() != 2 or not parts[1].begins_with("enc_"):
				_err(ctx, "expected story_battle:<encounter_id>")
		"sponsor_window_open":
			if parts.size() > 2 or (parts.size() == 2 and not SponsorWindows.KINDS.has(parts[1])):
				_err(ctx, "expected sponsor_window_open[:%s]" % "|".join(SponsorWindows.KINDS))


# ======================================================================================================================
# Rule 10: conditions
# ======================================================================================================================

func _check_conditions() -> void:
	var achs: Array = _out["achievements"]
	for i in achs.size():
		var a: Dictionary = achs[i]
		var allowed: PackedStringArray = payload_keys(str(a["trigger"]))
		_check_condition(_ctx("achievements", i, a) + ".condition", str(a["condition"]), allowed, str(a["trigger"]))
	var scs: Array = _out["scenes"]
	for i in scs.size():
		_check_condition(_ctx("scenes", i, scs[i]) + ".condition", str(scs[i]["condition"]), SCENE_CONTEXT_KEYS,
			"safe room context")


func _check_condition(ctx: String, src: String, e_keys: PackedStringArray, what: String) -> void:
	var ce: ConditionExpr = ConditionExpr.parse(src)
	if ce.error != "":
		_err(ctx, "parse error: " + ce.error)
		return
	for op: Dictionary in ce.operands():
		var key: String = str(op["key"])
		match str(op["scope"]):
			"e":
				if not e_keys.has(key):
					_err(ctx, "unknown key e.%s for %s (%s)" % [key, what, ", ".join(e_keys)])
			"s":
				if not STAT_IDS.has(key):
					_err(ctx, "unknown stat s.%s" % key)


# ======================================================================================================================
# Normalization primitives
# ======================================================================================================================

func _err(ctx: String, msg: String) -> void:
	errors.append("%s: %s" % [ctx, msg])


static func _ctx(prefix: String, i: int, raw: Variant) -> String:
	var id: String = "?"
	if typeof(raw) == TYPE_DICTIONARY and (raw as Dictionary).has("id"):
		id = str((raw as Dictionary)["id"])
	return "%s[%d|%s]" % [prefix, i, id]


func _matches(pattern: String, s: String) -> bool:
	var re: RegEx = _regex.get(pattern, null)
	if re == null:
		re = RegEx.create_from_string(pattern)
		_regex[pattern] = re
	return re.search(s) != null


## Normalizes `raw` against `spec`: unknown keys, required fields, types, ints integral, defaults filled.
## Returns {} if `raw` is not an object.
func _norm(ctx: String, raw: Variant, spec: Array) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		_err(ctx, "expected object")
		return {}
	var d: Dictionary = raw
	var out: Dictionary = {}
	var known: Dictionary = {}
	for f: Array in spec:
		var fname: String = f[0]
		var typ: String = f[1]
		known[fname] = true
		var required: bool = f.size() < 3
		if d.has(fname):
			var conv: Array = _convert(d[fname], typ)
			if bool(conv[0]):
				out[fname] = conv[1]
			else:
				_err(ctx + "." + fname, str(conv[2]))
				out[fname] = _default_value(typ, null if required else f[2])
		else:
			if required:
				_err(ctx + "." + fname, "missing required field")
			out[fname] = _default_value(typ, null if required else f[2])
	for k: Variant in d.keys():
		if not known.has(str(k)):
			_err(ctx + "." + str(k), "unknown key")
	return out


## Returns [ok: bool, value: Variant, reason: String].
func _convert(v: Variant, typ: String) -> Array:
	match typ:
		"s":
			if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
				return [true, str(v), ""]
			return [false, null, "expected string"]
		"i":
			if JsonUtil.is_integral(v):
				return [true, int(v), ""]
			if typeof(v) == TYPE_FLOAT:
				return [false, null, "expected integer (got %s)" % str(v)]
			return [false, null, "expected integer"]
		"f":
			if JsonUtil.is_number(v):
				return [true, float(v), ""]
			return [false, null, "expected number"]
		"b":
			if typeof(v) == TYPE_BOOL:
				return [true, v, ""]
			return [false, null, "expected bool"]
		"d":
			if typeof(v) == TYPE_DICTIONARY:
				return [true, (v as Dictionary).duplicate(true), ""]
			return [false, null, "expected object"]
		"a":
			if typeof(v) == TYPE_ARRAY:
				return [true, (v as Array).duplicate(true), ""]
			return [false, null, "expected array"]
		"sa":
			if typeof(v) != TYPE_ARRAY:
				return [false, null, "expected array of strings"]
			var out: PackedStringArray = []
			for e: Variant in (v as Array):
				if typeof(e) != TYPE_STRING and typeof(e) != TYPE_STRING_NAME:
					return [false, null, "expected array of strings"]
				out.append(str(e))
			return [true, out, ""]
		"ia":
			if typeof(v) != TYPE_ARRAY:
				return [false, null, "expected array of integers"]
			var outi: PackedInt32Array = []
			for e: Variant in (v as Array):
				if not JsonUtil.is_integral(e):
					return [false, null, "expected array of integers"]
				outi.append(int(e))
			return [true, outi, ""]
		"c2":
			if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and JsonUtil.is_integral((v as Array)[0]) \
					and JsonUtil.is_integral((v as Array)[1]):
				return [true, [int((v as Array)[0]), int((v as Array)[1])], ""]
			return [false, null, "expected grid cell [x, y] (integers)"]
		"v2":
			if typeof(v) == TYPE_ARRAY and (v as Array).size() == 2 and JsonUtil.is_number((v as Array)[0]) \
					and JsonUtil.is_number((v as Array)[1]):
				return [true, [float((v as Array)[0]), float((v as Array)[1])], ""]
			return [false, null, "expected [x, z] (numbers)"]
	return [false, null, "unknown type " + typ]


func _default_value(typ: String, dflt: Variant) -> Variant:
	match typ:
		"s":
			return "" if dflt == null else str(dflt)
		"i":
			return 0 if dflt == null else int(dflt)
		"f":
			return 0.0 if dflt == null else float(dflt)
		"b":
			return false if dflt == null else bool(dflt)
		"d":
			return {} if dflt == null else (dflt as Dictionary).duplicate(true)
		"a":
			return [] if dflt == null else (dflt as Array).duplicate(true)
		"sa":
			return PackedStringArray() if dflt == null else PackedStringArray(dflt)
		"ia":
			return PackedInt32Array() if dflt == null else PackedInt32Array(dflt)
		"c2":
			return [0, 0] if dflt == null else (dflt as Array).duplicate()
		"v2":
			return [0.0, 0.0] if dflt == null else [float((dflt as Array)[0]), float((dflt as Array)[1])]
	return null


func _range_i(ctx: String, v: int, lo: int, hi: int) -> void:
	if v < lo or v > hi:
		_err(ctx, "out of range %d..%d (got %d)" % [lo, hi, v])


func _range_f(ctx: String, v: float, lo: float, hi: float) -> void:
	if v < lo or v > hi:
		_err(ctx, "out of range %s..%s (got %s)" % [str(lo), str(hi), str(v)])


func _enum(ctx: String, v: String, vocab: PackedStringArray) -> void:
	if not vocab.has(v):
		_err(ctx, "'%s' not in [%s]" % [v, ", ".join(vocab)])


func _subset(ctx: String, values: PackedStringArray, vocab: PackedStringArray) -> void:
	for v: String in values:
		if not vocab.has(v):
			_err(ctx, "'%s' not in [%s]" % [v, ", ".join(vocab)])


func _hex(ctx: String, v: String) -> void:
	if not is_hex_color(v):
		_err(ctx, "must be a hex color \"#rrggbb\" (got '%s')" % v)


func _text_len(ctx: String, text: String) -> void:
	if text.length() > MAX_TEXT_LEN:
		_err(ctx, "text longer than %d characters (%d)" % [MAX_TEXT_LEN, text.length()])


## Dict<key, number>: keys ⊂ `keys` (empty = any key), values in lo..hi (ints if as_int). require_all: every key
## present.
func _num_dict(ctx: String, raw: Dictionary, keys: PackedStringArray, as_int: bool, lo: float, hi: float,
		require_all: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw.keys():
		var key: String = str(k)
		var v: Variant = raw[k]
		if not keys.is_empty() and not keys.has(key):
			_err(ctx + "." + key, "unknown key (allowed: %s)" % ", ".join(keys))
			continue
		if as_int:
			if not JsonUtil.is_integral(v):
				_err(ctx + "." + key, "expected integer")
				continue
			if float(v) < lo or float(v) > hi:
				_err(ctx + "." + key, "out of range %d..%d (got %s)" % [int(lo), int(hi), str(v)])
			out[key] = int(v)
		else:
			if not JsonUtil.is_number(v):
				_err(ctx + "." + key, "expected number")
				continue
			if float(v) < lo or float(v) > hi:
				_err(ctx + "." + key, "out of range %s..%s (got %s)" % [str(lo), str(hi), str(v)])
			out[key] = float(v)
	if require_all:
		for key: String in keys:
			if not out.has(key) and not raw.has(key):
				_err(ctx + "." + key, "missing required field")
	return out
