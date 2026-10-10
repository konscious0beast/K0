class_name Balance extends RefCounted
## All battle/progression formula constants (02_TECH §5.9, GDD §3/§16.3). Values may be rebalanced, the structure
## may not.
## The battle core converts the float constants once to permille/basis points (core/stats/fixed_math.gd) and computes
## with integers (05 CR-12); e.g. the damage variance is drawn as rng.randi_range(900, 1100) ‰.

const DMG_VARIANCE_MIN: float = 0.9
const DMG_VARIANCE_MAX: float = 1.1
const HEAL_VARIANCE_MIN: float = 0.95
const HEAL_VARIANCE_MAX: float = 1.05
const CRIT_BASE: float = 0.05
const CRIT_PER_LCK: float = 0.005
const CRIT_CAP: float = 0.40
const CRIT_MULT: float = 1.5
const DEFEND_MULT: float = 0.5
const GUARD_DEF_MULT: float = 1.5
const COMBO_MULT: float = 1.1
const HEAL_STAT_MULT: float = 1.5
const HEAL_BASE: float = 10.0
const DEFEND_MP_PCT: float = 0.05
const DEFEND_MP_MIN: int = 2
const POST_BATTLE_MP_REGEN: float = 0.15
const TAUNT_CHANCE: float = 0.80
const STUN_BOSS_MULT: float = 0.5
const SUMMON_CTR_FRAC: float = 0.5
const OVERKILL_MAXHP_FRAC: float = 1.0
const OVERKILL_CREDIT_MULT: float = 1.25
const DROP_LCK_DIV: float = 100.0
const FLEE_BASE: float = 0.40
const FLEE_PER_SPD: float = 0.03
const FLEE_PER_FAIL: float = 0.15
const FLEE_PREEMPT: float = 0.25
const FLEE_MIN: float = 0.10
const FLEE_MAX: float = 0.95
const STUNT_COOLDOWN: int = 3
const STUNT_CHANCE_MIN: float = 0.05
const LEVEL_CAP: int = 10
const EXP_A: float = 18.0
const EXP_B: float = 1.7
const EXP_C: float = 15.0
const KO_REVIVE_HP: int = 1             # after VICTORY, KO'd members return with 1 HP
const EASY_TIMER_MULT: float = 1.5      # Vorabendprogramm
const EASY_ENEMY_DMG: float = 0.75
const EASY_EXP: float = 1.2
const TUTORIAL_ENEMY_DMG: float = 0.5
const BACK_DOT: float = -0.34           # exploration: "from behind" (≙ > 110°)
