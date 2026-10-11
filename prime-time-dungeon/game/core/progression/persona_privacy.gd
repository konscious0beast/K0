class_name PersonaPrivacy extends RefCounted
## The export boundary of the persona (08 §2.7): display fields (GameState.player_name, the kai member's
## display_name) never leave the device inside a state dictionary — run-log anchors (start_state) and the save slot
## file carry GameState.DEFAULT_NAME; the persona file (Save.persona_path) restores them locally. StateHash leaves them
## out anyway (P-2), so start_hash stays valid.

const MEMBER: String = "kai"


## Deep copy of a GameState.to_dict() with player_name and the kai member's display_name set to "Kai".
static func scrub_state_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	if out.has("player_name"):
		out["player_name"] = GameState.DEFAULT_NAME
	var party: Variant = out.get("party", null)
	if party is Array:
		for m: Variant in (party as Array):
			if m is Dictionary and str((m as Dictionary).get("id", "")) == MEMBER:
				(m as Dictionary)["display_name"] = GameState.DEFAULT_NAME
	return out


## Sets the display fields of `state` from the persona file (no-op without a profile).
static func restore_display(state: GameState, p: PersonaProfile) -> void:
	if state == null or p == null:
		return
	state.player_name = p.name
	var kai: PartyMember = state.member(MEMBER)
	if kai != null:
		kai.display_name = p.name
