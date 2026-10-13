extends "res://tests/fixtures/rt_world/world_case.gd"
## 08 §6.3 (K2): the persona look in the world (real floor 1, real-time run, world fixture stream). The exploration
## rigs — the player when Kai leads, the companion when the Count leads — are built from DB.party_model, so they wear
## the persona's look; in a real-time combat the party's puppets are exactly these rigs (07 §2.8), so Kai fights in
## the look too; the Count keeps his own model; without a persona Kai is today's Kai.

const LOOK: Dictionary = {"hair": "lk_hair_curls", "hair_color": "lk_hc_black", "skin": "lk_skin_7",
	"beard": "lk_beard_full", "glasses": "lk_glasses_round", "outfit": "lk_outfit_blue"}
const STYLE: Dictionary = {"hair": "curls", "beard": "full"}


## A new game (it fights in real time) with a persona in LOOK.
func _new_rt_game() -> void:
	var p: PersonaProfile = PersonaProfile.canon(DB.data)
	p.name = "Jana"
	p.look = LOOK.duplicate()
	Game.new_game(0, "Jana", SEED, &"prime", HeroRules.DEFAULT_HERO, p)


func after_each() -> void:
	await super()
	Game.persona = null


func _model(n: Node) -> Dictionary:
	return n.get("model") as Dictionary if n != null else {}


## Starts the world combat with f1_g1 in (1,4) and returns kai's puppet rig.
func _kai_puppet() -> Node3D:
	var cell: Vector2i = Vector2i(1, 4)
	place_player(cell, Vector3(0.0, 0.0, 2.0), 0.0)
	place_lead("f1_g1", cell, Vector3(0.0, 0.0, -1.5), PI)
	assert_true(scene.pull("f1_g1", "skill", "skl_x"), "the combat starts")
	director.advance(5)
	var kai_unit: String = ""
	for u: RtUnit in Game.combat.units():
		if u.def_id == "kai":
			kai_unit = u.id
	assert_ne(kai_unit, "", "kai is in the combat")
	return director.puppets.call("rig_of", kai_unit) as Node3D


func test_kai_leads_and_fights_in_the_look() -> void:
	await make_world()
	var rig: Node3D = scene.get_player().rig
	assert_eq(_model(rig), DB.party_model("kai"), "the player rig: DB.party_model")
	assert_eq(_model(rig).get("style", {}), STYLE)
	assert_eq(((_model(rig)["colors"]) as Dictionary)["skin"], "#6b4128")
	assert_has(Array(_model(rig)["props"]), "glasses")
	assert_eq(_model(scene.get_companion().rig), DB.data.party_member("mopsula").model, "the Count stays the Count")
	var puppet: Node3D = await _kai_puppet()
	assert_true(puppet == rig, "kai's puppet is the player rig")
	assert_eq(_model(puppet).get("style", {}), STYLE, "the real-time combat shows the look")


func test_the_count_leads_and_kai_follows_in_the_look() -> void:
	await make_world("win", 300, "mopsula")
	var comp: Node3D = scene.get_companion().rig
	assert_eq(_model(comp), DB.party_model("kai"), "the companion rig: DB.party_model")
	assert_eq(_model(comp).get("style", {}), STYLE)
	assert_eq(str(_model(scene.get_player().rig).get("base", "")), "pug")
	var puppet: Node3D = await _kai_puppet()
	assert_true(puppet == comp, "kai's puppet is the companion rig")
	assert_eq(_model(puppet).get("style", {}), STYLE)


func test_without_a_persona_kai_is_the_canon_kai() -> void:
	Game.persona = null
	await make_world()
	assert_eq(_model(scene.get_player().rig), DB.data.party_member("kai").model)
