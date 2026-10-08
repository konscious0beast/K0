extends "res://scenes/exploration/interactable.gd"
## Floor event with a choice dialog (02_TECH §7.3/§7.4, GDD §2.6). Offers FloorEvent.choices() (impossible options are
## shown greyed out); a choice goes through Game.apply_floor_event (rules, Show, record, Events.event_completed);
## ExplorationScene reacts to open_gate / encounter_id of the outcome. Completed events (and an exhausted wheel) have no
## prompt any more.

const PROPS: Dictionary = {"photo_drone": &"camera_drone", "lost_candidate": &"phone_booth", "wheel": &"fortune_wheel",
	"lever": &"lever", "broken_vending": &"broken_vending"}

## Reveal pacing (M3 tuning, no spec value): the same for PropKit (M4) props and fallback props, so how long the timer
## stays paused does not depend on which art is loaded.
const LEVER_SEC: float = 0.35
const WHEEL_SEC: float = 1.2
const DRONE_SEC: float = 0.4
const KICK_SEC: float = 0.3

var ev: EventSpawn = null
var prop: Node3D = null
var _dimmed: bool = false


func setup_event(p_ev: EventSpawn, palette: Dictionary, prop_seed: int) -> void:
	ev = p_ev
	interact_id = p_ev.id
	name = "Event_" + p_ev.id
	extent = 0.5
	var prop_id: StringName = PROPS.get(p_ev.type, &"crate")
	prop = PropKit.build(prop_id, prop_seed, palette)
	if prop == null:
		prop = Node3D.new()
	if FB.is_empty(prop):
		FB.fill_prop(prop, prop_id, palette)
	prop.name = "Prop"
	add_child(prop)
	if p_ev.type != "photo_drone":
		_make_blocker(Vector3(1.1, 1.8, 0.9), Vector3(0.0, 0.9, 0.0))
	_make_area(Rules.INTERACT_RADIUS + extent + 0.8)
	refresh()


func choices() -> PackedStringArray:
	if ev == null or Game.state == null:
		return PackedStringArray()
	return FloorEvent.choices(ev, Game.state, DB.data)


func prompt_text() -> String:
	if choices().is_empty():
		return ""
	return tr("Untersuchen: %s") % title()


func interact() -> void:
	if scene != null and scene.has_method("open_event_dialog"):
		scene.call("open_event_dialog", self)


func title() -> String:
	match ev.type if ev != null else "":
		"photo_drone":
			return tr("Kamera-Drohne „Lächeln!“")
		"lost_candidate":
			return tr("Herr Brettschneider in der Telefonzelle")
		"wheel":
			return tr("Glücksrad von DoomScroll+")
		"lever":
			return tr("Verdächtiger Hebel")
		"broken_vending":
			return tr("Kaputter Automat")
	return tr("Etwas Seltsames")


func description() -> String:
	var p: Dictionary = ev.params if ev != null else {}
	match ev.type if ev != null else "":
		"photo_drone":
			return tr("Eine NOVA-Drohne surrt dir ins Gesicht. Das rote Licht blinkt: LIVE.")
		"lost_candidate":
			return tr("Ein verletzter Kandidat klammert sich an den Hörer. „Haben Sie vielleicht was zum Verbinden?“")
		"wheel":
			var left: int = spins_left()
			var spins: String = tr("Keine Drehung mehr.")
			if left == 1:
				spins = tr("Noch 1 Drehung.")
			elif left > 1:
				spins = tr("Noch %d Drehungen.") % left
			return tr("Ein Dreh kostet %d Cr. %s Die Zuschauer lieben Glücksspiel.") % [int(p.get("cost", 0)), spins]
		"lever":
			return tr("Ein rostiger Hebel. Daneben ein Schild: „NICHT ZIEHEN“.")
		"broken_vending":
			return tr("Der Automat flackert. Drinnen klemmen zwei Dosen KRAWUMM.")
	return ""


## Dialog options [{"id", "label", "enabled"}] in display order; disabled options explain what is missing.
func options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if ev == null:
		return out
	var avail: PackedStringArray = choices()
	var p: Dictionary = ev.params
	match ev.type:
		"photo_drone":
			out.append({"id": "pose", "label": tr("Posieren"), "enabled": avail.has("pose")})
			out.append({"id": "smash", "label": tr("Zertreten"), "enabled": avail.has("smash")})
		"lost_candidate":
			var gave: bool = false
			for c: String in avail:
				if c.begins_with(FloorEvent.GIVE_PREFIX):
					var item_id: String = c.substr(FloorEvent.GIVE_PREFIX.length())
					out.append({"id": c, "label": tr("Geben: %s") % _item_name(item_id), "enabled": true})
					gave = true
			if not gave:
				out.append({"id": "give", "label": tr("Heilitem geben (keins dabei)"), "enabled": false})
			out.append({"id": "leave", "label": tr("Weitergehen"), "enabled": avail.has("leave")})
		"wheel":
			var spin_label: String = tr("Drehen (%d Cr)") % int(p.get("cost", 0))
			if not avail.has("spin"):
				# Greyed out with the reason (what is missing).
				spin_label = tr("%s – keine Drehungen mehr") % spin_label if spins_left() <= 0 \
					else tr("%s – zu wenig Credits") % spin_label
			out.append({"id": "spin", "label": spin_label, "enabled": avail.has("spin")})
			out.append({"id": "ignore", "label": tr("Ignorieren"), "enabled": avail.has("ignore")})
		"lever":
			out.append({"id": "pull", "label": tr("Ziehen"), "enabled": avail.has("pull")})
			out.append({"id": "leave", "label": tr("Lassen"), "enabled": avail.has("leave")})
		"broken_vending":
			out.append({"id": "kick", "label": tr("Treten"), "enabled": avail.has("kick")})
			out.append({"id": "leave", "label": tr("Lassen"), "enabled": avail.has("leave")})
	return out


## Choice that only closes the dialog (ui_cancel).
func cancel_choice() -> String:
	return ""


## Option focused first in the dialog: the safe one (leave / ignore), so a mashed confirm key risks nothing.
func default_choice() -> String:
	match ev.type if ev != null else "":
		"photo_drone":
			return "pose"
		"wheel":
			return "ignore"
	return "leave"


## Wheel spins left on this floor (max_spins − event_uses).
func spins_left() -> int:
	if ev == null:
		return 0
	var uses: int = int(Game.state.floor_run.event_uses.get(ev.id, 0)) \
		if Game.state != null and Game.state.floor_run != null else 0
	return maxi(0, int(ev.params.get("max_spins", 3)) - uses)


## Short result line for a toast ("" = none).
func outcome_text(choice: String, outcome: Dictionary) -> String:
	if not bool(outcome.get("valid", false)):
		return ""
	match ev.type:
		"photo_drone":
			return tr("Klick! Die Zuschauer sind begeistert.") if choice == "pose" \
				else tr("Drohne zerlegt: +%d Cr") % int(outcome.get("credits", 0))
		"lost_candidate":
			if choice.begins_with(FloorEvent.GIVE_PREFIX):
				return tr("Herr Brettschneider bedankt sich mit einem Glückslos.")
		"wheel":
			var w: Dictionary = outcome.get("wheel", {})
			match str(w.get("kind", "nothing")):
				"item":
					return tr("Glücksrad: %d× %s") % [int(w.get("amount", 1)), _item_name(str(w.get("id", "")))]
				"credits":
					return tr("Glücksrad: +%d Cr") % int(w.get("amount", 0))
				"box":
					return tr("Glücksrad: Lootbox!")
				"encounter":
					return tr("Glücksrad: Tauben-Alarm!")
				_:
					return tr("Glücksrad: Niete. Werbepause.")
		"lever":
			return tr("Klonk! Irgendwo öffnet sich ein Tor.") if bool(outcome.get("success", false)) \
				else tr("Flutwelle! Und da kommt noch was …")
		"broken_vending":
			return tr("Zwei Dosen KRAWUMM fallen heraus!") if bool(outcome.get("success", false)) \
				else tr("Stromschlag! Autsch.")
	return ""


## Visual reaction of the prop after a choice; returns how long it plays (s). The scene shows the result toast and
## starts a resulting encounter only after it (no spoiled wheel result, the lever moves before the flood fight).
func play_outcome(choice: String, outcome: Dictionary) -> float:
	var dur: float = 0.0
	if not bool(outcome.get("valid", false)) or not is_inside_tree():
		refresh()
		return dur
	match ev.type:
		"lever":
			var handle: Node3D = prop.get_node_or_null("Handle") as Node3D
			if prop.has_method("play_action"):
				# PropKit lever (M4 PropAnim): the arm is pulled down in 0.35 s and swings back afterwards.
				dur = LEVER_SEC
				prop.call("play_action")
			elif handle != null:
				dur = LEVER_SEC
				var tw: Tween = create_tween()
				tw.tween_property(handle, "rotation:x", deg_to_rad(35.0), LEVER_SEC).set_trans(Tween.TRANS_BACK)
		"wheel":
			var spin: Node3D = prop.get_node_or_null("Wheel/Spin") as Node3D
			if prop.has_method("play_action"):
				# PropKit wheel (M4 PropAnim): fast spin slowing down to its idle turn (no segment to land on).
				dur = WHEEL_SEC
				prop.call("play_action")
			elif spin != null:
				dur = WHEEL_SEC
				var tw2: Tween = create_tween()
				tw2.tween_property(spin, "rotation:y", spin.rotation.y + TAU * 3.0 + 1.3, WHEEL_SEC) \
					.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		"photo_drone":
			if choice == "smash":
				dur = DRONE_SEC
				var tw3: Tween = create_tween()
				tw3.tween_property(prop, "position:y", -1.4, DRONE_SEC).set_trans(Tween.TRANS_QUAD) \
					.set_ease(Tween.EASE_IN)
				tw3.tween_callback(func() -> void: prop.visible = false)
		"broken_vending":
			if choice == "kick":
				dur = KICK_SEC
				var base: Vector3 = prop.position
				var tw4: Tween = create_tween()
				for i in 4:
					var dx: float = 0.06 * (1.0 if i % 2 == 0 else -1.0)
					tw4.tween_property(prop, "position", base + Vector3(dx, 0.0, 0.0), KICK_SEC / 5.0)
				tw4.tween_property(prop, "position", base, KICK_SEC / 5.0)
	refresh()
	return dur


## Completed events (and an exhausted wheel) are dimmed: glow parts off, no pulse, albedo −40 % (no prompt any more).
func refresh() -> void:
	if prop == null:
		return
	var done: bool = choices().is_empty()
	set_meta(&"completed", done)
	if done != _dimmed:
		_dimmed = done
		FB.dim_prop(prop, done)


func is_dimmed() -> bool:
	return _dimmed
