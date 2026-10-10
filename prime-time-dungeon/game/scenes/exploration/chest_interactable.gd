extends "res://scenes/exploration/interactable.gd"
## Chest (02_TECH §7.3, GDD §2.5): wood / metal / locked. Opening goes through Game.open_chest (rolls with
## SeedUtil.derive(floor_run.loot_seed, "chest", k) — 05 CR-11, never the public layout seed — records, add_rewards,
## opened_chests, Events.chest_opened), then the prop animates (ChestProp.open) and Sfx chest_open plays. Locked chests
## need itm_key_master in the inventory.

var chest: ChestSpawn = null
var prop: Node3D = null
var is_open: bool = false


func setup_chest(spawn: ChestSpawn, palette: Dictionary, prop_seed: int, opened: bool) -> void:
	chest = spawn
	interact_id = spawn.id
	name = "Chest_" + spawn.id
	extent = 0.35
	prop = PropKit.build(&"chest", prop_seed, palette)
	if prop == null:
		prop = Node3D.new()
	if FB.is_empty(prop):
		FB.fill_prop(prop, &"chest", palette, {"type": spawn.type})
	prop.name = "Prop"
	add_child(prop)
	_make_blocker(Vector3(0.95, 0.6, 0.65), Vector3(0.0, 0.3, 0.0))
	_drop_prop_collision(prop)
	_make_area(Rules.INTERACT_RADIUS + extent + 0.8)
	if opened:
		is_open = true
		_show_open(false)


func is_locked() -> bool:
	return chest != null and chest.type == "locked"


func prompt_text() -> String:
	if is_open or chest == null:
		return ""
	if is_locked() and not _has_item(KEY_ITEM):
		return tr("Verschlossen. Ein Generalschlüssel wäre praktisch.")
	if is_locked():
		return tr("Spind aufschließen")
	if chest.type == "metal":
		return tr("Spind öffnen")
	return tr("Kiste öffnen")


func interact() -> void:
	if is_open or chest == null or Game.state == null or Game.state.floor_run == null:
		return
	if is_locked() and not _has_item(KEY_ITEM):
		Sfx.play_ui(&"ui_error")
		return
	var rewards: Array[LootReward] = Game.open_chest(chest.id)
	if not Game.state.floor_run.opened_chests.has(chest.id):
		Sfx.play_ui(&"ui_error")
		return
	is_open = true
	_show_open(true)
	Sfx.play(&"chest_open")
	if scene != null and scene.has_method("on_chest_opened"):
		scene.call("on_chest_opened", self, rewards)


func _show_open(animated: bool) -> void:
	if prop is ChestProp:
		var cp: ChestProp = prop as ChestProp
		if animated:
			cp.open(true)
		else:
			cp.set_open_instant()
	if prop.has_meta(FB.META_FALLBACK):
		FB.open_chest(prop, animated)
