extends TestCase
## M4 galleries (02_TECH §1.5/§12.4 screenshot targets): every gallery scene instantiates, builds its content and runs a
## few frames without script errors (the runner fails a test on any SCRIPT ERROR). The render probe skips itself
## headless (pixels are only measured under check.sh --shot).

const SCENES: PackedStringArray = [
	"res://art/gallery/character_gallery.tscn", "res://art/gallery/archetype_gallery.tscn",
	"res://art/gallery/anim_gallery.tscn", "res://art/gallery/prop_gallery.tscn", "res://art/gallery/hero_gallery.tscn",
	"res://art/gallery/boss_gallery.tscn", "res://art/gallery/enemy_gallery.tscn", "res://art/gallery/env_gallery.tscn",
	"res://art/gallery/env_room_gallery.tscn", "res://art/gallery/env_arena_gallery.tscn",
	"res://art/gallery/env_safe_gallery.tscn", "res://art/gallery/env_kinds_gallery.tscn",
	"res://art/gallery/env_props_gallery.tscn", "res://art/gallery/vfx_gallery.tscn",
	"res://art/gallery/render_probe.tscn",
]


func _count(root: Node, cls: String) -> int:
	var n: int = 1 if root.is_class(cls) else 0
	for c: Node in root.get_children():
		n += _count(c, cls)
	return n


func test_every_gallery_scene_runs() -> void:
	for path: String in SCENES:
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, path)
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		add_to_tree(inst)
		await wait_frames(6)
		assert_true(is_instance_valid(inst) and inst.is_inside_tree(), path + " still alive")
		if path.ends_with("render_probe.tscn"):
			assert_gt(_count(inst, "SubViewport"), 0, "probe renders into its own viewport")
		else:
			assert_eq(_count(inst, "Camera3D"), 1, path + ": one camera")
			assert_gt(_count(inst, "MeshInstance3D"), 0, path + ": has content")
		if is_instance_valid(inst):
			inst.get_parent().remove_child(inst)
			inst.free()


func test_vfx_gallery_freezes_effects() -> void:
	var inst: Node = (load("res://art/gallery/vfx_gallery.tscn") as PackedScene).instantiate()
	add_to_tree(inst)
	await wait_frames(4)
	var effects: int = 0
	for c: Node in inst.get_children():
		if c.get("kind") != null and Vfx.KINDS.has(c.get("kind") as StringName):
			effects += 1
	assert_eq(effects, Vfx.KINDS.size(), "one effect per kind")
	var labels: int = 0
	var captions: int = 0
	for c: Node in inst.get_children():
		if c.has_method("show_number"):
			if bool(c.get("is_caption")):
				captions += 1
			else:
				labels += 1
	assert_eq(labels, Vfx.STYLES.size(), "one damage number per style")
	assert_eq(captions, 2, "weak + resist captions")
