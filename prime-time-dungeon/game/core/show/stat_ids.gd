class_name StatIds extends RefCounted
## Achievement counter ids (02_TECH §6.3), persistent in ShowState.stats. == DataValidator.STAT_IDS
## (test_m2_achievements asserts the equality).
##
## Counters grow by +n (Show.bump_stat), viewers_max / viewers_target_peak only grow to a new maximum
## (Show.set_stat_max), explore_seconds_since_battle is reset to 0 by Show.begin_battle. bets_won / liga_battles
## (06 §4.6) are raised by MarottenRules before the show_bet trigger. A PREEMPTIVE battle opened from Graf Mopsula's
## bark (BattleSetup.opener "bark") counts as bark_openers, not as preemptives (no sneaking; integration round 4).

const ALL: PackedStringArray = ["kills_total", "kills_skill", "battles_won", "battles_fled", "preemptives",
	"ambushes_won", "crits_total", "stunts_success", "stunts_fail", "chests_opened", "sponsor_gifts",
	"credits_spent_vendor", "lootboxes_opened", "events_completed", "game_overs", "ko_mopsula",
	"explore_seconds_since_battle", "viewers_max", "viewers_target_peak", "followers_gained_run", "hype_100_count",
	"bets_won", "liga_battles",                                     # 06-C: show bets won, battles won in the Liga
	"bark_openers",                                                 # 06 A × C: battles opened from Mopsula's bark
	# Echtzeitkampf (07, R1a, §9.4): interrupts / dodges of the controlled unit, adds killed by the train, taunts of the
	# person (own key or Partner-Spezial, by_ai == false) — raised by the ShowRules profile rt (R5a)
	"interrupts_total", "dodges_total", "train_kills", "taunts_total"]
