extends TestCase
## M1 test fixture: mini data set independent of res://data (02_TECH §11.2) + static helpers shared by the
## test_m1_*.gd files (used via `const Fx := preload("res://tests/test_m1_fixture.gd")`). Contains the fixture
## self-test.

const ALL_STATS: PackedStringArray = ["hp", "mp", "str", "mag", "def", "res", "spd", "lck"]


static func _stats(hp: int, mp: int, s: int, m: int, d: int, r: int, spd: int, lck: int) -> Dictionary:
	return {"hp": hp, "mp": mp, "str": s, "mag": m, "def": d, "res": r, "spd": spd, "lck": lck}


static func _model(base: String) -> Dictionary:
	return {"base": base, "colors": {"primary": "#808080"}}


static func _skill(id: String, user: String, category: String, target: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "name": id.trim_prefix("skl_"), "user": user, "category": category, "target": target}
	d.merge(extra, true)
	return d


static func _enemy(id: String, stats: Dictionary, actions: Array, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"id": id, "name": id.trim_prefix("enm_"), "stats": stats, "attack_skill": "skl_e_strike",
		"ai": {"type": "weighted", "actions": actions}, "model": _model("rodent"), "explore": {"field_speed": 4.0}}
	d.merge(extra, true)
	return d


static func _item(id: String, use_skill: String, usable: String = "both") -> Dictionary:
	return {"id": id, "name": id.trim_prefix("itm_"), "type": "consumable", "use_skill": use_skill, "usable": usable,
		"price": 10}


## Tables for GameData.load_from_dicts (02_TECH §4.5).
static func tables() -> Dictionary:
	var phys: Dictionary = {"damage_type": "physical", "element": "physical"}
	var statuses: Array = [
		{"id": "sts_poison", "name": "Vergiftet", "kind": "debuff", "default_turns": 4, "tick_timing": "turn_start",
			"tick_pct": -8, "tick_min": 1, "element": "poison"},
		{"id": "sts_stun", "name": "Betäubt", "kind": "debuff", "default_turns": 1, "flags": ["delay_on_apply"]},
		{"id": "sts_slow", "name": "Verlangsamt", "kind": "debuff", "default_turns": 3, "tick_speed_mult": 1.5,
			"excludes": ["sts_haste"]},
		{"id": "sts_haste", "name": "Turbo", "kind": "buff", "default_turns": 3, "tick_speed_mult": 0.6,
			"excludes": ["sts_slow"]},
		{"id": "sts_guard", "name": "Gepanzert", "kind": "buff", "default_turns": 3, "flags": ["guard"]},
		{"id": "sts_taunt", "name": "Provoziert", "kind": "buff", "default_turns": 3, "flags": ["taunt"]},
		{"id": "sts_brittle", "name": "Spröde", "kind": "debuff", "default_turns": 2, "stat_mult": {"def": 0.5, "spd": 1.5}},
		{"id": "sts_regen", "name": "Regeneration", "kind": "buff", "default_turns": 3, "tick_timing": "turn_end",
			"tick_pct": 10, "tick_min": 1},
		{"id": "sts_mute", "name": "Stumm", "kind": "debuff", "default_turns": 2, "flags": ["no_magic", "no_stunt"]},
	]
	var skills: Array = [
		_skill("skl_attack_kai", "party", "attack", "single_enemy", phys),
		_skill("skl_attack_mopsula", "party", "attack", "single_enemy", phys),
		_skill("skl_kai_heavy_swing", "party", "attack", "single_enemy",
			{"damage_type": "physical", "element": "physical", "power": 160, "mp_cost": 3, "rank": 4}),
		_skill("skl_kai_taunt", "party", "buff", "self", {"power": 0, "mp_cost": 2, "rank": 2,
			"statuses": [{"id": "sts_taunt", "turns": 3}, {"id": "sts_guard", "turns": 3}]}),
		_skill("skl_kai_sweep", "party", "attack", "all_enemies",
			{"damage_type": "physical", "element": "physical", "power": 80, "mp_cost": 5}),
		_skill("skl_kai_first_aid", "party", "heal", "single_ally",
			{"damage_type": "heal", "heal_mode": "pct", "power": 30, "mp_cost": 4, "rank": 2, "cleanse": ["sts_poison"]}),
		_skill("skl_kai_cable_whip", "party", "attack", "single_enemy",
			{"damage_type": "physical", "element": "shock", "power": 120, "mp_cost": 8,
				"statuses": [{"id": "sts_stun", "chance": 1.0}]}),
		_skill("skl_kai_double", "party", "attack", "single_enemy",
			{"damage_type": "physical", "element": "physical", "power": 50, "hits": 2, "mp_cost": 1}),
		_skill("skl_stunt_kai_suplex", "party", "stunt", "single_enemy",
			{"damage_type": "physical", "element": "physical", "power": 230, "rank": 4, "cooldown": 3,
				"success_base": 0.6, "success_lck": 0.01, "success_cap": 0.85, "success_boss_mod": -0.15,
				"fail_effect": {"self_dmg_pct": 10, "delay_pct": 50}, "anim": "stunt"}),
		_skill("skl_stunt_mop_entrance", "party", "stunt", "all_enemies",
			{"damage_type": "magical", "element": "fire", "power": 140, "rank": 4, "cooldown": 3,
				"success_base": 0.55, "fail_effect": {"status": "sts_stun"}, "anim": "stunt"}),
		_skill("skl_mop_noble_flame", "party", "magic", "single_enemy",
			{"damage_type": "magical", "element": "fire", "power": 110, "mp_cost": 4, "anim": "cast"}),
		_skill("skl_mop_holy_lick", "party", "heal", "single_ally",
			{"damage_type": "heal", "heal_mode": "mag", "power": 100, "mp_cost": 4, "rank": 2, "anim": "cast"}),
		_skill("skl_mop_royal_decree", "party", "buff", "single_ally",
			{"power": 0, "mp_cost": 6, "rank": 2, "statuses": [{"id": "sts_haste", "turns": 3}], "anim": "cast"}),
		_skill("skl_mop_frost_sneeze", "party", "magic", "single_enemy",
			{"damage_type": "magical", "element": "ice", "power": 105, "mp_cost": 5,
				"statuses": [{"id": "sts_slow", "chance": 1.0, "turns": 3}], "anim": "cast"}),
		_skill("skl_mop_revive", "party", "heal", "single_ally_ko",
			{"damage_type": "heal", "heal_mode": "pct", "power": 40, "mp_cost": 14, "rank": 4, "anim": "cast"}),
		_skill("skl_mop_mass_lick", "party", "heal", "all_allies",
			{"damage_type": "heal", "heal_mode": "mag", "power": 60, "mp_cost": 10, "cleanse": ["sts_poison"],
				"anim": "cast"}),
		_skill("skl_e_strike", "enemy", "attack", "single_enemy", phys),
		_skill("skl_e_bite", "enemy", "attack", "single_enemy", phys),
		_skill("skl_e_gnaw_poison", "enemy", "attack", "single_enemy",
			{"damage_type": "physical", "element": "poison", "power": 80,
				"statuses": [{"id": "sts_poison", "chance": 0.35}]}),
		_skill("skl_e_dive_bomb", "enemy", "attack", "all_enemies",
			{"damage_type": "physical", "element": "physical", "power": 60, "rank": 4}),
		_skill("skl_e_rat_heal", "enemy", "heal", "single_ally",
			{"damage_type": "heal", "heal_mode": "pct", "power": 30, "mp_cost": 5, "rank": 2}),
		_skill("skl_e_zap", "enemy", "magic", "single_enemy",
			{"damage_type": "magical", "element": "shock", "power": 100, "mp_cost": 3}),
		_skill("skl_e_web", "enemy", "debuff", "single_enemy",
			{"power": 0, "mp_cost": 2, "statuses": [{"id": "sts_slow", "chance": 0.8}]}),
		_skill("skl_e_brace", "enemy", "buff", "self",
			{"power": 0, "rank": 2, "statuses": [{"id": "sts_guard", "turns": 2}]}),
		_skill("skl_e_fine", "enemy", "special", "single_enemy",
			{"power": 0, "special": {"kind": "steal_credits", "max": 40, "refund_on_win": true}}),
		_skill("skl_e_escape", "enemy", "special", "self", {"power": 0, "rank": 2, "special": {"kind": "escape"}}),
		_skill("skl_b_broom", "enemy", "attack", "single_enemy",
			{"damage_type": "physical", "element": "physical", "power": 110}),
		_skill("skl_b_rules", "enemy", "buff", "self", {"power": 0, "statuses": [{"id": "sts_guard", "turns": 2}]}),
		_skill("skl_b_keys", "enemy", "attack", "all_enemies",
			{"damage_type": "physical", "element": "physical", "power": 70, "rank": 4}),
		_skill("skl_b_call_tenant", "enemy", "summon", "self", {"power": 0, "mp_cost": 6, "summon": ["enm_rat"]}),
		_skill("skl_item_bandage", "item", "item", "single_ally",
			{"damage_type": "heal", "heal_mode": "fixed", "power": 45, "rank": 2, "anim": "item"}),
		_skill("skl_item_antidote", "item", "item", "single_ally",
			{"power": 0, "rank": 2, "cleanse": ["sts_poison"], "anim": "item"}),
		_skill("skl_item_smelling_salts", "item", "item", "single_ally_ko",
			{"damage_type": "heal", "heal_mode": "pct", "power": 30, "rank": 2, "anim": "item"}),
		_skill("skl_item_ice_spray", "item", "item", "single_enemy",
			{"damage_type": "fixed", "element": "ice", "power": 90, "rank": 2, "anim": "item"}),
		_skill("skl_item_molotov", "item", "item", "all_enemies",
			{"damage_type": "fixed", "element": "fire", "power": 60, "rank": 2, "anim": "item"}),
		_skill("skl_item_smoke", "item", "item", "self", {"power": 0, "rank": 2, "flee_guaranteed": true, "anim": "item"}),
		_skill("skl_item_elixir", "item", "item", "single_ally",
			{"damage_type": "heal", "heal_mode": "pct", "power": 100, "mp_restore_pct": 100, "rank": 2, "anim": "item"}),
		_skill("skl_item_krawumm", "item", "item", "single_ally", {"power": 0, "mp_restore": 20, "rank": 2, "anim": "item"}),
		_skill("skl_item_burger", "item", "item", "single_ally",
			{"damage_type": "heal", "heal_mode": "fixed", "power": 120, "rank": 2, "anim": "item"}),
	]
	var items: Array = [
		_item("itm_bandage", "skl_item_bandage"), _item("itm_antidote", "skl_item_antidote"),
		_item("itm_smelling_salts", "skl_item_smelling_salts", "battle"),
		_item("itm_ice_spray", "skl_item_ice_spray", "battle"),
		_item("itm_molotov", "skl_item_molotov", "battle"), _item("itm_smoke", "skl_item_smoke", "battle"),
		_item("itm_elixir", "skl_item_elixir"), _item("itm_energy_krawumm", "skl_item_krawumm"),
		_item("itm_brutzel_burger", "skl_item_burger"),
		{"id": "itm_key_master", "name": "Generalschlüssel", "type": "key", "sell": 0},
		{"id": "itm_wpn_axe", "name": "Axt", "type": "weapon", "rarity": "epic", "price": 480, "stats": {"str": 12}},
	]
	var party: Array = [
		{"id": "kai", "name": "Kai", "battle_slot": 0, "base_stats": _stats(64, 12, 12, 5, 9, 6, 11, 8),
			"growth": _stats(9, 2, 2, 1, 1, 1, 1, 1), "attack_skill": "skl_attack_kai",
			"learnset": [{"level": 1, "skill": "skl_kai_heavy_swing"}], "stunts": ["skl_stunt_kai_suplex"],
			"model": _model("humanoid")},
		{"id": "mopsula", "name": "Mopsula", "title": "Graf", "battle_slot": 1,
			"base_stats": _stats(42, 30, 5, 13, 6, 11, 14, 12), "growth": _stats(6, 4, 1, 2, 1, 2, 1, 1),
			"attack_skill": "skl_attack_mopsula", "learnset": [{"level": 1, "skill": "skl_mop_noble_flame"}],
			"stunts": ["skl_stunt_mop_entrance"], "model": _model("pug")},
	]
	var enemies: Array = [
		_enemy("enm_rat", _stats(24, 0, 13, 3, 5, 3, 13, 5), [
			{"skill": "skl_e_bite", "weight": 3, "target": "random"},
			{"skill": "skl_e_gnaw_poison", "weight": 1, "target": "not_status:sts_poison"}],
			{"exp": 12, "credits": 6, "element_mods": {"fire": 1.5},
				"drops": [{"item": "itm_bandage", "chance": 0.25}, {"item": "itm_antidote", "chance": 0.1}]}),
		_enemy("enm_pigeon", _stats(20, 0, 12, 4, 3, 6, 19, 8), [
			{"skill": "skl_e_bite", "weight": 3, "target": "lowest_hp_pct"},
			{"skill": "skl_e_dive_bomb", "weight": 1, "target": "all_enemies"}],
			{"exp": 14, "credits": 5, "element_mods": {"shock": 1.5}}),
		_enemy("enm_slime", _stats(40, 10, 12, 12, 10, 4, 9, 3), [
			{"skill": "skl_e_bite", "weight": 2, "target": "random"}],
			{"exp": 20, "credits": 8, "element_mods": {"fire": 1.5, "physical": 0.5, "poison": 0.0},
				"status_immune": ["sts_poison"]}),
		_enemy("enm_shaman", _stats(34, 30, 9, 16, 6, 12, 12, 6), [
			{"skill": "skl_e_bite", "weight": 1, "target": "random"},
			{"skill": "skl_e_rat_heal", "weight": 6, "target": "ally_lowest_hp_pct", "cond": {"ally_hp_below": 0.5}}],
			{"exp": 26, "credits": 12}),
		_enemy("enm_mimic", _stats(60, 0, 18, 18, 20, 20, 16, 20), [
			{"skill": "skl_e_fine", "weight": 10, "target": "random", "cond": {"once": true}},
			{"skill": "skl_e_bite", "weight": 3, "target": "random"},
			{"skill": "skl_e_escape", "weight": 100, "target": "self", "cond": {"turn_mod": [4, 3]}}],
			{"exp": 60, "credits": 150, "element_mods": {"shock": 1.5}}),
		_enemy("enm_dummy", _stats(500, 0, 1, 1, 1, 1, 1, 1), [], {"exp": 1, "credits": 1}),
		{"id": "enm_boss_janitor", "name": "Hausmeister", "boss": true, "stats": _stats(380, 60, 23, 14, 14, 10, 12, 6),
			"exp": 180, "credits": 200, "attack_skill": "skl_b_broom",
			"element_mods": {"shock": 1.5, "poison": 0.5}, "status_resist": {"sts_stun": 0.5, "sts_slow": 0.5},
			"boss_drops": [{"kind": "item", "id": "itm_key_master", "amount": 1},
				{"kind": "box", "id": "box_bronze", "amount": 1}],
			"ai": {"type": "phased", "actions": []},
			"phases": [
				{"hp_above": 0.6, "on_enter": [{"op": "say", "tag": "boss_intro:enm_boss_janitor"}],
					"actions": [{"skill": "skl_b_rules", "weight": 10, "target": "self", "cond": {"once": true}},
						{"skill": "skl_b_broom", "weight": 3, "target": "random"}]},
				{"hp_above": 0.25, "on_enter": [{"op": "summon", "enemy": "enm_rat", "count": 1},
						{"op": "say", "tag": "boss_phase:enm_boss_janitor:2"}],
					"actions": [{"skill": "skl_b_broom", "weight": 2, "target": "random"},
						{"skill": "skl_b_keys", "weight": 1, "target": "all_enemies"},
						{"skill": "skl_b_call_tenant", "weight": 4, "target": "self", "cond": {"allies_alive_below": 2}}]},
				{"hp_above": 0.0, "on_enter": [{"op": "status_self", "status": "sts_haste", "turns": 5},
						{"op": "say", "tag": "boss_phase:enm_boss_janitor:3"}],
					"actions": [{"skill": "skl_b_broom", "weight": 2, "target": "lowest_hp_pct"}]}],
			"model": _model("brute"), "explore": {"field_speed": 0.0}},
		{"id": "enm_boss_queen", "name": "Königin", "boss": true, "stats": _stats(720, 120, 26, 20, 18, 16, 15, 10),
			"exp": 420, "credits": 500, "attack_skill": "skl_b_broom",
			"element_mods": {"ice": 1.5, "fire": 0.5, "poison": 0.0}, "status_immune": ["sts_poison"],
			"status_resist": {"sts_stun": 0.5, "sts_slow": 0.5}, "ai": {"type": "phased", "actions": []},
			"phases": [
				{"hp_above": 0.65, "on_enter": [{"op": "summon", "enemy": "enm_rat", "count": 2},
						{"op": "say", "tag": "boss_intro:enm_boss_queen"}],
					"actions": [{"skill": "skl_b_broom", "weight": 3, "target": "random"}]},
				{"hp_above": 0.3, "on_enter": [{"op": "add_pseudo", "unit": "pu_train", "ctr": 120},
						{"op": "say", "tag": "boss_phase:enm_boss_queen:2"}],
					"actions": [{"skill": "skl_b_broom", "weight": 3, "target": "random"}]},
				{"hp_above": 0.0, "on_enter": [{"op": "remove_pseudo", "unit": "pu_train"},
						{"op": "fixed_damage_self", "amount": 72, "min_hp": 1},
						{"op": "status_self", "status": "sts_haste", "turns": 99},
						{"op": "say", "tag": "boss_phase:enm_boss_queen:3"}],
					"actions": [{"skill": "skl_b_broom", "weight": 3, "target": "lowest_hp_pct"}]}],
			"model": _model("rodent"), "explore": {"field_speed": 0.0}},
	]
	var pseudo: Array = [
		{"id": "pu_train", "name": "Einfahrender Zug", "icon": "train",
			"action": {"fixed_pct_maxhp": 35, "element": "physical", "ignores_guard": true, "target": "all_party"},
			"ctr_after": 160, "warn_tag": "boss_train_warning", "warn_at": 2},
	]
	var sponsors: Array = [
		{"id": "spn_gluck", "name": "Glückwasser", "color": "#4ad9d9", "gift": [{"kind": "heal_party_pct", "value": 35}]},
		{"id": "spn_krawumm", "name": "KRAWUMM", "color": "#ff7a1a",
			"gift": [{"kind": "status_party", "status": "sts_haste", "turns": 3}]},
		{"id": "spn_brutzel", "name": "Brutzel-Burger", "color": "#ff8a3d",
			"gift": [{"kind": "item", "item": "itm_brutzel_burger", "value": 1}, {"kind": "heal_party_flat", "value": 20}]},
		{"id": "spn_sorgenfrei", "name": "Sorgenfrei", "color": "#ffffff",
			"gift": [{"kind": "revive_or_heal_lowest", "value": 50}]},
		{"id": "spn_novanet", "name": "NovaNet", "color": "#2222ff", "gift": [{"kind": "mp_party_pct", "value": 40}]},
		{"id": "spn_doom", "name": "DoomScroll+", "color": "#7a5cff",
			"gift": [{"kind": "status_enemies", "status": "sts_slow", "turns": 3, "target": "enemies", "ignore_resist": true}]},
	]
	var lootboxes: Array = [
		{"id": "box_bronze", "name": "Bronze", "tier": 1, "color": "#cd7f32", "rolls": 2,
			"rarity_weights": {"common": 80, "rare": 18, "epic": 2}},
		{"id": "box_gold", "name": "Gold", "tier": 3, "color": "#ffd700", "rolls": 4,
			"rarity_weights": {"common": 25, "rare": 55, "epic": 20}, "guarantee": "epic"},
	]
	var pools: Dictionary = {"f1": {
		"common": [{"kind": "credits", "id": "", "amount": 40, "weight": 30},
			{"kind": "item", "id": "itm_bandage", "amount": 2, "weight": 25}],
		"rare": [{"kind": "item", "id": "itm_smelling_salts", "amount": 1, "weight": 20}],
		"epic": [{"kind": "item", "id": "itm_wpn_axe", "amount": 1, "weight": 10}]}}
	return {"statuses": statuses, "skills": skills, "items": items, "party": party, "enemies": enemies,
		"pseudo_units": pseudo, "sponsors": sponsors, "lootboxes": lootboxes, "lootbox_pools": pools,
		"party_start": {"inventory": {"itm_bandage": 3}, "credits": 50}}


## Party combatant from the fixture def (level 1 base stats, full HP/MP unless given).
static func member(data: GameData, def_id: String, pid: String, slot: int, opts: Dictionary = {}) -> Combatant:
	var def: PartyMemberDef = data.party_member(def_id)
	var stats: StatBlock = StatBlock.from_dict(def.base_stats)
	if opts.has("stats"):
		var over: Dictionary = opts["stats"]
		for k: String in over.keys():
			stats.set_stat(StatBlock.key_to_stat(k), int(over[k]))
	var skills: PackedStringArray = opts.get("skills", PackedStringArray()) as PackedStringArray
	var c: Combatant = Combatant.create_party(def, pid, slot, def.name, 1, stats,
			int(opts.get("hp", stats.get_stat(StatBlock.Stat.HP))), int(opts.get("mp", stats.get_stat(StatBlock.Stat.MP))),
			skills, def.stunts, def.attack_skill, opts.get("element_mods", {}) as Dictionary,
			opts.get("status_immune", PackedStringArray()) as PackedStringArray, "physical",
			float(opts.get("crit_bonus", 0.0)))
	return c


## BattleSetup with Kai (p0) + Mopsula (p1) and the given enemies. opts: kai/mop (member opts), seed, advantage,
## items, credits, is_boss, can_flee, tutorial, enemy_dmg_mult, exp_mult, solo (only Kai).
static func make_setup(data: GameData, enemy_ids: PackedStringArray, opts: Dictionary = {}) -> BattleSetup:
	var s: BattleSetup = BattleSetup.new()
	s.encounter_id = str(opts.get("encounter_id", "enc_test"))
	s.group_id = str(opts.get("group_id", "f1_g1"))
	s.enemy_ids = enemy_ids
	s.party.append(member(data, "kai", "p0", 0, opts.get("kai", {}) as Dictionary))
	if not bool(opts.get("solo", false)):
		s.party.append(member(data, "mopsula", "p1", 1, opts.get("mop", {}) as Dictionary))
	s.items = (opts.get("items", {}) as Dictionary).duplicate(true)
	s.credits_available = int(opts.get("credits", 100))
	s.advantage = int(opts.get("advantage", BattleSetup.Advantage.NORMAL)) as BattleSetup.Advantage
	s.seed = int(opts.get("seed", 1))
	s.is_boss = bool(opts.get("is_boss", false))
	s.can_flee = bool(opts.get("can_flee", not s.is_boss))
	s.tutorial = bool(opts.get("tutorial", false))
	s.enemy_dmg_mult = float(opts.get("enemy_dmg_mult", 1.0))
	s.exp_mult = float(opts.get("exp_mult", 1.0))
	return s


static func make_state(data: GameData, enemy_ids: PackedStringArray, opts: Dictionary = {}) -> BattleState:
	return BattleState.new(make_setup(data, enemy_ids, opts), data)


## One AI/auto step (current actor chooses, submit). [] if finished.
static func auto_step(state: BattleState) -> Array[ActionEvent]:
	var none: Array[ActionEvent] = []
	if state.is_finished():
		return none
	return state.submit(state.choose_ai_command())


## Auto vs auto until the end or `max_turns` TURN_STARTs; returns all events (incl. start()).
static func run_auto(state: BattleState, max_steps: int = 400) -> Array[ActionEvent]:
	var all: Array[ActionEvent] = []
	if state.phase == BattleState.Phase.SETUP:
		all.append_array(state.start())
	var n: int = 0
	while not state.is_finished() and n < max_steps:
		all.append_array(auto_step(state))
		n += 1
	return all


static func of_type(events: Array[ActionEvent], t: ActionEvent.Type) -> Array[ActionEvent]:
	var out: Array[ActionEvent] = []
	for e: ActionEvent in events:
		if e.type == t:
			out.append(e)
	return out


static func types(events: Array[ActionEvent]) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: ActionEvent in events:
		out.append(ActionEvent.type_name(e.type))
	return out


static func dicts(events: Array[ActionEvent]) -> Array:
	var out: Array = []
	for e: ActionEvent in events:
		out.append(e.to_dict())
	return out


## Lets the given unit act next: its counter 0, all others >= 1 (keeps the relative order of the rest).
static func force_next(state: BattleState, c: Combatant) -> void:
	for o: Combatant in state.combatants:
		if o != c and o.ctb_counter < 1:
			o.ctb_counter = 1
	c.ctb_counter = 0


# --- self-test ------------------------------------------------------------------------------------------------------

func test_fixture_data_is_valid() -> void:
	var data: GameData = fixture_data(tables())
	assert_true(data.is_valid(), "fixture data loads without errors")
	assert_true(data.has_id("pseudo_units", "pu_train"))
	var s: BattleState = make_state(data, PackedStringArray(["enm_rat"]))
	var ev: Array[ActionEvent] = s.start()
	assert_false(ev.is_empty())
	assert_eq(ActionEvent.type_name(ev[0].type), "BATTLE_START")
