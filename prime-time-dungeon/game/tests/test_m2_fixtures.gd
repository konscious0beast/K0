extends TestCase
## M2 test fixture: one self-contained mini data set (GameData.load_from_dicts, 02_TECH §11.2 — M1/M2 unit tests are
## independent of the M7 content) shared by all test_m2_*.gd files via
## `const Fx := preload("res://tests/test_m2_fixtures.gd")`, plus helpers to swap it into DB.data for the Show/Save
## autoload tests. The tests in this file check the fixture itself.

static var _cache: GameData = null


## Valid fixture data (cached; defs are read-only).
static func data() -> GameData:
	if _cache == null:
		_cache = GameData.new()
		_cache.load_from_dicts(tables())
	return _cache


static func _model(base: String) -> Dictionary:
	return {"base": base, "colors": {"primary": "#888888"}}


static func _stats(hp: int, mp: int, st: int, mg: int, df: int, rs: int, sp: int, lk: int) -> Dictionary:
	return {"hp": hp, "mp": mp, "str": st, "mag": mg, "def": df, "res": rs, "spd": sp, "lck": lk}


static func _line(id: String, tag: String, text: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "tag": tag, "text": text}
	d.merge(extra, true)
	return d


static func tables() -> Dictionary:
	return {
		"statuses": [
			{"id": "sts_poison", "name": "Vergiftet", "kind": "debuff", "default_turns": 4, "tick_timing": "turn_start",
				"tick_pct": -8, "tick_min": 1, "element": "poison"},
			{"id": "sts_slow", "name": "Verlangsamt", "kind": "debuff", "tick_speed_mult": 1.5},
			{"id": "sts_guard", "name": "Gepanzert", "kind": "buff", "flags": ["guard"]},
		],
		"skills": [
			{"id": "skl_attack_kai", "name": "Angriff", "user": "party", "category": "attack", "target": "single_enemy",
				"damage_type": "physical", "element": "physical"},
			{"id": "skl_attack_mopsula", "name": "Angriff", "user": "party", "category": "attack",
				"target": "single_enemy", "damage_type": "physical", "element": "physical"},
			{"id": "skl_kai_heavy_swing", "name": "Wuchtschlag", "user": "party", "category": "attack",
				"target": "single_enemy", "damage_type": "physical", "element": "physical", "power": 160, "mp_cost": 3},
			{"id": "skl_kai_finisher", "name": "Finisher", "user": "party", "category": "attack", "target": "single_enemy",
				"damage_type": "physical", "element": "physical", "power": 200, "kill_hype": 10},
			{"id": "skl_mop_flame", "name": "Adelsflamme", "user": "party", "category": "magic", "target": "single_enemy",
				"damage_type": "magical", "element": "fire", "power": 110, "mp_cost": 4},
			{"id": "skl_mop_lick", "name": "Schlabbern", "user": "party", "category": "heal", "target": "single_ally",
				"damage_type": "heal", "heal_mode": "mag", "mp_cost": 4},
			{"id": "skl_mop_frost", "name": "Frostniesen", "user": "party", "category": "magic", "target": "single_enemy",
				"damage_type": "magical", "element": "ice", "mp_cost": 5},
			{"id": "skl_mop_thunder", "name": "Donnerbellen", "user": "party", "category": "magic",
				"target": "all_enemies", "damage_type": "magical", "element": "shock", "mp_cost": 8},
			{"id": "skl_stunt_kai_suplex", "name": "Suplex", "user": "party", "category": "stunt", "target": "single_enemy",
				"damage_type": "physical", "element": "physical", "power": 230, "success_base": 0.6, "cooldown": 3},
			{"id": "skl_e_bite", "name": "Biss", "user": "enemy", "category": "attack", "target": "single_enemy",
				"damage_type": "physical", "element": "physical"},
			{"id": "skl_item_bandage", "name": "Pflaster", "user": "item", "category": "item", "target": "single_ally",
				"damage_type": "heal", "heal_mode": "fixed", "power": 45},
			{"id": "skl_item_salts", "name": "Riechsalz", "user": "item", "category": "item", "target": "single_ally_ko",
				"damage_type": "heal", "heal_mode": "pct", "power": 30},
			{"id": "skl_item_megaphone", "name": "Megafon", "user": "item", "category": "item", "target": "self",
				"hype": 25},
			{"id": "skl_item_ether", "name": "Energie", "user": "item", "category": "item", "target": "single_ally",
				"mp_restore": 10, "mp_restore_pct": 10},
			{"id": "skl_item_antidote", "name": "Gegengift", "user": "item", "category": "item", "target": "single_ally",
				"cleanse": ["sts_poison"]},
			{"id": "skl_item_molotov", "name": "Molotow", "user": "item", "category": "item", "target": "all_enemies",
				"damage_type": "fixed", "element": "fire", "power": 30},
			{"id": "skl_item_group_heal", "name": "Gruppenheilung", "user": "item", "category": "item",
				"target": "all_allies", "damage_type": "heal", "heal_mode": "pct", "power": 20},
		],
		"items": [
			{"id": "itm_bandage", "name": "Werbepflaster", "type": "consumable", "price": 25, "tags": ["heal"],
				"use_skill": "skl_item_bandage", "usable": "both"},
			{"id": "itm_salts", "name": "Riechsalz", "type": "consumable", "rarity": "rare", "price": 60,
				"tags": ["revive"], "use_skill": "skl_item_salts", "usable": "both"},
			{"id": "itm_megaphone", "name": "Hype-Megafon", "type": "consumable", "rarity": "rare", "price": 120,
				"tags": ["show"], "use_skill": "skl_item_megaphone", "usable": "battle"},
			{"id": "itm_ether", "name": "Energie", "type": "consumable", "price": 30, "tags": ["mp"],
				"use_skill": "skl_item_ether", "usable": "field"},
			{"id": "itm_antidote", "name": "Gegengift", "type": "consumable", "price": 20, "tags": ["cure"],
				"use_skill": "skl_item_antidote", "usable": "both"},
			{"id": "itm_molotov", "name": "Molotow", "type": "consumable", "price": 40, "tags": ["damage"],
				"use_skill": "skl_item_molotov", "usable": "battle"},
			{"id": "itm_group_heal", "name": "Gruppenpflaster", "type": "consumable", "price": 0, "sell": 0,
				"tags": ["heal"], "use_skill": "skl_item_group_heal", "usable": "both"},
			{"id": "itm_stack3", "name": "Kleiner Stapel", "type": "consumable", "price": 10, "max_stack": 3,
				"use_skill": "skl_item_bandage", "usable": "both"},
			{"id": "itm_wpn_mop", "name": "Wischmopp", "type": "weapon", "sell": 10, "equip_by": ["kai"],
				"stats": {"str": 3}},
			{"id": "itm_wpn_axe", "name": "Feuerwehraxt", "type": "weapon", "rarity": "rare", "price": 480,
				"equip_by": ["kai"], "stats": {"str": 12}, "crit_bonus": 0.05, "attack_element": "fire"},
			{"id": "itm_wpn_collar", "name": "Lederhalsband", "type": "weapon", "sell": 8, "equip_by": ["mopsula"],
				"stats": {"mag": 2}},
			{"id": "itm_arm_hoodie", "name": "Hoodie", "type": "armor", "sell": 15, "stats": {"def": 2, "hp": 10}},
			{"id": "itm_arm_vest", "name": "Warnweste", "type": "armor", "rarity": "rare", "price": 300,
				"stats": {"def": 5, "hp": 20}, "element_mods": {"poison": 0.5}},
			{"id": "itm_acc_scarf", "name": "Fanschal", "type": "accessory", "rarity": "epic", "sell": 150,
				"show_mods": {"hype_gain_mult": 1.2}},
			{"id": "itm_acc_mic", "name": "Ansteckmikro", "type": "accessory", "rarity": "epic", "sell": 150,
				"show_mods": {"follower_mult": 1.15}},
			{"id": "itm_acc_mask", "name": "Gasmaske", "type": "accessory", "rarity": "epic", "price": 300,
				"crit_bonus": 0.05, "element_mods": {"poison": 0.0}, "status_immune": ["sts_poison"]},
			{"id": "itm_key_master", "name": "Generalschlüssel", "type": "key", "sell": 0, "max_stack": 1},
		],
		"classes": [
			{"id": "cls_kai_test", "name": "Testklasse", "for": ["kai"], "min_floor": 1,
				"stat_mult": {"hp": 1.1, "str": 1.15}, "growth_add": {"hp": 3.0},
				"learnset": [{"level": 2, "skill": "skl_kai_finisher"}]},
		],
		"party_start": {"inventory": {"itm_bandage": 3, "itm_antidote": 1}, "credits": 50},
		"party": [
			{"id": "kai", "name": "Kai", "battle_slot": 0, "base_stats": _stats(64, 12, 12, 5, 9, 6, 11, 8),
				"growth": {"hp": 9.0, "mp": 2.0, "str": 2.0, "mag": 0.6, "def": 1.5, "res": 0.8, "spd": 0.5, "lck": 0.5},
				"attack_skill": "skl_attack_kai",
				"learnset": [{"level": 1, "skill": "skl_kai_heavy_swing"}, {"level": 3, "skill": "skl_kai_finisher"}],
				"stunts": ["skl_stunt_kai_suplex"],
				"equipment": {"weapon": "itm_wpn_mop", "armor": "itm_arm_hoodie", "accessory": ""},
				"model": _model("humanoid")},
			{"id": "mopsula", "name": "Mopsula", "title": "Graf", "battle_slot": 1,
				"base_stats": _stats(42, 30, 5, 13, 6, 11, 14, 12),
				"growth": {"hp": 6.0, "mp": 4.0, "str": 0.6, "mag": 2.2, "def": 0.8, "res": 1.6, "spd": 0.6, "lck": 0.7},
				"attack_skill": "skl_attack_mopsula",
				"learnset": [{"level": 1, "skill": "skl_mop_flame"}, {"level": 1, "skill": "skl_mop_lick"},
					{"level": 2, "skill": "skl_mop_frost"}, {"level": 3, "skill": "skl_mop_thunder"}],
				"equipment": {"weapon": "itm_wpn_collar", "armor": "", "accessory": ""},
				"element_mods": {"ice": 0.5}, "status_resist": {"sts_poison": 0.25},
				"model": _model("pug")},
		],
		"enemies": [
			{"id": "enm_rat", "name": "Kanalratte", "stats": _stats(24, 0, 13, 3, 5, 3, 13, 5), "exp": 12, "credits": 6,
				"attack_skill": "skl_e_bite", "drops": [{"item": "itm_bandage", "chance": 0.25}],
				"model": _model("rodent"), "explore": {"field_speed": 4.8}},
			{"id": "enm_boss", "name": "Der Hausmeister", "level": 6, "boss": true,
				"stats": _stats(380, 60, 23, 14, 14, 10, 12, 6), "exp": 180, "credits": 200, "attack_skill": "skl_e_bite",
				"boss_drops": [{"kind": "item", "id": "itm_key_master", "amount": 1},
					{"kind": "box", "id": "box_silver", "amount": 1}],
				"model": _model("brute"), "explore": {"field_speed": 0.0}},
		],
		"floors": [
			{"id": "floor_1", "index": 1, "name": "Etage 1", "theme": "metro", "timer_seconds": 1200,
				"timer_start_after": "enc_f1_tutorial", "floor_mult": 1.0, "grid": {"w": 8, "h": 8},
				"quarter_boss": "enc_f1_qb",
				"encounters": [
					{"id": "enc_f1_tutorial", "enemies": ["enm_rat", "enm_rat"], "weight": 0, "tutorial": true},
					{"id": "enc_f1_a", "enemies": ["enm_rat"], "weight": 0},
					{"id": "enc_f1_qb", "enemies": ["enm_boss"], "weight": 0, "boss": true},
				],
				"layout": {
					"zones": [{"id": "zone_platform", "name": "Bahnsteig"}],
					"cells": [{"x": 3, "y": 7, "zone": "zone_platform", "kind": "start", "doors": "N"},
						{"x": 3, "y": 6, "zone": "zone_platform", "kind": "normal", "doors": "NESW"},
						{"x": 2, "y": 6, "zone": "zone_platform", "kind": "safe", "doors": "E"},
						{"x": 4, "y": 6, "zone": "zone_platform", "kind": "quarter_boss", "doors": "W"},
						{"x": 3, "y": 5, "zone": "zone_platform", "kind": "stairs", "doors": "S"}],
					"encounters_placed": [
						{"group_id": "f1_g0", "enc_id": "enc_f1_tutorial", "cell": [3, 6], "state": "IDLE", "turn": false},
						{"group_id": "f1_qb", "enc_id": "enc_f1_qb", "cell": [4, 6]}],
					"chests": [{"id": "f1_c0", "cell": [3, 6], "offset": [3.5, 2.0], "type": "wood"},
						{"id": "f1_c1", "cell": [3, 6], "offset": [-3.5, 2.0], "type": "metal",
							"contents": [{"kind": "item", "id": "itm_arm_vest", "amount": 1},
								{"kind": "credits", "amount": 15}]}],
					"safe_rooms": [{"id": "sr_kiosk", "cell": [2, 6], "name": "Kiosk", "theme": "kiosk",
						"shop": ["itm_bandage", "itm_salts"]}],
					"stairs": {"cell": [3, 5]},
				}},
			{"id": "floor_2", "index": 2, "name": "Etage 2", "theme": "mall", "timer_seconds": 900, "floor_mult": 1.5,
				"grid": {"w": 6, "h": 6}, "rooms": {"min": 6, "max": 8}, "safe_rooms": 1, "chests": {"min": 1, "max": 2},
				"enemy_groups": {"min": 1, "max": 2},
				"chest_table": [{"kind": "item", "id": "itm_bandage", "weight": 3, "min": 1, "max": 2},
					{"kind": "credits", "weight": 1, "min": 30, "max": 60}],
				"shop": ["itm_bandage", "itm_ether"],
				"encounters": [{"id": "enc_f2_a", "enemies": ["enm_rat"]}]},
		],
		"lootboxes": [
			{"id": "box_bronze", "name": "Bronze", "tier": 1, "color": "#cd7f32", "rolls": 2,
				"rarity_weights": {"common": 80, "rare": 18, "epic": 2}},
			{"id": "box_silver", "name": "Silber", "tier": 2, "color": "#c0c8d2", "rolls": 3,
				"rarity_weights": {"common": 55, "rare": 38, "epic": 7}, "guarantee": "rare"},
			{"id": "box_gold", "name": "Gold", "tier": 3, "color": "#ffc83d", "rolls": 4,
				"rarity_weights": {"common": 25, "rare": 55, "epic": 20}, "guarantee": "epic"},
			{"id": "box_fan", "name": "Fan", "tier": 4, "color": "#ff5fa2", "rolls": 2,
				"rarity_weights": {"common": 50, "rare": 40, "epic": 10}, "fixed_pool": "fan"},
			{"id": "box_common1", "name": "Nur Common", "tier": 1, "color": "#888888", "rolls": 1,
				"rarity_weights": {"common": 1, "rare": 0, "epic": 0}},
			{"id": "box_common2", "name": "Zwei Common", "tier": 1, "color": "#888888", "rolls": 2,
				"rarity_weights": {"common": 1, "rare": 0, "epic": 0}},
			{"id": "box_epic1", "name": "Nur Episch", "tier": 1, "color": "#888888", "rolls": 1,
				"rarity_weights": {"common": 0, "rare": 0, "epic": 1}},
			{"id": "box_guar_rare", "name": "Garantie selten", "tier": 2, "color": "#888888", "rolls": 3,
				"rarity_weights": {"common": 1, "rare": 0, "epic": 0}, "guarantee": "rare"},
			{"id": "box_guar_epic", "name": "Garantie episch", "tier": 3, "color": "#888888", "rolls": 2,
				"rarity_weights": {"common": 1, "rare": 0, "epic": 0}, "guarantee": "epic"},
		],
		"lootbox_pools": {
			"f1": {
				"common": [{"kind": "credits", "id": "", "amount": 25, "weight": 30},
					{"kind": "item", "id": "itm_bandage", "amount": 2, "weight": 25}],
				"rare": [{"kind": "item", "id": "itm_salts", "amount": 1, "weight": 20},
					{"kind": "credits", "id": "", "amount": 120, "weight": 10}],
				"epic": [{"kind": "item", "id": "itm_acc_mask", "amount": 1, "weight": 10},
					{"kind": "credits", "id": "", "amount": 400, "weight": 10}],
				"fan": [{"kind": "item", "id": "itm_acc_mic", "amount": 1, "weight": 40}],
			},
			"f2": {"common": [{"kind": "credits", "id": "", "amount": 50, "weight": 1}]},
			"f3": {"common": [{"kind": "item", "id": "itm_wpn_axe", "amount": 1, "weight": 1}],
				"epic": [{"kind": "item", "id": "itm_wpn_axe", "amount": 1, "weight": 1}],
				"fan": [{"kind": "item", "id": "itm_acc_mic", "amount": 1, "weight": 1}]},
		},
		"lootbox_pity": {"rare": 4, "epic": 8},
		"achievements": [
			{"id": "ach_first_blood", "name": "Erster Kill", "desc": "d", "trigger": "enemy_killed",
				"condition": "s.kills_total == 1", "box": "box_bronze"},
			{"id": "ach_overkill", "name": "Overkill", "desc": "d", "trigger": "enemy_killed",
				"condition": "e.overkill == true", "box": "box_bronze"},
			{"id": "ach_boss_kill", "name": "Boss erlegt", "desc": "d", "trigger": "enemy_killed",
				"condition": "e.enemy_id == \"enm_boss\" && e.by == \"stunt\""},
			{"id": "ach_first_win", "name": "Erster Sieg", "desc": "d", "trigger": "battle_won",
				"condition": "s.battles_won == 1", "box": "box_bronze"},
			{"id": "ach_one_hp", "name": "Haaresbreite", "desc": "d", "trigger": "battle_won",
				"condition": "e.min_party_hp == 1", "box": "box_silver", "hidden": true},
			{"id": "ach_ambush_won", "name": "Rückenwind", "desc": "d", "trigger": "battle_won",
				"condition": "e.encounter_type == \"ambush\"", "box": "box_bronze", "followers": 7},
			{"id": "ach_titled_win", "name": "Mit Titel", "desc": "d", "trigger": "battle_won",
				"condition": "f.title_ms_5000 == true && e.items_used == 0"},
			{"id": "ach_flee_first", "name": "Rückzug", "desc": "d", "trigger": "battle_fled",
				"condition": "s.battles_fled == 1", "box": "box_bronze"},
			{"id": "ach_preemptive_2", "name": "Leise Sohle", "desc": "d", "trigger": "battle_started",
				"condition": "e.encounter_type == \"preemptive\" && s.preemptives == 2", "box": "box_bronze"},
			{"id": "ach_stunt_first", "name": "Showtalent", "desc": "d", "trigger": "stunt_resolved",
				"condition": "e.success == true && s.stunts_success == 1", "box": "box_bronze"},
			{"id": "ach_combo", "name": "Team", "desc": "d", "trigger": "combo", "condition": "e.member == \"mopsula\"",
				"box": "box_bronze"},
			{"id": "ach_mopsula_ko", "name": "Der Graf fiel", "desc": "d", "trigger": "party_ko",
				"condition": "e.member == \"mopsula\" && s.ko_mopsula == 1", "box": "box_bronze"},
			{"id": "ach_boss", "name": "Feierabend", "desc": "d", "trigger": "boss_defeated",
				"condition": "e.boss_id == \"enm_boss\"", "box": "box_gold"},
			{"id": "ach_sponsor_first", "name": "Gesponsert", "desc": "d", "trigger": "sponsor_gift",
				"condition": "s.sponsor_gifts == 1", "box": "box_bronze"},
			{"id": "ach_viewers_3000", "name": "Quotenhit", "desc": "d", "trigger": "viewers_changed",
				"condition": "e.viewers >= 3000", "box": "box_silver"},
			{"id": "ach_chest_metal", "name": "Spind", "desc": "d", "trigger": "chest_opened",
				"condition": "e.type == \"metal\"", "box": "box_bronze"},
			{"id": "ach_vendor_100", "name": "Kaufrausch", "desc": "d", "trigger": "item_bought",
				"condition": "s.credits_spent_vendor >= 100", "box": "box_bronze"},
			{"id": "ach_lootbox_2", "name": "Gacha", "desc": "d", "trigger": "lootbox_opened",
				"condition": "s.lootboxes_opened == 2", "box": "box_bronze"},
			{"id": "ach_level_3", "name": "Aufsteiger", "desc": "d", "trigger": "level_up",
				"condition": "e.member == \"kai\" && e.level == 3", "box": "box_bronze"},
			{"id": "ach_events_2", "name": "Neugierig", "desc": "d", "trigger": "event_completed",
				"condition": "s.events_completed == 2", "box": "box_silver"},
			{"id": "ach_pacifist", "name": "Pazifist", "desc": "d", "trigger": "explore_tick",
				"condition": "s.explore_seconds_since_battle >= 300", "box": "box_bronze"},
			{"id": "ach_speedrun", "name": "Expresszug", "desc": "d", "trigger": "floor_completed",
				"condition": "e.floor == 1 && e.timer_left >= 480", "box": "box_gold"},
			{"id": "ach_bets_5", "name": "M.O.D.s Liebling", "desc": "d", "trigger": "show_bet",
				"condition": "e.kind == \"marotte\" && e.event == \"won\" && s.bets_won == 5", "box": "box_silver"},
		],
		"sponsors": [
			{"id": "spn_heal", "name": "Glückwasser", "color": "#4ad9d9", "gift": [{"kind": "heal_party_pct", "value": 35}],
				"weight": 3, "weight_mods": [{"cond": "ally_hp_below", "value": 0.5, "mult": 3.0}]},
			{"id": "spn_mana", "name": "NovaNet", "color": "#3a6cff", "gift": [{"kind": "mp_party_pct", "value": 40}],
				"weight": 2, "weight_mods": [{"cond": "ally_mp_below", "value": 0.3, "mult": 2.0}]},
			{"id": "spn_revive", "name": "Sorgenfrei", "color": "#ffffff",
				"gift": [{"kind": "revive_or_heal_lowest", "value": 50}], "weight": 1,
				"weight_mods": [{"cond": "ally_ko", "mult": 6.0}]},
			{"id": "spn_slow", "name": "DoomScroll+", "color": "#7a5cff",
				"gift": [{"kind": "status_enemies", "status": "sts_slow", "turns": 3, "target": "enemies",
					"ignore_resist": true}], "weight": 2, "weight_mods": [{"cond": "is_boss", "mult": 2.0}]},
			{"id": "spn_late", "name": "Spätsponsor", "color": "#ff8a3d", "gift": [{"kind": "heal_party_flat", "value": 20}],
				"weight": 5, "min_floor": 2},
		],
		"milestones": [
			{"id": "ms_100", "followers": 100, "reward_box": "box_bronze"},
			{"id": "ms_250", "followers": 250, "reward_box": "box_fan"},
			{"id": "ms_500", "followers": 500, "reward_box": "box_silver", "credits": 300},
			{"id": "ms_1000", "followers": 1000, "reward_box": "box_fan", "item": "itm_acc_scarf"},
			{"id": "ms_5000", "followers": 5000, "reward_box": "box_gold", "title": "Quotenkönig:in", "min_floor": 2},
		],
		"mod_lines": [
			_line("mod_floor_start_01", "floor_start", "Etage {floor}! Los, {name}.", {"max_floor": 1}),
			_line("mod_floor_start_02", "floor_start", "Neue Etage {floor}, neues Glück.", {"min_floor": 2}),
			_line("mod_first_fight_01", "first_fight", "Ihr erster Kampf!"),
			_line("mod_ach_generic_01", "achievement_generic", "Achievement: {achievement}!"),
			_line("mod_ach_first_blood_01", "achievement:ach_first_blood", "Erster Kill! Die Werbekunden atmen auf."),
			_line("mod_crit_01", "crit", "KRITISCH!"),
			_line("mod_crit_02", "crit", "Volltreffer! Zeitlupe, bitte."),
			_line("mod_kill_streak_01", "kill_streak", "Kill-Serie! Jemand bringe {name} einen Vertrag."),
			_line("mod_overkill_01", "overkill", "Overkill!"),
			_line("mod_low_hp_hi", "low_hp", "Drama bei hoher Quote!", {"min_hype": 50}),
			_line("mod_low_hp_lo", "low_hp", "Ihre HP sind niedrig!", {"max_hype": 49}),
			_line("mod_stunt_success_01", "stunt_success", "WAS FÜR EIN STUNT!"),
			_line("mod_stunt_fail_01", "stunt_fail", "Autsch."),
			_line("mod_boring_01", "boring_fight", "Gähn."),
			_line("mod_boss_intro_01", "boss_intro:enm_boss", "Applaus für den Hausmeister!"),
			_line("mod_boss_defeated_01", "boss_defeated", "Boss besiegt!"),
			_line("mod_sponsor_01", "sponsor_gift", "Präsentiert von {sponsor}!"),
			_line("mod_gift_received_01", "gift_received", "Ein Geschenk aus dem Publikum!"),
			_line("mod_milestone_01", "follower_milestone", "{followers} Follower!"),
			_line("mod_timer_300_01", "timer_warn_300", "Noch fünf Minuten!"),
			_line("mod_timer_60_01", "timer_warn_60", "EINE MINUTE!"),
			_line("mod_timer_600_01", "timer_warn_600", "noch 10 min??", {"voice": "chat"}),
			_line("mod_timer_expired_01", "timer_expired", "Sendeschluss."),
			_line("mod_death_01", "death", "Sendeschluss, {name}."),
			_line("mod_intro_01", "intro", "Guten Abend, Galaxis!"),
			_line("mod_vendor_01", "vendor_buy", "{item}! Exzellente Wahl."),
			_line("mod_level_up_01", "level_up", "Level {level}!"),
			_line("mod_floor_end_01", "floor_end", "Etage geschafft!"),
			_line("mod_stairs_01", "stairs_found", "Die Treppe!"),
			_line("mod_handle_01", "chat_handle", "OmaHilde1953", {"voice": "chat"}),
			_line("mod_chat_mid_01", "chat_hype_mid", "solide runde", {"voice": "chat"}),
			_line("mod_chat_mid_02", "chat_hype_mid", "wer hat hunger", {"voice": "chat"}),
			_line("mod_chat_crit_01", "chat_crit", "KRIT!!", {"voice": "chat", "user": "u_bahn_ultra"}),
		],
	}


# --- autoload helpers (Show/Save tests) -------------------------------------------------------------------------------

## Swaps the fixture into DB.data and starts a fresh game on floor 1 (Game.new_game). Returns the previous data.
static func begin_world(seed: int = 77, slot: int = 0) -> GameData:
	var db: Node = Engine.get_main_loop().root.get_node("DB")
	var prev: GameData = db.get("data")
	db.set("data", data())
	var game: Node = Engine.get_main_loop().root.get_node("Game")
	game.call("new_game", slot, "Kai", seed)
	return prev


## Restores DB.data and resets Game/Show to "no game" (tests must not leak state into later test files).
static func end_world(prev: GameData) -> void:
	var root: Window = Engine.get_main_loop().root
	var game: Node = root.get_node("Game")
	var show: Node = root.get_node("Show")
	if game.get("state") != null:
		show.call("end_battle", null)
	game.set("in_battle", false)
	game.set("timer_running", false)
	game.set("replaying", false)
	game.set("state", null)
	game.set("run_log", null)
	game.set("sim", null)
	game.set("quest", null)
	game.set("mode", &"campaign")
	game.call("clear_blocking_dialogs")
	if prev != null:
		root.get_node("DB").set("data", prev)


# --- tests of the fixture ---------------------------------------------------------------------------------------------

func test_fixture_is_valid() -> void:
	var d: GameData = fixture_data(tables())
	assert_true(d.is_valid(), "; ".join(d.errors))
	assert_len(d.all_party(), 2)
	assert_eq(d.party_member("kai").battle_slot, 0)
	assert_eq(d.all_milestones()[0].id, "ms_100", "milestones sorted by followers")
	assert_eq(d.loot_pool(2, "rare"), [], "floor 2 has no rare pool")


func test_fixture_covers_every_achievement_trigger() -> void:
	var seen: PackedStringArray = []
	for a: AchievementDef in data().all_achievements():
		if not seen.has(a.trigger):
			seen.append(a.trigger)
	for t: String in DataValidator.ACH_TRIGGERS:
		assert_has(seen, t, "fixture achievement for trigger " + t)
