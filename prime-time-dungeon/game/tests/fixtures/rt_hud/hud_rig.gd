extends RefCounted
## Puts a CombatHud (res://scenes/combat/ui/combat_hud.tscn) bound to a sim (the HudSim double or the real RtSim of
## RtKit) and the director double into a TestCase's tree (07 §12.5 R3); rects() lists the shown element rects. Private
## fixture (no class_name). The HUD sits under a plain holder node (no Router.adopt), every node is freed with the
## test. Default params: no Events wiring, no screen modes — a test that checks the modes passes {"modes": true}.

const HUD_SCENE: String = "res://scenes/combat/ui/combat_hud.tscn"
const HudDirector := preload("res://tests/fixtures/rt_hud/hud_director.gd")
const HudScenarios := preload("res://tests/fixtures/rt_hud/hud_scenarios.gd")
const CombatView := preload("res://scenes/combat/ui/combat_view.gd")
const UnitFrames := preload("res://scenes/combat/ui/unit_frames.gd")
const CombatHudScript := preload("res://scenes/combat/ui/combat_hud.gd")


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


## Every element rect of the HUD (+ overlay) on screen now: name → Rect2 (canvas).
static func rects(hud: Node, overlay: CanvasLayer) -> Dictionary:
	var out: Dictionary = {}
	var frames: Control = hud.get("frames") as Control
	var fo: Vector2 = frames.get_global_rect().position
	for n: String in ["ctl_frame", "partner_frame", "special", "chip"]:
		var r: Rect2 = frames.call("hit_rect", n) as Rect2
		if r.size.x > 0.0:
			out[n] = r
	if out.has("special"):                                       # visible rects (hit areas: test_r3_touch_layout)
		out["special"] = Rect2(fo + (frames.call("special_rect") as Rect2).position,
			(frames.call("special_rect") as Rect2).size)
	if out.has("chip"):
		out["chip"] = Rect2(fo + (frames.call("chip_rect") as Rect2).position, (frames.call("chip_rect") as Rect2).size)
	var model: Dictionary = frames.call("model")
	for spec: Array in [["ctl", UnitFrames.CTL_STATUS], ["partner", UnitFrames.PARTNER_STATUS]]:
		var u: RtUnit = model.get(str(spec[0]), null) as RtUnit
		var sim: RtSim = hud.get("sim")
		var n: int = mini(CombatView.statuses(sim, u).size(), UnitFrames.STATUS_MAX) if u != null else 0
		if n > 0:
			out["status_" + str(spec[0])] = Rect2(fo + (spec[1] as Vector2),
				Vector2(UnitFrames.STATUS_STEP * n, UnitFrames.STATUS_SIZE + 2.5))      # icon + buff / debuff line
	var top: float = float(frames.call("top_block_bottom"))
	if top > 0.0:
		var bw: float = UnitFrames.BOSS_W if model.get("boss", null) != null else UnitFrames.TARGET_W
		out["top_block"] = Rect2(fo + Vector2((frames.size.x - bw) * 0.5, 0.0), Vector2(bw, top))
	var bar: Control = hud.get("bar") as Control
	if bar.is_visible_in_tree():
		out["bar"] = bar.get_global_rect()
	var cast: Control = (hud.get("_frame") as Control).get_node("PlayerCast") as Control
	if cast.visible:
		out["player_cast"] = cast.get_global_rect()
	var fr: Rect2 = (hud.get("_frame") as Control).get_global_rect()
	var sub: Dictionary = CombatHudScript.SUBTITLE_PC
	out["subtitle"] = Rect2(fr.position.x + (fr.size.x - float(sub["width"])) * 0.5,
		fr.end.y - float(sub["bottom"]) - 56.0, float(sub["width"]), 56.0)
	if overlay != null:
		out["show_top_left"] = (overlay.get("_top_left") as Control).get_global_rect()
		out["hype"] = overlay.call("hype_rect") as Rect2
		for n2: String in ["clock_chip_rect", "show_chip_rect"]:
			var r2: Rect2 = overlay.call(n2) as Rect2
			if r2.size.x > 0.0:
				out[n2] = r2
		out["ticker"] = (overlay.get("_ticker_panel") as Control).get_global_rect()
	return out
