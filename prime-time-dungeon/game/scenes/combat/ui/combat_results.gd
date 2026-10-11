# STUB(R1a) — owned by R3. Replace completely, keep the public API.
extends CanvasLayer
## Results of a real-time combat (07 §8.9): successor of scenes/battle/ui/battle_results.gd with the 06 docking points
## — results_shown + show_slot (06 §8.0 Nr. 12: package C hangs its show-bet effect onto the slot), the chip
## "TALENT BEREIT · im Safe Room wählen" on a talent level (06 B, never a choice here), present(); autoplay continues
## after 1.0 s (auto_continue_sec). Forms: regular win (lower third, non-blocking), boss win (credits panel), flight,
## defeat (existing sign-off). Private script (no class_name), like battle_results.gd.
## Stub: present() emits results_shown and shows nothing.

signal results_shown(result: BattleResult)

## Slot for the show-bet effect of package C (hearts flying into the show chip); null until R3 builds the panel.
var show_slot: Control = null
## >= 0: continue automatically after this many seconds (autoplay 1.0); < 0: wait for the player.
var auto_continue_sec: float = -1.0


## Shows the result of `result` with the applied `rewards`. Stub: only results_shown.
func present(result: BattleResult, _rewards: BattleRewards) -> void:
	results_shown.emit(result)
