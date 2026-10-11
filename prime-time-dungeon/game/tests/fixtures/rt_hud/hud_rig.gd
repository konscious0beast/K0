extends RefCounted
## Puts a CombatHud (res://scenes/combat/ui/combat_hud.tscn) bound to a HudSim and the director double into a
## TestCase's tree (07 §12.5 R3). Private fixture (no class_name). The HUD sits under a plain holder node (no
## Router.adopt), every node is freed with the test. Default params: no Events wiring, no screen modes — a test that
## checks the modes passes {"modes": true}.

const HUD_SCENE: String = "res://scenes/combat/ui/combat_hud.tscn"
const HudDirector := preload("res://tests/fixtures/rt_hud/hud_director.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")


## {"hud": CanvasLayer, "director": Node, "sim": RtSim}.
static func make(tc: TestCase, sim: RtSim, data: GameData, extra: Dictionary = {}) -> Dictionary:
	var holder: Node = Node.new()
	holder.name = "R3Rig"
	tc.add_to_tree(holder)
	var dir: Node = HudDirector.new()
	dir.name = "Director"
	dir.set("sim", sim)
	holder.add_child(dir)
	var hud: CanvasLayer = (load(HUD_SCENE) as PackedScene).instantiate() as CanvasLayer
	var params: Dictionary = {"director": dir, "sim": sim, "data": data, "auto_events": false, "modes": false}
	params.merge(extra, true)
	hud.call("setup", params)
	holder.add_child(hud)
	dir.set("hud", hud)
	return {"hud": hud, "director": dir, "sim": sim}
