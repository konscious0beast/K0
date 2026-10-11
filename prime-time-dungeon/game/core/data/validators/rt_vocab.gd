class_name RtVocab extends RefCounted
## All real-time combat vocabularies (07 §4.10) and the symbol ids of the action bar / status symbols (07 §8.2, §8.4)
## as constants — the one source for validators/rt.gd (R4), RtCommand / RtMods (R1b) and the HUD (R3). Complete since
## R1a (07 §12.2); a new word needs a contract change (07 §12.2 "Änderungsantrag"). Pure constants, no logic.

## Rule targets (07 §5.3 "Ziele").
const RT_TARGETS: PackedStringArray = ["threat_top", "current", "assist", "self", "random_enemy", "nearest_enemy",
	"farthest_enemy", "lowest_hp_pct_enemy", "lowest_hp_pct_ally", "ko_ally", "controlled", "caster", "none"]
## Rule conditions (07 §5.3 "Bedingungen") → value type: "i" int, "b" bool, "s" String, "d" object (fields below).
const RT_CONDITION_TYPES: Dictionary = {
	"self_hp_below_pm": "i", "self_hp_above_pm": "i", "ally_hp_below_pm": "i", "allies_below_pm": "d",
	"ally_ko": "b", "target_hp_above_pm": "i", "target_hp_below_pm": "i", "target_no_status": "s",
	"self_no_status": "s", "self_mp_min": "i", "self_mp_above_pm": "i", "enemies_in_radius": "d",
	"enemy_on_ally": "b", "caster_within_cm": "i", "target_casting": "b", "adds_below": "i", "phase": "i",
	"after_ms": "i", "boss_fight": "b", "toggle": "s",
}
const RT_CONDITIONS: PackedStringArray = ["self_hp_below_pm", "self_hp_above_pm", "ally_hp_below_pm",
	"allies_below_pm", "ally_ko", "target_hp_above_pm", "target_hp_below_pm", "target_no_status", "self_no_status",
	"self_mp_min", "self_mp_above_pm", "enemies_in_radius", "enemy_on_ally", "caster_within_cm", "target_casting",
	"adds_below", "phase", "after_ms", "boss_fight", "toggle"]
## Fields of the object-valued conditions.
const RT_CONDITION_FIELDS: Dictionary = {"allies_below_pm": ["pm", "min"], "enemies_in_radius": ["r_cm", "min"]}
## Rule keys (07 §4.9, §5.3): RtRule {"skill" | "item", "target", "cond", "first_ms", "every_ms", "once", "filler",
## "then": {"skill", "delay_ms"}}.
const RT_RULE_KEYS: PackedStringArray = ["skill", "item", "target", "cond", "first_ms", "every_ms", "once", "filler",
	"then"]
## Boss phase ops (07 §4.9).
const RT_PHASE_OPS: PackedStringArray = ["say", "status_self", "summon", "fixed_damage_self", "set", "clear_zones",
	"telegraph"]
const TELEGRAPH_SHAPES: PackedStringArray = ["circle", "cone", "ring", "line"]
const TELEGRAPH_ANCHORS: PackedStringArray = ["self", "target_pos", "each_enemy", "random", "lane"]
const AOE_CENTERS: PackedStringArray = ["self", "target"]
const STATUS_TO: PackedStringArray = ["target", "self", "all_enemies", "all_allies"]
const STACK_MODES: PackedStringArray = ["replace", "refresh", "ignore"]
## Real-time status flags (07 §4.7); the CTB DataValidator.STATUS_FLAGS stay valid as well (guard).
const RT_STATUS_FLAGS: PackedStringArray = ["no_act", "no_move", "no_cast", "fixate", "interrupt_on_apply", "hidden"]
const RT_PRESETS: PackedStringArray = ["attack", "support", "careful"]
const RT_TOGGLES: PackedStringArray = ["interrupt", "show", "potions"]
## Defaults of the partner switches (07 §5.2).
const RT_TOGGLE_DEFAULTS: Dictionary = {"interrupt": true, "show": true, "potions": false}
const MP_REGEN_MODES: PackedStringArray = ["hit", "time"]
## Item kinds of party item rules / the potion key (07 §3.11, §5.3).
const RT_ITEM_KINDS: PackedStringArray = ["heal", "revive", "mp", "cure"]
const SUMMON_AT: PackedStringArray = ["door", "near"]
## Tutorial steps (07 §2.13, encounters[].rt.tutorial) and first-time hint cards (07 §2.13, combat_hint ids).
const TUTORIAL_STEPS: PackedStringArray = ["target", "bar1", "show", "dodge"]
const HINT_IDS: PackedStringArray = ["interrupt", "zone", "partner_special", "finale", "flee", "enrage",
	"partner_tactic"]
## Static modifiers (07 §9.5): ops, unit selectors, sources, the fields of the ops.
const MOD_OPS: PackedStringArray = ["stat_pm", "skill_pm", "move_pm", "swing_pm", "threat_pm", "dmg_dealt_pm",
	"dmg_taken_pm", "heal_taken_pm", "first_hit_taken_pm", "on", "add_rule", "element_swap", "extra_enemy",
	"forbid_skill", "forbid_items", "unlock_variant"]
const MOD_UNITS: PackedStringArray = ["p0", "party", "enemies", "boss", "all"]
const MOD_SOURCES: PackedStringArray = ["species", "spec", "equip", "showboss", "twist"]
const MOD_STATS: PackedStringArray = ["str", "mag", "def", "res", "spd", "lck", "max_hp", "max_mp"]
const MOD_SKILL_FIELDS: PackedStringArray = ["power", "cooldown", "cast", "mp"]
const MOD_EVENTS: PackedStringArray = ["combat_start", "kill", "interrupt", "dodge", "crit", "ko_ally",
	"show_success"]
const MOD_EFFECTS: PackedStringArray = ["heal_pct", "mp", "status"]
## Auto-attack targets of enemies (07 §4.9 "auto_target" ⊆ RT_TARGETS; listed for the validator).
const AUTO_TARGETS: PackedStringArray = ["threat_top", "lowest_hp_pct_enemy", "nearest_enemy", "random_enemy"]
## Real-time command types (07 §10.1) — mirrored by RtCommand.TYPES.
const COMMAND_TYPES: PackedStringArray = ["ability_use", "target_change", "move_sample", "combat_item",
	"partner_preset", "partner_special", "auto_attack", "autopilot", "combat_hint", "move_input", "combat_speed",
	"move_batch"]
## Allowed combat speeds in per mille (07 §10.7 O1).
const COMBAT_SPEEDS: PackedInt32Array = [1000, 850, 700]
## Symbol ids of the action bar, the partner button and the status symbols (07 §4.6 "icon", §8.2, §8.4). R3 draws
## every id; data reference them through skills/statuses `rt.icon`. Names follow the "Symbol-Idee" of 07 §4.2/§4.3,
## never a skill id (skills may be renamed).
const ICON_IDS: PackedStringArray = [
	# Kai (07 §4.2)
	"mop_swing", "megaphone_notes", "paw_plaster", "leash_lasso", "cable_sparks", "mop_circle", "spray_flame",
	"wrestler_stars", "studio_camera",
	# Graf Mopsula (07 §4.3; no crown motif, 06 §3.2)
	"monocle_beam", "seal_flame", "tongue_glitter", "drool_halo", "two_tongues", "pug_nose_ice", "scroll_seal",
	"bark_bolt", "cape_spotlight", "monocle_flames",
	# potion key + consumables (07 §4.5)
	"potion", "bandage", "burger", "antidote", "can", "salts", "molotov", "ice_spray", "smoke", "megaphone", "elixir",
	# status symbols (07 §8.4)
	"poison", "stun", "slow", "haste", "guard", "taunted", "dazed", "regen", "burn", "admonished", "dizzy", "enrage",
	# enemies / generic
	"claw", "bite", "bolt", "fire", "ice", "toxic", "train", "whistle", "ticket", "generic",
]
