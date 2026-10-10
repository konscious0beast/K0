extends "res://scenes/exploration/interactable.gd"
## Regie-Notiz (06 §2.7, package A): a little director's stand with a glowing yellow post-it — M.O.D.'s backstage
## jokes. "Regie-Notiz lesen" → ExplorationScene.read_note → Game.open_secret (+15 followers once, M.O.D.
## regie_note:<n>); the post-it flies off, the stand stays. A note "behind" a Kulissenwand stays hidden (no visuals, no
## prompt) until that wall is down (reveal()).

const POSTIT: Color = Color("#ffe14d")
const BOARD: Color = Color("#2a2530")
const COLLECT_SEC: float = 0.6

var secret: Dictionary = {}
var secret_id: String = ""
var number: int = 0
var collected: bool = false
var hidden_behind: bool = false
var prop: Node3D = null
var postit: Node3D = null


## `p_secret` = layout.secrets entry (kind "note"); `hidden` = behind a wall that still stands.
func setup_note(p_secret: Dictionary, hidden: bool) -> void:
	secret = p_secret
	secret_id = str(p_secret.get("id", ""))
	number = int(p_secret.get("n", 0))
	interact_id = secret_id
	name = "Note_" + secret_id
	extent = 0.2
	prop = Node3D.new()
	prop.name = "Prop"
	add_child(prop)
	# the board faces the room centre (the node's −Z, _placement): the post-it sits on that side, the board leans back
	FB._mesh_part(prop, FB._cyl(0.03, 0.04, 1.0, 6), Vector3(0.0, 0.5, 0.0), FB.toon(Color("#55505e")),
		Vector3.ZERO, "Pole")
	var board: MeshInstance3D = FB._mesh_part(prop, FB._box(Vector3(0.72, 0.5, 0.04)), Vector3(0.0, 1.12, 0.0),
		FB.toon(BOARD), Vector3(deg_to_rad(28.0), 0.0, 0.0), "Board")
	postit = Node3D.new()
	postit.name = "PostIt"
	postit.position = Vector3(0.05, 1.14, -0.035)
	postit.rotation = Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(-7.0))
	prop.add_child(postit)
	FB._mesh_part(postit, FB._box(Vector3(0.34, 0.34, 0.012)), Vector3.ZERO, FB.toon(POSTIT, true, 0.6, 0.012),
		Vector3.ZERO, "Paper")
	for i in 3:
		FB._mesh_part(postit, FB._box(Vector3(0.22 - i * 0.04, 0.022, 0.016)), Vector3(-0.015, 0.07 - i * 0.06,
			-0.002), FB.toon(FB.INK, false), Vector3.ZERO, "Line%d" % i)
	FB._mesh_part(prop, FB._sphere(0.06), Vector3(0.0, 1.55, 0.0), FB.glow(POSTIT, 2.2, 1.2, 0.08), Vector3.ZERO,
		"Glint")
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_make_area(Rules.INTERACT_RADIUS + extent + 0.8)
	set_hidden(hidden)


func set_hidden(on: bool) -> void:
	hidden_behind = on
	if prop != null:
		prop.visible = not on
	monitoring = not on and not collected


## The wall in front of it fell: the note appears.
func reveal() -> void:
	if not hidden_behind:
		return
	set_hidden(false)
	if is_inside_tree():
		Vfx.spawn(&"sparkle", get_parent(), global_position + Vector3(0.0, 1.1, 0.0), POSTIT)


func prompt_text() -> String:
	if collected or hidden_behind or secret_id == "":
		return ""
	return tr("Regie-Notiz beschnuppern") if Game.hero() == "mopsula" else tr("Regie-Notiz lesen")


func interact() -> void:
	if collected or hidden_behind:
		return
	if scene != null and scene.has_method("read_note"):
		scene.call("read_note", self)
	elif Game.open_secret(secret_id):
		collect_visual(false)


## The post-it flies up, spins and is gone; the stand stays (no prompt any more).
func collect_visual(animated: bool) -> void:
	if collected:
		return
	collected = true
	monitoring = false
	var glint: Node3D = prop.get_node_or_null("Glint") as Node3D if prop != null else null
	if glint != null:
		glint.visible = false
	if postit == null:
		return
	if not animated or not is_inside_tree():
		postit.visible = false
		return
	Sfx.play(&"coin")
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(postit, "position:y", postit.position.y + 1.2, COLLECT_SEC).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(postit, "rotation:y", TAU * 1.5, COLLECT_SEC)
	tw.tween_property(postit, "scale", Vector3.ONE * 0.2, COLLECT_SEC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: postit.visible = false)
