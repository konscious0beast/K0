extends Node
## Global signal bus. Signals only, no state, no logic.
## Arrays in signal args are untyped on purpose (no dependency on core classes); element types are documented.
## Achievement triggers carry one `payload: Dictionary` (keys: §6.3 "Trigger-Payloads").

# --- Flow ---------------------------------------------------------------
signal scene_changed(scene_path: String)
signal new_game_started(slot: int)
signal game_loaded(slot: int)
signal game_saved(slot: int, ok: bool)
signal settings_changed()
signal input_scheme_changed(scheme: int)                 # Game.InputScheme
signal overlay_mode_requested(mode: StringName)          # &"explore", &"battle", &"safe_room", &"menu", &"hidden"
signal pause_menu_toggled(open: bool)

# --- Floor / exploration -----------------------------------------------
signal floor_entered(floor_index: int)                   # first entry of a floor (not on resume)
signal floor_timer_started()                             # FloorRun.timer_started false → true (after tutorial battle)
signal floor_timer_changed(seconds_left: int)            # whenever the integer second changes
signal floor_timer_warning(seconds_left: int)            # exactly at FloorDef.timer_warnings values
signal floor_timer_expired()
signal floor_completed(floor_index: int)                 # stairs taken (before summary overlay)
signal room_entered(cell: Vector2i, room_kind: int, first_visit: bool)   # RoomCell.Kind
signal enemy_alerted(group_id: String)
signal encounter_triggered(group_id: String, encounter_id: String, advantage: int)  # BattleSetup.Advantage
signal chest_opened(chest_id: String, rewards: Array)    # Array[LootReward]; Game.open_chest
signal gate_opened(cell: Vector2i, dir: int)             # RoomCell.DOOR_*
signal stray_spawn_requested(zone_id: String, group_id: String, encounter_id: String)   # Game (RunSim STRAY_DUE)
signal camera_drag(relative: Vector2)                    # touch camera drag in viewport px
signal camera_zoom(amount: float)                        # touch pinch: arm length change in m (> 0 = zoom out)

# --- Battle ---------------------------------------------------------------
signal battle_started(encounter_id: String, is_boss: bool)
signal battle_turn_started(combatant_id: String, is_party: bool)
signal battle_ended(outcome: int, encounter_id: String)  # BattleResult.Outcome

# --- Achievement triggers (payload keys: §6.3) --------------------------------
signal enemy_killed(payload: Dictionary)                 # Show (from ActionEvent KO)
signal battle_won(payload: Dictionary)                   # Show.end_battle
signal battle_fled(payload: Dictionary)                  # Show.end_battle
signal stunt_resolved(payload: Dictionary)               # Show (STUNT_RESULT)
signal combo(payload: Dictionary)                        # Show (COMBO)
signal party_ko(payload: Dictionary)                     # Show (KO of a party member)
signal boss_defeated(payload: Dictionary)                # Show.end_battle (VICTORY + is_boss)
signal boss_hp_changed(payload: Dictionary)              # Show (boss hit, hp_after): {"boss_id", "hp", "max_hp"}
signal item_bought(payload: Dictionary)                  # Game.buy
signal event_completed(payload: Dictionary)              # Game.apply_floor_event (FloorEvent done)
signal explore_tick(payload: Dictionary)                 # Game, once per full explore second (RunSim)
signal level_up(payload: Dictionary)                     # Game.apply_battle_result, once per level gained

# --- Show -----------------------------------------------------------------
signal viewers_changed(viewers: int)                     # noise-free ShowModel value (deterministic)
signal followers_changed(followers: int, delta: int)
signal hype_changed(hype: float, delta: float, reason: StringName)
signal achievement_unlocked(achievement_id: String)
signal milestone_reached(milestone_id: String)
signal sponsor_gift_triggered(sponsor_id: String)
# voice: &"mod", &"mopsula", &"kai", &"chat"
signal mod_said(text: String, voice: StringName, tag: String, blocking: bool)
signal dialog_finished(tag: String)                      # emitted by ModDialog when a line is done/dismissed
signal chat_posted(user: String, text: String, mood: StringName)  # mood: &"hype", &"neutral", &"bored"

# --- Progression ------------------------------------------------------------
signal party_changed()
signal member_leveled(member_id: String, new_level: int, learned: PackedStringArray)
signal inventory_changed()
signal credits_changed(credits: int, delta: int)
signal lootbox_earned(box_id: String)
signal lootbox_opened(box_id: String, rewards: Array)    # Array[LootReward]
# --- Talents & casting (06 §2/§3, package B) ----------------------------------
signal talent_pending(member_id: String, level: int)     # Game.apply_battle_result: a level-up earned a talent choice
signal talent_picked(member_id: String, talent_id: String)   # Game.pick_talent (recorded)

# --- Live mode (M8 hooks, Brief §6b; 05_LIVE_MODUS CR-1) ------------------------
signal run_started(event_id: String, league: String)
signal run_finished(summary: Dictionary)
signal quest_progress(progress: float)
signal quest_completed()
signal gift_received(gift: Dictionary)                   # every accepted gift, incl. source "system"
signal gift_rejected(gift_id: String, reason: String)
# Sponsor-Fenster (05 §6.13, user decision 2026-10-08): viewers may help only while a window is open.
# window = SponsorWindows.window_view: {"open", "id", "kind" (periodic|safe_room|boss|dev), "ref", "slots", "used",
# "free", "full", "per_viewer", "left_ticks", "len_ticks", "left_sec"}.
signal sponsor_window_opened(window: Dictionary)         # Game (RunSim SPONSOR_WINDOW_OPENED)
signal sponsor_window_closed(window_id: String, reason: String)   # Game (RunSim): reason time|left|superseded|floor
signal sponsor_window_updated(window: Dictionary)        # Show: a gift took a slot of the open window

# --- Hero & field abilities (06 §1, package A) ---------------------------------
signal hero_changed(hero_id: String)                     # Game.set_hero: the controlled character changed
signal field_ability_used(hero_id: String, ability: StringName, hits: int)   # ExplorationScene: &"strike" | &"bark"
signal secret_opened(secret_id: String)                  # Game.open_secret: Kulissenwand / Regie-Notiz (06 §2.7)

# --- Show bets / Marotten / Unterhosen-Liga (06 §4, package C) --------------------
signal marotten_announced(ids: PackedStringArray)        # Show.start_floor: M.O.D.'s preferences of the floor
signal marotte_progress(marotte_id: String, hits: int, goal: int)   # Show: a heart filled (battle / room visit)
signal marotte_won(marotte_id: String)                   # Show: `goal` hearts — the bet is won
signal liga_changed(tier: int)                           # Show.begin_battle: the battle's Liga tier differs (0/1/2)

# --- UI -----------------------------------------------------------------
signal toast_requested(text: String, icon: StringName)
## Bottom corners (canvas px inside the safe frame) a screen keeps for its own panels while overlay `mode` is active;
## the ModDialog box centres in the free span between them (battle: command menu / party panels). (0, 0) clears.
signal dialog_reserve_requested(mode: StringName, left: float, right: float)
